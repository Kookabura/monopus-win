[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 90,
  [Parameter()]
   [int32]$C = 95
)

$states_text = @('ok', 'war', 'cri')
$state = 0

$os = gwmi Win32_OperatingSystem
$mem_counter = gwmi Win32_PerfRawData_PerfOS_Memory

$mem_total_m = [int]($os.TotalVisibleMemorySize/1Kb)
$mem_total_b = $os.TotalVisibleMemorySize*1Kb
$mem_free_m = $mem_counter.AvailableMBytes
$mem_free_b = $mem_counter.AvailableBytes
$mem_cache_m = [int]($mem_counter.CacheBytes/1Mb)
$mem_cache_b = $mem_counter.CacheBytes
$mem_used_m = $mem_total_m - $mem_free_m
$mem_used_b = $mem_total_b - $mem_free_b
$memUsedPrc = [int]($mem_used_b/$mem_total_b*100)

if ($memUsedPrc -ge $w -and $memUsedPrc -lt $c) {
    $state = 1
} elseif ($memUsedPrc -ge $c) {
    $state = 2
}

$output = "local_memory_$($states_text[$state])::total==$($mem_total_m)__used_unt==$($mem_used_m)__user_pct==$($memUsedPrc) | TOTAL=$mem_total_b;;;; USED=$mem_used_b;;;; CACHE=$mem_cache_b;;;;"
Write-Output $output
exit $state