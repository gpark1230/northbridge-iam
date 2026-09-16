$nb = "OU=Northbridge,DC=corp,DC=northbridge,DC=local"
$pw = Read-Host "Admin account password" -AsSecureString

# Tier 0 — domain/identity administration
New-ADUser -Name "svc-admin-t0" -SamAccountName "admin-t0" `
    -UserPrincipalName "admin-t0@corp.northbridge.local" `
    -Path "OU=Tier0,OU=AdminAccounts,$nb" `
    -AccountPassword $pw -Enabled $true `
    -Description "Tier 0 admin - domain controllers and AD only"

# Tier 1 — member servers
New-ADUser -Name "svc-admin-t1" -SamAccountName "admin-t1" `
    -UserPrincipalName "admin-t1@corp.northbridge.local" `
    -Path "OU=Tier1,OU=AdminAccounts,$nb" `
    -AccountPassword $pw -Enabled $true `
    -Description "Tier 1 admin - member servers and applications"

# Tier 2 — workstations
New-ADUser -Name "svc-admin-t2" -SamAccountName "admin-t2" `
    -UserPrincipalName "admin-t2@corp.northbridge.local" `
    -Path "OU=Tier2,OU=AdminAccounts,$nb" `
    -AccountPassword $pw -Enabled $true `
    -Description "Tier 2 admin - workstations and end-user support"

# Groups that define each tier
$adminOU = "OU=AdminAccounts,$nb"
New-ADGroup -Name "TIER0_Admins" -GroupScope Global -GroupCategory Security `
    -Path $adminOU -Description "Domain and identity administration"
New-ADGroup -Name "TIER1_Admins" -GroupScope Global -GroupCategory Security `
    -Path $adminOU -Description "Member server administration"
New-ADGroup -Name "TIER2_Admins" -GroupScope Global -GroupCategory Security `
    -Path $adminOU -Description "Workstation administration"

Add-ADGroupMember -Identity "TIER0_Admins" -Members "admin-t0"
Add-ADGroupMember -Identity "TIER1_Admins" -Members "admin-t1"
Add-ADGroupMember -Identity "TIER2_Admins" -Members "admin-t2"