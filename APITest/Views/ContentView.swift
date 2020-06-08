//
//  ContentView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/8/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import SwiftUI
import ReSwift
import APIModels
import JSONAPI

enum Device {
    case iPhone
    case iPad
    case mac
    case other

    static var current: Self {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return .iPad
        case .phone:
            return .iPhone
        default:
            return .other
        }
        #endif
    }
}

struct ContentView: View {
    @ObservedObject private var appState = ObservableState(store: store)

    private var state: AppState { appState.current }
    private var entities: EntityCache { state.entities }

    var contentViewDisabled: Bool {
        state.takeover.modal != nil
    }

    var settingsEditorOpen: Bool {
        state.takeover.settingsEditor != nil
    }

    var settingsButtonDisabled: Bool {
        !(state.takeover.settingsEditor?.$host.isValid ?? true)
    }

    var body: some View {
        ZStack {
            if state.takeover.isHelp {
                HelpView(host: state.host)
                    .rotation3DEffect(Angle(degrees: -180), axis: (x: 1, y: 0, z: 0))
            } else {
                VStack(spacing: 0) {
                    ToolbarView(
                        buildingAndRunningTestCount: state.buildingAndRunningTests.count,
                        finishedTodayTestCount: state.testsFinishedToday.count,
                        settingsTrayOpen: settingsEditorOpen,
                        newTestButtonDisabled: settingsEditorOpen,
                        settingsButtonDisabled: settingsButtonDisabled
                    )
                    Rectangle().fill(Color.secondary).frame(height: 2)
                    ZStack {
                        self.listAndDetailViews

                        // settings view if visible
                        self.settingsView
                    }
                }.disabled(contentViewDisabled)

                // present any current modal (or none)
                self.modalViews

                // present any current Toast
                self.toastView
            }
        }.rotation3DEffect(state.takeover.isHelp ? Angle(degrees: 180): Angle(degrees: 0), axis: (x: 1, y: 0, z: 0))
            .animation(.default, value: state.takeover.isHelp)
    }

    var listAndDetailViews: some View {
        ZStack {
            if Device.current == .iPhone {
                NavigationView {
                    TestListView(
                        tests: Array(entities.tests.values),
                        selectedTestId: state.selectedTestId
                    ).frame(width: 340)
                    TestDetailView(
                        forTestId: state.selectedTestId,
                        in: state.entities,
                        withMessageTypeFilters: state.toggles.messages,
                        filterText: state.filterText,
                        viewing: state.detailsViewing
                    ).frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    TestListView(
                        tests: Array(entities.tests.values),
                        selectedTestId: state.selectedTestId
                    ).frame(width: 340)
                    TestDetailView(
                        forTestId: state.selectedTestId,
                        in: state.entities,
                        withMessageTypeFilters: state.toggles.messages,
                        filterText: state.filterText,
                        viewing: state.detailsViewing
                    ).frame(maxWidth: .infinity)
                }
            }
        }
    }
}

extension ContentView {
    var modalViews: some View {
        ZStack {
            // dim things for modal presentation
            Rectangle().fill(Color.black)
                .opacity(contentViewDisabled ? 0.75 : 0.0)
                .animation(.easeInOut(duration: 0.05))

            HStack {
                Spacer().frame(maxWidth: .infinity)
                VStack {
                    Spacer().frame(maxHeight: .infinity)
                    NewTestModalView(
                        entityCache: entities,
                        selection: state.recentlyUsedProperties,
                        newTestState: state.takeover.modal?.newTestState
                    )
                    Spacer().frame(maxHeight: .infinity)
                }
                Spacer().frame(maxWidth: .infinity)
            }
        }.edgesIgnoringSafeArea(.all)
    }

    var settingsView: some View {
        ZStack {
            // dim things for modal presentation
            Rectangle().fill(Color.black)
                .opacity(state.takeover.settingsEditor != nil ? 0.75 : 0.0)
                .animation(.easeInOut(duration: 0.05))

            HStack(spacing: 0) {
                Spacer().frame(maxWidth: .infinity)
                SettingsView(
                    settingsEditorState: state.takeover.settingsEditor
                )
            }
        }.edgesIgnoringSafeArea(.all)
    }

    var toastView: some View {
        ZStack {
            state.toastQueue.first.map { toastContent in
                ToastView(content: toastContent)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
