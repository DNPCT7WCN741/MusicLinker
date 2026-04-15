//
//  _______App.swift
//  我想让你也听上
//
//  Created by Tashkent on 2026/4/15.
//

import SwiftUI
import SwiftData

struct _______App: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup(content: {
            ContentView()
        })
        .modelContainer(sharedModelContainer)
    }
}
