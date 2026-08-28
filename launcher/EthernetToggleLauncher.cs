using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

namespace EthernetToggle
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            string exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? AppDomain.CurrentDomain.BaseDirectory;
            string scriptPath = Path.Combine(exeDir, "scripts", "Ethernet-Launcher.ps1");
            string scriptRoot = Path.Combine(exeDir, "scripts");

            if (!File.Exists(scriptPath))
            {
                return;
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = string.Format("-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\"", scriptPath),
                WorkingDirectory = scriptRoot,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            };

            Process.Start(startInfo);
        }
    }
}
