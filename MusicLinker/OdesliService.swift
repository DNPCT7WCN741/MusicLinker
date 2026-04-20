import Foundation

// MARK: - Odesli API Response Models

struct OdesliResponse: Codable {
    let entityUniqueId: String
    let userCountry: String
    let pageUrl: String
    let entitiesByUniqueId: [String: MusicEntity]
    let linksByPlatform: [String: PlatformLinks]
}

struct MusicEntity: Codable {
    let id: String
    let type: String
    let title: String?
    let artistName: String?
    let thumbnailUrl: String?
    let thumbnailWidth: Int?
    let thumbnailHeight: Int?
    let apiProvider: String
    let platforms: [String]
    let releaseDate: String?
}

struct PlatformLinks: Codable {
    let country: String?
    let url: String
    let nativeAppUriMobile: String?
    let nativeAppUriDesktop: String?
    let entityUniqueId: String
}

// MARK: - Platform Info

enum MusicPlatform: String, CaseIterable {
    case spotify = "spotify"
    case appleMusic = "appleMusic"
    case netease = "netease"
    case qqMusic = "tidal"       // Odesli doesn't support QQ/Netease natively
    case youtubeMusic = "youtubeMusic"
    case tidal = "tidal1"
    case deezer = "deezer"
    case amazonMusic = "amazonMusic"
    case pandora = "pandora"
    case soundcloud = "soundcloud"

    var displayName: String {
        switch self {
        case .spotify: return "Spotify"
        case .appleMusic: return "Apple Music"
        case .netease: return "网易云音乐"
        case .qqMusic: return "QQ 音乐"
        case .youtubeMusic: return "YouTube Music"
        case .tidal: return "Tidal"
        case .deezer: return "Deezer"
        case .amazonMusic: return "Amazon Music"
        case .pandora: return "Pandora"
        case .soundcloud: return "SoundCloud"
        }
    }

    var icon: String {
        switch self {
        case .spotify: return "🎵"
        case .appleMusic: return "🎵"
        case .netease: return "☁️"
        case .qqMusic: return "🎶"
        case .youtubeMusic: return "▶️"
        case .tidal: return "🌊"
        case .deezer: return "🎧"
        case .amazonMusic: return "📦"
        case .pandora: return "🐦"
        case .soundcloud: return "☁️"
        }
    }

    var color: String {
        switch self {
        case .spotify: return "#1DB954"
        case .appleMusic: return "#FC3C44"
        case .netease: return "#E60026"
        case .qqMusic: return "#31C27C"
        case .youtubeMusic: return "#FF0000"
        case .tidal: return "#000000"
        case .deezer: return "#A238FF"
        case .amazonMusic: return "#00A8E1"
        case .pandora: return "#3668FF"
        case .soundcloud: return "#FF5500"
        }
    }
}

// MARK: - App Platform Model

struct AppPlatformLink: Identifiable {
    let id = UUID()
    let platformKey: String
    let displayName: String
    let iconName: String
    let accentColor: String
    let url: String
    let nativeUrl: String?
}

// MARK: - Odesli Service
import SwiftUI
import SwiftData // 截图显示你还用了 SwiftData，保留它
import Combine // ✅ 确保这一行存在

@Observable // 使用这个宏
class MyData {
    var name: String = ""
    // 不需要写 objectWillChange
}
@Observable // 使用宏，连 ObservableObject 协议都不需要写
class MyModel {
    var name = "Tashkent"
}

class OdesliService: ObservableObject {
    @Published var isLoading = false
    @Published var result: SongResult?
    @Published var errorMessage: String?

    private let baseURL = "https://api.song.link/v1-alpha.1/links"
    private let songwhipURL = "https://songwhip.com/"

    func fetchLinks(url: String) async {
        // 将中国区链接转换为美国区链接（提高跨平台映射成功率）
        var processedURL = url
        if url.contains("music.apple.com/cn") {
            processedURL = url.replacingOccurrences(of: "/cn/", with: "/us/")
            print("🔄 检测到中国区 Apple Music 链接，转换为美国区: \(processedURL)")
        } else if url.contains("geo.music.apple.com/cn") {
            processedURL = url.replacingOccurrences(of: "geo.music.apple.com/cn", with: "music.apple.com/us")
            print("🔄 检测到中国区 Apple Music 短链接，转换为美国区: \(processedURL)")
        }
        
        guard let encodedURL = processedURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)?url=\(encodedURL)&userCountry=US&songIfSingle=true") else {
            await MainActor.run {
                self.errorMessage = "无效的链接格式"
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.result = nil
        }

        do {
            print("🌐 正在请求 API: \(requestURL.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: requestURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ 无效的 HTTP 响应")
                throw URLError(.badServerResponse)
            }

            print("✅ HTTP 状态码: \(httpResponse.statusCode)")

            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP 错误: \(httpResponse.statusCode)")
                throw NSError(domain: "OdesliError", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "无法找到这首歌的信息，请检查链接是否正确 (HTTP \(httpResponse.statusCode))"])
            }

            let odesliResponse = try JSONDecoder().decode(OdesliResponse.self, from: data)
            var songResult = parseSongResult(from: odesliResponse)
            
            // 检查是否缺少关键平台（Spotify 或 Apple Music）
            let hasSpotify = songResult.platforms.contains { $0.displayName == "Spotify" }
            let hasAppleMusic = songResult.platforms.contains { $0.displayName == "Apple Music" }
            
            print("🔍 检查平台覆盖: Spotify=\(hasSpotify), Apple Music=\(hasAppleMusic)")
            
            // 如果缺少关键平台，尝试备用 API 补充
            if !hasSpotify || !hasAppleMusic {
                print("⚠️ 缺少关键平台，尝试备用 API 补充...")
                do {
                    if let backupLinks = try await fetchFromBackupAPI(
                        url: processedURL, 
                        title: songResult.title, 
                        artist: songResult.artist,
                        missingSpotify: !hasSpotify,
                        missingAppleMusic: !hasAppleMusic
                    ) {
                        songResult = mergeResults(primary: songResult, backup: backupLinks)
                    }
                } catch {
                    print("⚠️ 备用 API 调用失败，继续使用主 API 结果: \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.result = songResult
                self.isLoading = false
            }
        } catch let decodingError as DecodingError {
            print("❌ 解析错误: \(decodingError)")
            await MainActor.run {
                self.errorMessage = "解析响应失败：\(decodingError.localizedDescription)"
                self.isLoading = false
            }
        } catch let urlError as URLError {
            print("❌ 网络错误: \(urlError.localizedDescription)")
            print("   错误代码: \(urlError.code.rawValue)")
            if urlError.code == .secureConnectionFailed {
                print("   ⚠️ TLS/SSL 连接失败 - 请检查 Info.plist 的 ATS 设置")
            }
            await MainActor.run {
                self.errorMessage = "网络请求失败: \(urlError.localizedDescription)\n请检查网络连接"
                self.isLoading = false
            }
        } catch {
            print("❌ 未知错误: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func getPlatformInfo(for key: String) -> (displayName: String, icon: String, color: String, priority: Int)? {
        let normalizedKey = key.lowercased()
        
        switch normalizedKey {
        case "spotify":
            return ("Spotify", "spotify.icon", "#1DB954", 1)
        case "applemusic", "itunes":
            return ("Apple Music", "applemusic.icon", "#FC3C44", 2)
        case "youtube", "youtubemusic":
            return ("YouTube Music", "youtubemusic.icon", "#FF0000", 3)
        case "tidal":
            return ("Tidal", "tidal.icon", "#000000", 4)
        case "deezer":
            return ("Deezer", "deezer.icon", "#A238FF", 5)
        case "amazon", "amazonmusic", "amazonstore":
            return ("Amazon Music", "amazonmusic.icon", "#00A8E1", 6)
        case "pandora":
            return ("Pandora", "pandora.icon", "#3668FF", 7)
        case "soundcloud":
            return ("SoundCloud", "soundcloud.icon", "#FF5500", 8)
        case "napster":
            return ("Napster", "napster.icon", "#0D0D0D", 9)
        case "yandex", "yandexmusic":
            return ("Yandex Music", "yandex.icon", "#FFCC00", 10)
        case "anghami":
            return ("Anghami", "anghami.icon", "#A020F0", 11)
        case "boomplay":
            return ("Boomplay", "boomplay.icon", "#FF6B35", 12)
        case "audius":
            return ("Audius", "audius.icon", "#CC0FE0", 13)
        case "spinrilla":
            return ("Spinrilla", "spinrilla.icon", "#00D1FF", 14)
        default:
            return nil
        }
    }

    private func parseSongResult(from response: OdesliResponse) -> SongResult {
        let entity = response.entitiesByUniqueId[response.entityUniqueId]
        
        // 调试输出：查看 API 返回的所有平台
        print("==========================================")
        print("📱 API 返回的平台数量: \(response.linksByPlatform.count)")
        print("📱 平台 keys: \(response.linksByPlatform.keys.sorted())")
        print("==========================================")
        
        var links: [AppPlatformLink] = []
        var addedPlatforms: Set<String> = [] // 用于去重
        
        // 遍历 API 返回的所有平台（不再使用固定列表）
        for (key, platformData) in response.linksByPlatform {
            if let info = getPlatformInfo(for: key) {
                // 检查是否已添加该平台（避免 appleMusic 和 itunes 重复）
                if !addedPlatforms.contains(info.displayName) {
                    links.append(AppPlatformLink(
                        platformKey: key,
                        displayName: info.displayName,
                        iconName: info.icon,
                        accentColor: info.color,
                        url: platformData.url,
                        nativeUrl: platformData.nativeAppUriMobile
                    ))
                    addedPlatforms.insert(info.displayName)
                    print("✅ 添加平台: \(info.displayName) (key: \(key))")
                } else {
                    print("⏭️ 跳过重复平台: \(info.displayName) (key: \(key))")
                }
            } else {
                // 未知平台也显示出来
                print("⚠️ 未知平台: '\(key)' - 使用默认样式")
                if !addedPlatforms.contains(key.capitalized) {
                    links.append(AppPlatformLink(
                        platformKey: key,
                        displayName: key.capitalized,
                        iconName: "music.note",
                        accentColor: "#888888",
                        url: platformData.url,
                        nativeUrl: platformData.nativeAppUriMobile
                    ))
                    addedPlatforms.insert(key.capitalized)
                }
            }
        }
        
        // 按优先级排序
        links.sort { link1, link2 in
            let priority1 = getPlatformInfo(for: link1.platformKey)?.priority ?? 999
            let priority2 = getPlatformInfo(for: link2.platformKey)?.priority ?? 999
            return priority1 < priority2
        }
        
        print("✅ 最终解析了 \(links.count) 个平台链接（去重后）")
        print("==========================================")

        let albumTitle = response.entitiesByUniqueId.values.first { $0.type == "album" }?.title
        let releaseDate = entity?.releaseDate ?? response.entitiesByUniqueId.values.first { $0.releaseDate != nil }?.releaseDate
        let releaseYear = releaseDate.map { String($0.prefix(4)) }

        // 改进封面图片获取逻辑：优先从主实体获取，如果没有则遍历所有实体查找
        var thumbnailUrl = entity?.thumbnailUrl
        if thumbnailUrl == nil {
            // 尝试从所有实体中找到有封面的
            thumbnailUrl = response.entitiesByUniqueId.values
                .first(where: { $0.thumbnailUrl != nil })?
                .thumbnailUrl
            if thumbnailUrl != nil {
                print("📸 从备用实体获取封面图片")
            }
        } else {
            print("📸 从主实体获取封面图片")
        }

        return SongResult(
            title: entity?.title ?? "未知歌曲",
            artist: entity?.artistName ?? "未知艺术家",
            album: albumTitle,
            releaseYear: releaseYear,
            thumbnailUrl: thumbnailUrl,
            songLinkUrl: response.pageUrl,
            platforms: links
        )
    }
    
    // MARK: - 备用 API（使用多个来源）
    private func fetchFromBackupAPI(url: String, title: String, artist: String, missingSpotify: Bool, missingAppleMusic: Bool) async throws -> [AppPlatformLink]? {
        print("🔄 尝试备用 API 补充...")
        print("   歌曲信息: \(title) - \(artist)")
        
        var backupLinks: [AppPlatformLink] = []
        
        // 方案1: 直接构造链接（基于URL模式）
        if let constructedLinks = constructLinksFromURL(url) {
            print("✅ 通过 URL 模式构造成功")
            backupLinks.append(contentsOf: constructedLinks)
        }
        
        // 方案2: 基于歌曲信息构造搜索链接
        if missingSpotify {
            if let spotifyLink = constructSpotifySearchLink(title: title, artist: artist) {
                backupLinks.append(spotifyLink)
                print("✅ 构造 Spotify 搜索链接")
            }
        }
        
        if missingAppleMusic {
            if let appleMusicLink = constructAppleMusicSearchLink(title: title, artist: artist) {
                backupLinks.append(appleMusicLink)
                print("✅ 构造 Apple Music 搜索链接")
            }
        }
        
        // 方案3: 尝试 Songwhip API（作为最后的尝试）
        if backupLinks.isEmpty {
            return try await fetchFromSongwhip(url: url)
        }
        
        return backupLinks.isEmpty ? nil : backupLinks
    }
    
    // 构造 Spotify 搜索链接
    private func constructSpotifySearchLink(title: String, artist: String) -> AppPlatformLink? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let searchURL = "https://open.spotify.com/search/\(query)"
        
        return AppPlatformLink(
            platformKey: "spotify",
            displayName: "Spotify",
            iconName: "spotify.icon",
            accentColor: "#1DB954",
            url: searchURL,
            nativeUrl: nil
        )
    }
    
    // 构造 Apple Music 搜索链接
    private func constructAppleMusicSearchLink(title: String, artist: String) -> AppPlatformLink? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // Apple Music 搜索 URL 格式
        let searchURL = "https://music.apple.com/search?term=\(query)"
        
        return AppPlatformLink(
            platformKey: "appleMusic",
            displayName: "Apple Music",
            iconName: "applemusic.icon",
            accentColor: "#FC3C44",
            url: searchURL,
            nativeUrl: nil
        )
    }
    
    // 方案1: 基于 URL 模式直接构造跨平台链接
    private func constructLinksFromURL(_ url: String) -> [AppPlatformLink]? {
        var links: [AppPlatformLink] = []
        
        // 如果是 Spotify 链接，尝试构造基本链接
        if url.contains("spotify.com/track/") {
            // 提取 track ID
            if let trackId = extractSpotifyTrackId(from: url) {
                // Spotify 链接已知，可以添加到列表
                links.append(AppPlatformLink(
                    platformKey: "spotify",
                    displayName: "Spotify",
                    iconName: "spotify.icon",
                    accentColor: "#1DB954",
                    url: "https://open.spotify.com/track/\(trackId)",
                    nativeUrl: "spotify:track:\(trackId)"
                ))
                print("✅ 从 URL 提取: Spotify (ID: \(trackId))")
            }
        }
        
        // 如果是 Apple Music 链接
        if url.contains("music.apple.com") || url.contains("geo.music.apple.com") {
            // Apple Music 链接已知
            links.append(AppPlatformLink(
                platformKey: "appleMusic",
                displayName: "Apple Music",
                iconName: "applemusic.icon",
                accentColor: "#FC3C44",
                url: url,
                nativeUrl: nil
            ))
            print("✅ 从 URL 提取: Apple Music")
        }
        
        return links.isEmpty ? nil : links
    }
    
    // 提取 Spotify Track ID
    private func extractSpotifyTrackId(from url: String) -> String? {
        if let range = url.range(of: "track/") {
            let afterTrack = url[range.upperBound...]
            if let questionMark = afterTrack.firstIndex(of: "?") {
                return String(afterTrack[..<questionMark])
            } else {
                return String(afterTrack)
            }
        }
        return nil
    }
    
    // 方案2: Songwhip API
    private func fetchFromSongwhip(url: String) async throws -> [AppPlatformLink]? {
        print("🔄 调用 Songwhip API...")
        
        guard let requestURL = URL(string: "https://songwhip.com/api/") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5 // 5秒超时
        
        let body: [String: String] = ["url": url]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ Songwhip API 请求失败")
            return nil
        }
        
        // 解析响应
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let links = json["links"] as? [String: Any] {
            
            var backupLinks: [AppPlatformLink] = []
            
            // Spotify
            if let spotifyData = links["spotify"] as? [[String: Any]],
               let firstSpotify = spotifyData.first,
               let spotifyUrl = firstSpotify["link"] as? String {
                backupLinks.append(AppPlatformLink(
                    platformKey: "spotify",
                    displayName: "Spotify",
                    iconName: "spotify.icon",
                    accentColor: "#1DB954",
                    url: spotifyUrl,
                    nativeUrl: nil
                ))
                print("✅ Songwhip 找到: Spotify")
            }
            
            // Apple Music
            if let appleMusicData = links["appleMusic"] as? [[String: Any]],
               let firstApple = appleMusicData.first,
               let appleUrl = firstApple["link"] as? String {
                backupLinks.append(AppPlatformLink(
                    platformKey: "appleMusic",
                    displayName: "Apple Music",
                    iconName: "applemusic.icon",
                    accentColor: "#FC3C44",
                    url: appleUrl,
                    nativeUrl: nil
                ))
                print("✅ Songwhip 找到: Apple Music")
            }
            
            // YouTube Music
            if let youtubeData = links["youtube"] as? [[String: Any]],
               let firstYoutube = youtubeData.first,
               let youtubeUrl = firstYoutube["link"] as? String {
                backupLinks.append(AppPlatformLink(
                    platformKey: "youtube",
                    displayName: "YouTube Music",
                    iconName: "youtubemusic.icon",
                    accentColor: "#FF0000",
                    url: youtubeUrl,
                    nativeUrl: nil
                ))
                print("✅ Songwhip 找到: YouTube Music")
            }
            
            return backupLinks.isEmpty ? nil : backupLinks
        }
        
        return nil
    }
    
    // MARK: - 合并结果
    private func mergeResults(primary: SongResult, backup: [AppPlatformLink]) -> SongResult {
        var allLinks = primary.platforms
        var existingPlatforms = Set(primary.platforms.map { $0.displayName })
        
        // 添加备用 API 提供的缺失平台
        for backupLink in backup {
            if !existingPlatforms.contains(backupLink.displayName) {
                allLinks.append(backupLink)
                existingPlatforms.insert(backupLink.displayName)
                print("➕ 从备用 API 添加: \(backupLink.displayName)")
            }
        }
        
        // 重新排序
        allLinks.sort { link1, link2 in
            let priority1 = getPlatformInfo(for: link1.platformKey)?.priority ?? 999
            let priority2 = getPlatformInfo(for: link2.platformKey)?.priority ?? 999
            return priority1 < priority2
        }
        
        print("🎉 合并后共 \(allLinks.count) 个平台")
        
        return SongResult(
            title: primary.title,
            artist: primary.artist,
            album: primary.album,
            releaseYear: primary.releaseYear,
            thumbnailUrl: primary.thumbnailUrl,
            songLinkUrl: primary.songLinkUrl,
            platforms: allLinks
        )
    }
}

// MARK: - Song Result Model

struct SongResult {
    let title: String
    let artist: String
    let album: String?
    let releaseYear: String?
    let thumbnailUrl: String?
    let songLinkUrl: String
    let platforms: [AppPlatformLink]
}
