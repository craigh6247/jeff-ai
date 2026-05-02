//
//  Item.swift
//  Jeff AI
//
//  Created by Craig Hollington on 02/05/2026.
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
