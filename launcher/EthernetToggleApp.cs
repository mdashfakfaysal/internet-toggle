using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading;
using System.Web.Script.Serialization;
using System.Windows.Forms;

namespace EthernetToggle
{
    internal sealed class AppConfig
    {
        public string adapterName { get; set; }
        public string taskName { get; set; }
        public string appName { get; set; }

        public static AppConfig Load(string configPath)
        {
            var defaults = new AppConfig
            {
                adapterName = "Ethernet",
                taskName = "ToggleEthernet",
                appName = "Ethernet Toggle"
            };

            if (!File.Exists(configPath))
            {
                return defaults;
            }

            try
            {
                var json = File.ReadAllText(configPath);
                var loaded = new JavaScriptSerializer().Deserialize<AppConfig>(json);
                if (loaded == null)
                {
                    return defaults;
                }

                if (string.IsNullOrWhiteSpace(loaded.adapterName)) loaded.adapterName = defaults.adapterName;
                if (string.IsNullOrWhiteSpace(loaded.taskName)) loaded.taskName = defaults.taskName;
                if (string.IsNullOrWhiteSpace(loaded.appName)) loaded.appName = defaults.appName;
                return loaded;
            }
            catch
            {
                return defaults;
            }
        }
    }

    internal static class NativeMethods
    {
        [DllImport("user32.dll", CharSet = CharSet.Auto)]
        public static extern bool DestroyIcon(IntPtr handle);
    }

    internal static class AdapterHelper
    {
        public static bool IsEnabled(string adapterName)
        {
            try
            {
                using (var searcher = new System.Management.ManagementObjectSearcher(
                    "SELECT NetEnabled FROM Win32_NetworkAdapter WHERE NetConnectionID = '" + adapterName.Replace("'", "''") + "'"))
                {
                    foreach (System.Management.ManagementObject obj in searcher.Get())
                    {
                        var value = obj["NetEnabled"];
                        if (value is bool)
                        {
                            return (bool)value;
                        }
                    }
                }
            }
            catch
            {
            }

            return false;
        }

        public static void QueueAction(string actionFile, string taskName, string action)
        {
            var dir = Path.GetDirectoryName(actionFile);
            if (!string.IsNullOrEmpty(dir) && !Directory.Exists(dir))
            {
                Directory.CreateDirectory(dir);
            }

            File.WriteAllText(actionFile, action);
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
        private readonly string _repoRoot;
        private readonly string _actionFile;
        private readonly string _signalFile;
        private readonly string _iconPath;
        private readonly string _logoPath;
        private readonly NotifyIcon _notifyIcon;
        private readonly Form _form;
        private readonly Label _statusLabel;
        private readonly Button _toggleButton;
        private readonly System.Windows.Forms.Timer _timer;
        private Bitmap _heldBitmap;
        private IntPtr _iconHandle = IntPtr.Zero;
        private bool _isClosing;

        public MainApplicationContext(AppConfig config, string repoRoot)
        {
            _config = config;
            _repoRoot = repoRoot;
            _actionFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "pending-action.txt");
            _signalFile = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "EthernetToggle", "show-window.signal");
            _iconPath = Path.Combine(repoRoot, "assets", "icon.ico");
            _logoPath = Path.Combine(repoRoot, "assets", "logo.png");

            _form = BuildForm(out _statusLabel, out _toggleButton);
            MainForm = _form;
            _notifyIcon = BuildNotifyIcon();
            _timer = new System.Windows.Forms.Timer { Interval = 2000 };
            _timer.Tick += OnTimerTick;
            _timer.Start();

            UpdateState();
            _form.Show();
        }

        private Form BuildForm(out Label statusLabel, out Button toggleButton)
        {
            var form = new Form
            {
                Text = _config.appName,
                ClientSize = new Size(360, 280),
                MinimumSize = new Size(360, 280),
                MaximumSize = new Size(360, 280),
                FormBorderStyle = FormBorderStyle.FixedSingle,
                MaximizeBox = false,
                StartPosition = FormStartPosition.CenterScreen,
                BackColor = Color.FromArgb(30, 30, 30),
                ForeColor = Color.White
            };

            if (File.Exists(_logoPath))
            {
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
                    // Window icon is optional; tray uses CreateTrayIcon fallback.
                }
            }

            var headerPanel = new Panel
            {
                Dock = DockStyle.Top,
                Height = 84,
                BackColor = Color.FromArgb(24, 24, 24),
                Padding = new Padding(16, 12, 16, 8)
            };

            var logoPicture = new PictureBox
            {
                Size = new Size(52, 52),
                Location = new Point(16, 14),
                SizeMode = PictureBoxSizeMode.Zoom
            };
            if (File.Exists(_logoPath))
            {
                logoPicture.Image = Image.FromFile(_logoPath);
            }

            var titleLabel = new Label
            {
                Text = _config.appName,
                Font = new Font("Segoe UI", 13f, FontStyle.Bold),
                ForeColor = Color.White,
                AutoSize = true,
                Location = new Point(80, 18)
            };

            var adapterLabel = new Label
            {
                Text = "Adapter: " + _config.adapterName,
                Font = new Font("Segoe UI", 9f),
                ForeColor = Color.FromArgb(170, 170, 170),
                AutoSize = true,
                Location = new Point(82, 46)
            };

            headerPanel.Controls.Add(logoPicture);
            headerPanel.Controls.Add(titleLabel);
            headerPanel.Controls.Add(adapterLabel);

            var contentPanel = new Panel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(20, 16, 20, 20),
                BackColor = Color.FromArgb(30, 30, 30)
            };

            statusLabel = new Label
            {
                Font = new Font("Segoe UI", 12f, FontStyle.Bold),
                AutoSize = true,
                Location = new Point(0, 0)
            };

            toggleButton = new Button
            {
                Size = new Size(320, 40),
                Location = new Point(0, 36),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 10f, FontStyle.Bold),
                Cursor = Cursors.Hand
            };
            toggleButton.FlatAppearance.BorderSize = 0;
            toggleButton.Click += (s, e) => RunAction("Toggle");

            var enableButton = new Button
            {
                Text = "Enable",
                Size = new Size(154, 34),
                Location = new Point(0, 88),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(45, 45, 45),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9f)
            };
            enableButton.FlatAppearance.BorderColor = Color.FromArgb(70, 70, 70);
            enableButton.Click += (s, e) => RunAction("Enable");

            var disableButton = new Button
            {
                Text = "Disable",
                Size = new Size(154, 34),
                Location = new Point(166, 88),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(45, 45, 45),
                ForeColor = Color.White,
                Font = new Font("Segoe UI", 9f)
            };
            disableButton.FlatAppearance.BorderColor = Color.FromArgb(70, 70, 70);
            disableButton.Click += (s, e) => RunAction("Disable");

            var hintLabel = new Label
            {
                Text = "Close hides to tray. Right-click tray icon to exit.",
                Font = new Font("Segoe UI", 8.5f),
                ForeColor = Color.FromArgb(130, 130, 130),
                AutoSize = true,
                Location = new Point(0, 132)
            };

            contentPanel.Controls.Add(statusLabel);
            contentPanel.Controls.Add(toggleButton);
            contentPanel.Controls.Add(enableButton);
            contentPanel.Controls.Add(disableButton);
            contentPanel.Controls.Add(hintLabel);

            form.Controls.Add(contentPanel);
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

        protected override void OnMainFormClosed(object sender, EventArgs e)
        {
            if (!_isClosing)
            {
                return;
            }

            base.OnMainFormClosed(sender, e);
        }

        private NotifyIcon BuildNotifyIcon()
        {
            var menu = new ContextMenuStrip();
            var showItem = new ToolStripMenuItem("Show Window");
            var enableItem = new ToolStripMenuItem("Enable Ethernet");
            var disableItem = new ToolStripMenuItem("Disable Ethernet");
            var exitItem = new ToolStripMenuItem("Exit");

            showItem.Click += (s, e) => ShowMainWindow();
            enableItem.Click += (s, e) => RunAction("Enable");
            disableItem.Click += (s, e) => RunAction("Disable");
            exitItem.Click += (s, e) =>
            {
                _isClosing = true;
                _form.Close();
            };

            menu.Items.Add(showItem);
            menu.Items.Add(enableItem);
            menu.Items.Add(disableItem);
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

        private void ShowMainWindow()
        {
            _form.Show();
            _form.WindowState = FormWindowState.Normal;
            _form.Activate();
        }

        private void RunAction(string action)
        {
            AdapterHelper.QueueAction(_actionFile, _config.taskName, action);
            Thread.Sleep(750);
            UpdateState();
        }

        private void OnTimerTick(object sender, EventArgs e)
        {
            if (File.Exists(_signalFile))
            {
                try { File.Delete(_signalFile); } catch { }
                ShowMainWindow();
            }

            UpdateState();
        }

        private void UpdateState()
        {
            var isEnabled = AdapterHelper.IsEnabled(_config.adapterName);

            _statusLabel.Text = isEnabled ? "Ethernet is ON" : "Ethernet is OFF";
            _statusLabel.ForeColor = isEnabled ? Color.FromArgb(46, 160, 67) : Color.FromArgb(160, 160, 160);
            _toggleButton.Text = isEnabled ? "Disable Ethernet" : "Enable Ethernet";
            _notifyIcon.Text = _config.appName + (isEnabled ? ": On" : ": Off");

            SetTrayIcon(isEnabled);
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
                        drewLogo = false;
                    }
                }

                if (!drewLogo)
                {
                    using (var brush = new SolidBrush(isOn ? Color.FromArgb(46, 160, 67) : Color.FromArgb(140, 140, 140)))
                    {
                        graphics.FillEllipse(brush, 2, 2, 12, 12);
                    }
                }
                else
                {
                    using (var brush = new SolidBrush(isOn ? Color.FromArgb(46, 160, 67) : Color.FromArgb(140, 140, 140)))
                    {
                        graphics.FillEllipse(brush, 10, 10, 5, 5);
                    }
                }
            }

            if (_heldBitmap != null)
            {
                _heldBitmap.Dispose();
            }

            if (_iconHandle != IntPtr.Zero)
            {
                NativeMethods.DestroyIcon(_iconHandle);
            }

            _heldBitmap = bitmap;
            _iconHandle = bitmap.GetHicon();
            return Icon.FromHandle(_iconHandle);
        }

        private void SetTrayIcon(bool isOn)
        {
            var newIcon = CreateTrayIcon(isOn);

            if (_notifyIcon.Icon != null)
            {
                _notifyIcon.Icon.Dispose();
            }

            _notifyIcon.Icon = newIcon;
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

                MessageBox.Show(ex.ToString(), "Ethernet Toggle Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
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
