function New-AzureObjectDB {
    [cmdletbinding()]
    param()
process{
    function getServices {
        $sub.SubscriptionId | Invoke-Parallel { Invoke-RestMethod -uri https://management.core.windows.net/$_/services/hostedservices -Method GET -Headers $headers }
    }
    function getDeployments {
    param($svc)
        $svc.HostedServices.HostedService | skip-null | Invoke-Parallel -ThrottleLimit 16 {
            $curr = $_
            $subId = ([uri]$curr.Url).Segments[1] -replace "\/",""
            try {
                $dep = Invoke-RestMethod -uri "https://management.core.windows.net/$subId/services/hostedservices/$($curr.ServiceName)?embed-detail=true" -Method GET -Headers $headers 
                $dep.HostedService.deployments.deployment | where {$_ -ne $null} | 
                    Add-Member -MemberType NoteProperty -Name ServiceName -Value $curr.ServiceName -Force -PassThru |
                    Add-Member -MemberType NoteProperty -Name SubscriptionID -Value $subId -Force -PassThru
            }
            catch {
                $ErrorMessage = $_.Exception.Message
                Write-Error "Failed to fetch data from $subId`:$($curr.ServiceName). Message: $ErrorMessage"
            }
        }
    }
    $authHeader = Get-AzureAuthHeader

    $headerDate = '2014-10-01'
    $headers = @{"x-ms-version"="$headerDate";
                "Authorization" = $authHeader;
                'Accept' = 'application/json'}


    $sub = Get-AzureSubscription

    $deployments = getDeployments (getServices)

    # prepare indexes
    $ipAddrIndex = @{}
    $storageAcctIndex = @{}
    $storageFileIndex = @{}
    $servicesIndex = @{}
    $deploymentIndex = @{}

    $database = new-object System.Collections.ArrayList
    
    $deployments | % {
        try {
            $curr = $_
                $ri1 = $curr.RoleInstanceList.RoleInstance | % { xmlToObject $_ }
                $ro1 = $curr.RoleList.Role | % { xmlToObject $_  }
                $vm = $ri1 | % {$c = $_; $r = $c.'RoleName'; $x = $ro1 | where {$_.'RoleName' -eq $r};  $x.remove('RoleName'); [pscustomobject]($_ + $x) } | 
                            Add-Member -MemberType NoteProperty -Name ServiceName -Value $curr.ServiceName -PassThru -Force |
                            Add-Member -MemberType NoteProperty -Name DeploymentName -Value $curr.Name -PassThru -Force |
                            Add-Member -MemberType NoteProperty -Name SubscriptionID -Value $curr.SubscriptionID -PassThru -Force
                $vm | % {$database.Add($_)} | Out-Null
                $servicesIndex[$curr.ServiceName] = $deploymentIndex[$curr.Name] = $vm                
        }
        catch{ $data = 1 }
    }

    #build default indexes (IP, StorageAcct, VM os vhd, VM data VHD)
    foreach ($element in $database){
        if ($element.ipaddress) {$ipAddrIndex[$element.ipaddress] = $ipAddrIndex[$element.ipaddress] + (,$element)}
            else {$ipAddrIndex["noip"] = $ipAddrIndex["noip"] + (,$element)}

        if ($element.OSVirtualHardDisk) {$url = [uri]$element.OSVirtualHardDisk.MediaLink; $storageAcctIndex[$url.host] = $storageAcctIndex[$url.host] + (,$element)}
            else {$storageAcctIndex["noDisk"] = $storageAcctIndex["noDisk"] + (,$element)}

        if ($element.OSVirtualHardDisk) {$url = [uri]$element.OSVirtualHardDisk.MediaLink; $storageFileIndex[$url.Segments[-1]] = $storageFileIndex[$url.Segments[-1]] + (,$element)}
            else {$storageFileIndex["noDrive"] = $storageFileIndex["noDrive"] + (,$element)}

        if ($element.DataVirtualHardDisks) {
            $element.DataVirtualHardDisks.DataVirtualHardDisk | % {
                $url = [uri]$_.MediaLink; $storageFileIndex[$url.Segments[-1]] = $storageFileIndex[$url.Segments[-1]] + (,$curr)
            }
        }

    }

    #create database
    $DB = @{Database = $database; Index = @{'IPAddress' = $ipAddrIndex; StorageAccount = $storageAcctIndex; DriveFile = $storageFileIndex; Service = $servicesIndex; Deployment = $deploymentIndex}}
    $DB
}
}

function xmlToObject {
param($o)
$h = @{}
$o  | gm -MemberType Property | % {
    $prop = $_.name
    if ($o."$prop" -is 'System.Xml.XmlElement') {
        $h[$prop] = xmlToObject $o."$prop"
    }
    else { $h[$prop] = $o."$prop" }
}
$h
}
function Get-AzureObjectFromDB {
[cmdletbinding()]
param(
    [Parameter(ParameterSetName = "Common", Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    $Database)
DynamicParam{
    $paramNames = $Database.Index.keys
    $paramDictionary = new-object System.Management.Automation.RuntimeDefinedParameterDictionary
    
    #generate parameters based on indexes of the DB
    foreach ($key in $paramNames){
        $attr = New-Object System.Management.Automation.ParameterAttribute
        $attr.Mandatory = $false
        $attr.ParameterSetName = "Common"
        
        $attributeCollection = new-object System.Collections.ObjectModel.Collection[System.Attribute]
        $attributeCollection.Add($attr)

        $p = New-Object System.Management.Automation.RuntimeDefinedParameter($key, [string], $attributeCollection)

        
        $paramDictionary.Add($key, $p)
    }
    
    return $paramDictionary
}

process {
    if ($PSBoundParameters.IPAddress) {$Database.Index.IPAddress[$PSBoundParameters.IPAddress]}
    if ($PSBoundParameters.StorageAccount) {$Database.Index.StorageAccount[$PSBoundParameters.StorageAccount]}
    if ($PSBoundParameters.DriveFile) {$Database.Index.DriveFile[$PSBoundParameters.DriveFile]}
}
}