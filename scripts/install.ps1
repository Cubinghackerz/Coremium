# Installs the latest Coremium for Windows (beta) for the current user. Usage, in PowerShell:
#   irm https://raw.githubusercontent.com/Cubinghackerz/Coremium/master/scripts/install.ps1 | iex
# Downloads the newest windows-v* release, checks its SHA-256 against the published checksum, installs to
# %LOCALAPPDATA%\Programs\Coremium (no admin), adds a Start menu shortcut and starts it. Run it again to update.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$repo = 'Cubinghackerz/Coremium'

Write-Host 'Finding the latest Windows release...'
# Parentheses make PowerShell enumerate the JSON array instead of passing it on as one object.
$release = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases?per_page=30" -Headers @{ 'User-Agent' = 'coremium-installer' }) |
    Where-Object { $_.tag_name -like 'windows-v*' } | Select-Object -First 1
if (-not $release) { throw "No Windows release found at https://github.com/$repo/releases" }
$zipAsset = $release.assets | Where-Object { $_.name -like '*.zip' } | Select-Object -First 1
$sumAsset = $release.assets | Where-Object { $_.name -like '*.sha256' } | Select-Object -First 1
if (-not $zipAsset -or -not $sumAsset) { throw "Release $($release.tag_name) is missing its files." }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("coremium-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp $zipAsset.name
    Invoke-WebRequest $zipAsset.browser_download_url -OutFile $zip -UseBasicParsing
    $sums = Join-Path $tmp 'sums.txt'
    Invoke-WebRequest $sumAsset.browser_download_url -OutFile $sums -UseBasicParsing
    $expected = ((Get-Content $sums -Raw) -split '\s+')[0].Trim().ToLower()
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
    if ($expected -ne $actual) { throw 'Checksum mismatch. Nothing was installed.' }
    Write-Host 'Checksum OK.'

    $dir = Join-Path $env:LOCALAPPDATA 'Programs\Coremium'
    $exe = Join-Path $dir 'Coremium.exe'
    $running = Get-Process -Name Coremium -ErrorAction SilentlyContinue
    if ($running) {
        $running | Stop-Process -Force
        Start-Sleep -Seconds 1
        if (Test-Path $exe) { & $exe --restore-all | Out-Null }   # put every app back before replacing the program
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Expand-Archive $zip -DestinationPath $dir -Force

    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Programs')) 'Coremium.lnk'))
    $link.TargetPath = $exe
    $link.Description = 'Coremium (beta)'
    $link.Save()

    Start-Process $exe
    Write-Host "Coremium $($release.tag_name) is installed. It is in the Start menu and the system tray."
}
finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
