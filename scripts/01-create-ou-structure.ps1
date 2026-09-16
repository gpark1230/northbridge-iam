$base = "DC=corp,DC=northbridge,DC=local"

# Top-level container for the whole organization
New-ADOrganizationalUnit -Name "Northbridge" -Path $base

$nb = "OU=Northbridge,$base"

# Business units
New-ADOrganizationalUnit -Name "Corporate"       -Path $nb
New-ADOrganizationalUnit -Name "Operations"      -Path $nb
New-ADOrganizationalUnit -Name "External"        -Path $nb
New-ADOrganizationalUnit -Name "ServiceAccounts" -Path $nb
New-ADOrganizationalUnit -Name "AdminAccounts"   -Path $nb
New-ADOrganizationalUnit -Name "Computers"       -Path $nb

# Corporate departments
$corp = "OU=Corporate,$nb"
"Finance","HR","IT","Sales","Marketing" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $corp
}

# Operations departments
$ops = "OU=Operations,$nb"
"Warehouse","Drivers","Dispatch" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $ops
}

# External workers
$ext = "OU=External,$nb"
"Contractors","Seasonal" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $ext
}

# Admin tiers
$admin = "OU=AdminAccounts,$nb"
"Tier0","Tier1","Tier2" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $admin
}

# Computer objects
$comp = "OU=Computers,$nb"
"Workstations","Servers" | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path $comp
}