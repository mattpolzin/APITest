//
//  ToolbarView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/12/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels

struct ToolbarView: View {
    let buildingAndRunningTestCount: Int
    let finishedTodayTestCount: Int

    var body: some View {
        HStack {
            StandardButton(
                action: { store.dispatch(NewTest.open) },
                label: "New Test"
            )
            Spacer()
            Text("\(buildingAndRunningTestCount) build/running")
            Rectangle().fill(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.secondary.opacity(0.5), Color.clear]), startPoint: .top, endPoint: .bottom))
                .frame(idealWidth: 2, idealHeight: 44).fixedSize()
            Text("\(finishedTodayTestCount) finished today")
            Spacer().frame(maxWidth: .infinity)
        }
    }
}
