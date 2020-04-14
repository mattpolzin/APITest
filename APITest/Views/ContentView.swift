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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
