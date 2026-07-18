// 2026-07-18 18:31 SGT
//
//  Item.swift
//  DocumentConsolidate
//
//  Created by Hei Long Xia on 18/7/26.
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
