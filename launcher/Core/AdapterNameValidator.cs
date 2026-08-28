using System;
using System.Text.RegularExpressions;

namespace EthernetToggle.Core
{
    internal static class AdapterNameValidator
    {
        private static readonly Regex ValidAdapterName =
            new Regex(@"^[A-Za-z0-9 \-_\(\)\[\]\.#]+$", RegexOptions.Compiled);

        public static bool IsValid(string adapterName)
        {
            if (string.IsNullOrWhiteSpace(adapterName))
            {
                return false;
            }

            if (adapterName.Length > 128)
            {
                return false;
            }

            return ValidAdapterName.IsMatch(adapterName);
        }

        public static string ValidateOrThrow(string adapterName)
        {
            if (!IsValid(adapterName))
            {
                throw new ArgumentException("Invalid adapter name.", "adapterName");
            }

            return adapterName;
        }
    }
}
