using System;
using System.Collections.Generic;

namespace EthernetToggle.Pro
{
    internal sealed class AdapterProfileState
    {
        public string name { get; set; }
        public bool enabled { get; set; }
    }

    internal sealed class NetworkProfile
    {
        public string id { get; set; }
        public string name { get; set; }
        public string preferred { get; set; }
        public List<AdapterProfileState> adapters { get; set; }

        public NetworkProfile()
        {
            adapters = new List<AdapterProfileState>();
        }
    }

    internal sealed class ProfileCollection
    {
        public List<NetworkProfile> profiles { get; set; }

        public ProfileCollection()
        {
            profiles = new List<NetworkProfile>();
        }
    }

    internal sealed class HotkeyBinding
    {
        public int key { get; set; }
        public uint modifiers { get; set; }
        public bool enabled { get; set; }
    }

    internal sealed class ProSchedule
    {
        public bool enabled { get; set; }
        public string time { get; set; }
        public string action { get; set; }
        public string profileId { get; set; }
        public string lastRunDate { get; set; }
    }

    internal sealed class FailoverSettings
    {
        public bool ethernetDownSwitchToWifi { get; set; }
        public bool wifiDownSwitchToEthernet { get; set; }
    }

    internal sealed class RuleSettings
    {
        public bool ethernetConnectedDisableWifi { get; set; }
        public bool wifiConnectedDisableEthernet { get; set; }
    }

    internal sealed class ProHotkeySettings
    {
        public HotkeyBinding switchEthernet { get; set; }
        public HotkeyBinding switchWifi { get; set; }
        public HotkeyBinding toggleEthernet { get; set; }
        public HotkeyBinding applyProfile1 { get; set; }
        public HotkeyBinding applyProfile2 { get; set; }

        public ProHotkeySettings()
        {
            switchEthernet = HotkeyDefaults(0x45);
            switchWifi = HotkeyDefaults(0x57);
            toggleEthernet = HotkeyDefaults(0x54);
            applyProfile1 = HotkeyDefaults(0x31);
            applyProfile2 = HotkeyDefaults(0x32);
        }

        private static HotkeyBinding HotkeyDefaults(int virtualKey)
        {
            return new HotkeyBinding
            {
                key = virtualKey,
                modifiers = 0x0001 | 0x0002,
                enabled = true
            };
        }
    }

    internal sealed class ProSettings
    {
        public FailoverSettings failover { get; set; }
        public RuleSettings rules { get; set; }
        public ProHotkeySettings hotkeys { get; set; }
        public List<ProSchedule> schedules { get; set; }

        public ProSettings()
        {
            failover = new FailoverSettings();
            rules = new RuleSettings();
            hotkeys = new ProHotkeySettings();
            schedules = new List<ProSchedule>
            {
                new ProSchedule { enabled = false, time = "08:00", action = "SwitchEthernet" },
                new ProSchedule { enabled = false, time = "18:00", action = "SwitchWifi" }
            };
        }
    }

    internal sealed class HistoryEntry
    {
        public string timestamp { get; set; }
        public string action { get; set; }
        public string detail { get; set; }
        public string source { get; set; }
    }

    internal sealed class ConnectionHistory
    {
        public List<HistoryEntry> entries { get; set; }

        public ConnectionHistory()
        {
            entries = new List<HistoryEntry>();
        }
    }

    internal sealed class ProExportBundle
    {
        public string version { get; set; }
        public string exportedAt { get; set; }
        public ProfileCollection profiles { get; set; }
        public ProSettings proSettings { get; set; }
        public bool launchAtStartup { get; set; }
        public bool startMinimizedToTray { get; set; }
    }
}
