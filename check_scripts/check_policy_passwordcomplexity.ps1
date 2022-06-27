[CmdletBinding()]
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$errcount = 0
$detailed_status = ""
$assembly_status = @()

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
						Write-Verbose "No Lockout Policy" -ForegroundColor Red
						$errcount++
						$assembly_status += "lockout"
					}
				}
				
				if($policy -like "PasswordComplexity")
				{
					$value = $line.substring($line.IndexOf("=") + 1,$line.Length - ($line.IndexOf("=") + 1))
					
					if([int]$value -eq 0)
					{
						Write-Verbose "No Strong Password Policy" -ForegroundColor Red
						$errcount++
						$assembly_status += "strong_password"
					}
				}
			}
		}
		Remove-Item $file
		
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
}
catch
{ 
	Write-Host $_ -ForegroundColor Red
	$state = 3
}
	
$output = "check_policy_password.$($states_text[$state])$detailed_status | errcount=$errcount;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
