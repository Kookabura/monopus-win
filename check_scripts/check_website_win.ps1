[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)][string]$url
)
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')

$state = 3
$statusCode = 0

try {
    $response = Invoke-WebRequest -Uri $url
    $statusCode = $response.StatusCode

    if ($statusCode -eq 200) {
        Write-Verbose "Response is ok"
        $state = 0
    } else {
        Write-Verbose "Response is not ok $statusCode"
        $state = 2
    }
} catch {
    Write-Verbose "Response error"
}

$output = "check_website.$($states_text[$state]) | status=$statusCode"
Write-Output $output
exit $state

