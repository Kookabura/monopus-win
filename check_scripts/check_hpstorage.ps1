<#
.SYNOPSIS
    Check HP Storate Array health status.
.DESCRIPTION
    HP Smart Storage CLI should be installed in C:\Program Files\HP\hpssacli\bin\. Local administrator permissions are reqired.
# 
#>

[CmdletBinding()]
Param(
)

$working_dir = Split-Path -path $MyInvocation.MyCommand.Path -Parent
$t = $host.ui.RawUI.ForegroundColor
$state = 3
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$bad_controllers = @()
$bad_drives = @()
$output = ''

if (Test-path "C:\Program Files\HP\hpssacli\bin\hpssacli.exe") {
    (Invoke-Expression -Command "& 'C:\Program Files\HP\hpssacli\bin\hpssacli.exe' controller all show" | ? {$_ -ne ""}) -match "(?<=Slot\s)\d+" | Out-Null
    
    if ($matches) {
        $state = 0
        $controllers = $data.Controllers."Response Data".'Number of Controllers'        
        foreach ($slot in $matches.keys) {
            $drives = Invoke-Expression -Command "& 'C:\Program Files\HP\hpssacli\bin\hpssacli.exe' controller slot=$($matches.Item($slot)) physicaldrive all show"
            foreach ($drive in $drives) {
                if ($drive -match 'Failed') {
                    $drive -match "(?<=physicaldrive\s)\d.*\d(?=\s\()" | Out-Null
                    $matches.keys | % {$bad_drives += $matches.Item($_)}
                    $bad_controllers += $slot
                    $state = 2
                }
            }
        }

    }

    if ($bad_controllers.length) {
        $output = ("bad_controllers==" + ($bad_controllers -join ',') + "__bad_drives==" + ($bad_drives -join ','))
    }
}

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output "check_hpstorage_$($states_text[$state])::$output"
$host.ui.RawUI.ForegroundColor = $t
exit $state