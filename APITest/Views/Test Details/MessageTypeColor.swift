//
//  MessageTypeColor.swift
//  APITest
//
//  Created by Mathew Polzin on 4/25/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels

extension API.MessageType {
    var color: SwiftUI.Color {
        switch self {
        case .debug, .info:
            return .gray
        case .warning:
            return .yellow
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}
