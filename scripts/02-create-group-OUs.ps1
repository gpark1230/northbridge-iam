$nb = "OU=Northbridge,DC=corp,DC=northbridge,DC=local"
New-ADOrganizationalUnit -Name "Groups" -Path $nb
New-ADOrganizationalUnit -Name "Roles"     -Path "OU=Groups,$nb"
New-ADOrganizationalUnit -Name "Resources" -Path "OU=Groups,$nb"