[CmdletBinding()]
Param(
)
$output = $null
$perf = $null
$states_text = @('ok', 'warning', 'critical')
$state = 0

$Path = Test-Path -Path 'C:\Program Files\Java'
If ($Path -eq 'True')
    {
        $state = "2"
    }    

$output = "Path$($states_text[$state])::Events=='обнаружена Java x64' | Events='обнаружена Java x64';;;;;"
Write-Verbose $output
Write-Output $output
exit $state
