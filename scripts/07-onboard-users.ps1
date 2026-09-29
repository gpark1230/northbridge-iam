<#
.SYNOPSIS
    Provisions Active Directory accounts from the simulated HR feed.

.DESCRIPTION
    Reads data/hr-feed.csv and data/role-matrix.csv. For each person,
    resolves their job title to a target OU and role group, creates the
    account, assigns group membership, sets the manager, and applies an
    account expiry for time-bound employee types.

    Idempotent: existing accounts are skipped, so the script can run
    against the full feed on any schedule.

.NOTES
    Run on NB-DC01 as a domain administrator, from the repository root.
#>

Import-Module ActiveDirectory

$domainDN   = "DC=corp,DC=northbridge,DC=local"
$orgOU      = "OU=Northbridge,$domainDN"
$hrFeed     = Import-Csv ".\data\hr-feed.csv"
$roleMatrix = Import-Csv ".\data\role-matrix.csv"

$defaultPassword = ConvertTo-SecureString "Northbridge!Temp2026" -AsPlainText -Force
$log = @()

# Build a lookup table so each job title resolves in one operation
# instead of scanning the whole matrix for every person.
$roleLookup = @{}
foreach ($row in $roleMatrix) {
    $roleLookup[$row.JobTitle] = $row
}

foreach ($person in $hrFeed) {

    # No rule for this job title - log it and move on rather than
    # failing silently or stopping the whole run.
    $rule = $roleLookup[$person.JobTitle]
    if (-not $rule) {
        $log += "SKIPPED: $($person.EmployeeID) - no rule for job title '$($person.JobTitle)'"
        continue
    }

    # Strip anything that is not a letter, so names like O'Rourke
    # do not produce an invalid account name. 20 chars is the AD limit.
    $first = $person.FirstName -replace "[^a-zA-Z]", ""
    $last  = $person.LastName  -replace "[^a-zA-Z]", ""
    $sam   = ("$first.$last").ToLower()
    if ($sam.Length -gt 20) { $sam = $sam.Substring(0, 20) }

    # Idempotency check: a real HR feed sends every employee every run,
    # not just new ones, so the script has to skip what already exists.
    if (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) {
        $log += "EXISTS:  $sam - already provisioned, skipping"
        continue
    }

    # The matrix stores the OU path with semicolons because commas
    # would break the CSV. Swap them back and append the domain path.
    $targetOU = ($rule.TargetOU -replace ";", ",") + ",$orgOU"

    $params = @{
        Name                  = "$($person.FirstName) $($person.LastName)"
        GivenName             = $person.FirstName
        Surname               = $person.LastName
        SamAccountName        = $sam
        UserPrincipalName     = "$sam@corp.northbridge.local"
        DisplayName           = "$($person.FirstName) $($person.LastName)"
        Path                  = $targetOU
        AccountPassword       = $defaultPassword
        Enabled               = $true
        ChangePasswordAtLogon = $true
        EmployeeID            = $person.EmployeeID
        Department            = $person.Department
        Title                 = $person.JobTitle
    }

    # One failure should not stop the remaining accounts from provisioning.
    try {
        New-ADUser @params
        Add-ADGroupMember -Identity $rule.RoleGroup -Members $sam
    }
    catch {
        $log += "FAILED:  $sam - $($_.Exception.Message)"
        continue
    }

    # Department heads have no manager, and a manager may not exist yet
    # if the feed is not ordered by hierarchy. Both cases are handled.
    if ($person.Manager) {
        $mgr = Get-ADUser -LDAPFilter "(employeeID=$($person.Manager))" -ErrorAction SilentlyContinue
        if ($mgr) {
            Set-ADUser -Identity $sam -Manager $mgr.DistinguishedName
        }
    }

    # Policy comes from the role matrix, the date comes from the HR feed.
    if ($rule.AccountExpires -eq "Yes" -and $person.EndDate) {
        Set-ADAccountExpiration -Identity $sam -DateTime ([datetime]$person.EndDate)
        $log += "CREATED: $sam ($($person.JobTitle)) - expires $($person.EndDate)"
    }
    else {
        $log += "CREATED: $sam ($($person.JobTitle))"
    }
}

Write-Host "`n=== Provisioning Summary ===" -ForegroundColor Cyan
$log | ForEach-Object { Write-Host $_ }
Write-Host "`nTotal processed: $($hrFeed.Count)" -ForegroundColor Cyan

# Write the run log as audit evidence of what was provisioned and when.
if (-not (Test-Path ".\findings")) {
    New-Item -ItemType Directory -Path ".\findings" | Out-Null
}
$log | Out-File ".\findings\provisioning-log-$(Get-Date -Format 'yyyy-MM-dd').txt"