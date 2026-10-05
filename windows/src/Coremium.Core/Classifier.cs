namespace Coremium.Core;

/// <summary>Recognises apps by executable name and install path. Unknown apps are "Other" and are left alone.</summary>
public static class Classifier
{
    static readonly Dictionary<string, Category> Known = new(StringComparer.OrdinalIgnoreCase)
    {
        // games and launchers
        ["robloxplayerbeta"] = Category.Game, ["javaw"] = Category.Game, ["minecraft"] = Category.Game, ["minecraftlauncher"] = Category.Game,
        ["modrinth app"] = Category.Game, ["steam"] = Category.Game, ["epicgameslauncher"] = Category.Game, ["fortniteclient-win64-shipping"] = Category.Game,
        ["valorant-win64-shipping"] = Category.Game, ["cs2"] = Category.Game, ["leagueclient"] = Category.Game, ["league of legends"] = Category.Game,
        ["gta5"] = Category.Game, ["eldenring"] = Category.Game, ["overwatch"] = Category.Game, ["battle.net"] = Category.Game,
        // creative
        ["premiere pro"] = Category.Creative, ["adobe premiere pro"] = Category.Creative, ["afterfx"] = Category.Creative, ["photoshop"] = Category.Creative,
        ["illustrator"] = Category.Creative, ["resolve"] = Category.Creative, ["blender"] = Category.Creative, ["obs64"] = Category.Creative,
        ["capcut"] = Category.Creative, ["fl64"] = Category.Creative, ["ableton live 12 suite"] = Category.Creative, ["figma"] = Category.Creative,
        ["unity"] = Category.Creative, ["unrealeditor"] = Category.Creative, ["krita"] = Category.Creative, ["audacity"] = Category.Creative,
        // developer
        ["code"] = Category.Developer, ["cursor"] = Category.Developer, ["devenv"] = Category.Developer, ["rider64"] = Category.Developer,
        ["idea64"] = Category.Developer, ["pycharm64"] = Category.Developer, ["windowsterminal"] = Category.Developer, ["wt"] = Category.Developer,
        ["powershell"] = Category.Developer, ["pwsh"] = Category.Developer, ["cmd"] = Category.Developer, ["windsurf"] = Category.Developer,
        ["zed"] = Category.Developer, ["sublime_text"] = Category.Developer, ["docker desktop"] = Category.Developer, ["androidstudio64"] = Category.Developer,
        ["studio64"] = Category.Developer, ["antigravity"] = Category.Developer, ["warp"] = Category.Developer,
        // local AI and compute
        ["ollama"] = Category.LocalAI, ["ollama app"] = Category.LocalAI, ["lm studio"] = Category.LocalAI, ["lmstudio"] = Category.LocalAI,
        ["comfyui"] = Category.LocalAI, ["gpt4all"] = Category.LocalAI, ["jan"] = Category.LocalAI, ["vmware"] = Category.LocalAI,
        ["virtualboxvm"] = Category.LocalAI, ["vmmem"] = Category.LocalAI,
        // browsers
        ["chrome"] = Category.Browser, ["msedge"] = Category.Browser, ["firefox"] = Category.Browser, ["brave"] = Category.Browser,
        ["opera"] = Category.Browser, ["vivaldi"] = Category.Browser, ["arc"] = Category.Browser, ["zen"] = Category.Browser, ["comet"] = Category.Browser,
        // communication
        ["discord"] = Category.Communication, ["slack"] = Category.Communication, ["teams"] = Category.Communication, ["ms-teams"] = Category.Communication,
        ["zoom"] = Category.Communication, ["whatsapp"] = Category.Communication, ["telegram"] = Category.Communication, ["outlook"] = Category.Communication,
        ["olk"] = Category.Communication, ["signal"] = Category.Communication,
        // AI assistants
        ["claude"] = Category.AI, ["chatgpt"] = Category.AI, ["copilot"] = Category.AI, ["perplexity"] = Category.AI,
        // media
        ["spotify"] = Category.Media, ["vlc"] = Category.Media, ["music.ui"] = Category.Media, ["itunes"] = Category.Media,
        // productivity
        ["winword"] = Category.Productivity, ["excel"] = Category.Productivity, ["powerpnt"] = Category.Productivity, ["notion"] = Category.Productivity,
        ["obsidian"] = Category.Productivity, ["onenote"] = Category.Productivity,
        // system
        ["explorer"] = Category.System, ["taskmgr"] = Category.System, ["systemsettings"] = Category.System,
    };

    public static Category Classify(string exeName, string? path)
    {
        if (Known.TryGetValue(exeName, out var c)) return c;
        var p = path?.Replace('/', '\\').ToLowerInvariant() ?? "";
        if (p.Contains("\\steamapps\\common\\") || p.Contains("\\epic games\\") || p.Contains("\\riot games\\") || p.Contains("\\xboxgames\\")) return Category.Game;
        if (p.Contains("\\adobe\\") || p.Contains("\\blackmagic design\\")) return Category.Creative;
        if (p.Contains("\\jetbrains\\")) return Category.Developer;
        return Category.Other;
    }
}
