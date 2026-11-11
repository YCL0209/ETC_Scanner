#!/bin/bash
# auto_beta 通知：macOS 常駐對話框 + Email（透過 App 既有的 Google Apps Script 寄信服務）
# 用法：notify.sh <success|failure> "<標題>" "<內容>"
# 設定檔：fastlane/.notify.env（NOTIFY_EMAIL / GAS_EMAIL_URL / GAS_API_KEY）

LEVEL="$1"; TITLE="$2"; BODY="$3"
DIR="$(cd "$(dirname "$0")" && pwd)"
[ -f "$DIR/.notify.env" ] && source "$DIR/.notify.env"

# 跳脫 AppleScript 字串中的 \ 與 "
as_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
t=$(as_escape "$TITLE"); b=$(as_escape "$BODY")

# 1) macOS：一般通知（短暫橫幅）
/usr/bin/osascript -e "display notification \"$b\" with title \"$t\"" >/dev/null 2>&1 || true

# 2) macOS：失敗時跳常駐對話框（按了才消失，最多停留 12 小時；背景執行不卡住腳本）
if [ "$LEVEL" = "failure" ]; then
  /usr/bin/osascript -e "display dialog \"$b\" with title \"$t\" buttons {\"知道了\"} default button 1 with icon caution giving up after 43200" >/dev/null 2>&1 &
fi

# 3) Email
if [ -n "${NOTIFY_EMAIL:-}" ] && [ -n "${GAS_EMAIL_URL:-}" ]; then
  payload=$(/usr/bin/python3 -c 'import json,sys; print(json.dumps({"action":"sendEmail","recipient":sys.argv[1],"subject":sys.argv[2],"message":sys.argv[3],"csvContent":"","senderName":"ETC Scanner 自動上傳"}, ensure_ascii=False))' \
    "$NOTIFY_EMAIL" "$TITLE" "$BODY")
  resp=$(/usr/bin/curl -sSL --max-time 60 -X POST "$GAS_EMAIL_URL" \
    -H "Content-Type: application/json" -H "x-api-key: ${GAS_API_KEY:-}" \
    --data-binary "$payload" 2>&1)
  if printf '%s' "$resp" | grep -q '"success":\s*true'; then
    echo "[notify] email 已寄出 → $NOTIFY_EMAIL"
  else
    echo "[notify] email 寄送失敗（GAS 回應：$(printf '%s' "$resp" | tr -d '\n' | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -c 100)$(printf '%s' "$resp" | head -c 150 | grep -v '<' )）"
  fi
fi
