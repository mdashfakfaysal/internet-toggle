using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using EthernetToggle.Pro;

namespace EthernetToggle.UI
{
    internal sealed class ProfilesForm : Form
    {
        private readonly ProDataStore _store;
        private readonly Func<System.Collections.Generic.IList<NetworkAdapterSnapshot>> _getAdapters;
        private readonly Action<NetworkProfile> _applyProfile;
        private readonly ListBox _profileList;
        private readonly TextBox _nameBox;
        private readonly Label _detailLabel;

        public ProfilesForm(
            ProDataStore store,
            Func<System.Collections.Generic.IList<NetworkAdapterSnapshot>> getAdapters,
            Action<NetworkProfile> applyProfile)
        {
            _store = store;
            _getAdapters = getAdapters;
            _applyProfile = applyProfile;

            Text = "Network Profiles";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(460, 360);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var title = new Label
            {
                Text = "Saved network profiles",
                Font = new Font("Segoe UI", 12f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(20, 16)
            };

            _profileList = new ListBox
            {
                Location = new Point(20, 48),
                Size = new Size(420, 140),
                BackColor = Color.FromArgb(45, 45, 45),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            _profileList.SelectedIndexChanged += (s, e) => UpdateDetail();

            _nameBox = new TextBox
            {
                Location = new Point(20, 204),
                Size = new Size(300, 24),
                BackColor = Color.FromArgb(45, 45, 45),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };

            _detailLabel = new Label
            {
                Location = new Point(20, 236),
                Size = new Size(420, 48),
                ForeColor = Color.FromArgb(170, 170, 170),
                Font = new Font("Segoe UI", 8.75f)
            };

            var saveButton = CreateButton("Save current", 20, 300, (s, e) => SaveCurrentProfile());
            var applyButton = CreateButton("Apply", 140, 300, (s, e) => ApplySelectedProfile());
            var deleteButton = CreateButton("Delete", 230, 300, (s, e) => DeleteSelectedProfile());
            var closeButton = CreateButton("Close", 352, 300, (s, e) => Close());
            closeButton.DialogResult = DialogResult.OK;

            Controls.Add(title);
            Controls.Add(_profileList);
            Controls.Add(_nameBox);
            Controls.Add(_detailLabel);
            Controls.Add(saveButton);
            Controls.Add(applyButton);
            Controls.Add(deleteButton);
            Controls.Add(closeButton);

            ReloadProfiles();
        }

        private Button CreateButton(string text, int left, int top, EventHandler onClick)
        {
            var button = new Button
            {
                Text = text,
                Size = new Size(96, 30),
                Location = new Point(left, top),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White
            };
            button.FlatAppearance.BorderColor = Color.FromArgb(90, 90, 90);
            button.Click += onClick;
            return button;
        }

        private void ReloadProfiles()
        {
            _profileList.Items.Clear();
            foreach (var profile in _store.Profiles.profiles)
            {
                _profileList.Items.Add(profile);
            }

            _profileList.DisplayMember = "name";
            if (_profileList.Items.Count > 0)
            {
                _profileList.SelectedIndex = 0;
            }
        }

        private NetworkProfile GetSelectedProfile()
        {
            return _profileList.SelectedItem as NetworkProfile;
        }

        private void UpdateDetail()
        {
            var profile = GetSelectedProfile();
            if (profile == null)
            {
                _detailLabel.Text = "Select a profile or save the current adapter state.";
                return;
            }

            _nameBox.Text = profile.name;
            var enabled = string.Join(", ", profile.adapters.Where(a => a.enabled).Select(a => a.name));
            var disabled = string.Join(", ", profile.adapters.Where(a => !a.enabled).Select(a => a.name));
            _detailLabel.Text = "Enabled: " + (string.IsNullOrEmpty(enabled) ? "none" : enabled) +
                                 Environment.NewLine +
                                 "Disabled: " + (string.IsNullOrEmpty(disabled) ? "none" : disabled);
        }

        private void SaveCurrentProfile()
        {
            var name = _nameBox.Text.Trim();
            if (string.IsNullOrWhiteSpace(name))
            {
                MessageBox.Show(this, "Enter a profile name.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                return;
            }

            var adapters = _getAdapters();
            var preferredAdapter = adapters.FirstOrDefault(a => a.IsConnected);
            var preferred = preferredAdapter != null ? preferredAdapter.Name : string.Empty;
            if (string.IsNullOrEmpty(preferred))
            {
                var enabledAdapter = adapters.FirstOrDefault(a => a.IsEnabled);
                preferred = enabledAdapter != null ? enabledAdapter.Name : string.Empty;
            }
            _store.CreateProfileFromAdapters(name, adapters, preferred);
            ReloadProfiles();
        }

        private void ApplySelectedProfile()
        {
            var profile = GetSelectedProfile();
            if (profile == null)
            {
                return;
            }

            _applyProfile(profile);
        }

        private void DeleteSelectedProfile()
        {
            var profile = GetSelectedProfile();
            if (profile == null)
            {
                return;
            }

            _store.DeleteProfile(profile.id);
            ReloadProfiles();
        }
    }
}
