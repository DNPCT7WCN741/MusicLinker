import SwiftUI

// MARK: - Share Extension Support
// This file provides URL scheme handling so other apps (Spotify, Apple Music, etc.)
// can share a song link directly to MusicLinker.
//
// Setup in Info.plist:
// Add URL Scheme: "musiclinker"
// So that links like "musiclinker://open?url=..." will launch the app.

struct URLHandler {
    static func extractMusicURL(from incomingURL: URL) -> String? {
        // Handle custom scheme: musiclinker://open?url=https://...
        if incomingURL.scheme == "musiclinker",
           let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
           let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value {
            return urlParam
        }

        // Handle universal links / direct music URLs
        let urlString = incomingURL.absoluteString
        let supportedDomains = [
            "open.spotify.com",
            "music.apple.com",
            "music.youtube.com",
            "tidal.com",
            "deezer.com",
            "music.amazon.com",
            "soundcloud.com",
            "pandora.com",
            "song.link",
            "odesli.co"
        ]

        for domain in supportedDomains {
            if urlString.contains(domain) {
                return urlString
            }
        }

        return nil
    }
}

// MARK: - App Info.plist additions (README)
/*
 Add the following to your Info.plist to enable URL scheme handling:

 <key>CFBundleURLTypes</key>
 <array>
     <dict>
         <key>CFBundleURLSchemes</key>
         <array>
             <string>musiclinker</string>
         </array>
         <key>CFBundleURLName</key>
         <string>com.yourapp.musiclinker</string>
     </dict>
 </array>

 And add this to handle incoming URLs in your App struct:

 struct MusicLinkerApp: App {
     var body: some Scene {
         WindowGroup {
             ContentView()
                 .onOpenURL { url in
                     if let musicURL = URLHandler.extractMusicURL(from: url) {
                         // Pass to ContentView via @StateObject or NotificationCenter
                         NotificationCenter.default.post(
                             name: .init("IncomingMusicURL"),
                             object: musicURL
                         )
                     }
                 }
         }
     }
 }
 */
