[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string]$SqlServer
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$list_db = @()
$nanes_db = ""
$n = 0

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=$SqlServer; Integrated Security=True"

try
{
	$SqlConnection.Open()
	$SqlCmd = $SqlConnection.CreateCommand()
	$SqlCmd.CommandText = "EXEC sp_helpdb"
	$objReader = $SqlCmd.ExecuteReader()

	while ($objReader.read())
	{
		$nane_db = $objReader.GetValue(0)
		$status_db = $objReader.GetValue(5)[7..12] -join $null
		if (!($status_db -like "ONLINE"))
		{
			$list_db += $nane_db
			$n++
			$state = 2
		}
	}
	$nanes_db = [string]::Join(", ", $list_db)
	
	$objReader.close()
	$SqlConnection.Close()
}
catch
{
	Write-Host $_ -ForegroundColor Red
	$state = 3
}

$output = "find_sql_data.$($states_text[$state])::list_db==$nanes_db | counted=$n;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state