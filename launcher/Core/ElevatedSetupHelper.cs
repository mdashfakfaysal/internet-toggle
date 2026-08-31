using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace EthernetToggle.Core
{
    internal static class ElevatedSetupHelper
    {
        public static bool IsTaskRegistered(string taskName)
        {
            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "schtasks.exe",
                    Arguments = "/Query /TN \"" + taskName + "\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                };

                using (var process = Process.Start(startInfo))
                {
                    if (process == null)
                    {
                        return false;
                    }

                    process.WaitForExit(8000);
                    return process.ExitCode == 0;
                }
            }
            catch
            {
                return false;
            }
        }

        public static bool PromptAndRegister(IWin32Window owner, string repoRoot, string taskName)
        {
            var message =
                "Internet Switcher needs a one-time Windows administrator setup to enable or disable network adapters.\n\n" +
                "Click Yes to approve the UAC prompt. After setup, switching works without repeated prompts.\n\n" +
                "This is required for Microsoft Store and fresh installs.";

            var result = MessageBox.Show(
                owner,
                message,
                "One-Time Setup Required",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Information);

            if (result != DialogResult.Yes)
            {
                return false;
            }

            var scriptPath = Path.Combine(repoRoot, "scripts", "Register-ElevatedTask.ps1");
            if (!File.Exists(scriptPath))
            {
                MessageBox.Show(
                    owner,
                    "Setup script not found:\n" + scriptPath,
                    "Setup Error",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return false;
            }

            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + scriptPath + "\"",
                    WorkingDirectory = repoRoot,
                    UseShellExecute = true,
                    Verb = "runas",
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                using (var process = Process.Start(startInfo))
                {
                    if (process != null)
                    {
                        process.WaitForExit(60000);
                    }
                }
            }
            catch
            {
                return false;
            }

            return IsTaskRegistered(taskName);
        }
    }
}
