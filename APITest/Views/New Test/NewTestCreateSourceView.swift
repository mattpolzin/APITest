//
//  NewTestCreateSourceView.swift
//  APITest
//
//  Created by Mathew Polzin on 6/7/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import ReSwift
import APIModels

struct NewTestCreateSourceView: View {

    let openAPISourceUri: String
    let serverHostOverride: URL?

    var openAPISource: Binding<String> {
        Binding(
            get: { self.openAPISourceUri },
            set: { store.dispatch(NewTest.changeSourceUri($0)) }
        )
    }

    var serverHost: Binding<String> {
        Binding(
            get: { self.serverHostOverride?.absoluteString ?? "" },
            set: { newValue in
                guard newValue.count > 0 else {
                    store.dispatch(NewTest.changeServerOverride(nil))
                    return
                }
                store.dispatch(NewTest.changeServerOverride(newValue))
            }
        )
    }

    var body: some View {
        VStack {
            Text("New Test").font(.title)
            Spacer()
            TextField(title: "OpenAPI Source", value: self.openAPISource, isValid: true) // TODO: invalidate for bad values
            TextField(title: "API Server Override", value: self.serverHost, isValid: true) // TODO: invalidate for bad values
            Spacer()
            HStack {
                StandardButton(
                    action: { store.dispatch(NewTest.cancelNewSource) },
                    label: "Cancel"
                )

                StandardButton(
                    action: {
                        store.dispatch(API.StartTest.request(.new(uri: self.openAPISourceUri, apiHostOverride: self.serverHostOverride)))
                        store.dispatch(NewTest.dismiss)
                },
                    label: "Start"
                )
            }.padding(.top, 5)
        }.padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 3).fill(Color(.secondarySystemBackground))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                    .shadow(radius: 1)
        )
    }
}
