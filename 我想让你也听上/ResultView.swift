import SwiftUI

struct ResultView: View {
    let result: SongResult
    @State private var copiedURL: String? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Song info card
            songInfoCard

            // Platform links
            VStack(spacing: 10) {
                HStack {
                    Text("在以下平台收听")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.3))
                        .tracking(2)
                    Spacer()
                    Text("\(result.platforms.count) 个平台")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.25))
                }
                .padding(.horizontal, 4)

                ForEach(result.platforms) { platform in
                    PlatformLinkRow(
                        platform: platform,
                        isCopied: copiedURL == platform.url,
                        onOpen: { openURL(platform.nativeUrl ?? platform.url) },
                        onCopy: { copyURL(platform.url) }
                    )
                }
            }

            // Song.link button
            songLinkButton
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
                            .foregroundColor(.white.opacity(0.6))
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
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(result.artist)
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.55))
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
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
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
            .foregroundColor(Color(hex: "#A78BFA").opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#7C3AED").opacity(0.2), lineWidth: 1)
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

// MARK: - Platform Link Row

struct PlatformLinkRow: View {
    let platform: AppPlatformLink
    let isCopied: Bool
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
                    .foregroundColor(.white)

                Text(shortenedURL(platform.url))
                    .font(.system(size: 11))
                    .foregroundColor(Color.white.opacity(0.35))
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
                                : Color.white.opacity(0.4)
                        )
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(
                                    isCopied
                                        ? Color(hex: "#4ADE80").opacity(0.15)
                                        : Color.white.opacity(0.07)
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
                .fill(Color.white.opacity(isPressed ? 0.08 : 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
        ))
        .padding()
    }
    .preferredColorScheme(.dark)
}
