# Check Adaptec RIAD controller for SMART issues

[CmdletBinding()]
Param(

)

$working_dir = Split-Path -path $MyInvocation.MyCommand.Path -Parent
[array]$data=Invoke-Expression -Command "$working_dir\vendor\adaptec\arcconf.exe GETVERSION"
[int32]$controllers = ($data[0] -split ' ')[-1]
$state = 0
$states_text = @('ok', 'warning', 'critical')
$bad_disks = @()
$output = ''

for ($i=1; $i -le $controllers; $i++) {
    [string]$data=Invoke-Expression -Command "$working_dir\vendor\adaptec\arcconf.exe GETSMARTSTATS $i"
    # Checking SATA disks status
    $data -match "<SmartStats.*</SmartStats>" | Out-Null
    $sata = [xml]$matches[0]
    foreach ($s in $sata.SmartStats.PhysicalDriveSmartStats) {
        if ($s.SMARTHealthStatus.Status -ne 'ok') {
            $bad_disks += "sata_$($s.id)"
        }
    }

    # Checking SAS disks status
    $data -match "<SASSmartStats.*</SASSmartStats>" | Out-Null
    $sas = [xml]$matches[0]
    foreach ($s in $sas.SASSmartStats.PhysicalDriveSmartStats) {
        if ($s.SMARTHealthStatus.Status -ne 'ok') {
            $bad_disks += "sas_$($s.id)"
        }
    }
}

if ($bad_disks) {
    $state = 2
    $output = ("bad_disks==" + ($bad_disks -join ','))
}

Write-Output "check_adaptec_$($states_text[$state])::$output"
exit $state