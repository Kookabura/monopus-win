[CmdletBinding()]
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'critical', 'unknown')
$state_colors = @('Green', 'Red', 'DarkGray')
$state = 0
$err = ""
$errmsg = "ok"

try
{
	$svc = Get-WindowsFeature RDS-RD-Server -ErrorAction Ignore
	if($svc -ne $null) {$rdp = $svc.Installed}
	
	if($rdp)
	{
		$temp = $env:TEMP
		$file = "$temp\pol.txt"
		$process = [diagnostics.process]::Start("secedit.exe", "/export /cfg $file /areas securitypolicy")
		$process.WaitForExit()
		$in = get-content $file
		
		foreach ($line in $in)
		{
			if ($line -like "*password*" -or $line -like "*lockout*" -and $line -notlike "machine\*" -and $line -notlike "require*" )
			{
				$policy = $line.substring(0,$line.IndexOf("=") - 1)
				
				if($policy -like "LockoutBadCount")
				{
					$value = $line.substring($line.IndexOf("=") + 1,$line.Length - ($line.IndexOf("=") + 1))
					
					if([int]$value -eq 0)
					{
						$state = 1
						Write-Host "No Lockout Policy" -ForegroundColor Red
						$err = "_lockout"
					}
				}
				
				if($policy -like "PasswordComplexity")
				{
					$value = $line.substring($line.IndexOf("=") + 1,$line.Length - ($line.IndexOf("=") + 1))
					
					if([int]$value -eq 0)
					{
						$state = 1
						Write-Host "No Strong Password Policy" -ForegroundColor Red
						$err = "_strong_password"
					}
				}
			}
		}
		Remove-Item $file
		if ($err -ne "") {$errmsg = "err" + $err}
	}
}
catch { 
	Write-Host $_ -ForegroundColor Red
	$state = 2
	$errmsg = "err"
}
	
$output = "check_policy_password.$errmsg | errlvl=$state;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
