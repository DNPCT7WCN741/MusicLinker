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

    func fetchLinks(url: String) async {
        guard let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let requestURL = URL(string: "\(baseURL)?url=\(encodedURL)&userCountry=CN&songIfSingle=true") else {
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
            let (data, response) = try await URLSession.shared.data(from: requestURL)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            guard httpResponse.statusCode == 200 else {
                throw NSError(domain: "OdesliError", code: httpResponse.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "无法找到这首歌的信息，请检查链接是否正确"])
            }

            let odesliResponse = try JSONDecoder().decode(OdesliResponse.self, from: data)
            let songResult = parseSongResult(from: odesliResponse)

            await MainActor.run {
                self.result = songResult
                self.isLoading = false
            }
        } catch let decodingError as DecodingError {
            await MainActor.run {
                self.errorMessage = "解析响应失败：\(decodingError.localizedDescription)"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func parseSongResult(from response: OdesliResponse) -> SongResult {
        // Get song metadata from the first entity
        let entity = response.entitiesByUniqueId[response.entityUniqueId]

        let platformOrder = [
            ("spotify", "Spotify", "spotify.icon", "#1DB954"),
            ("appleMusic", "Apple Music", "applemusic.icon", "#FC3C44"),
            ("youtubeMusic", "YouTube Music", "youtubemusic.icon", "#FF0000"),
            ("tidal", "Tidal", "tidal.icon", "#000000"),
            ("deezer", "Deezer", "deezer.icon", "#A238FF"),
            ("amazonMusic", "Amazon Music", "amazonmusic.icon", "#00A8E1"),
            ("pandora", "Pandora", "pandora.icon", "#3668FF"),
            ("soundcloud", "SoundCloud", "soundcloud.icon", "#FF5500"),
            ("napster", "Napster", "napster.icon", "#0D0D0D"),
        ]

        var links: [AppPlatformLink] = []
        for (key, name, icon, color) in platformOrder {
            if let platformData = response.linksByPlatform[key] {
                links.append(AppPlatformLink(
                    platformKey: key,
                    displayName: name,
                    iconName: icon,
                    accentColor: color,
                    url: platformData.url,
                    nativeUrl: platformData.nativeAppUriMobile
                ))
            }
        }

        let albumTitle = response.entitiesByUniqueId.values.first { $0.type == "album" }?.title
        let releaseDate = entity?.releaseDate ?? response.entitiesByUniqueId.values.first { $0.releaseDate != nil }?.releaseDate
        let releaseYear = releaseDate.map { String($0.prefix(4)) }

        return SongResult(
            title: entity?.title ?? "未知歌曲",
            artist: entity?.artistName ?? "未知艺术家",
            album: albumTitle,
            releaseYear: releaseYear,
            thumbnailUrl: entity?.thumbnailUrl,
            songLinkUrl: response.pageUrl,
            platforms: links
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
