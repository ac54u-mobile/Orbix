# Orbix

> 原生 SwiftUI 打造的 iOS qBittorrent 远程客户端，iOS 17+。

管理远程 qBittorrent 服务器：实时任务监控、联网搜种、统计仪表盘、OTA 更新、Face ID 应用锁。

---

## 功能

- **多服务器** — 添加/切换/删除 qBittorrent 服务器
- **任务管理** — 实时进度、速度、状态；筛选（全部/下载中/做种中/已暂停/已完成）；滑动删除
- **任务操作** — 启动/暂停/强制启动/校验/删除；支持磁链、种子 URL、`.torrent` 文件
- **统计** — 实时速度、传输量、分享率、磁盘、连接状态、任务概览
- **联网搜种** — 对接 141ppv.com，搜索结果以密集照片墙呈现，无限滚动
- **收藏** — 长按种子收藏，工具栏一键筛选收藏列表
- **图片浏览** — 搜索结果支持全屏图片查看器
- **应用锁** — Face ID 生物识别，后台 8 秒自动锁定
- **OTA 更新** — GitHub Releases 检测更新，应用内下载安装
- **深色模式** — 全局统一的深色设计语言

## 环境要求

- iOS 17.0+
- qBittorrent 服务器（已开启 Web UI）
- [TrollStore](https://github.com/opa334/TrollStore) 安装

## 安装

### GitHub Actions（推荐）

每次推送自动构建未签名 `.ipa`：

1. 打开 [Actions](https://github.com/ac54u/Orbix/actions)
2. 进入最新的成功 workflow
3. 下载 `Orbix-Unsigned-IPA` artifact
4. 解压得到 `Orbix.ipa`，用 TrollStore 安装

### 发布

```bash
git tag v1.0.10
git push --tags
```

## 技术栈

| 技术 | 用途 |
|------|------|
| SwiftUI | 全部 UI |
| Swift 5.9 / async-await | 网络层 |
| URLSession | API 通信 |
| LocalAuthentication | Face ID |
| UserDefaults | 本地持久化 |
| XcodeGen | 项目生成 |
| GitHub Actions | CI / 构建 |

## 项目结构

```
ios/Orbix/
├── OrbixApp.swift
├── Theme/              颜色 / 字体 / 动画 token
├── Models/             服务器 / 种子 / 搜索结果 / 版本模型
├── Services/           API 客户端 / 爬虫 / 翻译 / 应用锁 / OTA
├── Views/              所有页面和组件
│   ├── SplashView.swift
│   ├── WelcomeView.swift
│   ├── LoginView.swift
│   ├── ServerSelectionView.swift
│   ├── ServerManagementView.swift
│   ├── MainTabView.swift
│   ├── TorrentListView.swift
│   ├── TorrentDetailView.swift
│   ├── AddTorrentView.swift
│   ├── StatsView.swift
│   ├── SearchView.swift
│   └── SettingsView.swift
├── Components/         SkeletonBar / ProgressBar / Toast / MediaViewer
└── Utils/              ImageCache
```

## 配置

- 修改更新检测仓库：`Services/UpdateService.swift` → `repo`
- 设计 token 集中在 `Theme/` 目录，统一管理颜色/字体/动画

---

当前版本 **v1.0.10**
