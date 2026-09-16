New-GPO -Name "Northbridge - Account Policy" -Comment "Password and lockout policy - must link at domain root"
New-GPLink -Name "Northbridge - Account Policy" -Target "DC=corp,DC=northbridge,DC=local"