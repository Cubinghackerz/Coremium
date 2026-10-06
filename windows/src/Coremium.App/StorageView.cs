using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Coremium.Core;
using Microsoft.VisualBasic.FileIO;

namespace Coremium.App;

sealed class StorageRowVM : Observable
{
    public StorageItem Item { get; init; } = null!;
    public string Name => Item.Name;
    public string Kind => StorageInfo.Title(Item.Kind);
    public string Size => StorageScanner.Format(Item.Bytes);
    bool selected;
    public bool Selected { get => selected; set { if (Set(ref selected, value)) Changed?.Invoke(); } }
    public Action? Changed;
}

/// Storage: read-only scan, then the chosen items go to the Recycle Bin after an explicit review.
sealed class StorageModel : Observable
{
    public ObservableCollection<StorageRowVM> Rows { get; } = new();
    string summary = "Scan to see temporary files, browser caches and old downloads.", status = "";
    bool scanning;
    public string Summary { get => summary; private set => Set(ref summary, value); }
    public string Status { get => status; set => Set(ref status, value); }
    public bool Scanning { get => scanning; private set => Set(ref scanning, value); }
    public long SelectedBytes => Rows.Where(r => r.Selected).Sum(r => r.Item.Bytes);
    public string SelectedText => $"Review {StorageScanner.Format(SelectedBytes)}…";

    public async Task ScanAsync()
    {
        if (Scanning) return;
        Scanning = true; Status = "";
        var downloads = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "Downloads");
        var local = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var items = await Task.Run(() => StorageScanner.Scan(Path.GetTempPath(), downloads, local, DateTime.Now));
        Rows.Clear();
        foreach (var i in items)
        {
            var row = new StorageRowVM { Item = i, Selected = i.Kind != StorageKind.OldDownloads };
            row.Changed = () => Raise(nameof(SelectedText));
            Rows.Add(row);
        }
        var total = items.Sum(i => i.Bytes);
        Summary = items.Count == 0 ? "Nothing large to clear." : $"{StorageScanner.Format(total)} can be cleared · {Rows.Count} items";
        Raise(nameof(SelectedText));
        Scanning = false;
    }

    /// Builds the warning text shown before anything moves.
    public (string Text, List<StorageItem> Move, List<StorageItem> Skip) Review()
    {
        var chosen = Rows.Where(r => r.Selected).Select(r => r.Item).ToList();
        var running = Process.GetProcesses().Select(p => { try { return p.ProcessName.ToLowerInvariant(); } catch { return ""; } }).ToHashSet();
        var skip = chosen.Where(i => i.Kind == StorageKind.BrowserCaches && running.Contains(i.Name.Split(' ')[0])).ToList();
        var move = chosen.Except(skip).ToList();
        var lines = new List<string> { $"Move {StorageScanner.Format(move.Sum(i => i.Bytes))} ({move.Count} items) to the Recycle Bin?", "" };
        foreach (var g in move.GroupBy(i => i.Kind)) lines.Add($"• {StorageInfo.Title(g.Key)}: {g.Count()} items, {StorageScanner.Format(g.Sum(i => i.Bytes))}");
        lines.Add("");
        lines.Add("Nothing is deleted for good: you can restore anything from the Recycle Bin.");
        if (move.Any(i => i.Kind == StorageKind.OldDownloads)) lines.Add("⚠ This includes your own downloads. Make sure you don't need them.");
        if (skip.Count > 0) lines.Add($"Skipping {skip.Count} browser cache(s) because the browser is open. Close it to clear those too.");
        return (string.Join(Environment.NewLine, lines), move, skip);
    }

    public async Task CleanAsync(List<StorageItem> move)
    {
        var (moved, failed) = await Task.Run(() =>
        {
            long bytes = 0; int failures = 0;
            foreach (var i in move)
            {
                try
                {
                    if (Directory.Exists(i.Path)) FileSystem.DeleteDirectory(i.Path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
                    else FileSystem.DeleteFile(i.Path, UIOption.OnlyErrorDialogs, RecycleOption.SendToRecycleBin);
                    bytes += i.Bytes;
                }
                catch { failures++; }
            }
            return (bytes, failures);
        });
        foreach (var r in Rows.Where(r => move.Contains(r.Item)).ToList()) Rows.Remove(r);
        Status = $"Moved {StorageScanner.Format(moved)} to the Recycle Bin." + (failed > 0 ? $" {failed} item(s) were in use and stayed." : "");
        Raise(nameof(SelectedText));
    }
}
