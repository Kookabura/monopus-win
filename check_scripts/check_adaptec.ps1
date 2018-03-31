# Check Adaptec RIAD controller for SMART issues

[CmdletBinding()]
Param(

)

$working_dir = Split-Path -path $MyInvocation.MyCommand.Path -Parent
$t = $host.ui.RawUI.ForegroundColor
$state = 0
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$output = ''

if (Test-Path "$working_dir\vendor\adaptec\arcconf.exe") {
    try {
        [array]$data=Invoke-Expression -Command "& '$working_dir\vendor\adaptec\arcconf.exe' GETVERSION" -ErrorAction SilentlyContinue
        [int32]$controllers = ($data[0] -split ' ')[-1]
    } catch {
        $state = 3
    }
    $bad_disks = @()


    for ($i=1; $i -le $controllers; $i++) {
        [string]$data=Invoke-Expression -Command "& '$working_dir\vendor\adaptec\arcconf.exe' GETSMARTSTATS $i"
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
} else {
    $state = 3
}

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output "check_adaptec_$($states_text[$state])::$output"
$host.ui.RawUI.ForegroundColor = $t
exit $state