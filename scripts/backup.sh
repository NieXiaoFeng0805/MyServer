#!/usr/bin/env bash
# 备份 NXL 服务器的配置类数据到外置盘（骨架，Melon 插回后启用）
# 用法: ./backup.sh [目标根目录]
set -euo pipefail

TARGET="${1:-/run/media/nxl-server/Melon/backup}"
STAMP="$(date +%Y%m%d-%H%M)"
SRC=(/data/docker /data/alist /data/knowledge /data/photos)

if ! mountpoint -q "$(dirname "$TARGET")" 2>/dev/null; then
  echo "✗ 备份盘未挂载: $(dirname "$TARGET")" >&2
  exit 1
fi

mkdir -p "$TARGET/$STAMP"
for d in "${SRC[@]}"; do
  [ -d "$d" ] || continue
  rsync -a --delete \
    --exclude 'logs/' --exclude 'cache/' --exclude 'node_modules/' \
    "$d/" "$TARGET/$STAMP/$(basename "$d")/"
done

ln -sfn "$TARGET/$STAMP" "$TARGET/latest"
echo "✓ 备份完成: $TARGET/$STAMP"
du -sh "$TARGET/$STAMP"
