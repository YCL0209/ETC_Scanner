#!/bin/bash
# auto_beta 通知：macOS 通知＋失敗時常駐對話框
# 用法：notify.sh <success|failure> "<標題>" "<內容>"

LEVEL="$1"; TITLE="$2"; BODY="$3"

# 跳脫 AppleScript 字串中的 \ 與 "
as_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
t=$(as_escape "$TITLE"); b=$(as_escape "$BODY")

# 1) macOS：一般通知（短暫橫幅）
/usr/bin/osascript -e "display notification \"$b\" with title \"$t\"" >/dev/null 2>&1 || true

# 2) macOS：失敗時跳常駐對話框（按了才消失，最多停留 12 小時；背景執行不卡住腳本）
if [ "$LEVEL" = "failure" ]; then
  /usr/bin/osascript -e "display dialog \"$b\" with title \"$t\" buttons {\"知道了\"} default button 1 with icon caution giving up after 43200" >/dev/null 2>&1 &
fi

