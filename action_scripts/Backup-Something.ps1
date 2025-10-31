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
                Write-Verbose "Compressing file"
                Add-Type -assembly 'System.IO.Compression'
                Add-Type -assembly 'System.IO.Compression.FileSystem'
        
                [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($dtarget, ([System.IO.Compression.ZipArchiveMode]::Create))
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $tmpfile.fullname, (Split-Path $tmpfile.fullname -Leaf)) | Out-Null
                $ZipFile.Dispose()

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

# Бэкап Микротика
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

#####===== Умный бэкап папок с автоматическим выбором метода =====#####
function Execute-BackupFolders
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
        [switch]$ForceRobocopy,
        [int]$RetryCount = 3
    )
    
    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Starting smart folder backup..."
    
    # Проверяем доступность VSS
    $vssAvailable = Test-VSSAvailability
    $useVSS = $vssAvailable -and (-not $ForceRobocopy)
    
    if ($useVSS) {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS available. Using shadow copies for consistent backup."
        Execute-BackupWithVSS -Folders $Folders -BackupTempLocation $BackupTempLocation -BackupSetsLocation $BackupSetsLocation -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
    } else {
        Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS not available. Using Robocopy with retry logic."
        if (-not $vssAvailable) {
            Write-Warning "VSS shadow copies are not available. Some open files may not be backed up correctly."
        }
        Execute-BackupWithRobocopy -Folders $Folders -BackupTempLocation $BackupTempLocation -BackupSetsLocation $BackupSetsLocation -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt -RetryCount $RetryCount
    }
}

#####===== Проверка доступности VSS =====#####
function Test-VSSAvailability
{
    try {
        # Проверяем права администратора
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
        if (-not $isAdmin) {
            Write-Verbose "VSS requires administrator privileges"
            return $false
        }
        
        # Проверяем службу VSS
        $vssService = Get-Service -Name VSS -ErrorAction SilentlyContinue
        if (-not $vssService -or $vssService.Status -ne 'Running') {
            Write-Verbose "VSS service is not running"
            return $false
        }
        
        # Пробуем создать тестовый снапшот
        $testDrive = $env:SystemDrive
        $shadowClass = [WMICLASS]"root\cimv2:win32_shadowcopy"
        $result = $shadowClass.Create($testDrive, "ClientAccessible")
        
        if ($result.ReturnValue -eq 0) {
            # Успешно - удаляем тестовый снапшот
            $shadow = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $result.ShadowID }
            if ($shadow) {
                $shadow.Delete()
            }
            Write-Verbose "VSS is available and working"
            return $true
        } else {
            Write-Verbose "VSS creation failed with error: $($result.ReturnValue)"
            return $false
        }
    } catch {
        Write-Verbose "VSS test failed: $_"
        return $false
    }
}

#####===== Бэкап с VSS (теневые копии) =====#####
function Execute-BackupWithVSS
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
    
    $shadows = @{}
    $shadowLinks = @{}
    
    try {
        # Создаем теневые копии для каждого тома
        $volumes = @()
        foreach ($folder in $Folders) {
            $volume = Split-Path $folder -Qualifier
            if ($volumes -notcontains $volume -and $volume) {
                Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Creating shadow copy for volume $volume"
                
                $shadowClass = [WMICLASS]"root\cimv2:win32_shadowcopy"
                $result = $shadowClass.Create($volume, "ClientAccessible")
                
                if ($result.ReturnValue -eq 0) {
                    $shadow = Get-WmiObject Win32_ShadowCopy | Where-Object { $_.ID -eq $result.ShadowID }
                    $shadows[$volume] = $shadow
                    
                    # Создаем симлинк к теневой копии
                    $shadowLinkPath = Join-Path $env:TEMP "Shadow_$([System.Guid]::NewGuid().ToString())"
                    $targetPath = "$($shadow.DeviceObject)\"
                    
                    # Используем New-Item для создания junction вместо mklink
                    New-Item -ItemType Junction -Path $shadowLinkPath -Target $targetPath -Force | Out-Null
                    $shadowLinks[$volume] = $shadowLinkPath
                    
                    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Shadow copy created and linked to $shadowLinkPath"
                    $volumes += $volume
                } else {
                    Write-Error "Failed to create shadow copy for $volume. Error code: $($result.ReturnValue)"
                    throw "VSS creation failed"
                }
            }
        }
        
        # Бэкапим из теневых копий
        foreach ($folder in $Folders) {
            $volume = Split-Path $folder -Qualifier
            $relativePath = Split-Path $folder -NoQualifier
            
            if ($shadowLinks.ContainsKey($volume)) {
                $shadowSource = Join-Path $shadowLinks[$volume] $relativePath.TrimStart('\')
                
                if (Test-Path $shadowSource) {
                    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up from shadow copy: $shadowSource"
                    
                    $folderName = (Get-Item $folder).Name
                    $backupName = "$folderName" + (Get-Date -Format "_yyyy-MM-dd_HH-mm-ss")
                    $currentBackup = Join-Path $BackupTempLocation "$backupName.zip"
                    
                    # Создаем бэкап из теневой копии
                    Backup-Folder -Folder $shadowSource -BackupPath $BackupTempLocation -Name $backupName
                    
                    # Обрабатываем бэкап-сет
                    Handle-BackupSet -SourceFile $currentBackup -TargetPath $BackupSetsLocation -RetainPolicy @{
                        'daily' = @{'retainDays' = 7; 'retainCopies' = 7}
                        'monthly' = @{'retainDays' = 93; 'retainCopies' = 3}
                    } -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
                    
                    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): VSS backup of $folder completed"
                } else {
                    Write-Warning "Shadow source path not found: $shadowSource"
                }
            }
        }
        
    } finally {
        # Очистка: удаляем симлинки и теневые копии
        foreach ($volume in $shadowLinks.Keys) {
            $linkPath = $shadowLinks[$volume]
            if (Test-Path $linkPath) {
                Remove-Item $linkPath -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        
        foreach ($volume in $shadows.Keys) {
            $shadow = $shadows[$volume]
            if ($shadow) {
                try {
                    $shadow.Delete()
                    Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Shadow copy for $volume removed"
                } catch {
                    $errorMessage = $_
                    Write-Warning "Failed to remove shadow copy for $volume - $errorMessage"
                }
            }
        }
    }
}

#####===== Бэкап с Robocopy (резервный метод) =====#####
function Execute-BackupWithRobocopy
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
    
    $incrementalTemp = Join-Path $BackupTempLocation "Incremental"
    if (!(Test-Path $incrementalTemp)) {
        New-Item -Path $incrementalTemp -ItemType Directory -Force | Out-Null
    }
    
    foreach ($folder in $Folders) {
        if (!(Test-Path $folder)) {
            Write-Warning "Source folder $folder does not exist. Skipping."
            continue
        }
        
        $folderName = (Get-Item $folder).Name
        $tempBackupFolder = Join-Path $incrementalTemp $folderName
        $backupName = "$folderName" + (Get-Date -Format "_yyyy-MM-dd_HH-mm-ss")
        $currentBackup = Join-Path $BackupTempLocation "$backupName.zip"
        
        try {
            # Создаем/обновляем инкрементальную копию через Robocopy
            if (!(Test-Path $tempBackupFolder)) {
                New-Item -Path $tempBackupFolder -ItemType Directory -Force | Out-Null
            }
            
            $robocopyArgs = @(
                "`"$folder`"",
                "`"$tempBackupFolder`"",
                "/MIR", "/COPY:DAT", "/DCOPY:T",
                "/R:$RetryCount", "/W:10",
                "/NP", "/NDL", "/NFL", "/NJH", "/NJS"
            )
            
            Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Synchronizing $folder with Robocopy..."
            $robocopyResult = Start-Process -FilePath "robocopy" -ArgumentList $robocopyArgs -Wait -PassThru -NoNewWindow
            
            if ($robocopyResult.ExitCode -le 7) {
                # Создаем финальный бэкап
                Backup-Folder -Folder $tempBackupFolder -BackupPath $BackupTempLocation -Name $backupName
                # Расписание
                Handle-BackupSet -SourceFile $currentBackup -TargetPath $BackupSetsLocation -RetainPolicy @{
                    'daily' = @{'retainDays' = 7; 'retainCopies' = 7}
                    'monthly' = @{'retainDays' = 93; 'retainCopies' = 3}
                } -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
                
                Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Robocopy backup of $folder completed"
            } else {
                $exitCode = $robocopyResult.ExitCode
                Write-Error "Robocopy failed for $folder with exit code $exitCode"
            }
            
        } catch {
            $errorMessage = $_
            Write-Error "Robocopy backup failed for $folder - $errorMessage"
        }
    }
}

# Бекап папок
function Backup-Folder {
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$true)][string]$Folder,
        [Parameter(Mandatory=$true)][string]$BackupPath,
        [string]$Name,
        [int]$CompressionLevel = 5
    )

    Process {
        try {
            if (!($source = Get-Item $Folder -ErrorAction SilentlyContinue)) {
                throw "Source folder $Folder does not exist"
            }

            if (!(Test-Path $BackupPath)) {
                New-Item -Path $BackupPath -ItemType Directory -Force | Out-Null
            }

            if (!$Name) {
                $Name = $source.Name
            }

            $backupFile = Join-Path $BackupPath "$Name.zip"
            
            Write-Verbose "Backuping folder $Folder to $backupFile"
            
            if (Test-Path $backupFile) {
                Remove-Item $backupFile -Force
            }
            
            Add-Type -Assembly 'System.IO.Compression'
            Add-Type -Assembly 'System.IO.Compression.FileSystem'
            
            [System.IO.Compression.ZipFile]::CreateFromDirectory($Folder, $backupFile, $CompressionLevel, $false)
            
            Write-Output $backupFile
            
        } catch {
            $errorMessage = $_
            Write-Error "Failed to backup folder $Folder - $errorMessage"
            throw
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
        
        Get-ChildItem -Path $IncrementalPath -Directory | Where-Object {
            $_.LastWriteTime -lt $cutoffDate
        } | ForEach-Object {
            Write-Host "Removing old incremental backup: $($_.Name)"
            Remove-Item -Path $_.FullName -Recurse -Force
        }
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

#####===== Бэкап микротика =====##### # доделать
function Execute-BackupMikrotik
{
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$MHost,                # ip
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Login,                # Login для микротика
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Pass,                 # Пароль для микротика
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

# Запуск бэкапа
Execute-BackupFolders -Folders 'D:\!Disp', 'C:\Users' -BackupTempLocation 'F:\TMP' -BackupSetsLocation 'F:\!Backup' -LogFile 'F:\!Backup\logs.log' -Compress $true





# Примеры использования:

#####===== Бекaп папок (пример) =====#####
#Execute-BackupFolders -Folders 'C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', 'C:\Users\aseregin\Downloads' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Бекaп баз данных SQL (пример) =====#####
#Execute-BackupSQL -Databases 'bd1', 'bd2' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Бекaп микротика (пример) =====#####
#Execute-BackupMikrotik -MHost '192.168.88.1' -Login 'login' -Pass 'pass' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Расшифровка зашифрованного бекапа (пример) =====#####
#DecryptGzip-File -InputFile \\tsclient\G\Arhiv\Desktop_daily_0706132446.zip.zip -OutputFile C:\TMP\Desktop_daily_0706132446.zip -Password "P@55word"

# Для папок:
#####===== Автоматический выбор (рекомендуется) =====#####
# Execute-BackupFolders -Folders 'D:\!Disp', 'C:\Users' -BackupTempLocation 'F:\TMP' -BackupSetsLocation 'F:\!Backup' -LogFile 'F:\!Backup\logs.log' -Compress $true

#####===== Принудительно использовать Robocopy =====#####
# Execute-BackupFolders -Folders 'D:\!Disp', 'C:\Users' -BackupTempLocation 'F:\TMP' -BackupSetsLocation 'F:\!Backup' -ForceRobocopy -Compress $true

#####===== Проверить доступность VSS =====#####
# Test-VSSAvailability
