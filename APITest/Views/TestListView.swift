//
//  TestListView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/12/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI
import APIModels
import JSONAPI

extension API.APITestDescriptor {
    public static let createdAtOrdering: (Self, Self) -> Bool = { left, right in
        return left.createdAt > right.createdAt
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

struct TestListView: View {
    let tests: [API.APITestDescriptor]
    let selectedTestId: API.APITestDescriptor.Id?

    let dateFormatter: DateFormatter = {
        var df = DateFormatter()
        df.doesRelativeDateFormatting = true
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()

    var body: some View {
        List {
            ForEach(tests.sorted(by: API.APITestDescriptor.createdAtOrdering)) { test in
                HStack {
                    // Test Creation Date/Time
                    Text(self.dateFormatter.string(from: test.createdAt))
                        .frame(minWidth: 230, alignment: .leading)
                    Spacer()
                    // Test Status
                    Text(test.status.rawValue)
                        .padding(.init(top: 5, leading: 10, bottom: 5, trailing: 10))
                        .frame(minWidth: 90, alignment: .center)
                        .background(test.status.color)
                        .cornerRadius(10)
                }.padding(.init(top: 5, leading: 10, bottom: 5, trailing: 10))
                    .listRowInsets(
                        .init(top: 0, leading: 0, bottom: 0, trailing: 0)
                ).onTapGesture {
                    store.dispatch(API.GetTest.requestDescriptor(id: test.id, includeMessages: true, includeProperties: (true, alsoIncludeSource: true)))
                    store.dispatch(API.GetTest.requestRawLogs(id: test.id))
                    store.dispatch(test.select)
                }.background(
                    self.selectedTestId == test.id
                        ? Color.accentColor
                        : Color.clear
                )
            }
        }
    }
}
