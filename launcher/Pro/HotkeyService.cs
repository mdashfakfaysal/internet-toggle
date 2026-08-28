using System;
using System.Collections.Generic;
using System.Windows.Forms;
using EthernetToggle.Core;
using EthernetToggle.Edition;

namespace EthernetToggle.Pro
{
    internal sealed class HotkeyService : IDisposable
    {
        private readonly Form _host;
        private readonly ProDataStore _store;
        private readonly Dictionary<int, GlobalHotkey> _registered = new Dictionary<int, GlobalHotkey>();

        public event Action<string> HotkeyActionRequested;

        public HotkeyService(Form host, ProDataStore store)
        {
            _host = host;
            _store = store;
        }

        public void RegisterAll(bool isPro)
        {
            DisposeRegistered();

            if (isPro && EditionService.CanUseFeature(Feature.AdvancedHotkeys))
            {
                RegisterBinding(1, _store.Settings.hotkeys.switchWifi, "SwitchWifi");
                RegisterBinding(2, _store.Settings.hotkeys.switchEthernet, "SwitchEthernet");
                RegisterBinding(3, _store.Settings.hotkeys.toggleEthernet, "ToggleEthernet");
                RegisterBinding(4, _store.Settings.hotkeys.applyProfile1, "ApplyProfile1");
                RegisterBinding(5, _store.Settings.hotkeys.applyProfile2, "ApplyProfile2");
                return;
            }

            if (EditionService.CanUseFeature(Feature.BasicHotkey))
            {
                RegisterBinding(1, _store.Settings.hotkeys.switchWifi, "SwitchWifi");
            }
        }

        private void RegisterBinding(int id, HotkeyBinding binding, string actionName)
        {
            if (binding == null || !binding.enabled || binding.key <= 0)
            {
                return;
            }

            try
            {
                var hotkey = new GlobalHotkey(_host, id, (Keys)binding.key, binding.modifiers);
                hotkey.HotkeyPressed += (s, e) =>
                {
                    var handler = HotkeyActionRequested;
                    if (handler != null)
                    {
                        handler(actionName);
                    }
                };
                _registered[id] = hotkey;
            }
            catch
            {
            }
        }

        public void Dispose()
        {
            DisposeRegistered();
        }

        private void DisposeRegistered()
        {
            foreach (var hotkey in _registered.Values)
            {
                hotkey.Dispose();
            }

            _registered.Clear();
        }
    }
}
