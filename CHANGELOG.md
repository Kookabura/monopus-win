# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

## [1.7]

- check_veeam_space updated: return used space

## [1.6.8]

- created get_prn_status
- check_scripts/check_rows_count.ps1 updated
- 1c checks parametr bug fixed
- check_scripts/process_ram_win.ps1 negative value bug fixed
- check_rows_count output fixed
- fixed CommandText param
- action_scripts/Backup-Something.ps1 update
- add check_scripts/check_veeam_space.ps1
- update check_scripts/check_veeam_space.ps1
- check_scripts/check_veeam_space.ps1 var bug
- Fixed failed agent issue due to 1C checks
- Removed debug by default
- check_power_chute created
- Update Backup-Something.ps1
- Backup-sql collector created
- check_power_chute.ps1 remove unnecessary
- check_website_win.ps1 added

## [1.6.7]

### Added
- script az_ad_sync status
- scripts check_files_in_folder, check_rows_count
- script check_location


### Changed
- check_scripts/1c_db_check.ps1 updated
- 1c_background_tasks and 1c_sessions_check update
- Update main.cfg.sample
- check_rows_count update
- Replaced Wsearch to wuaserv service

## [1.6.6]

### Added

- check_scripts/check_files_in_folder.ps1 added new script
- check_scripts/check_location.ps1 added new script
- check_scripts/check_rows_count.ps1 added new script

### Changed

- check_scripts/1c_db_check.ps1 updated
- check_scripts/1c_sessions_check.ps1 remove background tasks
- check_scripts/check_updates.ps1 replaced wsearch to wuaserv 

## [1.6.5]

### Fixed

- check_scripts/1c_db_check.ps1. Fixed multiple processes error.

### Changed

- check_scripts/1c_db_check.ps1. Added warning and critical values. Defaults are now 0.8 and 1
- check_scripts/check_policy_passwordcomplexity.ps1. Removed unnecessary condition.
- check_scripts/check_shadow_copy.ps1. Updated logic.
- check_scripts/check_updates.ps1. Changed days since latest update count.

## [1.6.4] - 2023-04-06

### Added

- 1c_sessions_check.ps1. Added conditions for statuses to the check.

### Fixed

- check_check_policy_passwordcomplexity.ps1. Fixed state bug.
- check_updates.ps1. Minor fixes.
- local_load.ps1. Fixed bug.

### Changed

- check_updates.ps1. Changed default warning and critical values

## [1.6.3] - 2023-03-24

### Added

- Service status tracking
- Script for installing/updating agents
- Check script: 1c_background_tasks.ps1
- Check script: 1c_db_check.ps1
- Check script: 1c_response_time_db_check.ps1
- Check script: 1c_sessions_check.ps1
- Check script: check_azure_agent_status.ps1
- Check script: check_certificate_expiration.ps1
- Check script: check_dirs_compare.ps1
- Check script: check_shadow_copy.ps1
- Check script: check_remote_disk_connection.ps1
- Check script: check_veeam_backup_status.ps1
- Check script: check_wbackup.ps1
- Check script: get_mssqlserver_errors.ps1
- Check script: process_ram_win.ps1

### Fixed

- check_policy_passwordcomplexity.ps1. Fixed a bug in the script
- check_updates.ps1. Fixed the display of the result of the check
- get_schtaskstatus.ps1. Fixed display of statuses. For correct display on the site (hyphenation to another line)
- local_load.ps1. Fixed load error greater than 100 percent
- Fixed client inactivity in case of check timeout

### Changed

- brute_force.ps1. Added a filter to the check
- brute_force.ps1. Set critical and warning values
- check_applocker.ps1. Added appx to exclusion conditions
- check_null_sql_data.ps1. Updated the script
- check_pipelines_tasks.ps1. Added the number of minutes to the parameters
- get_rd_sessions.ps1. Updated the script
- Moved the timeout parameter to the config file
- Increased fault tolerance in case of network failure

## [1.6.2] - 2022-07-19

## [1.6.1] - 2022-07-18

## [1.6.0] - 2022-06-02

## [1.5.2] - 2021-01-04

### Changed
- Fixed result sending moment determination for hosts that are in different timezones
- Fixed process_load error if temp xml is empty

## [1.5.1] - 2021-01-03

### Changed
- Fixed args parsing if value contains a space
- Improved check_client_ver check to prevent multiple config file update

## [1.5.0] - 2021-01-03

### Added
- CPU load per process check
- Writing permission check before client update
- SQL and folders backup scripts. Folder backup is processed by shadow copies
- check_graceperiod for nonlicansed RDP

### Changed
- Improved blocking RDp port script to follow Windows limitations
- Improved first check determination in local_load check
- Switched args format to common powershell format. Example: -parameter value

## [1.3.7] - 2019-09-22
