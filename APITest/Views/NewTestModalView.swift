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

struct NewTestModalView: View {
    let sources: EntityCache.Cache<API.OpenAPISource>
    @State private var selectedSource: RequestSource = .default
    let isPresented: Bool

    var sourceOptions: [RequestSource] {
        [.default]
            + sources.map { .existing($0.value) }
            + [.new(uri: "")]
    }

    init(sources apiSources: EntityCache.Cache<API.OpenAPISource>, selection: API.OpenAPISource.Id? = nil, isPresented: Bool) {
        sources = apiSources
        self.isPresented = isPresented
        selectedSource = selection.flatMap { apiSources[$0] }.flatMap { .existing($0) } ?? .default
    }

    var body: some View {
        ZStack {
            if isPresented {
                VStack {
                    Text("New Test").font(.title)
                    List {
                        ForEach(sourceOptions) { source in
                            ZStack(alignment: .center) {
                                Rectangle().fill(source == self.selectedSource ? Color.accentColor : Color.clear)
                                source.textView
                            }.contentShape(Rectangle())
                            .onTapGesture { self.selectedSource = source }
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
                                store.dispatch(self.selectedSource.action)
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
    enum RequestSource: Equatable, Identifiable, CustomStringConvertible {
        case `default`
        case new(uri: String)
        case existing(API.OpenAPISource)

        var description: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(let source):
                return source.uri
            }
        }

        var id: String {
            switch self {
            case .default:
                return "default"
            case .new:
                return "new"
            case .existing(let source):
                return source.id.rawValue.uuidString
            }
        }

        var textView: Text {
            switch self {
            case .default, .new:
                return Text(description).bold()
            case .existing:
                return Text(description).italic()
            }
        }

        var action: API.StartTest {
            switch self {
            case .default:
                return API.StartTest.request(.default)
            case .new(uri: let uri):
                return API.StartTest.request(.new(uri: uri))
            case .existing(let source):
                return API.StartTest.request(.existing(id: source.id))
            }
        }
    }
}

struct NewTestView_Previews: PreviewProvider {
    static var previews: some View {
        NewTestModalView(sources: [:], isPresented: true)
    }
}
