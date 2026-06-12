//
//  Item.swift
//  tecSwiftChallenge2026
//
//  Created by Manuel Antonio Perez Fonseca on 11/06/26.
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
