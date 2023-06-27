[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$path,
  [Parameter(Mandatory=$true)][string]$C
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state = 0
$output = $null
$count = 0

Get-ChildItem $path | Where-Object {
    if (!$_.PSIsContainer) {
        $created = $_.CreationTime
        $age = (Get-Date) - $created

        if ($age.TotalHours -gt $C) {
            $count++
        }
    }
}


if ($count -gt 0) {
    $state = 2
}

$output = "check_files_in_folder.$($states_text[$state]) | files=$count"
Write-Output $output
exit $state


