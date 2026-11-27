#!/bin/sh
# 强制更新报价单生成器容器（不依赖 Watchtower，手动跑一次就能换新）
#
# 在 NAS 上、docker-compose.yml 所在目录执行：
#     sh deploy/update.sh
# 或先赋予执行权限：chmod +x deploy/update.sh && ./deploy/update.sh
#
# 它会：读 .env → docker pull → 强制重建 quote-web → 打印新容器用的镜像
# 不需要停 Watchtower；两个都更新也不冲突。

set -eu
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  # shellcheck disable=SC1091
  . ./.env
  echo "[.env] 已读取（QUOTE_IMAGE=${QUOTE_IMAGE:-未设置}）"
else
  echo "[.env] 没有 .env，用默认镜像地址"
fi

IMAGE="${QUOTE_IMAGE:-ghcr.io/y-nanli/contract-generator:latest}"

echo "== 1/4 拉取镜像：$IMAGE"
docker pull "$IMAGE"

echo "== 2/4 强制重建 quote-web（用新镜像，不重建 watchtower）"
docker compose up -d --force-recreate --no-deps web

echo "== 3/4 容器状态"
docker compose ps || true

echo "== 4/4 新容器实际用的镜像"
docker inspect quote-web \
  --format 'Image: {{.Config.Image}}
Digest: {{.Image}}
Created: {{.Created}}
Started: {{.State.StartedAt}}' 2>/dev/null || echo "（容器名不是 quote-web？请自行对照 docker ps）"

echo
echo "浏览器打开 http://本机IP:8090，页面左上角应显示 v2.7；"
echo "若还是旧版，Ctrl+F5 硬刷新，或确认访问的端口/容器是不是这一个。"
