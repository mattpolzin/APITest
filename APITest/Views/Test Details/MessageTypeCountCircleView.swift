//
//  MessageTypeCountCircleView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/25/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels

struct MessageTypeCountCircleView: View {
    let count: Int?
    let messageType: API.MessageType
    let filtered: Bool

    var body: some View {
        ZStack {
            Text("00").opacity(0)
                .padding(5)
                .background(Circle().stroke(messageType.color, lineWidth: 3))
            count.map { Text("\($0)") }
        }.opacity(filtered ? 1.0 : 0.5)
    }
}
