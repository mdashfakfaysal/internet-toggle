using System;
using System.Drawing;
using System.Windows.Forms;
using EthernetToggle.Pro;

namespace EthernetToggle.UI
{
    internal sealed class HotkeyCaptureForm : Form
    {
        private readonly Label _prompt;
        public HotkeyBinding ResultBinding { get; private set; }

        public HotkeyCaptureForm(HotkeyBinding current)
        {
            Text = "Capture Hotkey";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(360, 140);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;
            KeyPreview = true;

            _prompt = new Label
            {
                Text = "Press the key combination...",
                Font = new Font("Segoe UI", 10f),
                AutoSize = false,
                Size = new Size(320, 48),
                Location = new Point(20, 20),
                ForeColor = Color.FromArgb(220, 220, 220)
            };

            var cancel = new Button
            {
                Text = "Cancel",
                DialogResult = DialogResult.Cancel,
                Size = new Size(88, 30),
                Location = new Point(252, 92),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(55, 55, 55),
                ForeColor = Color.White
            };

            Controls.Add(_prompt);
            Controls.Add(cancel);

            if (current != null)
            {
                _prompt.Text = "Current: " + FormatBinding(current) + Environment.NewLine + "Press a new combination...";
            }

            KeyDown += OnKeyDown;
        }

        private void OnKeyDown(object sender, KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape)
            {
                DialogResult = DialogResult.Cancel;
                Close();
                return;
            }

            if (e.KeyCode == Keys.ControlKey || e.KeyCode == Keys.ShiftKey || e.KeyCode == Keys.Menu)
            {
                return;
            }

            uint modifiers = 0;
            if (e.Control) modifiers |= 0x0002;
            if (e.Alt) modifiers |= 0x0001;
            if (e.Shift) modifiers |= 0x0004;

            if (modifiers == 0)
            {
                _prompt.Text = "Use at least Ctrl and/or Alt.";
                return;
            }

            ResultBinding = new HotkeyBinding
            {
                key = (int)e.KeyCode,
                modifiers = modifiers,
                enabled = true
            };

            DialogResult = DialogResult.OK;
            Close();
        }

        public static string FormatBinding(HotkeyBinding binding)
        {
            if (binding == null || !binding.enabled)
            {
                return "Disabled";
            }

            var parts = new System.Collections.Generic.List<string>();
            if ((binding.modifiers & 0x0002) != 0) parts.Add("Ctrl");
            if ((binding.modifiers & 0x0001) != 0) parts.Add("Alt");
            if ((binding.modifiers & 0x0004) != 0) parts.Add("Shift");
            parts.Add(((Keys)binding.key).ToString());
            return string.Join("+", parts.ToArray());
        }
    }
}
