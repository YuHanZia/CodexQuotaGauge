# CodexQuotaGauge

Languages: **English** | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

A Windows 11 taskbar quota widget that shows your Codex usage quota in large, readable numbers. Claude quota support is kept in the codebase, but it is disabled by default and can be enabled later from the widget menu.

## Preview

When Codex currently exposes only weekly quota data, the widget automatically switches to a compact weekly-only layout:

![Codex compact layout preview](assets/codex-compact.svg)

When Claude and Codex are both enabled and both 5-hour and weekly quota data are available:

![Claude and Codex full dashboard preview](assets/dual-dashboard.svg)

## Features

- Shows Codex weekly remaining quota percentage.
- Automatically hides the Codex 5-hour column when OpenAI does not provide 5-hour quota data.
- Keeps Claude quota support available, disabled by default.
- Right-click menu for refresh, details, Claude toggle, and exit.
- Starts automatically when Windows starts.

## Install

1. Download or clone this repository.
2. Double-click `Install.bat`.
3. The widget should appear near the Windows taskbar notification area.

Install location:

```text
%LOCALAPPDATA%\CodexQuotaGauge\app
```

## Uninstall

Double-click `Uninstall.bat`.

The uninstaller stops the background process, removes the startup shortcut, and deletes local runtime state:

```text
%LOCALAPPDATA%\CodexQuotaGauge
```

## Requirements

- Windows 11
- Codex Desktop installed and signed in
- Claude Desktop installed and signed in, only if you want to enable Claude quota monitoring

## Usage

- Right-click the panel to open the menu.
- Choose `立即更新` to refresh quota data.
- Choose `開啟詳細資訊` to view reset times.
- Double-click the panel to open the details window.

## Privacy

CodexQuotaGauge reads quota information from locally signed-in Codex and Claude desktop sessions. It does not write tokens to this repository, status files, notifications, or the widget UI.
