# MusicLinker

跨平台音乐链接转换工具。粘贴任意音乐平台的歌曲链接，一键获取 Spotify、Apple Music、YouTube Music、网易云音乐等 15+ 平台的对应链接。

## 功能

- **跨平台链接转换** — 基于 Odesli API，覆盖全球主流音乐流媒体
- **Share Extension** — 在其他 App 中直接分享歌曲链接到 MusicLinker
- **正在播放检测** — 读取 Apple Music 当前播放歌曲并自动搜索
- **歌词海报生成** — 获取歌曲热门歌词并生成可分享的海报卡片
- **AI 歌词精选** — 通过 DeepSeek AI 从完整歌词中提取最动人的片段
- **音频预览** — 支持 iTunes / Spotify 30 秒试听
- **搜索历史** — 自动保存搜索记录，支持删除和回看
- **7 种主题** — 深色、浅色、纯黑、紫色、绿色、橙色、粉色
- **多语言** — 中文、English、日本語、Русский
- **一键复制全部链接** — 批量导出所有平台链接
- **网易云音乐增强** — 可选配置 API 以获取精确歌曲链接
- **CN 模式** — Apple Music 链接自动切换中区 / 美区

## 支持的平台

Spotify · Apple Music · YouTube Music · 网易云音乐 · Tidal · Deezer · Amazon Music · Pandora · SoundCloud · Napster · Yandex Music · Anghami · Boomplay · Audius · Spinrilla

## 项目结构

```
MusicLinker/
├── MusicLinkerApp.swift          # App 入口
├── ContentView.swift             # 主界面（搜索、历史、主题）
├── ResultView.swift              # 结果卡片（平台链接、歌词海报、音频预览）
├── OdesliService.swift           # API 服务（Odesli + 网易云）
├── URLHandler.swift              # URL Scheme 处理
├── LanguageManager.swift         # 多语言管理
├── KeychainHelper.swift          # Keychain 安全存储
├── Content+Color.swift           # 主题与颜色定义
├── ShareExtension/               # 系统分享扩展
│   └── ShareViewController.swift
└── Config.txt                    # API Key 配置
```

## 快速开始

1. 用 Xcode 打开 `MusicLinker.xcodeproj`
2. 在 Signing & Capabilities 中选择你的开发者 Team
3. 如有需要，修改 Bundle Identifier
4. Command+R 运行

> iOS 16.0+ / Xcode 14.0+

## 可选配置

### 网易云音乐 API

在设置中填入自部署的 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) 地址，可获取精确歌曲链接。留空则使用搜索链接，不影响正常使用。

### DeepSeek AI 歌词分析

在设置中启用并填入 [DeepSeek API Key](https://platform.deepseek.com)，可在浏览歌词时由 AI 精选最动人的段落。禁用不影响其他功能。

### Share Extension

在其他音乐 App 中点击"分享" → 选择 MusicLinker，链接会自动传递给主 App。

## 技术栈

SwiftUI · Async/Await · Combine · URLSession · Keychain · App Groups · MediaPlayer

## 许可证

MIT License

## 致谢

- [Odesli](https://odesli.co) — 核心跨平台链接 API
- [Songwhip](https://songwhip.com) — 备用数据源
- [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) — 网易云音乐 API
