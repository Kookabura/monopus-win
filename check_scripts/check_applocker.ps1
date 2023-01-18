[CmdletBinding()]
$t = $host.ui.RawUI.ForegroundColor
$errmsg = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$errcount = 0
$detailed_status = ""
$assembly_status = @()


try
{
	$svc = Get-Service AppIDSvc
	
	if($svc.Status -ne "Running")
	{
		$errcount++
		$assembly_status += "svc_not_started"
	}
	if($svc.StartType -ne "Automatic")
	{
		$errcount++
		$assembly_status += "svc_start_status"
	}
	
	$rulecollections = (Get-AppLockerPolicy -Effective).rulecollections | select -Property *
	
	foreach ($rule in $rulecollections)
	{
		if (($rule.RuleCollectionType -ne "Dll") -and ($rule.RuleCollectionType -ne "Appx"))
		{
			if ($rule.EnforcementMode -ne "Enabled")
			{
				$errcount++
				$assembly_status += "rules_off"
			}
			if ($rule.Empty)
			{
				$errcount++
				$assembly_status += "rules_empty"
			}
		}
	}
	
	if ($errcount -gt 0)
	{
		$state = 2
		
		foreach ($s in $assembly_status)
		{
			if (!($detailed_status -like "*$s*"))
			{
				$detailed_status = [string]::Join(".",$detailed_status,$s)
			}
		}
	}
}
catch
{ 
	Write-Host $_ -ForegroundColor Red
	$state = 3
}
	
$output = "check_applocker.$($errmsg[$state])$detailed_status | errcount=$errcount;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
