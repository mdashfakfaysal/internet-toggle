using System;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Windows.Forms;
using EthernetToggle.Edition;
using EthernetToggle.Pro;

namespace EthernetToggle.UI
{
    internal sealed class ProSettingsForm : Form
    {
        private readonly ProDataStore _store;
        private readonly UserSettings _settings;
        private readonly Action<UserSettings> _onSettingsChanged;
        private readonly Action _onHotkeysChanged;
        private readonly string _appVersion;

        private CheckBox _startupCheck;
        private CheckBox _minimizedCheck;
        private CheckBox _failoverEthDown;
        private CheckBox _failoverWifiDown;
        private CheckBox _ruleEthDisableWifi;
        private CheckBox _ruleWifiDisableEth;
        private CheckBox[] _scheduleEnabled;
        private TextBox[] _scheduleTime;
        private ComboBox[] _scheduleAction;
        private ComboBox[] _scheduleProfile;
        private Label[] _hotkeyLabels;

        public ProSettingsForm(
            ProDataStore store,
            UserSettings settings,
            Action<UserSettings> onSettingsChanged,
            Action onHotkeysChanged,
            string appVersion,
            string appName)
        {
            _store = store;
            _settings = settings;
            _onSettingsChanged = onSettingsChanged;
            _onHotkeysChanged = onHotkeysChanged;
            _appVersion = appVersion;

            Text = appName + " Pro Settings";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(520, 420);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var tabs = new TabControl
            {
                Dock = DockStyle.Top,
                Height = 360,
                Font = new Font("Segoe UI", 9f)
            };

            tabs.TabPages.Add(BuildGeneralTab());
            tabs.TabPages.Add(BuildAutomationTab());
            tabs.TabPages.Add(BuildHotkeysTab());
            tabs.TabPages.Add(BuildSchedulesTab());
            tabs.TabPages.Add(BuildDataTab());

            var close = new Button
            {
                Text = "Close",
                DialogResult = DialogResult.OK,
                Size = new Size(88, 30),
                Location = new Point(412, 376),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White
            };
            close.FlatAppearance.BorderSize = 0;
            close.Click += (s, e) => SaveAll();

            Controls.Add(tabs);
            Controls.Add(close);
            AcceptButton = close;
        }

        private TabPage BuildGeneralTab()
        {
            var page = CreateTab("General");
            _startupCheck = CreateCheck(page, "Launch at Windows startup", 16, _settings.launchAtStartup);
            CreateHint(page, "Adds or removes the Startup folder shortcut.", 38);
            _minimizedCheck = CreateCheck(page, "Start minimized to tray", 72, _settings.startMinimizedToTray);
            CreateHint(page, "On launch, show only the tray icon.", 94);

            var proBadge = new Label
            {
                Text = "Internet Switcher Pro — automation, profiles, hotkeys, and history enabled.",
                Location = new Point(16, 140),
                Size = new Size(460, 40),
                ForeColor = Color.FromArgb(120, 190, 255),
                Font = new Font("Segoe UI", 9f, FontStyle.Bold)
            };
            page.Controls.Add(proBadge);
            return page;
        }

        private TabPage BuildAutomationTab()
        {
            var page = CreateTab("Automation");
            var failoverTitle = CreateSection(page, "Automatic failover", 12);
            _failoverEthDown = CreateCheck(page, "When Ethernet disconnects, switch to Wi-Fi", 36, _store.Settings.failover.ethernetDownSwitchToWifi);
            _failoverWifiDown = CreateCheck(page, "When Wi-Fi disconnects, switch to Ethernet", 62, _store.Settings.failover.wifiDownSwitchToEthernet);

            var rulesTitle = CreateSection(page, "Per-adapter rules", 100);
            _ruleEthDisableWifi = CreateCheck(page, "When Ethernet is connected, disable Wi-Fi", 124, _store.Settings.rules.ethernetConnectedDisableWifi);
            _ruleWifiDisableEth = CreateCheck(page, "When Wi-Fi is connected, disable Ethernet", 150, _store.Settings.rules.wifiConnectedDisableEthernet);
            return page;
        }

        private TabPage BuildHotkeysTab()
        {
            var page = CreateTab("Hotkeys");
            _hotkeyLabels = new Label[5];
            var bindings = new[]
            {
                _store.Settings.hotkeys.switchEthernet,
                _store.Settings.hotkeys.switchWifi,
                _store.Settings.hotkeys.toggleEthernet,
                _store.Settings.hotkeys.applyProfile1,
                _store.Settings.hotkeys.applyProfile2
            };
            var names = new[] { "Switch to Ethernet", "Switch to Wi-Fi", "Toggle Ethernet", "Apply Profile 1", "Apply Profile 2" };

            for (var i = 0; i < names.Length; i++)
            {
                var top = 16 + (i * 44);
                page.Controls.Add(new Label
                {
                    Text = names[i],
                    Location = new Point(16, top),
                    Size = new Size(180, 20),
                    ForeColor = Color.White
                });

                _hotkeyLabels[i] = new Label
                {
                    Text = HotkeyCaptureForm.FormatBinding(bindings[i]),
                    Location = new Point(200, top),
                    Size = new Size(180, 20),
                    ForeColor = Color.FromArgb(170, 170, 170)
                };
                page.Controls.Add(_hotkeyLabels[i]);

                var index = i;
                var change = CreateSmallButton("Change", 390, top - 2);
                change.Click += (s, e) => ChangeHotkey(index);
                page.Controls.Add(change);
            }

            return page;
        }

        private TabPage BuildSchedulesTab()
        {
            var page = CreateTab("Schedules");
            _scheduleEnabled = new CheckBox[2];
            _scheduleTime = new TextBox[2];
            _scheduleAction = new ComboBox[2];
            _scheduleProfile = new ComboBox[2];

            for (var i = 0; i < 2; i++)
            {
                var schedule = _store.Settings.schedules[i];
                var top = 16 + (i * 92);
                _scheduleEnabled[i] = CreateCheck(page, "Enable schedule " + (i + 1), top, schedule.enabled);

                page.Controls.Add(new Label { Text = "Time (HH:mm)", Location = new Point(16, top + 28), AutoSize = true, ForeColor = Color.FromArgb(170, 170, 170) });
                _scheduleTime[i] = new TextBox
                {
                    Text = schedule.time ?? "08:00",
                    Location = new Point(110, top + 24),
                    Size = new Size(60, 24),
                    BackColor = Color.FromArgb(45, 45, 45),
                    ForeColor = Color.White
                };
                page.Controls.Add(_scheduleTime[i]);

                _scheduleAction[i] = new ComboBox
                {
                    Location = new Point(190, top + 24),
                    Size = new Size(130, 24),
                    DropDownStyle = ComboBoxStyle.DropDownList,
                    BackColor = Color.FromArgb(45, 45, 45),
                    ForeColor = Color.White
                };
                _scheduleAction[i].Items.AddRange(new object[] { "SwitchEthernet", "SwitchWifi", "ApplyProfile" });
                _scheduleAction[i].SelectedItem = string.IsNullOrEmpty(schedule.action) ? "SwitchEthernet" : schedule.action;
                page.Controls.Add(_scheduleAction[i]);

                _scheduleProfile[i] = new ComboBox
                {
                    Location = new Point(330, top + 24),
                    Size = new Size(150, 24),
                    DropDownStyle = ComboBoxStyle.DropDownList,
                    BackColor = Color.FromArgb(45, 45, 45),
                    ForeColor = Color.White
                };
                foreach (var profile in _store.Profiles.profiles)
                {
                    _scheduleProfile[i].Items.Add(profile);
                }

                _scheduleProfile[i].DisplayMember = "name";
                if (!string.IsNullOrEmpty(schedule.profileId))
                {
                    var selected = _store.GetProfileById(schedule.profileId);
                    if (selected != null)
                    {
                        _scheduleProfile[i].SelectedItem = selected;
                    }
                }

                page.Controls.Add(_scheduleProfile[i]);
            }

            page.Controls.Add(new Label
            {
                Text = "Schedules run once per day at the specified minute.",
                Location = new Point(16, 210),
                Size = new Size(460, 32),
                ForeColor = Color.FromArgb(140, 140, 140)
            });
            return page;
        }

        private TabPage BuildDataTab()
        {
            var page = CreateTab("Data");
            var export = CreateSmallButton("Export config...", 16, 20);
            export.Size = new Size(120, 30);
            export.Click += (s, e) => ExportConfig();

            var import = CreateSmallButton("Import config...", 150, 20);
            import.Size = new Size(120, 30);
            import.Click += (s, e) => ImportConfig();

            var history = CreateSmallButton("View history", 16, 70);
            history.Size = new Size(120, 30);
            history.Click += (s, e) =>
            {
                using (var form = new HistoryForm(_store))
                {
                    form.ShowDialog(this);
                }
            };

            page.Controls.Add(export);
            page.Controls.Add(import);
            page.Controls.Add(history);
            page.Controls.Add(new Label
            {
                Text = "Export includes profiles, automation settings, hotkeys, schedules, and startup preferences.",
                Location = new Point(16, 120),
                Size = new Size(460, 48),
                ForeColor = Color.FromArgb(170, 170, 170)
            });
            return page;
        }

        private void ChangeHotkey(int index)
        {
            HotkeyBinding current;
            switch (index)
            {
                case 0: current = _store.Settings.hotkeys.switchEthernet; break;
                case 1: current = _store.Settings.hotkeys.switchWifi; break;
                case 2: current = _store.Settings.hotkeys.toggleEthernet; break;
                case 3: current = _store.Settings.hotkeys.applyProfile1; break;
                default: current = _store.Settings.hotkeys.applyProfile2; break;
            }

            using (var capture = new HotkeyCaptureForm(current))
            {
                if (capture.ShowDialog(this) != DialogResult.OK || capture.ResultBinding == null)
                {
                    return;
                }

                switch (index)
                {
                    case 0: _store.Settings.hotkeys.switchEthernet = capture.ResultBinding; break;
                    case 1: _store.Settings.hotkeys.switchWifi = capture.ResultBinding; break;
                    case 2: _store.Settings.hotkeys.toggleEthernet = capture.ResultBinding; break;
                    case 3: _store.Settings.hotkeys.applyProfile1 = capture.ResultBinding; break;
                    default: _store.Settings.hotkeys.applyProfile2 = capture.ResultBinding; break;
                }

                _hotkeyLabels[index].Text = HotkeyCaptureForm.FormatBinding(capture.ResultBinding);
                _store.SaveSettings();
                if (_onHotkeysChanged != null) _onHotkeysChanged();
            }
        }

        private void ExportConfig()
        {
            using (var dialog = new SaveFileDialog
            {
                Filter = "Internet Switcher config (*.json)|*.json",
                FileName = "internet-switcher-pro-config.json"
            })
            {
                if (dialog.ShowDialog(this) != DialogResult.OK)
                {
                    return;
                }

                File.WriteAllText(dialog.FileName, _store.ExportBundle(_appVersion, _settings.launchAtStartup, _settings.startMinimizedToTray));
                MessageBox.Show(this, "Configuration exported.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
        }

        private void ImportConfig()
        {
            using (var dialog = new OpenFileDialog { Filter = "Internet Switcher config (*.json)|*.json" })
            {
                if (dialog.ShowDialog(this) != DialogResult.OK)
                {
                    return;
                }

                _store.ImportBundle(File.ReadAllText(dialog.FileName), (launch, minimized) =>
                {
                    _settings.launchAtStartup = launch;
                    _settings.startMinimizedToTray = minimized;
                });

                MessageBox.Show(this, "Configuration imported. Reopen settings to refresh fields.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
                if (_onSettingsChanged != null) _onSettingsChanged(_settings);
                if (_onHotkeysChanged != null) _onHotkeysChanged();
            }
        }

        private void SaveAll()
        {
            _settings.launchAtStartup = _startupCheck.Checked;
            _settings.startMinimizedToTray = _minimizedCheck.Checked;
            _store.Settings.failover.ethernetDownSwitchToWifi = _failoverEthDown.Checked;
            _store.Settings.failover.wifiDownSwitchToEthernet = _failoverWifiDown.Checked;
            _store.Settings.rules.ethernetConnectedDisableWifi = _ruleEthDisableWifi.Checked;
            _store.Settings.rules.wifiConnectedDisableEthernet = _ruleWifiDisableEth.Checked;

            for (var i = 0; i < 2; i++)
            {
                var schedule = _store.Settings.schedules[i];
                schedule.enabled = _scheduleEnabled[i].Checked;
                schedule.time = _scheduleTime[i].Text.Trim();
                schedule.action = _scheduleAction[i].SelectedItem != null ? _scheduleAction[i].SelectedItem.ToString() : "SwitchEthernet";
                var profile = _scheduleProfile[i].SelectedItem as NetworkProfile;
                schedule.profileId = profile != null ? profile.id : null;
            }

            _store.SaveSettings();
            if (_onSettingsChanged != null) _onSettingsChanged(_settings);
        }

        private static TabPage CreateTab(string title)
        {
            return new TabPage(title) { BackColor = Color.FromArgb(30, 30, 30), ForeColor = Color.White };
        }

        private static Label CreateSection(Control parent, string text, int top)
        {
            var label = new Label
            {
                Text = text,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                Location = new Point(16, top),
                AutoSize = true,
                ForeColor = Color.White
            };
            parent.Controls.Add(label);
            return label;
        }

        private static CheckBox CreateCheck(Control parent, string text, int top, bool isChecked)
        {
            var box = new CheckBox
            {
                Text = text,
                Checked = isChecked,
                AutoSize = true,
                Location = new Point(16, top),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9f)
            };
            parent.Controls.Add(box);
            return box;
        }

        private static Label CreateHint(Control parent, string text, int top)
        {
            var label = new Label
            {
                Text = text,
                Location = new Point(34, top),
                Size = new Size(440, 24),
                ForeColor = Color.FromArgb(150, 150, 150),
                Font = new Font("Segoe UI", 8.25f)
            };
            parent.Controls.Add(label);
            return label;
        }

        private static Button CreateSmallButton(string text, int left, int top)
        {
            var button = new Button
            {
                Text = text,
                Size = new Size(72, 26),
                Location = new Point(left, top),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White
            };
            button.FlatAppearance.BorderColor = Color.FromArgb(90, 90, 90);
            return button;
        }
    }
}
