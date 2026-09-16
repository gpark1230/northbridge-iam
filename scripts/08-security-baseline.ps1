$nb = "OU=Northbridge,DC=corp,DC=northbridge,DC=local"
New-GPO -Name "Northbridge - Security Baseline" -Comment "NTLM hardening, screen lock, audit policy"
New-GPLink -Name "Northbridge - Security Baseline" -Target $nb