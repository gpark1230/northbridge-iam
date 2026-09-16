Get-ADGroup -Filter 'Name -like "RES_*"' | ForEach-Object {
    $members = (Get-ADGroupMember $_ | Select-Object -ExpandProperty Name) -join ", "
    [PSCustomObject]@{ Resource = $_.Name; Roles = $members }
} | Sort-Object Resource | Format-Table -AutoSize -Wrap