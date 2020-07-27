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
import ReSwift

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct NewTestModalView: View {
    @State private var selectedProperties: NewTestModalView.RequestProperties = .default
    @State private var size: CGSize = .zero

    let newTestState: AppState.Modal.NewTestModalState?

    let propertiesOptions: [RequestProperties]

    init(
        entityCache: EntityCache,
        selection: API.APITestProperties.Id? = nil,
        newTestState: AppState.Modal.NewTestModalState?
    ) {

        let existingOptions: [RequestProperties] = entityCache.testProperties.values
            .compactMap { properties in (properties ~> \.openAPISource).materialized(from: entityCache).map { (properties, $0) } }
            .map { (properties, source) in
                .existing(
                    properties.id,
                    sourceUri: source.uri,
                    apiHostOverride: properties.apiHostOverride?.absoluteString,
                    parser: properties.parser
                )
        }

        let selectedProperties: RequestProperties? = selection.flatMap { $0.materialized(from: entityCache) }
            .flatMap { properties in (properties ~> \.openAPISource).materialized(from: entityCache).map { (properties, $0) } }
            .map { (properties, source) in
                .existing(
                    properties.id,
                    sourceUri: source.uri,
                    apiHostOverride: properties.apiHostOverride?.absoluteString,
                    parser: properties.parser
                )
        }

        self.init(
            properties: [.default] + existingOptions + [.new],
            selection: selectedProperties,
            newTestState: newTestState
        )
    }

    init(
        properties: [RequestProperties],
        selection: RequestProperties? = nil,
        newTestState: AppState.Modal.NewTestModalState?
    ) {
        self.newTestState = newTestState
        self.propertiesOptions = properties
        self.selectedProperties = selection ?? .default
    }

    var body: some View {
        ZStack {
            self.newTestState.map { testState in
                ZStack {
                    testState.newSourceState.map { newSourceState in
                        NewTestCreateSourceView(
                            openAPISourceUri: newSourceState.openAPISourceUri,
                            serverHostOverride: newSourceState.serverHostOverride.flatMap(URL.init(string:)),
                            parser: newSourceState.parser
                        )
                            .frame(width: self.size.width, height: self.size.height)
                            .rotation3DEffect(Angle(degrees: 180), axis: (x: 0, y: 1, z: 0))
                    }
                    if !testState.isNewSource {
                        NewTestSelectSourceView(propertiesOptions: self.propertiesOptions, selectedProperties: $selectedProperties)
                            .onPreferenceChange(SizePreferenceKey.self, perform: { self.size = $0 })
                    }
                }.rotation3DEffect(testState.isNewSource ? Angle(degrees: -180): Angle(degrees: 0), axis: (x: 0, y: 1, z: 0))
                    .animation(.default, value: testState.isNewSource)
            }
        }.transition(.opacity)
        .animation(.easeInOut(duration: 0.1), value: newTestState != nil)
    }
}

extension NewTestModalView {
    enum RequestProperties: Equatable, Swift.Identifiable, CustomStringConvertible {
        case `default`
        case new
        case existing(API.APITestProperties.Id, sourceUri: String, apiHostOverride: String?, parser: API.Parser)

        var description: String {
            switch self {
            case .default:
                return "default configuration"
            case .new:
                return "new configuration"
            case .existing(_, let sourceUri, let hostOverride, let parser):
                return "\(sourceUri)" + (hostOverride.map { " (server: \($0))" } ?? "") + (parser == .fast ? "[fast parser]" : "")
            }
        }

        var id: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(let id, _, _, _):
                return id.rawValue.uuidString
            }
        }

        var textViews: [Text] {
            switch self {
            case .default, .new:
                return [ Text(description).bold() ]
            case .existing(_, let sourceUri, let hostOverride, let parser):
                return [ Text(sourceUri).italic() ]
                    + [
                        [ Text(" ("),
                        Text("server: ").bold(),
                        Text(hostOverride.map { $0 } ?? "default").italic() ],
                        parser == .fast ? [ Text(", "), Text("parser: ").bold(), Text("fast").italic() ] : [],
                        [ Text(")").bold() ]
                    ].flatMap { $0 }
            }
        }

        var actions: [ReSwift.Action] {
            switch self {
            case .default:
                return [API.StartTest.request(.default), NewTest.dismiss]
            case .new:
                return [NewTest.newSource]
            case .existing(let id, _, _, _):
                return [API.StartTest.request(.existing(id: id)), NewTest.dismiss]
            }
        }
    }
}

struct NewTestView_Previews: PreviewProvider {
    static var previews: some View {
        NewTestModalView(properties: [], newTestState: .selectSource)
    }
}
