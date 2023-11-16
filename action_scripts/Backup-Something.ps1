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
        $dtarget = "$TargetPath\daily\$($tmpfile.basename)_daily_$($date.ToString('ddMMHHmmss'))$($tmpfile.extension)"
        
        if (($tmpfile.fullname -split ':\\')[0] -eq ($dtarget -split ':\\')[0] -and ($tmpfile.Extension -eq '.zip' -or (!$Compress -and [string]::IsNullOrWhiteSpace($Encrypt)))) {
            cmd /c mklink /H "$dtarget" "$($tmpfile.fullname)" | Out-Null
            Write-Verbose 'NO Compress or Encrypt'
        } else {
            if ($Compress -or ![string]::IsNullOrWhiteSpace($Encrypt)) {
                Write-Verbose 'Compress or Encrypt'
        
                $dtarget = "$dtarget.zip"

                Write-Verbose "Compressing file"
                Add-Type -assembly 'System.IO.Compression'
                Add-Type -assembly 'System.IO.Compression.FileSystem'
        
                [System.IO.Compression.ZipArchive]$ZipFile = [System.IO.Compression.ZipFile]::Open($dtarget, ([System.IO.Compression.ZipArchiveMode]::Create))
                [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($ZipFile, $tmpfile.fullname, (Split-Path $tmpfile.fullname -Leaf)) | Out-Null
                $ZipFile.Dispose()

                if (![string]::IsNullOrWhiteSpace($Encrypt)) {
                    if ($Password.Length -eq 0) {
                        Write-Warning "Encryption is carried out without a password!"
                    }
            
                    Write-Verbose "Encrypting compressed file"
                    $dtargetEncrypt = "$Encrypt\daily\$($tmpfile.basename)_daily_$($date.ToString('ddMMHHmmss'))$($tmpfile.extension).zip"
                    EncryptGzip-File -InputFile $dtarget -OutputFile $dtargetEncrypt -Password $Password
                } 

                if (-not $Compress) {
                    Write-Verbose "Removing temporary compressed file"
                    Remove-Item $dtarget
                }

            } else {
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

            if ($RetainPolicy['weekly']) {
                $isMonthlyCopyExists = (ls ($path + '\weekly\*') -Include ($tmpfile.basename + '_weekly*') | ? {$_.lastwritetime -gt (Get-Date -hour 0 -minute 0 -second 0).AddDays(-7)}).count
                if (!$isMonthlyCopyExists) {
                    $hardlink = "$path\weekly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'weekly')
                    if ([bool]([System.Uri]$path).IsUnc) {
                        Write-Verbose "Copiyng file to weekly repo"
                        cp $dtarget $hardlink
                    } else {
                        Write-Verbose "Creating hard link $hardlink from $dtarget"
                        cmd /c mklink /H "$hardlink" "$dtarget" | Out-Null
                    }
                }
            }

            if ($RetainPolicy['monthly']) {
                $isMonthlyCopyExists = (ls ($path + '\monthly\*') -Include ($tmpfile.basename + '_monthly*') | ? {$_.lastwritetime -gt (Get-Date -day 1 -hour 0 -minute 0 -second 0)}).count
                if (!$isMonthlyCopyExists) {
                    $hardlink = "$path\monthly\" + ((Split-Path $dtarget -Leaf) -replace 'daily', 'monthly')
                    if ([bool]([System.Uri]$path).IsUnc) {
                        Write-Verbose "Copiyng file to monthly repo"
                        cp $dtarget $hardlink
                    } else {
                        Write-Verbose "Creating hard link $hardlink from $dtarget"
                        cmd /c mklink /H "$hardlink" "$dtarget" | Out-Null
                    }
                }
            }

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

# Р‘РµРєР°Рї РјРёРєСЂРѕС‚РёРєР°
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


# Р‘РµРєР°Рї SQL
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

        # РЎСѓС‰РµСЃС‚РІСѓРµС‚ Р»Рё РїР°РїРєР° РґР»СЏ Р±РµРєР°РїР°
        if (!(Test-Path $path)) {
            throw "Backup path $path not found. Cannot proccess backup."
        }

        # РЈРґР°Р»СЏРµРј РєРѕРїРёСЋ, РµСЃР»Рё РѕРЅР° СѓР¶Рµ РµСЃС‚СЊ
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


#####===== Р‘РµРєР°Рї РїР°РїРѕРє =====#####
function Execute-BackupFolders
{
    [CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string[]]$Folders, # РїРµСЂРµС‡РёСЃР»РµРЅРёРµ РїР°РїРѕРє РґР»СЏ Р±РµРєР°РїР°
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation, # РІСЂРµРјРµРЅРЅРѕРµ С…СЂР°РЅРёР»РёС‰Рµ РєРѕРїРёР№
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation, # С…СЂР°РЅРёР»РёС‰Рµ Р±РµРєР°РїРѕРІ
		[string]$LogFile,
		[string]$Password,
		[boolean]$Compress,
		[boolean]$Encrypt
    )
	
	# РЎРѕР·РґР°РµРј С‚РµРЅРµРІС‹Рµ РєРѕРїРёРё РґР»СЏ РґРёСЃРєРѕРІ, РЅР° РєРѕС‚РѕСЂС‹С… РЅР°С…РѕРґСЏС‚СЃСЏ РїР°РїРєРё
	Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Starting folders backup job..."
	$volumes = @()
	$shadows = @{}
	foreach ($folder in $Folders) {
		# РџРѕР»СѓС‡Р°РµРј РґРёСЃРє РїР°РїРєРё
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

	# Р‘РµРєР°РїРёРј РґР°РЅРЅС‹Рµ РёР· С‚РµРЅРµРІРѕР№ РєРѕРїРёРё
	foreach ($folder in $Folders) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $folder to temp location $BackupTempLocation"
		if (!(Test-Path $BackupTempLocation)) {
			mkdir $BackupTempLocation
		}
		try {
			# Р‘РµРєР°РїРёРј РїР°РїРєСѓ
			$file = Backup-Folder -Folder (Join-Path $shadowpath (Split-Path $folder -NoQualifier)) -BackupPath $BackupTempLocation

			#РџРµСЂРµРјРµС‰Р°РµРј Р±РµРєР°Рї РІ С…СЂР°РЅРёР»РёС‰Рµ
			Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location and hadling copies count"
			Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 366; 'retainCopies' = 12}} -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
			Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup is finished successfully."
		} catch {
			Write-Host ((get-date -format 'dd.MM.yy HH:mm:ss: Backup folder $folder is failed [line: ') + $_.InvocationInfo.ScriptLineNumber + '] ' + ' - ' + $_) -ForegroundColor Red
		}
	}

	# РЈРґР°Р»СЏРµРј С‚РµРЅРµРІС‹Рµ РєРѕРїРёРё
	foreach ($volume in $shadows.keys) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Removing shadow copy for volume $volume"
		Remove-ShadowLink $shadows[$volume]
		cmd /c rmdir (Join-Path $volume 'shadow')
	}
}

#####===== Р‘РµРєР°Рї Р±Р°Р· РґР°РЅРЅС‹С… SQL =====#####
function Execute-BackupSQL
{
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string[]]$Databases, # РїРµСЂРµС‡РёСЃР»РµРЅРёРµ Р‘Р”
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation, # РІСЂРµРјРµРЅРЅРѕРµ С…СЂР°РЅРёР»РёС‰Рµ РєРѕРїРёР№
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation, # С…СЂР°РЅРёР»РёС‰Рµ Р±РµРєР°РїРѕРІ
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
		[string]$Encrypt = ''  # path to encrypted files directory
    )

	foreach ($db in $Databases) {
		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backing up $db to temp location..."
		if (!(Test-Path $BackupTempLocation)) {
			mkdir $BackupTempLocation
		}
		$file = Backup-SQLDatabase -Database $db -Path $BackupTempLocation

		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Moving to backup set location and hadling copies count..."
		Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy $RetainPolicy -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt -Verbose

		Write-Host "$(get-date -format 'dd.MM.yy HH:mm:ss'): Backup is finished."
	}
}

#####===== Р‘РµРєР°Рї РјРёРєСЂРѕС‚РёРєР° =====##### РґРѕРґРµР»Р°С‚СЊ
function Execute-BackupMikrotik
{
	[CmdletBinding()]
    param (
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$MHost, # ip
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Login, # Login РґР»СЏ РјРёРєСЂРѕС‚РёРєР°
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Pass, # РїР°СЂРѕР»СЊ РґР»СЏ РјРёРєСЂРѕС‚РёРєР°
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$BackupTempLocation, # РІСЂРµРјРµРЅРЅРѕРµ С…СЂР°РЅРёР»РёС‰Рµ РєРѕРїРёР№
		[Parameter(Mandatory=$true)][string]$BackupSetsLocation, # С…СЂР°РЅРёР»РёС‰Рµ Р±РµРєР°РїРѕРІ
		[string]$LogFile,
		[string]$Password,
		[boolean]$Compress,
		[boolean]$Encrypt
    )

	$file = Backup-Mikrotik -MHost $MHost -Login $Login -Pass $Pass -Path $BackupTempLocation
	Handle-BackupSet -SourceFile $file -TargetPath $BackupSetsLocation -RetainPolicy @{'daily' = @{'retainDays' = 7;'retainCopies' = 7}; 'monthly' = @{'retainDays' = 62; 'retainCopies' = 2}} -LogFile $LogFile -Password $Password -Compress $Compress -Encrypt $Encrypt
}

#####===== Р‘РµРєР°Рї РїР°РїРѕРє (РїСЂРёРјРµСЂ) =====#####
#Execute-BackupFolders -Folders 'C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', 'C:\Users\aseregin\Downloads' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Р‘РµРєР°Рї Р±Р°Р· РґР°РЅРЅС‹С… SQL (РїСЂРёРјРµСЂ) =====#####
#Execute-BackupSQL -Databases 'bd1', 'bd2' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Р‘РµРєР°Рї РјРёРєСЂРѕС‚РёРєР° (РїСЂРёРјРµСЂ) =====#####
#Execute-BackupMikrotik -MHost '192.168.88.1' -Login 'login' -Pass 'pass' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

#####===== Р Р°СЃС€РёС„СЂРѕРІРєР° Р·Р°С€РёС„СЂРѕРІР°РЅРЅРѕРіРѕ Р±РµРєР°РїР° (РїСЂРёРјРµСЂ) =====#####
#DecryptGzip-File -InputFile \\tsclient\G\Arhiv\Desktop_daily_0706132446.zip.zip -OutputFile C:\TMP\Desktop_daily_0706132446.zip -Password "P@55word"

