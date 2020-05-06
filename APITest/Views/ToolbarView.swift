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
    let settingsTrayOpen: Bool
    let newTestButtonDisabled: Bool
    let settingsButtonDisabled: Bool

    var body: some View {
        HStack {
            StandardButton(
                action: {
                    store.dispatch(API.GetAllProperties.request)
                    store.dispatch(NewTest.open)
            },
                label: "New Test"
            ).disabled(newTestButtonDisabled)

            Spacer()

            Text("\(buildingAndRunningTestCount) building/running")

            Self.divider

            Text("\(finishedTodayTestCount) finished today")
            Spacer().frame(maxWidth: .infinity)

            Image("Settings")
                .renderingMode(.template)
                .resizable()
                .rotationEffect(.degrees(settingsTrayOpen ? -90.0 : 0.0)).animation(.easeInOut(duration: 0.25))
                .foregroundColor(settingsButtonDisabled ? .gray : .accentColor)
                .padding(8).frame(width: 46, height: 46)
                .onTapGesture {
                    store.dispatch(Settings.toggleOpen)
            }
            .disabled(settingsButtonDisabled)

            Spacer()

            Button(action: { store.dispatch(Help.open) }, label: { Image("Help").resizable() })
                .padding(8)
                .frame(width: 46, height: 46)
        }
    }

    static var divider: some View {
        Rectangle().fill(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.secondary.opacity(0.5), Color.clear]), startPoint: .top, endPoint: .bottom))
            .frame(idealWidth: 2, idealHeight: 44).fixedSize()
    }
}
