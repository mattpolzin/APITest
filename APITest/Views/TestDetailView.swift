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

extension API.MessageType {
    var color: SwiftUI.Color {
        switch self {
        case .debug, .info:
            return .gray
        case .warning:
            return .yellow
        case .success:
            return .green
        case .error:
            return .red
        }
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
        }

        var populatedValues: Populated? {
            guard case let .populated(state) = self else {
                return nil
            }
            return state
        }
    }

    let state: State
    let filters: AppState.Toggles.Messages

    var successCount: Int? {
        state.populatedValues?.messages.filter { $0.messageType == .success }.count
    }

    var warningCount: Int? {
        state.populatedValues?.messages.filter { $0.messageType == .warning }.count
    }

    var errorCount: Int? {
        state.populatedValues?.messages.filter { $0.messageType == .error }.count
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
            HStack {
                Text("Test Details").font(.title).padding(.trailing, 2)
                MessageTypeCountCircle(count: successCount, messageType: .success, filtered: filters.showSuccessMessages)
                    .onTapGesture {
                        store.dispatch(Toggle(field: \.messages.showSuccessMessages))
                }
                MessageTypeCountCircle(count: warningCount, messageType: .warning, filtered: filters.showWarningMessages)
                    .onTapGesture {
                        store.dispatch(Toggle(field: \.messages.showWarningMessages))
                }
                MessageTypeCountCircle(count: errorCount, messageType: .error, filtered: filters.showErrorMessages)
                    .onTapGesture {
                        store.dispatch(Toggle(field: \.messages.showErrorMessages))
                }
            }.padding(.top, 10).padding(.bottom, 5)

            state.populatedValues.map { state in
                VStack {

                    Text("Source: \(state.source.uri)").font(.subheadline)
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
            if state.populatedValues == nil {
                Self.loaderCells
            }
            Spacer()
        }
    }

    static let loaderCells: some View = List {
        MessageCellView.dummy.opacity(1.0)
        MessageCellView.dummy.opacity(0.5)
        MessageCellView.dummy.opacity(0.2)
        MessageCellView.dummy.opacity(0.05)
    }
}

struct MessageTypeCountCircle: View {
    let count: Int?
    let messageType: API.MessageType
    let filtered: Bool

    var body: some View {
        ZStack {
            Text("00").opacity(0)
                .padding(5)
                .background(Circle().stroke(messageType.color, lineWidth: 3))
            count.map { Text("\($0)") }
        }.opacity(filtered ? 1.0 : 0.5)
    }
}

struct MessageCellView: View {
    let messageType: API.MessageType
    let message: String
    let path: String?
    let context: String?

    var body: some View {
        HStack {
            Rectangle().fill(messageType.color)
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.body).bold()
                path.map { Text("→ \($0)").font(.body).italic() }
                context.map { Text("→ \($0)").font(.body) }
            }
        }.listRowInsets(.init(top: 10, leading: 10, bottom: 10, trailing: 10))
    }

    static var dummy: Self {
        MessageCellView(
            messageType: .info,
            message: .randomMorse(count: 25),
            path: .randomMorse(count: 8, asPath: true),
            context: .randomMorse(count: 15)
        )
    }
}

extension String {
    static func randomMorse(count: Int, asPath: Bool = false) -> String {
        let characters: [Character] = ["·", "−"]

        let randomChar: () -> Character = { characters[Int.random(in: 0..<(characters.count))] }

        let randomMorse = (0..<count).reduce(into: "") { res, _ in res.append(randomChar()) }

        guard asPath else {
            return randomMorse
        }

        let pathSplits = [
            Int.random(in: 0..<randomMorse.count),
            Int.random(in: 1..<randomMorse.count)
            ].map { randomMorse.index(randomMorse.startIndex, offsetBy: $0) }

        let ret = String(randomMorse[randomMorse.startIndex..<pathSplits[0]])
            + "/"
            + String(randomMorse[randomMorse.startIndex..<pathSplits[1]])
            + "/"
            + String(randomMorse[pathSplits[1]...])

        return ret
    }
}

extension TestDetailView {
    init(forTestId testId: API.APITestDescriptor.Id?, in entities: EntityCache, withFilters filters: AppState.Toggles.Messages) {
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

        self.state = .populated(
            .init(
                test: test,
                source: source,
                messages: messages
            )
        )
    }
}

struct TestDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TestDetailView(state: .loading, filters: .init())
    }
}
