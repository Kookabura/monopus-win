[CmdletBinding()]
Param
(
	[Parameter()][int32]$W = 30,
	[Parameter()][int32]$C = 180
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$err = ""

try
{
	if ((Get-Service 'wuauserv').starttype -ne "Disabled")
	{
        try
        {
            $Session = New-Object -ComObject Microsoft.Update.Session
		    $Searcher = $Session.CreateUpdateSearcher()
		    $HistoryCount = $Searcher.GetTotalHistoryCount()
		    $lastUpdate = $Searcher.QueryHistory(0,$HistoryCount) | ForEach-Object -Process {
						    New-Object -TypeName PSObject -Property @{
							    InstalledOn = Get-Date -Date $_.Date;
						    }
					    } | Sort-Object -Descending -Property InstalledOn | select -first 1
		    $daysSinceLastUpdate = (New-TimeSpan -Start $lastUpdate.InstalledOn -End (Get-Date)).Days
		}
		catch
		{ 
			try
		    {
			    $lastUpdate = Get-Date ((Get-WmiObject -Class win32_quickfixengineering | Sort-Object -Descending -Property InstalledOn | select -first 1).InstalledOn).Date
			    $daysSinceLastUpdate = (New-TimeSpan -Start $lastUpdate -End (Get-Date)).Days

			    if ($daysSinceLastUpdate -gt $W -and $daysSinceLastUpdate -lt $C)
			    {
				    $state = 1
			    }
			    else
			    {
				    if ($daysSinceLastUpdate -ge $C)
				    {
					    $state = 2
				    }
			    }
		    }
		    catch
		    { 
		    	Write-Host $_ -ForegroundColor Red
                	$state = 3
		    }
		}

		if ((Get-Service 'wuauserv').Status -like "Running")
		{
			$SearchResult = $Searcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0")
			$availableUpdates = $($SearchResult.updates.count)

			if (($daysSinceLastUpdate -gt $W -and $daysSinceLastUpdate -lt $C) -and $availableUpdates)
			{
				$state = 1
			}
			else
			{
				if ($daysSinceLastUpdate -ge $C -and $availableUpdates)
				{
					$state = 2
				}
			}
		}
		else
		{
			$err = "Windows Update"
			$state = 1
		}
	}
	else
	{
		$err = "Windows Update"
		
		try
		{
			$lastUpdate = wmic qfe list | ForEach-Object -Process {
				# Here we find the substring with the date and then transform it to format MM-dd-yyyy    
                if ($_ -match '\d{1,2}\/\d{1,2}\/\d{4}') {
                    $s = $Matches[0]
                    $arr = $s -split '/'
                    if ($arr[0].Length -lt 2) {
                        $arr[0] = '0' + $arr[0]
                    }
                    if ($arr[1].Length -lt 2) {
                        $arr[1] = '0' + $arr[1]
                    }
                    $s = $arr -join '-'
                    New-Object -TypeName PSObject -Property @{
		                InstalledOn = [datetime]::ParseExact($s,'MM-dd-yyyy',$null);
	                }
                }
            } | Sort-Object -Descending -Property InstalledOn | select -first 1
			$daysSinceLastUpdate = (New-TimeSpan -Start $lastUpdate.InstalledOn -End (Get-Date)).Days
			
			if ($daysSinceLastUpdate -gt $W -and $daysSinceLastUpdate -lt $C)
			{
				$state = 1
			}
			else
			{
				if ($daysSinceLastUpdate -ge $C)
				{
					$state = 2
				}
			}
		}
		catch
		{ 
			Write-Host $_ -ForegroundColor Red 
            $state = 3
		}
	}
}
catch
{ 
    Write-Host $_ -ForegroundColor Red
    $state = 3  
}

$output = "check_updates.$($states_text[$state])::availableupdates==$($availableUpdates)__dayssincelastupdate==$($daysSinceLastUpdate)__err==$err | availableupdates=$availableupdates;;; dayssincelastupdate=$daysSinceLastUpdate;;;"
Write-Output $output
exit $state
