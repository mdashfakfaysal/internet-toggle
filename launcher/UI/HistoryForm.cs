using System;
using System.Drawing;
using System.Linq;
using System.Windows.Forms;
using EthernetToggle.Pro;

namespace EthernetToggle.UI
{
    internal sealed class HistoryForm : Form
    {
        public HistoryForm(ProDataStore store)
        {
            Text = "Connection History";
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            StartPosition = FormStartPosition.CenterParent;
            ClientSize = new Size(560, 380);
            BackColor = Color.FromArgb(30, 30, 30);
            ForeColor = Color.White;

            var list = new ListView
            {
                Location = new Point(16, 16),
                Size = new Size(528, 300),
                View = View.Details,
                FullRowSelect = true,
                GridLines = true,
                BackColor = Color.FromArgb(45, 45, 45),
                ForeColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle
            };
            list.Columns.Add("Time", 140);
            list.Columns.Add("Action", 90);
            list.Columns.Add("Detail", 220);
            list.Columns.Add("Source", 70);

            foreach (var entry in store.History.entries)
            {
                var item = new ListViewItem(entry.timestamp ?? string.Empty);
                item.SubItems.Add(entry.action ?? string.Empty);
                item.SubItems.Add(entry.detail ?? string.Empty);
                item.SubItems.Add(entry.source ?? string.Empty);
                list.Items.Add(item);
            }

            var close = new Button
            {
                Text = "Close",
                DialogResult = DialogResult.OK,
                Size = new Size(88, 30),
                Location = new Point(456, 332),
                FlatStyle = FlatStyle.Flat,
                BackColor = Color.FromArgb(70, 130, 220),
                ForeColor = Color.White
            };
            close.FlatAppearance.BorderSize = 0;

            Controls.Add(list);
            Controls.Add(close);
            AcceptButton = close;
        }
    }
}
