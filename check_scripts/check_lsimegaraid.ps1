<#
.SYNOPSIS
    Check MegaRaid controller health status.
.DESCRIPTION
    MegaRAID Storage Manager should be installed in C:\Program Files (x86)\MegaRAID Storage Manager. It works through StorCli by default.
    You can use MegaCli for legacy devices.
.PARAMETER Legacy
    If default mode isn't working try set this to $true
# 
#>

[CmdletBinding()]
Param(
    [Parameter()]
    [boolean]$Legacy = $false
)

$working_dir = Split-Path -path $MyInvocation.MyCommand.Path -Parent
$t = $host.ui.RawUI.ForegroundColor
$state = 0
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$bad_controllers = @()
$output = ''

if ($Legacy) {
    $data = Invoke-Expression -Command "& '$working_dir\vendor\lsimegaraid\MegaCli.exe' -LDInfo -LAll -aAll" | ? {$_ -match "State\s*:"} | ? {$_ -notmatch "Optimal"}
    if ($data) {
        $state = 2
    }
} elseif (Test-path "C:\Program Files (x86)\MegaRAID Storage Manager\StorCLI64.exe") {
    $data = (Invoke-Expression -Command "& 'C:\Program Files (x86)\MegaRAID Storage Manager\StorCLI64.exe' show J") -join "`n" | ConvertFrom-Json

    if ($data.Controllers."Command Status".Status -and $data.Controllers."Response Data".'Number of Controllers') {
        $controllers = $data.Controllers."Response Data".'Number of Controllers'
        for ($i=0; $i -lt $controllers; $i++) {
            if ($data.Controllers."Response Data".'System Overview'[$i].hlth -ne 'Opt') {
                $bad_controllers += $i+1
                $state = 2
            }
        }
    } else {
        $state = 3
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