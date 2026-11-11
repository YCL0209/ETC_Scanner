# TestFlight 自動上傳 — 修復與自動化紀錄

> **紀錄日期**：2026-07-24
> **範圍**：修復壞掉的 fastlane 自動版本迭代上傳，並建立 launchd 定時自動上傳

---

## 一、背景（原本壞在哪）

專案的「自動版本迭代上傳測試版」功能（fastlane → TestFlight）本來是壞的，跑不起來。檢查後發現**兩層問題**：

1. **Fastfile 金鑰路徑打錯**（程式碼層）— 上次能跑之後，Fastfile 被改壞。
2. **Apple 開發者合約過期**（帳號層）— 在上次成功上傳後才發生，會擋掉所有 TestFlight API。

另外也澄清一個誤會：**在今天之前，並沒有「開機就自動上傳」的排程**。先前唯一的自動化是 git `post-commit` hook 會自動 `git push` 到 GitHub，那跟 TestFlight 上傳無關。fastlane 本身不會排程，一定要靠 launchd/cron 去定時呼叫。

---

## 二、今天做了什麼

### 1. 修 Fastfile 金鑰路徑（致命）
- `key_filepath` 由不存在的 `./fastlane/33P2U2Z62C.p8` → 改為實際檔案 `./fastlane/AuthKey_33P2U2Z62C.p8`
- `beta`、`uploadonly` 兩個 lane 都修正（改用共用的 `make_api_key`）

### 2. build number 自動對齊 TestFlight
- `beta` lane 加入 `latest_testflight_build_number`，以 TestFlight 現有最新 build **+1** 為新 build，避免本地 build 號落後被以「重複/更低」退件。
- 新增唯讀診斷 lane `latestbuild`：驗證金鑰並印出目前最新 build，**不會上傳**。

### 3. 啟用 apple-generic 版本系統
- `ETC_Scanner.xcodeproj/project.pbxproj` 的 App target（Debug/Release）加入 `VERSIONING_SYSTEM = "apple-generic";`，讓 `increment_build_number`（agvtool）能正常運作。

### 4. 新增 `.gitignore`（安全）
- 忽略 `*.p8` 私鑰、`*.ipa`、`*.dSYM.zip`、Xcode/Ruby 產物、以及自動化的執行期檔案。
- 避免日後 `git add .` 誤把 App Store Connect 私鑰提交上去。

### 5. Apple 合約重簽（帳號持有人本人操作）
- 錯誤訊息：`A required agreement is missing or has expired`。
- 由 Account Holder（andy02090516@icloud.com）到 https://appstoreconnect.apple.com 簽署後解鎖。

### 6. 實際上傳成功
- `fastlane ios beta` 完整跑通：讀到 build 8 → 設 build 9 → 建置 → 上傳 → **TestFlight 已處理完成 build 1.2 (9)**（App ID: 6745792080）。

### 7. 建立 launchd 定時自動上傳（本次新做的功能）
- 每 **80 天**自動跑一次 `fastlane ios beta`（效期 90 天，提前 10 天緩衝）。

---

## 三、自動上傳系統怎麼運作

```
launchd (com.etcscanner.autobeta)
   │  登入/開機時 + 每天 13:30 觸發
   ▼
fastlane/auto_beta.sh
   │  讀 fastlane/.last_upload_epoch
   │  距上次上傳 < 80 天 → 略過（不動作）
   │  距上次上傳 ≥ 80 天 → 執行 ↓
   ▼
bundle exec fastlane ios beta   →  上傳 TestFlight
   │  成功 → 更新 .last_upload_epoch + macOS 成功通知
   └  失敗 → 判斷原因 → macOS 常駐對話框（按「知道了」才消失，不會默默壞掉）
```

- **沒開機的日子**：那天不會跑，但**下次開機**會補檢查 → 符合「當天有開機就會傳」。
- **build 號**：每次自動抓 TestFlight 最新 +1，不用手動管。

---

## 四、相關檔案

| 檔案 | 用途 |
|---|---|
| `fastlane/Fastfile` | 三個 lane：`beta`（自動遞增上傳）/ `uploadonly`（用現有 ipa 上傳）/ `latestbuild`（唯讀診斷） |
| `fastlane/auto_beta.sh` | 自動上傳判斷腳本（80 天判斷＋失敗原因分類＋通知＋記錄） |
| `fastlane/notify.sh` | 通知：macOS 通知／失敗時常駐對話框 |
| `~/Library/LaunchAgents/com.etcscanner.autobeta.plist` | launchd 排程設定 |
| `fastlane/.last_upload_epoch` | 記錄上次上傳時間（gitignore） |
| `fastlane/auto_beta.log` | 自動上傳執行紀錄（gitignore） |
| `fastlane/AuthKey_33P2U2Z62C.p8` | App Store Connect API 私鑰（gitignore，勿外流） |

---

## 五、重要日期

| 項目 | 日期 |
|---|---|
| 本次上傳 | 2026-07-24（build 1.2 / 9）|
| build 效期到期 | 2026-10-22（+90 天）|
| 下次自動上傳 | 2026-10-12 之後（+80 天）|

---

## 六、常用操作

```bash
# 唯讀驗證金鑰＋看 TestFlight 目前最新 build（不上傳）
bundle exec fastlane ios latestbuild

# 手動上傳一版（自動遞增）
bundle exec fastlane ios beta

# 想馬上強制自動上傳：刪狀態檔再跑腳本
rm fastlane/.last_upload_epoch && bash fastlane/auto_beta.sh

# 暫停 / 恢復自動上傳
launchctl unload ~/Library/LaunchAgents/com.etcscanner.autobeta.plist
launchctl load -w ~/Library/LaunchAgents/com.etcscanner.autobeta.plist

# 改上傳週期：編輯 auto_beta.sh 的 INTERVAL_DAYS
```

---

## 七、自動上傳失敗時，常見原因

1. **Apple 合約再次過期** → Account Holder 到 App Store Connect 重簽（同今天狀況）。
2. **發布憑證 / 描述檔到期**（約每年一次）→ 在 Xcode 更新簽章。
3. **Mac 未登入 / 鑰匙圈鎖住** → 程式碼簽章需要解鎖的登入鑰匙圈。
4. 診斷起點：先看 `fastlane/auto_beta.log`，再跑 `bundle exec fastlane ios latestbuild` 驗證金鑰與帳號狀態。

---

## 失敗通知與常見原因

上傳失敗時 Mac 會跳出**常駐對話框**（最多停留 12 小時），內容直接寫出原因與處理方式；排程每天 13:30 自動重試，修好前每天都會提醒。

| 對話框標籤 | 原因 | 處理 |
|---|---|---|
| 【合約/會員過期】 | Apple 開發者合約/會員到期或有新合約未簽 | developer.apple.com → Account、App Store Connect → 商務 簽署/續約 |
| 【防火牆攔截】 | 辦公室 FortiGate SSL 檢查攔截 `contentdelivery.itunes.apple.com`（altool 報 `Defaults.properties` 錯誤） | 請網管將 `*.apple.com` 排除 SSL 檢查；或接手機熱點後執行 `bash fastlane/auto_beta.sh` |
| 【網路不通】 | 斷網/DNS | 恢復網路後手動補跑或等隔天 |
| 【API 金鑰失效】 | App Store Connect API key 被撤銷 | 重新產生金鑰並替換 `fastlane/AuthKey_*.p8` |
| 【build 號重複】 | TestFlight 已有相同 build 號 | 通常重跑即可 |
| 【簽署問題】 | 憑證/描述檔到期 | Xcode → Settings → Accounts 更新 |
| 【編譯失敗】 | 程式碼/Xcode 版本問題 | 用 Xcode Archive 看錯誤 |

> TestFlight build 90 天過期；80 天週期留有 10 天緩衝處理失敗。


