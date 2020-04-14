//
//  StandardButton.swift
//  APITest
//
//  Created by Mathew Polzin on 4/13/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct StandardButton: View {
    let action: () -> Void
    let label: String

    var body: some View {
        Button(action: action) {
            Text(label)
        }.background(Color.clear)
            .padding(8)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
            .padding(10)
    }
}
