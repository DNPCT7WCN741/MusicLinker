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

// MARK: - NetEase API Response Models

struct NeteaseSearchResponse: Codable {
    let code: Int
    let result: NeteaseSearchResult?
}

struct NeteaseSearchResult: Codable {
    let songs: [NeteaseSong]?
    let songCount: Int?
}

struct NeteaseSong: Codable {
    let id: Int
    let name: String
    let artists: [NeteaseArtist]
    let album: NeteaseAlbum
    
    enum CodingKeys: String, CodingKey {
        case id, name, artists, album
    }
}

struct NeteaseArtist: Codable {
    let id: Int
    let name: String
}

struct NeteaseAlbum: Codable {
    let id: Int
    let name: String
    let picUrl: String?
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
import Combine

class OdesliService: ObservableObject {
    @Published var isLoading = false
    @Published var result: SongResult?
    @Published var errorMessage: String?
    private var isFetching = false

    private let baseURL = "https://api.song.link/v1-alpha.1/links"
    private let songwhipURL = "https://songwhip.com/"
    private let defaultTimeout: TimeInterval = 8.0

    // CN 模式：Apple Music 链接转为中国区
    var isCNMode: Bool {
        get { UserDefaults.standard.object(forKey: "isCNMode") == nil ? true : UserDefaults.standard.bool(forKey: "isCNMode") }
        set { UserDefaults.standard.set(newValue, forKey: "isCNMode") }
    }
    
    
    // 网易云音乐 API 地址（用户可配置，默认为空表示不使用API）
    private var neteaseAPIBaseURL: String {
        UserDefaults.standard.string(forKey: "neteaseAPIBaseURL") ?? ""
    }
    
    // 是否启用网易云音乐 API
    var isNeteaseAPIEnabled: Bool {
        !neteaseAPIBaseURL.isEmpty && neteaseAPIBaseURL != "none"
    }
    
    // 设置网易云音乐 API 地址
    func setNeteaseAPIBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "neteaseAPIBaseURL")
    }
    
    // 获取当前配置的网易云音乐 API 地址
    func getNeteaseAPIBaseURL() -> String {
        return neteaseAPIBaseURL
    }


    
    // 通过歌名+艺术家搜索全平台链接
    func fetchByTitleArtist(title: String, artist: String) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.result = nil
        }

        print("🎵 识别当前播放: \(title) - \(artist)")

        // Step 1: iTunes Search → 获得 Apple Music 链接
        if let appleMusicURL = await searchITunes(title: title, artist: artist) {
            print("✅ iTunes 找到: \(appleMusicURL)")
            let decoded = appleMusicURL.removingPercentEncoding ?? appleMusicURL
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "?&=+#")
            guard let encoded = decoded.addingPercentEncoding(withAllowedCharacters: allowed),
                  let requestURL = URL(string: "\(baseURL)?url=\(encoded)&userCountry=US&songIfSingle=true") else {
                await buildFallbackResult(title: title, artist: artist)
                return
            }

            guard let (data, response) = try? await data(from: requestURL),
                  let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let odesli = try? JSONDecoder().decode(OdesliResponse.self, from: data) else {
                await buildFallbackResult(title: title, artist: artist)
                return
            }

            var songResult = parseSongResult(from: odesli)
            let hasNetease = songResult.platforms.contains { $0.displayName == "网易云音乐" }
            let hasQQ = songResult.platforms.contains { $0.displayName == "QQ 音乐" }

            if !hasNetease, let neteaseLink = await searchNeteaseByTitleAndArtist(title: title, artist: artist) {
                songResult = mergeResults(primary: songResult, backup: [neteaseLink])
            }
            if !hasQQ, let qqLink = await searchQQByTitleAndArtist(title: title, artist: artist) {
                songResult = mergeResults(primary: songResult, backup: [qqLink])
            }

            await MainActor.run {
                self.result = songResult
                self.isLoading = false
            }
        } else {
            await buildFallbackResult(title: title, artist: artist)
        }
    }

    private func buildFallbackResult(title: String, artist: String) async {
        var platforms: [AppPlatformLink] = []
        if let link = constructSpotifySearchLink(title: title, artist: artist) { platforms.append(link) }
        if let link = constructAppleMusicSearchLink(title: title, artist: artist) { platforms.append(link) }
        if let link = constructNeteaseSearchLink(title: title, artist: artist) { platforms.append(link) }
        if let link = constructQQSearchLink(title: title, artist: artist) { platforms.append(link) }

        await MainActor.run {
            self.result = SongResult(
                title: title, artist: artist, album: nil, releaseYear: nil,
                thumbnailUrl: nil, songLinkUrl: "",
                platforms: platforms
            )
            self.isLoading = false
        }
    }

    func fetchLinks(url: String) async {
        guard !isFetching else { return }
        isFetching = true
        defer { isFetching = false }
        
        // 网易云手机短链 163cn.tv → 跟随重定向
        if url.contains("163cn.tv") {
            await MainActor.run { self.isLoading = true; self.errorMessage = nil; self.result = nil }
            print("🔄 检测到网易云手机短链，解析重定向...")
            if let resolved = await resolveURL(url), resolved.contains("music.163.com") {
                await fetchLinksFromNetease(neteaseURL: resolved)
            } else {
                await MainActor.run {
                    self.errorMessage = "无法解析短链，请使用完整链接"
                    self.isLoading = false
                }
            }
            return
        }

        // 检测到网易云音乐链接，走特殊流程
        if url.contains("music.163.com") || url.contains("y.music.163.com") {
            await fetchLinksFromNetease(neteaseURL: url)
            return
        }
        
        // 检测到 QQ 音乐链接，走特殊流程
        if url.contains("y.qq.com") {
            await fetchLinksFromQQMusic(qqURL: url)
            return
        }
        
        // Apple Music CN 链接：先转 US 区试，400 时回退 CN 原链
        var candidateURLs: [String] = [url]
        if url.contains("music.apple.com/cn") {
            let usURL = url.replacingOccurrences(of: "/cn/", with: "/us/")
            candidateURLs = [usURL, url]   // US 优先，CN 备用
            print("🔄 检测到中国区 Apple Music 链接，先尝试美国区: \(usURL)")
        } else if url.contains("geo.music.apple.com/cn") {
            let usURL = url.replacingOccurrences(of: "geo.music.apple.com/cn", with: "music.apple.com/us")
            candidateURLs = [usURL, url]
            print("🔄 检测到中国区 Apple Music 短链接，先尝试美国区: \(usURL)")
        }

        // URL 作为查询参数值时，必须编码 ?、&、=、# 等字符
        var valueAllowed = CharacterSet.urlQueryAllowed
        valueAllowed.remove(charactersIn: "?&=+#")

        func buildOdesliURL(_ raw: String) -> URL? {
            let decoded = raw.removingPercentEncoding ?? raw
            guard let encoded = decoded.addingPercentEncoding(withAllowedCharacters: valueAllowed) else { return nil }
            return URL(string: "\(baseURL)?url=\(encoded)&userCountry=US&songIfSingle=true")
        }

        // 依次尝试候选链接，首个 200 为准
        var odesliData: Data? = nil
        var processedURL = url
        var lastStatusCode: Int = 0
        for candidate in candidateURLs {
            guard let requestURL = buildOdesliURL(candidate) else { continue }
            print("🌐 正在请求 API: \(requestURL.absoluteString)")
            if let (data, response) = try? await data(from: requestURL),
               let http = response as? HTTPURLResponse {
                print("✅ HTTP 状态码: \(http.statusCode)")
                lastStatusCode = http.statusCode
                if http.statusCode == 200 {
                    odesliData = data
                    processedURL = candidate
                    break
                } else {
                    print("⚠️ \(candidate.contains("/us/") ? "美国区" : "原链接") 返回 \(http.statusCode)，继续尝试下一个...")
                }
            }
        }

        guard let finalData = odesliData else {
            await MainActor.run {
                if lastStatusCode == 429 {
                    self.errorMessage = "请求过于频繁，请稍等片刻再试（Odesli API 限速）"
                } else {
                    self.errorMessage = "无法找到这首歌的信息，请检查链接是否正确"
                }
                self.isLoading = false
            }
            return
        }
        let _ = processedURL  // 供后续日志使用

        // 强制 Apple Music 链接使用 itmss Scheme（打开 Apple Music 应用）
        if processedURL.contains("music.apple.com") || processedURL.contains("geo.music.apple.com") {
            if processedURL.hasPrefix("https://") {
                processedURL = processedURL.replacingOccurrences(of: "https://", with: "itmss://")
            } else if processedURL.hasPrefix("http://") {
                processedURL = processedURL.replacingOccurrences(of: "http://", with: "itmss://")
            } else if !processedURL.hasPrefix("itmss://") {
                processedURL = "itmss://\(processedURL)"
            }
            print("🔄 Apple Music 链接已更新为 itmss Scheme: \(processedURL)")
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.result = nil
        }

        do {
            let odesliResponse = try JSONDecoder().decode(OdesliResponse.self, from: finalData)
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

            // 无论如何，如果没有网易云链接，主动搜索添加
            let hasNetease = songResult.platforms.contains { $0.platformKey == "netease" || $0.displayName == "网易云音乐" }
            if !hasNetease {
                print("🔍 主动搜索网易云音乐链接...")
                if let neteaseLink = await searchNeteaseByTitleAndArtist(title: songResult.title, artist: songResult.artist) {
                    songResult = mergeResults(primary: songResult, backup: [neteaseLink])
                }
            }

            // 如果没有 QQ 音乐链接，主动搜索添加
            let hasQQ = songResult.platforms.contains { $0.platformKey == "qqmusic" || $0.displayName == "QQ 音乐" }
            if !hasQQ {
                print("🔍 主动搜索 QQ 音乐链接...")
                if let qqLink = await searchQQByTitleAndArtist(title: songResult.title, artist: songResult.artist) {
                    songResult = mergeResults(primary: songResult, backup: [qqLink])
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

    // MARK: - QQ 音乐链接特殊处理
    // 流程：QQ音乐链接 → 提取 songmid → 调用官方接口获取歌曲信息 → iTunes 搜索 → Odesli 全平台
    private func fetchLinksFromQQMusic(qqURL: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.result = nil
        }
        
        print("🎵 检测到 QQ 音乐链接，启动专用流程...")
        
        // Step 1: 提取 songmid（如果直接失败，尝试跟随短链重定向）
        var effectiveURL = qqURL
        var extractedMid = extractQQSongMid(from: qqURL)
        if extractedMid == nil {
            print("🔄 直接提取 songmid 失败，尝试解析短链重定向...")
            if let resolved = await resolveURL(qqURL) {
                effectiveURL = resolved
                extractedMid = extractQQSongMid(from: resolved)
            }
        }
        guard let songmid = extractedMid else {
            await MainActor.run {
                self.errorMessage = "无法解析 QQ 音乐链接中的歌曲 ID"
                self.isLoading = false
            }
            return
        }
        let _ = effectiveURL  // 已提取 songmid，effectiveURL 仅供调试
        
        print("🔍 提取到 QQ 音乐 songmid: \(songmid)")
        
        // Step 2: 调用 QQ 音乐官方接口获取歌曲信息
        guard let songInfo = await fetchQQSongDetail(songmid: songmid) else {
            await MainActor.run {
                self.errorMessage = "无法获取歌曲信息，请检查网络连接"
                self.isLoading = false
            }
            return
        }
        
        let title = songInfo.title
        let artist = songInfo.artist
        let thumbnailUrl = songInfo.thumbnailUrl
        print("✅ 获取到歌曲信息: \(title) - \(artist)")
        
        // Step 3: iTunes 搜索获得 Apple Music 链接
        if let appleMusicURL = await searchITunes(title: title, artist: artist) {
            print("🎵 iTunes 找到链接，传给 Odesli...")
            
            // Step 4: 把 Apple Music 链接传给 Odesli 获取全平台结果
            let decodedAM1 = appleMusicURL.removingPercentEncoding ?? appleMusicURL
            var amAllowed1 = CharacterSet.urlQueryAllowed
            amAllowed1.remove(charactersIn: "?&=+#")
            if let encodedAM = decodedAM1.addingPercentEncoding(withAllowedCharacters: amAllowed1),
               let requestURL = URL(string: "\(baseURL)?url=\(encodedAM)&userCountry=US&songIfSingle=true"),
               let (data, response) = try? await data(from: requestURL),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let odesliResponse = try? JSONDecoder().decode(OdesliResponse.self, from: data) {
                
                let songResult = parseSongResult(from: odesliResponse)
                
                // 插入精确的 QQ 音乐链接
                let qqLink = AppPlatformLink(
                    platformKey: "qqmusic",
                    displayName: "QQ 音乐",
                    iconName: "qqmusic.icon",
                    accentColor: "#31C27C",
                    url: "https://y.qq.com/n/ryqq/songDetail/\(songmid)",
                    nativeUrl: "qqmusic://playSong?songmid=\(songmid)"
                )
                var platforms = songResult.platforms.filter { $0.displayName != "QQ 音乐" }
                platforms.append(qqLink)
                
                // 如果没有网易云链接，主动搜索添加
                let hasNeteaseFromQQ = platforms.contains { $0.platformKey == "netease" || $0.displayName == "网易云音乐" }
                if !hasNeteaseFromQQ, let neteaseSearchLink = await searchNeteaseByTitleAndArtist(title: title, artist: artist) {
                    platforms.append(neteaseSearchLink)
                }
                
                platforms.sort {
                    let p1 = getPlatformInfo(for: $0.platformKey)?.priority ?? 999
                    let p2 = getPlatformInfo(for: $1.platformKey)?.priority ?? 999
                    return p1 < p2
                }
                
                await MainActor.run {
                    self.result = SongResult(
                        title: songResult.title.isEmpty ? title : songResult.title,
                        artist: songResult.artist.isEmpty ? artist : songResult.artist,
                        album: songResult.album,
                        releaseYear: songResult.releaseYear,
                        thumbnailUrl: songResult.thumbnailUrl ?? thumbnailUrl,
                        songLinkUrl: songResult.songLinkUrl,
                        platforms: platforms
                    )
                    self.isLoading = false
                }
                return
            }
        }
        
        // 回退：显示基本结果（有正确歌曲信息 + QQ 音乐链接）
        let qqLink = AppPlatformLink(
            platformKey: "qqmusic",
            displayName: "QQ 音乐",
            iconName: "qqmusic.icon",
            accentColor: "#31C27C",
            url: "https://y.qq.com/n/ryqq/songDetail/\(songmid)",
            nativeUrl: "qqmusic://playSong?songmid=\(songmid)"
        )
        var platforms = [qqLink]
        if let spotifyLink = constructSpotifySearchLink(title: title, artist: artist) { platforms.append(spotifyLink) }
        if let amLink = constructAppleMusicSearchLink(title: title, artist: artist) { platforms.append(amLink) }
        if let neteaseLink = await searchNeteaseByTitleAndArtist(title: title, artist: artist) { platforms.append(neteaseLink) }
        
        await MainActor.run {
            self.result = SongResult(
                title: title, artist: artist, album: nil, releaseYear: nil,
                thumbnailUrl: thumbnailUrl, songLinkUrl: qqURL, platforms: platforms
            )
            self.isLoading = false
        }
    }
    
    // 从 QQ 音乐 URL 提取 songmid
    private func extractQQSongMid(from url: String) -> String? {
        // 格式：y.qq.com/n/ryqq/songDetail/SONGMID
        if let range = url.range(of: "songDetail/") {
            let after = url[range.upperBound...]
            let mid = after.components(separatedBy: CharacterSet(charactersIn: "?#&/ ")).first ?? ""
            return mid.isEmpty ? nil : mid
        }
        // 格式：y.qq.com/n/ryqq/song?songmid=SONGMID
        if let range = url.range(of: "songmid=") {
            let after = url[range.upperBound...]
            let mid = after.components(separatedBy: CharacterSet(charactersIn: "?#&/ ")).first ?? ""
            return mid.isEmpty ? nil : mid
        }
        return nil
    }
    
    // 调用 QQ 音乐官方接口获取歌曲信息
    private func fetchQQSongDetail(songmid: String) async -> (title: String, artist: String, thumbnailUrl: String?)? {
        guard let url = URL(string: "https://c.y.qq.com/v8/fcg-bin/fcg_play_single_song.fcg?songmid=\(songmid)&format=json") else { return nil }
        
        print("📡 调用 QQ 音乐官方接口...")
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]],
               let song = dataArr.first {
                
                let songName = song["name"] as? String ?? ""
                let singers = song["singer"] as? [[String: Any]] ?? []
                let artistName = singers.compactMap { $0["name"] as? String }.joined(separator: ", ")
                
                // 封面：y.gtimg.cn/music/photo_new/T002R500x500M000{pmid}.jpg
                var picUrl: String? = nil
                if let album = song["album"] as? [String: Any],
                   let pmid = album["pmid"] as? String, !pmid.isEmpty {
                    picUrl = "https://y.gtimg.cn/music/photo_new/T002R500x500M000\(pmid).jpg"
                }
                
                if !songName.isEmpty {
                    print("✅ QQ 官方接口获取: \(songName) - \(artistName)")
                    return (songName, artistName, picUrl)
                }
            }
        } catch {
            print("⚠️ QQ 音乐官方接口失败: \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - 网易云音乐链接特殊处理
    // 流程：网易云链接 → 调用网易云API获取歌曲信息 → 用歌曲信息搜索Odesli获取其他平台链接
    private func fetchLinksFromNetease(neteaseURL: String) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.result = nil
        }
        
        print("🎵 检测到网易云音乐链接，启动专用流程...")
        
        // Step 1: 提取歌曲ID
        guard let songId = extractNeteaseSongId(from: neteaseURL) else {
            await MainActor.run {
                self.errorMessage = "无法解析网易云音乐链接中的歌曲 ID"
                self.isLoading = false
            }
            return
        }
        
        print("🔍 提取到网易云歌曲 ID: \(songId)")
        
        // Step 2: 调用网易云官方接口获取歌曲信息（无需第三方API）
        guard let songInfo = await fetchNeteaseSOngDetail(songId: songId) else {
            await MainActor.run {
                self.errorMessage = "无法获取歌曲信息，请检查网络连接"
                self.isLoading = false
            }
            return
        }
        
        let title = songInfo.title
        let artist = songInfo.artist
        let thumbnailUrl = songInfo.thumbnailUrl
        print("✅ 获取到歌曲信息: \(title) - \(artist)")
        
        // Step 3: 用歌名+艺术家搜索 iTunes，获得 Apple Music 链接
        if let appleMusicURL = await searchITunes(title: title, artist: artist) {
            print("🎵 iTunes 找到链接: \(appleMusicURL)，传给 Odesli...")
            
            // Step 4: 把 Apple Music 链接传给 Odesli 获取全平台结果
            let decodedAM2 = appleMusicURL.removingPercentEncoding ?? appleMusicURL
            var amAllowed2 = CharacterSet.urlQueryAllowed
            amAllowed2.remove(charactersIn: "?&=+#")
            if let encodedAM = decodedAM2.addingPercentEncoding(withAllowedCharacters: amAllowed2),
               let requestURL = URL(string: "\(baseURL)?url=\(encodedAM)&userCountry=US&songIfSingle=true"),
               let (data, response) = try? await data(from: requestURL),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let odesliResponse = try? JSONDecoder().decode(OdesliResponse.self, from: data) {
                
                let songResult = parseSongResult(from: odesliResponse)
                
                // 插入精确的网易云链接
                let neteaseLink = AppPlatformLink(
                    platformKey: "netease",
                    displayName: "网易云音乐",
                    iconName: "netease.icon",
                    accentColor: "#E60026",
                    url: "https://music.163.com/#/song?id=\(songId)",
                    nativeUrl: "orpheus://song/\(songId)"
                )
                var platforms = songResult.platforms.filter { $0.displayName != "网易云音乐" }
                platforms.append(neteaseLink)
                
                // 如果没有 QQ 音乐链接，主动搜索添加
                let hasQQFromNetease = platforms.contains { $0.platformKey == "qqmusic" || $0.displayName == "QQ 音乐" }
                if !hasQQFromNetease, let qqSearchLink = await searchQQByTitleAndArtist(title: title, artist: artist) {
                    platforms.append(qqSearchLink)
                }
                
                platforms.sort {
                    let p1 = getPlatformInfo(for: $0.platformKey)?.priority ?? 999
                    let p2 = getPlatformInfo(for: $1.platformKey)?.priority ?? 999
                    return p1 < p2
                }
                
                await MainActor.run {
                    self.result = SongResult(
                        title: songResult.title.isEmpty ? title : songResult.title,
                        artist: songResult.artist.isEmpty ? artist : songResult.artist,
                        album: songResult.album,
                        releaseYear: songResult.releaseYear,
                        thumbnailUrl: songResult.thumbnailUrl ?? thumbnailUrl,
                        songLinkUrl: songResult.songLinkUrl,
                        platforms: platforms
                    )
                    self.isLoading = false
                }
                return
            }
        }
        
        // Step 5: Odesli 也失败了，展示基本结果（有正确歌曲信息）
        await buildNeteaseOnlyResult(songId: songId, title: title, artist: artist, thumbnailUrl: thumbnailUrl, neteaseURL: neteaseURL)
    }
    
    // iTunes 搜索获取 Apple Music 链接（免费，无需 API Key）
    private func searchITunes(title: String, artist: String) async -> String? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&limit=10") else {
            return nil
        }
        
        print("🔍 iTunes 搜索: \(query)")
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               !results.isEmpty {
                let targetArtist = normalizeArtistName(artist)
                let targetTitle = normalizeSongTitle(title)
                var bestMatch: [String: Any]? = nil
                var bestScore = 0

                for result in results {
                    guard let trackName = result["trackName"] as? String,
                          let artistName = result["artistName"] as? String,
                          let trackViewUrl = result["trackViewUrl"] as? String else {
                        continue
                    }
                    let resultTitle = normalizeSongTitle(trackName)
                    let resultArtist = normalizeArtistName(artistName)

                    var score = 0
                    if resultTitle == targetTitle { score += 50 }
                    else if resultTitle.contains(targetTitle) || targetTitle.contains(resultTitle) { score += 20 }
                    if resultArtist == targetArtist { score += 50 }
                    else if resultArtist.contains(targetArtist) || targetArtist.contains(resultArtist) { score += 30 }
                    else {
                        let targetParts = targetArtist.split(separator: " ").map(String.init)
                        let matchedParts = targetParts.filter { resultArtist.contains($0) }
                        score += min(matchedParts.count * 20, 40)
                    }

                    if score > bestScore {
                        bestScore = score
                        bestMatch = result
                    }
                }

                if let match = bestMatch,
                   bestScore >= 80,
                   let trackViewUrl = match["trackViewUrl"] as? String {
                    var cleanURL = trackViewUrl.components(separatedBy: "&uo=").first ?? trackViewUrl
                    cleanURL = standardizeAppleMusicURL(cleanURL)
                    print("✅ iTunes 找到: \(cleanURL) (score=\(bestScore))")
                    return cleanURL
                }
                print("⚠️ iTunes 搜索未找到足够匹配的结果，最佳分数=\(bestScore)")
            }
        } catch {
            print("⚠️ iTunes 搜索失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // 获取网易云歌曲详情（使用官方网页接口，无需第三方API）
    private func fetchNeteaseSOngDetail(songId: String) async -> (title: String, artist: String, thumbnailUrl: String?)? {
        // 首先尝试官方接口
        if let result = await queryNeteaseOfficial(songId: songId) {
            return result
        }
        
        // 如果用户配置了自定义API，也尝试一下
        if isNeteaseAPIEnabled {
            if let result = await querySongDetail(from: neteaseAPIBaseURL, songId: songId) {
                return result
            }
        }
        
        return nil
    }
    
    // 调用网易云官方网页接口
    private func queryNeteaseOfficial(songId: String) async -> (title: String, artist: String, thumbnailUrl: String?)? {
        guard let url = URL(string: "https://music.163.com/api/song/detail?ids=%5B\(songId)%5D") else { return nil }
        
        print("📡 调用网易云官方接口...")
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let songs = json["songs"] as? [[String: Any]],
               let song = songs.first {
                
                let songName = song["name"] as? String ?? ""
                var artistName = ""
                if let artists = song["artists"] as? [[String: Any]] {
                    artistName = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
                }
                var picUrl: String? = nil
                if let album = song["album"] as? [String: Any] {
                    picUrl = album["picUrl"] as? String
                }
                
                if !songName.isEmpty {
                    print("✅ 官方接口获取: \(songName) - \(artistName)")
                    return (songName, artistName, picUrl)
                }
            }
        } catch {
            print("⚠️ 官方接口失败: \(error.localizedDescription)")
        }
        return nil
    }
    
    // 调用用户自定义 API（与网易云API Enhanced格式兼容）
    private func querySongDetail(from host: String, songId: String) async -> (title: String, artist: String, thumbnailUrl: String?)? {
        guard let url = URL(string: "\(host)/song/detail?ids=\(songId)") else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 6.0
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let songs = json["songs"] as? [[String: Any]], let song = songs.first {
                let songName = song["name"] as? String ?? ""
                var artistName = ""
                if let ar = song["ar"] as? [[String: Any]] {
                    artistName = ar.compactMap { $0["name"] as? String }.joined(separator: ", ")
                } else if let artists = song["artists"] as? [[String: Any]] {
                    artistName = artists.compactMap { $0["name"] as? String }.joined(separator: ", ")
                }
                var picUrl: String? = nil
                if let al = song["al"] as? [String: Any] { picUrl = al["picUrl"] as? String }
                else if let album = song["album"] as? [String: Any] { picUrl = album["picUrl"] as? String }
                if !songName.isEmpty { return (songName, artistName, picUrl) }
            }
        } catch { }
        return nil
    }

    private func buildNeteaseOnlyResult(songId: String, title: String, artist: String, thumbnailUrl: String?, neteaseURL: String) async {
        var platforms: [AppPlatformLink] = [
            AppPlatformLink(
                platformKey: "netease",
                displayName: "网易云音乐",
                iconName: "netease.icon",
                accentColor: "#E60026",
                url: "https://music.163.com/#/song?id=\(songId)",
                nativeUrl: "orpheus://song/\(songId)"
            )
        ]
        
        // 附加搜索链接作为备选
        if let spotifyLink = constructSpotifySearchLink(title: title, artist: artist) {
            platforms.append(spotifyLink)
        }
        if let appleMusicLink = constructAppleMusicSearchLink(title: title, artist: artist) {
            platforms.append(appleMusicLink)
        }
        if let qqLink = await searchQQByTitleAndArtist(title: title, artist: artist) {
            platforms.append(qqLink)
        }
        
        await MainActor.run {
            self.result = SongResult(
                title: title,
                artist: artist,
                album: nil,
                releaseYear: nil,
                thumbnailUrl: thumbnailUrl,
                songLinkUrl: neteaseURL,
                platforms: platforms
            )
            self.isLoading = false
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
        case "netease", "neteasemusic", "cloudmusic":
            return ("网易云音乐", "netease.icon", "#E60026", 4)
        case "qqmusic", "qq", "tencentmusic":
            return ("QQ 音乐", "qqmusic.icon", "#31C27C", 5)
        case "tidal":
            return ("Tidal", "tidal.icon", "#000000", 6)
        case "deezer":
            return ("Deezer", "deezer.icon", "#A238FF", 7)
        case "amazon", "amazonmusic", "amazonstore":
            return ("Amazon Music", "amazonmusic.icon", "#00A8E1", 8)
        case "pandora":
            return ("Pandora", "pandora.icon", "#3668FF", 9)
        case "soundcloud":
            return ("SoundCloud", "soundcloud.icon", "#FF5500", 10)
        case "napster":
            return ("Napster", "napster.icon", "#0D0D0D", 10)
        case "yandex", "yandexmusic":
            return ("Yandex Music", "yandex.icon", "#FFCC00", 11)
        case "anghami":
            return ("Anghami", "anghami.icon", "#A020F0", 12)
        case "boomplay":
            return ("Boomplay", "boomplay.icon", "#FF6B35", 13)
        case "audius":
            return ("Audius", "audius.icon", "#CC0FE0", 14)
        case "spinrilla":
            return ("Spinrilla", "spinrilla.icon", "#00D1FF", 15)
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
                    var linkURL = platformData.url

                    // 如果 CN 模式开启且链接是 geo.music.apple.com（短链/区域跳转），则跳过显示该链接
                    if isCNMode && (key == "appleMusic" || key == "itunes") && linkURL.contains("geo.music.apple.com") {
                        print("⏭️ CN 模式：跳过 geo.music.apple.com 链接（key: \(key)）")
                        continue
                    }
                    
                    // Apple Music 链接标准化：所有 iTunes 格式转为 Apple Music（全局）
                    if key == "appleMusic" || key == "itunes" {
                        linkURL = standardizeAppleMusicURL(linkURL)
                    }
                    
                    // CN 模式下转为中国区
                    if isCNMode && (key == "appleMusic" || key == "itunes") {
                        linkURL = convertAppleMusicToCN(linkURL)
                    }
                    
                    // 平台级别艺术家校验：如果该平台对应的实体（entityUniqueId）与主实体艺术家不匹配，则跳过
                    let platformEntityId = platformData.entityUniqueId
                    if let pEntity = response.entitiesByUniqueId[platformEntityId] {
                        let mainArtist = normalizeArtistName(entity?.artistName ?? "")
                        let platArtist = normalizeArtistName(pEntity.artistName ?? "")
                        var artistMatch = false
                        if !mainArtist.isEmpty && !platArtist.isEmpty {
                            if platArtist.contains(mainArtist) || mainArtist.contains(platArtist) {
                                artistMatch = true
                            } else {
                                // 部分词匹配
                                let mainParts = mainArtist.split(separator: " ").map(String.init)
                                let matched = mainParts.contains { platArtist.contains($0) }
                                if matched { artistMatch = true }
                            }
                        } else {
                            // 任一为空时不做严格过滤
                            artistMatch = true
                        }

                        if !artistMatch {
                            print("⏭️ 跳过平台（艺术家不匹配）: \(info.displayName) - 平台艺术家=\(pEntity.artistName ?? "")，主实体艺术家=\(entity?.artistName ?? "")")
                            continue
                        }
                    }

                    // CN 模式下强制 https URL（Apple Music 的 universal link 会直接打开 App）
                    // 非 CN 模式使用 itmss:// 原生 scheme
                    var native = platformData.nativeAppUriMobile
                    if key == "appleMusic" || key == "itunes" {
                        native = isCNMode ? nil : appleMusicToItmss(linkURL)
                    }
                    links.append(AppPlatformLink(
                        platformKey: key,
                        displayName: info.displayName,
                        iconName: info.icon,
                        accentColor: info.color,
                        url: linkURL,
                        nativeUrl: native
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

        // 改进封面图片获取逻辑：在所有实体中选择最合适的封面
        var thumbnailUrl: String? = nil
        var bestScore = 0
        func scoreEntity(_ e: MusicEntity) -> Int {
            let w = e.thumbnailWidth ?? 0
            let h = e.thumbnailHeight ?? 0
            if w > 0 && h > 0 { return w * h }
            if w > 0 { return w * 100 }
            return 1
        }

        // 常见占位图或不合格图片的关键词，用于排除
        let placeholderPatterns = ["default", "image_not_available", "placeholder", "2a96cbd8b46e442fc41c2b86b821562f.png", "fastly.net/i/u/"]

        // 优先尝试主实体（如果存在且非占位图）
        if let main = entity, let t = main.thumbnailUrl, !placeholderPatterns.contains(where: { t.contains($0) }) {
            thumbnailUrl = t
            bestScore = scoreEntity(main)
            print("📸 从主实体获取封面图片（首选）")
        }

        // 遍历所有实体，挑选分辨率最高且非占位图的图片
        for e in response.entitiesByUniqueId.values {
            guard let t = e.thumbnailUrl else { continue }
            if placeholderPatterns.contains(where: { t.contains($0) }) { continue }
            let s = scoreEntity(e)
            if s > bestScore {
                bestScore = s
                thumbnailUrl = t
            }
        }

        if thumbnailUrl != nil {
            print("📸 从实体集合中选择最佳封面")
        } else {
            // 回退：任意可用封面（可能是占位图）
            thumbnailUrl = response.entitiesByUniqueId.values.first(where: { $0.thumbnailUrl != nil })?.thumbnailUrl
            if thumbnailUrl != nil { print("📸 回退到首个可用封面（可能为占位图）") }
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
    
    /// 将 Apple Music 链接转为中国区（/us/ → /cn/，或替换其他地区代码）
    private func convertAppleMusicToCN(_ url: String) -> String {
        // 先统一为 music.apple.com（iTunes → Apple Music）
        var result = standardizeAppleMusicURL(url)
        
        // 匹配 music.apple.com 的地区代码并替换为 cn
        let regionPattern = #"(music\.apple\.com/)([a-z]{2})(/)"#
        if let regex = try? NSRegularExpression(pattern: regionPattern),
           let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           match.numberOfRanges == 4,
           let range = Range(match.range(at: 0), in: result) {
            let prefix = result[Range(match.range(at: 1), in: result)!]
            let suffix = result[Range(match.range(at: 3), in: result)!]
            result = result.replacingCharacters(in: range, with: "\(prefix)cn\(suffix)")
        }
        return result
    }
    
    /// 统一将 iTunes 链接转换为 Apple Music 格式（全局方法）
    private func standardizeAppleMusicURL(_ url: String) -> String {
        // 使用正则匹配任何 iTunes 域名并替换为 Apple Music
        let pattern = #"itunes\.apple\.com"#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(url.startIndex..., in: url)
            return regex.stringByReplacingMatches(in: url, options: [], range: range, withTemplate: "music.apple.com")
        }
        return url.replacingOccurrences(of: "itunes.apple.com", with: "music.apple.com")
    }

    /// 将 Apple Music 网页链接转换为 itmss:// Scheme（用于在 Apple Music 应用中打开）
    private func appleMusicToItmss(_ url: String) -> String {
        var result = standardizeAppleMusicURL(url)
        if result.hasPrefix("https://") {
            return result.replacingOccurrences(of: "https://", with: "itmss://")
        } else if result.hasPrefix("http://") {
            return result.replacingOccurrences(of: "http://", with: "itmss://")
        } else if !result.hasPrefix("itmss://") {
            return "itmss://\(result)"
        }
        return result
    }

    // MARK: - 备用 API（使用多个来源）
    private func fetchFromBackupAPI(url: String, title: String, artist: String, missingSpotify: Bool, missingAppleMusic: Bool) async throws -> [AppPlatformLink]? {        print("🔄 尝试备用 API 补充...")
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
        
        // 方案3: 尝试 Songwhip API（如果前面的方案都没有结果）
        if backupLinks.isEmpty {
            if let songwhipLinks = try await fetchFromSongwhip(url: url) {
                backupLinks.append(contentsOf: songwhipLinks)
            }
        }
        
        // 方案4: 通过网易云官方搜索接口获取精确直链
        if let neteaseDirectLink = await searchNeteaseByTitleAndArtist(title: title, artist: artist) {
            backupLinks.append(neteaseDirectLink)
            print("✅ 网易云直接搜索获取精确链接")
        } else if let neteaseAPILink = await searchNeteaseAPI(title: title, artist: artist) {
            backupLinks.append(neteaseAPILink)
            print("✅ 使用网易云第三方 API 获取链接")
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
    
    // 构造网易云音乐搜索链接
    private func constructNeteaseSearchLink(title: String, artist: String) -> AppPlatformLink? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        // 网易云音乐搜索 URL 格式
        let searchURL = "https://music.163.com/#/search/m/?s=\(query)"
        
        return AppPlatformLink(
            platformKey: "netease",
            displayName: "网易云音乐",
            iconName: "netease.icon",
            accentColor: "#E60026",
            url: searchURL,
            nativeUrl: "orpheuswidget://search?keyword=\(query)"  // 网易云音乐 App URL Scheme
        )
    }
    
    // MARK: - 网易云音乐 API 调用

    /// 通过歌名+艺术家直接调用网易云官方网页搜索接口，返回精确直链（无需认证）
    private func searchNeteaseByTitleAndArtist(title: String, artist: String) async -> AppPlatformLink? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&limit=5&offset=0") else { return nil }

        print("🔍 网易云直接搜索: \(query)")

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let result = json["result"] as? [String: Any],
                  let songs = result["songs"] as? [[String: Any]],
                  !songs.isEmpty else {
                print("⚠️ 网易云搜索无结果")
                return nil
            }

            // 选出最匹配的结果，优先保证艺术家与歌曲名称同时匹配
            guard let bestSong = selectBestNeteaseSong(from: songs, title: title, artist: artist) else {
                print("⚠️ 网易云搜索未找到足够匹配的结果")
                return nil
            }

            guard let songId = bestSong["id"] as? Int else { return nil }
            let songName = bestSong["name"] as? String ?? title
            print("✅ 网易云搜索找到: \(songName) (ID: \(songId))")

            return AppPlatformLink(
                platformKey: "netease",
                displayName: "网易云音乐",
                iconName: "netease.icon",
                accentColor: "#E60026",
                url: "https://music.163.com/#/song?id=\(songId)",
                nativeUrl: "orpheus://song/\(songId)"
            )
        } catch {
            print("⚠️ 网易云搜索失败: \(error.localizedDescription)")
            return nil
        }
    }

    // 通过网易云音乐 API 搜索歌曲
    private func searchNeteaseAPI(title: String, artist: String) async -> AppPlatformLink? {
        // 如果未启用 API，直接返回 nil
        guard isNeteaseAPIEnabled else {
            print("ℹ️ 网易云 API 未启用，将使用搜索链接")
            return nil
        }
        
        let keywords = "\(title) \(artist)"
        guard let encodedKeywords = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(neteaseAPIBaseURL)/cloudsearch?keywords=\(encodedKeywords)&type=1&limit=10") else {
            print("❌ 网易云 API URL 构造失败")
            return nil
        }
        
        print("🌐 正在调用网易云 API: \(requestURL.absoluteString)")
        
        do {
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 5.0  // 5秒超时，避免等待太久
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("❌ 网易云 API HTTP 错误")
                return nil
            }
            
            let searchResponse = try JSONDecoder().decode(NeteaseSearchResponse.self, from: data)
            
            guard searchResponse.code == 200,
                  let songs = searchResponse.result?.songs,
                  let bestSong = selectBestNeteaseSong(from: songs, title: title, artist: artist) else {
                print("⚠️ 网易云 API 未返回匹配结果")
                return nil
            }
            
            let songId = bestSong.id
            let neteaseURL = "https://music.163.com/#/song?id=\(songId)"
            let nativeURL = "orpheus://song/\(songId)"
            
            print("✅ 网易云 API 找到歌曲: \(bestSong.name) (ID: \(songId))")
            
            return AppPlatformLink(
                platformKey: "netease",
                displayName: "网易云音乐",
                iconName: "netease.icon",
                accentColor: "#E60026",
                url: neteaseURL,
                nativeUrl: nativeURL
            )
        } catch {
            print("⚠️ 网易云 API 调用失败: \(error.localizedDescription)")
            return nil
        }
    }

    private func normalizeSearchText(_ text: String) -> String {
        let lower = text.lowercased().folding(options: .diacriticInsensitive, locale: .current)
        let stripped = lower.replacingOccurrences(of: #"[\p{P}\p{S}]"#, with: " ", options: .regularExpression)
        let squashed = stripped.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        return squashed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeSongTitle(_ title: String) -> String {
        let removedExtras = title.replacingOccurrences(of: #"\s*[\(\[\{].*?[\)\]\}]"#, with: "", options: .regularExpression)
        return normalizeSearchText(removedExtras)
    }

    private func normalizeArtistName(_ artist: String) -> String {
        return normalizeSearchText(artist)
    }

    private func selectBestNeteaseSong(from songs: [NeteaseSong], title: String, artist: String) -> NeteaseSong? {
        let titleNorm = normalizeSongTitle(title)
        let artistNorm = normalizeArtistName(artist)
        var bestSong: NeteaseSong? = nil
        var bestScore = 0

        for song in songs {
            let songTitle = normalizeSongTitle(song.name)
            let songArtistNames = song.artists.map { normalizeArtistName($0.name) }.joined(separator: " ")
            
            var score = 0
            if songTitle == titleNorm { score += 50 }
            else if songTitle.contains(titleNorm) || titleNorm.contains(songTitle) { score += 20 }

            if !artistNorm.isEmpty {
                if songArtistNames.contains(artistNorm) { score += 50 }
                else {
                    let artistParts = artistNorm.split(separator: " ").map(String.init)
                    let matchedParts = artistParts.filter { songArtistNames.contains($0) }
                    score += min(matchedParts.count * 20, 40)
                }
            }

            if score > bestScore {
                bestScore = score
                bestSong = song
            }
        }

        // 如果提供了艺术家名，确保最终候选至少在艺术家上有匹配（防止仅歌名相同但艺术家不同的误匹配）
        if !artistNorm.isEmpty {
            if let chosen = bestSong {
                let songArtistNames = chosen.artists.map { normalizeArtistName($0.name) }.joined(separator: " ")
                let fullMatch = songArtistNames.contains(artistNorm)
                let partialMatch = artistNorm.split(separator: " ").map(String.init).contains { songArtistNames.contains($0) }
                if !fullMatch && !partialMatch {
                    return nil
                }
            } else {
                return nil
            }
        }

        guard bestScore >= 50 else { return nil }
        return bestSong
    }

    private func selectBestNeteaseSong(from songs: [[String: Any]], title: String, artist: String) -> [String: Any]? {
        let titleNorm = normalizeSongTitle(title)
        let artistNorm = normalizeArtistName(artist)
        var bestSong: [String: Any]? = nil
        var bestScore = 0

        for song in songs {
            let songTitle = normalizeSongTitle(song["name"] as? String ?? "")
            let songArtists = (song["artists"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }
                .map(normalizeArtistName)
                .joined(separator: " ")
            
            var score = 0
            if songTitle == titleNorm { score += 50 }
            else if songTitle.contains(titleNorm) || titleNorm.contains(songTitle) { score += 20 }

            if !artistNorm.isEmpty {
                if songArtists.contains(artistNorm) { score += 50 }
                else {
                    let artistParts = artistNorm.split(separator: " ").map(String.init)
                    let matchedParts = artistParts.filter { songArtists.contains($0) }
                    score += min(matchedParts.count * 20, 40)
                }
            }

            if score > bestScore {
                bestScore = score
                bestSong = song
            }
        }

        // 如果提供了艺术家名，确保最终候选至少在艺术家上有匹配
        if !artistNorm.isEmpty {
            if let chosen = bestSong {
                let songArtists = (chosen["artists"] as? [[String: Any]] ?? [])
                    .compactMap { $0["name"] as? String }
                    .map(normalizeArtistName)
                    .joined(separator: " ")
                let fullMatch = songArtists.contains(artistNorm)
                let partialMatch = artistNorm.split(separator: " ").map(String.init).contains { songArtists.contains($0) }
                if !fullMatch && !partialMatch {
                    return nil
                }
            } else {
                return nil
            }
        }

        guard bestScore >= 50 else { return nil }
        return bestSong
    }

    /// 通过歌名+艺术家搜索 QQ 音乐，返回精确直链（无需认证）
    private func searchQQByTitleAndArtist(title: String, artist: String) async -> AppPlatformLink? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?n=5&p=1&w=\(encoded)&format=json&cr=1&aggr=1&flag_qc=0") else { return nil }

        print("🔍 QQ音乐搜索: \(query)")

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("https://y.qq.com", forHTTPHeaderField: "Referer")
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return constructQQSearchLink(title: title, artist: artist)
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataObj = json["data"] as? [String: Any],
                  let songObj = dataObj["song"] as? [String: Any],
                  let list = songObj["list"] as? [[String: Any]],
                  !list.isEmpty else {
                print("⚠️ QQ音乐搜索无结果，使用搜索链接")
                return constructQQSearchLink(title: title, artist: artist)
            }

            // 优先找艺术家名包含匹配的结果；如果没有艺术家匹配，则不返回直链（避免只匹配到同名但不同作者的歌曲）
            let artistLower = artist.lowercased()
            var matchedSong: [String: Any]? = nil
            for song in list {
                let singers = song["singer"] as? [[String: Any]] ?? []
                let singerNames = singers.compactMap { $0["name"] as? String }.joined(separator: " ").lowercased()
                if !artistLower.isEmpty && singerNames.contains(artistLower) {
                    matchedSong = song
                    break
                }
            }

            // 如果没有找到带有艺术家匹配的结果，则回退为搜索链接
            guard let bestSong = matchedSong ?? (artist.isEmpty ? list.first : nil) else {
                print("⚠️ QQ音乐搜索未找到艺术家匹配，使用搜索链接")
                return constructQQSearchLink(title: title, artist: artist)
            }

            guard let songmid = bestSong["songmid"] as? String, !songmid.isEmpty else {
                return constructQQSearchLink(title: title, artist: artist)
            }
            let songName = bestSong["songname"] as? String ?? title
            print("✅ QQ音乐搜索找到: \(songName) (mid: \(songmid))")

            return AppPlatformLink(
                platformKey: "qqmusic",
                displayName: "QQ 音乐",
                iconName: "qqmusic.icon",
                accentColor: "#31C27C",
                url: "https://y.qq.com/n/ryqq/songDetail/\(songmid)",
                nativeUrl: "qqmusic://playSong?songmid=\(songmid)"
            )
        } catch {
            print("⚠️ QQ音乐搜索失败: \(error.localizedDescription)")
            return constructQQSearchLink(title: title, artist: artist)
        }
    }

    private func constructQQSearchLink(title: String, artist: String) -> AppPlatformLink? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return AppPlatformLink(
            platformKey: "qqmusic",
            displayName: "QQ 音乐",
            iconName: "qqmusic.icon",
            accentColor: "#31C27C",
            url: "https://y.qq.com/n/ryqq/search?w=\(query)",
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
        
        // 如果是 Apple Music 或 iTunes 链接
        if url.contains("music.apple.com") || url.contains("geo.music.apple.com") || url.contains("itunes.apple.com") {
            let appleMusicUrl = standardizeAppleMusicURL(url)
            
            links.append(AppPlatformLink(
                platformKey: "appleMusic",
                displayName: "Apple Music",
                iconName: "applemusic.icon",
                accentColor: "#FC3C44",
                url: appleMusicUrl,
                nativeUrl: nil
            ))
            print("✅ 从 URL 提取: Apple Music")
        }
        
        // 如果是网易云音乐链接
        if url.contains("music.163.com") || url.contains("y.music.163.com") {
            // 网易云音乐链接已知
            if let songId = extractNeteaseSongId(from: url) {
                let neteaseURL = "https://music.163.com/#/song?id=\(songId)"
                let nativeURL = "orpheus://song/\(songId)"
                links.append(AppPlatformLink(
                    platformKey: "netease",
                    displayName: "网易云音乐",
                    iconName: "netease.icon",
                    accentColor: "#E60026",
                    url: neteaseURL,
                    nativeUrl: nativeURL
                ))
                print("✅ 从 URL 提取: 网易云音乐 (ID: \(songId))")
            } else {
                // 如果无法提取ID，仍然添加原始链接
                links.append(AppPlatformLink(
                    platformKey: "netease",
                    displayName: "网易云音乐",
                    iconName: "netease.icon",
                    accentColor: "#E60026",
                    url: url,
                    nativeUrl: nil
                ))
                print("✅ 从 URL 提取: 网易云音乐")
            }
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
    
    // 解析短链：只取第一跳 302 的 Location 头，不继续跟随
    // 原因：URLSession 自动跟随所有重定向后 response.url 是最终 HTML 页，未必含 songmid
    // 解析短链：只取第一跳 302 的 Location 头，立即返回，不等待响应体
    // 不能用 async data(for:) + delegate，那会在 redirect 被阻断后 hang 住触发系统超时
    private func resolveURL(_ urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        return await withCheckedContinuation { continuation in
            var request = URLRequest(url: url)
            request.timeoutInterval = 8.0
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

            let capturer = RedirectCapturer(continuation: continuation, originalURL: urlString)
            let session = URLSession(configuration: .ephemeral, delegate: capturer, delegateQueue: nil)
            session.dataTask(with: request).resume()
        }
    }

    private func extractNeteaseSongId(from url: String) -> String? {
        // 支持多种URL格式
        // https://music.163.com/#/song?id=123456
        // https://music.163.com/song?id=123456
        // https://y.music.163.com/m/song?id=123456
        
        if let range = url.range(of: "id=") {
            let afterId = url[range.upperBound...]
            var songId = ""
            for char in afterId {
                if char.isNumber {
                    songId.append(char)
                } else {
                    break
                }
            }
            return songId.isEmpty ? nil : songId
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
               var appleUrl = firstApple["link"] as? String {
                // 统一为 Apple Music（iTunes → Apple Music）
                appleUrl = standardizeAppleMusicURL(appleUrl)
                
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

    private func data(from url: URL, timeout: TimeInterval? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout ?? defaultTimeout
        return try await URLSession.shared.data(for: request)
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

// MARK: - 短链重定向捕获代理
// 在收到第一个 302 时立即 resume continuation，不等响应体，避免系统超时
private class RedirectCapturer: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
    private let continuation: CheckedContinuation<String?, Never>
    private let originalURL: String
    private var resumed = false

    init(continuation: CheckedContinuation<String?, Never>, originalURL: String) {
        self.continuation = continuation
        self.originalURL = originalURL
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard !resumed else { completionHandler(nil); return }
        resumed = true

        // 优先用 response 里的 Location 头，如果没有就用 URLRequest 的 URL
        let location = response.value(forHTTPHeaderField: "Location")
            ?? request.url?.absoluteString
            ?? originalURL
        let finalURL: String
        if location.hasPrefix("http") {
            finalURL = location
        } else if let base = URL(string: originalURL) {
            finalURL = "\(base.scheme ?? "https")://\(base.host ?? "")\(location)"
        } else {
            finalURL = location
        }
        print("🔄 重定向解析: \(originalURL) → \(finalURL)")
        continuation.resume(returning: finalURL)
        completionHandler(nil) // 阻止继续跟随
        session.invalidateAndCancel()
        task.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !resumed else { return }
        resumed = true
        // 没有发生重定向（或取消），返回 nil 让调用方处理
        continuation.resume(returning: nil)
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 不需要响应体，取消任务节省资源
        dataTask.cancel()
    }
}
