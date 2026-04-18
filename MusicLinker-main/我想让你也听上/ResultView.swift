import SwiftUI
import UIKit
import AVFoundation
import CoreImage

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
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var renderedPoster: UIImage?
    @State private var isShowingSaveAlert = false
    @State private var saveAlertMessage: String = ""
    @State private var previewURL: URL? = nil
    @State private var videoURL: URL? = nil
    @State private var isGeneratingVideo: Bool = false
    @State private var errorMessage: String? = nil
    @State private var videoSaver: VideoSaver? = nil
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
        .alert(saveAlertMessage, isPresented: $isShowingSaveAlert) {
            Button(languageManager.translate("result.ok"), role: .cancel) {}
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
                    Text("已找到 \(result.platforms.count) 个平台链接")
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
                Button(action: generateVideo) {
                    HStack(spacing: 10) {
                                Image(systemName: "film")
                            .font(.system(size: 16, weight: .semibold))
                        Text(languageManager.translate("result.generateVideo"))
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
                .disabled(isGeneratingVideo)
                .overlay(
                    Group {
                        if isGeneratingVideo {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }
                )

                HStack(spacing: 12) {
                    Button(action: shareVideo) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                            Text(languageManager.translate("result.shareVideo"))
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

                    Button(action: saveVideoToAlbum) {
                        HStack(spacing: 10) {
                            Image(systemName: "video")
                                .font(.system(size: 15, weight: .semibold))
                            Text(languageManager.translate("result.saveVideo"))
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
        ZStack {
            Rectangle()
                .fill(dominantColor)
                .opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer(minLength: 24)

                if let uiImage = coverUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                        .background(Color.black.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(dominantColor.opacity(0.85), lineWidth: 6)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 18, x: 0, y: 12)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 56))
                                .foregroundColor(Color.white.opacity(0.35))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(dominantColor.opacity(0.85), lineWidth: 6)
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 18, x: 0, y: 12)
                }

                VStack(spacing: 8) {
                    Text(result.title)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: 250)

                    Text(result.artist)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .frame(maxWidth: 250)

                    if let album = result.album {
                        Text(album)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(theme.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .frame(maxWidth: 250)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    if let year = result.releaseYear {
                        Text(year)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(theme.accent.opacity(0.15))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    Text("song.link")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(theme.accent.opacity(0.15))
                        .clipShape(Capsule())
                }
                .frame(maxWidth: 250)
                .padding(.bottom, 20)
            }
            .padding(.horizontal, 18)
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
        let renderer = ImageRenderer(content: posterCard.frame(width: 1080, height: 1920))
        renderer.scale = 3
        let image = renderer.uiImage
        renderedPoster = image
        return image
    }

    private func shareVideo() {
        buttonFeedback()
        createPosterVideo { result in
            switch result {
            case .success(let url):
                shareItems = [url]
                isShowingShareSheet = true
            case .failure(let error):
                errorMessage = "生成视频失败：\(error.localizedDescription)"
            }
        }
    }

    private func generateVideo() {
        buttonFeedback()
        createPosterVideo { result in
            switch result {
            case .success:
                saveAlertMessage = "视频已生成，您可以分享或保存它。"
                isShowingSaveAlert = true
            case .failure(let error):
                errorMessage = "生成视频失败：\(error.localizedDescription)"
            }
        }
    }

    private func saveVideoToAlbum() {
        buttonFeedback()
        createPosterVideo { result in
            switch result {
            case .success(let url):
                let saver = VideoSaver { error in
                    if let error = error {
                        saveAlertMessage = "保存失败：\(error.localizedDescription)"
                    } else {
                        saveAlertMessage = "已保存视频到相册"
                    }
                    isShowingSaveAlert = true
                }
                videoSaver = saver
                UISaveVideoAtPathToSavedPhotosAlbum(url.path, saver, #selector(VideoSaver.video(_:didFinishSavingWithError:contextInfo:)), nil)
            case .failure(let error):
                saveAlertMessage = "保存失败：\(error.localizedDescription)"
                isShowingSaveAlert = true
            }
        }
    }

    private func createPosterVideo(completion: @escaping (Result<URL, Error>) -> Void) {
        if let existing = videoURL {
            completion(.success(existing))
            return
        }

        guard let image = renderPosterImage() else {
            completion(.failure(NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法渲染海报图像"])))
            return
        }

        let currentPreviewURL = previewURL
        isGeneratingVideo = true

        Task.detached(priority: .userInitiated) { [image, currentPreviewURL] in
            do {
                let audioURL = try await self.getPreviewAudioURL(existingPreviewURL: currentPreviewURL)
                if currentPreviewURL == nil {
                    await MainActor.run {
                        self.previewURL = audioURL
                    }
                }
                let videoFile = try await self.makeVideoFile(with: image, audioURL: audioURL)
                await MainActor.run {
                    self.videoURL = videoFile
                    self.isGeneratingVideo = false
                    completion(.success(videoFile))
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingVideo = false
                    self.errorMessage = "生成视频失败：\(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }

    private func getPreviewAudioURL(existingPreviewURL: URL?) async throws -> URL {
        if let url = existingPreviewURL {
            return url
        }
        let query = "\(result.title) \(result.artist)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法构造试听请求"])
        }

        if let deezerURL = try await searchDeezerPreview(query: encodedQuery) {
            return deezerURL
        }

        guard let token = try await fetchSpotifyAccessToken() else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取访问令牌"])
        }

        guard let url = URL(string: "https://api.spotify.com/v1/search?q=track:\"\(result.title)\" artist:\"\(result.artist)\"&type=track&limit=5") else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法构造试听请求"])
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

        previewURL = previewLink
        return previewLink
    }

    private func makeVideoFile(with image: UIImage, audioURL: URL) async throws -> URL {
        let size = CGSize(width: 720, height: 1280)
        let resizedImage = resizeImage(image, targetSize: size)
        guard let pixelBuffer = pixelBuffer(from: resizedImage, width: Int(size.width), height: Int(size.height)) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法生成像素缓冲区"])
        }

        let videoURL = FileManager.default.temporaryDirectory.appendingPathComponent("video_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: videoURL)

        let writer = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height)
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: attributes)

        guard writer.canAdd(videoInput) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法添加视频输入"])
        }
        writer.add(videoInput)

        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let totalFrames = 450
        for frameIndex in 0..<totalFrames {
            let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: 30)
            if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                throw writer.error ?? NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "写入视频帧失败"])
            }
        }

        videoInput.markAsFinished()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            writer.finishWriting {
                if let error = writer.error {
                    continuation.resume(throwing: error)
                } else {
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let finalURL = try self.addAudioToVideo(videoURL: videoURL, audioURL: audioURL)
                            try? FileManager.default.removeItem(at: videoURL)
                            continuation.resume(returning: finalURL)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    private func addAudioToVideo(videoURL: URL, audioURL: URL) throws -> URL {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)
        let composition = AVMutableComposition()

        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取视频轨道"])
        }
        let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionVideoTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)

        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取音频轨道"])
        }
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        try compositionAudioTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: audioTrack, at: .zero)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("final_\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outputURL)

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "ResultView", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法创建导出会话"])
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?

        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                semaphore.signal()
            } else if let error = exportSession.error {
                exportError = error
                semaphore.signal()
            }
        }

        semaphore.wait()

        if let error = exportError {
            throw error
        }

        return outputURL
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            UIColor.black.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()

            let aspect = min(targetSize.width / image.size.width, targetSize.height / image.size.height)
            let newSize = CGSize(width: image.size.width * aspect, height: image.size.height * aspect)
            let x = (targetSize.width - newSize.width) / 2.0
            let y = (targetSize.height - newSize.height) / 2.0
            image.draw(in: CGRect(x: x, y: y, width: newSize.width, height: newSize.height))
        }
    }

    private func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
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
            let averageUIColor = image.averageColor ?? UIColor(named: "AccentColor") ?? UIColor.systemPurple
            await MainActor.run {
                coverUIImage = image
                dominantColor = Color(averageUIColor)
            }
        } catch {
            // ignore load errors and keep default gradient
        }
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

class VideoSaver: NSObject {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        completion(error)
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
