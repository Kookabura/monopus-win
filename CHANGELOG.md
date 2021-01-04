# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased]

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
