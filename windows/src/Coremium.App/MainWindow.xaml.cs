using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Interop;
using System.Windows.Media;
using Coremium.Core;

namespace Coremium.App;

public partial class MainWindow : Window
{
    readonly Engine engine;

    internal MainWindow(Engine engine)
    {
        InitializeComponent();
        this.engine = engine;
        DataContext = engine;
        engine.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName == nameof(Engine.Load)) LoadBar.Width = Math.Max(4, (LoadBar.Parent as FrameworkElement)!.ActualWidth * engine.Load);
            if (e.PropertyName is nameof(Engine.Paused) or nameof(Engine.Advanced)) UpdateButtons();
        };
        IsVisibleChanged += (_, _) => engine.WindowVisible = IsVisible;
        SourceInitialized += (_, _) => DarkTitleBar();
        UpdateButtons();
    }

    /// <summary>Closing the window keeps Coremium running in the tray; quit from the tray menu.</summary>
    protected override void OnClosing(CancelEventArgs e) { e.Cancel = true; Hide(); }

    void DarkTitleBar()
    {
        var hwnd = new WindowInteropHelper(this).Handle;
        int on = 1, mica = 2;
        Native.DwmSetWindowAttribute(hwnd, 20, ref on, sizeof(int));      // DWMWA_USE_IMMERSIVE_DARK_MODE
        Native.DwmSetWindowAttribute(hwnd, 38, ref mica, sizeof(int));    // DWMWA_SYSTEMBACKDROP_TYPE (Windows 11), ignored elsewhere
    }

    void UpdateButtons()
    {
        PauseButton.Content = engine.Paused ? "Resume" : "Pause";
        PauseButton.Background = engine.Paused ? new SolidColorBrush(Color.FromRgb(0xF5, 0xD2, 0x5B)) : new SolidColorBrush(Color.FromArgb(0x16, 255, 255, 255));
        PauseButton.Foreground = engine.Paused ? Brushes.Black : Brushes.White;
        AdvancedButton.Background = engine.Advanced ? (Brush)FindResource("Perf") : new SolidColorBrush(Color.FromArgb(0x16, 255, 255, 255));
        AdvancedButton.Foreground = engine.Advanced ? Brushes.Black : Brushes.White;
    }

    async void Storage_Click(object sender, RoutedEventArgs e)
    {
        var show = StorageView.Visibility != Visibility.Visible;
        StorageView.Visibility = show ? Visibility.Visible : Visibility.Collapsed;
        AppsView.Visibility = show ? Visibility.Collapsed : Visibility.Visible;
        StorageButton.Background = show ? Brushes.White : new SolidColorBrush(Color.FromArgb(0x16, 255, 255, 255));
        StorageButton.Foreground = show ? Brushes.Black : Brushes.White;
        if (show && engine.Storage.Rows.Count == 0) await engine.Storage.ScanAsync();
    }

    async void StorageScan_Click(object sender, RoutedEventArgs e) => await engine.Storage.ScanAsync();

    async void StorageReview_Click(object sender, RoutedEventArgs e)
    {
        var (text, move, _) = engine.Storage.Review();
        if (move.Count == 0) { engine.Storage.Status = "Nothing selected to move."; return; }
        // Nothing moves without this explicit confirmation.
        if (MessageBox.Show(this, text, "Coremium: review before moving", MessageBoxButton.OKCancel, MessageBoxImage.Warning, MessageBoxResult.Cancel) == MessageBoxResult.OK)
            await engine.Storage.CleanAsync(move);
    }

    void Mode_Click(object sender, RoutedEventArgs e) => engine.SetMode((Mode)((Button)sender).Tag);
    void Pause_Click(object sender, RoutedEventArgs e) => engine.Paused = !engine.Paused;
    void Advanced_Click(object sender, RoutedEventArgs e) => engine.Advanced = !engine.Advanced;

    void Chip_Click(object sender, RoutedEventArgs e)
    {
        var b = (Button)sender;
        if (b.Tag is string id && b.DataContext is ChipVM chip) engine.Toggle(id, chip.Rule);
    }
}
