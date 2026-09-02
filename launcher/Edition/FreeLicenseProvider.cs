namespace EthernetToggle.Edition
{
    internal sealed class FreeLicenseProvider : ILicenseProvider
    {
        public LicenseState GetState()
        {
            return LicenseState.Free;
        }

        public string GetEditionDisplayName()
        {
            return "Link Priority";
        }
    }
}
