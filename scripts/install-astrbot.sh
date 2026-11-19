#!/bin/bash
# AstrBot 安装脚本（pip 方式，依赖走阿里云镜像，主程序走本地代理拉最新版）
set -e

echo "=== [1/4] 安装系统依赖（需要输入 sudo 密码）==="
sudo apt update
sudo apt install -y python3-pip python3.14-venv

cd /home/nxl-server/MyLittleFish

echo "=== [2/4] 创建虚拟环境 ==="
python3 -m venv .venv
env -u https_proxy -u http_proxy -u all_proxy .venv/bin/pip install -U pip -i https://mirrors.aliyun.com/pypi/simple/

echo "=== [3/4] 安装 AstrBot（主程序走代理从 pypi.org 下，依赖走阿里云）==="
# 获取最新 wheel 下载地址（需要本地 Clash 代理 7897 已开启）
if https_proxy=http://127.0.0.1:7897 curl -s --connect-timeout 10 --max-time 60 \
     https://pypi.org/pypi/astrbot/json -o /tmp/astrbot-pypi.json; then
  WHEEL_URL=$(python3 -c "import json;d=json.load(open('/tmp/astrbot-pypi.json'));print([u for u in d['urls'] if u['packagetype']=='bdist_wheel'][0]['url'])")
  REALNAME=$(basename "$WHEEL_URL" | cut -d'#' -f1)
  echo "下载: $REALNAME"
  https_proxy=http://127.0.0.1:7897 curl -sL --connect-timeout 10 --max-time 600 \
    -o "/tmp/$REALNAME" "$WHEEL_URL"
  env -u https_proxy -u http_proxy -u all_proxy .venv/bin/pip install "/tmp/$REALNAME" \
    -i https://mirrors.aliyun.com/pypi/simple/
else
  echo "代理访问 pypi.org 失败，改用阿里云镜像的 4.9.2 版本..."
  env -u https_proxy -u http_proxy -u all_proxy .venv/bin/pip install astrbot \
    -i https://mirrors.aliyun.com/pypi/simple/
fi

echo "=== [4/4] 启动 AstrBot ==="
nohup .venv/bin/astrbot > astrbot.log 2>&1 &
sleep 8
echo "--- 启动日志（找 WebUI 地址和初始密码）---"
tail -30 astrbot.log
