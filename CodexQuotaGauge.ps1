param(
    [switch]$NoStartupPrompt
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public static class QuotaGaugeNative {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool DestroyIcon(IntPtr handle);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindow(string className, string windowName);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr FindWindowEx(IntPtr parent, IntPtr childAfter, string className, string windowName);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool SetWindowPos(
        IntPtr handle,
        IntPtr insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags
    );

    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}

public sealed class QuotaOverlayForm : Form {
    protected override bool ShowWithoutActivation {
        get { return true; }
    }

    protected override CreateParams CreateParams {
        get {
            const int WS_EX_TOOLWINDOW = 0x00000080;
            const int WS_EX_NOACTIVATE = 0x08000000;
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE;
            return cp;
        }
    }
}

public sealed class QuotaMiniPanel : Control {
    private int claudeFiveRemaining = -1;
    private int claudeWeekRemaining = -1;
    private int codexFiveRemaining = -1;
    private int codexWeekRemaining = -1;
    private bool showClaude = true;

    public QuotaMiniPanel() {
        DoubleBuffered = true;
        SetStyle(ControlStyles.AllPaintingInWmPaint |
                 ControlStyles.UserPaint |
                 ControlStyles.OptimizedDoubleBuffer, true);
        Cursor = Cursors.Hand;
    }

    public void UpdateData(int claudeFive, int claudeWeek, int codexFive, int codexWeek, bool shouldShowClaude) {
        claudeFiveRemaining = ClampQuota(claudeFive);
        claudeWeekRemaining = ClampQuota(claudeWeek);
        codexFiveRemaining = ClampQuota(codexFive);
        codexWeekRemaining = ClampQuota(codexWeek);
        showClaude = shouldShowClaude;
        Invalidate();
    }

    private static int ClampQuota(int value) {
        if (value < 0) return -1;
        return Math.Max(0, Math.Min(100, value));
    }

    private static Color QuotaColor(int remaining) {
        if (remaining < 0) return Color.FromArgb(148, 163, 184);
        if (remaining <= 15) return Color.FromArgb(248, 113, 113);
        if (remaining <= 30) return Color.FromArgb(251, 191, 36);
        return Color.FromArgb(74, 222, 128);
    }

    private static System.Drawing.Drawing2D.GraphicsPath RoundedRect(Rectangle rect, int radius) {
        int diameter = radius * 2;
        var path = new System.Drawing.Drawing2D.GraphicsPath();
        path.AddArc(rect.Left, rect.Top, diameter, diameter, 180, 90);
        path.AddArc(rect.Right - diameter, rect.Top, diameter, diameter, 270, 90);
        path.AddArc(rect.Right - diameter, rect.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(rect.Left, rect.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }

    protected override void OnPaint(PaintEventArgs e) {
        base.OnPaint(e);
        Graphics g = e.Graphics;
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        g.Clear(Color.Transparent);

        if (showClaude) {
            bool compactCodex = codexFiveRemaining < 0 && codexWeekRemaining >= 0;
            int claudePanelWidth = compactCodex ? 292 : (Width - 10) / 2;
            int codexPanelWidth = compactCodex ? Math.Max(186, Width - claudePanelWidth - 10) : claudePanelWidth;
            Rectangle claudePanel = new Rectangle(1, 1, claudePanelWidth, Height - 3);
            Rectangle codexPanel = new Rectangle(claudePanelWidth + 9, 1, codexPanelWidth, Height - 3);
            DrawDashboard(g, claudePanel, "Claude", Color.FromArgb(251, 191, 36), claudeFiveRemaining, claudeWeekRemaining);
            DrawDashboard(g, codexPanel, "Codex", Color.FromArgb(125, 211, 252), codexFiveRemaining, codexWeekRemaining);
        }
        else {
            Rectangle codexPanel = new Rectangle(1, 1, Width - 2, Height - 3);
            DrawDashboard(g, codexPanel, "Codex", Color.FromArgb(125, 211, 252), codexFiveRemaining, codexWeekRemaining);
        }
    }

    private static void DrawDashboard(Graphics g, Rectangle panel, string title, Color titleColor, int fiveRemaining, int weekRemaining) {
        bool hideFiveHour = title == "Codex" && fiveRemaining < 0 && weekRemaining >= 0;
        using (var panelPath = RoundedRect(panel, 7))
        using (Brush background = new SolidBrush(Color.FromArgb(5, 15, 27)))
        using (Pen border = new Pen(Color.FromArgb(71, 85, 105))) {
            g.FillPath(background, panelPath);
            g.DrawPath(border, panelPath);
            g.DrawLine(border, panel.Left + 68, panel.Top + 6, panel.Left + 68, panel.Bottom - 7);
            if (!hideFiveHour) {
                g.DrawLine(border, panel.Left + 182, panel.Top + 6, panel.Left + 182, panel.Bottom - 7);
            }
        }

        using (Font brandFont = new Font("Microsoft JhengHei UI", 15f, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Font valueFont = new Font("Microsoft JhengHei UI", 38f, FontStyle.Bold, GraphicsUnit.Pixel))
        using (Font labelFont = new Font("Microsoft JhengHei UI", 19f, FontStyle.Bold, GraphicsUnit.Pixel)) {
            Color labelColor = Color.FromArgb(148, 163, 184);
            TextRenderer.DrawText(g, title, brandFont, new Point(panel.Left + 10, panel.Top + 7), titleColor, TextFormatFlags.NoPadding);
            TextRenderer.DrawText(g, "\u984D\u5EA6", labelFont, new Point(panel.Left + 12, panel.Top + 36), labelColor, TextFormatFlags.NoPadding);
            if (hideFiveHour) {
                DrawMetric(g, new Rectangle(panel.Left + 72, panel.Top - 2, Math.Max(96, panel.Width - 76), panel.Height), "\u6BCF\u9031", weekRemaining, valueFont, labelFont, labelColor);
            }
            else {
                DrawMetric(g, new Rectangle(panel.Left + 70, panel.Top - 2, 112, panel.Height), "5 \u5C0F\u6642", fiveRemaining, valueFont, labelFont, labelColor);
                DrawMetric(g, new Rectangle(panel.Left + 184, panel.Top - 2, 104, panel.Height), "\u6BCF\u9031", weekRemaining, valueFont, labelFont, labelColor);
            }
        }
    }

    private static void DrawMetric(
        Graphics g,
        Rectangle column,
        string label,
        int remaining,
        Font valueFont,
        Font labelFont,
        Color labelColor
    ) {
        Color color = QuotaColor(remaining);
        string value = remaining < 0 ? "--%" : remaining + "%";
        TextFormatFlags flags = TextFormatFlags.NoPadding | TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter;
        TextRenderer.DrawText(g, value, valueFont, new Rectangle(column.Left, column.Top, column.Width, 42), color, flags);
        TextRenderer.DrawText(g, label, labelFont, new Rectangle(column.Left, column.Top + 42, column.Width, 22), labelColor, flags);
    }
}
'@

[void][QuotaGaugeNative]::SetProcessDPIAware()
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AppName = 'Claude / Codex 額度監控'
$script:RefreshSeconds = 60
$script:IsRefreshing = $false
$script:IsFirstRefresh = $true
$script:LastFiveRemaining = $null
$script:LastWeekRemaining = $null
$script:LastClaudeFiveRemaining = $null
$script:LastClaudeWeekRemaining = $null
$script:LastNotifiedFive = $null
$script:LastNotifiedWeek = $null
$script:Quota = $null
$script:ClaudeQuota = $null
$script:CurrentIcon = $null
$script:FiveHistory = New-Object 'System.Collections.Generic.List[int]'
$script:WeekHistory = New-Object 'System.Collections.Generic.List[int]'
$script:StartupShortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Codex Quota Gauge.lnk'
$script:LauncherPath = Join-Path $PSScriptRoot 'Start Codex Quota Gauge.vbs'
$script:StateDirectory = Join-Path $env:LOCALAPPDATA 'CodexQuotaGauge'
$script:StatePath = Join-Path $script:StateDirectory 'status.json'
$script:ErrorPath = Join-Path $script:StateDirectory 'last-error.txt'
$script:SettingsPath = Join-Path $script:StateDirectory 'settings.json'
$script:NotificationHistoryPath = Join-Path $script:StateDirectory 'notified-resets.json'
$script:ClaudeStatusPath = Join-Path $env:USERPROFILE '.claude\usage-status.json'
$script:ClaudeProbePath = Join-Path $PSScriptRoot 'claude_usage_probe.py'
$script:NotifiedResetKeys = @{}

[void](New-Item -ItemType Directory -Path $script:StateDirectory -Force)

$createdNew = $false
$script:Mutex = New-Object System.Threading.Mutex($true, 'Local\CodexQuotaGauge', [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show(
        'Codex 額度監控已經在執行中。',
        $script:AppName,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    exit 0
}

function Get-AppSettings {
    $defaults = [ordered]@{
        claude_enabled = $true
    }

    if (-not (Test-Path -LiteralPath $script:SettingsPath)) {
        return [pscustomobject]$defaults
    }

    try {
        $data = Get-Content -Raw -LiteralPath $script:SettingsPath | ConvertFrom-Json
        return [pscustomobject]@{
            claude_enabled = if ($null -ne $data.claude_enabled) { [bool]$data.claude_enabled } else { $true }
        }
    }
    catch {
        return [pscustomobject]$defaults
    }
}

function Test-ClaudeEnabled {
    return [bool](Get-AppSettings).claude_enabled
}

function Set-ClaudeEnabled {
    param([bool]$Enabled)

    [pscustomobject]@{
        claude_enabled = $Enabled
    } | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}
function Find-CodexCli {
    $binRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $binRoot) {
        $candidate = Get-ChildItem -LiteralPath $binRoot -Recurse -Filter 'codex.exe' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($candidate) {
            return $candidate.FullName
        }
    }

    $command = Get-Command 'codex.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source -notlike '*\WindowsApps\*') {
        return $command.Source
    }

    throw '找不到可執行的 Codex CLI。請先開啟一次 Codex Desktop，再重新整理。'
}

function Convert-ResetTime {
    param([object]$EpochSeconds)

    if ($null -eq $EpochSeconds) {
        return $null
    }

    return [DateTimeOffset]::FromUnixTimeSeconds([int64]$EpochSeconds).ToLocalTime()
}

function Convert-ClaudeResetTime {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    $text = [string]$Value
    $numeric = 0.0
    if ([double]::TryParse($text, [ref]$numeric)) {
        return [DateTimeOffset]::FromUnixTimeSeconds([int64]$numeric).ToLocalTime()
    }

    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($text, [ref]$parsed)) {
        return $parsed.ToLocalTime()
    }

    return $null
}

function Get-CodexQuota {
    $exe = Find-CodexCli
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $exe
    $startInfo.Arguments = 'app-server --stdio'
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    try {
        [void]$process.Start()
        $process.StandardInput.WriteLine('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"clientInfo":{"name":"codex-quota-gauge","version":"1.0.0"}}}')
        $process.StandardInput.WriteLine('{"jsonrpc":"2.0","id":2,"method":"account/rateLimits/read","params":{}}')
        $process.StandardInput.Flush()

        $deadline = [DateTime]::UtcNow.AddSeconds(12)
        $readTask = $process.StandardOutput.ReadLineAsync()
        $rateLimits = $null

        while ([DateTime]::UtcNow -lt $deadline -and $null -eq $rateLimits) {
            if ($readTask.Wait(100)) {
                $line = $readTask.Result
                if ($null -eq $line) {
                    break
                }

                try {
                    $message = $line | ConvertFrom-Json
                    if ($message.id -eq 2 -and $message.result.rateLimits) {
                        $rateLimits = $message.result.rateLimits
                        break
                    }
                }
                catch {
                    # Ignore non-JSON diagnostics and continue reading.
                }

                $readTask = $process.StandardOutput.ReadLineAsync()
            }

            [System.Windows.Forms.Application]::DoEvents()
        }

        if ($null -eq $rateLimits) {
            throw 'Codex 在 12 秒內沒有回傳額度資料。'
        }

        $fiveLimit = $null
        $weekLimit = $null
        foreach ($limit in @($rateLimits.primary, $rateLimits.secondary)) {
            if ($null -eq $limit) {
                continue
            }

            $duration = [int]$limit.windowDurationMins
            if ($duration -gt 0 -and $duration -le 360) {
                $fiveLimit = $limit
            }
            elseif ($duration -ge 10080) {
                $weekLimit = $limit
            }
        }

        if ($null -eq $fiveLimit -and $null -eq $weekLimit -and $rateLimits.primary) {
            $fiveLimit = $rateLimits.primary
        }

        $fiveRemaining = if ($fiveLimit) {
            [Math]::Max(0, [Math]::Min(100, 100 - [int]$fiveLimit.usedPercent))
        }
        else {
            -1
        }
        $weekRemaining = if ($weekLimit) {
            [Math]::Max(0, [Math]::Min(100, 100 - [int]$weekLimit.usedPercent))
        }
        else {
            -1
        }

        return [pscustomobject]@{
            Plan = [string]$rateLimits.planType
            FiveRemaining = $fiveRemaining
            FiveReset = if ($fiveLimit) { Convert-ResetTime $fiveLimit.resetsAt } else { $null }
            WeekRemaining = $weekRemaining
            WeekReset = if ($weekLimit) { Convert-ResetTime $weekLimit.resetsAt } else { $null }
            UpdatedAt = [DateTimeOffset]::Now
            CliPath = $exe
        }
    }
    finally {
        if ($process -and -not $process.HasExited) {
            try {
                $process.Kill()
            }
            catch {
                # The process may have exited between the check and Kill().
            }
        }
        if ($process) {
            $process.Dispose()
        }
    }
}

function Get-ClaudeQuota {
    if (Test-Path -LiteralPath $script:ClaudeProbePath) {
        try {
            $python = $null
            $settingsPath = Join-Path $env:USERPROFILE '.claude\settings.json'
            if (Test-Path -LiteralPath $settingsPath) {
                try {
                    $settings = Get-Content -Raw -LiteralPath $settingsPath | ConvertFrom-Json
                    if ($settings.statusLine -match '^(?<python>[A-Za-z]:\\[^"]*?python(?:\.exe)?)\s+') {
                        $candidate = $Matches.python
                        if (Test-Path -LiteralPath $candidate) {
                            $python = $candidate
                        }
                    }
                }
                catch {
                    # Fall back to PATH lookup below.
                }
            }
            if (-not $python) {
                $cmd = Get-Command python.exe,python -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($cmd) {
                    $python = $cmd.Source
                }
            }
            if (-not $python) {
                throw '找不到 Python，無法讀取 Claude Desktop 額度。'
            }

            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = $python
            $startInfo.Arguments = '"' + $script:ClaudeProbePath + '"'
            $startInfo.UseShellExecute = $false
            $startInfo.RedirectStandardOutput = $true
            $startInfo.RedirectStandardError = $true
            $startInfo.CreateNoWindow = $true

            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $startInfo
            [void]$process.Start()
            if (-not $process.WaitForExit(15000)) {
                try { $process.Kill() } catch {}
                throw 'Claude Desktop 額度讀取逾時。'
            }
            $raw = $process.StandardOutput.ReadToEnd()
            $process.Dispose()
            $probe = $raw | ConvertFrom-Json
            if ($probe.available) {
                return [pscustomobject]@{
                    Plan = 'claude'
                    FiveRemaining = [int]$probe.five_hour_remaining_percent
                    FiveReset = Convert-ClaudeResetTime $probe.five_hour_resets_at
                    WeekRemaining = [int]$probe.weekly_remaining_percent
                    WeekReset = Convert-ClaudeResetTime $probe.weekly_resets_at
                    UpdatedAt = Convert-ClaudeResetTime $probe.updated_at
                    Source = $script:ClaudeProbePath
                    Available = $true
                }
            }
        }
        catch {
            # Fall back to Claude Code statusLine status file below.
        }
    }

    if (-not (Test-Path -LiteralPath $script:ClaudeStatusPath)) {
        return [pscustomobject]@{
            Plan = 'claude'
            FiveRemaining = -1
            FiveReset = $null
            WeekRemaining = -1
            WeekReset = $null
            UpdatedAt = $null
            Source = $script:ClaudeStatusPath
            Available = $false
        }
    }

    try {
        $data = Get-Content -Raw -LiteralPath $script:ClaudeStatusPath | ConvertFrom-Json
        $rateLimits = $data.rate_limits
        if (-not $rateLimits) {
            throw 'Claude 狀態檔沒有 rate_limits。'
        }

        $fiveUsed = [double]$rateLimits.five_hour.used_percentage
        $weekUsed = [double]$rateLimits.seven_day.used_percentage
        $fiveRemaining = [Math]::Max(0, [Math]::Min(100, 100 - [int][Math]::Round($fiveUsed)))
        $weekRemaining = [Math]::Max(0, [Math]::Min(100, 100 - [int][Math]::Round($weekUsed)))
        $updatedAt = $null
        if ($data._received_at) {
            $updatedAt = [DateTimeOffset]::Parse([string]$data._received_at).ToLocalTime()
        }

        return [pscustomobject]@{
            Plan = 'claude'
            FiveRemaining = $fiveRemaining
            FiveReset = Convert-ClaudeResetTime $rateLimits.five_hour.resets_at
            WeekRemaining = $weekRemaining
            WeekReset = Convert-ClaudeResetTime $rateLimits.seven_day.resets_at
            UpdatedAt = $updatedAt
            Source = $script:ClaudeStatusPath
            Available = $true
        }
    }
    catch {
        return [pscustomobject]@{
            Plan = 'claude'
            FiveRemaining = -1
            FiveReset = $null
            WeekRemaining = -1
            WeekReset = $null
            UpdatedAt = $null
            Source = $script:ClaudeStatusPath
            Available = $false
        }
    }
}

function Get-QuotaColor {
    param([int]$Remaining)

    if ($Remaining -le 15) {
        return [System.Drawing.Color]::FromArgb(239, 68, 68)
    }
    if ($Remaining -le 30) {
        return [System.Drawing.Color]::FromArgb(245, 158, 11)
    }
    return [System.Drawing.Color]::FromArgb(34, 197, 94)
}

function New-QuotaIcon {
    param([int]$Remaining)

    $bitmap = New-Object System.Drawing.Bitmap 64, 64
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    try {
        $graphics.Clear([System.Drawing.Color]::Transparent)
        $background = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(30, 41, 59))
        $track = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(71, 85, 105)), 8
        $valuePen = New-Object System.Drawing.Pen (Get-QuotaColor $Remaining), 8
        $valuePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $valuePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $textBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
        $fontSize = if ($Remaining -eq 100) { 15 } else { 18 }
        $font = New-Object System.Drawing.Font 'Segoe UI', $fontSize, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $format = New-Object System.Drawing.StringFormat
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center

        try {
            $graphics.FillEllipse($background, 2, 2, 60, 60)
            $graphics.DrawArc($track, 8, 8, 48, 48, -90, 360)
            if ($Remaining -gt 0) {
                $graphics.DrawArc($valuePen, 8, 8, 48, 48, -90, [float](3.6 * $Remaining))
            }
            $graphics.DrawString([string]$Remaining, $font, $textBrush, ([System.Drawing.RectangleF]::new(7, 7, 50, 50)), $format)

            $handle = $bitmap.GetHicon()
            try {
                return ([System.Drawing.Icon]::FromHandle($handle)).Clone()
            }
            finally {
                [void][QuotaGaugeNative]::DestroyIcon($handle)
            }
        }
        finally {
            $background.Dispose()
            $track.Dispose()
            $valuePen.Dispose()
            $textBrush.Dispose()
            $font.Dispose()
            $format.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Format-Reset {
    param([object]$ResetTime)

    if ($null -eq $ResetTime) {
        return '未知'
    }

    $remaining = $ResetTime - [DateTimeOffset]::Now
    if ($remaining.TotalSeconds -lt 0) {
        $countdown = '即將重置'
    }
    elseif ($remaining.TotalDays -ge 1) {
        $countdown = '{0} 天 {1} 小時' -f [Math]::Floor($remaining.TotalDays), $remaining.Hours
    }
    elseif ($remaining.TotalHours -ge 1) {
        $countdown = '{0} 小時 {1} 分' -f [Math]::Floor($remaining.TotalHours), $remaining.Minutes
    }
    else {
        $countdown = '{0} 分' -f [Math]::Max(0, [Math]::Ceiling($remaining.TotalMinutes))
    }

    return '{0:MM/dd HH:mm} ({1})' -f $ResetTime, $countdown
}


function Get-ResetNotificationKey {
    param(
        [string]$ServiceName,
        [string]$WindowName,
        [object]$ResetTime
    )

    $resetKey = if ($null -ne $ResetTime) {
        try {
            ([DateTimeOffset]$ResetTime).ToString('o')
        }
        catch {
            [string]$ResetTime
        }
    }
    else {
        'unknown-' + [DateTimeOffset]::Now.ToString('yyyy-MM-dd')
    }

    return '{0}|{1}|{2}' -f $ServiceName, $WindowName, $resetKey
}

function Load-NotificationHistory {
    $script:NotifiedResetKeys = @{}

    if (-not (Test-Path -LiteralPath $script:NotificationHistoryPath)) {
        return
    }

    try {
        $data = Get-Content -Raw -LiteralPath $script:NotificationHistoryPath | ConvertFrom-Json
        foreach ($item in @($data.items)) {
            if ($item.key) {
                $script:NotifiedResetKeys[[string]$item.key] = [string]$item.notified_at
            }
        }
    }
    catch {
        $script:NotifiedResetKeys = @{}
    }
}

function Save-NotificationHistory {
    try {
        $items = foreach ($key in $script:NotifiedResetKeys.Keys) {
            [pscustomobject]@{
                key = $key
                notified_at = $script:NotifiedResetKeys[$key]
            }
        }

        [pscustomobject]@{
            items = @($items)
        } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $script:NotificationHistoryPath -Encoding UTF8
    }
    catch {
        # 通知歷史寫入失敗時，不影響主面板。
    }
}

function Test-AndRememberResetNotification {
    param(
        [string]$ServiceName,
        [string]$WindowName,
        [object]$ResetTime
    )

    $key = Get-ResetNotificationKey $ServiceName $WindowName $ResetTime
    if ($script:NotifiedResetKeys.ContainsKey($key)) {
        return $false
    }

    $script:NotifiedResetKeys[$key] = [DateTimeOffset]::Now.ToString('o')
    Save-NotificationHistory
    return $true
}

function Set-StartupEnabled {
    param([bool]$Enabled)

    if ($Enabled) {
        if (-not (Test-Path -LiteralPath $script:LauncherPath)) {
            throw '找不到背景啟動器。'
        }
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($script:StartupShortcut)
        $shortcut.TargetPath = (Get-Command 'wscript.exe').Source
        $shortcut.Arguments = '"' + $script:LauncherPath + '"'
        $shortcut.WorkingDirectory = $PSScriptRoot
        $shortcut.Description = $script:AppName
        $shortcut.Save()
    }
    else {
        Remove-Item -LiteralPath $script:StartupShortcut -Force -ErrorAction SilentlyContinue
    }

    $script:StartupMenuItem.Checked = Test-Path -LiteralPath $script:StartupShortcut
}

function Show-Balloon {
    param(
        [string]$Title,
        [string]$Message,
        [System.Windows.Forms.ToolTipIcon]$Icon = [System.Windows.Forms.ToolTipIcon]::Info
    )

    if (-not $script:ToastForm) {
        return
    }

    $script:ToastTitle.Text = $Title
    $script:ToastMessage.Text = $Message
    $script:ToastTitle.ForeColor = if ($Icon -eq [System.Windows.Forms.ToolTipIcon]::Warning) {
        [System.Drawing.Color]::FromArgb(251, 191, 36)
    }
    elseif ($Icon -eq [System.Windows.Forms.ToolTipIcon]::Error) {
        [System.Drawing.Color]::FromArgb(248, 113, 113)
    }
    else {
        [System.Drawing.Color]::FromArgb(125, 211, 252)
    }

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $script:ToastForm.Location = New-Object System.Drawing.Point (
        $workingArea.Right - $script:ToastForm.Width - 14
    ), (
        $workingArea.Bottom - $script:ToastForm.Height - 14
    )
    $script:ToastForm.Show()
    $script:ToastTimer.Stop()
    $script:ToastTimer.Start()
}


function Notify-QuotaReset {
    param(
        [string]$ServiceName,
        [string]$WindowName,
        [int]$Remaining,
        [object]$ResetTime
    )

    if (-not (Test-AndRememberResetNotification $ServiceName $WindowName $ResetTime)) {
        return
    }

    $toastMessage = '目前額度已回到 {0}%。下次重置：{1}' -f
        $Remaining,
        (Format-Reset $ResetTime)

    Show-Balloon "$ServiceName $WindowName 額度已重置" $toastMessage
}


function Position-MiniPanel {
    $codexCompact = $script:Quota -and $script:Quota.FiveRemaining -lt 0 -and $script:Quota.WeekRemaining -ge 0
    $panelWidth = if (Test-ClaudeEnabled) {
        if ($codexCompact) { 492 } else { 594 }
    }
    else {
        if ($codexCompact) { 194 } else { 302 }
    }
    $panelHeight = 66
    $taskbar = [QuotaGaugeNative]::FindWindow('Shell_TrayWnd', $null)
    $taskbarRect = New-Object QuotaGaugeNative+RECT

    if ($taskbar -ne [IntPtr]::Zero -and [QuotaGaugeNative]::GetWindowRect($taskbar, [ref]$taskbarRect)) {
        $taskbarWidth = $taskbarRect.Right - $taskbarRect.Left
        $taskbarHeight = $taskbarRect.Bottom - $taskbarRect.Top

        if ($taskbarWidth -ge $taskbarHeight) {
            $tray = [QuotaGaugeNative]::FindWindowEx($taskbar, [IntPtr]::Zero, 'TrayNotifyWnd', $null)
            $trayRect = New-Object QuotaGaugeNative+RECT
            $rightEdge = $taskbarRect.Right - 220
            if ($tray -ne [IntPtr]::Zero -and [QuotaGaugeNative]::GetWindowRect($tray, [ref]$trayRect)) {
                $rightEdge = $trayRect.Left - 8
            }

            $height = $panelHeight
            $script:MiniForm.Size = New-Object System.Drawing.Size $panelWidth, $height
            $script:MiniPanel.Size = $script:MiniForm.ClientSize
            $script:MiniForm.Location = New-Object System.Drawing.Point (
                $rightEdge - $script:MiniForm.Width
            ), (
                $taskbarRect.Bottom - $height
            )
            Set-MiniPanelTopMost
            return
        }
    }

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $script:MiniForm.Size = New-Object System.Drawing.Size $panelWidth, $panelHeight
    $script:MiniPanel.Size = $script:MiniForm.ClientSize
    $script:MiniForm.Location = New-Object System.Drawing.Point (
        $workingArea.Right - $script:MiniForm.Width - 8
    ), (
        $workingArea.Bottom - $script:MiniForm.Height - 8
    )
    Set-MiniPanelTopMost
}

function Set-MiniPanelTopMost {
    if (-not $script:MiniForm -or $script:MiniForm.IsDisposed -or -not $script:MiniForm.IsHandleCreated) {
        return
    }

    $hwndTopMost = [IntPtr](-1)
    $swpNoActivate = 0x0010
    $swpShowWindow = 0x0040
    [void][QuotaGaugeNative]::SetWindowPos(
        $script:MiniForm.Handle,
        $hwndTopMost,
        $script:MiniForm.Left,
        $script:MiniForm.Top,
        $script:MiniForm.Width,
        $script:MiniForm.Height,
        ($swpNoActivate -bor $swpShowWindow)
    )
}

function Set-BarValue {
    param(
        [System.Windows.Forms.Panel]$Track,
        [System.Windows.Forms.Label]$Fill,
        [int]$Value
    )

    $width = [Math]::Max(0, [Math]::Floor(($Track.ClientSize.Width - 4) * ($Value / 100.0)))
    $Fill.Width = $width
    $Fill.BackColor = Get-QuotaColor $Value
}

function Update-DetailsWindow {
    if ($null -eq $script:Quota) {
        return
    }

    $script:FiveValueLabel.Text = '剩餘 {0}%' -f $script:Quota.FiveRemaining
    $script:WeekValueLabel.Text = '剩餘 {0}%' -f $script:Quota.WeekRemaining
    $script:FiveResetLabel.Text = '重置：' + (Format-Reset $script:Quota.FiveReset)
    $script:WeekResetLabel.Text = '重置：' + (Format-Reset $script:Quota.WeekReset)
    $script:UpdatedLabel.Text = '更新 {0:HH:mm:ss}  |  方案：{1}' -f $script:Quota.UpdatedAt, $script:Quota.Plan
    Set-BarValue $script:FiveTrack $script:FiveFill $script:Quota.FiveRemaining
    Set-BarValue $script:WeekTrack $script:WeekFill $script:Quota.WeekRemaining
}

function Show-Details {
    Update-DetailsWindow

    $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $script:DetailsForm.Location = New-Object System.Drawing.Point (
        $workingArea.Right - $script:DetailsForm.Width - 18
    ), (
        $workingArea.Bottom - $script:DetailsForm.Height - 18
    )

    $script:DetailsForm.Show()
    $script:DetailsForm.Activate()
}

function Test-LowQuotaNotification {
    param(
        [string]$WindowName,
        [int]$Remaining,
        [ref]$LastNotified
    )

    if ($Remaining -lt 0) {
        return
    }

    $threshold = $null
    foreach ($candidate in @(30, 15, 5)) {
        if ($Remaining -le $candidate) {
            $threshold = $candidate
        }
    }

    if ($null -ne $threshold -and $LastNotified.Value -ne $threshold) {
        Show-Balloon "$WindowName 額度偏低" "目前只剩 $Remaining%。滑鼠移到監控條可查看重置時間。" ([System.Windows.Forms.ToolTipIcon]::Warning)
        $LastNotified.Value = $threshold
    }
    elseif ($Remaining -gt 30) {
        $LastNotified.Value = $null
    }
}

function Update-QuotaDisplay {
    $script:FiveHistory.Add([int]$script:Quota.FiveRemaining)
    $script:WeekHistory.Add([int]$script:Quota.WeekRemaining)
    while ($script:FiveHistory.Count -gt 24) {
        $script:FiveHistory.RemoveAt(0)
    }
    while ($script:WeekHistory.Count -gt 24) {
        $script:WeekHistory.RemoveAt(0)
    }

    $claudeFive = if ($script:ClaudeQuota) { $script:ClaudeQuota.FiveRemaining } else { -1 }
    $claudeWeek = if ($script:ClaudeQuota) { $script:ClaudeQuota.WeekRemaining } else { -1 }
    $claudeFiveText = if ($claudeFive -ge 0) { "剩餘 $claudeFive%" } else { "尚無資料" }
    $claudeWeekText = if ($claudeWeek -ge 0) { "剩餘 $claudeWeek%" } else { "尚無資料" }
    $claudeFiveReset = if ($script:ClaudeQuota) { Format-Reset $script:ClaudeQuota.FiveReset } else { '未知' }
    $claudeWeekReset = if ($script:ClaudeQuota) { Format-Reset $script:ClaudeQuota.WeekReset } else { '未知' }
    $showClaude = Test-ClaudeEnabled
    $showCodexFive = $script:Quota.FiveRemaining -ge 0
    $script:MiniPanel.UpdateData($claudeFive, $claudeWeek, $script:Quota.FiveRemaining, $script:Quota.WeekRemaining, $showClaude)
    $codexTooltip = if ($showCodexFive) {
        "Codex 5 小時：剩餘 {0}%｜重置 {1}`nCodex 每週：剩餘 {2}%｜重置 {3}" -f
            $script:Quota.FiveRemaining,
            (Format-Reset $script:Quota.FiveReset),
            $script:Quota.WeekRemaining,
            (Format-Reset $script:Quota.WeekReset)
    }
    else {
        "Codex 每週：剩餘 {0}%｜重置 {1}" -f
            $script:Quota.WeekRemaining,
            (Format-Reset $script:Quota.WeekReset)
    }
    $tooltipText = if ($showClaude) {
        "Claude 5 小時：{0}｜重置 {1}`nClaude 每週：{2}｜重置 {3}`n{4}" -f
            $claudeFiveText,
            $claudeFiveReset,
            $claudeWeekText,
            $claudeWeekReset,
            $codexTooltip
    }
    else {
        $codexTooltip
    }
    $script:PanelToolTip.SetToolTip($script:MiniPanel, $tooltipText)
    Position-MiniPanel
    $script:FiveMenuItem.Visible = $showCodexFive
    $script:FiveResetMenuItem.Visible = $showCodexFive
    if ($showCodexFive) {
        $script:FiveMenuItem.Text = '5 小時：剩餘 {0}%' -f $script:Quota.FiveRemaining
        $script:FiveResetMenuItem.Text = '5 小時重置：' + (Format-Reset $script:Quota.FiveReset)
    }
    $script:WeekMenuItem.Text = '每週：剩餘 {0}%' -f $script:Quota.WeekRemaining
    $script:WeekResetMenuItem.Text = '每週重置：' + (Format-Reset $script:Quota.WeekReset)
    $script:UpdatedMenuItem.Text = '更新時間：{0:HH:mm:ss}' -f $script:Quota.UpdatedAt
    Update-DetailsWindow

    [pscustomobject]@{
        codex_plan = $script:Quota.Plan
        codex_five_hour_remaining_percent = $script:Quota.FiveRemaining
        codex_five_hour_resets_at = if ($script:Quota.FiveReset) { $script:Quota.FiveReset.ToString('o') } else { $null }
        codex_weekly_remaining_percent = $script:Quota.WeekRemaining
        codex_weekly_resets_at = if ($script:Quota.WeekReset) { $script:Quota.WeekReset.ToString('o') } else { $null }
        claude_enabled = $showClaude
        claude_available = if ($showClaude -and $script:ClaudeQuota) { $script:ClaudeQuota.Available } else { $false }
        claude_five_hour_remaining_percent = $claudeFive
        claude_five_hour_resets_at = if ($script:ClaudeQuota -and $script:ClaudeQuota.FiveReset) { $script:ClaudeQuota.FiveReset.ToString('o') } else { $null }
        claude_weekly_remaining_percent = $claudeWeek
        claude_weekly_resets_at = if ($script:ClaudeQuota -and $script:ClaudeQuota.WeekReset) { $script:ClaudeQuota.WeekReset.ToString('o') } else { $null }
        updated_at = $script:Quota.UpdatedAt.ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $script:StatePath -Encoding UTF8
    Remove-Item -LiteralPath $script:ErrorPath -Force -ErrorAction SilentlyContinue
}

function Refresh-Quota {
    if ($script:IsRefreshing) {
        return
    }

    $script:IsRefreshing = $true
    $script:RefreshMenuItem.Enabled = $false
    $script:UpdatedMenuItem.Text = '更新中...'

    try {
        $newQuota = Get-CodexQuota
        $claudeEnabled = Test-ClaudeEnabled
        $newClaudeQuota = if ($claudeEnabled) { Get-ClaudeQuota } else { $null }

        $script:Quota = $newQuota
        $script:ClaudeQuota = $newClaudeQuota

        if ($null -ne $script:LastFiveRemaining -and $newQuota.FiveRemaining -ge 0 -and $script:LastFiveRemaining -ge 0 -and $newQuota.FiveRemaining -ge ($script:LastFiveRemaining + 40)) {
            Notify-QuotaReset 'Codex' '5 小時' $newQuota.FiveRemaining $newQuota.FiveReset
        }
        if ($null -ne $script:LastWeekRemaining -and $newQuota.WeekRemaining -ge 0 -and $script:LastWeekRemaining -ge 0 -and $newQuota.WeekRemaining -ge ($script:LastWeekRemaining + 40)) {
            Notify-QuotaReset 'Codex' '每週' $newQuota.WeekRemaining $newQuota.WeekReset
        }
        if ($claudeEnabled -and $newClaudeQuota -and $newClaudeQuota.Available) {
            if ($null -ne $script:LastClaudeFiveRemaining -and $newClaudeQuota.FiveRemaining -ge 0 -and $script:LastClaudeFiveRemaining -ge 0 -and $newClaudeQuota.FiveRemaining -ge ($script:LastClaudeFiveRemaining + 40)) {
                Notify-QuotaReset 'Claude' '5 小時' $newClaudeQuota.FiveRemaining $newClaudeQuota.FiveReset
            }
            if ($null -ne $script:LastClaudeWeekRemaining -and $newClaudeQuota.WeekRemaining -ge 0 -and $script:LastClaudeWeekRemaining -ge 0 -and $newClaudeQuota.WeekRemaining -ge ($script:LastClaudeWeekRemaining + 40)) {
                Notify-QuotaReset 'Claude' '每週' $newClaudeQuota.WeekRemaining $newClaudeQuota.WeekReset
            }
        }

        Update-QuotaDisplay

        Test-LowQuotaNotification '5 小時' $newQuota.FiveRemaining ([ref]$script:LastNotifiedFive)
        Test-LowQuotaNotification '每週' $newQuota.WeekRemaining ([ref]$script:LastNotifiedWeek)

        $script:LastFiveRemaining = $newQuota.FiveRemaining
        $script:LastWeekRemaining = $newQuota.WeekRemaining
        if ($claudeEnabled -and $newClaudeQuota -and $newClaudeQuota.Available) {
            $script:LastClaudeFiveRemaining = $newClaudeQuota.FiveRemaining
            $script:LastClaudeWeekRemaining = $newClaudeQuota.WeekRemaining
        }
        $script:IsFirstRefresh = $false
    }
    catch {
        $script:UpdatedMenuItem.Text = '更新失敗'
        $script:StatusMenuItem.Text = $_.Exception.Message
        $script:StatusMenuItem.Visible = $true
        ('{0:o} {1}' -f [DateTimeOffset]::Now, $_.Exception.Message) |
            Set-Content -LiteralPath $script:ErrorPath -Encoding UTF8
        if ($script:IsFirstRefresh) {
            Show-Balloon 'Codex 額度更新失敗' $_.Exception.Message ([System.Windows.Forms.ToolTipIcon]::Error)
        }
    }
    finally {
        if ($script:Quota) {
            $script:StatusMenuItem.Visible = $false
        }
        $script:RefreshMenuItem.Enabled = $true
        $script:IsRefreshing = $false
    }
}

$script:DetailsForm = New-Object System.Windows.Forms.Form
$script:DetailsForm.Text = $script:AppName
$script:DetailsForm.ClientSize = New-Object System.Drawing.Size 410, 310
$script:DetailsForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$script:DetailsForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$script:DetailsForm.MaximizeBox = $false
$script:DetailsForm.MinimizeBox = $false
$script:DetailsForm.ShowInTaskbar = $false
$script:DetailsForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$script:DetailsForm.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$script:DetailsForm.ForeColor = [System.Drawing.Color]::White
$script:DetailsForm.Font = New-Object System.Drawing.Font 'Microsoft JhengHei UI', 11

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Codex 額度監控'
$titleLabel.Location = New-Object System.Drawing.Point 22, 18
$titleLabel.AutoSize = $true
$titleLabel.Font = New-Object System.Drawing.Font 'Segoe UI Semibold', 16
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(226, 232, 240)
$script:DetailsForm.Controls.Add($titleLabel)

$fiveTitle = New-Object System.Windows.Forms.Label
$fiveTitle.Text = '5 小時額度'
$fiveTitle.Location = New-Object System.Drawing.Point 24, 65
$fiveTitle.AutoSize = $true
$fiveTitle.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$script:DetailsForm.Controls.Add($fiveTitle)

$script:FiveValueLabel = New-Object System.Windows.Forms.Label
$script:FiveValueLabel.Text = '剩餘 --%'
$script:FiveValueLabel.Location = New-Object System.Drawing.Point 245, 61
$script:FiveValueLabel.Size = New-Object System.Drawing.Size 140, 24
$script:FiveValueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$script:FiveValueLabel.Font = New-Object System.Drawing.Font 'Segoe UI Semibold', 11
$script:DetailsForm.Controls.Add($script:FiveValueLabel)

$script:FiveTrack = New-Object System.Windows.Forms.Panel
$script:FiveTrack.Location = New-Object System.Drawing.Point 24, 91
$script:FiveTrack.Size = New-Object System.Drawing.Size 360, 18
$script:FiveTrack.BackColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$script:DetailsForm.Controls.Add($script:FiveTrack)

$script:FiveFill = New-Object System.Windows.Forms.Label
$script:FiveFill.Location = New-Object System.Drawing.Point 2, 2
$script:FiveFill.Size = New-Object System.Drawing.Size 0, 14
$script:FiveTrack.Controls.Add($script:FiveFill)

$script:FiveResetLabel = New-Object System.Windows.Forms.Label
$script:FiveResetLabel.Text = '重置：--'
$script:FiveResetLabel.Location = New-Object System.Drawing.Point 24, 114
$script:FiveResetLabel.Size = New-Object System.Drawing.Size 360, 22
$script:FiveResetLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$script:DetailsForm.Controls.Add($script:FiveResetLabel)

$weekTitle = New-Object System.Windows.Forms.Label
$weekTitle.Text = '每週額度'
$weekTitle.Location = New-Object System.Drawing.Point 24, 151
$weekTitle.AutoSize = $true
$weekTitle.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$script:DetailsForm.Controls.Add($weekTitle)

$script:WeekValueLabel = New-Object System.Windows.Forms.Label
$script:WeekValueLabel.Text = '剩餘 --%'
$script:WeekValueLabel.Location = New-Object System.Drawing.Point 245, 147
$script:WeekValueLabel.Size = New-Object System.Drawing.Size 140, 24
$script:WeekValueLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleRight
$script:WeekValueLabel.Font = New-Object System.Drawing.Font 'Segoe UI Semibold', 11
$script:DetailsForm.Controls.Add($script:WeekValueLabel)

$script:WeekTrack = New-Object System.Windows.Forms.Panel
$script:WeekTrack.Location = New-Object System.Drawing.Point 24, 177
$script:WeekTrack.Size = New-Object System.Drawing.Size 360, 18
$script:WeekTrack.BackColor = [System.Drawing.Color]::FromArgb(51, 65, 85)
$script:DetailsForm.Controls.Add($script:WeekTrack)

$script:WeekFill = New-Object System.Windows.Forms.Label
$script:WeekFill.Location = New-Object System.Drawing.Point 2, 2
$script:WeekFill.Size = New-Object System.Drawing.Size 0, 14
$script:WeekTrack.Controls.Add($script:WeekFill)

$script:WeekResetLabel = New-Object System.Windows.Forms.Label
$script:WeekResetLabel.Text = '重置：--'
$script:WeekResetLabel.Location = New-Object System.Drawing.Point 24, 200
$script:WeekResetLabel.Size = New-Object System.Drawing.Size 360, 22
$script:WeekResetLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$script:DetailsForm.Controls.Add($script:WeekResetLabel)

$script:UpdatedLabel = New-Object System.Windows.Forms.Label
$script:UpdatedLabel.Text = '等待第一次更新...'
$script:UpdatedLabel.Location = New-Object System.Drawing.Point 24, 246
$script:UpdatedLabel.Size = New-Object System.Drawing.Size 245, 24
$script:UpdatedLabel.ForeColor = [System.Drawing.Color]::FromArgb(148, 163, 184)
$script:DetailsForm.Controls.Add($script:UpdatedLabel)

$refreshButton = New-Object System.Windows.Forms.Button
$refreshButton.Text = '立即更新'
$refreshButton.Location = New-Object System.Drawing.Point 294, 240
$refreshButton.Size = New-Object System.Drawing.Size 90, 32
$refreshButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$refreshButton.BackColor = [System.Drawing.Color]::FromArgb(30, 41, 59)
$refreshButton.ForeColor = [System.Drawing.Color]::White
$refreshButton.Add_Click({ Refresh-Quota })
$script:DetailsForm.Controls.Add($refreshButton)

$script:DetailsForm.Add_FormClosing({
    param($sender, $eventArgs)
    if ($eventArgs.CloseReason -eq [System.Windows.Forms.CloseReason]::UserClosing) {
        $eventArgs.Cancel = $true
        $sender.Hide()
    }
})

$script:MiniForm = New-Object QuotaOverlayForm
$script:MiniForm.Text = $script:AppName
$script:MiniForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$script:MiniForm.ShowInTaskbar = $false
$script:MiniForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$script:MiniForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$script:MiniForm.TopMost = $true
$script:MiniForm.BackColor = [System.Drawing.Color]::Magenta
$script:MiniForm.TransparencyKey = [System.Drawing.Color]::Magenta
$initialPanelWidth = 302
$script:MiniForm.Size = New-Object System.Drawing.Size $initialPanelWidth, 66

$script:MiniPanel = New-Object QuotaMiniPanel
$script:MiniPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
$script:MiniForm.Controls.Add($script:MiniPanel)
$script:MiniPanel.Add_DoubleClick({ Show-Details })

$script:PanelToolTip = New-Object System.Windows.Forms.ToolTip
$script:PanelToolTip.AutoPopDelay = 12000
$script:PanelToolTip.InitialDelay = 300
$script:PanelToolTip.ReshowDelay = 100

$script:ToastForm = New-Object QuotaOverlayForm
$script:ToastForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$script:ToastForm.ShowInTaskbar = $false
$script:ToastForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$script:ToastForm.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
$script:ToastForm.TopMost = $true
$script:ToastForm.BackColor = [System.Drawing.Color]::FromArgb(15, 23, 42)
$script:ToastForm.Size = New-Object System.Drawing.Size 480, 118

$script:ToastTitle = New-Object System.Windows.Forms.Label
$script:ToastTitle.Location = New-Object System.Drawing.Point 20, 14
$script:ToastTitle.Size = New-Object System.Drawing.Size 440, 32
$script:ToastTitle.Font = New-Object System.Drawing.Font 'Microsoft JhengHei UI', 22, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$script:ToastForm.Controls.Add($script:ToastTitle)

$script:ToastMessage = New-Object System.Windows.Forms.Label
$script:ToastMessage.Location = New-Object System.Drawing.Point 20, 51
$script:ToastMessage.Size = New-Object System.Drawing.Size 440, 50
$script:ToastMessage.ForeColor = [System.Drawing.Color]::FromArgb(203, 213, 225)
$script:ToastMessage.Font = New-Object System.Drawing.Font 'Microsoft JhengHei UI', 18, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$script:ToastForm.Controls.Add($script:ToastMessage)
$script:ToastForm.Add_Click({ $script:ToastForm.Hide() })
$script:ToastTitle.Add_Click({ $script:ToastForm.Hide() })
$script:ToastMessage.Add_Click({ $script:ToastForm.Hide() })

$script:ToastTimer = New-Object System.Windows.Forms.Timer
$script:ToastTimer.Interval = 7000
$script:ToastTimer.Add_Tick({
    $script:ToastTimer.Stop()
    $script:ToastForm.Hide()
})

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$contextMenu.ShowImageMargin = $false

$headerItem = New-Object System.Windows.Forms.ToolStripMenuItem
$headerItem.Text = 'Claude / Codex 額度監控'
$headerItem.Enabled = $false
$headerItem.Font = New-Object System.Drawing.Font $headerItem.Font, ([System.Drawing.FontStyle]::Bold)
[void]$contextMenu.Items.Add($headerItem)
[void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$script:FiveMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:FiveMenuItem.Text = '5 小時：讀取中...'
$script:FiveMenuItem.Enabled = $false
[void]$contextMenu.Items.Add($script:FiveMenuItem)

$script:FiveResetMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:FiveResetMenuItem.Text = '5 小時重置：--'
$script:FiveResetMenuItem.Enabled = $false
[void]$contextMenu.Items.Add($script:FiveResetMenuItem)

$script:WeekMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:WeekMenuItem.Text = '每週：讀取中...'
$script:WeekMenuItem.Enabled = $false
[void]$contextMenu.Items.Add($script:WeekMenuItem)

$script:WeekResetMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:WeekResetMenuItem.Text = '每週重置：--'
$script:WeekResetMenuItem.Enabled = $false
[void]$contextMenu.Items.Add($script:WeekResetMenuItem)

$script:UpdatedMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:UpdatedMenuItem.Text = '更新時間：--'
$script:UpdatedMenuItem.Enabled = $false
[void]$contextMenu.Items.Add($script:UpdatedMenuItem)

$script:StatusMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:StatusMenuItem.Text = ''
$script:StatusMenuItem.Enabled = $false
$script:StatusMenuItem.Visible = $false
[void]$contextMenu.Items.Add($script:StatusMenuItem)
[void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$detailsItem = New-Object System.Windows.Forms.ToolStripMenuItem
$detailsItem.Text = '開啟詳細資訊'
$detailsItem.Add_Click({ Show-Details })
[void]$contextMenu.Items.Add($detailsItem)

$script:RefreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:RefreshMenuItem.Text = '立即更新'
$script:RefreshMenuItem.Add_Click({ Refresh-Quota })
[void]$contextMenu.Items.Add($script:RefreshMenuItem)

$script:ClaudeMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:ClaudeMenuItem.Text = '顯示 Claude 額度'
$script:ClaudeMenuItem.CheckOnClick = $false
$script:ClaudeMenuItem.Checked = Test-ClaudeEnabled
$script:ClaudeMenuItem.Add_Click({
    try {
        Set-ClaudeEnabled (-not (Test-ClaudeEnabled))
        $script:ClaudeMenuItem.Checked = Test-ClaudeEnabled
        $script:ClaudeQuota = $null
        $script:LastClaudeFiveRemaining = $null
        $script:LastClaudeWeekRemaining = $null
        Position-MiniPanel
        Refresh-Quota
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})
[void]$contextMenu.Items.Add($script:ClaudeMenuItem)

$script:StartupMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
$script:StartupMenuItem.Text = '登入 Windows 時自動啟動'
$script:StartupMenuItem.CheckOnClick = $false
$script:StartupMenuItem.Checked = Test-Path -LiteralPath $script:StartupShortcut
$script:StartupMenuItem.Add_Click({
    try {
        Set-StartupEnabled (-not $script:StartupMenuItem.Checked)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            $script:AppName,
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
})
[void]$contextMenu.Items.Add($script:StartupMenuItem)
[void]$contextMenu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))

$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
$exitItem.Text = '結束程式'
$exitItem.Add_Click({
    $script:RefreshTimer.Stop()
    [System.Windows.Forms.Application]::Exit()
})
[void]$contextMenu.Items.Add($exitItem)

$script:MiniForm.ContextMenuStrip = $contextMenu
$script:MiniPanel.ContextMenuStrip = $contextMenu

$script:RefreshTimer = New-Object System.Windows.Forms.Timer
$script:RefreshTimer.Interval = $script:RefreshSeconds * 1000
$script:RefreshTimer.Add_Tick({ Refresh-Quota })
$script:RefreshTimer.Start()

$script:ZOrderTimer = New-Object System.Windows.Forms.Timer
$script:ZOrderTimer.Interval = 1000
$script:ZOrderTimer.Add_Tick({
    Position-MiniPanel
    Set-MiniPanelTopMost
})
$script:ZOrderTimer.Start()

try {
    Load-NotificationHistory
    $script:MiniForm.Show()
    Position-MiniPanel
    Set-MiniPanelTopMost
    Refresh-Quota
    [System.Windows.Forms.Application]::Run($script:MiniForm)
}
finally {
    $script:ZOrderTimer.Stop()
    $script:ZOrderTimer.Dispose()
    $script:RefreshTimer.Stop()
    $script:RefreshTimer.Dispose()
    $script:ToastTimer.Stop()
    $script:ToastTimer.Dispose()
    $script:PanelToolTip.Dispose()
    $script:ToastForm.Dispose()
    $script:MiniForm.Dispose()
    $script:DetailsForm.Dispose()
    if ($script:Mutex) {
        try {
            $script:Mutex.ReleaseMutex()
        }
        catch {
            # The mutex may already have been released during shutdown.
        }
        $script:Mutex.Dispose()
    }
}









