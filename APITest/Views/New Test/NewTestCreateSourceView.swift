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
    
    var body: some View {
        VStack {
            Text("New Test").font(.title)
            Spacer()
            HStack {
                StandardButton(
                    action: { store.dispatch(NewTest.cancelNewSource) },
                    label: "Cancel"
                )

                StandardButton(
                    action: {
                        // TODO: fill out uri and host override
                        store.dispatch(API.StartTest.request(.new(uri: "", apiHostOverride: nil)))
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
