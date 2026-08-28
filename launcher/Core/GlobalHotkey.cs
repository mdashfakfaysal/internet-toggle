using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace EthernetToggle.Core
{
    internal sealed class GlobalHotkey : NativeWindow, IDisposable
    {
        private const int WmHotkey = 0x0312;
        private readonly int _id;
        private bool _registered;

        public event EventHandler HotkeyPressed;

        public GlobalHotkey(IWin32Window window, int id, Keys key, uint modifiers)
        {
            _id = id;
            AssignHandle(window.Handle);
            RegisterHotKey(Handle, _id, modifiers, (uint)key);
            _registered = true;
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == WmHotkey && m.WParam.ToInt32() == _id)
            {
                var handler = HotkeyPressed;
                if (handler != null)
                {
                    handler(this, EventArgs.Empty);
                }
            }

            base.WndProc(ref m);
        }

        public void Dispose()
        {
            if (_registered)
            {
                UnregisterHotKey(Handle, _id);
                _registered = false;
            }
        }

        [DllImport("user32.dll")]
        private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

        [DllImport("user32.dll")]
        private static extern bool UnregisterHotKey(IntPtr hWnd, int id);
    }
}
