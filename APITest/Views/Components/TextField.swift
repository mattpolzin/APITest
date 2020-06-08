//
//  TextField.swift
//  APITest
//
//  Created by Mathew Polzin on 6/7/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct TextField: View {
    let title: String
    @Binding var value: String
    let isValid: Bool

    var body: some View {
        SwiftUI.TextField(title, text: self.$value)
            .padding(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(self.isValid ? Color.secondary : Color.red, lineWidth: 2)
                    .animation(nil, value: self.isValid)
        )
    }
}
