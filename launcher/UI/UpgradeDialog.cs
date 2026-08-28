using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using EthernetToggle.Core;
using EthernetToggle.Edition;

namespace EthernetToggle.UI
{
    internal sealed class UpgradeDialog : Form
    {
        public UpgradeDialog(string repoRoot, Feature feature)
        {
            var version = AppVersionInfo.Load(repoRoot);

            Text = "Internet Switcher Pro";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(440, 220);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var title = new Label
            {
                Text = "Upgrade to Pro",
                Font = new Font("Segoe UI", 13f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(20, 18)
            };

            var message = new Label
            {
                Text = GetFeatureMessage(feature),
                Font = new Font("Segoe UI", 9.25f),
                ForeColor = Color.FromArgb(200, 200, 200),
                AutoSize = false,
                Size = new Size(400, 72),
                Location = new Point(20, 52)
            };

            var learn = new Button
            {
                Text = "Learn more",
                Size = new Size(100, 30),
                Location = new Point(20, 168),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White
            };
            learn.FlatAppearance.BorderColor = Color.FromArgb(90, 90, 90);
            learn.Click += (s, e) =>
            {
                try
                {
                    Process.Start(new ProcessStartInfo(version.githubRepo) { UseShellExecute = true });
                }
                catch
                {
                }
            };

            var close = new Button
            {
                Text = "Not now",
                DialogResult = DialogResult.OK,
                Size = new Size(88, 30),
                Location = new Point(332, 168),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White
            };
            close.FlatAppearance.BorderSize = 0;

            Controls.Add(title);
            Controls.Add(message);
            Controls.Add(learn);
            Controls.Add(close);
            AcceptButton = close;
        }

        private static string GetFeatureMessage(Feature feature)
        {
            switch (feature)
            {
                case Feature.MultipleProfiles:
                    return "Save and switch between multiple network profiles. Available in Internet Switcher Pro.";
                case Feature.AutomaticFailover:
                    return "Automatically switch between Ethernet and Wi-Fi when a connection drops. Available in Pro.";
                case Feature.Schedules:
                    return "Schedule adapter changes for specific times. Available in Pro.";
                case Feature.ConnectionHistory:
                    return "View connection status history and diagnostics. Available in Pro.";
                default:
                    return "This feature is part of Internet Switcher Pro — automation, profiles, and advanced controls.";
            }
        }
    }
}
