[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)][string]$SqlServer,
	[Parameter(Mandatory=$true)][string]$SqlDatabase,
	[Parameter(Mandatory=$true)][string]$SqlTable,
	[Parameter(Mandatory=$true)][string]$SqlSearchParameter,
	[Parameter()][int32]$C = 0
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'critical', 'unknown')
$state_colors = @('Green', 'Red', 'DarkGray')
$state = 2

$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
$SqlConnection.ConnectionString = "Server=$SqlServer; Database=$SqlDatabase; Integrated Security=True"

try
{
	$SqlConnection.Open()
	$SqlCmd = $SqlConnection.CreateCommand()
	$SqlCmd.CommandText = "SELECT Count(*) FROM [$SqlDatabase].[dbo].[$SqlTable] WHERE $SqlSearchParameter = 0 and CONVERT (date, ImportDate) like CONVERT (date, SYSDATETIME())"
	#$SqlCmd.CommandText = "SELECT Count(*) FROM [$SqlDatabase].[dbo].[$SqlTable] WHERE $SqlSearchParameter = 0 and CONVERT (date, ImportDate) like CONVERT (date, '2022-01-15')"
	$objReader = $SqlCmd.ExecuteReader()

	while ($objReader.read())
	{
		$n = $objReader.GetValue(0)
	  	if ($n -gt $C)
		{
			$state = 1
		}
		else
		{
			$state = 0
		}
	}

	$objReader.close()
	$SqlConnection.Close()
}
catch
{
	Write-Host $_ -ForegroundColor Red
	$state = 2
}

$output = "find_sql_data.$($states_text[$state])::counted==$n | counted=$n;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state
