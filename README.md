# Orbix

> 原生 SwiftUI 打造的 iOS qBittorrent 远程客户端，iOS 17+。

管理远程 qBittorrent 服务器：实时任务监控、内置搜索、联网搜种、统计仪表盘、字幕提取翻译、OTA 更新、Face ID 应用锁。界面完全采用 iOS 原生设计语言（系统 List/Form、语义色、Dynamic Type），视觉对齐 Apple 官方 App。

---

## 功能

- **服务器管理** — 添加/切换/删除 qBittorrent 服务器，连接测试
- **种子管理** — 实时进度、速度、状态；筛选（全部/下载中/做种中/已暂停/已完成）；滑动删除；批量操作
- **种子操作** — 启动/暂停/强制启动/校验/删除；支持磁链、种子 URL、`.torrent` 文件
- **种子详情** — 分组列表展示传输/文件/Tracker/Peers，左右滑动切换种子
- **统计仪表盘** — 实时速度、传输量、分享率、磁盘、连接状态、任务概览
- **内置搜索** — 直接调用 qBittorrent 搜索插件检索种子，支持插件筛选，搜索结果一键添加下载
- **联网搜种** — 对接 141ppv.com，搜索结果以密集照片墙呈现，无限滚动
- **视频提取字幕** — Whisper 语音识别 + 翻译一站式管线，视频直出中文 `.srt`
- **字幕翻译** — 导入 `.srt` 逐条翻译，导出 Infuse 可用中文字幕
- **收藏** — 长按种子收藏，工具栏一键筛选收藏列表
- **图片浏览** — 搜索结果支持全屏图片查看器
- **应用锁** — Face ID 生物识别，后台自动锁定
- **OTA 更新** — GitHub Releases 检测更新，应用内下载安装
- **深色模式** — 跟随系统浅色/深色外观，全程使用系统语义色自适应

## 环境要求

- iOS 17.0+
- qBittorrent 服务器（已开启 Web UI，建议 4.6+）
- [TrollStore](https://github.com/opa334/TrollStore) 安装

## 安装

### GitHub Actions（推荐）

每次推送自动构建未签名 `.ipa`：

1. 打开 [Actions](https://github.com/ac54u-mobile/Orbix/actions)
2. 进入最新的成功 workflow
3. 下载 `Orbix-Unsigned-IPA` artifact
4. 解压得到 `Orbix.ipa`，用 TrollStore 安装

### 发布

```bash
git tag v1.1.2
git push --tags
```

## 技术栈

| 技术 | 用途 |
|------|------|
| SwiftUI | 全部 UI（系统 List/Form/Material/语义色） |
| Swift 5.9 / async-await | 网络层 |
| URLSession | qBittorrent API 通信 |
| LocalAuthentication | Face ID |
| Keychain | 凭据安全存储 |
| XcodeGen | 项目生成 |
| GitHub Actions | CI / 构建 |

## 项目结构

```
ios/Orbix/
├── OrbixApp.swift         应用入口
├── ContentView.swift      根导航路由
├── Theme/
│   └── AppMotion.swift    统一触觉反馈（AppHaptics）
├── Models/                数据模型
│   ├── ServerConfig.swift
│   ├── TorrentInfo.swift
│   ├── ScrapedTorrent.swift
│   └── AppRelease.swift
├── Services/              业务逻辑层
│   ├── QBitApi.swift             核心 API 客户端
│   ├── QBitApi+Search.swift      内置搜索引擎
│   ├── QBitApi+TorrentData.swift 种子数据
│   ├── QBitApi+TorrentActions.swift 种子操作
│   ├── QBitApi+Preferences.swift 偏好设置
│   ├── CredentialsManager.swift  凭据管理 + 连接测试
│   ├── KeychainService.swift     Keychain 加密存储
│   ├── PersistenceService.swift  本地偏好持久化
│   ├── AppLockService.swift      Face ID 应用锁
│   ├── TorrentSearchService.swift 141ppv 爬虫
│   ├── TorrentDetailDataService.swift 种子详情
│   ├── SpeechTranscribeService.swift  Whisper 语音识别
│   ├── DeepSeekTranslateService.swift 字幕翻译
│   ├── TranslateService.swift    翻译服务
│   └── UpdateService.swift       OTA 更新
├── Views/                 页面视图
│   ├── SplashView / WelcomeView / LoginView
│   ├── ServerSelectionView / ServerManagementView / AddServiceView
│   ├── MainTabView
│   ├── TorrentListView / AddTorrentView
│   ├── TorrentDetailView / TorrentDetailPagerView
│   ├── TorrentDetail{File,Tracker,Advanced}Sheet
│   ├── StatsView / SettingsView
│   ├── SearchView（141ppv）/ QBitSearchView（内置搜索）
│   └── VideoSubtitleView / SubtitleTranslateView（字幕管线）
├── Components/            可复用组件
│   ├── TorrentRow / ScrapedTorrentRow / TorrentDetailSheet
│   ├── StatusIcon / GlobalSpeedPill / EmptyStateView
│   ├── MediaViewer / ToastView / ConnectingDialog
│   └── 更多...
├── Extensions/
│   ├── View+Extensions.swift
│   └── Color+Hex.swift
└── Utils/
    ├── OrbixStrings.swift  国际化字符串
    ├── FormatUtils.swift   格式化工具
    ├── ImageCache.swift    图片缓存
    ├── SRTParser.swift     SRT 字幕解析
    ├── Constants.swift     常量
    └── RetryUtils.swift    重试工具

server/
└── translate_server.py    自建翻译服务端
```

## 配置

- 修改更新检测仓库：`Services/UpdateService.swift` → `repo`
- 界面全部使用系统组件与语义色，无自建设计系统；触觉反馈集中在 `Theme/AppMotion.swift`

---

当前版本 **v1.1.2**
