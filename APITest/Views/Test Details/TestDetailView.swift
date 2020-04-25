//
//  TestDetailView.swift
//  APITest
//
//  Created by Mathew Polzin on 4/8/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import SwiftUI
import ReSwift
import APIModels
import JSONAPI

extension API.APITestMessage {
    public static let createdAtOrdering: (Self, Self) -> Bool = { left, right in
        return left.createdAt < right.createdAt
    }
}

struct TestDetailView: View {
    enum State: Equatable {
        case loading
        case empty
        case populated(Populated)

        struct Populated: Equatable {
            let test: API.APITestDescriptor
            let source: API.OpenAPISource
            let messages: [API.APITestMessage]
            let logs: String
            let viewing: TestDetailsHeaderView.Viewing
        }

        var populatedValues: Populated? {
            guard case let .populated(state) = self else {
                return nil
            }
            return state
        }

        var messages: [API.APITestMessage] {
            guard let values = populatedValues else {
                return []
            }
            return values.messages
        }

        var viewing: TestDetailsHeaderView.Viewing? {
            guard let values = populatedValues else {
                return nil
            }
            return values.viewing
        }
    }

    let state: State
    let filters: AppState.Toggles.Messages

    var successCount: Int? {
        return state.populatedValues?.messages.filter { $0.messageType == .success }.count
    }

    var warningCount: Int? {
        return state.populatedValues?.messages.filter { $0.messageType == .warning }.count
    }

    var errorCount: Int? {
        return state.populatedValues?.messages.filter { $0.messageType == .error }.count
    }

    func messageFilter(_ message: API.APITestMessage) -> Bool {
        let allowedMessageTypes: [API.MessageType] = [
            filters.showSuccessMessages ? .success : nil,
            filters.showWarningMessages ? .warning : nil,
            filters.showErrorMessages ? .error : nil
        ].compactMap { $0 }

        return allowedMessageTypes.contains(message.messageType)
    }

    let dateFormatter: DateFormatter = {
        var df = DateFormatter()
        df.doesRelativeDateFormatting = true
        df.dateStyle = .short
        df.timeStyle = .medium
        return df
    }()

    var body: some View {
        VStack(spacing: 0) {
            // header
            TestDetailsHeaderView(
                successCount: successCount,
                warningCount: warningCount,
                errorCount: errorCount,
                filters: filters,
                viewing: state.viewing
            ).padding(.top, 10).padding(.bottom, 5)

            // source subheader
            Text(state.populatedValues.map { "Source: \($0.source.uri)" } ?? "").font(.subheadline)
                .padding(.bottom, 5)

            // details
            state.populatedValues.map { state in
                Group {
                    if state.viewing == .logs {
                        RawTestLogView(logs: state.logs)
                    } else if state.viewing == .messages {
                        List {
                            ForEach(state.messages.filter(self.messageFilter), id: \.id) { message in
                                MessageCellView(
                                    messageType: message.messageType,
                                    message: message.message,
                                    path: message.path,
                                    context: message.context
                                )
                            }
                        }
                    }
                }
            }
            if state.populatedValues == nil {
                Group {
                    Self.emptyStateCells
                }
            }
            Spacer()
        }
    }

    static let emptyStateCells: some View = List {
        MessageCellView.dummy.opacity(1.0)
        MessageCellView.dummy.opacity(0.5)
        MessageCellView.dummy.opacity(0.2)
    }
}

extension TestDetailView {
    init(
        forTestId testId: API.APITestDescriptor.Id?,
        in entities: EntityCache,
        withFilters filters: AppState.Toggles.Messages,
        viewing: TestDetailsHeaderView.Viewing
    ) {
        self.filters = filters
        guard let test = testId?.materialize(from: entities) else {
            self.state = .empty
            return
        }
        guard let source = (test ~> \.openAPISource).materialize(from: entities) else {
            self.state = .loading
            return
        }
        let messages = (test ~> \.messages).compactMap { $0.materialize(from: entities) }
        let logs = entities.testLogs[test.id] ?? ""

        self.state = .populated(
            .init(
                test: test,
                source: source,
                messages: messages,
                logs: logs,
                viewing: viewing
            )
        )
    }
}

struct TestDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TestDetailView(state: .loading, filters: .init())
    }
}
