<#
    .Synopsis
        Geeting amount of TCP conections to remote hosts
    .EXAMPLE
        get_netconnections.ps1
#> 


[CmdletBinding()]
Param(
  [Parameter(Position=0,
             ValueFromPipelineByPropertyName=$true,
             ParameterSetName='Hosts')]
  [ValidateNotNullOrEmpty()]
  [string[]]$Hosts,
  [Parameter()]
   [int32]$W = 0,
  [Parameter()]
   [int32]$C = 10
)

Begin {

    $t = $host.ui.RawUI.ForegroundColor
    $states_text = @('ok', 'warning', 'critical', 'unknown')
    $state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
    $state = 0
    $tmp = @()

    foreach($remoteHost in $Hosts){
    # Checking DNS name or IP address?
        if (!($remoteHost -as [IPAddress] -as [Bool])) {
            $tmp += ([System.Net.Dns]::GetHostAddresses($remoteHost)).IpAddressToString
        } else {
            $tmp += $remoteHost
        }
    }

}

Process {
    $connections = @()
        
    try {
        # Getting connections to specified IPs or all
        if ($tmp) {
            $connections = Get-NetTCPConnection -RemoteAddress $tmp -ErrorAction SilentlyContinue
        } else {
            $connections = Get-NetTCPConnection -ErrorAction SilentlyContinue
        }

        $conns_num = ($connections | Measure-Object).count
      
    } catch {
        Write-Host $_ -ForegroundColor Red
        $state = 3
    }

    $perf_data = "conns_num=$conns_num;;;"
    $output = "get_netconnections.$($states_text[$state])::connections==$conns_num"

    $output += " | $perf_data"
}

End {

    $host.ui.RawUI.ForegroundColor = $($state_colors[$state])
    Write-Output $output
    $host.ui.RawUI.ForegroundColor = $t
    exit $state

}