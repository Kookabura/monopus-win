[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)][string]$endpoint,
  [Parameter()][int32]$W = 10,
  [Parameter()][int32]$C = 5
)

$states_text = @('ok', 'war', 'cri')
$state = 0
$Path = "C:\ProgramData\Veeam\Endpoint\$endpoint\Job.$endpoint.Backup.log"
$logLines = Get-Content $Path

$line = $logLines | Where-Object { $_ -match "Quota \(mb\):(\d+), FreeSpace \(mb\):(\d+)" } | Select-Object -Last 1

if ($line -ne $null) {
    $matches = $null
    if ($line -match "Quota \(mb\):(\d+), FreeSpace \(mb\):(\d+)") {
        $quota = $matches[1] / 1000
        $freeSpace = $matches[2] / 1000
        $used = [math]::Round(($quota - $freeSpace), 2)
        $usedResult = [math]::Round(($used / $quota) * 100, 2)
        $result = [math]::Round(($freeSpace / $quota) * 100, 2)

        $regex = "\[(\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2})\]"
        $matchData = [regex]::Match($line, $regex)
        $date = $matchData.Groups[1].Value
        
        Write-Verbose "Date: $date"
        Write-Verbose "Quota: $quota GB"
        Write-Verbose "FreeSpace: $freeSpace GB"
        Write-Verbose "FreeSpace: $result%"

        
        if ($result -le $C) {
            $state = 2
        } elseif ($result -le $W) {
            $state = 1
        }
    }
}

$output = "check_veeam_space.$($states_text[$state])::freeSpace==$($freeSpace)__quota==$($quota)__date==$($date)__result==$($result)__usedResult==$($usedResult)__used==$($used) | QUOTA=$($quota);;;; USED=$($used);;;;"
#$output = "check_veeam_space.$($states_text[$state])::result==$($result)__date=$($date) | RESULT=$($result);;;;"
Write-Output $output
exit $state

