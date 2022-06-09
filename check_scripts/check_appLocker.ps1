[CmdletBinding()]
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$err = ""
$errmsg = "ok"

try {
	$applocker = Get-AppLockerPolicy -Effective
	
	if($applocker.RuleCollections.count -eq 0)
	{
		$state = 1
		$err += "_rules_empty"
	}

	$svc = Get-Service AppIDSvc
	
	if($svc.StartType -ne 'Automatic')
	{
		$state = 1
		$err += "_svc_start_type"
	}
	
	if($svc.Status -ne 'Running')
	{
		$state = 2
		$err += "_svc_no_runing"
	}
	
	if ($err -ne "") {$errmsg = "err" + $err}
}
catch
{ 
	Write-Host $_ -ForegroundColor Red
	$state = 3
}
	
$output = "check_status.$($states_text[$state])::condition==$errmsg | errlvl=$state;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
