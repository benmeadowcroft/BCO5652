<#
.SYNOPSIS
Add a VR replicated VM to a PG. For illustrative purposes only!
.DESCRIPTION

.PARAMETER SrmServer
The domain name of the protected site SRM server to connect to
.PARAMETER UserName
.PARAMETER Password
.PARAMETER RemoteUserName
.PARAMETER RemotePassword
.PARAMETER VmId
The id of the VM to add to the VR protection group. E.g. 'vm-108'

.EXAMPLE

.LINK
https://github.com/benmeadowcroft/BCO5652
#>

param (
    [string] $SrmServer = 'localhost',
    [string] $UserName = 'Administrator',
    [string] $Password = 'VMware1!',
    [string] $RemoteUserName = 'Administrator',
    [string] $RemotePassword = 'VMware1!',
    [string] $ProtectionGroupName = 'WebServers',
    [Parameter(Mandatory=$true)][string] $VmId
)

[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true} # ignore untrusted SSL certificate
Write-Host "Connecting to SRM"
$webSvc = New-WebServiceProxy ("https://" + $SrmServer + ":8095/srm-Service?wsdl") -Namespace SRM
$srm = New-Object SRM.SrmService
$srm.Url = "https://" + $SrmServer + ":9007"
$srm.Timeout = 600000
$srm.CookieContainer = New-Object System.Net.CookieContainer

$srmSvcRef = New-Object SRM.ManagedObjectReference
$srmSvcRef.Type = "SrmServiceInstance"
$srmSvcRef.Value = $srmSvcRef.Type

$srmSvcContent = $srm.RetrieveContent($srmSvcRef)

Write-Host "Log in to SRM"
$srm.SrmLoginSites($srmSvcRef, $UserName, $Password, $RemoteUserName, $RemotePassword, $null)

$srmObject = New-Object System.Object
$srmObject | Add-Member -Type NoteProperty -value $SrmServer -Name SRMServer
$srmObject | Add-Member -Type NoteProperty -value $srm -Name SRMService
$srmObject | Add-Member -Type NoteProperty -value $srmSvcContent -Name SRMContent

$targetPG = New-Object System.Object

#Get Information about the ProtectionGroups and combine them
ForEach ($protectionGroup in $SrmObject.SRMService.ListProtectionGroups($SrmObject.SRMContent.Protection)) {
  
    Write-Host "Fetching ProtectionGroupInfo"
    $protectionGroupInfo = $SrmObject.SRMService.GetInfo($protectionGroup)
    If ($protectionGroupInfo.Name -eq $ProtectionGroupName) {
        $targetPG | Add-Member -Type NoteProperty -value $protectionGroup -Name ManagedObject
        $targetPG | Add-Member -Type NoteProperty -value $protectionGroupInfo -Name Info
    }
}

Write-Host 'PG is ' $targetPG.Info.Name

# create protection specification

$vmref = New-Object SRM.ManagedObjectReference
$vmref.type = 'VirtualMachine'
$vmref.Value = $VmId
$vmspec = New-Object SRM.SrmProtectionGroupVmProtectionSpec
$vmspec.vm = $vmref

# Associate VM with PG
Write-Host "Associating VM '$VmId' with PG"
$srmObject.SRMService.AssociateVms($targetPG.ManagedObject, @($vmref))

# Configure Protection
$task = $srmObject.SRMService.ProtectVms($targetPG.ManagedObject, $vmspec)

# Wait for protection task to complete
while(!($srmObject.SRMService.IsComplete($task))) {
    Write-Host 'Waiting for protection task to complete...'
    Start-Sleep -Seconds 1
}

Write-Host "Log out of SRM"
$srm.SrmLogoutLocale($srmSvcRef)
