# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

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
