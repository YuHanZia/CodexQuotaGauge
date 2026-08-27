$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$sourceDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateDir = Join-Path $env:LOCALAPPDATA 'CodexQuotaGauge'
$appDir = Join-Path $stateDir 'app'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Quota Gauge.lnk'
$launcher = Join-Path $appDir 'Start Codex Quota Gauge.vbs'

Write-Host '[CodexQuotaGauge] Installing files'
New-Item -ItemType Directory -Force -Path $appDir | Out-Null

$files = @(
    'CodexQuotaGauge.ps1',
    'claude_usage_probe.py',
    'Start Codex Quota Gauge.vbs',
    'Uninstall.ps1',
    'Uninstall.bat'
)

foreach ($file in $files) {
    Copy-Item -LiteralPath (Join-Path $sourceDir $file) -Destination (Join-Path $appDir $file) -Force
}

if (-not (Test-Path -LiteralPath (Join-Path $stateDir 'settings.json'))) {
    @{ claude_enabled = $false } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stateDir 'settings.json') -Encoding UTF8
}

Write-Host '[CodexQuotaGauge] Stopping old process'
$targets = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq 'powershell.exe' -and
        $_.CommandLine -like '*CodexQuotaGauge.ps1*' -and
        $_.ProcessId -ne $PID
    }

foreach ($target in $targets) {
    Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host '[CodexQuotaGauge] Creating startup shortcut'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($startupShortcut)
$shortcut.TargetPath = 'wscript.exe'
$shortcut.Arguments = ('"{0}"' -f $launcher)
$shortcut.WorkingDirectory = $appDir
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host '[CodexQuotaGauge] Starting widget'
& cscript.exe //NoLogo $launcher

Write-Host ''
Write-Host 'CodexQuotaGauge installed.'
Write-Host 'The widget should appear near the Windows taskbar notification area.'
