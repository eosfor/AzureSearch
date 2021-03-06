function Get-AzureVM {
[CmdletBinding(DefaultParameterSetName='ListAllVMs')]
param(
    [Parameter(ParameterSetName='GetVMByServiceAndVMName', Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true, HelpMessage='Service name.')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${ServiceName},

    [Parameter(ParameterSetName='GetVMByServiceAndVMName', Position=1, ValueFromPipelineByPropertyName=$true, HelpMessage='The name of the virtual machine to get.')]
    [string]
    ${Name},

    [Parameter(ParameterSetName='ListAllVMs', Position=1, ValueFromPipelineByPropertyName=$true, HelpMessage='Subscription name.')]
    [Parameter(ParameterSetName='GetVMByServiceAndVMName', Position=2, ValueFromPipelineByPropertyName=$true, HelpMessage='Subscription name.')]
    [string]
    ${SubscriptionName},

    [Parameter(ParameterSetName='ListAllVMs', Position=1, ValueFromPipelineByPropertyName=$true, HelpMessage='Subscription name.')]
    [Parameter(ParameterSetName='GetVMByServiceAndVMName', Position=2, ValueFromPipelineByPropertyName=$true, HelpMessage='Subscription name.')]
    [string]
    ${SubscriptionID},

    [Parameter(HelpMessage='In-memory profile.')]
    [Microsoft.Azure.Common.Authentication.Models.AzureSMProfile]
    ${Profile})

begin
{
    try {
        $outBuffer = $null
        $defaultSubscription = Get-AzureSubscription -Default

        if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
        {
            $PSBoundParameters['OutBuffer'] = 1
        }

        if ($PSBoundParameters['SubscriptionName'])
        {
            $null = $PSBoundParameters.Remove('SubscriptionName')
            
            Select-AzureSubscription -SubscriptionName $SubscriptionName -ErrorAction Stop
        }

        if ($PSBoundParameters['SubscriptionID'])
        {
            $null = $PSBoundParameters.Remove('SubscriptionID')
            
            Select-AzureSubscription -SubscriptionID $SubscriptionID -ErrorAction Stop
        }

        $subsName = (Get-AzureSubscription -Default).SubscriptionName
        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Azure\Get-AzureVM', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters | Add-Member -MemberType NoteProperty -Name "SubscriptionName" -Value $subsName -PassThru}
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process
{
    try {
        $obj = $steppablePipeline.Process($_)
    } catch {
        throw
    }
}

end
{
    try {
        Select-AzureSubscription -SubscriptionName $defaultSubscription.SubscriptionName
        $steppablePipeline.End()
    } catch {
        throw
    }
}
<#

.ForwardHelpTargetName Azure\Get-AzureVM
.ForwardHelpCategory Cmdlet

#>

}