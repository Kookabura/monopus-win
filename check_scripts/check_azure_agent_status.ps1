[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string]$organization_name,
	[Parameter(Mandatory=$true)][string]$pass
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$names_offline_agents = ""
$list_offline_agents = ""
$count_agents = 0
$count_offline_agents = 0

$authenication = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pass)")) }
$url_pools = "https://dev.azure.com/$($organization_name)/_apis/distributedtask/pools?api-version=7.1-preview.1"

try
{
    $list_id_agents = (Invoke-RestMethod -Method GET -Uri $url_pools -Headers $authenication).value.id
	
	foreach ($id in $list_id_agents)
	{
        $count_agents++
		$url_agent = "https://dev.azure.com/$($organization_name)/_apis/distributedtask/pools/$id/agents?api-version=5.1"

		$agent = Invoke-RestMethod -Method GET -Uri $url_agent -Headers $authenication

		foreach ($a in $agent.value)
		{
			if ($a.status -eq "offline") #"online" "offline"
			{
                $s = $a.name
                $names_offline_agents += $s.ToString()
                $count_offline_agents++
			}
		}
	}

	if ($count_offline_agents -gt 0)
	{
		$state = 2
	}
	
	$list_offline_agents = [string]::Join(', ', $names_offline_agents)
}
catch
{
    Write-Host $_ -ForegroundColor Red
    $state = 3
}

$output = "check_azure_agent_status.$($states_text[$state])::offline_agents==$list_offline_agents | count_agents=$count_agents; count_offline_agents=$count_offline_agents;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state