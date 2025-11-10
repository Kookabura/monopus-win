[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$url
)
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$state = 3
$statusCode = 0

try {
    $startTime = Get-Date
    $response = Invoke-WebRequest -Uri $url
    $endTime = Get-Date
    $elapsedTime = $endTime - $startTime
    $respTime = [math]::Round($elapsedTime.TotalSeconds, 3)

    $statusCode = $response.StatusCode

    $sizeInBytes = $response.RawContentLength
    $sizeInMB = [math]::Round($sizeInBytes / 1MB, 4)

    if ($statusCode -eq 200) {
        Write-Verbose "Response is ok"
        $state = 0
    } else {
        Write-Verbose "Response is not ok $statusCode"
        $state = 2
    }

    $output = "check_website_win.$($states_text[$state])::time==$($respTime)__size==$($sizeInMB) | time=$($respTime);;;; size=$($sizeInMB);;;;"
} catch {
    $state = 3
    $output = "check_website_win.$($states_text[$state])::error==$($_) | time=0;;;; size=0;;;;"
    Write-Verbose "Response error $_"
}


Write-Output $output
exit $state
