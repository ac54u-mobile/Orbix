#!/bin/bash
# 将本地提交推送到指定远程仓库 https://github.com/ac54u/orbix.git
set -e

REMOTE_URL="https://github.com/ac54u/orbix.git"

# 确保 origin remote 存在且指向正确的 URL
if ! git remote get-url origin &>/dev/null; then
    git remote add origin "$REMOTE_URL"
else
    git remote set-url origin "$REMOTE_URL"
fi

# 远程默认分支为 master，本地分支为 main
git push origin main:master
git push --tags
