namespace EthernetToggle.Edition
{
    internal interface ILicenseProvider
    {
        LicenseState GetState();
        string GetEditionDisplayName();
    }
}
