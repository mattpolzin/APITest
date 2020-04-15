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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ToolbarView(
                    buildingAndRunningTestCount: state.buildingAndRunningTests.count,
                    finishedTodayTestCount: state.testsFinishedToday.count
                )
                Rectangle().fill(Color.secondary).frame(height: 2)
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
                Spacer()
            }.disabled(state.modal != .none)

            // dim things for modal presentation
            Rectangle().fill(Color.black)
                .opacity(state.modal == .none ? 0.0 : 0.75)
                .animation(.easeInOut(duration: 0.05))

            // present any current modal (or none)
            self.modals
        }
    }
}

extension ContentView {
    var modals: some View {
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
