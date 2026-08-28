using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;
using EthernetToggle.Core;
using EthernetToggle.Edition;
using EthernetToggle.Pro;
using EthernetToggle.UI;

namespace EthernetToggle
{
    internal sealed class AppConfig
    {
        public string version { get; set; }
        public string adapterName { get; set; }
        public string ethernetAdapterName { get; set; }
        public string wifiAdapterName { get; set; }
        public string taskName { get; set; }
        public string appName { get; set; }
        public string exeName { get; set; }
        public string[] excludePatterns { get; set; }
        public bool launchAtStartup { get; set; }
        public bool startMinimizedToTray { get; set; }

        public static AppConfig Load(string configPath)
        {
            var defaults = CreateDefaults();
            if (!File.Exists(configPath))
            {
                return defaults;
            }

            try
            {
                var json = File.ReadAllText(configPath);
                var loaded = new JavaScriptSerializer().Deserialize<AppConfig>(json) ?? defaults;
                if (string.IsNullOrWhiteSpace(loaded.appName)) loaded.appName = defaults.appName;
                if (string.IsNullOrWhiteSpace(loaded.exeName)) loaded.exeName = defaults.exeName;
                if (string.IsNullOrWhiteSpace(loaded.taskName)) loaded.taskName = defaults.taskName;
                if (string.IsNullOrWhiteSpace(loaded.ethernetAdapterName))
                {
                    loaded.ethernetAdapterName = string.IsNullOrWhiteSpace(loaded.adapterName) ? defaults.ethernetAdapterName : loaded.adapterName;
                }
                if (string.IsNullOrWhiteSpace(loaded.wifiAdapterName)) loaded.wifiAdapterName = defaults.wifiAdapterName;
                if (string.IsNullOrWhiteSpace(loaded.adapterName)) loaded.adapterName = loaded.ethernetAdapterName;
                if (loaded.excludePatterns == null || loaded.excludePatterns.Length == 0) loaded.excludePatterns = defaults.excludePatterns;
                return loaded;
            }
            catch
            {
                return defaults;
            }
        }

        private static AppConfig CreateDefaults()
        {
            return new AppConfig
            {
                version = "1.4.0",
                adapterName = "Ethernet",
                ethernetAdapterName = "Ethernet",
                wifiAdapterName = "Wi-Fi",
                taskName = "ToggleInternetAdapter",
                appName = "Internet Toggle",
                exeName = "Internet Toggle",
                excludePatterns = new[] { "vEthernet", "Hyper-V" },
                launchAtStartup = true,
                startMinimizedToTray = true
            };
        }
    }

    internal sealed class UserSettings
    {
        public bool launchAtStartup { get; set; }
        public bool startMinimizedToTray { get; set; }

        public static UserSettings FromDefaults(AppConfig config)
        {
            return new UserSettings
            {
                launchAtStartup = config.launchAtStartup,
                startMinimizedToTray = config.startMinimizedToTray
            };
        }

        public static UserSettings Load(string settingsPath, AppConfig config)
        {
            var settings = FromDefaults(config);
            if (!File.Exists(settingsPath))
            {
                return settings;
            }

            try
            {
                var loaded = new JavaScriptSerializer().Deserialize<UserSettings>(File.ReadAllText(settingsPath));
                if (loaded == null)
                {
                    return settings;
                }

                settings.launchAtStartup = loaded.launchAtStartup;
                settings.startMinimizedToTray = loaded.startMinimizedToTray;
                return settings;
            }
            catch
            {
                return settings;
            }
        }

        public void Save(string settingsPath)
        {
            var dir = Path.GetDirectoryName(settingsPath);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            var json = new JavaScriptSerializer().Serialize(this);
            File.WriteAllText(settingsPath, json, Encoding.UTF8);
        }
    }

    internal static class StartupShortcutHelper
    {
        public static void ApplyLaunchAtStartup(bool enabled, AppConfig config, string exePath, string workingDirectory)
        {
            var shortcutPath = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.Startup),
                config.appName + ".lnk");

            if (enabled)
            {
                CreateShortcut(shortcutPath, exePath, workingDirectory, config.appName + " - internet adapter control", exePath + ",0");
                return;
            }

            if (File.Exists(shortcutPath))
            {
                File.Delete(shortcutPath);
            }
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string workingDirectory, string description, string iconLocation)
        {
            var shortcutType = Type.GetTypeFromProgID("WScript.Shell");
            if (shortcutType == null)
            {
                return;
            }

            dynamic shell = Activator.CreateInstance(shortcutType);
            dynamic shortcut = shell.CreateShortcut(shortcutPath);
            shortcut.TargetPath = targetPath;
            shortcut.Arguments = string.Empty;
            shortcut.WorkingDirectory = workingDirectory;
            shortcut.Description = description;
            shortcut.WindowStyle = 7;
            shortcut.IconLocation = iconLocation;
            shortcut.Save();
        }
    }

    internal sealed class NetworkAdapterInfo
    {
        public string Name { get; set; }
        public string Description { get; set; }
        public bool IsEnabled { get; set; }
        public bool IsConnected { get; set; }
        public bool IsVirtual { get; set; }
        public string ConnectionState { get; set; }
        public string StatusText { get; set; }
    }

    internal static class NativeMethods
    {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern bool DestroyIcon(IntPtr handle);
    }

    internal static class AdapterHelper
    {
        private sealed class MsftAdapterState
        {
            public int MediaConnectState { get; set; }
            public string InterfaceDescription { get; set; }
            public bool Virtual { get; set; }
        }

        public static IList<NetworkAdapterInfo> GetAdapters(AppConfig config, bool includeVirtual)
        {
            var results = new List<NetworkAdapterInfo>();
            var msftStates = GetMsftAdapterStates();

            try
            {
                using (var searcher = new System.Management.ManagementObjectSearcher(
                    "SELECT NetConnectionID, NetEnabled, PhysicalAdapter, NetConnectionStatus, Description FROM Win32_NetworkAdapter WHERE NetConnectionID IS NOT NULL"))
                {
                    foreach (System.Management.ManagementObject obj in searcher.Get())
                    {
                        var name = Convert.ToString(obj["NetConnectionID"]);
                        if (string.IsNullOrWhiteSpace(name))
                        {
                            continue;
                        }

                        MsftAdapterState msft;
                        msftStates.TryGetValue(name, out msft);

                        var description = Convert.ToString(obj["Description"]) ?? string.Empty;
                        if (msft != null && !string.IsNullOrWhiteSpace(msft.InterfaceDescription))
                        {
                            description = msft.InterfaceDescription;
                        }

                        var isVirtual = IsVirtualAdapter(name, description, config.excludePatterns, obj, msft);
                        if (isVirtual && !includeVirtual)
                        {
                            continue;
                        }

                        var enabled = obj["NetEnabled"] is bool && (bool)obj["NetEnabled"];
                        var netConnectionStatus = ConvertNetConnectionStatus(obj["NetConnectionStatus"]);
                        var mediaConnectState = msft != null ? msft.MediaConnectState : 0;
                        var connection = MapMediaConnectionState(enabled, mediaConnectState, netConnectionStatus);
                        var isConnected = enabled && connection == "Connected";

                        results.Add(new NetworkAdapterInfo
                        {
                            Name = name,
                            Description = description,
                            IsEnabled = enabled,
                            IsConnected = isConnected,
                            IsVirtual = isVirtual,
                            ConnectionState = connection,
                            StatusText = BuildStatusText(enabled, connection, isVirtual)
                        });
                    }
                }
            }
            catch
            {
            }

            return results.OrderBy(a => a.IsVirtual).ThenBy(a => a.Name).ToList();
        }

        private static Dictionary<string, MsftAdapterState> GetMsftAdapterStates()
        {
            var map = new Dictionary<string, MsftAdapterState>(StringComparer.OrdinalIgnoreCase);

            try
            {
                var scope = new System.Management.ManagementScope(@"\\.\root\StandardCimv2");
                var query = new System.Management.ObjectQuery(
                    "SELECT Name, MediaConnectState, InterfaceDescription, Virtual FROM MSFT_NetAdapter");

                using (var searcher = new System.Management.ManagementObjectSearcher(scope, query))
                {
                    foreach (System.Management.ManagementObject obj in searcher.Get())
                    {
                        var name = Convert.ToString(obj["Name"]);
                        if (string.IsNullOrWhiteSpace(name))
                        {
                            continue;
                        }

                        map[name] = new MsftAdapterState
                        {
                            MediaConnectState = obj["MediaConnectState"] != null ? Convert.ToInt32(obj["MediaConnectState"]) : 0,
                            InterfaceDescription = Convert.ToString(obj["InterfaceDescription"]) ?? string.Empty,
                            Virtual = obj["Virtual"] is bool && (bool)obj["Virtual"]
                        };
                    }
                }
            }
            catch
            {
            }

            return map;
        }

        private static int ConvertNetConnectionStatus(object value)
        {
            if (value == null)
            {
                return 0;
            }

            return Convert.ToInt32(value);
        }

        private static bool IsVirtualAdapter(string name, string description, string[] excludePatterns, System.Management.ManagementObject obj, MsftAdapterState msft)
        {
            if (msft != null && msft.Virtual)
            {
                return true;
            }

            var physical = obj["PhysicalAdapter"];
            if (physical is bool && !(bool)physical)
            {
                return true;
            }

            var combined = name + " " + description;
            if (excludePatterns != null)
            {
                foreach (var pattern in excludePatterns)
                {
                    if (!string.IsNullOrWhiteSpace(pattern) &&
                        combined.IndexOf(pattern, StringComparison.OrdinalIgnoreCase) >= 0)
                    {
                        return true;
                    }
                }
            }

            return name.StartsWith("vEthernet", StringComparison.OrdinalIgnoreCase);
        }

        private static string MapMediaConnectionState(bool enabled, int mediaConnectState, int netConnectionStatus)
        {
            if (!enabled)
            {
                return "Disabled";
            }

            switch (mediaConnectState)
            {
                case 1:
                    return "Connected";
                case 2:
                    return "Disconnected";
                default:
                    if (netConnectionStatus == 2)
                    {
                        return "Connecting";
                    }

                    return "No connection";
            }
        }

        private static string BuildStatusText(bool enabled, string connection, bool isVirtual)
        {
            if (!enabled)
            {
                return isVirtual ? "Disabled · Virtual" : "Disabled";
            }

            var suffix = isVirtual ? " · Virtual" : string.Empty;
            return "Enabled · " + connection + suffix;
        }

        public static void QueueRequest(string actionFile, string taskName, object payload)
        {
            var dir = Path.GetDirectoryName(actionFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            var json = new JavaScriptSerializer().Serialize(payload);
            File.WriteAllText(actionFile, json, Encoding.UTF8);
            Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = "/Run /TN \"" + taskName + "\"",
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden
            });
        }
    }

    internal sealed class SettingsForm : Form
    {
        private readonly CheckBox _startupCheck;
        private readonly CheckBox _minimizedCheck;
        private readonly UserSettings _settings;
        private readonly Action<UserSettings> _onChanged;

        public SettingsForm(UserSettings settings, Action<UserSettings> onChanged, string appName)
        {
            _settings = settings;
            _onChanged = onChanged;

            Text = appName + " Settings";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(400, 210);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var titleLabel = new Label
            {
                Text = "Startup behavior",
                Font = new Font("Segoe UI", 11f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(20, 16)
            };

            _startupCheck = CreateSettingCheckBox("Launch at Windows startup", 48, settings.launchAtStartup);
            var startupDescription = CreateDescriptionLabel(
                "Add or remove the app from the Windows Startup folder.",
                70);

            _minimizedCheck = CreateSettingCheckBox("Start minimized to tray", 104, settings.startMinimizedToTray);
            var minimizedDescription = CreateDescriptionLabel(
                "On launch, show only the tray icon. Click the tray icon to open the window.",
                126);

            _startupCheck.CheckedChanged += (s, e) =>
            {
                _settings.launchAtStartup = _startupCheck.Checked;
                _onChanged(_settings);
            };

            _minimizedCheck.CheckedChanged += (s, e) =>
            {
                _settings.startMinimizedToTray = _minimizedCheck.Checked;
                _onChanged(_settings);
            };

            var closeButton = new Button
            {
                Text = "Close",
                Size = new Size(88, 30),
                Location = new Point(292, 168),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                DialogResult = DialogResult.OK
            };
            closeButton.FlatAppearance.BorderSize = 0;

            Controls.Add(titleLabel);
            Controls.Add(_startupCheck);
            Controls.Add(startupDescription);
            Controls.Add(_minimizedCheck);
            Controls.Add(minimizedDescription);
            Controls.Add(closeButton);
            AcceptButton = closeButton;
        }

        private static CheckBox CreateSettingCheckBox(string text, int top, bool isChecked)
        {
            return new CheckBox
            {
                Text = text,
                Checked = isChecked,
                AutoSize = true,
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                ForeColor = Color.White,
                Location = new Point(20, top)
            };
        }

        private static Label CreateDescriptionLabel(string text, int top)
        {
            return new Label
            {
                Text = text,
                Font = new Font("Segoe UI", 8.25f),
                ForeColor = Color.FromArgb(160, 160, 160),
                AutoSize = false,
                Size = new Size(360, 32),
                Location = new Point(38, top)
            };
        }
    }

    internal sealed class MainApplicationContext : ApplicationContext
    {
        private readonly AppConfig _config;
        private readonly string _actionFile;
        private readonly string _signalFile;
        private readonly string _settingsPath;
        private readonly string _logoPath;
        private readonly string _exePath;
        private readonly string _repoRoot;
        private readonly UserSettings _userSettings;
        private readonly NotifyIcon _notifyIcon;
        private readonly Form _form;
        private readonly FlowLayoutPanel _adapterList;
        private readonly Label _summaryLabel;
        private readonly System.Windows.Forms.Timer _timer;
        private readonly AppVersionInfo _productVersion;
        private readonly bool _isProEdition;
        private readonly ProDataStore _proStore;
        private readonly AutomationService _automation;
        private HotkeyService _hotkeyService;
        private GlobalHotkey _wifiHotkey;
        private Bitmap _heldBitmap;
        private IntPtr _iconHandle = IntPtr.Zero;
        private bool _isClosing;

        public MainApplicationContext(AppConfig config, string repoRoot)
        {
            _config = config;
            _repoRoot = repoRoot;
            _productVersion = AppVersionInfo.Load(repoRoot);
            _isProEdition = EditionService.IsProEdition();
            if (_isProEdition)
            {
                _proStore = new ProDataStore();
                _automation = new AutomationService(_proStore, new AppConfigSnapshot
                {
                    ethernetAdapterName = config.ethernetAdapterName,
                    wifiAdapterName = config.wifiAdapterName
                });
            }
            else
            {
                _proStore = null;
                _automation = null;
            }
            _exePath = Assembly.GetExecutingAssembly().Location;
            _actionFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InternetToggle", "pending-action.json");
            _signalFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InternetToggle", "show-window.signal");
            _settingsPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InternetToggle", "settings.json");
            _logoPath = Path.Combine(repoRoot, "assets", "logo.png");
            _userSettings = UserSettings.Load(_settingsPath, _config);
            StartupShortcutHelper.ApplyLaunchAtStartup(_userSettings.launchAtStartup, _config, _exePath, _repoRoot);

            _form = BuildForm(out _adapterList, out _summaryLabel);
            MainForm = _form;
            _adapterList.Resize += (s, e) => ResizeAdapterRows();
            _notifyIcon = BuildNotifyIcon();
            if (_isProEdition)
            {
                _hotkeyService = new HotkeyService(_form, _proStore);
                _hotkeyService.HotkeyActionRequested += OnHotkeyActionRequested;
                _hotkeyService.RegisterAll(true);
            }
            else
            {
                RegisterBasicHotkey();
            }

            _timer = new System.Windows.Forms.Timer { Interval = 2000 };
            _timer.Tick += OnTimerTick;
            _timer.Start();

            RefreshAdapters();

            if (!_userSettings.startMinimizedToTray)
            {
                _form.Show();
            }
        }

        private void RegisterBasicHotkey()
        {
            if (!EditionService.CanUseFeature(Feature.BasicHotkey))
            {
                return;
            }

            try
            {
                _wifiHotkey = new GlobalHotkey(_form, 1, Keys.W, 0x0001 | 0x0002);
                _wifiHotkey.HotkeyPressed += (s, e) => SwitchToWifi();
            }
            catch
            {
            }
        }

        private Form BuildForm(out FlowLayoutPanel adapterList, out Label summaryLabel)
        {
            var windowTitle = _productVersion.productName + " " + _productVersion.GetDisplayVersion();
            var form = new Form
            {
                Text = windowTitle,
                AutoScaleMode = AutoScaleMode.Dpi,
                Font = new Font("Segoe UI", 9f),
                ClientSize = new Size(560, 560),
                MinimumSize = new Size(560, 560),
                FormBorderStyle = FormBorderStyle.FixedSingle,
                MaximizeBox = false,
                StartPosition = FormStartPosition.CenterScreen,
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.White
            };

            TrySetFormIcon(form);

            var headerPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                Height = 96,
                BackColor = Color.FromArgb(24, 24, 24),
                ColumnCount = 3,
                RowCount = 1,
                Padding = new Padding(16, 12, 16, 12)
            };
            headerPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 52f));
            headerPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            headerPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 228f));

            var logoPicture = new PictureBox
            {
                Dock = DockStyle.Fill,
                SizeMode = PictureBoxSizeMode.Zoom,
                BackColor = Color.FromArgb(24, 24, 24),
                Margin = new Padding(0, 2, 10, 2)
            };
            if (File.Exists(_logoPath))
            {
                logoPicture.Image = Image.FromFile(_logoPath);
            }

            var titlePanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(24, 24, 24),
                ColumnCount = 1,
                RowCount = 2,
                Margin = new Padding(0)
            };
            titlePanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 26f));
            titlePanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));

            var titleLabel = new Label
            {
                Text = EditionService.GetEditionLabel(),
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                ForeColor = Color.White,
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.BottomLeft
            };

            var subtitleLabel = new Label
            {
                Text = (_isProEdition ? "Pro edition · " : string.Empty) + "Internet adapter control · v" + _productVersion.GetDisplayVersion(),
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(170, 170, 170),
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.TopLeft
            };

            titlePanel.Controls.Add(titleLabel, 0, 0);
            titlePanel.Controls.Add(subtitleLabel, 0, 1);

            var headerActionsPanel = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                FlowDirection = FlowDirection.RightToLeft,
                WrapContents = false,
                BackColor = Color.FromArgb(24, 24, 24),
                Padding = new Padding(0, 4, 0, 0)
            };

            var aboutButton = CreateHeaderButton("About");
            aboutButton.Click += (s, e) => ShowAboutDialog();
            var settingsButton = CreateHeaderButton("Settings");
            settingsButton.Click += (s, e) => ShowSettingsDialog();
            var profilesButton = CreateHeaderButton("Profiles");
            profilesButton.Click += (s, e) => ShowProFeature(Feature.MultipleProfiles);

            headerActionsPanel.Controls.Add(profilesButton);
            headerActionsPanel.Controls.Add(settingsButton);
            headerActionsPanel.Controls.Add(aboutButton);

            headerPanel.Controls.Add(logoPicture, 0, 0);
            headerPanel.Controls.Add(titlePanel, 1, 0);
            headerPanel.Controls.Add(headerActionsPanel, 2, 0);

            var quickPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                Height = 52,
                Padding = new Padding(16, 8, 16, 8),
                BackColor = Color.FromArgb(30, 30, 30),
                ColumnCount = 2,
                RowCount = 1
            };
            quickPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50f));
            quickPanel.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50f));

            var ethernetButton = CreateQuickButton("Switch to Ethernet");
            ethernetButton.Click += (s, e) => SwitchToEthernet();
            var wifiButton = CreateQuickButton("Switch to Wi-Fi");
            wifiButton.Click += (s, e) => SwitchToWifi();

            ethernetButton.Margin = new Padding(0, 0, 4, 0);
            wifiButton.Margin = new Padding(4, 0, 0, 0);
            quickPanel.Controls.Add(ethernetButton, 0, 0);
            quickPanel.Controls.Add(wifiButton, 1, 0);

            summaryLabel = new Label
            {
                Dock = DockStyle.Top,
                Height = 32,
                Padding = new Padding(16, 8, 16, 4),
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                ForeColor = Color.FromArgb(180, 180, 180),
                BackColor = Color.FromArgb(30, 30, 30),
                Text = "Loading adapters..."
            };

            var listHost = new Panel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(16, 8, 16, 8),
                BackColor = Color.FromArgb(30, 30, 30)
            };

            adapterList = new FlowLayoutPanel
            {
                Dock = DockStyle.Fill,
                AutoScroll = true,
                FlowDirection = FlowDirection.TopDown,
                WrapContents = false,
                BackColor = Color.FromArgb(36, 36, 36),
                Padding = new Padding(10, 8, 10, 8)
            };

            listHost.Controls.Add(adapterList);

            var hintLabel = new Label
            {
                Dock = DockStyle.Bottom,
                Height = 36,
                Padding = new Padding(16, 6, 16, 12),
                Text = "Close hides to tray · Ctrl+Alt+W switches to Wi-Fi · Right-click tray to exit",
                Font = new Font("Segoe UI", 8.25f),
                ForeColor = Color.FromArgb(120, 120, 120),
                TextAlign = ContentAlignment.MiddleCenter,
                BackColor = Color.FromArgb(24, 24, 24)
            };

            form.Controls.Add(listHost);
            form.Controls.Add(summaryLabel);
            form.Controls.Add(quickPanel);
            form.Controls.Add(hintLabel);
            form.Controls.Add(headerPanel);

            form.FormClosing += (s, e) =>
            {
                if (!_isClosing)
                {
                    e.Cancel = true;
                    form.Hide();
                }
            };

            form.FormClosed += (s, e) =>
            {
                if (_isClosing)
                {
                    Shutdown();
                }
            };

            return form;
        }

        private static Button CreateHeaderButton(string text)
        {
            var button = new Button
            {
                Text = text,
                Size = new Size(70, 28),
                Margin = new Padding(6, 0, 0, 0),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 8.75f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            button.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
            return button;
        }

        private static Button CreateQuickButton(string text)
        {
            var button = new Button
            {
                Text = text,
                Dock = DockStyle.Fill,
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9.25f, FontStyle.Bold),
                Cursor = Cursors.Hand,
                Height = 32
            };
            button.FlatAppearance.BorderSize = 0;
            return button;
        }

        private void TrySetFormIcon(Form form)
        {
            if (!File.Exists(_logoPath))
            {
                return;
            }

            try
            {
                using (var logoBitmap = new Bitmap(_logoPath))
                using (var formIconBitmap = new Bitmap(32, 32))
                {
                    using (var g = Graphics.FromImage(formIconBitmap))
                    {
                        g.DrawImage(logoBitmap, 0, 0, 32, 32);
                    }

                    form.Icon = Icon.FromHandle(formIconBitmap.GetHicon());
                }
            }
            catch
            {
            }
        }

        private NotifyIcon BuildNotifyIcon()
        {
            var menu = new ContextMenuStrip();
            var showItem = new ToolStripMenuItem("Show Window");
            var ethItem = new ToolStripMenuItem("Switch to Ethernet");
            var wifiItem = new ToolStripMenuItem("Switch to Wi-Fi");
            var exitItem = new ToolStripMenuItem("Exit");

            showItem.Click += (s, e) => ShowMainWindow();
            ethItem.Click += (s, e) => SwitchToEthernet();
            wifiItem.Click += (s, e) => SwitchToWifi();
            exitItem.Click += (s, e) =>
            {
                _isClosing = true;
                _form.Close();
            };

            menu.Items.Add(showItem);
            menu.Items.Add(ethItem);
            menu.Items.Add(wifiItem);

            if (_isProEdition && EditionService.CanUseFeature(Feature.AdvancedTrayActions))
            {
                var profilesMenu = new ToolStripMenuItem("Apply Profile");
                RefreshTrayProfileMenu(profilesMenu);
                profilesMenu.DropDownOpening += (s, e) => RefreshTrayProfileMenu(profilesMenu);
                menu.Items.Add(profilesMenu);
            }

            menu.Items.Add(exitItem);

            var notifyIcon = new NotifyIcon
            {
                Visible = true,
                ContextMenuStrip = menu,
                Text = _config.appName
            };

            notifyIcon.MouseClick += (s, e) =>
            {
                if (e.Button == MouseButtons.Left)
                {
                    ShowMainWindow();
                }
            };

            return notifyIcon;
        }

        private Control CreateAdapterRow(NetworkAdapterInfo adapter, int rowWidth)
        {
            const int buttonColumnWidth = 84;

            var row = new TableLayoutPanel
            {
                Width = rowWidth,
                Height = 72,
                ColumnCount = 2,
                RowCount = 1,
                Margin = new Padding(0, 0, 0, 8),
                BackColor = Color.FromArgb(45, 45, 45),
                Padding = new Padding(12, 8, 12, 8)
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, buttonColumnWidth));

            var infoPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(45, 45, 45),
                ColumnCount = 1,
                RowCount = 3,
                Margin = new Padding(0)
            };
            infoPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 20f));
            infoPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 18f));
            infoPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100f));

            var nameLabel = new Label
            {
                Text = adapter.Name,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = Color.White,
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.MiddleLeft
            };

            var statusLabel = new Label
            {
                Text = adapter.StatusText,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = adapter.IsConnected
                    ? Color.FromArgb(46, 160, 67)
                    : (adapter.IsEnabled ? Color.FromArgb(200, 180, 80) : Color.FromArgb(160, 160, 160)),
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.MiddleLeft
            };

            var descLabel = new Label
            {
                Text = adapter.Description,
                Font = new Font("Segoe UI", 8f),
                ForeColor = Color.FromArgb(130, 130, 130),
                Dock = DockStyle.Fill,
                AutoEllipsis = true,
                TextAlign = ContentAlignment.TopLeft
            };

            infoPanel.Controls.Add(nameLabel, 0, 0);
            infoPanel.Controls.Add(statusLabel, 0, 1);
            infoPanel.Controls.Add(descLabel, 0, 2);

            var buttonHost = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(45, 45, 45)
            };

            var toggleButton = new Button
            {
                Text = adapter.IsEnabled ? "Disable" : "Enable",
                Size = new Size(76, 30),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 8.75f, FontStyle.Bold),
                Anchor = AnchorStyles.None
            };
            toggleButton.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
            toggleButton.Click += (s, e) => RunAdapterAction(adapter.IsEnabled ? "Disable" : "Enable", adapter.Name, "UI");

            buttonHost.Controls.Add(toggleButton);
            buttonHost.Resize += (s, e) => CenterControlInPanel(toggleButton, buttonHost);

            row.Controls.Add(infoPanel, 0, 0);
            row.Controls.Add(buttonHost, 1, 0);
            row.HandleCreated += (s, e) => CenterControlInPanel(toggleButton, buttonHost);
            return row;
        }

        private static void CenterControlInPanel(Control control, Panel panel)
        {
            control.Left = Math.Max(0, (panel.ClientSize.Width - control.Width) / 2);
            control.Top = Math.Max(0, (panel.ClientSize.Height - control.Height) / 2);
        }

        private int GetAdapterRowWidth()
        {
            var scrollbar = _adapterList.VerticalScroll.Visible ? SystemInformation.VerticalScrollBarWidth : 0;
            return Math.Max(380, _adapterList.ClientSize.Width - scrollbar - 24);
        }

        private void ResizeAdapterRows()
        {
            var rowWidth = GetAdapterRowWidth();
            foreach (Control control in _adapterList.Controls)
            {
                control.Width = rowWidth;
            }
        }

        private void RefreshAdapters()
        {
            var adapters = AdapterHelper.GetAdapters(_config, includeVirtual: false);
            var rowWidth = GetAdapterRowWidth();
            _adapterList.SuspendLayout();
            _adapterList.Controls.Clear();

            foreach (var adapter in adapters)
            {
                _adapterList.Controls.Add(CreateAdapterRow(adapter, rowWidth));
            }

            if (adapters.Count == 0)
            {
                _adapterList.Controls.Add(new Label
                {
                    Text = "No adapters found.",
                    ForeColor = Color.White,
                    AutoSize = true,
                    Padding = new Padding(8)
                });
            }

            _adapterList.ResumeLayout();
            UpdateSummary(adapters);
            SetTrayIcon(adapters);
        }

        private void UpdateSummary(IList<NetworkAdapterInfo> adapters)
        {
            var eth = adapters.FirstOrDefault(a => a.Name.Equals(_config.ethernetAdapterName, StringComparison.OrdinalIgnoreCase));
            var wifi = adapters.FirstOrDefault(a => a.Name.Equals(_config.wifiAdapterName, StringComparison.OrdinalIgnoreCase));
            var ethText = "Ethernet: " + FormatSummaryState(eth);
            var wifiText = "Wi-Fi: " + FormatSummaryState(wifi);
            _summaryLabel.Text = ethText + "   |   " + wifiText;
            _notifyIcon.Text = _config.appName + " · " + ethText + ", " + wifiText;
        }

        private static string FormatSummaryState(NetworkAdapterInfo adapter)
        {
            if (adapter == null)
            {
                return "n/a";
            }

            if (!adapter.IsEnabled)
            {
                return "Disabled";
            }

            if (adapter.IsConnected)
            {
                return "Connected";
            }

            return adapter.ConnectionState == "Connecting" ? "Connecting" : "Disconnected";
        }

        private void RunAdapterAction(string action, string adapterName, string source)
        {
            try
            {
                AdapterNameValidator.ValidateOrThrow(adapterName);
            }
            catch (Exception ex)
            {
                AppLogger.Error("AdapterActionValidation", adapterName, ex.Message);
                MessageBox.Show(_form, "Invalid adapter name.", _config.appName, MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", action },
                { "adapter", adapterName }
            });
            AppLogger.Info(action, adapterName, true, "Queued adapter action");
            RecordHistory(action, adapterName, source);
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void SwitchToEthernet(string source)
        {
            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", "Switch" },
                { "enable", new[] { _config.ethernetAdapterName } },
                { "disable", new[] { _config.wifiAdapterName } },
                { "message", "Switched to Ethernet. Wi-Fi disabled." }
            });
            RecordHistory("Switch", "Ethernet", source);
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void SwitchToWifi(string source)
        {
            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", "Switch" },
                { "enable", new[] { _config.wifiAdapterName } },
                { "disable", new[] { _config.ethernetAdapterName } },
                { "message", "Switched to Wi-Fi. Ethernet disabled." }
            });
            RecordHistory("Switch", "Wi-Fi", source);
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void SwitchToEthernet()
        {
            SwitchToEthernet("UI");
        }

        private void SwitchToWifi()
        {
            SwitchToWifi("UI");
        }

        private void ToggleEthernetAdapter(string source)
        {
            var adapters = AdapterHelper.GetAdapters(_config, includeVirtual: false);
            var eth = adapters.FirstOrDefault(a => a.Name.Equals(_config.ethernetAdapterName, StringComparison.OrdinalIgnoreCase));
            if (eth == null)
            {
                return;
            }

            RunAdapterAction(eth.IsEnabled ? "Disable" : "Enable", eth.Name, source);
        }

        private void ApplyProfile(NetworkProfile profile, string source)
        {
            if (profile == null)
            {
                return;
            }

            var items = new List<Dictionary<string, object>>();
            foreach (var adapter in profile.adapters)
            {
                try
                {
                    AdapterNameValidator.ValidateOrThrow(adapter.name);
                }
                catch
                {
                    continue;
                }

                items.Add(new Dictionary<string, object>
                {
                    { "adapter", adapter.name },
                    { "action", adapter.enabled ? "Enable" : "Disable" }
                });
            }

            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", "Batch" },
                { "items", items.ToArray() },
                { "message", "Applied profile: " + profile.name }
            });
            RecordHistory("Profile", profile.name, source);
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void ApplyProfileByIndex(int index, string source)
        {
            if (!_isProEdition || _proStore == null)
            {
                return;
            }

            var profile = _proStore.GetProfileByIndex(index);
            if (profile != null)
            {
                ApplyProfile(profile, source);
            }
        }

        private void RecordHistory(string action, string detail, string source)
        {
            if (!_isProEdition || _proStore == null || !EditionService.CanUseFeature(Feature.ConnectionHistory))
            {
                return;
            }

            _proStore.AddHistory(action, detail, source);
        }

        private List<NetworkAdapterSnapshot> GetAdapterSnapshots()
        {
            return AdapterHelper.GetAdapters(_config, includeVirtual: false)
                .Select(a => new NetworkAdapterSnapshot
                {
                    Name = a.Name,
                    IsEnabled = a.IsEnabled,
                    IsConnected = a.IsConnected
                })
                .ToList();
        }

        private void EvaluateAutomation()
        {
            if (!_isProEdition || _automation == null || _proStore == null)
            {
                return;
            }

            if (!EditionService.CanUseFeature(Feature.AutomaticFailover) &&
                !EditionService.CanUseFeature(Feature.PerAdapterRules) &&
                !EditionService.CanUseFeature(Feature.Schedules))
            {
                return;
            }

            var result = _automation.Evaluate(GetAdapterSnapshots(), DateTime.Now);
            if (result.IsNone)
            {
                return;
            }

            switch (result.Action)
            {
                case AutomationAction.SwitchEthernet:
                    SwitchToEthernet("Automation");
                    break;
                case AutomationAction.SwitchWifi:
                    SwitchToWifi("Automation");
                    break;
                case AutomationAction.DisableWifi:
                    RunAdapterAction("Disable", _config.wifiAdapterName, "Rule");
                    break;
                case AutomationAction.DisableEthernet:
                    RunAdapterAction("Disable", _config.ethernetAdapterName, "Rule");
                    break;
                case AutomationAction.ApplyProfile:
                    var profile = _proStore.GetProfileById(result.ProfileId);
                    if (profile != null)
                    {
                        ApplyProfile(profile, "Schedule");
                    }
                    break;
            }
        }

        private void OnHotkeyActionRequested(string actionName)
        {
            switch (actionName)
            {
                case "SwitchEthernet":
                    SwitchToEthernet("Hotkey");
                    break;
                case "SwitchWifi":
                    SwitchToWifi("Hotkey");
                    break;
                case "ToggleEthernet":
                    ToggleEthernetAdapter("Hotkey");
                    break;
                case "ApplyProfile1":
                    ApplyProfileByIndex(0, "Hotkey");
                    break;
                case "ApplyProfile2":
                    ApplyProfileByIndex(1, "Hotkey");
                    break;
            }
        }

        private void RefreshTrayProfileMenu(ToolStripMenuItem profilesMenu)
        {
            profilesMenu.DropDownItems.Clear();
            if (_proStore == null)
            {
                profilesMenu.Enabled = false;
                return;
            }

            if (_proStore.Profiles.profiles.Count == 0)
            {
                profilesMenu.Enabled = false;
                return;
            }

            profilesMenu.Enabled = true;
            foreach (var profile in _proStore.Profiles.profiles)
            {
                var item = new ToolStripMenuItem(profile.name);
                item.Click += (s, e) => ApplyProfile(profile, "Tray");
                profilesMenu.DropDownItems.Add(item);
            }
        }

        private void ShowProfilesDialog()
        {
            using (var form = new ProfilesForm(_proStore, GetAdapterSnapshots, profile => ApplyProfile(profile, "Profiles")))
            {
                form.ShowDialog(_form);
            }
        }

        private void ShowMainWindow()
        {
            _form.Show();
            _form.WindowState = FormWindowState.Normal;
            _form.Activate();
        }

        private void ShowSettingsDialog()
        {
            if (_isProEdition && EditionService.CanUseFeature(Feature.ImportExportConfig))
            {
                using (var settingsForm = new ProSettingsForm(
                    _proStore,
                    _userSettings,
                    SaveUserSettings,
                    () => _hotkeyService.RegisterAll(true),
                    _productVersion.GetDisplayVersion(),
                    _config.appName))
                {
                    settingsForm.ShowDialog(_form);
                }
                return;
            }

            using (var settingsForm = new SettingsForm(_userSettings, SaveUserSettings, _config.appName))
            {
                settingsForm.ShowDialog(_form);
            }
        }

        private void ShowAboutDialog()
        {
            using (var aboutForm = new AboutForm(_repoRoot))
            {
                aboutForm.ShowDialog(_form);
            }
        }

        private void ShowProFeature(Feature feature)
        {
            if (!EditionService.CanUseFeature(feature))
            {
                using (var upgrade = new UpgradeDialog(_repoRoot, feature))
                {
                    upgrade.ShowDialog(_form);
                }
                return;
            }

            switch (feature)
            {
                case Feature.MultipleProfiles:
                    ShowProfilesDialog();
                    break;
                case Feature.ConnectionHistory:
                    using (var history = new HistoryForm(_proStore))
                    {
                        history.ShowDialog(_form);
                    }
                    break;
                default:
                    ShowSettingsDialog();
                    break;
            }
        }

        private void SaveUserSettings(UserSettings settings)
        {
            _userSettings.launchAtStartup = settings.launchAtStartup;
            _userSettings.startMinimizedToTray = settings.startMinimizedToTray;
            _userSettings.Save(_settingsPath);
            StartupShortcutHelper.ApplyLaunchAtStartup(_userSettings.launchAtStartup, _config, _exePath, _repoRoot);
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            if (File.Exists(_signalFile))
            {
                try { File.Delete(_signalFile); } catch { }
                ShowMainWindow();
            }

            RefreshAdapters();
            EvaluateAutomation();
        }

        private void SetTrayIcon(IList<NetworkAdapterInfo> adapters)
        {
            var eth = adapters.FirstOrDefault(a => a.Name.Equals(_config.ethernetAdapterName, StringComparison.OrdinalIgnoreCase));
            var wifi = adapters.FirstOrDefault(a => a.Name.Equals(_config.wifiAdapterName, StringComparison.OrdinalIgnoreCase));
            var isActive = (eth != null && eth.IsEnabled) || (wifi != null && wifi.IsEnabled);
            var newIcon = CreateTrayIcon(isActive);

            if (_notifyIcon.Icon != null)
            {
                _notifyIcon.Icon.Dispose();
            }

            _notifyIcon.Icon = newIcon;
        }

        private Icon CreateTrayIcon(bool isOn)
        {
            var bitmap = new Bitmap(16, 16, System.Drawing.Imaging.PixelFormat.Format32bppArgb);
            using (var graphics = Graphics.FromImage(bitmap))
            {
                graphics.Clear(Color.Transparent);
                graphics.SmoothingMode = SmoothingMode.AntiAlias;

                var drewLogo = false;
                if (File.Exists(_logoPath))
                {
                    try
                    {
                        using (var logo = Image.FromFile(_logoPath))
                        {
                            graphics.DrawImage(logo, 0, 0, 16, 16);
                            drewLogo = true;
                        }
                    }
                    catch
                    {
                    }
                }

                var color = isOn ? Color.FromArgb(46, 160, 67) : Color.FromArgb(140, 140, 140);
                using (var brush = new SolidBrush(color))
                {
                    if (drewLogo)
                    {
                        graphics.FillEllipse(brush, 10, 10, 5, 5);
                    }
                    else
                    {
                        graphics.FillEllipse(brush, 2, 2, 12, 12);
                    }
                }
            }

            if (_heldBitmap != null) _heldBitmap.Dispose();
            if (_iconHandle != IntPtr.Zero) NativeMethods.DestroyIcon(_iconHandle);

            _heldBitmap = bitmap;
            _iconHandle = bitmap.GetHicon();
            return Icon.FromHandle(_iconHandle);
        }

        private void Shutdown()
        {
            if (_wifiHotkey != null)
            {
                _wifiHotkey.Dispose();
                _wifiHotkey = null;
            }

            if (_hotkeyService != null)
            {
                _hotkeyService.Dispose();
                _hotkeyService = null;
            }

            _timer.Stop();
            _timer.Dispose();
            _notifyIcon.Visible = false;
            if (_notifyIcon.Icon != null) _notifyIcon.Icon.Dispose();
            if (_iconHandle != IntPtr.Zero) NativeMethods.DestroyIcon(_iconHandle);
            if (_heldBitmap != null) _heldBitmap.Dispose();
            _notifyIcon.Dispose();
            ExitThread();
        }

        protected override void OnMainFormClosed(object sender, EventArgs e)
        {
            if (!_isClosing)
            {
                return;
            }

            base.OnMainFormClosed(sender, e);
        }
    }

    internal static class Program
    {
        private const string MutexName = "Global\\InternetToggleApp";

        [DllImport("user32.dll")]
        private static extern bool SetProcessDPIAware();

        [STAThread]
        private static void Main()
        {
            try
            {
                if (Environment.OSVersion.Version.Major >= 6)
                {
                    SetProcessDPIAware();
                }

                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);

                using (var mutex = new Mutex(false, MutexName))
                {
                    if (!mutex.WaitOne(0, false))
                    {
                        SignalExistingInstance();
                        return;
                    }

                    var exeDir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location) ?? AppDomain.CurrentDomain.BaseDirectory;
                    var configPath = Path.Combine(exeDir, "config.json");
                    var config = AppConfig.Load(configPath);
                    EditionService.Initialize(null);

                    Application.Run(new MainApplicationContext(config, exeDir));
                }
            }
            catch (Exception ex)
            {
                try
                {
                    var logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InternetToggle", "error.log");
                    var logDir = Path.GetDirectoryName(logPath);
                    if (!string.IsNullOrEmpty(logDir) && !Directory.Exists(logDir))
                    {
                        Directory.CreateDirectory(logDir);
                    }
                    File.WriteAllText(logPath, ex.ToString());
                }
                catch
                {
                }

                MessageBox.Show(ex.ToString(), "Internet Toggle Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static void SignalExistingInstance()
        {
            var signalFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "InternetToggle", "show-window.signal");
            var dir = Path.GetDirectoryName(signalFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            File.WriteAllText(signalFile, "1");
        }
    }
}
