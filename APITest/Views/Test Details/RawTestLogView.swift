//
//  RawTestLogView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/25/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

// TODO: loading indication

struct RawTestLogView: View {
    let logs: String

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            Text(logs).font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
        }
    }
}
