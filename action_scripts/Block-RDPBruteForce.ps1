Import-Module "Microsoft.Powershell.Management"
Import-Module "International"
Import-Module "NetSecurity"


$start_time_event_search = (Get-Date).AddMinutes(-10) # Period where we're looking for bad attempts
$max_bad_attempts = 5 # Max bad logon attempts
$firewall_rule_name="BanIP"
$local_port=-1 #0 is mean all protocols, 1-65535 - block this TCP and UDP ports
$ip_address_list=@()

if ($local_port -eq -1) {
    $local_port=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\" -name PortNumber).PortNumber
    if (!($?)) {
        $local_port=3389 #if no value, than use default 3389 port
    }
}

# Getting bad logons attempts
$get_ip=@()
$events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational'; StartTime=$start_time_event_search; ID=140}

foreach ($e in $events) {
    $exml = [xml]$e.toXML()
    $get_ip += $exml.Event.EventData.Data.'#text'
}
$get_ip = ($get_ip | group | ? {$_.count -ge $max_bad_attempts}).name

if (!$get_ip) {
    Write-Host "There is no bad ip address. Stopping..."
    exit
}

# Getting currently blocked IP addresses
if (Get-NetFirewallRule -DisplayName $firewall_rule_name -ErrorAction SilentlyContinue) {
    foreach ($ip in (Get-NetFirewallRule -DisplayName $firewall_rule_name | Get-NetFirewallAddressFilter).RemoteAddress | select -Unique) {
        $ip_address_list+=$ip
    }
}
$new_ip_address_list = $ip_address_list

# Populate new IPs for blocking
foreach ($ip in $get_ip) { 

    if ($ip_address_list -notcontains $ip) {
     
        Write-Verbose "Adding $ip to RDP block list"
        $new_ip_address_list += $ip
        
        $log_body='IP ' + $ip + ' was banned for ' + $max_bad_attempts + " or greater bad logon attempts since $start_time_event_search"

        Write-EventLog -LogName 'System' -Source 'System' -Message $log_body -EventId 777 -EntryType Warning
    }
}

# Update firewall rules only if we have new IPs for blocking and ip list is not empty
if ($new_ip_address_list -ne $ip_address_list -and $new_ip_address_list) {

    if (!(Get-NetFirewallRule -DisplayName $firewall_rule_name -ErrorAction SilentlyContinue)) {

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