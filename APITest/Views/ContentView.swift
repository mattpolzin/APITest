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

struct ContentView: View {
    @ObservedObject private var appState = ObservableState(store: store)

    private var state: AppState { appState.current }
    private var entities: EntityCache { state.entities }

    var contentViewDisabled: Bool {
        state.modal != .none
    }

    var settingsEditorOpen: Bool {
        state.settingsEditor != nil
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ToolbarView(
                    buildingAndRunningTestCount: state.buildingAndRunningTests.count,
                    finishedTodayTestCount: state.testsFinishedToday.count,
                    settingsTrayOpen: settingsEditorOpen,
                    newTestButtonDisabled: settingsEditorOpen,
                    settingsButtonDisabled: !(state.settingsEditor?.$host.isValid ?? true)
                )
                Rectangle().fill(Color.secondary).frame(height: 2)
                ZStack {
                    HStack {
                        TestListView(
                            tests: Array(self.entities.tests.values),
                            selectedTestId: self.state.selectedTestId
                        ).frame(width: 330)
                        TestDetailView(
                            forTestId: self.state.selectedTestId,
                            in: self.state.entities,
                            withFilters: state.toggles.messages
                        ).frame(maxWidth: .infinity)
                    }
                    // settings view if visible
                    self.settingsView
                }
            }.disabled(contentViewDisabled)

            // present any current modal (or none)
            self.modalViews

            // present any current Toast
            self.toastView
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
                        sources: entities.sources,
                        selection: state.recentlyUsedSource,
                        isPresented: state.modal.isNewTest
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
                .opacity(state.settingsEditor != nil ? 0.75 : 0.0)
                .animation(.easeInOut(duration: 0.05))

            HStack(spacing: 0) {
                Spacer().frame(maxWidth: .infinity)
                SettingsView(
                    settingsEditorState: state.settingsEditor
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
