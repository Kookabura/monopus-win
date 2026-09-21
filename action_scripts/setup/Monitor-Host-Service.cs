using System;
using System.Diagnostics;
using System.IO;
using System.ServiceProcess;
using System.Threading;

internal sealed class MonitorHostService : ServiceBase
{
    private readonly ManualResetEvent stopping = new ManualResetEvent(false);
    private static readonly object logLock = new object();
    private static string logPath;
    private Thread worker;

    public MonitorHostService()
    {
        ServiceName = "MonOpusMonitorHost";
        CanStop = true;
    }

    protected override void OnStart(string[] args)
    {
        worker = new Thread(RunMonitor);
        worker.IsBackground = true;
        worker.Start();
    }

    protected override void OnStop()
    {
        stopping.Set();
        if (worker != null)
            worker.Join(15000);
    }

    private void RunMonitor()
    {
        string directory = Path.GetFullPath(Path.Combine(
            AppDomain.CurrentDomain.BaseDirectory, "..", ".."));
        logPath = Path.Combine(directory, "monitor-host-service.log");
        string script = Path.Combine(directory, "Monitor-Host.ps1");
        string powershell = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.System),
            @"WindowsPowerShell\v1.0\powershell.exe");

        while (!stopping.WaitOne(0))
        {
            Process child = null;
            try
            {
                child = new Process();
                child.StartInfo.FileName = powershell;
                child.StartInfo.Arguments =
                    "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + script + "\"";
                child.StartInfo.WorkingDirectory = directory;
                child.StartInfo.UseShellExecute = false;
                child.StartInfo.CreateNoWindow = true;
                child.StartInfo.RedirectStandardError = true;
                child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs data)
                {
                    if (data.Data != null)
                        Log("PowerShell error: " + data.Data);
                };
                child.Start();
                child.BeginErrorReadLine();
                Log("Started Monitor-Host.ps1, PID " + child.Id);

                while (!stopping.WaitOne(1000) && !child.HasExited) { }
                if (child.HasExited && !stopping.WaitOne(0))
                    Log("Monitor-Host.ps1 exited with code " + child.ExitCode + "; restarting in 5 seconds.");
            }
            catch (Exception error)
            {
                Log("Could not run Monitor-Host.ps1: " + error.Message);
                try
                {
                    EventLog.WriteEntry("Application", "monOpus monitor could not start: " + error,
                        EventLogEntryType.Error);
                }
                catch { }
            }
            finally
            {
                if (child != null)
                {
                    try
                    {
                        if (!child.HasExited)
                            child.Kill();
                        child.WaitForExit(5000);
                    }
                    catch (InvalidOperationException) { }
                    child.Dispose();
                }
            }

            // A crashed or normally exited monitor is started again after a short delay.
            stopping.WaitOne(5000);
        }
        Log("Service stopped.");
    }

    private static void Log(string message)
    {
        try
        {
            lock (logLock)
            {
                File.AppendAllText(logPath,
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " " + message + Environment.NewLine);
            }
        }
        catch { }
    }

    public static void Main()
    {
        ServiceBase.Run(new MonitorHostService());
    }
}
