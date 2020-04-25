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

    let filters: AppState.Toggles.Messages

    let viewing: Viewing?

    enum Viewing: Equatable {
        case messages
        case logs
    }

    var body: some View {
        ZStack {
            HStack {
                Text("Test Details").font(.title).padding(.trailing, 2)
                HStack {
                    MessageTypeCountCircleView(count: successCount, messageType: .success, filtered: filters.showSuccessMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showSuccessMessages))
                    }
                    MessageTypeCountCircleView(count: warningCount, messageType: .warning, filtered: filters.showWarningMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showWarningMessages))
                    }
                    MessageTypeCountCircleView(count: errorCount, messageType: .error, filtered: filters.showErrorMessages)
                        .onTapGesture {
                            store.dispatch(Toggle.field(\.messages.showErrorMessages))
                    }
                }.disabled(viewing == .logs).opacity(viewing == .logs ? 0.25 : 1.0)
            }
            HStack {
                Spacer()
                Button(
                    action: { store.dispatch(Toggle.detailsLogsOrMessages) },
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
                    .opacity(viewing == nil ? 0.0 : 1.0)
                    .disabled(viewing == nil)
            }
        }
    }
}
