$nb    = "OU=Northbridge,DC=corp,DC=northbridge,DC=local"
$roles = "OU=Roles,OU=Groups,$nb"
$res   = "OU=Resources,OU=Groups,$nb"

# Role groups — Global scope. Users go in here.
$roleGroups = @(
    @{Name="ROLE_Finance_Staff";       Desc="Finance department staff"}
    @{Name="ROLE_Finance_Manager";     Desc="Finance department managers"}
    @{Name="ROLE_HR_Staff";            Desc="HR department staff"}
    @{Name="ROLE_IT_Staff";            Desc="IT department staff"}
    @{Name="ROLE_Sales_Staff";         Desc="Sales department staff"}
    @{Name="ROLE_Marketing_Staff";     Desc="Marketing department staff"}
    @{Name="ROLE_Warehouse_Staff";     Desc="Warehouse operatives"}
    @{Name="ROLE_Warehouse_Supervisor";Desc="Warehouse supervisors"}
    @{Name="ROLE_Driver";              Desc="Delivery drivers"}
    @{Name="ROLE_Dispatch_Staff";      Desc="Dispatch coordinators"}
    @{Name="ROLE_Contractor";          Desc="External contractors - time-bound access"}
    @{Name="ROLE_Seasonal_Warehouse";  Desc="Seasonal warehouse workers"}
)

foreach ($g in $roleGroups) {
    New-ADGroup -Name $g.Name -GroupScope Global -GroupCategory Security `
                -Path $roles -Description $g.Desc
}

# Resource groups — Domain Local scope. Permissions are applied to these.
$resGroups = @(
    @{Name="RES_ERP_Read";           Desc="Read access to ERP"}
    @{Name="RES_ERP_Write";          Desc="Write access to ERP"}
    @{Name="RES_WMS_Read";           Desc="Read access to warehouse management system"}
    @{Name="RES_WMS_Write";          Desc="Write access to warehouse management system"}
    @{Name="RES_DispatchApp_Access"; Desc="Access to dispatch application"}
    @{Name="RES_FinanceShare_Read";  Desc="Read access to finance file share"}
    @{Name="RES_FinanceShare_Write"; Desc="Write access to finance file share"}
    @{Name="RES_HRShare_Read";       Desc="Read access to HR file share"}
    @{Name="RES_SalesShare_Write";   Desc="Write access to sales file share"}
    @{Name="RES_VPN_Access";         Desc="Remote VPN access"}
)

foreach ($g in $resGroups) {
    New-ADGroup -Name $g.Name -GroupScope DomainLocal -GroupCategory Security `
                -Path $res -Description $g.Desc
}