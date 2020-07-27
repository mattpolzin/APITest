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

    let openAPISourceUri: String?
    let serverHostOverride: URL?
    let parser: API.Parser

    var openAPISource: Binding<String> {
        Binding(
            get: { self.openAPISourceUri ?? "" },
            set: { newValue in
                guard newValue.count > 0 else {
                    store.dispatch(NewTest.changeSourceUri(nil))
                    return
                }
                store.dispatch(NewTest.changeSourceUri(newValue))
            }
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

    var fastParser: Binding<Bool> {
        Binding(
            get: { self.parser == .fast },
            set: { fast in
                store.dispatch(NewTest.changeParser(fast ? .fast : .stable))
            }
        )
    }

    var body: some View {
        VStack {
            Text("New Test").font(.title)
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                Text("OpenAPI Source:").padding(.bottom, 4)
                TextField(title: "(leave blank for default)", value: self.openAPISource, isValid: true) // TODO: invalidate for bad values
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("API Server Override:").padding(.bottom, 4)
                TextField(title: "(leave blank to use documented source)", value: self.serverHost, isValid: true) // TODO: invalidate for bad values
            }
            SwiftUI.Toggle(isOn: self.fastParser) { Text("Use Fast Parser") }
            Spacer()
            HStack {
                StandardButton(
                    action: { store.dispatch(NewTest.cancelNewSource) },
                    label: "Cancel"
                )

                StandardButton(
                    action: {
                        store.dispatch(
                            API.StartTest.request(
                                .new(
                                    uri: self.openAPISourceUri,
                                    apiHostOverride: self.serverHostOverride,
                                    parser: self.parser
                                )
                            )
                        )
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
