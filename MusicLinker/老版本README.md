# 🎵 MusicLinker

> **一键查找歌曲在所有音乐平台的链接**

MusicLinker 是一款 iOS 应用，让你轻松将歌曲链接在不同音乐平台之间转换。只需粘贴一个平台的链接，即可获取该歌曲在 Spotify、Apple Music、YouTube Music 等所有主流平台的访问链接。

---

## ✨ 核心功能

- 🔗 **跨平台链接转换** - 支持 14+ 音乐流媒体平台
- 🎨 **精美界面** - 现代化的 SwiftUI 设计
- 📸 **歌曲信息展示** - 自动获取封面、艺术家、专辑等信息
- 🚀 **智能备用策略** - 即使 API 缺失数据，也能提供搜索链接
- 🌍 **全球支持** - 自动转换地区链接，优化跨平台映射
- 📋 **一键复制** - 快速复制任意平台的链接
- ⚡️ **快速响应** - 异步加载，流畅体验

---

## 🎼 支持的平台

### 主流平台

| 平台 | 支持状态 | 说明 |
|------|---------|------|
| 🎵 **Spotify** | ✅ | 完整支持，包括搜索回退 |
| 🎵 **Apple Music** | ✅ | 完整支持，自动地区转换 |
| ▶️ **YouTube Music** | ✅ | 完整支持，包括封面解析 |
| ☁️ **网易云音乐** | ✅ | 搜索链接 + URL识别，支持App跳转 |
| 🌊 **Tidal** | ✅ | 高保真音乐平台 |
| 🎧 **Deezer** | ✅ | 欧洲流行平台 |
| 📦 **Amazon Music** | ✅ | 亚马逊音乐服务 |

### 其他支持的平台

- 🐦 **Pandora** - 在线广播与音乐流媒体
- ☁️ **SoundCloud** - 独立音乐人平台
- 🎵 **Napster** - 经典数字音乐平台
- 🎶 **Yandex Music** - 俄罗斯音乐服务
- 💜 **Anghami** - 中东地区流行平台
- 🔥 **Boomplay** - 非洲音乐平台
- 🎨 **Audius** - 去中心化音乐平台
- 🎤 **Spinrilla** - 嘻哈音乐平台

*总计支持 **15+ 平台**，持续更新中*

---

## 🛠 技术架构

### 项目结构

```
MusicLinker/
├── MusicLinkerApp.swift      # App 入口点
├── ContentView.swift         # 主界面 - 搜索框和结果展示
├── ResultView.swift          # 歌曲结果卡片 - 平台链接列表
├── OdesliService.swift       # 核心服务 - API 封装与数据解析
├── URLHandler.swift          # URL Scheme 处理器
├── LanguageManager.swift     # 多语言支持
└── Info.plist               # 配置文件（网络权限、URL Scheme）
```

### 核心技术栈

- **SwiftUI** - 现代化声明式 UI 框架
- **Async/Await** - Swift 并发编程
- **Combine** - 响应式数据流
- **URLSession** - 网络请求
- **ObservableObject** - 状态管理

### API 服务

#### 主 API：Odesli (song.link)

```
https://api.song.link/v1-alpha.1/links?url={URL}&userCountry=US&songIfSingle=true
```

- ✅ 免费使用，无需 API Key
- ✅ 支持全球主流音乐平台
- ✅ 返回完整歌曲元数据
- ⚠️ 每分钟有速率限制

#### 备用策略

1. **URL 模式识别** - 从已知 URL 提取平台信息
2. **智能搜索链接** - 基于歌曲信息构造搜索 URL
3. **Songwhip API** - 第三方备用数据源

---

## 🚀 快速开始

### 环境要求

- macOS 12.0+
- Xcode 14.0+
- iOS 16.0+ 设备或模拟器

### 安装步骤

#### 1. 克隆项目

```bash
git clone https://github.com/your-username/MusicLinker.git
cd MusicLinker
```

#### 2. 打开 Xcode 项目

```bash
open MusicLinker.xcodeproj
```

#### 3. 配置签名

在 Xcode 中：
1. 选择项目 → Targets → MusicLinker
2. Signing & Capabilities → Team → 选择你的开发者账号
3. Bundle Identifier → 修改为唯一标识符（如 `com.yourname.MusicLinker`）

#### 4. 运行

1. 选择目标设备（iPhone 模拟器或真机）
2. 点击 Run 按钮（⌘+R）

---

## 📱 使用指南

### 基本使用

1. **复制歌曲链接**
   - 在任意音乐 App（Spotify、Apple Music 等）中打开一首歌
   - 点击"分享" → "复制链接"

2. **粘贴并搜索**
   - 打开 MusicLinker
   - 点击"粘贴"按钮自动填充链接
   - 点击"搜索"

3. **获取平台链接**
   - 查看歌曲信息（封面、标题、艺术家）
   - 点击任意平台的链接图标
   - 或点击"复制链接"按钮

### 高级功能

#### URL Scheme 支持（可选配置）

在其他 App 中通过 URL Scheme 直接打开 MusicLinker：

```
musiclinker://open?url={encoded_music_url}
```

配置方法：在 `Info.plist` 中已包含相关设置。

---

## 🎯 核心功能详解

### 1. 智能地区转换

自动将中国区 Apple Music 链接转换为美国区，提高跨平台映射成功率：

```swift
// 中国区链接
music.apple.com/cn/album/...

// 自动转换为
music.apple.com/us/album/...
```

### 2. 智能备用链接

当 API 缺少某些平台的直接链接时，自动构造搜索链接：

```swift
// Spotify 搜索链接
https://open.spotify.com/search/{歌名}%20{艺术家}

// Apple Music 搜索链接  
https://music.apple.com/search?term={歌名}%20{艺术家}

// 网易云音乐搜索链接
https://music.163.com/#/search/m/?s={歌名}%20{艺术家}
```

用户可以点击搜索链接，在对应平台手动查找歌曲。

### 3. 网易云音乐支持

完整支持网易云音乐链接的识别和跳转：

- **URL 识别**：自动识别网易云音乐链接（music.163.com、y.music.163.com）
- **ID 提取**：智能提取歌曲 ID，构造标准链接
- **App 跳转**：支持直接跳转到网易云音乐 App（使用 orpheus:// URL Scheme）

#### 🆕 网易云音乐 API 增强（可选）

**默认模式（推荐）：**
- 使用搜索链接，无需配置
- 稳定可靠，用户体验好
- 支持直接跳转到网易云 App

**API 模式（高级功能）：**

如果你需要获取精确的歌曲链接而非搜索链接，可以配置网易云音乐 API：

1. **部署 API 服务**
   
   使用 [NeteaseCloudMusicApi](https://github.com/Binaryify/NeteaseCloudMusicApi) 项目：
   
   ```bash
   # 本地部署
   git clone https://github.com/Binaryify/NeteaseCloudMusicApi.git
   cd NeteaseCloudMusicApi
   npm install
   node app.js
   
   # 或使用 Vercel 一键部署（推荐）
   # 访问项目主页，点击 "Deploy to Vercel"
   ```

2. **在 App 中配置**
   
   - 打开 MusicLinker App
   - 点击右上角 ⚙️ 设置按钮
   - 输入你的 API 地址（例如：`https://your-api.vercel.app`）
   - 保存设置

3. **工作原理**
   
   启用 API 后，App 会尝试调用 API 获取精确链接：
   - ✅ API 成功：显示精确的歌曲链接
   - ⚠️ API 失败：自动回退到搜索链接
   - ⏱️ 5 秒超时保护，不影响用户体验

**API 端点说明：**

```
GET /cloudsearch?keywords={歌名 艺术家}&type=1&limit=1

响应格式：
{
  "code": 200,
  "result": {
    "songs": [{
      "id": 123456,
      "name": "歌名",
      "artists": [{"name": "艺术家"}],
      "album": {"picUrl": "封面URL"}
    }]
  }
}
```

**注意事项：**
- API 服务需要自行部署或使用可靠的公开服务
- 建议使用 Vercel 等平台部署，免费且稳定
- 如果没有 API 需求，保持默认配置即可

### 4. 多实体封面解析

智能从 API 返回的多个实体中查找封面图片，确保 YouTube Music 等平台也能正确显示封面。

### 5. 平台去重

自动处理 API 返回的重复平台（如 `appleMusic` 和 `itunes`），避免显示重复条目。

### 6. 自定义主题

提供 7 种精美主题供选择：

- 🌙 **深色**（默认）- 优雅的深色调，因为主创是是深色模式爱好者，所以默认是深色
- ☀️ **浅色** - 明亮清爽
- ⚫️ **纯黑** - OLED 友好
- 💜 **紫色** - 神秘优雅
- 💚 **绿色** - 清新自然  
- 🧡 **橙色** - 活力四射
- 💗 **粉色** - 浪漫温柔

切换方式：点击右上角调色板图标 🎨

---

## 🔧 配置说明

### Info.plist 关键配置

#### 网络安全设置（已配置）

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>song.link</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
        <!-- 更多域名配置... -->
    </dict>
</dict>
```

#### URL Scheme（已配置）

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

---

## 🐛 故障排除

### 常见问题

**Q: 为什么有些歌曲找不到某些平台的链接？**

A: 某些歌曲可能在特定平台不可用（地区限制、版权问题等）。MusicLinker 会自动提供搜索链接，让你在对应平台手动查找。

**Q: API 请求失败怎么办？**

A: 检查网络连接，确保 `Info.plist` 中的网络安全设置正确。Odesli API 有速率限制，请稍后重试。

**Q: 为什么封面图片不显示？**

A: 部分歌曲可能没有封面信息。YouTube Music 链接现已支持智能封面解析。

**Q: 如何添加更多平台？**

A: 在 `OdesliService.swift` 的 `getPlatformInfo()` 方法中添加新平台的映射配置。

---

## 🗺 路线图

### 已完成 ✅

- [x] 15+ 平台支持（包括网易云音乐）
- [x] 智能备用链接
- [x] 地区自动转换
- [x] YouTube Music 封面解析
- [x] 平台去重
- [x] 详细错误处理
- [x] 网易云音乐 URL 识别与 App 跳转
- [x] 7种精美主题（含纯黑省电模式）
- [x] 历史记录功能
- [x] 快速分享功能
- [x] 一键复制所有链接

### 计划中 🚧

- [ ] 历史记录功能
- [ ] 收藏夹
- [ ] Share Extension（分享扩展）
- [ ] Widget 支持
- [ ] macOS 版本
- [ ] 深色模式优化
- [ ] 离线缓存

---

## 📄 许可证

MIT License - 详见 LICENSE 文件

---

## 🙏 致谢

- [Odesli API](https://odesli.co) - 核心跨平台链接服务
- [Songwhip](https://songwhip.com) - 备用数据源
- Apple Human Interface Guidelines - UI/UX 设计指南

---

## 📮 联系方式

如有问题或建议，欢迎：
- 提交 Issue
- 发起 Pull Request
- 联系开发者

---
