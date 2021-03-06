//
//  TestDetailsHeaderView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/25/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import SwiftUI

struct TestDetailsHeaderView: View {
    let successCount: Int?
    let warningCount: Int?
    let errorCount: Int?

    let messageTypeFilters: AppState.Toggles.Messages
    let filterText: String

    let viewing: Viewing?
    let rawLogsAvailable: Bool

    enum Viewing: Equatable {
        case messages
        case logs
    }

    var body: some View {
        ZStack {
            HStack {
                Text("Test Details").font(.title).padding(.trailing, 2)
                HStack {
                    MessageTypeCountCircleView(count: successCount, messageType: .success, filtered: messageTypeFilters.showSuccessMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showSuccessMessages))
                    }
                    MessageTypeCountCircleView(count: warningCount, messageType: .warning, filtered: messageTypeFilters.showWarningMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showWarningMessages))
                    }
                    MessageTypeCountCircleView(count: errorCount, messageType: .error, filtered: messageTypeFilters.showErrorMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showErrorMessages))
                    }
                    SearchTextField(filterText: filterText).frame(maxWidth: 300)
                }.disabled(viewing == .logs).opacity(viewing == .logs ? 0.25 : 1.0)
            }
            HStack {
                Spacer()
                RawLogButton(
                    enabled: rawLogsAvailable,
                    viewing: viewing
                )
            }
        }
    }
}

struct RawLogButton: View {
    let enabled: Bool
    let viewing: TestDetailsHeaderView.Viewing?

    var body: some View {
        Button(
            action: { store.dispatch(TestDetails.toggleDetailsLogsOrMessages) },
            label: {
                Group {
                    if viewing == .messages {
                        Image("Code Braces").resizable()
                    } else {
                        Image("Checklist").resizable()
                    }
                }
            }
        )
        .padding(8)
        .frame(width: 46, height: 46)
        .opacity(!enabled || viewing == nil ? 0.0 : 1.0)
        .disabled(!enabled || viewing == nil)
    }
}
