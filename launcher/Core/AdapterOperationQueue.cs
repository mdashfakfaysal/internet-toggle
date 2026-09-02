using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;

namespace EthernetToggle.Core
{
    internal static class AdapterOperationQueue
    {
        private const string QueueFileName = "pending-action-queue.json";
        private const string LockFileName = "operation.lock";
        private const string LegacyFileName = "pending-action.json";
        private const int DebounceMilliseconds = 1200;
        private const int StaleLockSeconds = 30;

        private static readonly object SyncRoot = new object();
        private static DateTime _lastEnqueueUtc = DateTime.MinValue;
        private static bool _operationInFlight;

        public static string GetActionDirectory()
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "InternetToggle");
        }

        public static void RecoverOnStartup(string taskName)
        {
            var actionDir = GetActionDirectory();
            if (!Directory.Exists(actionDir))
            {
                Directory.CreateDirectory(actionDir);
            }

            ClearStaleLock(actionDir);
            ClearLockOnStartup(actionDir);
            ResetInFlightState();
            MigrateLegacyPendingFile(actionDir);
            ClearLegacyPendingFile(actionDir);

            if (!VerifyScheduledTask(taskName))
            {
                ReliabilityLog("Startup", "Scheduled task missing: " + taskName);
            }
        }

        public static bool TryEnqueue(string taskName, object payload, out string errorMessage)
        {
            errorMessage = null;

            if (_operationInFlight)
            {
                errorMessage = "Adapter operation already in progress. Please wait.";
                return false;
            }

            var now = DateTime.UtcNow;
            if ((now - _lastEnqueueUtc).TotalMilliseconds < DebounceMilliseconds)
            {
                errorMessage = "Please wait a moment before switching again.";
                return false;
            }

            var actionDir = GetActionDirectory();
            var lockPath = Path.Combine(actionDir, LockFileName);
            if (File.Exists(lockPath))
            {
                if (!IsLockStale(lockPath) && IsLockActivelyHeld(lockPath))
                {
                    errorMessage = "Adapter operation in progress. Please wait.";
                    return false;
                }

                ClearLockOnStartup(actionDir);
            }

            lock (SyncRoot)
            {
                AppendToQueue(actionDir, payload);
                _lastEnqueueUtc = now;
                _operationInFlight = true;
            }

            ReliabilityLog("Enqueue", new JavaScriptSerializer().Serialize(payload));

            ThreadPool.QueueUserWorkItem(_ => WaitForOperationComplete(actionDir));
            return true;
        }

        public static bool DispatchExecution(string taskName, string repoRoot, out string errorDetail)
        {
            return ElevatedOperationHelper.DispatchExecution(taskName, repoRoot, out errorDetail);
        }

        public static void WaitForCompletionBlocking(int timeoutSeconds)
        {
            var actionDir = GetActionDirectory();
            var lockPath = Path.Combine(actionDir, LockFileName);
            var deadline = DateTime.UtcNow.AddSeconds(timeoutSeconds);

            while (DateTime.UtcNow < deadline)
            {
                if (!_operationInFlight)
                {
                    return;
                }

                if (!File.Exists(lockPath) || IsLockStale(lockPath))
                {
                    _operationInFlight = false;
                    return;
                }

                Thread.Sleep(200);
            }

            ClearStaleLock(actionDir);
            _operationInFlight = false;
            ReliabilityLog("Timeout", "Blocking wait for operation completion timed out");
        }

        public static void MarkManualOperation()
        {
            _lastEnqueueUtc = DateTime.UtcNow;
        }

        public static void ResetInFlightState()
        {
            _operationInFlight = false;
        }

        public static bool IsOperationInFlight()
        {
            return _operationInFlight;
        }

        public static bool IsAutomationCooldownActive()
        {
            return (DateTime.UtcNow - _lastEnqueueUtc).TotalSeconds < 5;
        }

        private static void WaitForOperationComplete(string actionDir)
        {
            var lockPath = Path.Combine(actionDir, LockFileName);
            var deadline = DateTime.UtcNow.AddSeconds(30);

            while (DateTime.UtcNow < deadline)
            {
                if (!File.Exists(lockPath) || IsLockStale(lockPath))
                {
                    _operationInFlight = false;
                    return;
                }

                Thread.Sleep(200);
            }

            ClearStaleLock(actionDir);
            _operationInFlight = false;
            ReliabilityLog("Timeout", "Operation lock wait timed out");
        }

        private static void AppendToQueue(string actionDir, object payload)
        {
            if (!Directory.Exists(actionDir))
            {
                Directory.CreateDirectory(actionDir);
            }

            var queuePath = Path.Combine(actionDir, QueueFileName);
            var serializer = new JavaScriptSerializer { MaxJsonLength = int.MaxValue };
            var queue = new List<object>();

            if (File.Exists(queuePath))
            {
                try
                {
                    var existing = serializer.Deserialize<List<object>>(File.ReadAllText(queuePath, Encoding.UTF8));
                    if (existing != null)
                    {
                        queue = existing;
                    }
                }
                catch
                {
                }
            }

            queue.Add(payload);
            File.WriteAllText(queuePath, serializer.Serialize(queue), Encoding.UTF8);
        }

        private static void MigrateLegacyPendingFile(string actionDir)
        {
            var legacyPath = Path.Combine(actionDir, LegacyFileName);
            if (!File.Exists(legacyPath))
            {
                return;
            }

            try
            {
                var raw = File.ReadAllText(legacyPath, Encoding.UTF8);
                var serializer = new JavaScriptSerializer();
                var payload = serializer.DeserializeObject(raw);
                if (payload != null)
                {
                    AppendToQueue(actionDir, payload);
                    ReliabilityLog("Migrate", "Moved legacy pending-action.json to queue");
                }
            }
            catch
            {
            }
        }

        private static void ClearLegacyPendingFile(string actionDir)
        {
            var legacyPath = Path.Combine(actionDir, LegacyFileName);
            if (File.Exists(legacyPath))
            {
                try { File.Delete(legacyPath); } catch { }
            }
        }

        private static void ClearLockOnStartup(string actionDir)
        {
            var lockPath = Path.Combine(actionDir, LockFileName);
            if (File.Exists(lockPath))
            {
                try
                {
                    File.Delete(lockPath);
                    ReliabilityLog("Recovery", "Cleared operation.lock on startup/reset");
                }
                catch
                {
                }
            }
        }

        private static bool IsLockActivelyHeld(string lockPath)
        {
            try
            {
                var ageSeconds = (DateTime.UtcNow - File.GetLastWriteTimeUtc(lockPath)).TotalSeconds;
                return ageSeconds < 15;
            }
            catch
            {
                return false;
            }
        }

        private static void ClearStaleLock(string actionDir)
        {
            var lockPath = Path.Combine(actionDir, LockFileName);
            if (File.Exists(lockPath) && IsLockStale(lockPath))
            {
                try
                {
                    File.Delete(lockPath);
                    ReliabilityLog("Recovery", "Removed stale operation.lock");
                }
                catch
                {
                }
            }
        }

        private static bool IsLockStale(string lockPath)
        {
            try
            {
                return (DateTime.UtcNow - File.GetLastWriteTimeUtc(lockPath)).TotalSeconds > StaleLockSeconds;
            }
            catch
            {
                return true;
            }
        }

        private static bool VerifyScheduledTask(string taskName)
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

                    process.WaitForExit(5000);
                    return process.ExitCode == 0;
                }
            }
            catch
            {
                return false;
            }
        }

        private static void ReliabilityLog(string category, string detail)
        {
            try
            {
                var logDir = GetActionDirectory();
                if (!Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }

                var line = string.Format(
                    "{0:yyyy-MM-dd HH:mm:ss.fff}\t{1}\t{2}{3}",
                    DateTime.Now,
                    category,
                    detail,
                    Environment.NewLine);

                File.AppendAllText(Path.Combine(logDir, "reliability.log"), line, Encoding.UTF8);
            }
            catch
            {
            }
        }
    }
}
