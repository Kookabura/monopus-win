Import-Module "Microsoft.Powershell.Management"
Import-Module "International"
Import-Module "NetSecurity"


$start_time_event_search = (Get-Date).AddMinutes(-5)
$current_locale=(Get-WinSystemLocale).Name
$time_span=(New-TimeSpan -Start $start_time_event_search -End (get-date)).Minutes
$firewall_rule_name="BanIP"
$local_port=-1 #0 is mean all protocols, 1-65535 - block this TCP and UDP ports
$ip_address_list=@()


if ($current_locale -eq 'ru-RU') {
    $match_pattern='Тип входа'
} else {
    $match_pattern='Logon type'
}

$match_pattern+=':\s+(3)\s'

if ($local_port -eq -1) {
    $local_port=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\" -name PortNumber).PortNumber
    if (!($?)) {
        $local_port=3389 #if no value, than use default 3389 port
    }
}

# Getting bad logons attempts
$bad_RDP_logons = Get-EventLog -LogName 'Security' -After $start_time_event_search -InstanceId 4625 | ? {$_.Message -match $match_pattern} | select @{n='IpAddress';e={$_.ReplacementStrings[-2]} }
$get_ip = ($bad_RDP_logons | group -property IpAddress | ? {$_.Count -gt 5}).Name


# Getting currently blocked IP addresses
if (Get-NetFirewallRule -DisplayName $firewall_rule_name -ErrorAction SilentlyContinue) {
    foreach ($ip in (Get-NetFirewallRule -DisplayName $firewall_rule_name | Get-NetFirewallAddressFilter).RemoteAddress | select -Unique) {$ip_address_list+=$ip}
}
$new_ip_address_list = $ip_address_list


# Populate new IPs for blocking
foreach ($ip in $get_ip) { 
    
    if ($ip_address_list -notcontains $ip) {
     
        Write-Verbose "Adding $ip to RDP block list"
        $new_ip_address_list += $ip
        
        $log_body='IP ' + $ip + ' заблокирован за ' + ($bad_RDP_logons | ? {$_.IpAddress -eq $ip}).Count + " попыток входа в систему за $time_span минут"

        Write-EventLog -LogName 'System' -Source 'System' -Message $log_body -EventId 777 -EntryType Warning
    }
}

# Update firewall rules only if we have new IPs for blocking and ip list is not empty
if ($new_ip_address_list -ne $ip_address_list -and $new_ip_address_list) {

    if (!(Get-NetFirewallRule -DisplayName $firewall_rule_name)) {

        if ($local_port -eq 0) {
            New-NetFirewallRule -DisplayName $firewall_rule_name –RemoteAddress $new_ip_address_list -Direction Inbound -Action Block
        } else {
            New-NetFirewallRule -DisplayName $firewall_rule_name –RemoteAddress $new_ip_address_list -Direction Inbound –LocalPort $local_port -Action Block -Protocol TCP
            New-NetFirewallRule -DisplayName $firewall_rule_name –RemoteAddress $new_ip_address_list -Direction Inbound –LocalPort $local_port -Action Block -Protocol UDP
        }

    } else {
        # Getting all rules with that name and update them
        Get-NetFirewallRule -DisplayName $firewall_rule_name | Set-NetFirewallRule -RemoteAddress $new_ip_address_list -ErrorAction Stop

    }
}


#(Get-NetFirewallRule -DisplayName $firewall_rule_name | Get-NetFirewallAddressFilter).RemoteAddress | sort