function Get-AzureDisk {
[CmdletBinding()]
param(
    [Parameter(Position=0, ValueFromPipelineByPropertyName=$true, HelpMessage='Name of the disk in the disk library.')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${DiskName},

    [Parameter(Position=1, ValueFromPipelineByPropertyName=$true, HelpMessage='Subscription name.')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${SubscriptionName},

    [Parameter(HelpMessage='In-memory profile.')]
    [Microsoft.Azure.Common.Authentication.Models.AzureProfile]
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


        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Azure\Get-AzureDisk', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters | % {
            $subs = Get-AzureSubscription -Current
            $_ | Add-Member -MemberType NoteProperty -Name 'SubscriptionName' -Value $subs.SubscriptionName  -PassThru -force }
            }
        $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
        $steppablePipeline.Begin($PSCmdlet)
    } catch {
        throw
    }
}

process
{
    try {
        $steppablePipeline.Process($_)
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
}
<#

.ForwardHelpTargetName Azure\Get-AzureDisk
.ForwardHelpCategory Cmdlet

#>

