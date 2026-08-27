$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$stateDir = Join-Path $env:LOCALAPPDATA 'CodexQuotaGauge'
$startupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Quota Gauge.lnk'

Write-Host '[CodexQuotaGauge] 停止常駐程式'
$targets = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq 'powershell.exe' -and
        $_.CommandLine -like '*CodexQuotaGauge.ps1*' -and
        $_.ProcessId -ne $PID
    }

foreach ($target in $targets) {
    Stop-Process -Id $target.ProcessId -Force -ErrorAction SilentlyContinue
}

Write-Host '[CodexQuotaGauge] 移除開機自動啟動捷徑'
Remove-Item -LiteralPath $startupShortcut -Force -ErrorAction SilentlyContinue

Write-Host '[CodexQuotaGauge] 移除本機安裝檔與狀態檔'
if (Test-Path -LiteralPath $stateDir) {
    Remove-Item -LiteralPath $stateDir -Recurse -Force
}

Write-Host ''
Write-Host '已移除 Claude / Codex 額度監控。'
