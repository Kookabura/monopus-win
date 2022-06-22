[CmdletBinding()]
$t = $host.ui.RawUI.ForegroundColor
$errmsg = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$errcount = 0
$errdetails = "Error: "

try
{
	$svc = Get-Service AppIDSvc
	
	if($svc.StartType -ne "Automatic")
	{
		$errcount++
		$errdetails += "Incorrect service start status. "
	}
	if($svc.Status -ne "Running")
	{
		$errcount++
		$errdetails += "Service not started. "
	}
	
	$rulecollections = (Get-AppLockerPolicy -Effective).rulecollections | select -Property *
	
	foreach ($rule in $rulecollections)
	{
		if ($rule.RuleCollectionType -ne "Dll")
		{
			if ($rule.EnforcementMode -ne "Enabled")
			{
				$errcount++
				$errdetails += "Rules for '" + $rule.RuleCollectionType + "' off. "
			}
			if ($rule.Empty)
			{
				$errcount++
				$errdetails += "Rules for '" + $rule.RuleCollectionType + "' are empty. "
			}
		}
	}
	
	if ($errcount -gt 0)
	{
		$state = 2
	}
	else {$errdetails = "All good."}
}
catch
{ 
	Write-Host $_ -ForegroundColor Red
	$state = 3
}
	
$output = "check_applocker.$($errmsg[$state])::errdetails==$errdetails | errcount=$errcount;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
