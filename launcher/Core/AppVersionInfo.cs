using System;
using System.IO;
using System.Web.Script.Serialization;

namespace EthernetToggle.Core
{
    internal sealed class AppVersionInfo
    {
        public string productName { get; set; }
        public string freeDisplayName { get; set; }
        public string proDisplayName { get; set; }
        public string version { get; set; }
        public string assemblyVersion { get; set; }
        public string fileVersion { get; set; }
        public string company { get; set; }
        public string copyright { get; set; }
        public string githubRepo { get; set; }

        public static AppVersionInfo Load(string repoRoot)
        {
            var path = Path.Combine(repoRoot, "version.json");
            if (!File.Exists(path))
            {
                return CreateFallback();
            }

            try
            {
                var json = File.ReadAllText(path);
                return new JavaScriptSerializer().Deserialize<AppVersionInfo>(json) ?? CreateFallback();
            }
            catch
            {
                return CreateFallback();
            }
        }

        public string GetDisplayVersion()
        {
            return string.IsNullOrWhiteSpace(version) ? "1.0.0" : version;
        }

        private static AppVersionInfo CreateFallback()
        {
            return new AppVersionInfo
            {
                productName = "Internet Switcher",
                freeDisplayName = "Internet Switcher Free",
                proDisplayName = "Internet Switcher Pro",
                version = "1.0.0",
                assemblyVersion = "1.0.0.0",
                fileVersion = "1.0.0.0",
                company = "Internet Switcher",
                copyright = "Copyright (c) 2026",
                githubRepo = "https://github.com/mdashfakfaysal/internet-toggle"
            };
        }
    }
}
