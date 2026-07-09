# build.ps1 - Export Extraction Survivors for Windows + Linux and print itch.io push commands.
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\build.ps1
#
# Requirements:
#   - Godot 4.6.1 (path below) with 4.6.1.stable export templates installed
#     (Editor -> Editor Settings -> Export Templates, or unpack the official
#     Godot_v4.6.1-stable_export_templates.tpz into
#     %APPDATA%\Godot\export_templates\4.6.1.stable\)
#   - butler (https://itch.io/docs/butler/) installed + `butler login` done
#     before running the printed push commands.
#
# PowerShell 5.1 compatible (no &&, no ternary operators).

# ---- Fill these in before pushing to itch.io -------------------------------
$ButlerUser = "YOUR_ITCH_USERNAME"    # TODO(Ben): your itch.io username
$ItchSlug   = "extraction-survivors"  # TODO(Ben): confirm the itch.io project slug
# -----------------------------------------------------------------------------

$GodotExe    = "E:\Godot\Godot_v4.6.1-stable_win64.exe"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not (Test-Path $GodotExe)) {
    Write-Error "Godot binary not found at $GodotExe - update `$GodotExe in build.ps1"
    exit 1
}

# ---- Read version from project.godot ---------------------------------------
$projectFile = Join-Path $ProjectRoot "project.godot"
$versionMatch = Select-String -Path $projectFile -Pattern '^config/version="([^"]+)"' | Select-Object -First 1
if ($null -eq $versionMatch) {
    Write-Error "Could not read config/version from project.godot"
    exit 1
}
$Version = $versionMatch.Matches[0].Groups[1].Value
Write-Host "=== Extraction Survivors v$Version ===" -ForegroundColor Cyan

# ---- Export targets ---------------------------------------------------------
$targets = @(
    @{ Preset = "Windows Desktop"; OutDir = "build\windows"; OutFile = "extraction-survivors.exe";    Channel = "windows" },
    @{ Preset = "Linux/X11";       OutDir = "build\linux";   OutFile = "extraction-survivors.x86_64"; Channel = "linux" }
)

foreach ($t in $targets) {
    $outDir  = Join-Path $ProjectRoot $t.OutDir
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir $t.OutFile

    Write-Host ""
    Write-Host "Exporting '$($t.Preset)' -> $outPath" -ForegroundColor Yellow
    & $GodotExe --headless --path $ProjectRoot --export-release $t.Preset $outPath

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Export failed for preset '$($t.Preset)' (exit code $LASTEXITCODE)"
        exit 1
    }
    if (-not (Test-Path $outPath)) {
        Write-Error "Export reported success but $outPath was not created"
        exit 1
    }
    $sizeMB = [math]::Round((Get-Item $outPath).Length / 1MB, 1)
    Write-Host "OK: $($t.OutFile) ($sizeMB MB)" -ForegroundColor Green
}

# ---- Print (do not run) butler push commands --------------------------------
Write-Host ""
Write-Host "=== Builds complete. itch.io upload commands (run manually) ===" -ForegroundColor Cyan
if ($ButlerUser -eq "YOUR_ITCH_USERNAME") {
    Write-Host "NOTE: set `$ButlerUser and `$ItchSlug at the top of build.ps1 first." -ForegroundColor Red
}
foreach ($t in $targets) {
    $pushDir = $t.OutDir -replace '\\', '/'
    Write-Host ("  butler push {0} {1}/{2}:{3} --userversion {4}" -f $pushDir, $ButlerUser, $ItchSlug, $t.Channel, $Version)
}
Write-Host ""
Write-Host "(butler must be installed and 'butler login' completed once beforehand.)"
