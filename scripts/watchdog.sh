#!/bin/bash
# ============================================================
# 大肥鱼守护脚本
# 功能：每小时探测 AstrBot / NapCat / QQ 登录状态
#   - AstrBot、NapCat 进程不在 → 自动拉起
#   - QQ 掉线 → 重启 NapCat 尝试免扫码自动重登
#   - 彻底被踢（自动重登失败）→ PushPlus 推送通知你去扫码
#   - 服务器重启后由 @reboot cron 自动把服务拉起来
# 日志：/home/nxl-server/MyLittleFish/watchdog.log
# ============================================================

PATH=/usr/local/bin:/usr/bin:/bin

# ---------- 配置 ----------
# pushplus.plus 用微信扫码注册后把 token 填这里；留空 = 只记日志不推送
PUSHPLUS_TOKEN=""
BASE_DIR="/home/nxl-server/MyLittleFish"
NAPCAT_QQ="/home/nxl-server/Napcat/opt/QQ/qq"
NAPCAT_CFG="/home/nxl-server/Napcat/opt/QQ/resources/app/app_launcher/napcat/config"
LOG="$BASE_DIR/watchdog.log"
STATE="/tmp/dafeiyu_watchdog_state"   # 记录上次状态，避免每小时重复推送

# 去代理：代理环境变量会劫持 localhost 请求导致卡死
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy all_proxy VSCODE_PROXY_URI

log()  { echo "[$(date '+%F %T')] $*" >> "$LOG"; }
push() { # push "标题" "内容"
  [ -z "$PUSHPLUS_TOKEN" ] && return 0
  curl -s -m 10 -X POST http://www.pushplus.plus/send \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"$PUSHPLUS_TOKEN\",\"title\":\"$1\",\"content\":\"$2\"}" >/dev/null 2>&1
}

# 探测 QQ 是否在线（带重试，NapCat 刚启动时 API 还没就绪）
qq_is_login() {
  local i crd st tok port hash
  tok=$(jq -r .token "$NAPCAT_CFG/webui.json" 2>/dev/null)
  port=$(jq -r .port "$NAPCAT_CFG/webui.json" 2>/dev/null)
  hash=$(printf '%s' "${tok}.napcat" | sha256sum | cut -d' ' -f1)
  for i in 1 2 3; do
    crd=$(curl -s -m 10 -X POST "http://127.0.0.1:${port:-6099}/api/auth/login" \
      -H "Content-Type: application/json" -d "{\"hash\":\"$hash\"}" | jq -r '.data.Credential // empty')
    [ -z "$crd" ] && { sleep 20; continue; }
    st=$(curl -s -m 10 -X POST "http://127.0.0.1:${port:-6099}/api/QQLogin/CheckLoginStatus" \
      -H "Authorization: Bearer $crd" -H "Content-Type: application/json" -d '{}' \
      | jq -r '.data.isLogin // empty')
    { [ "$st" = "true" ] || [ "$st" = "false" ]; } && { echo "$st"; return 0; }
    sleep 20
  done
  echo "unknown"
}

# ---------- 1. AstrBot 存活 ----------
if ! pgrep -f "astrbot run" >/dev/null; then
  log "AstrBot 未运行，自动拉起"
  cd "$BASE_DIR" && nohup .venv/bin/astrbot run >> astrbot.log 2>&1 &
  push "大肥鱼 AstrBot 自动重启" "AstrBot 进程不在，已自动拉起"
  sleep 15
fi

# ---------- 2. NapCat 存活 ----------
if ! pgrep -f "Napcat/opt/QQ/qq" >/dev/null; then
  log "NapCat 未运行，自动拉起"
  screen -S napcat -X quit >/dev/null 2>&1; sleep 2
  screen -dmS napcat xvfb-run -a "$NAPCAT_QQ" --no-sandbox
  push "大肥鱼 NapCat 自动重启" "NapCat 进程不在，已自动拉起"
  sleep 60
fi

# ---------- 3. QQ 登录状态 ----------
IS_LOGIN=$(qq_is_login)
PREV=$(cat "$STATE" 2>/dev/null)

if [ "$IS_LOGIN" = "true" ]; then
  if [ "$PREV" != "ok" ]; then
    ws="未知"
    ss -tn state established 2>/dev/null | grep -q ":6199" && ws="已连接"
    log "QQ 在线（此前状态: ${PREV:-无记录}，反向ws: $ws）"
    push "大肥鱼在线 ✅" "QQ 已登录，AstrBot 反向 ws $ws"
  fi
  echo "ok" > "$STATE"
  exit 0
fi

# ---------- 4. QQ 掉线：重启 NapCat 尝试免扫码自动重登 ----------
log "QQ 掉线（isLogin=$IS_LOGIN），重启 NapCat 尝试自动重登"
screen -S napcat -X quit >/dev/null 2>&1
sleep 3
screen -dmS napcat xvfb-run -a "$NAPCAT_QQ" --no-sandbox
sleep 90   # 等 QQ 启动并尝试用保存的登录态自动登录

IS_LOGIN2=$(qq_is_login)
if [ "$IS_LOGIN2" = "true" ]; then
  log "重启后自动重登成功"
  if [ "$PREV" != "ok" ]; then
    push "大肥鱼已自动恢复 🎉" "QQ 掉线后已自动重登，无需人工干预"
  fi
  echo "ok" > "$STATE"
else
  log "自动重登失败，需人工扫码（isLogin2=$IS_LOGIN2）"
  if [ "$PREV" != "need_scan" ]; then
    tok=$(jq -r .token "$NAPCAT_CFG/webui.json" 2>/dev/null)
    push "大肥鱼掉线，来扫码 ⚠️" "QQ 被踢下线且自动重登失败。\n\n浏览器打开：\nhttp://192.168.1.88:6099/webui?token=${tok:-890b36e10307}\n\n手机 QQ 扫码即可恢复"
  fi
  echo "need_scan" > "$STATE"
fi
