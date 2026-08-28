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
                version = "1.3.0",
                adapterName = "Ethernet",
                ethernetAdapterName = "Ethernet",
                wifiAdapterName = "Wi-Fi",
                taskName = "ToggleEthernet",
                appName = "Network Toggle",
                exeName = "Ethernet Toggle",
                excludePatterns = new[] { "vEthernet", "Hyper-V" }
            };
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

    internal sealed class MainApplicationContext : ApplicationContext
    {
        private readonly AppConfig _config;
        private readonly string _actionFile;
        private readonly string _signalFile;
        private readonly string _logoPath;
        private readonly NotifyIcon _notifyIcon;
        private readonly Form _form;
        private readonly FlowLayoutPanel _adapterList;
        private readonly Label _summaryLabel;
        private readonly System.Windows.Forms.Timer _timer;
        private Bitmap _heldBitmap;
        private IntPtr _iconHandle = IntPtr.Zero;
        private bool _isClosing;

        public MainApplicationContext(AppConfig config, string repoRoot)
        {
            _config = config;
            _actionFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "pending-action.json");
            _signalFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "show-window.signal");
            _logoPath = Path.Combine(repoRoot, "assets", "logo.png");

            _form = BuildForm(out _adapterList, out _summaryLabel);
            MainForm = _form;
            _adapterList.Resize += (s, e) => ResizeAdapterRows();
            _notifyIcon = BuildNotifyIcon();
            _timer = new System.Windows.Forms.Timer { Interval = 2000 };
            _timer.Tick += OnTimerTick;
            _timer.Start();

            RefreshAdapters();
            _form.Show();
        }

        private Form BuildForm(out FlowLayoutPanel adapterList, out Label summaryLabel)
        {
            var form = new Form
            {
                Text = _config.appName,
                ClientSize = new Size(480, 500),
                MinimumSize = new Size(480, 500),
                FormBorderStyle = FormBorderStyle.FixedSingle,
                MaximizeBox = false,
                StartPosition = FormStartPosition.CenterScreen,
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.White
            };

            TrySetFormIcon(form);

            var headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 88,
                BackColor = Color.FromArgb(24, 24, 24)
            };

            var logoPicture = new PictureBox
            {
                Size = new Size(52, 52),
                Location = new Point(16, 16),
                SizeMode = PictureBoxSizeMode.Zoom
            };
            if (File.Exists(_logoPath))
            {
                logoPicture.Image = Image.FromFile(_logoPath);
            }

            var titleLabel = new Label
            {
                Text = _config.appName,
                Font = new Font("Segoe UI", 14f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(80, 18)
            };

            var subtitleLabel = new Label
            {
                Text = "Internet adapter control",
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(170, 170, 170),
                AutoSize = true,
                Location = new Point(82, 46)
            };

            headerPanel.Controls.Add(logoPicture);
            headerPanel.Controls.Add(titleLabel);
            headerPanel.Controls.Add(subtitleLabel);

            var quickPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Top,
                Height = 56,
                Padding = new Padding(16, 10, 16, 8),
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

            quickPanel.Controls.Add(ethernetButton, 0, 0);
            wifiButton.Margin = new Padding(6, 0, 0, 0);
            quickPanel.Controls.Add(wifiButton, 1, 0);

            summaryLabel = new Label
            {
                Dock = DockStyle.Top,
                Height = 28,
                Padding = new Padding(16, 6, 16, 0),
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
                Height = 24,
                Text = "Close hides to tray · Right-click tray icon to exit",
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

        private static Button CreateQuickButton(string text)
        {
            var button = new Button
            {
                Text = text,
                Dock = DockStyle.Fill,
                Margin = new Padding(0, 0, 6, 0),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9.5f, FontStyle.Bold),
                Cursor = Cursors.Hand,
                Height = 36
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
            var row = new TableLayoutPanel
            {
                Width = rowWidth,
                Height = 78,
                ColumnCount = 2,
                RowCount = 1,
                Margin = new Padding(0, 0, 0, 8),
                BackColor = Color.FromArgb(45, 45, 45),
                Padding = new Padding(12, 10, 12, 10)
            };
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100f));
            row.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 92f));

            var infoPanel = new Panel
            {
                Dock = DockStyle.Fill,
                BackColor = Color.FromArgb(45, 45, 45)
            };

            var nameLabel = new Label
            {
                Text = adapter.Name,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(0, 0)
            };

            var statusLabel = new Label
            {
                Text = adapter.StatusText,
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = adapter.IsConnected
                    ? Color.FromArgb(46, 160, 67)
                    : (adapter.IsEnabled ? Color.FromArgb(200, 180, 80) : Color.FromArgb(160, 160, 160)),
                AutoSize = true,
                Location = new Point(0, 20)
            };

            var descLabel = new Label
            {
                Text = adapter.Description,
                Font = new Font("Segoe UI", 8f),
                ForeColor = Color.FromArgb(130, 130, 130),
                AutoSize = false,
                Size = new Size(rowWidth - 140, 18),
                Location = new Point(0, 38)
            };

            infoPanel.Controls.Add(nameLabel);
            infoPanel.Controls.Add(statusLabel);
            infoPanel.Controls.Add(descLabel);

            var toggleButton = new Button
            {
                Text = adapter.IsEnabled ? "Disable" : "Enable",
                Dock = DockStyle.Fill,
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9f, FontStyle.Bold),
                Margin = new Padding(8, 8, 0, 8)
            };
            toggleButton.FlatAppearance.BorderColor = Color.FromArgb(80, 80, 80);
            toggleButton.Click += (s, e) => RunAdapterAction(adapter.IsEnabled ? "Disable" : "Enable", adapter.Name);

            row.Controls.Add(infoPanel, 0, 0);
            row.Controls.Add(toggleButton, 1, 0);
            return row;
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

        private void RunAdapterAction(string action, string adapterName)
        {
            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", action },
                { "adapter", adapterName }
            });
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void SwitchToEthernet()
        {
            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", "Switch" },
                { "enable", new[] { _config.ethernetAdapterName } },
                { "disable", new[] { _config.wifiAdapterName } },
                { "message", "Switched to Ethernet. Wi-Fi disabled." }
            });
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void SwitchToWifi()
        {
            AdapterHelper.QueueRequest(_actionFile, _config.taskName, new Dictionary<string, object>
            {
                { "type", "Switch" },
                { "enable", new[] { _config.wifiAdapterName } },
                { "disable", new[] { _config.ethernetAdapterName } },
                { "message", "Switched to Wi-Fi. Ethernet disabled." }
            });
            Thread.Sleep(900);
            RefreshAdapters();
        }

        private void ShowMainWindow()
        {
            _form.Show();
            _form.WindowState = FormWindowState.Normal;
            _form.Activate();
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            if (File.Exists(_signalFile))
            {
                try { File.Delete(_signalFile); } catch { }
                ShowMainWindow();
            }

            RefreshAdapters();
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
        private const string MutexName = "Global\\EthernetToggleApp";

        [STAThread]
        private static void Main()
        {
            try
            {
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

                    Application.Run(new MainApplicationContext(config, exeDir));
                }
            }
            catch (Exception ex)
            {
                try
                {
                    var logPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "error.log");
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

                MessageBox.Show(ex.ToString(), "Network Toggle Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        private static void SignalExistingInstance()
        {
            var signalFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "show-window.signal");
            var dir = Path.GetDirectoryName(signalFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            File.WriteAllText(signalFile, "1");
        }
    }
}
