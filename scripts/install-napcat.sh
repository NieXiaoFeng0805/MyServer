#!/bin/bash
# NapCat 安装脚本（官方 CLI 模式，用于 QQ 平台接入 AstrBot）
# 注意：NapCat 壳从 GitHub 下载（走代理会慢几分钟），QQ 本体从腾讯国内源下载（快）

curl -fL --connect-timeout 20 --max-time 1800 \
  -o /tmp/napcat.sh https://raw.githubusercontent.com/NapNeko/NapCat-Installer/main/script/install.sh &&
bash /tmp/napcat.sh --docker n --cli y --github-proxy 0

echo ""
echo "=== 安装完成。后续操作 ==="
echo "1. 启动 NapCat:        napcat"
echo "2. 打开 WebUI 扫码:    napcat webui   (浏览器打开 http://127.0.0.1:6099/webui)"
echo "3. 在 WebUI 网络配置里确认 ws 协议端口为 6099"
echo "4. 手机 QQ 扫码登录"
echo "5. AstrBot WebUI(http://127.0.0.1:6185) → 添加 OneBot v11 平台 → ws://127.0.0.1:6099/ws"
