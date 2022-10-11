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
[string[]]$names_offline_agents = ""
$list_offline_agents = ""
$pool_name = ""
$count_agents = 0
$count_offline_agents = 0

$authenication = @{Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($pass)")) }
$url_pools = "https://dev.azure.com/$($organization_name)/_apis/distributedtask/pools?api-version=7.1-preview.1"

try
{
    $pool_agents_data = (Invoke-RestMethod -Method GET -Uri $url_pools -Headers $authenication).value
	
	foreach ($pool_agent_data in $pool_agents_data)
	{
        if (!($pool_agent_data.name -like "Hosted*"))
        {
            $pool_name = $pool_agent_data.name

		    $url_agent = "https://dev.azure.com/$($organization_name)/_apis/distributedtask/pools/$($pool_agent_data.id)/agents?api-version=5.1"
        

		    $agent_in_pool = Invoke-RestMethod -Method GET -Uri $url_agent -Headers $authenication

		    foreach ($agent in $agent_in_pool.value)
		    {
                $count_agents++

			    if ($agent.status -like "offline" -and !($agent.provisioningState -eq "Deallocated")) #"online" "offline"
			    {
                    $summary_name = $agent.name + " в группе " + $pool_name
                    $names_offline_agents += $summary_name.ToString()
                    $count_offline_agents++
			    }
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
