using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace EthernetToggle.Pro
{
    internal sealed class ProDataStore
    {
        private const int MaxHistoryEntries = 200;
        private readonly string _baseDir;
        private readonly string _profilesPath;
        private readonly string _historyPath;
        private readonly string _proSettingsPath;
        private readonly JavaScriptSerializer _serializer = new JavaScriptSerializer();

        public ProfileCollection Profiles { get; private set; }
        public ConnectionHistory History { get; private set; }
        public ProSettings Settings { get; private set; }

        public ProDataStore()
        {
            _baseDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "InternetToggle");
            _profilesPath = Path.Combine(_baseDir, "profiles.json");
            _historyPath = Path.Combine(_baseDir, "history.json");
            _proSettingsPath = Path.Combine(_baseDir, "pro-settings.json");
            _serializer.MaxJsonLength = int.MaxValue;

            Profiles = LoadFile(_profilesPath, new ProfileCollection());
            History = LoadFile(_historyPath, new ConnectionHistory());
            Settings = LoadFile(_proSettingsPath, new ProSettings());
        }

        public void SaveProfiles()
        {
            SaveFile(_profilesPath, Profiles);
        }

        public void SaveHistory()
        {
            SaveFile(_historyPath, History);
        }

        public void SaveSettings()
        {
            SaveFile(_proSettingsPath, Settings);
        }

        public void AddHistory(string action, string detail, string source)
        {
            History.entries.Insert(0, new HistoryEntry
            {
                timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
                action = action,
                detail = detail,
                source = source
            });

            if (History.entries.Count > MaxHistoryEntries)
            {
                History.entries = History.entries.Take(MaxHistoryEntries).ToList();
            }

            SaveHistory();
        }

        public NetworkProfile CreateProfileFromAdapters(string name, IList<NetworkAdapterSnapshot> adapters, string preferred)
        {
            var profile = new NetworkProfile
            {
                id = Guid.NewGuid().ToString("N"),
                name = name,
                preferred = preferred,
                adapters = adapters.Select(a => new AdapterProfileState
                {
                    name = a.Name,
                    enabled = a.IsEnabled
                }).ToList()
            };

            Profiles.profiles.Add(profile);
            SaveProfiles();
            return profile;
        }

        public void DeleteProfile(string profileId)
        {
            Profiles.profiles.RemoveAll(p => string.Equals(p.id, profileId, StringComparison.OrdinalIgnoreCase));
            SaveProfiles();
        }

        public NetworkProfile GetProfileById(string profileId)
        {
            return Profiles.profiles.FirstOrDefault(p => string.Equals(p.id, profileId, StringComparison.OrdinalIgnoreCase));
        }

        public NetworkProfile GetProfileByIndex(int index)
        {
            if (index < 0 || index >= Profiles.profiles.Count)
            {
                return null;
            }

            return Profiles.profiles[index];
        }

        public string ExportBundle(string appVersion, bool launchAtStartup, bool startMinimizedToTray)
        {
            var bundle = new ProExportBundle
            {
                version = appVersion,
                exportedAt = DateTime.Now.ToString("o"),
                profiles = Profiles,
                proSettings = Settings,
                launchAtStartup = launchAtStartup,
                startMinimizedToTray = startMinimizedToTray
            };

            return _serializer.Serialize(bundle);
        }

        public void ImportBundle(string json, Action<bool, bool> applyUserSettings)
        {
            var bundle = _serializer.Deserialize<ProExportBundle>(json);
            if (bundle == null)
            {
                throw new InvalidOperationException("Invalid import file.");
            }

            if (bundle.profiles != null)
            {
                Profiles = bundle.profiles;
                SaveProfiles();
            }

            if (bundle.proSettings != null)
            {
                Settings = bundle.proSettings;
                SaveSettings();
            }

            if (applyUserSettings != null)
            {
                applyUserSettings(bundle.launchAtStartup, bundle.startMinimizedToTray);
            }
        }

        private T LoadFile<T>(string path, T fallback) where T : class
        {
            if (!File.Exists(path))
            {
                return fallback;
            }

            try
            {
                return _serializer.Deserialize<T>(File.ReadAllText(path, Encoding.UTF8)) ?? fallback;
            }
            catch
            {
                return fallback;
            }
        }

        private void SaveFile<T>(string path, T data)
        {
            if (!Directory.Exists(_baseDir))
            {
                Directory.CreateDirectory(_baseDir);
            }

            File.WriteAllText(path, _serializer.Serialize(data), Encoding.UTF8);
        }
    }

    internal sealed class NetworkAdapterSnapshot
    {
        public string Name { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsConnected { get; set; }
    }
}
