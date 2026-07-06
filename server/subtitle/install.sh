#!/usr/bin/env bash
# Orbix 字幕服务一键安装脚本（Debian/Ubuntu，需要 root）
# 用法: sudo bash install.sh
set -euo pipefail

INSTALL_DIR=/opt/orbix-subtitle
ENV_FILE=/etc/orbix-subtitle.env
SERVICE=/etc/systemd/system/orbix-subtitle.service
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> 安装依赖 (ffmpeg, python3-venv)"
apt-get update -qq
apt-get install -y -qq ffmpeg python3-venv python3-pip

echo "==> 部署到 $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/app.py" "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"

echo "==> 创建虚拟环境并安装 Python 依赖（首次需几分钟）"
python3 -m venv "$INSTALL_DIR/venv"
"$INSTALL_DIR/venv/bin/pip" install -q --upgrade pip
"$INSTALL_DIR/venv/bin/pip" install -q -r "$INSTALL_DIR/requirements.txt"

if [ ! -f "$ENV_FILE" ]; then
    GENERATED_KEY=$(head -c 24 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 32)
    cat > "$ENV_FILE" <<EOF
# Orbix 字幕服务配置
# app 端"字幕服务"设置里填写这个 key：
ORBIX_API_KEY=$GENERATED_KEY
# 换成你的 DeepSeek API Key（https://platform.deepseek.com）：
DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxx
# whisper 模型：tiny/base/small/medium/large-v3，越大越准越慢（CPU 建议 small）
WHISPER_MODEL=small
PORT=8788
EOF
    echo "==> 已生成配置 $ENV_FILE，请编辑填入 DEEPSEEK_API_KEY"
else
    echo "==> 已存在配置 $ENV_FILE，跳过"
fi

cat > "$SERVICE" <<EOF
[Unit]
Description=Orbix Subtitle Service
After=network.target

[Service]
EnvironmentFile=$ENV_FILE
ExecStart=$INSTALL_DIR/venv/bin/python $INSTALL_DIR/app.py
Restart=on-failure
# 需要能读视频目录、并在其中写 .srt 文件；qBittorrent 下载目录属主如非 root 请改 User
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable orbix-subtitle

echo ""
echo "安装完成。接下来："
echo "  1. 编辑 $ENV_FILE 填入 DEEPSEEK_API_KEY"
echo "  2. systemctl start orbix-subtitle"
echo "  3. curl http://127.0.0.1:8788/api/health 验证"
echo "  4. app 设置 → 字幕服务：地址填服务器 IP，端口 8788，API Key 用上面 ORBIX_API_KEY 的值"
echo "     （查看：grep ORBIX_API_KEY $ENV_FILE）"
