# Check MegaRaid controller health status
# MegaRAID Storage Manager should be installed in C:\Program Files (x86)\MegaRAID Storage Manager

[CmdletBinding()]
Param(

)

$t = $host.ui.RawUI.ForegroundColor
$state = 0
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$bad_controllers = @()
$output = ''

if (test-path "C:\Program Files (x86)\MegaRAID Storage Manager\StorCLI64.exe") {
    $data = (Invoke-Expression -Command "& 'C:\Program Files (x86)\MegaRAID Storage Manager\StorCLI64.exe' show J") -join "`n" | ConvertFrom-Json

    if ($data.Controllers."Command Status".Status -and $data.Controllers."Response Data".'Number of Controllers') {
        $controllers = $data.Controllers."Response Data".'Number of Controllers'
        for ($i=0; $i -lt $controllers; $i++) {
            if ($data.Controllers."Response Data".'System Overview'[$i].hlth -ne 'Opt') {
                $bad_controllers += $i+1
                $state = 2
            }
        }
    }

    if ($bad_controllers) {
        $output = ("bad_controllers==" + ($bad_controllers -join ','))
    }
} else {
    $state = 3
}

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output "check_lsimegaraid_$($states_text[$state])::$output"
$host.ui.RawUI.ForegroundColor = $t
exit $state