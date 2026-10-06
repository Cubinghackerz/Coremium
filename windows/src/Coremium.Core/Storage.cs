namespace Coremium.Core;

public enum StorageKind { TempFiles, BrowserCaches, OldDownloads }

public sealed record StorageItem(string Path, string Name, StorageKind Kind, long Bytes);

public static class StorageInfo
{
    public static string Title(StorageKind k) => k switch
    {
        StorageKind.TempFiles => "Temporary files",
        StorageKind.BrowserCaches => "Browser caches",
        _ => "Old downloads",
    };

    public static string Explanation(StorageKind k) => k switch
    {
        StorageKind.TempFiles => "Leftovers apps put in your temp folder. Only items older than a day are offered.",
        StorageKind.BrowserCaches => "Cached web pages and images. Browsers rebuild them; skipped while the browser is open.",
        _ => "Files in Downloads you haven't touched for 90 days. Check them before clearing.",
    };
}

/// Read-only scan of a few folders that are safe to clear. Everything cleared goes to the Recycle Bin (App side).
public static class StorageScanner
{
    public static long SizeOf(string path)
    {
        try
        {
            if (File.Exists(path)) return new FileInfo(path).Length;
            long total = 0;
            var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true, AttributesToSkip = FileAttributes.ReparsePoint };
            foreach (var f in new DirectoryInfo(path).EnumerateFiles("*", options)) total += f.Length;
            return total;
        }
        catch { return 0; }
    }

    /// Browser cache folders: (browser process name, cache folder).
    public static IEnumerable<(string Process, string Folder)> BrowserCacheFolders(string localAppData)
    {
        foreach (var (proc, root) in new[]
                 {
                     ("chrome", Path.Combine(localAppData, @"Google\Chrome\User Data")),
                     ("msedge", Path.Combine(localAppData, @"Microsoft\Edge\User Data")),
                     ("brave", Path.Combine(localAppData, @"BraveSoftware\Brave-Browser\User Data")),
                 })
        {
            if (!Directory.Exists(root)) continue;
            foreach (var profile in Directory.EnumerateDirectories(root))
                foreach (var cache in new[] { "Cache", "Code Cache", "GPUCache" })
                {
                    var dir = Path.Combine(profile, cache);
                    if (Directory.Exists(dir)) yield return (proc, dir);
                }
        }
    }

    public static List<StorageItem> Scan(string temp, string downloads, string localAppData, DateTime now, long minimumBytes = 1_000_000)
    {
        var items = new List<StorageItem>();
        void Add(string path, StorageKind kind, string name)
        {
            var bytes = SizeOf(path);
            if (bytes >= minimumBytes) items.Add(new StorageItem(path, name, kind, bytes));
        }
        if (Directory.Exists(temp))
            foreach (var entry in Directory.EnumerateFileSystemEntries(temp))
            {
                try { if ((now - File.GetLastWriteTime(entry)).TotalDays >= 1 && !IsLink(entry)) Add(entry, StorageKind.TempFiles, Path.GetFileName(entry)); } catch { }
            }
        foreach (var (proc, dir) in BrowserCacheFolders(localAppData))
            Add(dir, StorageKind.BrowserCaches, $"{proc} · {Path.GetFileName(Path.GetDirectoryName(dir))} · {Path.GetFileName(dir)}");
        if (Directory.Exists(downloads))
            foreach (var entry in Directory.EnumerateFileSystemEntries(downloads))
            {
                try { if ((now - File.GetLastWriteTime(entry)).TotalDays > 90 && !IsLink(entry)) Add(entry, StorageKind.OldDownloads, Path.GetFileName(entry)); } catch { }
            }
        return items.OrderByDescending(i => i.Bytes).ToList();
    }

    static bool IsLink(string path) => (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0;

    public static string Format(long bytes)
    {
        string[] units = ["B", "KB", "MB", "GB", "TB"];
        double v = bytes; int u = 0;
        while (v >= 1000 && u < units.Length - 1) { v /= 1000; u++; }
        return u == 0 ? $"{bytes} B" : $"{v:0.#} {units[u]}";
    }
}
