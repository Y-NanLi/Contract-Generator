#!/bin/sh
# 只读诊断：为什么 NAS 上的报价单页面没更新（不改任何东西）
#
# 在 NAS 上、docker-compose.yml 所在目录执行：
#     sh deploy/diagnose.sh
# 把输出整段贴回来即可定位。

echo "========== 0. 当前目录 / 文件 =========="
pwd
ls -la | grep -Ei "docker-compose|\.env" || true
echo
echo "[.env 内容]"
if [ -f .env ]; then cat .env; else echo "（没有 .env）"; fi

echo
echo "========== 1. 容器状态 =========="
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.CreatedAt}}\t{{.Ports}}' | grep -Ei "quote|watchtower|IMAGE" || true

echo
echo "========== 2. quote-web 实际用的镜像 =========="
docker inspect quote-web --format 'Config.Image={{.Config.Image}}
Image(digest)={{.Image}}
Created={{.Created}}
Started={{.State.StartedAt}}
RestartCount={{.RestartCount}}' 2>/dev/null || echo "（没有名为 quote-web 的容器）"

echo
echo "========== 3. 本地 latest 镜像 =========="
docker image inspect ghcr.io/y-nanli/contract-generator:latest \
  --format 'Id={{.Id}}
Created={{.Created}}
RepoDigests={{range .RepoDigests}}{{.}} {{end}}' 2>/dev/null || echo "（本地没有这个镜像）"

echo
echo "========== 4. 远端 latest 的 digest（ghcr 线上） =========="
TOKEN=$(curl -fsSL "https://ghcr.io/token?service=ghcr.io&scope=repository:y-nanli/contract-generator:pull" 2>/dev/null \
  | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
if [ -n "${TOKEN:-}" ]; then
  curl -fsS -D - -o /dev/null \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.oci.image.index.v1+json" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
    "https://ghcr.io/v2/y-nanli/contract-generator/manifests/latest" 2>/dev/null | grep -i "docker-content-digest" || echo "（取 digest 失败）"
else
  echo "（连 ghcr.io 取 token 失败：NAS 到 ghcr 的网络不通，这就是根因之一）"
fi

echo
echo "========== 5. Watchtower 最近日志 =========="
docker logs --tail 60 quote-watchtower 2>&1 | tail -40 || echo "（没有 quote-watchtower 容器）"

echo
echo "========== 6. 8090 实际吐出的页面版本号 =========="
curl -s http://127.0.0.1:8090/ 2>/dev/null | grep -o "const VERSION = '[0-9.]*'" | head -1 || echo "（curl 8090 失败）"
curl -sI http://127.0.0.1:8090/ 2>/dev/null | grep -Ei "HTTP/|cache-control|server:" || true

echo
echo "========== 7. compose 解析后的 web 镜像 =========="
docker compose config 2>/dev/null | grep -Ei "image:|container_name: quote-web" || echo "（compose config 解析失败）"
echo
echo "诊断结束。重点看：第 2 项 Image(digest) 与第 4 项 docker-content-digest 是否一致；"
echo "第 5 项里有没有 Found new image / Stopping / Creating，或者 401/timeout 之类报错。"
