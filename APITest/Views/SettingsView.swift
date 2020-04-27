//
//  SettingsView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/16/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct SettingsView: View {
    let settingsEditorState: AppState.SettingsEditor?

    var host: Binding<String> {
        Binding(
            get: { self.settingsEditorState?.host ?? "" },
            set: { store.dispatch(Settings.changeHost(proposedURL: $0)) }
        )
    }

    var body: some View {
        ZStack {
            settingsEditorState.map { settingsEditorState in
                HStack(spacing: 0) {
                    Rectangle().fill(Color.secondary).frame(width: 2)
                    VStack {
                        Text("Settings").font(.title)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("API Test Host:").padding(.bottom, 4)
                            Text("The host of the API Testing Service, not the service being tested.").italic().font(.footnote).padding(.bottom, 5)
                            HStack {
                                TextField("Host", text: self.host)
                                .padding(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(settingsEditorState.$host.isValid ? Color.secondary : Color.red, lineWidth: 2)
                                        .animation(nil, value: settingsEditorState.$host.isValid)
                                )
                            }
                        }.padding([.leading, .trailing], 12)
                        Spacer()
                    }.frame(maxHeight: .infinity)
                        .background(Rectangle().fill(Color(.secondarySystemBackground)))
                }.transition(.move(edge: .trailing))
                    .animation(.easeInOut(duration: 0.25))
            }
        }
    }
}
