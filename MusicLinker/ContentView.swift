//
//  ContentView.swift
//  我想让你也听上
//
//  Created by Tashkent on 2026/4/15.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Search History Model
struct SearchHistoryItem: Identifiable, Codable {
    let id: UUID
    let url: String
    let timestamp: Date
    let title: String?
    let artist: String?

    var displayText: String {
        if let title = title, let artist = artist {
            return "\(title) - \(artist)"
        } else {
            return url
        }
    }
    
    init(url: String, timestamp: Date, title: String?, artist: String?) {
        self.id = UUID()
        self.url = url
        self.timestamp = timestamp
        self.title = title
        self.artist = artist
    }
}

// MARK: - Main View
struct ContentView: View {
    @StateObject private var service = OdesliService()
    @EnvironmentObject var languageManager: LanguageManager
    
    @State private var inputURL = ""
    @State private var isShowingResult = false
    @State private var theme: AppTheme = .dark
    @FocusState private var isInputFocused: Bool
    
    @State private var searchHistory: [SearchHistoryItem] = []
    @State private var isShowingHistoryMenu = false
    @State private var selectedHistoryItem: SearchHistoryItem?
    @State private var historyLoaded = false
    @State private var isShowingLanguageMenu = false
    @State private var isShowingAPISettings = false
    @State private var neteaseAPIURL = ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: theme.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView
                        .padding(.top, 20)

                    ScrollView {
                        VStack(spacing: 24) {
                            searchCard

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
            .background(
                GeometryReader { geo in
                    ZStack {
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
                }
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
        }
        .preferredColorScheme(theme.preferredColorScheme)
        .onAppear {
            loadThemePreference()
            loadHistoryFromStorage()
        }
    }

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text("MusicLinker")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.textPrimary, theme.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Spacer()

                Menu {
                    if searchHistory.isEmpty {
                        Text(languageManager.translate("history.empty"))
                            .foregroundColor(.gray)
                    } else {
                        ForEach(searchHistory.prefix(10)) { item in
                            Button(action: { selectHistoryItem(item) }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayText)
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(1)
                                    Text(item.timestamp, style: .date)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        
                        if searchHistory.count > 10 {
                            Divider()
                            Button(role: .destructive, action: clearSearchHistory) {
                                Label(languageManager.translate("history.clear"), systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .foregroundColor(theme.textPrimary)
                        .background(
                            Circle()
                                .fill(theme.surfaceAlt)
                        )
                }
                .id("historyMenu-\(searchHistory.count)")
                
                Menu {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Button(action: { languageManager.setLanguage(language) }) {
                            HStack {
                                Text(language.displayName)
                                Spacer()
                                if languageManager.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .foregroundColor(theme.textPrimary)
                        .background(
                            Circle()
                                .fill(theme.surfaceAlt)
                        )
                }
                .id("languageMenu")

                Menu {
                    ForEach(AppTheme.allCases, id: \.self) { themeOption in
                        Button(action: { selectTheme(themeOption) }) {
                            HStack {
                                Image(systemName: themeOption.icon)
                                Text(themeOption.displayName)
                                Spacer()
                                if theme == themeOption {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeOption.accent)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: theme.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .foregroundColor(theme.textPrimary)
                        .background(
                            Circle()
                                .fill(theme.surfaceAlt)
                        )
                }
                .id("themeMenu")
                
                // API 设置按钮
                Button(action: {
                    neteaseAPIURL = service.getNeteaseAPIBaseURL()
                    isShowingAPISettings = true
                }) {
                    Image(systemName: "gearshape.fill")
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
        .sheet(isPresented: $isShowingAPISettings) {
            APISettingsSheet(neteaseAPIURL: $neteaseAPIURL, isPresented: $isShowingAPISettings, service: service)
                .presentationDetents([.medium])
        }
    }

    private var searchCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "music.note")
                    .font(.system(size: 13))
                    .foregroundColor(theme.accent)
                Text(languageManager.translate("header.pasteLink"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accent)
                Spacer()
            }

            HStack(spacing: 12) {
                TextField("", text: $inputURL, prompt: Text(languageManager.translate("search.placeholder"))
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

            HStack(spacing: 12) {
                Button(action: pasteFromClipboard) {
                    Label(languageManager.translate("button.paste"), systemImage: "doc.on.clipboard")
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
                    Label(languageManager.translate("button.search"), systemImage: "magnifyingglass")
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

            Text(languageManager.translate("loading.text"))
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

            Text(languageManager.translate("error.title"))
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
            VStack(spacing: 12) {
                Text(languageManager.translate("platforms.title"))
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
        buttonFeedback()
        if let string = UIPasteboard.general.string {
            inputURL = string
        }
    }
    
    private func search() {
        guard !inputURL.isEmpty else { return }
        buttonFeedback()
        isInputFocused = false

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            Task {
                await service.fetchLinks(url: inputURL)
                if let result = service.result {
                    saveToHistory(url: inputURL, title: result.title, artist: result.artist)
                }
            }
        }
    }

    private func selectTheme(_ newTheme: AppTheme) {
        buttonFeedback()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            theme = newTheme
        }
        saveThemePreference(newTheme)
    }
    
    private func saveThemePreference(_ theme: AppTheme) {
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")
    }
    
    private func loadThemePreference() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            self.theme = theme
        }
    }

    private func buttonFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func saveToHistory(url: String, title: String? = nil, artist: String? = nil) {
        searchHistory.removeAll { $0.url == url }

        let newItem = SearchHistoryItem(
            url: url,
            timestamp: Date(),
            title: title,
            artist: artist
        )
        searchHistory.insert(newItem, at: 0)

        if searchHistory.count > 50 {
            searchHistory = Array(searchHistory.prefix(50))
        }

        saveHistoryToStorage()
    }

    private func selectHistoryItem(_ item: SearchHistoryItem) {
        inputURL = item.url
        buttonFeedback()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            search()
        }
    }

    private func clearSearchHistory() {
        searchHistory.removeAll()
        saveHistoryToStorage()
    }

    private func saveHistoryToStorage() {
        if let data = try? JSONEncoder().encode(searchHistory) {
            UserDefaults.standard.set(data, forKey: "searchHistory")
        }
    }

    private func loadHistoryFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "searchHistory"),
           let history = try? JSONDecoder().decode([SearchHistoryItem].self, from: data) {
            searchHistory = history
        }
    }

    private let supportedPlatforms = [
        (name: "Spotify", color: "#1DB954"),
        (name: "Apple Music", color: "#FC3C44"),
        (name: "YouTube Music", color: "#FF0000"),
        (name: "网易云音乐", color: "#E60026"),
        (name: "QQ 音乐", color: "#31C27C"),
        (name: "Tidal", color: "#7B68EE"),
        (name: "Deezer", color: "#A238FF"),
        (name: "Amazon Music", color: "#00A8E1"),
        (name: "SoundCloud", color: "#FF5500"),
        (name: "Pandora", color: "#3668FF"),
    ]
}

// MARK: - API Settings Sheet
struct APISettingsSheet: View {
    @Binding var neteaseAPIURL: String
    @Binding var isPresented: Bool
    let service: OdesliService
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://your-api.com", text: $neteaseAPIURL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                } header: {
                    Text("网易云音乐 API 地址")
                } footer: {
                    Text("可选功能。留空则使用搜索链接（默认，推荐）。\n填入地址后可获取精确歌曲链接。\n\n当前状态：\(service.isNeteaseAPIEnabled ? "已启用 API 模式" : "使用搜索链接")")
                }
            }
            .navigationTitle("API 设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        service.setNeteaseAPIBaseURL(neteaseAPIURL)
                        isPresented = false
                    }
                }
            }
        }
    }
}

