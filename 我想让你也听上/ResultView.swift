import SwiftUI
import UIKit
import CoreImage

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
        case .dark: return [Color(hex: "#11131D"), Color(hex: "#171E30"), Color(hex: "#0F1520")]
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
    @State private var copiedURL: String? = nil
    @State private var coverUIImage: UIImage?
    @State private var dominantColor = Color(hex: "#7C3AED")
    @State private var isShowingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var renderedPoster: UIImage?
    @State private var isShowingSaveAlert = false
    @State private var saveAlertMessage: String = ""
    @State private var photoSaver: PhotoSaver? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Song info card
            songInfoCard

            // Poster preview and download
            posterSection

            // Platform links
            VStack(spacing: 10) {
                HStack {
                    Text("在以下平台收听")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textSecondary.opacity(0.7))
                        .tracking(2)
                    Spacer()
                    Text("\(result.platforms.count) 个平台")
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
        .task(id: result.thumbnailUrl) {
            await loadCoverImage()
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ActivityViewController(activityItems: shareItems)
        }
    }

    // MARK: - Subviews

    private var songInfoCard: some View {
        HStack(spacing: 16) {
            // Album art placeholder or actual image
            AsyncImage(url: URL(string: result.thumbnailUrl ?? "")) { phase in
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
                    Text("生成海报")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text("适合朋友圈大图分享，并可直接保存到相册")
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

            HStack(spacing: 12) {
                Button(action: sharePoster) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("分享海报")
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
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 15, weight: .semibold))
                        Text("保存到相册")
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
            .alert(saveAlertMessage, isPresented: $isShowingSaveAlert) {
                Button("知道了", role: .cancel) {}
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
            Group {
                if let uiImage = coverUIImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 48)
                        .overlay(Color.black.opacity(0.45))
                } else {
                    LinearGradient(
                        colors: [dominantColor, dominantColor.opacity(0.75), Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
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

    private func sharePoster() {
        guard let image = renderPosterImage() else { return }
        copyAllPlatformLinksToClipboard()
        shareItems = [image]
        isShowingShareSheet = true
    }

    private func savePosterToAlbum() {
        guard let image = renderPosterImage() else { return }
        let saver = PhotoSaver { error in
            if let error = error {
                saveAlertMessage = "保存失败：\(error.localizedDescription)"
            } else {
                saveAlertMessage = "已保存到相册"
            }
            isShowingSaveAlert = true
            photoSaver = nil
        }
        photoSaver = saver
        UIImageWriteToSavedPhotosAlbum(image, saver, #selector(PhotoSaver.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    private func copyAllPlatformLinksToClipboard() {
        var linkText = result.platforms.map { "\($0.displayName)：\($0.url)" }.joined(separator: "\n")
        linkText += "\n\nsong.link：\(result.songLinkUrl)"
        UIPasteboard.general.string = linkText
    }

    private func loadCoverImage() async {
        guard let urlString = result.thumbnailUrl,
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
                Text("在 song.link 查看完整页面")
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
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func copyURL(_ urlString: String) {
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
}

class PhotoSaver: NSObject {
    private let completion: (Error?) -> Void

    init(completion: @escaping (Error?) -> Void) {
        self.completion = completion
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
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
