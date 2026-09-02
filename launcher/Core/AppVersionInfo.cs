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
                productName = "Link Priority",
                freeDisplayName = "Link Priority",
                proDisplayName = "Link Priority",
                version = "2.1.0",
                assemblyVersion = "2.1.0.0",
                fileVersion = "2.1.0.0",
                company = "IT Doctor 360",
                copyright = "Copyright (c) 2026",
                githubRepo = "https://github.com/mdashfakfaysal/internet-toggle"
            };
        }
    }
}
