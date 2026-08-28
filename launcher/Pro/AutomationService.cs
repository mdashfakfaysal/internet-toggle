using System;
using System.Collections.Generic;
using System.Linq;

namespace EthernetToggle.Pro
{
    internal sealed class AutomationService
    {
        private readonly ProDataStore _store;
        private readonly AppConfigSnapshot _config;
        private bool _lastEthernetConnected;
        private bool _lastWifiConnected;
        private bool _initialized;

        public AutomationService(ProDataStore store, AppConfigSnapshot config)
        {
            _store = store;
            _config = config;
        }

        public AutomationResult Evaluate(IList<NetworkAdapterSnapshot> adapters, DateTime now)
        {
            var eth = FindAdapter(adapters, _config.ethernetAdapterName);
            var wifi = FindAdapter(adapters, _config.wifiAdapterName);

            if (!_initialized)
            {
                _lastEthernetConnected = eth != null && eth.IsConnected;
                _lastWifiConnected = wifi != null && wifi.IsConnected;
                _initialized = true;
                return AutomationResult.None;
            }

            var result = AutomationResult.None;

            result = Merge(result, EvaluateFailover(eth, wifi));
            result = Merge(result, EvaluateRules(eth, wifi));
            result = Merge(result, EvaluateSchedules(now));

            _lastEthernetConnected = eth != null && eth.IsConnected;
            _lastWifiConnected = wifi != null && wifi.IsConnected;
            return result;
        }

        private AutomationResult EvaluateFailover(NetworkAdapterSnapshot eth, NetworkAdapterSnapshot wifi)
        {
            var failover = _store.Settings.failover;
            if (failover == null)
            {
                return AutomationResult.None;
            }

            var ethConnected = eth != null && eth.IsConnected;
            var wifiConnected = wifi != null && wifi.IsConnected;

            if (failover.ethernetDownSwitchToWifi &&
                _lastEthernetConnected && !ethConnected &&
                (wifi == null || !wifi.IsEnabled || !wifiConnected))
            {
                return AutomationResult.SwitchWifi;
            }

            if (failover.wifiDownSwitchToEthernet &&
                _lastWifiConnected && !wifiConnected &&
                (eth == null || !eth.IsEnabled || !ethConnected))
            {
                return AutomationResult.SwitchEthernet;
            }

            return AutomationResult.None;
        }

        private AutomationResult EvaluateRules(NetworkAdapterSnapshot eth, NetworkAdapterSnapshot wifi)
        {
            var rules = _store.Settings.rules;
            if (rules == null)
            {
                return AutomationResult.None;
            }

            if (rules.ethernetConnectedDisableWifi &&
                eth != null && eth.IsConnected &&
                wifi != null && wifi.IsEnabled)
            {
                return AutomationResult.DisableWifi;
            }

            if (rules.wifiConnectedDisableEthernet &&
                wifi != null && wifi.IsConnected &&
                eth != null && eth.IsEnabled)
            {
                return AutomationResult.DisableEthernet;
            }

            return AutomationResult.None;
        }

        private AutomationResult EvaluateSchedules(DateTime now)
        {
            var schedules = _store.Settings.schedules;
            if (schedules == null)
            {
                return AutomationResult.None;
            }

            var today = now.ToString("yyyy-MM-dd");
            var current = now.ToString("HH:mm");

            foreach (var schedule in schedules.Where(s => s.enabled))
            {
                if (!string.Equals(schedule.time, current, StringComparison.Ordinal))
                {
                    continue;
                }

                if (string.Equals(schedule.lastRunDate, today, StringComparison.Ordinal))
                {
                    continue;
                }

                schedule.lastRunDate = today;
                _store.SaveSettings();

                if (string.Equals(schedule.action, "ApplyProfile", StringComparison.OrdinalIgnoreCase))
                {
                    return AutomationResult.ForProfile(schedule.profileId);
                }

                if (string.Equals(schedule.action, "SwitchEthernet", StringComparison.OrdinalIgnoreCase))
                {
                    return AutomationResult.SwitchEthernet;
                }

                if (string.Equals(schedule.action, "SwitchWifi", StringComparison.OrdinalIgnoreCase))
                {
                    return AutomationResult.SwitchWifi;
                }
            }

            return AutomationResult.None;
        }

        private static NetworkAdapterSnapshot FindAdapter(IList<NetworkAdapterSnapshot> adapters, string name)
        {
            return adapters.FirstOrDefault(a => a.Name.Equals(name, StringComparison.OrdinalIgnoreCase));
        }

        private static AutomationResult Merge(AutomationResult current, AutomationResult next)
        {
            return current.IsNone ? next : current;
        }
    }

    internal sealed class AutomationResult
    {
        public AutomationAction Action { get; private set; }
        public string ProfileId { get; private set; }

        public bool IsNone
        {
            get { return Action == AutomationAction.None; }
        }

        public static AutomationResult None
        {
            get { return new AutomationResult { Action = AutomationAction.None }; }
        }

        public static AutomationResult SwitchEthernet
        {
            get { return new AutomationResult { Action = AutomationAction.SwitchEthernet }; }
        }

        public static AutomationResult SwitchWifi
        {
            get { return new AutomationResult { Action = AutomationAction.SwitchWifi }; }
        }

        public static AutomationResult DisableWifi
        {
            get { return new AutomationResult { Action = AutomationAction.DisableWifi }; }
        }

        public static AutomationResult DisableEthernet
        {
            get { return new AutomationResult { Action = AutomationAction.DisableEthernet }; }
        }

        public static AutomationResult ForProfile(string profileId)
        {
            return new AutomationResult
            {
                Action = AutomationAction.ApplyProfile,
                ProfileId = profileId
            };
        }
    }

    internal enum AutomationAction
    {
        None,
        SwitchEthernet,
        SwitchWifi,
        DisableWifi,
        DisableEthernet,
        ApplyProfile
    }

    internal sealed class AppConfigSnapshot
    {
        public string ethernetAdapterName { get; set; }
        public string wifiAdapterName { get; set; }
    }
}
