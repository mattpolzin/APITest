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

extension API.APITestDescriptor {
    public static let createdAtOrdering: (Self, Self) -> Bool = { left, right in
        return left.createdAt < right.createdAt
    }
}

extension API.TestStatus {
    var color: SwiftUI.Color {
        switch self {
        case .pending:
            return .gray
        case .building, .running:
            return .blue
        case .passed:
            return .green
        case .failed:
            return .red
        }
    }
}

struct ContentView: View {
    @ObservedObject private var appState = ObservableState(store: store)

    let dateFormatter: DateFormatter = {
        var df = DateFormatter()
        df.doesRelativeDateFormatting = true
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { store.dispatch(API.StartTest.request) }) {
                    Text("New Test")
                        .background(Color.clear)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.accentColor, lineWidth: 2))
                        .padding(10)
                }
                Spacer()
                Text("\(appState.current.entityCache.tests.values.filter { [API.TestStatus.building, API.TestStatus.running].contains($0.status) }.count) build/running")
                Rectangle().fill(LinearGradient(gradient: Gradient(colors: [Color.clear, Color.gray.opacity(0.5), Color.clear]), startPoint: .top, endPoint: .bottom))
                    .frame(idealWidth: 2, idealHeight: 44).fixedSize()
                Text("\(appState.current.entityCache.tests.values.filter { [API.TestStatus.passed, API.TestStatus.failed].contains($0.status) && Calendar.current.isDateInToday($0.createdAt) }.count) finished today")
                Spacer().frame(maxWidth: .infinity)
            }
            Rectangle().fill(Color.gray).frame(height: 2)
            List {
                ForEach(appState.current.entityCache.tests.values.sorted(by: API.APITestDescriptor.createdAtOrdering), id: \.id) { test in
                    HStack {
                        Text(self.dateFormatter.string(from: test.createdAt)).frame(minWidth: 200, alignment: .leading)
                        Text(test.status.rawValue)
                            .padding(.init(top: 5, leading: 10, bottom: 5, trailing: 10))
                            .frame(minWidth: 80, alignment: .center)
                            .background(test.status.color)
                            .cornerRadius(10)
                    }
                }
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
