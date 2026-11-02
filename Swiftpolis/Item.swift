//
//  Item.swift
//  Swiftpolis
//
//  Created by Amir Abravesh on 11/3/26.
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
