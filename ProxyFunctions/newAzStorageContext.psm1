function New-AzureStorageContext {
[CmdletBinding(DefaultParameterSetName='AccountNameAndKey')]
param(
    [Parameter(ParameterSetName='AnonymousAccountEnvironment', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [Parameter(ParameterSetName='AccountNameAndKeyEnvironment', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [Parameter(ParameterSetName='AnonymousAccount', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [Parameter(ParameterSetName='SasTokenWithAzureEnvironment', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [Parameter(ParameterSetName='SasToken', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [Parameter(ParameterSetName='AccountNameAndKey', Mandatory=$true, Position=0, HelpMessage='Azure Storage Acccount Name')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${StorageAccountName},

    [Parameter(ParameterSetName='AccountNameAndKey', Mandatory=$true, Position=1, HelpMessage='Azure Storage Account Key')]
    [Parameter(ParameterSetName='AccountNameAndKeyEnvironment', Mandatory=$true, Position=1, HelpMessage='Azure Storage Account Key')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${StorageAccountKey},

    [Parameter(ParameterSetName='SasTokenWithAzureEnvironment', Mandatory=$true, HelpMessage='Azure Storage SAS Token')]
    [Parameter(ParameterSetName='SasToken', Mandatory=$true, HelpMessage='Azure Storage SAS Token')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${SasToken},

    [Parameter(ParameterSetName='ConnectionString', Mandatory=$true, HelpMessage='Azure Storage Connection String')]
    [ValidateNotNullOrEmpty()]
    [string]
    ${ConnectionString},

    [Parameter(ParameterSetName='LocalDevelopment', Mandatory=$true, HelpMessage='Use local development storage account')]
    [switch]
    ${Local},

    [Parameter(ParameterSetName='AnonymousAccountEnvironment', Mandatory=$true, HelpMessage='Use anonymous storage account')]
    [Parameter(ParameterSetName='AnonymousAccount', Mandatory=$true, HelpMessage='Use anonymous storage account')]
    [switch]
    ${Anonymous},

    [Parameter(ParameterSetName='AccountNameAndKey', HelpMessage='Protocol specification (HTTP or HTTPS), default is HTTPS')]
    [Parameter(ParameterSetName='AnonymousAccountEnvironment', HelpMessage='Protocol specification (HTTP or HTTPS), default is HTTPS')]
    [Parameter(ParameterSetName='AnonymousAccount', HelpMessage='Protocol specification (HTTP or HTTPS), default is HTTPS')]
    [Parameter(ParameterSetName='SasToken', HelpMessage='Protocol specification (HTTP or HTTPS), default is HTTPS')]
    [Parameter(ParameterSetName='AccountNameAndKeyEnvironment', HelpMessage='Protocol specification (HTTP or HTTPS), default is HTTPS')]
    [ValidateSet('Http','Https')]
    [string]
    ${Protocol},

    [Parameter(ParameterSetName='SasToken', HelpMessage='Azure storage endpoint')]
    [Parameter(ParameterSetName='AnonymousAccount', HelpMessage='Azure storage endpoint')]
    [Parameter(ParameterSetName='AccountNameAndKey', HelpMessage='Azure storage endpoint')]
    [string]
    ${Endpoint},

    [Parameter(ParameterSetName='AccountNameAndKeyEnvironment', Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Azure environment name')]
    [Parameter(ParameterSetName='SasTokenWithAzureEnvironment', Mandatory=$true, HelpMessage='Azure environment name')]
    [Parameter(ParameterSetName='AnonymousAccountEnvironment', Mandatory=$true, ValueFromPipelineByPropertyName=$true, HelpMessage='Azure environment name')]
    [Alias('Name','EnvironmentName')]
    [string]
    ${Environment},
    
    [Parameter(ParameterSetName='AccountNameAndKey', Mandatory=$false, HelpMessage='Azure Subscription Name')]
    [string]${SubscriptionName},

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

        $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Azure\New-AzureStorageContext', [System.Management.Automation.CommandTypes]::Cmdlet)
        $scriptCmd = {& $wrappedCmd @PSBoundParameters }
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
<#

.ForwardHelpTargetName Azure\New-AzureStorageContext
.ForwardHelpCategory Cmdlet

#>

}