$nb = "OU=Northbridge,DC=corp,DC=northbridge,DC=local"

New-GPO -Name "Tier Enforcement - Workstations" -Comment "Denies Tier 0 and Tier 1 admin logon to workstations"
New-GPO -Name "Tier Enforcement - Servers"      -Comment "Denies Tier 0 and Tier 2 admin logon to member servers"
New-GPO -Name "Tier Enforcement - DCs"          -Comment "Denies Tier 1 and Tier 2 admin logon to domain controllers"

New-GPLink -Name "Tier Enforcement - Workstations" -Target "OU=Workstations,OU=Computers,$nb"
New-GPLink -Name "Tier Enforcement - Servers"      -Target "OU=Servers,OU=Computers,$nb"
New-GPLink -Name "Tier Enforcement - DCs"          -Target "OU=Domain Controllers,DC=corp,DC=northbridge,DC=local"