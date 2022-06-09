[CmdletBinding()]
<#Param
(
	[Parameter()][string[]] 
	[Parameter()][int]
)#>

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'critical', 'unknown')
$state_colors = @('Green', 'Red', 'DarkGray')
$state = 0
$PasswordComplexity = "on"
$LockoutBadCount = "on"

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
						$LockoutBadCount = "off"
					}
				}
				if($policy -like "PasswordComplexity")
				{
					$value = $line.substring($line.IndexOf("=") + 1,$line.Length - ($line.IndexOf("=") + 1))
					
					if([int]$value -eq 0)
					{
						$state = 1
						Write-Host "No Strong Password Policy" -ForegroundColor Red
						$PasswordComplexity = "off"
					}
				}
			}
		}
		Remove-Item $file
	}
}
catch { 
	Write-Host $_ -ForegroundColor Red
	$state = 2
	$PasswordComplexity = "unknown"
	$LockoutBadCount = "unknown"
}
	
$output = "check_status.$($states_text[$state]) | PasswordComplexity=$($PasswordComplexity);;; | LockoutBadCount=$($LockoutBadCount);;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state