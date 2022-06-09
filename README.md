# monOpus Windows Monitoring Client
monOpus.io Windows monitoring client written on Powershell.
Monitoring-Host.ps1 assumed to be run as scheduled job on computer boot. You need to obtain API key and host_id from monopus.io before run.
Check scripts might be used separately from Monitoring-Host.ps1.

## Installation steps
1. Rename main.cfg.sample to main.cfg.
2. Put your API key to main.cfg.
3. Import scheduled task from scheduler_task.xml template. While importing set up the name of the task the same as task_name parameter in main.cfg.
4. Set up admin account and run with elevated command prompt parameter for imported scheduled task.
5. Run the task.

You should get new server on monOpus.io panel with common checks.

# Backup-Something.ps1 script

В конце файла показаны примеры как делать различные бэкапы.

В примерах указаны только обязательные параметры для функций. Кроме пароля для шифрования, его может и не быть, но с ним надежнее.
По умолчанию настроенно так, что если бекапы переносятся с диска на диск они будут заархивированы и зашифрованы в процессе. Это можно настраивать:

В случае со всеми функциями:

    Обязательные параметры:
        -BackupTempLocation - временное хранилище копий, в процессе удалится, нужно указать путь
        -BackupSetsLocation - место куда поместить бекапы, указать путь
    
    Опционально:
        -LogFile - лог файл, туда будут записываться гезультаты работы скрипта, путь к файлу
        -Password - будет применен в шифровании архива, набор символов
        -Compress - опция сжатия, подразумевается что при копировании по сети быстрее и надежнее будет передавать архив, по умолчанию включена, принимает значения $true или $false
        -Encrypt - функция шифрования, работает только при включенном сжатии, по умолчанию включена, принимает значения $true или $false
    
Бекап папок:

    Обязательные параметры:
        -Folders - перечисление папок для бекапа, если одна указывается просто путь, если несколько то в апострофах через запятую ('C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', '...')
    
    Пример:
        Execute-BackupFolders -Folders 'C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', 'C:\Users\aseregin\Downloads' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

Бекап баз данных SQL:

    Обязательные параметры:
        -Databases - перечисление БД для бекапа, если одна указывается просто имя, если несколько то в апострофах через запятую ('C:\Users\aseregin\Desktop', 'C:\Users\aseregin\Documents', '...')
        
    Пример:
        #Execute-BackupSQL -Databases 'bd1', 'bd2' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

Бекап микротика:

    Обязательные параметры:
        -MHost - IP устройства
        -Login - логин к устройству
        -Pass - пароль к устройству
    
    Пример:
        Execute-BackupMikrotik -MHost '192.168.88.1' -Login 'login' -Pass 'pass' -BackupTempLocation C:\TMP -BackupSetsLocation \\tsclient\G\Archiv -Password "P@55word"

Расшифровка зашифрованного бекапа:
    Может быть такое что файл бэкапа занят другим процессом. В таком случае его нужно скачать и делать расшифровку локально.
    
    Обязательные параметры:
        -InputFile - файл для расшифровки - полное имя файла с путем
        -OutputFile - расшифрованный файл, также будет разархивирован - полное имя файла с путем
    
    Опционально:
        -Password - если шифрование было с паролем, обязательно нужно указать тот же пароль, иначе расшифровка не выполнится корректно, набор символов
    
    Пример:
        DecryptGzip-File -InputFile \\tsclient\G\Arhiv\Desktop_daily_0706132446.zip.zip -OutputFile C:\TMP\Desktop_daily_0706132446.zip -Password "P@55word"
