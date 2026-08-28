using System;
using System.IO;
using System.Text;

namespace EthernetToggle.Core
{
    internal static class AppLogger
    {
        private static readonly object Sync = new object();
        private static bool _enabled = true;

        public static void SetEnabled(bool enabled)
        {
            _enabled = enabled;
        }

        public static void Info(string operation, string adapterName, bool success, string detail)
        {
            Write("INFO", operation, adapterName, success, detail);
        }

        public static void Error(string operation, string adapterName, string detail)
        {
            Write("ERROR", operation, adapterName, false, detail);
        }

        private static void Write(string level, string operation, string adapterName, bool success, string detail)
        {
            if (!_enabled)
            {
                return;
            }

            try
            {
                var logDir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "InternetToggle",
                    "logs");

                if (!Directory.Exists(logDir))
                {
                    Directory.CreateDirectory(logDir);
                }

                var safeAdapter = Sanitize(adapterName);
                var safeDetail = Sanitize(detail);
                var line = string.Format(
                    "{0:yyyy-MM-dd HH:mm:ss.fff}\t{1}\t{2}\t{3}\t{4}\t{5}",
                    DateTime.Now,
                    level,
                    AppVersionInfo.Load(AppDomain.CurrentDomain.BaseDirectory).GetDisplayVersion(),
                    Sanitize(operation),
                    safeAdapter,
                    success ? "OK" : "FAIL") + "\t" + safeDetail + Environment.NewLine;

                lock (Sync)
                {
                    File.AppendAllText(Path.Combine(logDir, "app.log"), line, Encoding.UTF8);
                }
            }
            catch
            {
            }
        }

        private static string Sanitize(string value)
        {
            if (string.IsNullOrEmpty(value))
            {
                return string.Empty;
            }

            return value.Replace('\t', ' ').Replace('\r', ' ').Replace('\n', ' ');
        }
    }
}
