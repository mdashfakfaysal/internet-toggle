using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace EthernetToggle.Core
{
    internal enum AdapterKind
    {
        Unknown,
        WiFi,
        Ethernet,
        Other
    }

    internal sealed class ResolvedAdapters
    {
        public NetworkAdapterInfo WiFi { get; set; }
        public NetworkAdapterInfo Ethernet { get; set; }

        public string WiFiName
        {
            get { return WiFi != null ? WiFi.Name : null; }
        }

        public string EthernetName
        {
            get { return Ethernet != null ? Ethernet.Name : null; }
        }
    }

    internal static class AdapterDiscovery
    {
        public static AdapterKind Classify(string name, string description)
        {
            var combined = (name + " " + description).ToLowerInvariant();

            if (IsWiFi(combined))
            {
                return AdapterKind.WiFi;
            }

            if (IsEthernet(combined, name))
            {
                return AdapterKind.Ethernet;
            }

            return AdapterKind.Other;
        }

        public static ResolvedAdapters Resolve(IList<NetworkAdapterInfo> adapters, string wifiHint, string ethernetHint)
        {
            var physical = adapters.Where(a => !a.IsVirtual).ToList();

            var wifi = FindByHint(physical, wifiHint)
                       ?? FindBest(physical, AdapterKind.WiFi);

            var ethernet = FindByHint(physical, ethernetHint)
                           ?? FindBest(physical, AdapterKind.Ethernet);

            if (ethernet == null)
            {
                ethernet = FindBest(physical, AdapterKind.Ethernet);
            }

            if (wifi == null)
            {
                wifi = FindBest(physical, AdapterKind.WiFi);
            }

            return new ResolvedAdapters
            {
                WiFi = wifi,
                Ethernet = ethernet
            };
        }

        private static NetworkAdapterInfo FindByHint(IList<NetworkAdapterInfo> adapters, string hint)
        {
            if (string.IsNullOrWhiteSpace(hint))
            {
                return null;
            }

            return adapters.FirstOrDefault(a =>
                a.Name.Equals(hint, StringComparison.OrdinalIgnoreCase) && a.IsPresent)
                ?? adapters.FirstOrDefault(a =>
                    a.Name.Equals(hint, StringComparison.OrdinalIgnoreCase));
        }

        private static NetworkAdapterInfo FindBest(IList<NetworkAdapterInfo> adapters, AdapterKind kind)
        {
            return adapters
                .Where(a => Classify(a.Name, a.Description) == kind)
                .OrderBy(a => PresenceScore(a))
                .ThenBy(a => GhostNameScore(a.Name))
                .ThenByDescending(a => a.IsConnected)
                .ThenByDescending(a => a.IsEnabled)
                .ThenBy(a => a.Name)
                .FirstOrDefault();
        }

        private static int PresenceScore(NetworkAdapterInfo adapter)
        {
            if (!adapter.IsPresent)
            {
                return 10;
            }

            if (adapter.IsConnected)
            {
                return 0;
            }

            if (adapter.IsEnabled)
            {
                return 1;
            }

            return 2;
        }

        private static int GhostNameScore(string name)
        {
            if (string.Equals(name, "Wi-Fi", StringComparison.OrdinalIgnoreCase))
            {
                return 0;
            }

            if (Regex.IsMatch(name ?? string.Empty, @"^Wi-Fi\s+\d+$", RegexOptions.IgnoreCase))
            {
                return 2;
            }

            return 1;
        }

        private static bool IsWiFi(string combined)
        {
            return combined.IndexOf("wi-fi", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("wifi", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("wireless", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("wlan", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("802.11", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("mediaTek wireless", StringComparison.Ordinal) >= 0;
        }

        private static bool IsEthernet(string combined, string name)
        {
            if (combined.IndexOf("virtual", StringComparison.Ordinal) >= 0
                || name.StartsWith("vEthernet", StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            if (IsWiFi(combined))
            {
                return false;
            }

            return combined.IndexOf("ethernet", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("gbe", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("gigabit", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("realtek", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("asix", StringComparison.Ordinal) >= 0
                   || combined.IndexOf("usb", StringComparison.Ordinal) >= 0 && combined.IndexOf("rndis", StringComparison.Ordinal) < 0;
        }
    }
}
