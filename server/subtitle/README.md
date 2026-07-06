# Orbix 字幕服务

部署在下载服务器上的字幕生成服务。app 长按种子 → 提取字幕 会调用它：

```
ffmpeg 提取音频 → faster-whisper 语音识别 → DeepSeek 翻译 → 视频旁生成 <视频名>.zh.srt
```

生成的 `.zh.srt` 与视频同目录同名，Infuse 播放时会自动识别为外挂中文字幕。

## 部署（服务器上执行）

```bash
# 1. 把 server/subtitle 目录拷到服务器，然后：
sudo bash install.sh

# 2. 填入 DeepSeek API Key（https://platform.deepseek.com 获取）
sudo nano /etc/orbix-subtitle.env

# 3. 启动
sudo systemctl start orbix-subtitle

# 4. 验证
curl http://127.0.0.1:8788/api/health
```

## app 配置

app 设置 → 字幕服务：

- 地址：服务器 IP（如 152.53.131.108）
- 端口：8788
- API Key：`grep ORBIX_API_KEY /etc/orbix-subtitle.env` 的值（安装时自动生成）

## qBittorrent 在 Docker 里？必须配置路径映射

app 汇报的视频路径是容器内路径（如 `/downloads/xxx.mp4`），宿主机上的字幕服务
需要知道它对应的真实目录。先查挂载：

```bash
docker inspect -f '{{ range .Mounts }}{{ .Source }} -> {{ .Destination }}{{ "\n" }}{{ end }}' qbittorrent
# 输出例: /mnt/user/downloads -> /downloads
```

然后在 `/etc/orbix-subtitle.env` 加一行并重启：

```bash
PATH_MAP=/downloads=/mnt/user/downloads
sudo systemctl restart orbix-subtitle
```

多组映射用逗号分隔：`PATH_MAP=/downloads=/mnt/a,/media=/mnt/b`。

## 注意

- 服务需要能读写 qBittorrent 的下载目录（默认以 root 运行；如目录属主不同，编辑
  service 文件里的 `User=`）。
- Whisper 在 CPU 上运行，`small` 模型处理一部 2 小时电影约 20-60 分钟（取决于 CPU）。
  追求速度可改 `WHISPER_MODEL=base`，追求质量用 `medium`。
- 端口 8788 需对 app 可访问（公网或内网均可），注意防火墙放行。

## API

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/api/health` | 健康检查（无需鉴权） |
| POST | `/api/jobs` | 创建任务 `{"video_path": "/downloads/Movie/movie.mkv"}` |
| GET | `/api/jobs/{id}` | 查询任务进度 |
| GET | `/api/jobs?video_path=...` | 按视频路径查任务（app 重新打开时续接进度） |

鉴权：请求头 `X-Api-Key: <ORBIX_API_KEY>`。

任务字段：`stage`（queued/extract/transcribe/translate/write/done/error）、
`progress`（当前阶段 0-100）、`srt_path`、`error`。
