//
//  SearchTextField.swift
//  APITest
//
//  Created by Mathew Polzin on 4/26/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct SearchTextField: View {

    let filterText: String

    var filter: Binding<String> {
        Binding(
            get: { self.filterText },
            set: { store.dispatch(Filter.apply($0)) }
        )
    }

    var body: some View {
        ZStack {
            TextField("Filter", text: self.filter)
            .padding([.top, .bottom], 5).padding([.leading, .trailing], 10)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.secondary, lineWidth: 2)
            )
        }
    }
}
