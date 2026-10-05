using System;
using System.Linq;
using System.Threading;
using System.Windows;
using Coremium.Core;
using Microsoft.Win32;
using Forms = System.Windows.Forms;

namespace Coremium.App;

public partial class App : Application
{
    static Mutex? single;
    Engine? engine;
    MainWindow? window;
    Forms.NotifyIcon? tray;
    const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        // Emergency recovery: Coremium.exe --restore-all puts every app back and exits.
        if (e.Args.Contains("--restore-all"))
        {
            var count = Store.Load<Ledger>("demoted.json").Entries.Count;
            new Scheduler().RestoreAll();
            Console.WriteLine($"Coremium: restored {count} process(es).");
            Shutdown(); return;
        }
        single = new Mutex(true, "Coremium.Windows.SingleInstance", out var first);
        if (!first) { Shutdown(); return; }

        engine = new Engine();
        window = new MainWindow(engine);
        SetupTray();
        AppDomain.CurrentDomain.ProcessExit += (_, _) => engine?.Shutdown();
        if (!e.Args.Contains("--background")) ShowWindow();
    }

    void SetupTray()
    {
        var menu = new Forms.ContextMenuStrip();
        menu.Opening += (_, _) => BuildMenu(menu);
        BuildMenu(menu);
        using var stream = GetResourceStream(new Uri("pack://application:,,,/app.ico"))!.Stream;
        tray = new Forms.NotifyIcon { Icon = new System.Drawing.Icon(stream), Text = "Coremium", Visible = true, ContextMenuStrip = menu };
        tray.MouseClick += (_, a) => { if (a.Button == Forms.MouseButtons.Left) ToggleWindow(); };
    }

    void BuildMenu(Forms.ContextMenuStrip menu)
    {
        menu.Items.Clear();
        menu.Items.Add(new Forms.ToolStripMenuItem(engine!.Status) { Enabled = false });
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(window!.IsVisible ? "Hide Coremium" : "Show Coremium", null, (_, _) => ToggleWindow());
        var modes = new Forms.ToolStripMenuItem("Mode");
        foreach (var m in Enum.GetValues<Mode>())
            modes.DropDownItems.Add(new Forms.ToolStripMenuItem(Labels.Of(m), null, (_, _) => engine.SetMode(m)) { Checked = engine.Rules.Mode == m });
        menu.Items.Add(modes);
        menu.Items.Add(new Forms.ToolStripMenuItem("Pause Coremium", null, (_, _) => engine.Paused = !engine.Paused) { Checked = engine.Paused });
        menu.Items.Add(new Forms.ToolStripMenuItem("Start with Windows", null, (_, _) => SetStartup(!StartsWithWindows)) { Checked = StartsWithWindows });
        menu.Items.Add("Restore all apps now", null, (_, _) => engine.RestoreAll());
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add("Quit Coremium", null, (_, _) => Quit());
    }

    static bool StartsWithWindows => Registry.CurrentUser.OpenSubKey(RunKey)?.GetValue("Coremium") != null;

    static void SetStartup(bool on)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RunKey);
        if (on) key.SetValue("Coremium", $"\"{Environment.ProcessPath}\" --background"); else key.DeleteValue("Coremium", false);
    }

    void ToggleWindow() { if (window!.IsVisible) window.Hide(); else ShowWindow(); }

    void ShowWindow()
    {
        window!.Show();
        if (window.WindowState == WindowState.Minimized) window.WindowState = WindowState.Normal;
        window.Activate();
    }

    public void Quit()
    {
        engine?.Shutdown();
        if (tray != null) { tray.Visible = false; tray.Dispose(); }
        Shutdown();
    }
}
