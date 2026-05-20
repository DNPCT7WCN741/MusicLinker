import SwiftUI
import UIKit
import AVFoundation
import CoreImage
import Photos

// MARK: - Album Cover Service
class AlbumCoverService {
    static func fetchAlbumCover(artist: String, album: String) async -> String? {
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedAlbum = album.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        // Use Last.fm API (you can get a free API key from https://www.last.fm/api)
        let apiKey = "your_lastfm_api_key_here" // Replace with actual API key
        let urlString = "https://ws.audioscrobbler.com/2.0/?method=album.getinfo&artist=\(encodedArtist)&album=\(encodedAlbum)&api_key=\(apiKey)&format=json"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(LastFmResponse.self, from: data)
            
            // Try to get the largest image
            if let images = response.album?.image {
                for image in images.reversed() { // Start from largest
                    if let url = image.url, !url.isEmpty, url != "https://lastfm.freetls.fastly.net/i/u/300x300/2a96cbd8b46e442fc41c2b86b821562f.png" {
                        return url
                    }
                }
            }
        } catch {
            print("Failed to fetch album cover: \(error)")
        }
        
        return nil
    }
}

// MARK: - Last.fm API Models
struct LastFmResponse: Codable {
    let album: LastFmAlbum?
}

struct LastFmAlbum: Codable {
    let image: [LastFmImage]?
}

struct LastFmImage: Codable {
    let url: String?
    let size: String?

    enum CodingKeys: String, CodingKey {
        case url = "#text"
        case size
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case dark = "深邃蓝"
    case light = "清爽白"
    case black = "纯黑夜"
    case purple = "梦幻紫"
    case green = "自然绿"
    case orange = "活力橙"
    case pink = "浪漫粉"

    var displayName: String { rawValue }
    
    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark, .black, .purple, .green: return .dark
        case .light, .orange, .pink: return .light
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .dark:
            return [
                Color(.sRGB, red: 0.067, green: 0.075, blue: 0.063),
                Color(.sRGB, red: 0.090, green: 0.118, blue: 0.188),
                Color(.sRGB, red: 0.059, green: 0.082, blue: 0.125)
            ]
        case .light:
            return [Color.white, Color(.sRGB, red: 0.969, green: 0.984, blue: 1.0), Color(.sRGB, red: 0.929, green: 0.957, blue: 1.0)]
        case .black:
            return [Color.black, Color(.sRGB, red: 0.039, green: 0.039, blue: 0.039), Color.black]
        case .purple:
            return [
                Color(.sRGB, red: 0.102, green: 0.055, blue: 0.180),
                Color(.sRGB, red: 0.180, green: 0.102, blue: 0.278),
                Color(.sRGB, red: 0.086, green: 0.039, blue: 0.180)
            ]
        case .green:
            return [
                Color(.sRGB, red: 0.039, green: 0.122, blue: 0.071),
                Color(.sRGB, red: 0.078, green: 0.208, blue: 0.145),
                Color(.sRGB, red: 0.051, green: 0.122, blue: 0.082)
            ]
        case .orange:
            return [
                Color(.sRGB, red: 1.0, green: 0.976, blue: 0.961),
                Color(.sRGB, red: 1.0, green: 0.957, blue: 0.929),
                Color(.sRGB, red: 1.0, green: 0.929, blue: 0.878)
            ]
        case .pink:
            return [
                Color(.sRGB, red: 1.0, green: 0.961, blue: 0.969),
                Color(.sRGB, red: 1.0, green: 0.894, blue: 0.914),
                Color(.sRGB, red: 1.0, green: 0.839, blue: 0.867)
            ]
        }
    }

    var surface: Color {
        switch self {
        case .dark:   return Color(.sRGB, red: 0.067, green: 0.094, blue: 0.129)
        case .light:  return Color.white
        case .black:  return Color.black
        case .purple: return Color(.sRGB, red: 0.118, green: 0.059, blue: 0.208)
        case .green:  return Color(.sRGB, red: 0.059, green: 0.137, blue: 0.094)
        case .orange: return Color(.sRGB, red: 1.0, green: 0.980, blue: 0.969)
        case .pink:   return Color(.sRGB, red: 1.0, green: 0.969, blue: 0.976)
        }
    }

    var surfaceAlt: Color {
        switch self {
        case .dark:   return Color(.sRGB, red: 0.094, green: 0.125, blue: 0.196)
        case .light:  return Color(.sRGB, red: 0.945, green: 0.969, blue: 1.0)
        case .black:  return Color(.sRGB, red: 0.051, green: 0.051, blue: 0.051)
        case .purple: return Color(.sRGB, red: 0.176, green: 0.082, blue: 0.282)
        case .green:  return Color(.sRGB, red: 0.102, green: 0.220, blue: 0.157)
        case .orange: return Color(.sRGB, red: 1.0, green: 0.941, blue: 0.902)
        case .pink:   return Color(.sRGB, red: 1.0, green: 0.918, blue: 0.941)
        }
    }

    var accent: Color {
        switch self {
        case .dark:   return Color(.sRGB, red: 0.114, green: 0.306, blue: 0.847)
        case .light:  return Color(.sRGB, red: 0.145, green: 0.388, blue: 0.922)
        case .black:  return Color.white
        case .purple: return Color(.sRGB, red: 0.659, green: 0.333, blue: 0.969)
        case .green:  return Color(.sRGB, red: 0.063, green: 0.725, blue: 0.506)
        case .orange: return Color(.sRGB, red: 0.976, green: 0.451, blue: 0.086)
        case .pink:   return Color(.sRGB, red: 0.925, green: 0.286, blue: 0.600)
        }
    }

    var accentSecondary: Color {
        switch self {
        case .dark:   return Color(.sRGB, red: 0.231, green: 0.510, blue: 0.965)
        case .light:  return Color(.sRGB, red: 0.376, green: 0.647, blue: 0.980)
        case .black:  return Color(.sRGB, red: 0.898, green: 0.898, blue: 0.898)
        case .purple: return Color(.sRGB, red: 0.753, green: 0.518, blue: 0.988)
        case .green:  return Color(.sRGB, red: 0.204, green: 0.827, blue: 0.600)
        case .orange: return Color(.sRGB, red: 0.984, green: 0.573, blue: 0.235)
        case .pink:   return Color(.sRGB, red: 0.957, green: 0.447, blue: 0.714)
        }
    }

    var textPrimary: Color {
        switch self {
        case .dark, .black, .purple, .green: return Color.white
        case .light:  return Color(.sRGB, red: 0.059, green: 0.090, blue: 0.165)
        case .orange: return Color(.sRGB, red: 0.486, green: 0.176, blue: 0.071)
        case .pink:   return Color(.sRGB, red: 0.514, green: 0.094, blue: 0.263)
        }
    }

    var textSecondary: Color {
        switch self {
        case .dark:   return Color(.sRGB, red: 0.580, green: 0.639, blue: 0.718)
        case .light:  return Color(.sRGB, red: 0.278, green: 0.337, blue: 0.404)
        case .black:  return Color(.sRGB, red: 0.627, green: 0.627, blue: 0.627)
        case .purple: return Color(.sRGB, red: 0.769, green: 0.710, blue: 0.992)
        case .green:  return Color(.sRGB, red: 0.525, green: 0.937, blue: 0.675)
        case .orange: return Color(.sRGB, red: 0.761, green: 0.255, blue: 0.047)
        case .pink:   return Color(.sRGB, red: 0.745, green: 0.094, blue: 0.365)
        }
    }

    var cardStroke: Color {
        switch self {
        case .dark, .purple, .green: return Color.white.opacity(0.08)
        case .light:  return Color(.sRGB, red: 0.796, green: 0.835, blue: 0.882).opacity(0.25)
        case .black:  return Color.white.opacity(0.15)
        case .orange: return Color(.sRGB, red: 0.992, green: 0.729, blue: 0.455).opacity(0.3)
        case .pink:   return Color(.sRGB, red: 0.984, green: 0.812, blue: 0.910).opacity(0.3)
        }
    }
    
    var icon: String {
        switch self {
        case .dark: return "moon.stars.fill"
        case .light: return "sun.max.fill"
        case .black: return "circle.fill"
        case .purple: return "sparkles"
        case .green: return "leaf.fill"
        case .orange: return "flame.fill"
        case .pink: return "heart.fill"
        }
    }
}

enum PosterMode {
    case cover, lyrics
}

enum PosterStyle {
    case pure, dynamic
}

struct ResultView: View {
    let result: SongResult
    let theme: AppTheme
    @EnvironmentObject var languageManager: LanguageManager
    @State private var copiedURL: String? = nil
    @State private var coverUIImage: UIImage?
    @State private var dominantColor = Color(hex: "#7C3AED")
    @State private var secondaryColor = Color(hex: "#9B59B6")
    @State private var tertiaryColor = Color(hex: "#C39BD3")
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var renderedPoster: UIImage?
    @State private var isShowingSaveAlert = false
    @State private var saveAlertMessage: String = ""
    @State private var isSavingPoster = false
    @State private var previewURL: URL? = nil
    @State private var isLoadingPreview: Bool = false
    @State private var isPlayingPreview: Bool = false
    @State private var audioPlayer: AVPlayer? = nil
    @State private var errorMessage: String? = nil
    @State private var lastFmCoverUrl: String?
    @State private var posterMode: PosterMode = .cover
    @State private var posterStyle: PosterStyle = .dynamic
    @State private var featuredLyric: String = ""
    @State private var featuredKeyPhrase: String = ""
    @State private var isLoadingLyrics: Bool = false
    @State private var isInstrumental: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            // Song info card
            songInfoCard

            // Poster preview and download
            posterSection

            // Platform links
            VStack(spacing: 10) {
                HStack {
                    Text(languageManager.translate("result.platforms"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .tracking(2)
                    Spacer()
                    Text("\(result.platforms.count) " + languageManager.translate("result.platforms.count"))
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary.opacity(0.5))
                }
                .padding(.horizontal, 4)

                ForEach(result.platforms) { platform in
                    PlatformLinkRow(
                        platform: platform,
                        isCopied: copiedURL == standardizeAppleMusicURL(platform.url),
                        theme: theme,
                        onOpen: { openURL(platform.nativeUrl ?? platform.url) },
                        onCopy: { copyURL(platform.url) }
                    )
                }
            }

            // Song.link button
            songLinkButton
        }
        .onAppear {
            // Load cover image if available
            Task {
                await loadCoverImage()
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if #available(iOS 16.0, *) {
                ActivityViewController(activityItems: shareItems)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                ActivityViewController(activityItems: shareItems)
            }
        }
        .alert(languageManager.translate("result.videoFailed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil }})) {
            Button(languageManager.translate("result.ok"), role: .cancel) {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? languageManager.translate("result.videoError"))
        }
        .alert(languageManager.translate("result.alert.title"), isPresented: $isShowingSaveAlert) {
            Button(languageManager.translate("result.ok"), role: .cancel) {
                saveAlertMessage = ""
            }
        } message: {
            Text(saveAlertMessage)
        }
    }

    // MARK: - Subviews

    private var songInfoCard: some View {
        HStack(spacing: 16) {
            // Album art placeholder or actual image
            AsyncImage(url: URL(string: result.thumbnailUrl ?? lastFmCoverUrl ?? "")) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure, .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#4C1D95"), Color(hex: "#831843")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "music.note")
                            .font(.system(size: 28))
                            .foregroundColor(theme.textSecondary.opacity(0.6))
                    }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color(hex: "#7C3AED").opacity(0.3), radius: 12, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 5) {
                Text(result.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(2)

                Text(result.artist)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: "#4ADE80"))
                        .frame(width: 6, height: 6)
                    Text("\(languageManager.translate("result.found")) \(result.platforms.count) \(languageManager.translate("result.linksFound"))")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#4ADE80").opacity(0.8))
                }
                .padding(.top, 2)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.06 : 0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        )
    }

    private var posterSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(languageManager.translate("result.generatePoster"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(languageManager.translate("result.posterTip"))
                        .font(.system(size: 11))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                }
                Spacer()
                if let year = result.releaseYear {
                    Text(year)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#A78BFA"))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            Capsule()
                                .fill(theme.accent.opacity(0.12))
                        )
                }
            }

            posterPreview

            VStack(spacing: 12) {
                // 试听15s
                Button(action: togglePreview) {
                    HStack(spacing: 10) {
                        Image(systemName: isPlayingPreview ? "stop.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(isPlayingPreview ? languageManager.translate("result.stopPreview") : languageManager.translate("result.playPreview"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color.white)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(LinearGradient(
                                colors: [theme.accent, theme.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
                .disabled(isLoadingPreview)
                .overlay(
                    Group {
                        if isLoadingPreview {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                )

                HStack(spacing: 12) {
                    Button(action: sharePoster) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text(languageManager.translate("result.share"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color.white)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient(
                                    colors: [Color(hex: "#7C3AED"), Color(hex: "#DB2777")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ))
                        )
                    }

                    Button(action: savePosterToAlbum) {
                        HStack(spacing: 10) {
                            if isSavingPoster {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: theme.textPrimary))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "photo")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            Text(languageManager.translate("result.saveAlbum"))
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(theme.textPrimary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.12 : 0.6))
                        )
                    }
                    .disabled(isSavingPoster)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.06 : 0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        )
    }

    private var posterPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 按钮行：Cover/Lyrics 胶囊 + Pure/Dynamic 胶囊
            HStack(spacing: 8) {
                // Cover / Lyrics
                HStack(spacing: 0) {
                    Button(action: { posterMode = .cover }) {
                        Text("Cover")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(posterMode == .cover ? theme.surface : theme.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(posterMode == .cover ? theme.textPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                    Button(action: {
                        posterMode = .lyrics
                        if featuredLyric.isEmpty && !isLoadingLyrics {
                            isLoadingLyrics = true
                            Task { await loadFeaturedLyric() }
                        }
                    }) {
                        HStack(spacing: 4) {
                            if isLoadingLyrics { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: theme.textSecondary)).scaleEffect(0.6) }
                            Text("Lyrics")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(posterMode == .lyrics ? theme.surface : theme.textSecondary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(posterMode == .lyrics ? theme.textPrimary : Color.clear)
                        .clipShape(Capsule())
                    }
                }
                .background(Capsule().fill(theme.surfaceAlt))

                // Pure / Dynamic
                HStack(spacing: 0) {
                    Button(action: { posterStyle = .pure }) {
                        Text("Pure")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(posterStyle == .pure ? theme.surface : theme.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(posterStyle == .pure ? theme.textPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                    Button(action: { posterStyle = .dynamic }) {
                        Text("Dynamic")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(posterStyle == .dynamic ? theme.surface : theme.textSecondary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(posterStyle == .dynamic ? theme.textPrimary : Color.clear)
                            .clipShape(Capsule())
                    }
                }
                .background(Capsule().fill(theme.surfaceAlt))
            }

            // 海报卡片（居中展示）
            HStack {
                Spacer()
                Group {
                    if posterMode == .cover {
                        posterCard
                    } else {
                        lyricsPosterCard
                    }
                }
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .frame(width: 280)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var posterCard: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let hPad = w * 0.09
            let coverSize = w - hPad * 2
            let coverTop = h * 0.07
            let stripHeight = h * 0.12

            ZStack(alignment: .bottom) {
                // 背景：Pure=纯色，Dynamic=渐变
                Group {
                    if posterStyle == .dynamic {
                        LinearGradient(
                            colors: [dominantColor, secondaryColor.opacity(0.55), dominantColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(colors: [dominantColor, dominantColor], startPoint: .top, endPoint: .bottom)
                    }
                }
                .ignoresSafeArea()

                // 封面图
                Group {
                    if let uiImage = coverUIImage {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: coverSize, height: coverSize)
                            .clipShape(RoundedRectangle(cornerRadius: coverSize * 0.06))
                    } else {
                        RoundedRectangle(cornerRadius: coverSize * 0.06)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: coverSize, height: coverSize)
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: coverSize * 0.25))
                                    .foregroundColor(Color.white.opacity(0.35))
                            )
                    }
                }
                .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)
                .position(x: w / 2, y: coverTop + coverSize / 2)

                // 底部两条色带
                VStack(spacing: 0) {
                    // 第一条：歌名
                    HStack {
                        Text(result.title)
                            .font(.system(size: w * 0.09, weight: .bold))
                            .foregroundColor(posterStyle == .dynamic ? Color.white : dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.leading, hPad)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: stripHeight)
                    .background(posterStyle == .dynamic ? Color.black.opacity(0.28) : secondaryColor)

                    // 第二条：专辑名 + 歌手
                    HStack {
                        Text(result.album ?? "")
                            .font(.system(size: w * 0.075, weight: .bold))
                            .foregroundColor(posterStyle == .dynamic ? Color.white.opacity(0.85) : dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.leading, hPad)
                        Spacer()
                        Text(result.artist)
                            .font(.system(size: w * 0.06, weight: .semibold))
                            .foregroundColor(posterStyle == .dynamic ? Color.white.opacity(0.85) : dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.trailing, hPad)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: stripHeight)
                    .background(posterStyle == .dynamic ? Color.black.opacity(0.18) : tertiaryColor)

                    // 底部留白，和色带等高
                    if posterStyle == .dynamic {
                        Color.clear.frame(height: stripHeight)
                    } else {
                        dominantColor.frame(height: stripHeight)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 42))
    }

    // MARK: - Lyrics Poster Card
    private var lyricsPosterCard: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let hPad = w * 0.10

            ZStack {
                // 背景：Pure=纯色，Dynamic=渐变
                Group {
                    if posterStyle == .dynamic {
                        LinearGradient(
                            colors: [dominantColor, secondaryColor.opacity(0.55), dominantColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        LinearGradient(colors: [dominantColor, dominantColor], startPoint: .top, endPoint: .bottom)
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // 大引号装饰
                    HStack {
                        Text("\u{201C}")
                            .font(.system(size: w * 0.32, weight: .black, design: .serif))
                            .foregroundColor(secondaryColor.opacity(0.6))
                            .offset(y: w * 0.08)
                        Spacer()
                    }
                    .padding(.leading, hPad * 0.5)

                    // 歌词区域：关键词在行内放大，其余正常
                    if isInstrumental {
                        Text("此刻无需言语")
                            .font(.system(size: w * 0.065, weight: .bold, design: .default))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, hPad)
                    } else {
                        let displayLyric = featuredLyric.isEmpty ? result.title : featuredLyric
                        Text(buildLyricAttributedString(lyric: displayLyric, keyPhrase: featuredKeyPhrase, baseSize: w * 0.058))
                            .lineSpacing(w * 0.022)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, hPad)
                    }

                    // 右引号
                    HStack {
                        Spacer()
                        Text("\u{201D}")
                            .font(.system(size: w * 0.32, weight: .black, design: .serif))
                            .foregroundColor(secondaryColor.opacity(0.6))
                            .offset(y: -(w * 0.08))
                    }
                    .padding(.trailing, hPad * 0.5)

                    Spacer()

                    // 分隔线
                    Rectangle()
                        .fill(secondaryColor.opacity(0.5))
                        .frame(height: 1)
                        .padding(.horizontal, hPad)
                        .padding(.bottom, h * 0.03)

                    // 底部：小封面 + 歌名 + 艺术家
                    HStack(spacing: w * 0.04) {
                        // 小封面缩略图
                        Group {
                            if let uiImage = coverUIImage {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                tertiaryColor
                            }
                        }
                        .frame(width: w * 0.13, height: w * 0.13)
                        .clipShape(RoundedRectangle(cornerRadius: w * 0.025))

                        VStack(alignment: .leading, spacing: w * 0.01) {
                            Text(result.title)
                                .font(.system(size: w * 0.058, weight: .bold))
                                .foregroundColor(Color.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text(result.artist)
                                .font(.system(size: w * 0.046, weight: .regular))
                                .foregroundColor(Color.white.opacity(0.65))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, h * 0.06)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 42))
    }

    /// 构建歌词 AttributedString：关键字在行内放大加粗，其余正常
    private func buildLyricAttributedString(lyric: String, keyPhrase: String, baseSize: CGFloat) -> AttributedString {
        var attributed = AttributedString(lyric)
        attributed.font = .system(size: baseSize, weight: .bold)
        attributed.foregroundColor = .white
        if !keyPhrase.isEmpty,
           let range = attributed.range(of: keyPhrase, options: .caseInsensitive) {
            attributed[range].font = .system(size: baseSize * 1.6, weight: .black)
        }
        return attributed
    }

    private func labelChip(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.7))
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }

    private func renderPosterImage() -> UIImage? {
        let w: CGFloat = 1080
        let h: CGFloat = 1920
        let content: AnyView
        if posterMode == .lyrics {
            content = AnyView(lyricsPosterCard.frame(width: w, height: h).environment(\.displayScale, 1))
        } else {
            content = AnyView(posterCard.frame(width: w, height: h).environment(\.displayScale, 1))
        }
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = .init(width: w, height: h)
        renderer.scale = 1
        let image = renderer.uiImage
        renderedPoster = image
        return image
    }

    private func sharePoster() {
        buttonFeedback()
        Task { @MainActor in
            guard let image = renderPosterImage() else { return }
            shareItems = [image]
            isShowingShareSheet = true
        }
    }

    private func savePosterToAlbum() {
        buttonFeedback()
        
        // 防止重复点击
        guard !isSavingPoster else { return }
        
        isSavingPoster = true
        
        Task { @MainActor in
            do {
                // 检查并请求相册访问权限
                let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                
                if status == .notDetermined {
                    let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                    if newStatus != .authorized && newStatus != .limited {
                        isSavingPoster = false
                        saveAlertMessage = languageManager.translate("result.needPhotoPermission")
                        isShowingSaveAlert = true
                        return
                    }
                } else if status == .denied || status == .restricted {
                    isSavingPoster = false
                    saveAlertMessage = languageManager.translate("result.needPhotoPermissionSettings")
                    isShowingSaveAlert = true
                    return
                }
                
                // 在主线程渲染图片（ImageRenderer本身就很快）
                guard let image = renderPosterImage() else {
                    isSavingPoster = false
                    saveAlertMessage = languageManager.translate("result.posterGenerateFailed")
                    isShowingSaveAlert = true
                    return
                }
                
                // 使用 Photos framework 保存图片（这个可以在后台）
                try await saveImageToPhotos(image)
                
                isSavingPoster = false
                saveAlertMessage = languageManager.translate("result.posterSaved")
                isShowingSaveAlert = true
                
            } catch {
                isSavingPoster = false
                let errorMsg = error.localizedDescription
                if errorMsg.contains("权限") || errorMsg.contains("access") || errorMsg.contains("authorization") {
                    saveAlertMessage = languageManager.translate("result.needPhotoPermissionSettings")
                } else {
                    saveAlertMessage = "\(languageManager.translate("result.saveFailed")): \(errorMsg)"
                }
                isShowingSaveAlert = true
            }
        }
    }
    
    private func saveImageToPhotos(_ image: UIImage) async throws {
        // 使用 Photos framework 的现代 API
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
    }

    private func togglePreview() {
        buttonFeedback()
        if isPlayingPreview {
            audioPlayer?.pause()
            audioPlayer = nil
            isPlayingPreview = false
            return
        }
        if let existing = previewURL {
            playAudio(url: existing)
            return
        }
        isLoadingPreview = true
        Task {
            do {
                let url = try await fetchPreviewURL()
                await MainActor.run {
                    previewURL = url
                    isLoadingPreview = false
                    playAudio(url: url)
                }
            } catch {
                await MainActor.run {
                    isLoadingPreview = false
                    errorMessage = "未找到试听源"
                }
            }
        }
    }

    private func playAudio(url: URL) {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        // 15秒后自动停止
        let stopTime = CMTime(seconds: 15, preferredTimescale: 1)
        player.addBoundaryTimeObserver(forTimes: [NSValue(time: stopTime)], queue: .main) { [weak player] in
            player?.pause()
            DispatchQueue.main.async {
                self.isPlayingPreview = false
                self.audioPlayer = nil
            }
        }
        player.play()
        audioPlayer = player
        isPlayingPreview = true
    }

    private func fetchPreviewURL() async throws -> URL {
        let query = "\(result.title) \(result.artist)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法构造请求"])
        }
        if let url = try await searchDeezerPreview(query: encodedQuery) {
            return url
        }
        guard let token = try await fetchSpotifyAccessToken() else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取token"])
        }
        guard let url = URL(string: "https://api.spotify.com/v1/search?q=track:\"\(result.title)\" artist:\"\(result.artist)\"&type=track&limit=5") else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法构造请求"])
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let searchResponse = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        guard let track = searchResponse.tracks.items.first,
              let previewString = track.preview_url,
              let previewLink = URL(string: previewString) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到试听源"])
        }
        return previewLink
    }

    private func searchDeezerPreview(query: String) async throws -> URL? {
        guard let url = URL(string: "https://api.deezer.com/search?q=\(query)&limit=1") else {
            return nil
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let searchResponse = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)

        guard let track = searchResponse.data.first,
              let previewURL = track.preview,
              let previewLink = URL(string: previewURL) else {
            return nil
        }

        return previewLink
    }

    private func fetchSpotifyAccessToken() async throws -> String? {
        guard let url = URL(string: "https://open.spotify.com/get_access_token?reason=transport&productType=web_player") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        return tokenResponse.accessToken
    }

    private func copyAllPlatformLinksToClipboard() {
        var linkText = result.platforms.map { "\($0.displayName)：\(standardizeAppleMusicURL($0.url))" }.joined(separator: "\n")
        linkText += "\n\nsong.link：\(result.songLinkUrl)"
        UIPasteboard.general.string = linkText
    }

    private func loadCoverImage() async {
        let urlString = result.thumbnailUrl ?? lastFmCoverUrl
        guard let urlString = urlString,
              let url = URL(string: urlString) else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return }
            let colors = image.extractPalette()
            await MainActor.run {
                coverUIImage = image
                dominantColor = colors[0]
                secondaryColor = colors[1]
                tertiaryColor = colors[2]
            }
        } catch {}
    }

    // MARK: - 歌词获取：从网易云拿 LRC，重复行检测找副歌/hook
    private func loadFeaturedLyric() async {
        defer { Task { @MainActor in isLoadingLyrics = false } }

        // 先从已有结果里找网易云链接，找不到则用歌名+艺术家搜索
        var songId: String? = nil
        if let neteaseLink = result.platforms.first(where: { $0.platformKey == "netease" || $0.displayName == "网易云音乐" }) {
            songId = extractNeteaseSongId(from: neteaseLink.url)
        }
        if songId == nil || songId!.isEmpty {
            print("🔍 结果里无网易云链接，搜索歌词用 song ID...")
            songId = await searchNeteaseForSongId(title: result.title, artist: result.artist)
        }
        guard let finalSongId = songId, !finalSongId.isEmpty else {
            print("❌ 无法获取 song ID，显示歌名")
            await MainActor.run { featuredLyric = result.title }
            return
        }
        print("🎵 loadFeaturedLyric songId=\(finalSongId)")

        // 并行：歌词 + 热门评论（哪行 LRC 被热评引用最多 = 最火歌词）
        async let lrcFetch    = fetchNeteaseLrc(songId: finalSongId)
        async let commentFetch = fetchNeteaseHotComments(songId: finalSongId)
        let (lrcText, hotComments) = await (lrcFetch, commentFetch)
        print("💬 热评数=\(hotComments.count)，LRC=\(lrcText == nil ? "nil" : "\(lrcText!.count)chars")")

        if lrcText == "__INSTRUMENTAL__" {
            print("ℹ️ 纯音乐，显示无言语提示")
            await MainActor.run { isInstrumental = true }
            return
        }
        guard let lrc = lrcText else {
            print("⚠️ LRC 为 nil，显示歌名")
            await MainActor.run { featuredLyric = result.title }
            return
        }

        let plainLines = plainLrcLines(from: lrc)

        // 优先级 1：DeepSeek AI（Key 已配置时）
        if let aiResult = await fetchFeaturedLyricFromAI(
            title: result.title, artist: result.artist, lines: plainLines) {
            await MainActor.run {
                featuredLyric = aiResult.lyric
                featuredKeyPhrase = aiResult.keyPhrase
            }
            return
        }

        // 优先级 2：热评匹配
        if !hotComments.isEmpty, plainLines.count >= 3 {
            outer: for comment in hotComments {
                for (idx, line) in plainLines.enumerated() where line.count >= 5 {
                    if comment.contains(line) {
                        let start = max(0, min(idx, plainLines.count - 3))
                        let block = plainLines[start ..< (start + 3)].joined(separator: "\n")
                        await MainActor.run { featuredLyric = block }
                        return
                    }
                }
            }
            print("💬 热评未匹配到歌词行，回退滑动窗口")
        }

        // 优先级 3：滑动窗口算法
        let line = pickFeaturedLine(from: lrc)
        await MainActor.run { featuredLyric = line }
    }

    // MARK: - Groq AI 歌词选取
    /// 把完整歌词交给 DeepSeek，让它找最打动人的连续 3 行
    private func fetchFeaturedLyricFromAI(title: String, artist: String, lines: [String]) async -> (lyric: String, keyPhrase: String)? {
        // 检查 AI 是否启用
        let isDeepseekEnabled = UserDefaults.standard.bool(forKey: "IsDeepSeekEnabled")
        guard isDeepseekEnabled else {
            print("ℹ️ DeepSeek AI 已禁用，跳过 AI 分析")
            return nil
        }
        
        // 从 Keychain 获取配置的 API Key（安全加密存储）
        guard let deepseekAPIKey = KeychainHelper.shared.retrieve(forKey: "DeepSeekAPIKey"),
              !deepseekAPIKey.isEmpty else {
            print("ℹ️ DeepSeek API Key 未配置，跳过")
            return nil
        }
        
        guard lines.count >= 3 else { return nil }
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else { return nil }

        let lyricsText = lines.joined(separator: "\n")
        let systemPrompt = """
        You are a music expert. Given song lyrics:
        1. Find the most iconic and emotionally resonant consecutive 3 lines.
        2. From those 3 lines, extract the single most powerful phrase (2-5 words max, must be a substring of one of the 3 lines).
        Return in EXACTLY this format (no other text):
        LINES:
        [line1]
        [line2]
        [line3]
        KEY:
        [2-5 word key phrase]
        """
        let userPrompt = "Song: \(title) by \(artist)\n\nLyrics:\n\(lyricsText)"

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userPrompt]
            ],
            "max_tokens": 150,
            "temperature": 0.3
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 10
        req.setValue("Bearer \(deepseekAPIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse else {
            print("❌ DeepSeek 请求失败")
            return nil
        }
        guard http.statusCode == 200 else {
            print("⚠️ DeepSeek HTTP \(http.statusCode)")
            return nil
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            print("❌ DeepSeek 响应解析失败")
            return nil
        }

        // 清洗：去掉空行、引号，取前 3 行
        let resultLines = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines)
                      .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”")) }
            .filter { !$0.isEmpty }
        // 解析 LINES: 和 KEY: 两段
        var lyricLines: [String] = []
        var keyPhrase: String = ""
        var inLines = false, inKey = false
        for raw in content.components(separatedBy: "\n") {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\u{22}\u{201C}\u{201D}"))
            if t == "LINES:" { inLines = true; inKey = false; continue }
            if t == "KEY:"   { inKey = true; inLines = false; continue }
            if t.isEmpty { continue }
            if inLines && lyricLines.count < 3 { lyricLines.append(t) }
            else if inKey && keyPhrase.isEmpty { keyPhrase = t }
        }
        // fallback：如果格式不对，取前3行非标签行当歌词
        if lyricLines.isEmpty {
            lyricLines = content.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && $0 != "LINES:" && $0 != "KEY:" }
                .prefix(3).map { $0 }
        }
        guard !lyricLines.isEmpty else { return nil }
        // 验证至少 1 行在原歌词里
        let hasMatch = lyricLines.contains { aiLine in lines.contains { $0 == aiLine } }
        if !hasMatch {
            print("⚠️ DeepSeek 返回内容与歌词不匹配，放弃")
            return nil
        }
        let lyric = lyricLines.joined(separator: "\n")
        print("✨ DeepSeek 歌词: \(lyric.prefix(60))")
        print("✨ DeepSeek 关键词: \(keyPhrase)")
        return (lyric: lyric, keyPhrase: keyPhrase)
    }

    /// 提取干净的 LRC 文本行列表（去掉元数据行）
    private func plainLrcLines(from lrc: String) -> [String] {
        let pattern = #"^\[\d+:\d+(?:\.\d+)?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        var lines: [String] = []
        for raw in lrc.components(separatedBy: "\n") {
            let ns = raw as NSString
            let rng = NSRange(location: 0, length: ns.length)
            guard let m = regex.firstMatch(in: raw, range: rng), m.numberOfRanges >= 2 else { continue }
            let text = ns.substring(with: m.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 3 && text.count <= 60,
                  !text.hasPrefix("作词"), !text.hasPrefix("作曲"),
                  !text.hasPrefix("编曲"), !text.hasPrefix("制作"),
                  !text.hasPrefix("//"), !text.hasPrefix("【") else { continue }
            lines.append(text)
        }
        return lines
    }

    /// 用歌名+艺术家搜索网易云，返回 song ID 字符串
    private func searchNeteaseForSongId(title: String, artist: String) async -> String? {
        let query = "\(title) \(artist)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&limit=5&offset=0") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let resultObj = json["result"] as? [String: Any],
              let songs = resultObj["songs"] as? [[String: Any]], !songs.isEmpty else { return nil }
        // 优先艺术家名匹配
        let artistLower = artist.lowercased()
        var best = songs[0]
        for song in songs {
            let names = (song["artists"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }.joined(separator: " ").lowercased()
            if !artistLower.isEmpty && names.contains(artistLower) { best = song; break }
        }
        guard let id = best["id"] as? Int else { return nil }
        print("✅ 搜索到网易云 song ID: \(id) for \(title)")
        return String(id)
    }

    /// 获取网易云 LRC 原始文本
    private func fetchNeteaseLrc(songId: String) async -> String? {
        // 先试 lv=-1（最佳质量），若返回空再试 lv=1
        if let lrc = await fetchNeteaseLrcWithVersion(songId: songId, lv: "-1"), !lrc.isEmpty {
            return lrc
        }
        print("⚠️ lv=-1 无结果，回退 lv=1")
        return await fetchNeteaseLrcWithVersion(songId: songId, lv: "1")
    }

    private func fetchNeteaseLrcWithVersion(songId: String, lv: String) async -> String? {
        guard let url = URL(string: "https://music.163.com/api/song/lyric?id=\(songId)&lv=\(lv)") else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: req) else {
            print("❌ LRC 请求失败 songId=\(songId) lv=\(lv)")
            return nil
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        print("🎵 LRC HTTP \(status) songId=\(songId) lv=\(lv) bytes=\(data.count)")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("❌ LRC JSON 解析失败")
            return nil
        }
        // 检查网易云返回的 code 字段
        if let code = json["code"] as? Int, code != 200 {
            print("⚠️ LRC API code=\(code) lv=\(lv)")
            return nil
        }
        if let nolyric = json["nolyric"] as? Bool, nolyric {
            print("ℹ️ 该歌曲无歌词 (nolyric=true)")
            return "__INSTRUMENTAL__"
        }
        if let uncollected = json["uncollected"] as? Bool, uncollected {
            print("ℹ️ 该歌曲歌词未收录")
            return nil
        }
        guard let lrc = (json["lrc"] as? [String: Any])?["lyric"] as? String,
              !lrc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("⚠️ LRC lyric 字段为空 lv=\(lv)")
            return nil
        }
        print("✅ LRC 获取成功，长度=\(lrc.count) lv=\(lv)")
        return lrc
    }

    /// 获取网易云热门评论（取 Top 5 content 字段）
    private func fetchNeteaseHotComments(songId: String) async -> [String] {
        let urlStr = "https://music.163.com/api/comment/hot?id=\(songId)&type=0&offset=0&total=false&limit=5"
        guard let url = URL(string: urlStr) else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
        // 检查 code 字段
        if let code = json["code"] as? Int, code != 200 {
            print("⚠️ 热评 API code=\(code)")
            return []
        }
        guard let hot = json["hotComments"] as? [[String: Any]] else { return [] }
        let comments = hot.compactMap { $0["content"] as? String }
        print("💬 获取到热评 \(comments.count) 条")
        return comments
    }

    /// LRC 解析 → 3行滑动窗口找副歌块（副歌是整块重复，不是单行重复）
    private func pickFeaturedLine(from lrc: String) -> String {
        // 1. 解析 LRC，提取 (时间戳秒数, 歌词文本)
        let pattern = #"^\[(\d+):(\d+(?:\.\d+)?)\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result.title }

        struct LLine { let time: Double; let text: String }
        var all: [LLine] = []

        for raw in lrc.components(separatedBy: "\n") {
            let ns = raw as NSString
            let rng = NSRange(location: 0, length: ns.length)
            guard let m = regex.firstMatch(in: raw, range: rng), m.numberOfRanges >= 4 else { continue }
            let min  = Double(ns.substring(with: m.range(at: 1))) ?? 0
            let sec  = Double(ns.substring(with: m.range(at: 2))) ?? 0
            let text = ns.substring(with: m.range(at: 3)).trimmingCharacters(in: .whitespacesAndNewlines)
            let len  = text.count
            guard len >= 3 && len <= 60,
                  !text.hasPrefix("作词"), !text.hasPrefix("作曲"),
                  !text.hasPrefix("编曲"), !text.hasPrefix("制作"),
                  !text.hasPrefix("//"), !text.hasPrefix("【") else { continue }
            all.append(LLine(time: min * 60 + sec, text: text))
        }

        guard all.count >= 3 else {
            return all.isEmpty ? result.title : all.map(\.text).joined(separator: "\n")
        }

        // 2. 3行滑动窗口：副歌是整块重复，找出现次数最多的3行组合
        var winFreq: [String: (count: Int, idx: Int)] = [:]
        for i in 0...(all.count - 3) {
            let key = [all[i].text, all[i+1].text, all[i+2].text].joined(separator: "\n")
            if winFreq[key] == nil { winFreq[key] = (1, i) }
            else { winFreq[key]!.count += 1 }
        }
        if let best = winFreq.max(by: { $0.value.count < $1.value.count }), best.value.count >= 2 {
            return best.key   // 命中！这就是副歌
        }

        // 3. 没有重复块 → 回退到单行重复，然后取锚点前后共3行
        var lineFreq: [String: Int] = [:]
        for l in all { lineFreq[l.text, default: 0] += 1 }
        if let bestLine = lineFreq.max(by: { $0.value < $1.value }), bestLine.value >= 2,
           let anchorIdx = all.firstIndex(where: { $0.text == bestLine.key }) {
            let start = max(0, min(anchorIdx, all.count - 3))
            return all[start..<(start + 3)].map(\.text).joined(separator: "\n")
        }

        // 4. 完全没有重复 → 用时间戳找 42% 位置（流行歌副歌通常在这里）
        let totalTime = all.last!.time
        if totalTime > 0 {
            let target = totalTime * 0.42
            let anchor = all.enumerated()
                .min(by: { abs($0.element.time - target) < abs($1.element.time - target) })?.offset
                ?? (all.count / 2)
            let start = max(0, min(anchor, all.count - 3))
            return all[start..<(start + 3)].map(\.text).joined(separator: "\n")
        }

        // 最终保险
        let start = max(0, all.count / 2 - 1)
        return all[start..<(start + 3)].map(\.text).joined(separator: "\n")
    }

    private func extractNeteaseSongId(from url: String) -> String? {
        guard let range = url.range(of: "id=") else { return nil }
        let after = url[range.upperBound...]
        var id = ""
        for ch in after {
            if ch.isNumber { id.append(ch) } else { break }
        }
        return id.isEmpty ? nil : id
    }

    private var songLinkButton: some View {
        Button(action: { openURL(result.songLinkUrl) }) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                Text(languageManager.translate("result.songLink"))
                    .font(.system(size: 13, weight: .medium))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
            }
            .foregroundColor(theme.accent.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(theme.accent.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // MARK: - Actions

    private func openURL(_ urlString: String) {
        buttonFeedback()
        let standardizedURL = standardizeAppleMusicURL(urlString)
        guard let url = URL(string: standardizedURL) else { return }
        UIApplication.shared.open(url)
    }

    private func copyURL(_ urlString: String) {
        buttonFeedback()
        let standardizedURL = standardizeAppleMusicURL(urlString)
        UIPasteboard.general.string = standardizedURL
        withAnimation(.spring(response: 0.3)) {
            copiedURL = urlString
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedURL = nil
            }
        }
    }

    /// 统一将 iTunes 链接转换为 Apple Music 格式（全局方法）
    private func standardizeAppleMusicURL(_ url: String) -> String {
        // 使用 replacingOccurrences 将 iTunes 域名转换为 Apple Music
        return url.replacingOccurrences(of: "itunes.apple.com", with: "music.apple.com")
    }

    private func buttonFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // 设置完成回调以避免警告
        controller.completionWithItemsHandler = { _, _, _, _ in
            // 完成后自动关闭
        }
        
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // 空实现，避免不必要的更新
    }
}

// MARK: - Spotify Preview Models

private struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let accessTokenExpirationTimestampMs: Int?
    let clientId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "accessToken"
        case accessTokenExpirationTimestampMs
        case clientId
    }
}

private struct DeezerSearchResponse: Codable {
    let data: [DeezerTrack]
}

private struct DeezerTrack: Codable {
    let preview: String?
}

private struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTrackContainer
}

private struct SpotifyTrackContainer: Codable {
    let items: [SpotifyTrack]
}

private struct SpotifyTrack: Codable {
    let preview_url: String?
    let name: String?
    let artists: [SpotifyArtist]?
    let album: SpotifyAlbum?
}

private struct SpotifyArtist: Codable {
    let name: String?
}

private struct SpotifyAlbum: Codable {
    let images: [SpotifyImage]?
}

private struct SpotifyImage: Codable {
    let url: String?
    let height: Int?
    let width: Int?
}

extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = ciImage ?? CIImage(image: self) else {
            return nil
        }
        let context = CIContext(options: nil)
        let extent = inputImage.extent
        guard let filter = CIFilter(name: "CIAreaAverage") else {
            return nil
        }
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: extent), forKey: kCIInputExtentKey)
        guard let outputImage = filter.outputImage else {
            return nil
        }
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                       toBitmap: &bitmap,
                       rowBytes: 4,
                       bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                       format: .RGBA8,
                       colorSpace: CGColorSpaceCreateDeviceRGB())
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: CGFloat(bitmap[3]) / 255
        )
    }

    func extractPalette() -> [Color] {
        let fallback: [Color] = [Color(hex: "#7C3AED"), Color(hex: "#9B59B6"), Color(hex: "#C39BD3")]
        guard let cgImage = self.cgImage else { return fallback }

        let width = 32
        let height = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &rawData,
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return fallback }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var pixels: [(r: Float, g: Float, b: Float)] = []
        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Float(rawData[i]) / 255
            let g = Float(rawData[i+1]) / 255
            let b = Float(rawData[i+2]) / 255
            let brightness = 0.299*r + 0.587*g + 0.114*b
            if brightness > 0.1 && brightness < 0.92 {
                pixels.append((r, g, b))
            }
        }
        guard !pixels.isEmpty else { return fallback }

        // 找饱和度最高的像素作为主色
        var bestH: CGFloat = 0, bestS: CGFloat = 0, bestBr: CGFloat = 0
        for px in pixels {
            let c = UIColor(red: CGFloat(px.r), green: CGFloat(px.g), blue: CGFloat(px.b), alpha: 1)
            var ph: CGFloat = 0, ps: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            c.getHue(&ph, saturation: &ps, brightness: &pb, alpha: &pa)
            if ps > bestS {
                bestS = ps; bestH = ph; bestBr = pb
            }
        }
        var h = bestH, s = bestS, br = bestBr

        // dominant 高饱和压暗，做深色背景
        let darkDominant = UIColor(hue: h, saturation: min(s * 1.0, 1), brightness: min(bestBr * 0.35, 0.45), alpha: 1)

        // 按色相分桶（每桶30度），统计各桶像素占比
        var hueBuckets = [Int: [(hue: CGFloat, sat: CGFloat, bri: CGFloat)]]()
        for px in pixels {
            let c = UIColor(red: CGFloat(px.r), green: CGFloat(px.g), blue: CGFloat(px.b), alpha: 1)
            var ph: CGFloat = 0, ps: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            c.getHue(&ph, saturation: &ps, brightness: &pb, alpha: &pa)
            guard ps > 0.15 else { continue }
            let bucket = Int(ph * 12) % 12
            hueBuckets[bucket, default: []].append((ph, ps, pb))
        }
        let total = pixels.count

        func findStrips(minRatio: Float, minDist: CGFloat) -> [(hue: CGFloat, sat: CGFloat, bri: CGFloat, ratio: Float)] {
            var result: [(hue: CGFloat, sat: CGFloat, bri: CGFloat, ratio: Float)] = []
            for (bucket, members) in hueBuckets {
                let ratio = Float(members.count) / Float(total)
                guard ratio >= minRatio else { continue }
                let bucketHue = CGFloat(bucket) / 12.0
                let dist = min(abs(bucketHue - h), 1 - abs(bucketHue - h))
                guard dist > minDist else { continue }
                let avgH = members.map(\.hue).reduce(0,+) / CGFloat(members.count)
                let avgS = members.map(\.sat).reduce(0,+) / CGFloat(members.count)
                let avgB = members.map(\.bri).reduce(0,+) / CGFloat(members.count)
                result.append((avgH, avgS, avgB, ratio))
            }
            return result.sorted { $0.ratio > $1.ratio }
        }

        // 两个色带都必须满足条件，逐步放宽阈值直到找到两个
        var stripCandidates = findStrips(minRatio: 0.20, minDist: 0.15)
        if stripCandidates.count < 2 {
            stripCandidates = findStrips(minRatio: 0.12, minDist: 0.12)
        }
        if stripCandidates.count < 2 {
            stripCandidates = findStrips(minRatio: 0.08, minDist: 0.08)
        }

        let stripUI1: UIColor
        let stripUI2: UIColor
        if stripCandidates.count >= 2 {
            let c1 = stripCandidates[0]
            let c2 = stripCandidates[1]
            stripUI1 = UIColor(hue: c1.hue, saturation: min(c1.sat * 0.75, 1), brightness: min(c1.bri * 1.35, 1), alpha: 1)
            stripUI2 = UIColor(hue: c2.hue, saturation: min(c2.sat * 0.65, 1), brightness: min(c2.bri * 1.45, 1), alpha: 1)
        } else if stripCandidates.count == 1 {
            let c1 = stripCandidates[0]
            stripUI1 = UIColor(hue: c1.hue, saturation: min(c1.sat * 0.75, 1), brightness: min(c1.bri * 1.35, 1), alpha: 1)
            stripUI2 = UIColor(hue: (c1.hue + 0.05).truncatingRemainder(dividingBy: 1), saturation: min(c1.sat * 0.65, 1), brightness: min(c1.bri * 1.45, 1), alpha: 1)
        } else {
            // 封面颜色太集中，用互补色兜底
            stripUI1 = UIColor(hue: (h + 0.5).truncatingRemainder(dividingBy: 1), saturation: 0.5, brightness: 0.85, alpha: 1)
            stripUI2 = UIColor(hue: (h + 0.55).truncatingRemainder(dividingBy: 1), saturation: 0.4, brightness: 0.9, alpha: 1)
        }

        let secondary = Color(stripUI1)
        let tertiary  = Color(stripUI2)

        return [Color(darkDominant), secondary, tertiary]
    }
}

// MARK: - Platform Link Row

struct PlatformLinkRow: View {
    let platform: AppPlatformLink
    let isCopied: Bool
    let theme: AppTheme
    let onOpen: () -> Void
    let onCopy: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack(spacing: 14) {
            // Platform color indicator
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: platform.accentColor))
                .frame(width: 4, height: 36)

            // Platform name
            VStack(alignment: .leading, spacing: 2) {
                Text(platform.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text(shortenedURL(platform.url))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textSecondary.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                // Copy button
                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(
                            isCopied
                                ? Color(hex: "#4ADE80")
                                : theme.textSecondary.opacity(0.5)
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(
                                    isCopied
                                        ? Color(hex: "#4ADE80").opacity(0.15)
                                        : theme.surfaceAlt.opacity(0.5)
                                )
                        )
                }
                .animation(.spring(response: 0.3), value: isCopied)

                // Open button
                Button(action: onOpen) {
                    Image(systemName: "arrow.up.right.square.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: platform.accentColor))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(hex: platform.accentColor).opacity(0.15))
                        )
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(theme.surfaceAlt.opacity(isPressed ? theme == .dark ? 0.12 : 0.6 : theme == .dark ? 0.08 : 0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
        .onTapGesture(perform: onOpen)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private func shortenedURL(_ url: String) -> String {
        url.replacingOccurrences(of: "https://", with: "")
           .replacingOccurrences(of: "http://", with: "")
    }
}

#Preview {
    ZStack {
        Color(hex: "#0F0F1A").ignoresSafeArea()
        ResultView(result: SongResult(
            title: "Blinding Lights",
            artist: "The Weeknd",
            album: "After Hours",
            releaseYear: "2020",
            thumbnailUrl: nil,
            songLinkUrl: "https://song.link/s/0VjIjW4GlUZAMYd2vXMi3b",
            platforms: [
                AppPlatformLink(platformKey: "spotify", displayName: "Spotify",
                                iconName: "spotify", accentColor: "#1DB954",
                                url: "https://open.spotify.com/track/0VjIjW4GlUZAMYd2vXMi3b",
                                nativeUrl: nil),
                AppPlatformLink(platformKey: "appleMusic", displayName: "Apple Music",
                                iconName: "applemusic", accentColor: "#FC3C44",
                                url: "https://music.apple.com/us/album/blinding-lights/1499378108",
                                nativeUrl: nil),
                AppPlatformLink(platformKey: "youtubeMusic", displayName: "YouTube Music",
                                iconName: "youtubemusic", accentColor: "#FF0000",
                                url: "https://music.youtube.com/watch?v=4NRXx6U8ABQ",
                                nativeUrl: nil),
            ]
        ), theme: .dark)
        .padding()
    }
    .preferredColorScheme(.dark)
}
