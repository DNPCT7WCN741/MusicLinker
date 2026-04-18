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

enum AppTheme {
    case dark
    case light

    var preferredColorScheme: ColorScheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .dark:
            let colors: [Color] = [
                Color(hex: "#111310"),
                Color(hex: "#171E30"),
                Color(hex: "#0F1520")
            ]
            return colors
        case .light: return [Color.white, Color(hex: "#F7FBFF"), Color(hex: "#EDF4FF")]
        }
    }

    var surface: Color {
        switch self {
        case .dark: return Color(hex: "#111821")
        case .light: return Color.white
        }
    }

    var surfaceAlt: Color {
        switch self {
        case .dark: return Color(hex: "#182032")
        case .light: return Color(hex: "#F1F7FF")
        }
    }

    var accent: Color {
        switch self {
        case .dark: return Color(hex: "#1D4ED8")
        case .light: return Color(hex: "#2563EB")
        }
    }

    var accentSecondary: Color {
        switch self {
        case .dark: return Color(hex: "#3B82F6")
        case .light: return Color(hex: "#60A5FA")
        }
    }

    var textPrimary: Color {
        switch self {
        case .dark: return Color.white
        case .light: return Color(hex: "#0F172A")
        }
    }

    var textSecondary: Color {
        switch self {
        case .dark: return Color(hex: "#94A3B8")
        case .light: return Color(hex: "#475569")
        }
    }

    var cardStroke: Color {
        switch self {
        case .dark: return Color.white.opacity(0.08)
        case .light: return Color(hex: "#CBD5E1").opacity(0.25)
        }
    }
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
                        isCopied: copiedURL == platform.url,
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
            
            // Try to fetch album cover from Last.fm if not available
            if result.thumbnailUrl == nil || result.thumbnailUrl?.isEmpty == true {
                Task {
                    if let coverUrl = await AlbumCoverService.fetchAlbumCover(artist: result.artist, album: result.album ?? result.title) {
                        await MainActor.run {
                            lastFmCoverUrl = coverUrl
                            // Reload cover image with Last.fm URL
                            Task {
                                await loadCoverImage()
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewController(activityItems: shareItems)
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
        posterCard
            .aspectRatio(9.0 / 16.0, contentMode: .fit)
            .frame(width: 280)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: Color.black.opacity(0.25), radius: 20, x: 0, y: 10)
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
                // 背景主色
                dominantColor
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
                            .foregroundColor(dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.leading, hPad)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: stripHeight)
                    .background(secondaryColor)

                    // 第二条：专辑名 + 歌手
                    HStack {
                        Text(result.album ?? "")
                            .font(.system(size: w * 0.075, weight: .bold))
                            .foregroundColor(dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.leading, hPad)
                        Spacer()
                        Text(result.artist)
                            .font(.system(size: w * 0.06, weight: .semibold))
                            .foregroundColor(dominantColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .padding(.trailing, hPad)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: stripHeight)
                    .background(tertiaryColor)

                    // 底部留白，和色带等高
                    dominantColor
                        .frame(height: stripHeight)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 42))
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
        let content = posterCard
            .frame(width: w, height: h)
            .environment(\.displayScale, 1)
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
        var linkText = result.platforms.map { "\($0.displayName)：\($0.url)" }.joined(separator: "\n")
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
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func copyURL(_ urlString: String) {
        buttonFeedback()
        UIPasteboard.general.string = urlString
        withAnimation(.spring(response: 0.3)) {
            copiedURL = urlString
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedURL = nil
            }
        }
    }

    private func buttonFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
