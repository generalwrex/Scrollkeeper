# Opens a ready-to-send "Share your data" issue for Scrollkeeper.
#
#   Double-click share-scrollkeeper-data.bat, or:
#   powershell -ExecutionPolicy Bypass -File share-scrollkeeper-data.ps1
#
# Reads your latest /sk export from Scrollkeeper's saved data (saved when
# you log out or /reload), copies it to the clipboard, and opens the GitHub
# issue page with the title and export already filled in. You just check
# it and click "Create". Nothing is sent without you.
#
# Optional: -WowFolder "D:\Games\World of Warcraft\_forever_"
param(
    [string]$WowFolder = ""
)
$ErrorActionPreference = "Stop"

# Inside the addon (...\_forever_\Interface\AddOns\Scrollkeeper\tools\community)
# the game folder is five levels up.
if (-not $WowFolder) {
    $guess = $PSScriptRoot
    for ($i = 0; $i -lt 5 -and $guess; $i++) { $guess = Split-Path $guess -Parent }
    if ($guess -and (Test-Path (Join-Path $guess "WTF"))) { $WowFolder = $guess }
    else { $WowFolder = "L:\Games\World of Warcraft\_forever_" }
}

# --- Find the saved data (newest if you have several accounts) ------------
$accounts = Join-Path $WowFolder "WTF\Account"
if (-not (Test-Path $accounts)) {
    Write-Host "Couldn't find $accounts" -ForegroundColor Red
    Write-Host "Run it again with your game folder, for example:"
    Write-Host '  powershell -ExecutionPolicy Bypass -File share-scrollkeeper-data.ps1 -WowFolder "C:\Games\World of Warcraft\_forever_"'
    exit 1
}
$file = Get-ChildItem -Path $accounts -Recurse -Filter "Scrollkeeper.lua" -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -like "*SavedVariables" } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $file) {
    Write-Host "No Scrollkeeper saved data yet. Log in on a mage, then log out (or /reload) and try again." -ForegroundColor Yellow
    exit 1
}
$text = Get-Content -Path $file.FullName -Raw -Encoding UTF8

# --- Pull out the export and its title ------------------------------------
function Read-LuaString([string]$source, [string]$key) {
    $pattern = '\["' + [regex]::Escape($key) + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"'
    $match = [regex]::Match($source, $pattern)
    if (-not $match.Success) { return $null }
    $value = $match.Groups[1].Value
    # Undo Lua escapes: \n, \", \\ (in that order of safety)
    $mark = [string][char]1
    $value = $value.Replace('\\', $mark).Replace('\n', "`n").Replace('\"', '"')
    return $value.Replace($mark, '\')
}
$export = Read-LuaString $text "lastExport"
$title = Read-LuaString $text "lastExportTitle"
if (-not $export) {
    Write-Host "Your saved data doesn't have an export yet." -ForegroundColor Yellow
    Write-Host "Update Scrollkeeper, log in on a mage, then log out (or /reload) and run this again."
    exit 1
}
if (-not $title) { $title = "[Data] " }

# --- Clipboard + open the issue -------------------------------------------
Set-Clipboard -Value $export
$base = "https://github.com/generalwrex/scrollkeeper/issues/new?template=share_data.yml"
$url = $base + "&title=" + [uri]::EscapeDataString($title) + "&export=" + [uri]::EscapeDataString($export)
Write-Host ""
Write-Host "Export found ($($export.Split("`n").Count) lines, saved $($file.LastWriteTime))." -ForegroundColor Green
Write-Host "Title: $title"
if ($url.Length -gt 7500) {
    # Too long for a link: open the form with just the title, paste the rest.
    $url = $base + "&title=" + [uri]::EscapeDataString($title)
    Write-Host "It's big, so paste it yourself: click the export box and press Ctrl+V (it's on your clipboard)." -ForegroundColor Yellow
} else {
    Write-Host "Opening GitHub with everything filled in. Check it and click Create. (It's on your clipboard too.)"
}
Start-Process $url
