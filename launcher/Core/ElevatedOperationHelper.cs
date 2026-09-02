using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;

namespace EthernetToggle.Core
{
    internal enum ElevatedRunOutcome
    {
        Ran,
        UserDeclined,
        Failed
    }

    internal static class ElevatedOperationHelper
    {
        public static bool PromptForAdminApproval(IWin32Window owner, string appName)
        {
            var message =
                "Windows requires administrator approval to enable or disable a network adapter.\n\n" +
                "Click Continue, then select Yes on the User Account Control (UAC) prompt.\n\n" +
                "If you decline UAC, the adapter will not be changed.";

            var result = MessageBox.Show(
                owner,
                message,
                "Administrator Approval Required",
                MessageBoxButtons.OKCancel,
                MessageBoxIcon.Information);

            return result == DialogResult.OK;
        }

        public static void ShowUacDeclinedDialog(IWin32Window owner, string appName)
        {
            MessageBox.Show(
                owner,
                "The network adapter was not changed because administrator approval was declined.\n\n" +
                "To try again, click the Ethernet button and select Yes on the UAC prompt.",
                appName,
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning);
        }

        public static ElevatedRunOutcome RunToggleScriptElevated(string repoRoot, out string errorDetail)
        {
            errorDetail = null;

            var toggleScript = Path.Combine(repoRoot, "scripts", "Toggle-NetworkAdapter.ps1");
            if (!File.Exists(toggleScript))
            {
                errorDetail = "Toggle script not found:\n" + toggleScript;
                return ElevatedRunOutcome.Failed;
            }

            var registerScript = Path.Combine(repoRoot, "scripts", "Register-ElevatedTask.ps1");
            string arguments;

            if (File.Exists(registerScript))
            {
                arguments = string.Format(
                    "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -Command \"& {{ & '{0}' -ErrorAction SilentlyContinue; & '{1}' }}\"",
                    registerScript.Replace("'", "''"),
                    toggleScript.Replace("'", "''"));
            }
            else
            {
                arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File \"" + toggleScript + "\"";
            }

            return StartElevatedProcess(repoRoot, arguments, out errorDetail);
        }

        public static bool DispatchExecution(string taskName, string repoRoot, out string errorDetail)
        {
            errorDetail = null;

            if (ElevatedSetupHelper.IsTaskRegistered(taskName))
            {
                TriggerScheduledTask(taskName);
                return true;
            }

            var outcome = RunToggleScriptElevated(repoRoot, out errorDetail);
            if (outcome == ElevatedRunOutcome.UserDeclined)
            {
                return false;
            }

            if (outcome == ElevatedRunOutcome.Failed)
            {
                return false;
            }

            return true;
        }

        private static ElevatedRunOutcome StartElevatedProcess(string repoRoot, string arguments, out string errorDetail)
        {
            errorDetail = null;

            try
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = arguments,
                    WorkingDirectory = repoRoot,
                    UseShellExecute = true,
                    Verb = "runas",
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                using (var process = Process.Start(startInfo))
                {
                    if (process == null)
                    {
                        errorDetail = "Could not start elevated PowerShell.";
                        return ElevatedRunOutcome.Failed;
                    }

                    process.WaitForExit(120000);
                    if (process.ExitCode != 0)
                    {
                        errorDetail = "Elevated operation failed (exit code " + process.ExitCode + ").";
                        return ElevatedRunOutcome.Failed;
                    }
                }

                return ElevatedRunOutcome.Ran;
            }
            catch (Win32Exception ex)
            {
                if (ex.NativeErrorCode == 1223)
                {
                    errorDetail = "Administrator approval was declined.";
                    return ElevatedRunOutcome.UserDeclined;
                }

                errorDetail = ex.Message;
                return ElevatedRunOutcome.Failed;
            }
            catch (Exception ex)
            {
                errorDetail = ex.Message;
                return ElevatedRunOutcome.Failed;
            }
        }

        private static void TriggerScheduledTask(string taskName)
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = "/Run /TN \"" + taskName + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            });
        }
    }
}
