using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("模方面板快捷键助手")]
[assembly: AssemblyDescription("ModelFun面板快捷键与自动备份工具")]
[assembly: AssemblyCompany("shijye")]
[assembly: AssemblyProduct("模方面板快捷键助手")]
[assembly: AssemblyCopyright("Copyright (C) 2026 shijye. All rights reserved.")]
[assembly: AssemblyInformationalVersion("V1.1")]
[assembly: AssemblyFileVersion("1.1.0.0")]
[assembly: AssemblyVersion("1.1.0.0")]

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        string appDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string scriptPath = Path.Combine(appDirectory, "RoadLevelHotkeys.ps1");

        if (!File.Exists(scriptPath))
        {
            MessageBox.Show(
                "未找到 RoadLevelHotkeys.ps1。请把 exe 和 ps1 文件放在同一目录。",
                "模方面板快捷键助手",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }

        string arguments = string.Format(
            "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\"",
            scriptPath.Replace("\"", "\\\""));

        try
        {
            StartPowerShell("pwsh.exe", arguments, appDirectory);
            return 0;
        }
        catch
        {
            try
            {
                string systemPowerShell = Path.Combine(
                    Environment.SystemDirectory,
                    @"WindowsPowerShell\v1.0\powershell.exe");
                StartPowerShell(systemPowerShell, arguments, appDirectory);
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show(
                    "PowerShell启动失败：\r\n" + ex.Message,
                    "模方面板快捷键助手",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return 1;
            }
        }
    }

    private static void StartPowerShell(string executable, string arguments, string workingDirectory)
    {
        ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.FileName = executable;
        startInfo.Arguments = arguments;
        startInfo.WorkingDirectory = workingDirectory;
        startInfo.UseShellExecute = false;
        startInfo.CreateNoWindow = true;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;

        Process process = Process.Start(startInfo);
        if (process == null)
            throw new InvalidOperationException("PowerShell进程未创建。");
    }
}
