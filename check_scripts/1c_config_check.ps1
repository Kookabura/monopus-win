param (
    [Parameter(Mandatory=$true)][String[]]$pubs,
    [string]$refPath = "C:\Program Files (x86)\MonOpus\check_scripts\vendor\reference.config",
    [string]$pubsPath = "C:\inetpub\wwwroot"
)

$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

$errors=@()

foreach ($pname in $pubs) {
    try {
        $pPath = "$pubsPath\$($pname.Trim())"
        $1CVer = (ls 'C:\Program Files (x86)\1cv8\common\1cestart.exe').VersionInfo.FileVersion
        $referenceConfig = Get-Content $refPath -Raw -ErrorAction Stop
        $referenceConfig = $referenceConfig -replace "1cv8\\[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\\", "1cv8\$1CVer\"
        $referenceConfig = $referenceConfig -replace '\s', ''
        $config = Get-Content "$pPath\web.config" -Raw -ErrorAction Stop
        $config = $config -replace '\s', ''

        if ($referenceConfig -ne $config) {
            $errors += $pname
        }

    } catch { $errors += $pname }
}

if ($errors.Count -ge 1) {
    $state = 2
}

$perfData = "errorsCount=$($errors.count);;;;"
$output = "1c_config_check.$($states_text[$state])::errorsCount==$($errors.count)__errorsPaths==$($errors -join ', ') | $($perfData)"
Write-Output $output
exit $state


