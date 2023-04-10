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
