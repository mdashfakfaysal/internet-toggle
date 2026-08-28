using System.Collections.Generic;

namespace EthernetToggle.Edition
{
    internal static class EditionService
    {
        private static readonly HashSet<Feature> FreeFeatures = new HashSet<Feature>
        {
            Feature.AdapterToggle,
            Feature.AdapterStatus,
            Feature.QuickSwitch,
            Feature.SystemTray,
            Feature.LaunchAtStartup,
            Feature.StartMinimizedToTray,
            Feature.ManualRefresh,
            Feature.BasicHotkey
        };

        private static readonly HashSet<Feature> ProOnlyFeatures = new HashSet<Feature>
        {
            Feature.MultipleProfiles,
            Feature.NetworkPriorities,
            Feature.AutomaticFailover,
            Feature.AdvancedHotkeys,
            Feature.Schedules,
            Feature.ConnectionRules,
            Feature.PerAdapterRules,
            Feature.AutoActionsOnAvailability,
            Feature.CustomProfileNaming,
            Feature.ImportExportConfig,
            Feature.ConnectionHistory,
            Feature.DiagnosticLogs,
            Feature.CliCommands,
            Feature.AdvancedTrayActions,
            Feature.VpnAutomationHooks,
            Feature.AutomationEngine
        };

        private static ILicenseProvider _provider;

        public static void Initialize(ILicenseProvider provider)
        {
            _provider = provider;
        }

        public static ILicenseProvider Provider
        {
            get { return _provider ?? CreateDefaultProvider(); }
        }

        public static bool CanUseFeature(Feature feature)
        {
            if (FreeFeatures.Contains(feature))
            {
                return true;
            }

            if (!ProOnlyFeatures.Contains(feature))
            {
                return false;
            }

            var state = Provider.GetState();
            return state == LicenseState.Pro ||
                   state == LicenseState.Trial ||
                   state == LicenseState.OfflineGracePeriod;
        }

        public static bool IsProEdition()
        {
            return CanUseFeature(Feature.MultipleProfiles);
        }

        public static string GetEditionLabel()
        {
            return Provider.GetEditionDisplayName();
        }

        private static ILicenseProvider CreateDefaultProvider()
        {
#if INTERNET_SWITCHER_PRO
            return new ProLicenseProvider();
#elif DEBUG
            return new DevLicenseProvider();
#else
            return new FreeLicenseProvider();
#endif
        }
    }
}
