# CodexQuotaGauge

Windows 11 右下角工作列額度小工具，用大字顯示 Codex 剩餘額度百分比。Claude 額度讀取程式仍保留，但預設關閉，可之後再打開。

## 示意圖

Codex 目前只有每週資料時，會自動縮成窄版：

![Codex 窄版示意圖](assets/codex-compact.svg)

Claude 與 Codex 都啟用、且都有 5 小時與每週資料時：

![Claude 與 Codex 完整示意圖](assets/dual-dashboard.svg)

## 功能

- 顯示 Codex 每週剩餘額度百分比。
- 如果 OpenAI 暫時沒有提供 Codex 5 小時額度資料，會自動隱藏 5 小時欄位並縮窄面板。
- Claude 額度功能保留，預設關閉。
- 右鍵選單可立即更新、開啟詳細資訊、開關 Claude 額度、關閉小工具。
- 開機自動啟動。

## 安裝

1. 下載或 clone 這個 repo。
2. 雙擊 `Install.bat`。
3. 面板會出現在 Windows 右下角工作列附近。

安裝位置：

```text
%LOCALAPPDATA%\CodexQuotaGauge\app
```

## 移除

雙擊 `Uninstall.bat`。

移除器會停止常駐程式、刪掉開機自動啟動捷徑，並移除本機狀態資料：

```text
%LOCALAPPDATA%\CodexQuotaGauge
```

## 使用前提

- Windows 11
- 已安裝並登入 Codex Desktop
- 若要啟用 Claude 額度：需已安裝並登入 Claude Desktop

## 使用方式

- 右鍵面板：開啟選單
- 選「立即更新」：重新讀取額度
- 選「開啟詳細資訊」：查看重置時間
- 雙擊面板：開啟詳細資訊

## 隱私

工具只讀取本機已登入的 Codex／Claude 額度狀態，不會把 token 寫入 repo、狀態檔、通知或畫面。
