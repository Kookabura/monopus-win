param (
    [Parameter(Mandatory=$true)][string[]]$databases,
    [string]$type = 'default'
)

$BackupTempLocation=  # временное хранилище бекапов
$LocalBackupTarget=  # локальное хранилище бекапов
$LocalBackupTargetCrypto= #сжатый шифрованный # локальное хранилище бекапов
$BackupSetMirror= 
$err = $false

try {
    . 'C:\Program Files (x86)\monopus\action_scripts\Backup-Something.ps1'

    switch ( $type )
    {
        'default' {
            Execute-BackupSQL -Databases $databases -BackupTempLocation $BackupTempLocation -BackupSetsLocation $LocalBackupTarget -Compress $true -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 366; 'retainCopies' = 12}}
        }
        'crypto' {
            Execute-BackupSQL -Databases $databases -BackupTempLocation $BackupTempLocation -BackupSetsLocation $LocalBackupTarget -Compress $true -Encrypt $LocalBackupTargetCrypto -Password "tas!@#a76Adcv23" -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 62; 'retainCopies' = 2}}
        }
        'hourly' {
            Execute-BackupSQL -Databases $databases -BackupTempLocation $BackupTempLocation -BackupSetsLocation $LocalBackupTarget -Compress $true -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 366; 'retainCopies' = 12}}
        }
        'log' {
            $file = Backup-SQLDatabase -Database $databases[0] -Path $BackupTempLocation -Type log -Verbose 
            Handle-BackupSet -SourceFile $file -TargetPath $LocalBackupTarget -Compress $true -Verbose
        }
    }
}
catch {$err = $true}

# Обновляем зеркало бекапов
#if(!$err) {robocopy $LocalBackupTarget $BackupSetMirror /MIR /W:0 /R:0}


