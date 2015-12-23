function New-AzureObjectDB {
param()
process{
    $authHeader = Get-AzureAuthHeader

    $headerDate = '2014-10-01'
    $headers = @{"x-ms-version"="$headerDate";
                "Authorization" = $authHeader;
                'Accept' = 'application/json'}

    # get subscriptions and services from them
    $sub = Get-AzureSubscription

    $h = $sub.SubscriptionId | Invoke-Parallel { Invoke-RestMethod -uri https://management.core.windows.net/$_/services/hostedservices -Method GET -Headers $headers }

    $ht = [hashtable]::Synchronized(@{})
    $h.HostedServices.HostedService | skip-null| invoke-parallel {
        #declare function inside of the script block
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
        try {
            $curr = $_
            $subId = ([uri]$curr.Url).Segments[1] -replace "\/",""
            $d = Invoke-RestMethod -uri "https://management.core.windows.net/$subId/services/hostedservices/$($curr.ServiceName)/deploymentslots/production" -Method GET -Headers $headers
            if ($d) {
                $ri1 = $d.Deployment.RoleInstanceList.RoleInstance | % { xmlToObject $_ }
                $ro1 = $d.Deployment.RoleList.Role | % { xmlToObject $_  }
                $ht[$curr.ServiceName] = $ri1 | % {$c = $_; $r = $c.'RoleName'; $x = $ro1 | where {$_.'RoleName' -eq $r};  $x.remove('RoleName'); [pscustomobject]($_ + $x) }
            }
            else { $ht[$curr.ServiceName] = $null }
        }
        catch{ $data = 1 }
    }

    # prepare indexes
    $ipAddrIndex = @{}
    $storageAcctIndex = @{}
    $storageFileIndex = @{}

    #build indexes
    $ht.Keys | % {
        $ht[$_] | % {
            if ($_.ipaddress) {$ipAddrIndex[$_.ipaddress] = $ipAddrIndex[$_.ipaddress] + (,$_)}
            else {$ipAddrIndex["noip"] = $ipAddrIndex["noip"] + (,$_)}
        }
    }

    $ht.Keys | % {
        $ht[$_] | % {
            if ($_.OSVirtualHardDisk) {$url = [uri]$_.OSVirtualHardDisk.MediaLink; $storageAcctIndex[$url.host] = $storageAcctIndex[$url.host] + (,$_)}
            else {$storageAcctIndex["noDisk"] = $storageAcctIndex["noDisk"] + (,$_)}
        }
    }

    $ht.Keys | % {
        $ht[$_] | % {
            $curr = $_
            if ($_.OSVirtualHardDisk) {$url = [uri]$_.OSVirtualHardDisk.MediaLink; $storageFileIndex[$url.Segments[-1]] = $storageFileIndex[$url.Segments[-1]] + (,$_)}
            else {$storageFileIndex["noDrive"] = $storageFileIndex["noDrive"] + (,$_)}

            if ($_.DataVirtualHardDisks) {
                $_.DataVirtualHardDisks.DataVirtualHardDisk | % {
                    $url = [uri]$_.MediaLink; $storageFileIndex[$url.Segments[-1]] = $storageFileIndex[$url.Segments[-1]] + (,$curr)
                }
            }
        }
    }

    #create database
    $DB = @{Database = $ht; Index = @{'IPAddress' = $ipAddrIndex; StorageAccount = $storageAcctIndex; DriveFile = $storageFileIndex}}
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
    $par = $PSBoundParameters
    if ($PSBoundParameters.IPAddress) {$Database.Index.IPAddress[$PSBoundParameters.IPAddress]}
    if ($PSBoundParameters.StorageAccount) {$Database.Index.StorageAccount[$PSBoundParameters.StorageAccount]}
    if ($PSBoundParameters.DriveFile) {$Database.Index.DriveFile[$PSBoundParameters.DriveFile]}
}
}


# $db = New-AzureObjectDB
# Get-AzureObjectFromDB -Database $DB -IPAddress 10.10.10.10
# Get-AzureObjectFromDB -Database $DB -drivefile filename.vhd