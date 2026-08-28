namespace EthernetToggle.Edition
{
#if DEBUG
    internal sealed class DevLicenseProvider : ILicenseProvider
    {
        public LicenseState GetState()
        {
            var devPro = System.Environment.GetEnvironmentVariable("INTERNET_SWITCHER_DEV_PRO");
            if (string.Equals(devPro, "1", System.StringComparison.Ordinal) ||
                string.Equals(devPro, "true", System.StringComparison.OrdinalIgnoreCase))
            {
                return LicenseState.Pro;
            }

            return LicenseState.Free;
        }

        public string GetEditionDisplayName()
        {
            return GetState() == LicenseState.Pro
                ? "Internet Switcher Pro (Dev)"
                : "Internet Switcher Free (Dev)";
        }
    }
#endif

    internal sealed class ProLicenseProvider : ILicenseProvider
    {
        public LicenseState GetState()
        {
            return LicenseState.Pro;
        }

        public string GetEditionDisplayName()
        {
            return "Internet Switcher Pro";
        }
    }
}
