using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using EthernetToggle.Core;
using EthernetToggle.Edition;

namespace EthernetToggle.UI
{
    internal sealed class AboutForm : Form
    {
        public AboutForm(string repoRoot)
        {
            var version = AppVersionInfo.Load(repoRoot);

            Text = "About";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(420, 260);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var title = new Label
            {
                Text = version.productName,
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(20, 20)
            };

            var edition = new Label
            {
                Text = EditionService.GetEditionLabel(),
                Font = new Font("Segoe UI", 10f),
                ForeColor = Color.FromArgb(170, 170, 170),
                AutoSize = true,
                Location = new Point(22, 52)
            };

            var versionLabel = new Label
            {
                Text = "Version " + version.GetDisplayVersion(),
                Font = new Font("Segoe UI", 9.5f),
                AutoSize = true,
                Location = new Point(22, 78)
            };

            var body = new Label
            {
                Text = "Controls which connection Windows uses by toggling your Ethernet adapter. Prioritize Wi-Fi disables Ethernet (Wi-Fi stays on). Prioritize Ethernet enables Ethernet and disconnects active Wi-Fi sessions without disabling the Wi-Fi adapter.",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(190, 190, 190),
                AutoSize = false,
                Size = new Size(380, 72),
                Location = new Point(22, 108)
            };

            var links = new Label
            {
                Text = version.githubRepo,
                Font = new Font("Segoe UI", 9f, FontStyle.Underline),
                ForeColor = Color.FromArgb(120, 180, 255),
                AutoSize = true,
                Location = new Point(22, 156),
                Cursor = Cursors.Hand
            };
            links.Click += (s, e) =>
            {
                try
                {
                    Process.Start(new ProcessStartInfo(version.githubRepo) { UseShellExecute = true });
                }
                catch
                {
                }
            };

            var copyright = new Label
            {
                Text = version.copyright,
                Font = new Font("Segoe UI", 8.25f),
                ForeColor = Color.FromArgb(130, 130, 130),
                AutoSize = true,
                Location = new Point(22, 182)
            };

            var close = new Button
            {
                Text = "Close",
                DialogResult = DialogResult.OK,
                Size = new Size(88, 30),
                Location = new Point(312, 214),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White
            };
            close.FlatAppearance.BorderSize = 0;

            Controls.Add(title);
            Controls.Add(edition);
            Controls.Add(versionLabel);
            Controls.Add(body);
            Controls.Add(links);
            Controls.Add(copyright);
            Controls.Add(close);
            AcceptButton = close;
        }
    }
}
