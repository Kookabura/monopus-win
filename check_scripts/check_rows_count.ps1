[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true)][string]$SqlServer,
	[Parameter(Mandatory=$true)][string]$SqlDatabase,
	[Parameter(Mandatory=$true)][string]$CommandText,
	[Parameter()][int32]$W = $null,
	[Parameter()][int32]$C
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warn', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

try
{
	$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
	$SqlConnection.ConnectionString = "Server=$SqlServer; Database=$SqlDatabase; Integrated Security=True"
    $SqlConnection.Open()
	$SqlCmd = $SqlConnection.CreateCommand()
	$SqlCmd.CommandText = $CommandText
	$objReader = $SqlCmd.ExecuteReader()

	while ($objReader.read())
	{
		$n = $objReader.GetValue(0)
		
	  	if ($n -gt $C)
		{
			$state = 2
		}
		elseif ($W -and $n -gt $W)
		{
			$state = 1
		}
	}

	$objReader.close()
	$SqlConnection.Close()
}
catch
{
	Write-Host $_ -ForegroundColor Red
	$state = 3
}

$output = "check_rows_count.$($states_text[$state])::counted==$n | counted=$n;;;"

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state


