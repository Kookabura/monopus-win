# Начало
[CmdletBinding()]
Param(
  [Parameter()]
   [int32]$W = 5,
  [Parameter()]
   [int32]$C = 1
)

$t = $host.ui.RawUI.ForegroundColor
$states_text = @('ok', 'warning', 'critical', 'unknown')
$state_colors = @('Green', 'Yellow', 'Red', 'DarkGray')
$state = 0

# Вставил твой код
$grace = ((gwmi -namespace "Root/CIMV2/TerminalServices" Win32_TerminalServiceSetting).GetGracePeriodDays()).DaysLeft

    if ($grace -le $w) {
        $state = 1
    } 
    if ($grace -le $c) {
        $state = 2
    }

# Финал

$output = "rdp_grace_repiod.$($states_text[$state])::daysleft==$days | days=$days;;;" # здесь должно быть кол-во дней до конца периода видно. По ним график будет рисоваться.

$host.ui.RawUI.ForegroundColor = $($state_colors[$state])
Write-Output $output
$host.ui.RawUI.ForegroundColor = $t
exit $state