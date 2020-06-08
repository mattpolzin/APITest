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

struct NewTestModalView: View {

    @State private var selectedProperties: RequestProperties = .default
    let isPresented: Bool
    let creatingNewSource: Bool

    let propertiesOptions: [RequestProperties]

    init(
        entityCache: EntityCache,
        selection: API.APITestProperties.Id? = nil,
        newTestState: AppState.Modal.NewTestModalState?
    ) {

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
        self.propertiesOptions = properties
        if let newTestState = newTestState {
            self.isPresented = true
            self.creatingNewSource = newTestState == .newSource
        } else {
            self.isPresented = false
            self.creatingNewSource = false
        }
        self.selectedProperties = selection ?? .default
    }

    var body: some View {
        ZStack {
            if isPresented {
                ZStack {
                    if creatingNewSource {
                        NewTestSourceView()
                            .rotation3DEffect(Angle(degrees: -180), axis: (x: 0, y: 1, z: 0))
                    } else {
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
                        )
                    }
                }.rotation3DEffect(creatingNewSource ? Angle(degrees: 180): Angle(degrees: 0), axis: (x: 0, y: 1, z: 0))
                    .animation(.default, value: creatingNewSource)
            }
        }.animation(.easeInOut(duration: 0.05))
    }
}

extension NewTestModalView {
    enum RequestProperties: Equatable, Swift.Identifiable, CustomStringConvertible {
        case `default`
        case new
        case existing(API.APITestProperties.Id, sourceUri: String, apiHostOverride: String?)

        var description: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(_, let sourceUri, let hostOverride):
                return "\(sourceUri)" + (hostOverride.map { " (server: \($0))" } ?? "")
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
                return [ Text(sourceUri).italic() ] + (hostOverride.map { [ Text(" ("), Text("server: ").bold(), Text($0).italic(), Text(")").bold() ] } ?? [])
            }
        }

        var actions: [ReSwift.Action] {
            switch self {
            case .default:
                return [API.StartTest.request(.default), NewTest.dismiss]
            case .new:
                return [NewTest.newSource]
            case .existing(let id, _, _):
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
