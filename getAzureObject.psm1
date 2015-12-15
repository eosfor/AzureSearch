<#
# Load ADAL Assemblies
$adal = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
$adalforms = "${env:ProgramFiles(x86)}\Microsoft SDKs\Azure\PowerShell\ServiceManagement\Azure\Services\Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll"
[System.Reflection.Assembly]::LoadFrom($adal)
[System.Reflection.Assembly]::LoadFrom($adalforms)
#>

function Get-AzureObject {
[CmdletBinding()]
param(
    [Parameter(ParameterSetName = "Common", Mandatory=$true)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $true)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $true)]
    [string[]]$Name,
    
    [Parameter(ParameterSetName = "BySubName", Mandatory = $true)]
    [string]$SubscriptionName,
    
    [Parameter(ParameterSetName = "BySubID", Mandatory = $true)]
    [string[]]$SubscriptionID,
    
    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    [string]$apiVersion = '2014-04-01-preview',
    
    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    [switch]$VMOnly,
    
    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    [switch]$ServiceOnly,
    
    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    [switch]$StorageOnly,

    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    [switch]$All,

    [Parameter(ParameterSetName = "Common", Mandatory=$false, HelpMessage = 'Returns raw data, works faster')]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]    
    [switch]$RawOutput,
    
    [Parameter(ParameterSetName = "Common", Mandatory = $true)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $true)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $true)]
    $ADTenant,
    
    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubName", Mandatory = $false)]
    [Parameter(ParameterSetName = "BySubID", Mandatory = $false)]
    $authHeader,

    [Parameter(ParameterSetName = "Common", Mandatory = $false)]
    [switch]$IncludeMKT
)
begin{
    if (! $PSBoundParameters["authHeader"]) {$authHeader = Get-AzureAuthHeader -ADTenant $ADTenant}

    ## hashtable with resource types and actions for each type
    $typesToFilter = @{'Microsoft.ClassicCompute/virtualMachines' = {param($id, $rg, $n) Get-AzureVM -SubscriptionID $id -ServiceName $rg -Name $n};
                       'Microsoft.ClassicCompute/domainNames' = {param($id, $rg, $n) Get-AzureService -SubscriptionName (Get-AzureSubscription -SubscriptionId $id).SubscriptionName -ServiceName $rg};
                       'microsoft.classicstorage/storageaccounts' = {param($id, $rg, $n) getStorageAccount $id $rg $n}}
    
    [System.Threading.Mutex] $mutant = New-Object 'System.Threading.Mutex';
    try
    {
        # Obtain a system mutex that prevents more than one deployment taking place at the same time.
        [bool]$wasCreated = $false;
        $mutant = New-Object System.Threading.Mutex($true, "MyMutex", [ref] $wasCreated);        
        if (!$wasCreated)
        {            
            $null = $mutant.WaitOne();
        }

        ### Do Work ###
        ## query string to include all subscriptions registered by using Add-AzureAccount (subscriptions part of the query)
        ## if ($PSBoundParameters.ContainsKey('SubscriptionName')){$subscrFilterString = generateFilterStringForSubscription -SubscriptionName $SubscriptionName}
        ## if ($PSBoundParameters.ContainsKey('SubscriptionID')){$subscrFilterString = generateFilterStringForSubscription -SubscriptionID $SubscriptionID}

        switch ($PsCmdlet.ParameterSetName){
            "Common" {$subscrFilterString = generateFilterStringForSubscription; break}
            "BySubName" {$subscrFilterString = generateFilterStringForSubscription -SubscriptionName $SubscriptionName; break}
            "BySubID" {$subscrFilterString = generateFilterStringForSubscription -SubscriptionID $SubscriptionID; break}
        }
    }
    finally
    {       
        $null = $mutant.ReleaseMutex(); 
        $null = $mutant.Dispose();
    }

    $headers = @{"x-ms-version"="$headerDate";
                "Authorization" = $authHeader;
                'Accept' = 'application/json'}

    
    # API method
    $method = "GET"

    #defaultFilter
    $foundFilterString = @() #
}
process{
    ## by default function runs a query for all objects and after that it filters out the
    ## resulting set by just removing unneccessary stuff
    ## REST filter

    ## prepare sert of filters to remove unneccessary stuff afterwards
    if ($VMOnly.IsPresent){
       $foundFilterString +=  "(`$_.type -eq 'Microsoft.ClassicCompute/virtualMachines')"
    }

    elseif ($ServiceOnly.IsPresent){
       $foundFilterString +=  "(`$_.type -eq 'Microsoft.ClassicCompute/domainNames')"
    }

    elseif ($StorageOnly.IsPresent){
       $foundFilterString +=  "(`$_.type -eq 'microsoft.classicstorage/storageaccounts')"
    }
    else {
        $foundFilterString = $typesToFilter.Keys | % {"(`$_.type -eq '$_')"}
    }

    ## build filter string for REST Query call
    $objectFilter = ($Name | %{ ("substringof('$_', name)", "substringof('$_', resourcegroup)") -join " or " }) -join " or "
    
    ## query header (name part of the filter)
    $headers.'x-ms-path-query' = "/resources?api-version=$apiVersion&`$filter=($subscrFilterString) and (($objectFilter))" -replace " ", "%20"

    # generate the API URI
    $URI = "https://management.azure.com/api/invoke"

    # execute the Azure REST API
    $list = @()
    $res = Invoke-RestMethod -Uri $URI -Method $method -Headers $headers -ErrorAction stop
    if ($res.value) {$list += $res.value}
    
    while (Get-Member -inputobject $res -name "nextLink" -Membertype Properties ){
        $res = Invoke-RestMethod -Uri $res.nextLink -Method $method -Headers $headers -ErrorAction stop
        if ($res.value) {$list += $res.value}
    }

    ## parse received objects
    $objectsFound = 
        $list | %{
            $element = $_
            $r = [regex]::Match($element.id, "/subscriptions/(?<SubscriptionID>.+)/resourceGroups/(?<ResourceGroup>.+?)/.+/(?<ObjectName>.+)$")
            new-object psobject -Property @{SubscriptionID = $r.Groups["SubscriptionID"]; ResourceGroup = $r.Groups["ResourceGroup"]; ObjectName = $element.name; type = $element.type; location = $element.location}
        }  
    
    ## remove unneccessary results
    $resultingFilterStr = ($foundFilterString -join " -or ")
    write-verbose $resultingFilterStr
    
    $foundFilter = [scriptblock]::Create($resultingFilterStr)

    $filteredObjects = $objectsFound | where $foundFilter


    if (! $all.IsPresent){
        ## if -All is set return all objects
        $filteredObjects = $filteredObjects | where ObjectName -in $Name
    }
    

    if ($RawOutput.IsPresent) {$filteredObjects}
    else {$filteredObjects | % {
           $ret = & $typesToFilter[$_.type] $_.SubscriptionID.value $_.ResourceGroup $_.ObjectName

           $ret
        }
    }
}
}

function Get-AzureAuthHeader {
[CmdletBinding()]
param($ADTenant)
    Write-Verbose "Getting auth header"
    # Set well-known client ID for AzurePowerShell
    $clientId = "1950a258-227b-4e31-a9cf-717495945fc2" 
    # Set redirect URI for Azure PowerShell
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    # Set Resource URI to Azure Service Management API
    $resourceAppIdURI = "https://management.core.windows.net/"
    # Set Authority to Azure AD Tenant
    $authority = "https://login.windows.net/$ADTenant"
    # Create Authentication Context tied to Azure AD Tenant
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
    # Acquire token
    $authResult = $authContext.AcquireToken($resourceAppIdURI, $clientId, $redirectUri, "Auto")
    # API header
    $headerDate = '2014-10-01'
    $authHeader = $authResult.CreateAuthorizationHeader()


    $authHeader
}

function generateFilterStringForName{
[CmdletBinding()]
param($Name, [switch]$VMOnly, [switch]$ServiceOnly, [switch]$StorageOnly)
$nameFilterString = 
    ($Name | % {
        $current = $_
        if ($VMOnly.IsPresent) {"substringof('$current',name)"}
        elseif ($ServiceOnly.IsPresent) {"substringof('$current',resourcegroup)"}
        elseif ($StorageOnly.IsPresent) {"substringof('$current',name)"}
        else {("substringof('$current',name)", "substringof('$current',resourcegroup)", "substringof('$current',name)")}
    }) -join " or "

write-verbose "Names filter`: $nameFilterString"
$nameFilterString
}

function generateFilterStringForSubscription{
[CmdletBinding()]
param($SubscriptionName, $SubscriptionID)
process {
    $test = $PSBoundParameters
    if ($PSBoundParameters.ContainsKey('SubscriptionID')){
        if ($SubscriptionID) {
            $subscrFilterString = ($SubscriptionID | % {"subscriptionId eq '$_'"}) -join ' or '}
    }
    elseif ($PSBoundParameters['SubscriptionName']){
        $subscriptions = (Get-AzureSubscription -SubscriptionName $SubscriptionName).SubscriptionId
        $subscrFilterString = ($subscriptions | % {"subscriptionId eq '$_'"}) -join ' or '}
    else {
        $subscriptions = (Get-AzureSubscription).SubscriptionId
        $subscrFilterString = ($subscriptions | % {"subscriptionId eq '$_'"}) -join ' or '}

    write-verbose "Subscriptions filter`: $subscrFilterString"
    $subscrFilterString
}
}

function getStorageAccount {
param($id, $rg, $n)
    $sub = Get-AzureSubscription -SubscriptionId $id
    $acct = Get-AzureStorageAccount -StorageAccountName $n -SubscriptionName $sub.SubscriptionName 3> $null

    $acct
}