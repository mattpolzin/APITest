//
//  NewTestSelectSourceView.swift
//  APITest
//
//  Created by Mathew Polzin on 6/7/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import ReSwift

struct NewTestSelectSourceView: View {

    let propertiesOptions: [NewTestModalView.RequestProperties]
    @Binding var selectedProperties: NewTestModalView.RequestProperties
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack {
                    Text("New Test").font(.title)
                    List {
                        ForEach(self.propertiesOptions) { properties in
                            ZStack(alignment: .center) {
                                Rectangle().fill(properties == self.selectedProperties ? Color.accentColor : Color.clear)
                                HStack { ForEach(0..<properties.textViews.count) { properties.textViews[$0] } }
                            }.contentShape(Rectangle())
                                .onTapGesture { self.selectedProperties = properties }
                                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                        }
                    }
                    HStack {
                        StandardButton(
                            action: { store.dispatch(NewTest.dismiss) },
                            label: "Cancel"
                        )

                        StandardButton(
                            action: {
                                for action in self.selectedProperties.actions {
                                    store.dispatch(action)
                                }
                        },
                            label: "Start"
                        )
                    }.padding(.top, 5)
                }.padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 3).fill(Color(.secondarySystemBackground))
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                            .shadow(radius: 1)
                ).preference(key: SizePreferenceKey.self, value: geometry.size)
            }
        }
    }
}
