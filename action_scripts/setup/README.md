# install monOpus Windows Monitoring Client
monOpus.io A Windows monitoring client written in Powershell.
Monitoring-Host.ps1 is expected to run as a scheduled task when the computer boots. You need to get an API key and host_id from monopus.io before running.

## Installation steps
1. Rename main.cfg.sample to main.cfg
2. Put your API key in main.cfg file
3. Import the scheduled task from the scheduler_task.xml template. When importing, set the task name to the same as the task_name parameter in main.cfg
4. Set up an administrator account and run with an elevated command line option for the imported scheduled task.
powershell.exe -nologo -executionpolicy bypass -c "&amp; 'C:\Program Files (x86)\MonOpus\Monitor-Host.ps1'"
5. Run the task. You should get a new server in the monOpus.io panel with the standard checks.
6. Now, in the srv.txt file, enter a list of servers for installing the agent and run the script.