//
//  NewTestView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/13/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels
import JSONAPI

struct NewTestModalView: View {

    @State private var selectedProperties: RequestProperties = .default
    let isPresented: Bool

    let propertiesOptions: [RequestProperties]

    init(entityCache: EntityCache, selection: API.APITestProperties.Id? = nil, isPresented: Bool) {

        let existingOptions: [RequestProperties] = entityCache.testProperties.values
            .compactMap { properties in (properties ~> \.openAPISource).materialized(from: entityCache).map { (properties, $0) } }
            .map { (properties, source) in
                .existing(properties.id, sourceUri: source.uri, apiHostOverride: properties.apiHostOverride?.absoluteString)
        }

        let selectedProperties: RequestProperties? = selection.flatMap { $0.materialized(from: entityCache) }
            .flatMap { properties in (properties ~> \.openAPISource).materialized(from: entityCache).map { (properties, $0) } }
            .map { (properties, source) in
                .existing(properties.id, sourceUri: source.uri, apiHostOverride: properties.apiHostOverride?.absoluteString)
        }

        self.init(properties: [.default] + existingOptions, selection: selectedProperties, isPresented: isPresented)
    }

    init(properties: [RequestProperties], selection: RequestProperties? = nil, isPresented: Bool) {
        self.propertiesOptions = properties
        self.isPresented = isPresented
        self.selectedProperties = selection ?? .default
    }

    var body: some View {
        ZStack {
            if isPresented {
                VStack {
                    Text("New Test").font(.title)
                    List {
                        ForEach(propertiesOptions) { properties in
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
                                store.dispatch(self.selectedProperties.action)
                                store.dispatch(NewTest.dismiss)
                            },
                            label: "Start"
                        )
                    }.padding(.top, 5)
                }.padding(10)
                 .background(
                    RoundedRectangle(cornerRadius: 3).fill(Color(.secondarySystemBackground))
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary))
                        .shadow(radius: 1)
                )
            }
        }.animation(.easeInOut(duration: 0.05))
    }
}

extension NewTestModalView {
    enum RequestProperties: Equatable, Swift.Identifiable, CustomStringConvertible {
        case `default`
        case new(uri: String)
        case existing(API.APITestProperties.Id, sourceUri: String, apiHostOverride: String?)

        var description: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(_, let sourceUri, let hostOverride):
                return "docs: \(sourceUri)" + (hostOverride.map { ", server: \($0)" } ?? "")
            }
        }

        var id: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(let id, _, _):
                return id.rawValue.uuidString
            }
        }

        var textViews: [Text] {
            switch self {
            case .default, .new:
                return [ Text(description).bold() ]
            case .existing(_, let sourceUri, let hostOverride):
                return [ Text("docs: ").bold(), Text(sourceUri).italic() ] + (hostOverride.map { [ Text(", "), Text("server: ").bold(), Text($0).italic() ] } ?? [])
            }
        }

        var action: API.StartTest {
            switch self {
            case .default:
                return API.StartTest.request(.default)
            case .new(uri: let uri):
                return API.StartTest.request(.new(uri: uri))
            case .existing(let id, _, _):
                return API.StartTest.request(.existing(id: id))
            }
        }
    }
}

struct NewTestView_Previews: PreviewProvider {
    static var previews: some View {
        NewTestModalView(properties: [], isPresented: true)
    }
}
