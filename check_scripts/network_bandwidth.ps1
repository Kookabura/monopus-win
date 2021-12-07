[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
   [string]$InterfaceName,
  [Parameter()]
   [int32]$W = 90,
  [Parameter()]
   [int32]$C = 95,
  [Parameter()]
    $config = $global:config
)

$states_text = @('ok', 'war', 'critical')
$state = 0

[Reflection.Assembly]::LoadWithPartialName("System.Web") | Out-Null
$int_hash = [System.Web.Security.FormsAuthentication]::HashPasswordForStoringInConfigFile($InterfaceName, "MD5")
$tmp = (Split-Path $PSCommandPath -Parent) + "/tmp/network_bandwidth_$int_hash.xml"
$first = $false
$average = -1

if (!(Test-Path (Split-Path $tmp -Parent))) {
    mkdir -Path (Split-Path $tmp -Parent) | Out-Null
}

if (Test-Path $tmp) {
    $indices = Import-Clixml $tmp
} else {
    $indices = @{}
}

if ($indices["net_$int_hash"] -ne $null -and (Get-Date) -lt (ls $tmp).LastWriteTime.AddMinutes(60)) {
    $first = $true
}

if (!$first) {
    
    $sample = [wmi]"Win32_PerfRawData_Tcpip_NetworkInterface.Name='$InterfaceName'"
    $indices = @{"net_$int_hash" = @{
            'BytesReceivedPersec' = $sample.BytesSentPersec
            'BytesSentPersec' = $sample.BytesSentPersec
            'timestamp' = [DateTimeOffset]::Now.ToUnixTimeSeconds()
        }
    }
    $output = "first==1"
} else {

    $sample = [wmi]"Win32_PerfRawData_Tcpip_NetworkInterface.Name='$InterfaceName'"
    $now = [DateTimeOffset]::Now.ToUnixTimeSeconds()
    $average_MbReceivedPersec = [math]::Round(($sample.BytesReceivedPersec - $indices["net_$int_hash"]['BytesReceivedPersec']) / ($now - $indices["net_$int_hash"]['timestamp']) / 125000, 4)
    $average_MbSentPersec = [math]::Round(($sample.BytesSentPersec - $indices["net_$int_hash"]['BytesSentPersec']) / ($now - $indices["net_$int_hash"]['timestamp']) / 125000, 4)
    $indices["net_$int_hash"]['BytesReceivedPersec'] = $sample.BytesReceivedPersec
    $indices["net_$int_hash"]['BytesSentPersec'] = $sample.BytesSentPersec
    $indices["net_$int_hash"]['timestamp'] = $now
    $output = "MbReceivedPersec==$($average_MbReceivedPersec)__MbSentPersec==$($average_MbSentPersec) | mbreceivedpersec=$average_MbReceivedPersec;$w;$c;0; mbsentpersec=$average_MbSentPersec;$w;$c;0;"
}

if ($average -ge $w -and $average -lt $c) {
    $state = 1
} elseif ($average -ge $c) {
    $state = 2
}


$indices | Export-Clixml $tmp
$output = "network_bandwidth_$($states_text[$state])::$output"
Write-Output $output
exit $state