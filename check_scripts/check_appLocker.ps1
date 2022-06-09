[CmdletBinding()]
Param
(
	[Parameter()][string[]] $adminMembers = @("$env:computername\CloudAdmin"),
	[Parameter()][int] $updateDays = 5
)
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'critical', 'unknown')
$state_colors = @('Green', 'Red', 'DarkGray')
$state = 0

	# включен AppLocker
	try {
		$applocker = Get-AppLockerPolicy -Effective
		if($applocker.RuleCollections.count -eq 0) {$state = 1}
		$svc = Get-Service AppIDSvc
		if($svc.Status -ne 'Running' -or $svc.StartType -ne 'Automatic') {$state = 1}
	}
	catch
	{ 
		Write-Host $_ -ForegroundColor Red
		$state = 2
	}
	
$output = "check_status.$($states_text[$state]) | Status=$($svc.Status);;; | RuleCollections=$($applocker.RuleCollections.count);;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state