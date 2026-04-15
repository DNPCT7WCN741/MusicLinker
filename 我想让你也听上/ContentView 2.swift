import SwiftUI
import Combine

// 2. 定义视图
struct ContentView: View {
    // 使用 @StateObject 管理服务实例
    @StateObject private var service = OdesliService()
    
    @State private var inputURL = ""
    @State private var isShowingResult = false
    @State private var theme: AppTheme = .dark
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: theme.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                // Ambient orbs
                GeometryReader { geo in
                    Circle()
                        .fill(theme.accent.opacity(0.15))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(x: -50, y: 100)

                    Circle()
                        .fill(theme.accentSecondary.opacity(0.12))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                        .offset(x: geo.size.width - 150, y: geo.size.height - 300)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView
                        .padding(.top, 20)

                    // Main content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Search card
                            searchCard

                            // Result or placeholder
                            if service.isLoading {
                                loadingView
                            } else if let error = service.errorMessage {
                                errorView(message: error)
                            } else if let result = service.result {
                                ResultView(result: result, theme: theme)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            } else {
                                placeholderView
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(theme.preferredColorScheme)
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("MusicLinker")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.textPrimary, theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Button(action: toggleTheme) {
                    Image(systemName: theme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .foregroundColor(theme.textPrimary)
                        .background(
                            Circle()
                                .fill(theme.surfaceAlt)
                        )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var searchCard: some View {
        VStack(spacing: 16) {
            // Label
            HStack {
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                    .foregroundColor(theme.accent)
                Text("粘贴音乐链接")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Spacer()
            }

            // Input field
            HStack(spacing: 12) {
                TextField("", text: $inputURL, prompt: Text("支持 Spotify / Apple Music / 网易云 / 酷狗…")
                    .foregroundColor(theme.textSecondary.opacity(0.6))
                    .font(.system(size: 14))
                )
                .font(.system(size: 14))
                .foregroundColor(theme.textPrimary)
                .focused($isInputFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .submitLabel(.search)
                .onSubmit { search() }

                if !inputURL.isEmpty {
                    Button(action: { inputURL = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.4))
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.25 : 0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isInputFocused
                                    ? theme.accent.opacity(0.6)
                                    : theme.cardStroke,
                                lineWidth: 1
                            )
                    )
            )

            // Paste & Search buttons
            HStack(spacing: 12) {
                Button(action: pasteFromClipboard) {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(theme.accent.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                                )
                        )
                }

                Button(action: search) {
                    Label("搜索", systemImage: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: inputURL.isEmpty
                                            ? [theme.surfaceAlt, theme.surface]
                                            : [theme.accent, theme.accentSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .disabled(inputURL.isEmpty)
                .opacity(inputURL.isEmpty ? 0.5 : 1)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.18 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: theme.accent))
                .scaleEffect(1.4)

            Text("正在查找各平台链接…")
                .font(.system(size: 14))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.16 : 0.8))
        )
    }


    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(Color(hex: "#F87171"))

            Text("无法获取链接")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(theme.textPrimary)

            Text(message)
                .font(.system(size: 13))
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "#7F1D1D").opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#F87171").opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var placeholderView: some View {
        VStack(spacing: 16) {
            // Supported platforms grid
            VStack(spacing: 12) {
                Text("支持的平台")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textSecondary.opacity(0.7))
                    .tracking(2)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(supportedPlatforms, id: \.name) { platform in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: platform.color))
                                .frame(width: 8, height: 8)
                            Text(platform.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.15 : 0.72))
                        )
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(theme.surfaceAlt.opacity(theme == .dark ? 0.18 : 0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(theme.cardStroke, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Actions
    
    private func pasteFromClipboard() {
        if let string = UIPasteboard.general.string {
            inputURL = string
        }
    }
    
    private func search() {
        guard !inputURL.isEmpty else { return }
        isInputFocused = false
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            Task {
                await service.fetchLinks(url: inputURL)
            }
        }
    }

    private func toggleTheme() {
        theme = theme == .dark ? .light : .dark
    }

    // MARK: - Data

    private let supportedPlatforms = [
        (name: "Spotify", color: "#1DB954"),
        (name: "Apple Music", color: "#FC3C44"),
        (name: "YouTube Music", color: "#FF0000"),
        (name: "网易云音乐", color: "#E60026"),
        (name: "Tidal", color: "#7B68EE"),
        (name: "Deezer", color: "#A238FF"),
        (name: "Amazon Music", color: "#00A8E1"),
        (name: "SoundCloud", color: "#FF5500"),
        (name: "Pandora", color: "#3668FF"),
    ]
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
}
