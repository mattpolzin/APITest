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

extension TestDetailView.MessageModel {
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
            let hostOverride: URL?
            let messages: [MessageModel]
            let logs: String?
            let viewing: TestDetailsHeaderView.Viewing
        }

        var populatedValues: Populated? {
            guard case let .populated(state) = self else {
                return nil
            }
            return state
        }

        var messages: [MessageModel] {
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

        var rawLogs: String? {
            guard let values = populatedValues else {
                return nil
            }
            return values.logs
        }
    }

    struct MessageModel: Equatable, Identifiable {
        let id: API.APITestMessage.Id
        let createdAt: Date
        let messageType: API.MessageType
        let message: String
        let path: String?
        let context: String?
        let highlighted: Bool
    }

    let state: State
    let messageTypeFilters: AppState.Toggles.Messages
    let filterText: String

    var successCount: Int? {
        return state.populatedValues?.messages.lazy.filter(self.textFilter).filter { $0.messageType == .success }.count
    }

    var warningCount: Int? {
        return state.populatedValues?.messages.lazy.filter(self.textFilter).filter { $0.messageType == .warning }.count
    }

    var errorCount: Int? {
        return state.populatedValues?.messages.lazy.filter(self.textFilter).filter { $0.messageType == .error }.count
    }

    /// Apply only the text filter.
    func textFilter(_ message: MessageModel) -> Bool {
        return filterText.isEmpty
            || message.message.contains(filterText)
            || (message.context?.contains(filterText) ?? false)
            || (message.path?.contains(filterText) ?? false)
    }

    /// Apply both the message type and text filters.
    func messageFilter(_ message: MessageModel) -> Bool {
        let allowedMessageTypes: [API.MessageType] = [
            .debug,
            .info,
            messageTypeFilters.showSuccessMessages ? .success : nil,
            messageTypeFilters.showWarningMessages ? .warning : nil,
            messageTypeFilters.showErrorMessages ? .error : nil
        ].compactMap { $0 }

        return allowedMessageTypes.contains(message.messageType)
            && textFilter(message)
    }

    /// Apply the message filter and sort by newest
    func sortedAndFiltered(_ messages: [MessageModel]) -> [MessageModel] {
        messages.lazy
            .filter(self.messageFilter)
            .sorted(by: MessageModel.createdAtOrdering)
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
                messageTypeFilters: messageTypeFilters,
                filterText: filterText,
                viewing: state.viewing,
                rawLogsAvailable: state.rawLogs != nil
            ).padding(.top, 10).padding(.bottom, 5)

            // source subheader
            Text(state.populatedValues.map { "OpenAPI Source: \($0.source.uri) (API Host: \($0.hostOverride?.absoluteString ?? "default"))" } ?? "").font(.subheadline)
                .padding(.bottom, 5)

            // details
            state.populatedValues.map { state in
                Group {
                    if state.viewing == .logs {
                        RawTestLogView(logs: state.logs ?? "")
                    } else if state.viewing == .messages {
                        List {
                            ForEach(sortedAndFiltered(state.messages)) { message in
                                MessageCellView(
                                    messageType: message.messageType,
                                    message: message.message,
                                    path: message.path,
                                    context: message.context,
                                    highlighted: message.highlighted
                                )
                                .background(Color(.systemBackground))
                                .onTapGesture {} // fixes scrolling for iOS
                                .onLongPressGesture {
                                    store.dispatch(TestDetails.longPressMessage(message.id))
                                }
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
        withMessageTypeFilters messageTypeFilters: AppState.Toggles.Messages,
        filterText: String,
        viewing: TestDetailsHeaderView.Viewing,
        highlighting highlightedMessages: Set<API.APITestMessage.Id>
    ) {
        self.messageTypeFilters = messageTypeFilters
        self.filterText = filterText
        guard let test = testId?.materialized(from: entities) else {
            self.state = .empty
            return
        }
        guard let properties = (test ~> \.testProperties).materialized(from: entities),
            let source = (properties ~> \.openAPISource).materialized(from: entities) else {
                self.state = .loading
                return
        }
        let messages = (test ~> \.messages).compactMap { $0.materialized(from: entities) }
        let logs = entities.testLogs[test.id]

        self.state = .populated(
            .init(
                test: test,
                source: source,
                hostOverride: properties.apiHostOverride,
                messages: messages.map { message in
                    MessageModel(
                        id: message.id,
                        createdAt: message.createdAt,
                        messageType: message.messageType,
                        message: message.message,
                        path: message.path,
                        context: message.context,
                        highlighted: highlightedMessages.contains(message.id)
                    )
                },
                logs: logs,
                viewing: viewing
            )
        )
    }
}

struct TestDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TestDetailView(state: .loading, messageTypeFilters: .init(), filterText: "")
    }
}
