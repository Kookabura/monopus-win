[CmdletBinding()]
param(
    [Parameter(ValueFromPipeline)]
    [AllowEmptyString()]
    [string]$country_code
)

$states_text = @('ok', 'warn')
$state = 1

if ([string]::IsNullOrEmpty($country_code)) {
    $status = 'ArgMiss'
} else {
		$status = 'ArgOk'
    $code = (Invoke-WebRequest http://ifconfig.io/country_code).Content
    if ($code.Trim() -eq $country_code.Trim()) {
			$state = 0
		}
}

$output = "location.$($states_text[$state]).$status"

Write-Output $output
exit $state


