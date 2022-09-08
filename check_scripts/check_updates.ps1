[CmdletBinding()]
Param
(
	[Parameter()][int32]$W = 30,
	[Parameter()][int32]$C = 10
)

if ($host.UI.RawUI.WindowTitle -match 'Powershell') {
    $t = $host.ui.RawUI.ForegroundColor
}
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 3
$err = ""

# latest update installation date and number of available updates
try
{
	if ((Get-Service 'wuauserv').Status -like "Running")
	{
		if((Get-Service 'WSearch').Status -like "Running")
		{
			$Session = New-Object -ComObject Microsoft.Update.Session
			$Searcher = $Session.CreateUpdateSearcher()
			$SearchResult = $Searcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0")
			$availableUpdates = $($SearchResult.updates.count)
			$HistoryCount = $Searcher.GetTotalHistoryCount()
			$lastUpdate = $Searcher.QueryHistory(0,$HistoryCount) | ForEach-Object -Process {
				New-Object -TypeName PSObject -Property @{
					InstalledOn = Get-Date -Date $_.Date;
				}
			} | Sort-Object -Descending -Property InstalledOn | select -first 1

			$daysSinceLastUpdate = (New-TimeSpan -Start $lastUpdate.InstalledOn -End (Get-Date)).Days
			
			if ($daysSinceLastUpdate -gt $W -and $availableUpdates)
			{
				$state = 2
			}
			else
			{
				$state = 0
			}
		}
		else
		{
			$err = "Windows Search"
			$state = 1
		}
	}
	else
	{
		$err = "Windows Update"
		$state = 1
	}
}
catch
{ 
    Write-Host $_ -ForegroundColor Red
    $state = 3  
}

$output = "check_updates.$($states_text[$state])::availableupdates==$($availableUpdates)__dayssincelastupdate==$($daysSinceLastUpdate)__err==$err | availableupdates=$availableupdates;;; dayssincelastupdate=$daysSinceLastUpdate;;;"

if ($host.UI.RawUI.WindowTitle -match 'Powershell')
{
    $host.ui.RawUI.ForegroundColor = $($state_colors[$state])
}

Write-Output $output
if ($host.UI.RawUI.WindowTitle -match 'Powershell')
{
    $host.ui.RawUI.ForegroundColor = $t
}

exit $state
