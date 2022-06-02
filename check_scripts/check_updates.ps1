[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 30,
  [Parameter()]
   [int32]$C = 10
)

if ($host.UI.RawUI.WindowTitle -match 'Powershell') {
    $t = $host.ui.RawUI.ForegroundColor
}
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 3

# latest update installation date and number of available updates
try {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $SearchResult = $UpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0")
    $availableUpdates = $($SearchResult.updates.count)
          
    $lastUpdate = (New-Object -com "Microsoft.Update.AutoUpdate").Results.LastInstallationSuccessDate
    $daysSinceLastUpdate = (New-TimeSpan –Start $lastUpdate –End (Get-Date)).Days
    
    if($daysSinceLastUpdate -gt $W -and $availableUpdates) {
        $state=2
    } else {
        $state=0
    }
}
catch { 
    Write-Host $_ -ForegroundColor Red
    $state = 3  
}

$output = "check_updates.$($states_text[$state])::availableupdates==$($availableUpdates)__dayssincelastupdate==$daysSinceLastUpdate | availableupdates=$availableupdates;;; dayssincelastupdate=$daysSinceLastUpdate;;;"

if ($host.UI.RawUI.WindowTitle -match 'Powershell') {
    $host.ui.RawUI.ForegroundColor = $($state_colors[$state])
}

Write-Output $output
if ($host.UI.RawUI.WindowTitle -match 'Powershell') {
    $host.ui.RawUI.ForegroundColor = $t
}

exit $state