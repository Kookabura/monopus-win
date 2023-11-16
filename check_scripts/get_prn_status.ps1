[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 2,
  [Parameter()]
   [int32]$C = 4
)

$states_text = @('ok', 'war', 'cri')
$state = 0
$params = @()
$output = ''
$perfdata = ''

if ($prnHanged = Get-Printer | Get-PrintJob  | ? {$_.submittedtime -lt (get-date).adddays(-$w)} | Group-Object printername) {
    $state = 1
    $perfdata += "hanged=$($prnHanged.count);0;0;0;0; "
    $params += "hanged==$($prnHanged.name -join ',')"
}


if ($prnErrors = Get-Printer | Get-PrintJob  | ? {$_.jobstatus -match 'error'} | Group-Object printername) {
    $state = 1
    $perfdata += "errors=$($prnErrors.count);0;0;0;0; "
    $params += "errors==$($prnErrors.name -join ',')"
}



$output = "get_prn_status_$($states_text[$state])::$($params -join '__') | $perfdata"
Write-Output $output
exit $state

