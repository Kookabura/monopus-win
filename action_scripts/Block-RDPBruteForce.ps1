Import-Module "Microsoft.Powershell.Management"
Import-Module "International"
Import-Module "NetSecurity"


$start_time_event_search = (Get-Date).AddMinutes(-10) # Period where we're looking for bad attempts
$max_bad_attempts = 5 # Max bad logon attempts
$firewall_rule_name="BlockRDPBruteForce"
$local_port=-1 #0 is mean all protocols, 1-65535 - block this TCP and UDP ports
$ip_address_list=@()
$trusted_ips=@() # Example @('1.1.1.1', '2.2.2.2')


if ($local_port -eq -1) {
    $local_port=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\" -name PortNumber).PortNumber
    if (!($?)) {
        $local_port=3389 #if no value, than use default 3389 port
    }
}

# Getting bad logons attempts
$get_ip=@()
$events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-RemoteDesktopServices-RdpCoreTS/Operational'; StartTime=$start_time_event_search; ID=140} -ErrorAction SilentlyContinue

foreach ($e in $events) {
    $get_ip += $e.Properties.Value
}

$get_ip = ($get_ip | group | ? {$_.count -ge $max_bad_attempts}).name

if (!$get_ip) {
    Write-Host "There is no bad ip address. Stopping..."
    exit
}

# Getting currently blocked IP addresses
if (Get-NetFirewallRule -DisplayName $firewall_rule_name -ErrorAction SilentlyContinue) {
    foreach ($ip in (Get-NetFirewallRule -DisplayName $firewall_rule_name | select -First 1 | Get-NetFirewallAddressFilter).RemoteAddress | select -Unique) {
        $ip_address_list+=$ip
    }
}

# This doesn't work in powershell_ise
[System.Collections.ArrayList]$new_ip_address_list = $ip_address_list

# Populate new IPs for blocking
foreach ($ip in $get_ip) { 

    if ($ip_address_list -notcontains $ip -and $trusted_ips -notcontains $ip) {
     
        Write-Host "Adding $ip to RDP block list."
        if (($new_ip_address_list | Measure-Object).count -ge 10000) {
            Write-Host "There are 10000 IPs in list. We should delete one. First item in list is $($new_ip_address_list[0]). Removing it"
            $new_ip_address_list.Remove($new_ip_address_list[0])
            Write-Host "The first item is $($new_ip_address_list[0]) now."
        }
        $new_ip_address_list += $ip # Max 10000 values. Server 2016 can't save more in one rule.
        $c = ($new_ip_address_list | Measure-Object).count
        Write-Host "The last item is $($new_ip_address_list[$c-1]) now."
        
        $log_body='IP ' + $ip + ' was banned for ' + $max_bad_attempts + " or greater bad logon attempts since $start_time_event_search"

        Write-EventLog -LogName 'System' -Source 'System' -Message $log_body -EventId 777 -EntryType Warning
    }
}

Write-Host "Total IPs to block $(($new_ip_address_list | Measure-Object).count)"

# Update firewall rules only if we have new IPs for blocking and ip list is not empty
if ((Compare-Object -ReferenceObject $new_ip_address_list -DifferenceObject $ip_address_list) -and $new_ip_address_list) {

    if (!(Get-NetFirewallRule -DisplayName $firewall_rule_name -ErrorAction SilentlyContinue)) {
        
        Write-Host "Creating new rules"
        New-NetFirewallRule -DisplayName $firewall_rule_name –RemoteAddress $new_ip_address_list -Direction Inbound –LocalPort $local_port -Action Block -Protocol TCP
        New-NetFirewallRule -DisplayName $firewall_rule_name –RemoteAddress $new_ip_address_list -Direction Inbound –LocalPort $local_port -Action Block -Protocol UDP

    } else {
        Write-Host "Adding bad ip addresses to blocking rule"
        # Getting all rules with that name and update them
        Get-NetFirewallRule -DisplayName $firewall_rule_name | Set-NetFirewallRule -RemoteAddress $new_ip_address_list -ErrorAction Stop

    }
}

#(Get-NetFirewallRule -DisplayName $firewall_rule_name | Get-NetFirewallAddressFilter).RemoteAddress | sort