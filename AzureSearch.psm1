<#
	Configuration file for module
#>

#get module object
$myScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
$myModule = Get-Content $myScriptRoot\AzureSearch.psm1
$mInfo = $MyInvocation.MyCommand.ScriptBlock.Module


#set OnRemove actions
$mInfo.OnRemove = {
    #cleanup properties being added
    Remove-TypeData -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleListContext'
    Remove-TypeData -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext'
}


#updating formats
Update-FormatData -PrependPath "$PSScriptRoot\AzureSearch.format.ps1xml"


#updating types

#add StaticIpAddress field
Update-TypeData -MemberType ScriptProperty -MemberName 'StaticIpAddress' -Value {(Get-AzureStaticVNetIP -vm $this).ipaddress} -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleListContext'
Update-TypeData -MemberType ScriptProperty -MemberName 'StaticIpAddress' -Value {(Get-AzureStaticVNetIP -vm $this).ipaddress} -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext'

#add AzureSubnet field
Update-TypeData -MemberType ScriptProperty -MemberName 'AzureSubnet' -Value {Get-AzureSubnet -vm $this} -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleListContext'
Update-TypeData -MemberType ScriptProperty -MemberName 'AzureSubnet' -Value {Get-AzureSubnet -vm $this} -TypeName 'Microsoft.WindowsAzure.Commands.ServiceManagement.Model.PersistentVMRoleContext'