# MusicLinker — iOS/iPadOS App

一个 iOS 应用，输入任意音乐平台的歌曲链接，自动聚合该歌曲在其他所有主流平台的链接。

---

## 支持的平台

| 输入 | 输出 |
|------|------|
| Spotify | ✅ |
| Apple Music | ✅ |
| YouTube Music | ✅ |
| Tidal | ✅ |
| Deezer | ✅ |
| Amazon Music | ✅ |
| SoundCloud | ✅ |
| Pandora | ✅ |
---

## 技术架构

```
MusicLinker/
├── MusicLinkerApp.swift   # App 入口
├── ContentView.swift      # 主界面（搜索 + 结果展示）
├── ResultView.swift       # 歌曲结果 + 平台链接列表
├── OdesliService.swift    # Odesli/song.link API 封装
└── URLHandler.swift       # URL Scheme 处理（从其他 App 接收链接）
```

### 核心 API：Odesli（song.link）

本 App 使用 [Odesli API](https://odesli.co) 进行跨平台音乐链接转换。

- **免费使用**，无需 API Key（每分钟有速率限制）
- 支持全球（境外）主流音乐平台
- 返回歌曲元数据（标题、艺术家、封面图）

```
GET https://api.song.link/v1-alpha.1/links?url={encoded_url}&userCountry=CN
```

---

## 如何运行

### 1. 创建 Xcode 项目

1. 打开 Xcode → New Project → iOS → App
2. 将所有 `.swift` 文件拖入项目
3. 删除默认生成的 `ContentView.swift`（使用本项目的版本）

### 2. 配置 Info.plist（可选）

若要支持从 Spotify / Apple Music 的"分享"菜单直接打开本 App，在 `Info.plist` 中添加：

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>musiclinker</string>
        </array>
    </dict>
</array>
```

### 3. 网络权限

在 `Info.plist` 中添加（Xcode 默认已有，确认存在即可）：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
</dict>
```

---

## 使用方法

1. 在任意音乐 App（Spotify、Apple Music 等）找到一首歌
2. 点击"分享" → 复制链接
3. 打开 MusicLinker，点击"粘贴"按钮
4. 点击"搜索"，即可看到该歌曲在所有平台的链接
5. 点击对应平台的 ↗ 按钮直接跳转，或点击复制链接图标复制

---

## 未来可扩展功能

- [ ] Shortcut / Widget 支持（iOS 主屏幕小组件）
- [ ] Share Extension（在其他 App 内直接分享到 MusicLinker）
- [ ] 收藏功能
- [ ] 国产平台直接支持（网易云 / QQ 音乐官方 API，需申请 Key）
- [ ] 生成15s视频
- [ ] 对于iPadOS进行ui适配
- [ ] 安卓版会有的
- [ ] 运用歌名进行搜索
      
