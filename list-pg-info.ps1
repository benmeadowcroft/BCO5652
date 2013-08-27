<#
.SYNOPSIS
List VMs in a Protection Group
.DESCRIPTION

.PARAMETER SrmServer
The domain name of the protected site SRM server to connect to
.PARAMETER UserName

.PARAMETER Password

.PARAMETER VmName
The id of the VM to add to the VR protection group. E.g. 'vm-108'

.EXAMPLE

.LINK
https://github.com/benmeadowcroft/BCO5652
#>

param (
    [string] $SrmServer = 'localhost',
    [string] $UserName = 'Administrator',
    [string] $Password = 'VMware1!'
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
$srm.SrmLoginLocale($srmSvcRef, $UserName, $Password, $null)

$srmObject = New-Object System.Object
$srmObject | Add-Member -Type NoteProperty -value $SrmServer -Name SRMServer
$srmObject | Add-Member -Type NoteProperty -value $srm -Name SRMService
$srmObject | Add-Member -Type NoteProperty -value $srmSvcContent -Name SRMContent

$protectionGroupList = @();

#Get Information about the ProtectionGroups and combine them
ForEach ($protectionGroup in $SrmObject.SRMService.ListProtectionGroups($SrmObject.SRMContent.Protection)) {
  
    Write-Host "Fetching ProtectionGroupInfo"
    $protectionGroupInfo = $SrmObject.SRMService.GetInfo($protectionGroup)
  
    Write-Host "Fetching VMs for ProtectionGroup"
    $protectedVms = $SrmObject.SRMService.listProtectedVms($protectionGroup) 
    $customProtectionGroupInfo = New-Object System.Object
    $customProtectionGroupInfo | Add-Member -Name ProtectionGroupMoRef -Value $protectionGroup -MemberType NoteProperty # -PassThru
    $customProtectionGroupInfo | Add-Member -Name ProtectionGroupInfo -Value $protectionGroupInfo -MemberType NoteProperty # -PassThru
    $customProtectionGroupInfo | Add-Member -Name ProtectedVms -Value $protectedVms -MemberType NoteProperty # -PassThru

    $protectionGroupList += $customProtectionGroupInfo
}

Write-Host "\nProtection Groups:"
ForEach ($pg in $protectionGroupList)  {
    Write-Host " | ProtectionGroup: " $pg.protectionGroupInfo.name
    Write-Host " +-- Description: " $pg.protectionGroupInfo.description
    Write-Host " +-- Replication Type: " $pg.protectionGroupInfo.type
    Write-Host " +-+ Virtual Machines:"
    ForEach ($vm in $pg.protectedVms) {
        Write-Host "   | VM MoId: " $vm.vm.value
        Write-Host "   +-- Protection State: " $vm.state
        Write-Host "   +-- Peer State: " $vm.peerState
        Write-Host "   +-- Needs Configuration: " $vm.needsConfiguration
        Write-Host "   |"
    }
}

Write-Host "Log out of SRM"
$srm.SrmLogoutLocale($srmSvcRef);
