[CmdletBinding()]
Param
(
	[Parameter(Mandatory=$true)][string]$servername
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0
$list_db = @()
$bad_db
$n = 0
$count

try
{
	[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
	$s = New-Object ('Microsoft.SqlServer.Management.Smo.Server') "$servername"
	$dbs=$s.Databases
	$count = $dbs.Count
	foreach ($db in $dbs)
	{
		if (!($db.Status -like "*Normal*"))
		{
			$list_db += $db.Name + " - " + $db.Status
			$n++
			$state = 2
		}
	}

	$bad_db = [string]::Join(", ", $list_db)
}
catch
{
	Write-Host $_ -ForegroundColor Red
	$state = 3
}

$output = "check_db_status.$($states_text[$state])::bad_db==$bad_db | count_bad=$n;;; count_all=$count;;;"
$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state 
