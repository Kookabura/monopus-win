function Handle-BackupSet {
   <#
    .Synopsis
        Handle backup sets
    .EXAMPLE
        Handle-Copy C:\Temp\Temp.zip E:\backup
    #> 

    [CmdletBinding()]

    Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$SourceFile,
    [Parameter(Mandatory=$true)]
    [string]$TargetPath,
    [hashtable]$RetainPolicy = @{
        'daily' = @{
            'retainDays' = 14;
            'retainCopies' = 14
        };
        'monthly' = @{
            'retainDays' = 365;
            'retainCopies' = 12
        }
    },
    [string]$LogFile,
    [boolean]$Compress = $true
    )

    Begin {
        if (!(Test-Path $TargetPath)) {
            Write-Verbose "Creating target path for backups"
            mkdir $TargetPath | Out-Null
        }

        if (!$RetainPolicy['daily']) {
            throw "Daily retain policy is obligitary"
        }

        if (Test-path $SourceFile)  {
            $tmpfile = Get-Item $SourceFile
        } else {
            throw "Source file $SourceFile doesn't exist"
        }

        foreach ($policy_name in $RetainPolicy.keys) {
            if (!(test-path (Join-Path $TargetPath $policy_name))) {
                mkdir (Join-Path $TargetPath $policy_name) | Out-Null
                if ($LASTEXITCODE) {
                    throw "Error on creating backup repositories"
                }
            }
        }

        $date = Get-Date
    }

    Process {
        # Перемещаем копии на сетевое хранилище

        $dtarget = "$TargetPath\daily\$($tmpfile.basename)_daily_$($date.ToString('dd-MM'))$($tmpfile.extension)"
        
        if (($tmpfile.fullname -split ':\\')[0] -eq ($dtarget -split ':\\')[0] -and ($tmpfile.Extension -eq '.zip' -or !$compress)) {
            # Если в рамках одного диска
            cmd /c mklink /H "$dtarget" "$($tmpfile.fullname)" | Out-Null
        } else {
            # Если диски разные
            # TO DO Сжимать до копирования. Так быстрее должно быть.
            if ($compress) {

                $dtarget = "$dtarget.zip"

                Add-Type -assembly 'System.IO.Compression'
                Add-Type -assembly 'System.IO.Compression.FileSystem'
                
                [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($dtarget, ([System.IO.Compression.ZipArchiveMode]::Create))
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $tmpfile.fullname, (Split-Path $tmpfile.fullname -Leaf)) | out-null
                $ZipFile.Dispose()
            } else {
                cp $tmpfile.fullname $dtarget
            }
            
        }

        # Откладываем копию в еженедельный архив
        if ($RetainPolicy['weekly']) {
            $isMonthlyCopyExists = (ls ($TargetPath + '\weekly\*') -Include ($tmpfile.basename + '_weekly*') | ? {$_.lastwritetime -gt (Get-Date -hour 0 -minute 0 -second 0).AddDays(-7)}).count
            if (!$isMonthlyCopyExists) {
                $hardlink = "$TargetPath\weekly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'weekly')
                if ([bool]([System.Uri]$TargetPath).IsUnc) {
                    # TO DO: just copy if it is unc path
                    Write-Verbose "Copiyng file to weekly repo"
                    cp $dtarget $hardlink
                } else {
                    Write-Verbose "Creating hard link $hardlink from $dtarget"
                    cmd /c mklink /H "$hardlink" "$dtarget" | Out-Null
                }
            }
        }

        # Откладываем копию в ежемесячный архив
        if ($RetainPolicy['monthly']) {
            $isMonthlyCopyExists = (ls ($TargetPath + '\monthly\*') -Include ($tmpfile.basename + '_monthly*') | ? {$_.lastwritetime -gt (Get-Date -day 1 -hour 0 -minute 0 -second 0)}).count
            if (!$isMonthlyCopyExists) {
                $hardlink = "$TargetPath\monthly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'monthly')
                if ([bool]([System.Uri]$TargetPath).IsUnc) {
                    # TO DO: just copy if it is unc path
                    Write-Verbose "Copiyng file to monthly repo"
                    cp $dtarget $hardlink
                } else {
                    Write-Verbose "Creating hard link $hardlink from $dtarget"
                    cmd /c mklink /H "$hardlink" "$dtarget" | Out-Null
                }
            }
        }

        # Удаляем старые копии
        $policy_arr = $retainPolicy.GetEnumerator()
        foreach ($policy in $policy_arr) {
            Write-Verbose "Checking retain policy $($policy.name) for retain copies. Threshold is $($policy.value['retainCopies'])"
            $numberOfCopies = (ls ((Join-Path $TargetPath $policy.name) + '\*') -Include ($tmpfile.basename + '_*' + $policy.name + '*')).count
            Write-Verbose "Number of copies is in asset is $numberOfCopies"
            
            if ($numberOfCopies -gt ($retainCopies = $policy.value['retainCopies'])) {
                Write-Verbose "Number of copies in $($policy.name) set is greater than $($policy.value['retainCopies']). Strat cleaning..."

                $iterations = $numberOfCopies - $retainCopies
                $backupSets = ls ((Join-Path $TargetPath $policy.name) + '\*') -Include ($tmpfile.basename + '_*' + $policy.name + '*') | ? {$_.LastWriteTime -lt (get-date).AddDays(-$policy.value['retainDays'])} | sort lastwritetime
                
                Write-Verbose (ConvertTo-Json $backupSets)
                
                if ($backupSets) {
                    for ($i=0;$i -lt $iterations;$i++) {
                        if ($backupSets[$i]) {
                            $backupSets[$i] | rm
                            if ($LogFile) {
                                ((get-date -format 'dd.MM.yy HH:mm:ss: ') + 'Удален файл - ' + $backupSets[$i].name) | Out-File $logFile -Encoding unicode -Append
                            }
                        }
                    }
                }
            }
        }

        if (!$LASTEXITCODE) {
            rm $tmpfile
        }
    }

    End {
    }
}


function Backup-Mikrotik {

    [CmdletBinding()]

    Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$MHost,
    [string]$Login = 'admin',
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Pass,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Path,
    [string]$Prefix)

    Begin{
        
        $pscred = New-Object Management.Automation.PSCredential(
            $Login,
            (ConvertTo-SecureString $Pass -AsPlainText -Force)
        )
        $ssh = New-SSHSession $MHost -AcceptKey -Credential $pscred -ErrorAction Stop
    }
    Process{

        if (!$prefix) {
            $out = (Invoke-SSHCommand $ssh -Command "/system identity print" -EnsureConnection).Output
            $name = (($out -split "\r\n" | select-string name) -split ":")[1].trim()
            $prefix = "$($name)"
        }

        $currentDate=Get-Date -Format yyyyMMdd

        $fname = $prefix

        $out = (Invoke-SSHCommand $ssh -Command "/system backup save name=$fname password=$currentDate" -EnsureConnection).Output

        if($out.Trim() -eq "Configuration backup saved")
        {
	        $sftp = New-SFTPSession $MHost -AcceptKey -Credential $pscred
            $TargetPath = "$path\$fname.backup"
	        Get-SFTPFile -SFTPSession $sftp -RemoteFile "/$fname.backup" -LocalPath $Path -Overwrite
	        Remove-SFTPItem -SFTPSession $sftp -Path "/$fname.backup" -Force
	        Remove-SFTPSession $sftp | Out-Null
            Write-Output $TargetPath
        }
        else {
            Write-Verbose "Can't save backup"
        }

    }
    End{
        Remove-SSHSession $ssh | Out-Null
    }

}


function Backup-SQLDatabase {
    <#
    .Synopsis
        Backups SQL database. Script works with SQL 2008 and higher. Requires dbadmin privileges on target database.
    #>

    [CmdletBinding()]

    Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Database,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Path,
    [string]$Server=$env:computername)

    Begin{
        ## Full + Log Backup of MS SQL Server databases/span>            
        ## with SMO.            
        [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo');            
        [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Management.Sdk.Sfc');            
        [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO');            
        # Required for SQL Server 2008 (SMO 10.0).            
        [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMOExtended');

        if ((get-itemproperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server').InstalledInstances -eq 'SQLEXPRESS') {
            $Server = $Server + "\SQLEXPRESS"
        }
        Write-Verbose "Server name is $server"

        $srv = New-Object Microsoft.SqlServer.Management.Smo.Server $server;
        $srv.ConnectionContext.StatementTimeout = 0
        $date = Get-Date

        # Существует ли папка для бекапа
        if (!(Test-Path $path)) {
            throw "Backup path $path not found. Cannot proccess backup."
        }

        # Удаляем копию, если она уже есть
        $path = $Path + $database + '_full' + '.bak'
        if (Test-Path $path) {
            rm $path
        }
    }
    Process{
        try {
            
            Write-Verbose "Backing up to $path"
            $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup")            
            $backup.Action = "Database"            
            $backup.Database = $database           
            $backup.Devices.AddDevice($path, "File")                  
            $backup.Incremental = 0
            # Starting full backup process.
            $backup.SqlBackup($srv);     
            #Backup-SqlDatabase -ServerInstance $server -BackupFile ($tempBackupPath + $database + '_daily_full_' + $date.ToString('dd-MM') + '.bak') -Database $database
            Write-Output $path
        } catch {
            ((get-date -format 'dd.MM.yy HH:mm:ss: [line: ') + $_.InvocationInfo.ScriptLineNumber + '] ' + $database + ' - ' + $_)
        }

    }
    End{}
}


function Backup-Folder {
    <#
    .Synopsis
        Zip folder
    #>

    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$true)]
        [string]$Folder,
        [Parameter(Mandatory=$true)]
        [string]$BackupPath,
        [string]$Name
    )

    Process {

        if (!($source = get-item $Folder -ErrorAction SilentlyContinue)) {
            throw "Source folder $Folder does not exist"
        }

        if (!($target = get-item $BackupPath -ErrorAction SilentlyContinue)) {
            throw "Target path $BackupPath does not exist"
        }

        if (!$name) {
            $Name = $source.name
        }

        $date = get-date
        $backupFile = Join-Path $BackupPath "$name.zip"
        Write-Verbose "Backuping file $Folder to $backupFile"
        if (Test-Path $backupFile) {
            rm $backupFile
        }
        
        Add-Type -assembly 'System.IO.Compression'
        Add-Type -assembly 'System.IO.Compression.FileSystem'
                
        [System.IO.Compression.ZipFile]::CreateFromDirectory($Folder, $backupFile, 'Optimal', $false) | Out-Null

        Write-Output $backupFile
    }
}


function New-ShadowLink {
    [CmdletBinding()]
    param (
        [string]$Drive=($ENV:SystemDrive)
    )

    begin {
        if (!$Drive.EndsWith('\')) {
            $Drive += '\'
        }
    }

    process {
        Write-Verbose "Creating a snapshot of $Drive"
        $class=[WMICLASS]"root\cimv2:win32_shadowcopy";
        $result = $class.create($Drive, "ClientAccessible");

        Write-Verbose "Getting the full target path for a symlink to the shadow snapshot"
        $shadow = Get-WmiObject Win32_ShadowCopy | Where-Object ID -eq $result.ShadowID
        $target = "$($shadow.DeviceObject)\";
    }

    end {
        Write-Verbose "Returning shadowcopy snapshot object"
        return $shadow;
    }
}


function Remove-ShadowLink {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $shadow
    )

    begin {
    }

    process {
        Write-Verbose "Deleting the shadowcopy snapshot"
        $shadow.Delete();

        Write-Verbose "Deleting the now empty folder"
    }

    end {
        Write-Verbose "Shadow link and snapshot have been removed";
        return;
    }

}


# Общие параметры для всех заданий бекапа
$BackupTempLocation = 'C:\Arhiv\Backups' # временное хранилище копий
$BackupSetsLocation = 'C:\Arhiv\Backups' # хранилище бекапов

###### -------------------------------------------------------------------
# Бекап баз данных SQL
$databases = @('lera-money')


foreach ($db in $databases) {
    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $db to temp location..."
    if (!(Test-Path $BackupTempLocation)) {
        mkdir $BackupTempLocation
    }
    $file = Backup-SQLDatabase -Database $db -Path $BackupTempLocation

    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location and hadling copies count..."
    Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 366; 'retainCopies' = 12}}

    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup is finished."
}


###### ------------------------------------------------------------------
# Бекап папок
$folders = @('C:\1CBases\Base',
            'C:\1CBases\Base2',
            'C:\1CBases\Base3',
            'C:\1CBases\Base4',
            'C:\1CBases\Base5',
            'C:\1CBases\Base6')

# Создаем теневые копии для дисков, на которых находятся папки
Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Starting folders backup job..."
$volumes = @()
$shadows = @{}
foreach ($folder in $folders) {
    # Получаем диск папки
    $volume = Split-Path $folder -Qualifier
    if ($volumes -notcontains $volume) {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating shadow copy for volume $volume..."
        $shadow = New-ShadowLink -Drive $volume
        
        
        $shadowpath = $(Join-Path $volume 'shadow')
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating SymLink to shadowcopy at $shadowpath"
        $target = "$($shadow.DeviceObject)\";
        Invoke-Expression -Command "cmd /c mklink /d '$shadowpath' '$target'" | Out-Null

        $shadows[$volume] = $shadow
        $volumes += $volume
    }
}

# Бекапим данные из теневой копии
foreach ($folder in $folders) {
    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $folder to temp location $BackupTempLocation"
    if (!(Test-Path $BackupTempLocation)) {
        mkdir $BackupTempLocation
    }
    try {

        # Бекапим папку
        $file = Backup-Folder -Folder (Join-Path $shadowpath (Split-Path $folder -NoQualifier)) -BackupPath $BackupTempLocation

        #Перемещаем бекап к хранилище
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location and hadling copies count"
        Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 366; 'retainCopies' = 12}}
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup is finished successfully."
    } catch {
        Write-Host ((get-date -format 'dd.MM.yy HH:mm:ss: Backup folder $folder is failed [line: ') + $_.InvocationInfo.ScriptLineNumber + '] ' + ' - ' + $_) -ForegroundColor Red
    }

}

# Удаляем теневые копии
foreach ($volume in $shadows.keys) {
    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Removing shadow copy for volume $volume"
    Remove-ShadowLink $shadows[$volume]
    cmd /c rmdir (Join-Path $volume 'shadow')
}


##### -------------------------------------------------------------------------------
# Backup mikrotik configs
$config = @{
    'dc' = @{
        'ip' = '192.168.88.1';
        'login' = 'login';
        'pass' = 'pass'
     };
}
$config = $config.GetEnumerator()

foreach ($conf in $config) {

    $file = Backup-Mikrotik -MHost $conf.value['ip'] -Login $conf.value['login'] -Pass $conf.value['pass'] -Path C:\Scripts\
    Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 62; 'retainCopies' = 2}}
}