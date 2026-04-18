//
//  Item.swift
//  我想让你也听上
//
//  Created by Tashkent on 2026/4/15.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
