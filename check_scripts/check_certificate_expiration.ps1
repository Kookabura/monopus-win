[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true,
               Position=0,
               ValueFromPipelineByPropertyName=$true,
               ParameterSetName='Parameter Set 1')]
    [ValidateNotNullOrEmpty()][string[]]$Thumbprints,
	[Parameter()][int]$W = 15,
	[Parameter()][int]$C = 5
)

$output = $null
$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$c_unit = 0
$state = @(0)
$cert_status = @{
    'critical' = @();
    'warning' = @();
}

try
{
	add-pssnapin Microsoft.Exchange.Management.PowerShell.E2010
	
	$date = get-date

	foreach ($Thumbprint in $Thumbprints)
	{
		$cert = Get-ExchangeCertificate -Thumbprint $Thumbprint

		if (($cert.NotAfter - $date).Days -le $C)
		{
            $cert_status['critical'] += $Thumbprint + " (" + ($cert.NotAfter - $date).Days + " day)"
			$state += 2
		}
        else
        {
            if (($cert.NotAfter - $date).Days -le $W)
		    {
                $cert_status['warning'] += $Thumbprint + " (" + ($cert.NotAfter - $date).Days + " day)"
			    $state += 1
		    }
            else
            {
                $state += 0
            }
        }
	}

    $state = ($state | measure -Maximum).Maximum

    if (($state -eq 2) -and ($cert_status['warning'].count -gt 0))
    {
        $cert_status['critical'] += $cert_status['warning']
        $c_unit = $cert_status['warning'].count
    }
}
catch
{
	$state = 3
}

$output = "critical_cert==" + ($cert_status['critical'] -join '; ') + "__warning_cert==" + ($cert_status['warning'] -join '; ')
$output = "check_certificate_expiration.$($states_text[$state])::$output | troubles=" + ($cert_status['critical'].count + $cert_status['warning'].count - $c_unit) + ";0;0;0;"
Write-Output $output
exit $state