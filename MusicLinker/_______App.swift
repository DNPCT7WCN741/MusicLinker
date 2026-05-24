//
//  _______App.swift
//  我想让你也听上
//
//  Created by Tashkent on 2026/4/15.
//

import SwiftUI
import Combine

@main
struct _______App: App {
    @StateObject private var incomingURLState = IncomingURLState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(LanguageManager.shared)
                .environmentObject(incomingURLState)
                .onOpenURL { url in
                    if let musicURL = URLHandler.extractMusicURL(from: url) {
                        incomingURLState.pendingURL = musicURL
                    }
                }
        }
    }
}

final class IncomingURLState: ObservableObject {
    @Published var pendingURL: String?
}
