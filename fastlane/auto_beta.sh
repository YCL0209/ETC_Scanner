#!/bin/bash
# ETC_Scanner 自動 TestFlight 上傳
# 由 launchd (~/Library/LaunchAgents/com.etcscanner.autobeta.plist) 呼叫。
# 邏輯：距離上次成功上傳 >= INTERVAL_DAYS 天才會真的跑 fastlane ios beta。
# 排程只負責「常常來檢查」，是否上傳由這支腳本判斷 → 重開機也不會漏掉。

set -uo pipefail

PROJECT_DIR="/Users/liaoyacheng/Projects/ETC_Scanner"
STATE_FILE="$PROJECT_DIR/fastlane/.last_upload_epoch"
LOG_FILE="$PROJECT_DIR/fastlane/auto_beta.log"
INTERVAL_DAYS=80

# launchd 的 PATH 很精簡，補上 homebrew / ruby 的路徑
export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_HIDE_CHANGELOG=1
# Homebrew 版 fastlane 自帶 gem，不受 homebrew ruby 版本升級影響（bundler 會壞）
FASTLANE_BIN="/opt/homebrew/bin/fastlane"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }
# notify <success|failure> <標題> <內容>：macOS 通知（失敗時另跳常駐對話框）+ Email，見 notify.sh
notify() { /bin/bash "$PROJECT_DIR/fastlane/notify.sh" "$@" >> "$LOG_FILE" 2>&1 || true; }

cd "$PROJECT_DIR" || { log "❌ 找不到專案目錄 $PROJECT_DIR"; exit 1; }

now=$(date +%s)
last=0
[ -f "$STATE_FILE" ] && last=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

if [ "$last" -gt 0 ]; then
  elapsed_days=$(( (now - last) / 86400 ))
  if [ "$elapsed_days" -lt "$INTERVAL_DAYS" ]; then
    log "距上次上傳 ${elapsed_days} 天 (< ${INTERVAL_DAYS})，本次略過。"
    exit 0
  fi
  log "距上次上傳 ${elapsed_days} 天 (>= ${INTERVAL_DAYS})，開始自動上傳..."
else
  log "尚無上次上傳紀錄，開始首次自動上傳..."
fi

RUN_LOG="$PROJECT_DIR/fastlane/.last_run.log"
if "$FASTLANE_BIN" ios beta 2>&1 | tee "$RUN_LOG" >> "$LOG_FILE"; [ "${PIPESTATUS[0]}" -eq 0 ]; then
  echo "$now" > "$STATE_FILE"
  next_date=$(date -v+${INTERVAL_DAYS}d '+%Y-%m-%d' 2>/dev/null)
  log "✅ 上傳成功。下次預計 ${next_date} 之後。"
  notify success "TestFlight 自動上傳成功 ✅" "ETC_Scanner 新版已上傳，下次約 ${next_date}"
else
  log "❌ 上傳失敗，請看上方紀錄（常見：Apple 合約過期、憑證/描述檔到期）。"
  # 依錯誤內容給出可直接行動的提示（由上而下，先符合者優先）
  if grep -q "agreement is missing or has expired" "$RUN_LOG"; then
    reason="【合約/會員過期】Apple 開發者合約或會員資格過期，或有新合約未簽。請到 developer.apple.com → Account 與 App Store Connect → 商務 更新/簽署。"
  elif grep -qE "Defaults.properties|PKIX|unable to get local issuer" "$RUN_LOG"; then
    reason="【防火牆攔截】編譯成功，但網路防火牆（FortiGate SSL 檢查）攔截了 Apple 上傳伺服器 contentdelivery.itunes.apple.com。請網管把 *.apple.com 排除在 SSL 檢查外；或改接手機熱點後執行 bash fastlane/auto_beta.sh 補傳。"
  elif grep -qiE "Could not resolve host|could not connect|timed out|offline|network connection was lost" "$RUN_LOG"; then
    reason="【網路不通】連不到 Apple 伺服器（斷網或 DNS 問題）。確認網路後執行 bash fastlane/auto_beta.sh 補傳，或等明天 13:30 自動重試。"
  elif grep -qiE "Authentication credentials|NOT_AUTHORIZED|invalid.*(key|token)|HTTP 401|status code 401" "$RUN_LOG"; then
    reason="【API 金鑰失效】App Store Connect API 金鑰被撤銷或無效。請到 App Store Connect → 使用者與存取 → 整合 重新產生金鑰並替換 fastlane/AuthKey_*.p8。"
  elif grep -qiE "bundle version must be higher|has already been used|redundant binary" "$RUN_LOG"; then
    reason="【build 號重複】TestFlight 已有相同或更高的 build 號。通常重跑一次會自動 +1；若持續發生請檢查 Fastfile 的 build 號邏輯。"
  elif grep -qiE "certificate|provisioning profile|code ?sign" "$RUN_LOG"; then
    reason="【簽署問題】簽署憑證或描述檔到期/失效。請開 Xcode → Settings → Accounts 重新下載，或到 developer.apple.com 更新。"
  elif grep -qiE "ARCHIVE FAILED|BUILD FAILED|Error building|xcodebuild.*exit" "$RUN_LOG"; then
    reason="【編譯失敗】程式碼或 Xcode 版本造成編譯失敗。請用 Xcode 開專案 Archive 看錯誤。"
  elif grep -qiE "No such file or directory.*fastlane|command not found" "$RUN_LOG"; then
    reason="【工具遺失】找不到 fastlane。請執行 brew install fastlane。"
  elif grep -q "altool" "$RUN_LOG"; then
    reason="【上傳失敗】編譯成功，但送出到 Apple 失敗（altool）。"
  else
    reason="【未知錯誤】"
  fi
  days_left=$(( 90 - ( (now - last) / 86400 ) ))
  [ "$last" -gt 0 ] && reason="${reason}（目前 TestFlight 版本距過期約 ${days_left} 天，<=0 表示已過期）"
  notify failure "⚠️ ETC_Scanner TestFlight 自動上傳失敗" "$reason 詳細紀錄：fastlane/auto_beta.log。修好後排程每天 13:30 會自動重試。"
fi
