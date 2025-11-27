$SevenZipPath = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $SevenZipPath)) {
    # Попробуй найти 7-Zip в других путях
    $SevenZipPath = Get-ChildItem "C:\Program Files*\7-Zip\7z.exe" | Select-Object -First 1 -ExpandProperty FullName
    if (-not $SevenZipPath) {
        throw "7-Zip not found! Please install 7-Zip or check the path"
    }
}

function Remove-OldFiles {
    param (
        [string]$TargetDir,
        [hashtable]$RetainPolicy,
        [string]$BaseName,
        [string]$LogFile
    )

    $policy_arr = $RetainPolicy.GetEnumerator()
    foreach ($policy in $policy_arr) {
        Write-Verbose "Checking retain policy $($policy.name) for retain copies. Threshold is $($policy.value['retainCopies'])"
        $numberOfCopies = (ls ((Join-Path $TargetDir $policy.name) + '\*') -Include ($BaseName + '_*' + $policy.name + '*')).count
        Write-Verbose "Number of copies is in asset is $numberOfCopies"
        
        if ($numberOfCopies -gt ($retainCopies = $policy.value['retainCopies'])) {
            Write-Verbose "Number of copies in $($policy.name) set is greater than $($policy.value['retainCopies']). Start cleaning..."

            $iterations = $numberOfCopies - $retainCopies
            $backupSets = ls ((Join-Path $TargetDir $policy.name) + '\*') -Include ($BaseName + '_*' + $policy.name + '*') | ? {$_.LastWriteTime -lt (get-date).AddDays(-$policy.value['retainDays'])} | sort lastwritetime
            
            Write-Verbose (ConvertTo-Json $backupSets)
            
            if ($backupSets) {
                for ($i=0;$i -lt $iterations;$i++) {
                    if ($backupSets[$i]) {
                        $backupSets[$i] | rm
                        if ($LogFile) {
                            ((get-date -format 'dd.MM.yy HH:mm:ss: ') + 'Удален файл - ' + $backupSets[$i].name) | Out-File $LogFile -Encoding unicode -Append
                        }
                    }
                }
            }
        }
    }
}

function Create-BackupDirectory {
    Param (
        [string]$Path,
        [string]$PolicyName
    )
    
    $fullPath = Join-Path $Path $PolicyName
    if (!(Test-Path $fullPath)) {
        try {
            New-Item -Path $fullPath -ItemType Directory -ErrorAction Stop | Out-Null
        } catch {
            Write-Host "Failed to create directory: $_"
            throw "Error on creating backup repositories"
        }
    }
}

function Handle-BackupSet {
    [CmdletBinding()]
    Param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$SourceFile,
		[Parameter(Mandatory=$true)][string]$TargetPath,
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
        [string]$Encrypt = '',
		[string]$Password,
		[boolean]$Compress = $false
		
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
            Create-BackupDirectory -Path $TargetPath -PolicyName $policy_name
            if ($Encrypt) {
                Create-BackupDirectory -Path $Encrypt -PolicyName $policy_name
            }
        }

        $date = Get-Date
    }

    Process {
        # Перемещаем копии на сетевое хранилище

        $dtarget = "$TargetPath\daily\$($tmpfile.basename)_daily_$($date.ToString('ddMMHHmmss'))$($tmpfile.extension)"
        
        if (($tmpfile.fullname -split ':\\')[0] -eq ($dtarget -split ':\\')[0] -and ($tmpfile.Extension -eq '.zip' -or (!$Compress -and [string]::IsNullOrWhiteSpace($Encrypt)))) {
            # Если в рамках одного диска
            cmd /c mklink /H "$dtarget" "$($tmpfile.fullname)" | Out-Null
            Write-Verbose 'NO Compress or Encrypt'
        } else {
            # Если диски разные
            # Проверка, нужно ли сжимать или шифровать файл
            if ($Compress -or ![string]::IsNullOrWhiteSpace($Encrypt)) {
                Write-Verbose 'Compress or Encrypt'
        
                # Путь для временного сжатого файла
                $dtarget = "$dtarget.zip"

                # Сжимаем файл
                Write-Verbose "Compressing file with 7-Zip"
                & $SevenZipPath a "$dtarget" "$($tmpfile.fullname)" -mx=5 -tzip

                # Проверка, нужно ли шифровать файл
                if (![string]::IsNullOrWhiteSpace($Encrypt)) {
                    if ($Password.Length -eq 0) {
                        Write-Warning "Encryption is carried out without a password!"
                    }
            
                    # Шифрование сжатого файла
                    Write-Verbose "Encrypting compressed file"
                    $dtargetEncrypt = "$Encrypt\daily\$($tmpfile.basename)_daily_$($date.ToString('ddMMHHmmss'))$($tmpfile.extension).zip"
                    EncryptGzip-File -InputFile $dtarget -OutputFile $dtargetEncrypt -Password $Password
                    #EncryptGzip-File -InputFile $compressedTempFile -OutputFile $Encrypt -Password $Password

                } 

                # Удаление временного сжатого файла, если не нужно сохранять сжатую версию
                if (-not $Compress) {
                    Write-Verbose "Removing temporary compressed file"
                    Remove-Item $dtarget
                }

            } else {
                # Если сжатие и шифрование не требуется, просто копируем файл
                Copy-Item $tmpfile.fullname $dtarget
            }
        }


        $paths = @()
        if ($Compress -or [string]::IsNullOrWhiteSpace($Encrypt)) {
            $paths += $TargetPath
        }

        if (![string]::IsNullOrWhiteSpace($Encrypt)) {
            $paths += $Encrypt
        }

        foreach ($path in $paths) {
            $dtarget = "$path\daily\$($tmpfile.basename)_daily_$($date.ToString('ddMMHHmmss'))$($tmpfile.extension)"

            if ($Compress -or ![string]::IsNullOrWhiteSpace($Encrypt)) {
                $dtarget = "$dtarget.zip"
            }

            # Откладываем копию в еженедельный архив
            if ($RetainPolicy['weekly']) {
                $isMonthlyCopyExists = (ls ($path + '\weekly\*') -Include ($tmpfile.basename + '_weekly*') | ? {$_.lastwritetime -gt (Get-Date -hour 0 -minute 0 -second 0).AddDays(-7)}).count
                if (!$isMonthlyCopyExists) {
                    $hardlink = "$path\weekly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'weekly')
                    if ([bool]([System.Uri]$path).IsUnc) {
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
                $isMonthlyCopyExists = (ls ($path + '\monthly\*') -Include ($tmpfile.basename + '_monthly*') | ? {$_.lastwritetime -gt (Get-Date -day 1 -hour 0 -minute 0 -second 0)}).count
                if (!$isMonthlyCopyExists) {
                    $hardlink = "$path\monthly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'monthly')
                    if ([bool]([System.Uri]$path).IsUnc) {
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
            Remove-OldFiles -TargetDir $path -RetainPolicy $RetainPolicy -BaseName $tmpfile.basename -LogFile $LogFile
        }

        if (!$LASTEXITCODE) {
            rm $tmpfile
        }
    }

    End {
    }
}

function EncryptGzip-File
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)][String]$InputFile,
		[Parameter(Mandatory=$true)][String]$OutputFile,
		[String]$Password
	)

	$InputStream = New-Object IO.FileStream($InputFile, [IO.FileMode]::Open, [IO.FileAccess]::Read)
	$OutputStream = New-Object IO.FileStream($OutputFile, [IO.FileMode]::Create, [IO.FileAccess]::Write)

	$Salt = New-Object Byte[](32)
	$Prng = New-Object System.Security.Cryptography.RNGCryptoServiceProvider
	$Prng.GetBytes($Salt)

	$PBKDF2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt)
	$AESKey  = $PBKDF2.GetBytes(32)
	$AESIV   = $PBKDF2.GetBytes(16)

	$AES = New-Object Security.Cryptography.AesManaged
	$Enc = $AES.CreateEncryptor($AESKey, $AESIV)

	$OutputStream.Write($Salt, 0, $Salt.Length)

	$CryptoStream = New-Object System.Security.Cryptography.CryptoStream($OutputStream, $Enc, [System.Security.Cryptography.CryptoStreamMode]::Write)

	$InputStream.CopyTo($CryptoStream)
	
	$InputStream.Flush()
	$CryptoStream.Flush()
	$OutputStream.Flush()
	$InputStream.Close()
	$CryptoStream.Close()
	$OutputStream.Close()
}

function DecryptGzip-File
{
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true)][String]$InputFile,
		[Parameter(Mandatory=$true)][String]$OutputFile,
		[String]$Password
	)

	$InputStream = New-Object IO.FileStream($InputFile, [IO.FileMode]::Open, [IO.FileAccess]::Read)
	$OutputStream = New-Object IO.FileStream($OutputFile, [IO.FileMode]::Create, [IO.FileAccess]::Write)

	$Salt = New-Object Byte[](32)
	$BytesRead = $InputStream.Read($Salt, 0, $Salt.Length)
	if ($BytesRead -ne $Salt.Length)
	{
		Write-Host 'Failed to read Salt from file'
		exit
	}

	$PBKDF2 = New-Object System.Security.Cryptography.Rfc2898DeriveBytes($Password, $Salt)
	$AESKey  = $PBKDF2.GetBytes(32)
	$AESIV   = $PBKDF2.GetBytes(16)

	$AES = New-Object Security.Cryptography.AesManaged
	$Decryptor = $AES.CreateDecryptor($AESKey, $AESIV)

	$CryptoStream = New-Object System.Security.Cryptography.CryptoStream($InputStream, $Decryptor, [System.Security.Cryptography.CryptoStreamMode]::Read)
	
	$CryptoStream.CopyTo($OutputStream)
	
	$InputStream.Flush()
	$CryptoStream.Flush()
	$OutputStream.Flush()
	$InputStream.Close()
	$CryptoStream.Close()
	$OutputStream.Close()
}

# Бэкап микротика
function Backup-Mikrotik {
    [CmdletBinding()]
    Param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$MHost,
		[string]$Login = 'admin',
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Pass,
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Path,
		[string]$Prefix
	)

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


# Бэкап SQL
function Backup-SQLDatabase {
    [CmdletBinding()]
    Param (
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Database,
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [string]$Path,
    [string]$Server=$env:computername,
    [string]$Type="Database",
    [boolean]$Auto=$false
    )

    Begin{
        ## Full + Log Backup of MS SQL Server databases
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

        # Существует ли папка для бэкапа
        if (!(Test-Path $path)) {
            throw "Backup path $path not found. Cannot proccess backup."
        }

        # Удаляем копию, если она уже есть
        if ($type -eq "Database") {
            $path = $Path + $database + '_full' + '.bak'
        } elseif ($type -eq "log") {
            $path = $Path + $database + '_log' + '.trn'
        }
        if (Test-Path $path) {
            rm $path
        }
    }
    Process{
        try {

            Write-Verbose "Backing up to $path"
            $backup = New-Object ("Microsoft.SqlServer.Management.Smo.Backup")
            $backup.Action = $Type

            # The script runs full and log backup automatically depends on whether full backup was run today or not.
            if ($auto) {
                Write-Verbose "Automatic mode was detected. Checking if database is in full mode to process full or log backup."

                # Check if db is in full mode. If not switch to full backup? Or check the lastest full backup date?
                $database_object = $srv.databases | ? {$_.name -eq $database}

                if ($database_object.recoverymodel -ne 'simple') {
                    # If yes check last database full backup. If yesterday do full backup then. If it was today do log backup then.
                    if ($database_object.lastbackupdate.date -ne [datetime]::today) {
                        $backup.Action = 'database'
                        $path = ($path -replace '_log', '_full') -replace '\.trn', '.bak'
                    } else {
                        $backup.Action = 'log'
                        $path = ($path -replace '_full', '_log') -replace '\.bak', '.trn'
                    }
                } else {
                    Write-Warning "Database recovery model is Simple. Automatic mode is not possible. Switching to $type backup."
                }
            }

            Write-Verbose "Backup path is $path. Backup action is $($backup.action)."
            
            # If we're backuping log we should truncate them.
            if ($Type -eq "Database") {
                $backup.LogTruncation = 'Truncate'
            }

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
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$true)][string]$Folder,
        [Parameter(Mandatory=$true)][string]$BackupPath,
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

        & $SevenZipPath a "$backupFile" "$Folder\*" -mx=5 -tzip

        if (-not (Test-Path $backupFile)) {
            throw "Failed to create backup archive with 7-Zip"
        }

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


function Clear-OldRobocopyLogs {
    param(
        [string]$LogsPath = "F:\TMP",
        [int]$KeepDays = 7
    )
    
    try {
        Write-Host "$(Get-Date -format 'dd.MM.yy HH:mm:ss'): Cleaning old robocopy logs..."
        
        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        $oldLogs = Get-ChildItem -Path $LogsPath -Filter "robocopy_*.log" | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        }
        
        if ($oldLogs.Count -gt 0) {
            Write-Host "Found $($oldLogs.Count) old logs to remove"
            $oldLogs | Remove-Item -Force
            Write-Host "Old robocopy logs cleaned successfully"
        } else {
            Write-Host "No old robocopy logs found"
        }
    }
    catch {
        Write-Warning "Failed to clean old robocopy logs: $_"
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


#####===== Проверка доступности VSS =====#####
function Test-VSSAvailability
{
    [CmdletBinding()]
    param()
    
    try {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Testing VSS availability..."
        
        # 1. Проверяем права администратора
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-Warning "VSS requires administrator privileges. Current user is not admin."
            return $false
        }
        
        # 2. Проверяем службу VSS
        $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
        if (-not $vssService -or $vssService.Status -ne 'Running') {
            Write-Warning "VSS service is not running"
            return $false
        }
        
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS service is running"
        return $true
        
    } catch {
        Write-Warning "VSS test failed with exception: $($_.Exception.Message)"
        return $false
    }
}


#####===== Бэкап папок =====#####
function Execute-BackupFolders
{
    [CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string[]]$Folders, # перечиcление папок для бэкапа
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation, # временное хранилище копий
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation, # хранилище бэкапов
		[string]$LogFile,
		[string]$Password,
		[boolean]$Compress,
		[boolean]$Encrypt
    )
	
    # Очистка старых логов
    Clear-OldRobocopyLogs -LogsPath $BackupTempLocation -KeepDays 7
	
	# Создаем теневые копии для дисков, на которых находятся папки
	Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Starting folders backup job..."
	$volumes = @()
	$shadows = @{}
	foreach ($folder in $Folders) {
		# Получаем диск папки
		$volume = Split-Path $folder -Qualifier
		if ($volumes -notcontains $volume) {
			Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating shadow copy for volume $volume..."
			try {
				$shadow = New-ShadowLink -Drive $volume
				
				$shadowpath = $(Join-Path $volume 'shadow')
				Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating SymLink to shadowcopy at $shadowpath"
				$target = "$($shadow.DeviceObject)\";
				Invoke-Expression -Command "cmd /c mklink /d '$shadowpath' '$target'" | Out-Null

				$shadows[$volume] = @{
					Shadow = $shadow
					Path = $shadowpath
				}
				$volumes += $volume
			} catch {
				Write-Warning "Failed to create shadow copy for $($volume): $_"
				Write-Host "Will attempt Robocopy without shadow copy..."
			}
		}
	}

	# Бэкапим данные из теневой копии с помощью Robocopy
	foreach ($folder in $Folders) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $folder to temp location $BackupTempLocation"
		if (!(Test-Path $BackupTempLocation)) {
			mkdir $BackupTempLocation -Force | Out-Null
		}

		try {
			$volume = Split-Path $folder -Qualifier
			$folderName = Split-Path $folder -Leaf
			$currentDate = Get-Date -Format 'yyyyMMdd-HHmmss'

			# Путь для зеркальной копии Robocopy (сохраняется между запусками)
			$mirrorPath = Join-Path $BackupTempLocation $folderName

			# Определяем источник для копирования
			if ($shadows.ContainsKey($volume)) {
				# Используем теневую копию если доступна
				$shadowSource = Join-Path $shadows[$volume].Path (Split-Path $folder -NoQualifier).TrimStart('\')
				Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Using shadow copy source: $shadowSource"
				$source = $shadowSource
			} else {
				# Используем оригинальную папку если теневая копия недоступна
				Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Using original source: $folder"
				$source = $folder
			}

			# Создаем/обновляем зеркало с помощью Robocopy
			Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Synchronizing mirror with Robocopy..."

			$robocopyArgs = @(
				"`"$source`"",
				"`"$mirrorPath`"",
				"/MIR",         # зеркальный режим - синхронизирует назначение с источником
				"/E",           # включая подпапки
                "/B",           # РЕЖИМ РЕЗЕРВНОГО КОПИРОВАТЕЛЯ (Backup mode) - обходит некоторые ограничения прав
				"/ZB",          # использовать режим резервного копирования
				"/R:3",         # 3 попытки повтора
				"/W:5",         # ждать 5 секунд между попытками
				"/TBD",         # ждать определения общих имен
				"/NP",          # не показывать процент выполнения
				"/V",           # подробный вывод
				"/XD `"$RECYCLE.BIN`" `"System Volume Information`"",
				"/XF `"pagefile.sys`" `"swapfile.sys`" `"hiberfil.sys`"",
				"/UNILOG+:`"$BackupTempLocation\robocopy_$(Get-Date -Format 'dd.MM.yy_HH-mm-ss').log`""
			)

			$robocopyProcess = Start-Process -FilePath "robocopy.exe" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow

			if ($robocopyProcess.ExitCode -le 7) {
				Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Robocopy synchronization completed successfully"
				
				# Создаем ZIP из актуального зеркала через 7-Zip
                $backupFile = Join-Path $BackupSetsLocation "$folderName-$currentDate.zip"
                Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating ZIP archive from synchronized mirror with 7-Zip"
				
				try {
					& $SevenZipPath a "$backupFile" "$mirrorPath\*" -mx=5 -tzip

					# Перемещаем бэкап в хранилище
					Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location"
					Handle-BackupSet -SourceFile $backupFile -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 93; 'retainCopies' = 3}} -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt

					Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup completed successfully."
				} catch {
					Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Failed to create ZIP archive: $_" -ForegroundColor Red
				}
			} else {
				Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Robocopy synchronization failed with exit code: $($robocopyProcess.ExitCode)" -ForegroundColor Red
			}
			
		} catch {
			Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup folder $folder failed [line: $($_.InvocationInfo.ScriptLineNumber)] - $_" -ForegroundColor Red
		}
	}

	# Удаляем теневые копии
	foreach ($volume in $shadows.Keys) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Removing shadow copy for volume $volume"
		try {
			Remove-ShadowLink $shadows[$volume].Shadow
			cmd /c rmdir (Join-Path $volume 'shadow') 2>$null
		} catch {
			Write-Warning "Failed to remove shadow copy for $($volume): $_"
		}
	}
}

#####===== Прямой Robocopy (без VSS) =====#####
function Execute-BackupWithDirectRobocopy
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string[]]$Folders,
        [Parameter(Mandatory=$true)][string]$BackupTempLocation,
        [Parameter(Mandatory=$true)][string]$BackupSetsLocation,
        [string]$LogFile,
        [string]$Password,
        [boolean]$Compress,
        [boolean]$Encrypt,
        [int]$RetryCount = 3
    )
    
    foreach ($folder in $Folders) {
        if (!(Test-Path $folder)) {
            Write-Warning "Source folder $folder does not exist. Skipping."
            continue
        }
        
        $folderName = (Get-Item $folder).Name
        $tempBackupFolder = Join-Path $BackupTempLocation $folderName
        $backupName = "$folderName" + (Get-Date -Format "_yyyy-MM-dd_HH-mm-ss")
        $currentBackup = Join-Path $BackupTempLocation "$backupName.zip"
        
        try {
            # Создаем целевую папку
            if (!(Test-Path $tempBackupFolder)) {
                New-Item -Path $tempBackupFolder -ItemType Directory -Force | Out-Null
            }
            
            # Копируем напрямую Robocopy
            $robocopyArgs = @(
                "`"$folder`"",
                "`"$tempBackupFolder`"",
                "/MIR", "/COPY:DAT", "/DCOPY:T",
                "/R:$RetryCount", "/W:5",
                "/NP", "/NDL", "/NFL", "/NJH", "/NJS",
                "/XF", "*.tmp", "*.temp", "*.log",
                "/UNILOG:`"$BackupTempLocation\robocopy-$folderName.log`""
            )
            
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Running direct Robocopy (without VSS)..."
            $robocopyResult = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
            
            $exitCode = $robocopyResult.ExitCode
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Direct Robocopy completed with exit code: $exitCode"
            
            if ($exitCode -le 11) {
                # Создаем архив
                Backup-Folder -Folder $tempBackupFolder -BackupPath $BackupTempLocation -Name $backupName
                
                Handle-BackupSet -SourceFile $currentBackup -TargetPath $BackupSetsLocation -RetainPolicy @{
                    'daily' = @{'retainDays' = 7; 'retainCopies' = 7}
                    'monthly' = @{'retainDays' = 93; 'retainCopies' = 3}
                } -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
                
                Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Direct Robocopy backup of $folder completed"
            } else {
                Write-Error "Direct Robocopy failed for $folder with critical error code: $exitCode"
            }
            
            # Очищаем временную папку
            Remove-Item $tempBackupFolder -Recurse -Force -ErrorAction SilentlyContinue
            
        } catch {
            $errorMessage = $_
            Write-Error "Direct Robocopy backup failed for $folder - $errorMessage"
        }
    }
}

#####===== Функция для очистки старых инкрементальных копий =====#####
function Clear-OldIncrementalBackups
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string]$IncrementalPath,
        [int]$KeepDays = 7
    )
    
    if (Test-Path $IncrementalPath) {
        $cutoffDate = (Get-Date).AddDays(-$KeepDays)
        
        $oldBackups = Get-ChildItem -Path $IncrementalPath -Directory | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        }
        
        if ($oldBackups.Count -gt 0) {
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Removing $($oldBackups.Count) old incremental backups older than $KeepDays days"
            
            $oldBackups | ForEach-Object {
                Write-Host "Removing old incremental backup: $($_.Name)"
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Cleanup completed"
        } else {
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): No old incremental backups found for cleanup"
        }
    } else {
        Write-Warning "Incremental path $IncrementalPath does not exist"
    }
}

#####===== Автоматический выбор метода бэкапа =====#####
function Execute-BackupAutoMethod
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][string[]]$Folders,
        [Parameter(Mandatory=$true)][string]$BackupTempLocation,
        [Parameter(Mandatory=$true)][string]$BackupSetsLocation,
        [string]$LogFile,
        [string]$Password,
        [boolean]$Compress,
        [boolean]$Encrypt
    )
    
    # Проверяем доступность VSS
    $vssAvailable = Test-VSSAvailability
    
    if ($vssAvailable) {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS доступен, используем бэкап с теневой копией"
        Execute-BackupFolders -Folders $Folders -BackupTempLocation $BackupTempLocation -BackupSetsLocation $BackupSetsLocation -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
    } else {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS недоступен, используем прямой Robocopy"
        Execute-BackupWithDirectRobocopy -Folders $Folders -BackupTempLocation $BackupTempLocation -BackupSetsLocation $BackupSetsLocation -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
    }
}

#####===== Бэкап баз данных SQL =====#####
function Execute-BackupSQL
{
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string[]]$Databases,          # перечисление БД
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation,   # временное хранилище копий
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation,                            # хранилище бэкапов
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
		[string]$Password,
		[boolean]$Compress,
        [boolean]$Auto,
		[string]$Encrypt = ''  # path to encrypted files directory
    )

	foreach ($db in $Databases) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $db to temp location..."
		if (!(Test-Path $BackupTempLocation)) {
			mkdir $BackupTempLocation
		}
		$file = Backup-SQLDatabase -Database $db -Path $BackupTempLocation -Auto $auto

        if ($file -match '_log_') {
            $Encrypt = $false
        }

		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location and hadling copies count..."
		Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy $RetainPolicy -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt -Verbose

		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup is finished."
	}
}

#####===== Бэкап микротика =====#####
function Execute-BackupMikrotik
{
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$MHost,                # ip
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Login,                # Login для микротика
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Pass,                 # пароль для микротика
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation,   # временное хранилище копий
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation,                            # хранилище бэкапов
		[string]$LogFile,
		[string]$Password,
		[boolean]$Compress,
		[boolean]$Encrypt
    )

	$file = Backup-Mikrotik -MHost $MHost -Login $Login -Pass $Pass -Path $BackupTempLocation
	Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 62; 'retainCopies' = 2}} -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
}

#####===== Бэкап папок (пример) =====#####
#Execute-BackupFolders -Folders 'C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', 'C:\Users\aseregin\Downloads' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Бэкап баз данных SQL (пример) =====#####
#Execute-BackupSQL -Databases 'bd1', 'bd2' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Бэкап микротика (пример) =====#####
#Execute-BackupMikrotik -MHost '192.168.88.1' -Login 'login' -Pass 'pass' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Расшифровка зашифрованного бэкапа (пример) =====#####
#DecryptGzip-File -InputFile \\tsclient\G\Arhiv\Desktop_daily_0706132446.zip.zip -OutputFile C:\TMP\Desktop_daily_0706132446.zip -Password "P@55word"


#####===== Примеры для бекапирования папок =====#####

# 1. Автоматический выбор метода (опционально)
#Execute-BackupAutoMethod -Folders 'D:\Data', 'C:\Work' -BackupTempLocation 'F:\Temp' -BackupSetsLocation 'G:\Backups' -LogFile 'G:\Backups\log.txt' -Password "MyPassword123" -Compress $true -Encrypt $true

# 2. Принудительно с VSS (предпочтительно)
#Execute-BackupFolders -Folders 'D:\Important' -BackupTempLocation 'F:\Temp' -BackupSetsLocation 'G:\Backups' -LogFile 'G:\Backups\log.txt'

# 3. Принудительно без VSS (если есть проблемы)
#Execute-BackupWithDirectRobocopy -Folders 'C:\Users' -BackupTempLocation 'F:\Temp' -BackupSetsLocation 'G:\Backups' -RetryCount 5

# 4. Только проверка VSS
#Test-VSSAvailability

# 5. Очистка старых инкрементальных копий
#Clear-OldIncrementalBackups -IncrementalPath 'F:\Temp' -KeepDays 3