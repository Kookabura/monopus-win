Import-Module "Microsoft.Powershell.Management"
Import-Module "International"
Import-Module "NetSecurity"

$start_time_event_search = (Get-Date).AddMinutes(-5)
$current_locale=(Get-WinSystemLocale).Name
$time_span=(New-TimeSpan -Start $start_time_event_search -End (get-date)).Minutes
$RDP_port=38178
$ip_address_list=@()

if ($current_locale -eq 'ru-RU') {
 $match_pattern='Тип входа'
} else {
 $match_pattern='Logon type'
}

$match_pattern+=':\s+(3)\s'
if (!(Get-NetFirewallRule | ? DisplayName -eq "BlockRDPBruteForce")) {
 New-NetFirewallRule -DisplayName "BlockRDPBruteForce" –RemoteAddress 1.1.1.1 -Direction Inbound –LocalPort $RDP_port -Action Block
}
$bad_RDP_logons = Get-EventLog -LogName 'Security' -After $start_time_event_search -InstanceId 4625 | `
 ? {$_.Message -match $match_pattern} | select @{n='IpAddress';e={$_.ReplacementStrings[-2]} }
$get_ip = $bad_RDP_logons | group -property IpAddress | ? {$_.Count -gt 5} | Select -property Name
foreach ($ip in (Get-NetFirewallRule -DisplayName "BlockRDPBruteForce" | Get-NetFirewallAddressFilter).RemoteAddress) {$ip_address_list+=$ip}
foreach ($ip in $get_ip.Name) { 
 foreach ($exist_ip in $ip_address_list) {
  if ($exist_ip -eq $ip) {
    $this_ip_exist=$true
    break
  }
 }
 if (!($this_ip_exist)) {$ip_address_list+=$ip}
 $this_ip_exist=$false
 $log_body='IP ' + $ip + ' заблокирован за ' + ($bad_RDP_logons | ? {$_.IpAddress -eq $ip}).Count + " попыток входа в систему за $time_span минут"
 Write-EventLog -LogName 'System' -Source 'System' -Message $log_body -EventId 666 -EntryType Warning
}
Set-NetFirewallRule -DisplayName "BlockRDPBruteForce" -RemoteAddress $ip_address_list
#(Get-NetFirewallRule -DisplayName "BlockRDPBruteForce" | Get-NetFirewallAddressFilter).RemoteAddress | sort