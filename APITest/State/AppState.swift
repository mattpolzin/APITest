//
//  AppState.swift
//  APITest
//
//  Created by Mathew Polzin on 4/8/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift
import APIModels

struct AppState: Equatable, ReSwift.StateType {
    var entities: EntityCache

    var host: URL

    var selectedTestId: API.APITestDescriptor.Id?
    /// A "flashed" message is one that is temporarily
    /// highlighted for some reason.
    var highlightedMessages: Set<API.APITestMessage.Id>

    var detailsViewing: TestDetailsHeaderView.Viewing

    var recentlyUsedProperties: API.APITestProperties.Id?

    var toggles: Toggles
    var filterText: String

    var takeover: Takeover

    var toastQueue: [Toast.Content]

    init() {
        entities = .init()
        host = Config.host
        toggles = .init(messages: .init())
        filterText = ""
        takeover = .none
        toastQueue = []
        recentlyUsedProperties = nil
        selectedTestId = nil
        highlightedMessages = Set()
        detailsViewing = .messages
    }
}

extension AppState {
    var buildingAndRunningTests: [API.APITestDescriptor] {
        return entities.tests.values
            .filter { [API.TestStatus.building, API.TestStatus.running].contains($0.status) }
    }

    var finishedTests: [API.APITestDescriptor] {
        return entities.tests.values
            .filter { [API.TestStatus.passed, API.TestStatus.failed].contains($0.status) }
    }

    var testsFinishedToday: [API.APITestDescriptor] {
        return entities.tests.values
            .filter {
                [API.TestStatus.passed, API.TestStatus.failed].contains($0.status) &&
                    Calendar.current.isDateInToday($0.createdAt)
        }
    }
}

extension AppState {
    struct Toggles: Equatable {
        var messages: Messages

        struct Messages: Equatable {
            var showSuccessMessages: Bool = true
            var showWarningMessages: Bool = true
            var showErrorMessages: Bool = true
        }
    }
}

extension AppState {
    enum Takeover: Equatable {
        case modal(Modal)
        case settings(SettingsEditor)
        case help
        case none

        var settingsEditor: SettingsEditor? {
            guard case let .settings(editor) = self else {
                return nil
            }
            return editor
        }

        var modal: Modal? {
            guard case let .modal(modal) = self else {
                return nil
            }
            return modal
        }

        var isHelp: Bool {
            guard case .help = self else {
                return false
            }
            return true
        }
    }
}

extension AppState {
    struct SettingsEditor: Equatable {
        @Validated<URLStringValidator>
        var host: String

        func with(host: String) -> Self {
            return .init(host: host)
        }
    }
}

extension AppState {
    enum Modal: Equatable {
        case newTest(NewTestModalState)

        var isNewTest: Bool {
            guard case .newTest = self else {
                return false
            }
            return true
        }

        var newTestState: NewTestModalState? {
            guard case .newTest(let newTestState) = self else {
                return nil
            }
            return newTestState
        }
    }
}

extension AppState.Modal {
    enum NewTestModalState: Equatable {
        case selectSource
        case newSource(NewSourceState)

        struct NewSourceState: Equatable {
            var openAPISourceUri: String?

            @Validated<OptionalURLStringValidator>
            var serverHostOverride: String?

            var parser: API.Parser

            func with(source: String?) -> Self {
                return .init(openAPISourceUri: source, serverHostOverride: serverHostOverride, parser: parser)
            }

            func with(serverHostOverride: String?) -> Self {
                return .init(openAPISourceUri: openAPISourceUri, serverHostOverride: serverHostOverride, parser: parser)
            }

            func with(parser: API.Parser) -> Self {
                return .init(openAPISourceUri: openAPISourceUri, serverHostOverride: serverHostOverride, parser: parser)
            }
        }

        var isNewSource: Bool {
            guard case .newSource = self else {
                return false
            }
            return true
        }

        var newSourceState: NewSourceState? {
            guard case .newSource(let state) = self else {
                return nil
            }
            return state
        }
    }
}

extension AppState {
    static func reducer(action: ReSwift.Action, state: AppState?) -> AppState {
        var state = state ?? AppState()

        switch action {
        case let .response(entities) as API.EntityUpdate:
            state.entities.merge(with: entities)
            return state
        case .open as NewTest:
            state.takeover = .modal(.newTest(.selectSource))
            return state
        case .dismiss as NewTest:
            state.takeover = .none
            return state
        case .newSource as NewTest:
            state.takeover = .modal(.newTest(.newSource(.init(openAPISourceUri: nil, serverHostOverride: nil, parser: .stable))))
            return state
        case .cancelNewSource as NewTest:
            state.takeover = .modal(.newTest(.selectSource))
            return state
        case .changeSourceUri(let uri) as NewTest:
            guard let currentSource = state.takeover.modal?.newTestState?.newSourceState else {
                // invariante failure?
                return state
            }
            state.takeover = .modal(.newTest(.newSource(currentSource.with(source: uri))))
            return state
        case .changeServerOverride(let server) as NewTest:
            guard let currentSource = state.takeover.modal?.newTestState?.newSourceState else {
                // invariant failure?
                return state
            }
            state.takeover = .modal(.newTest(.newSource(currentSource.with(serverHostOverride: server))))
            return state
        case .changeParser(let parser) as NewTest:
            guard let currentSource = state.takeover.modal?.newTestState?.newSourceState else {
                // invariant failure?
                return state
            }
            state.takeover = .modal(.newTest(.newSource(currentSource.with(parser: parser))))
            return state
        case .toggleOpen as Settings:
            if let editor = state.takeover.settingsEditor {
                if let host = URL(string: editor.host) {
                    state.host = host
                }
                state.takeover = .none
            } else {
                state.takeover = .settings(.init(host: state.host.absoluteString))
            }
            return state
        case .open as Help:
            state.takeover = .help
            return state
        case .close as Help:
            state.takeover = .none
            return state
        case .toggleDetailsLogsOrMessages as TestDetails:
            switch state.detailsViewing {
            case .logs:
                state.detailsViewing = .messages
            case .messages:
                state.detailsViewing = .logs
            }
            return state
        case .highlightMessage(let messageId, turnedOn: let on) as TestDetails:
            if on {
                state.highlightedMessages.insert(messageId)
            } else {
                state.highlightedMessages.remove(messageId)
            }
            return state
        case .show(let content) as Toast:
            state.toastQueue.append(content)
            return state
        case .hide(let content) as Toast:
            state.toastQueue.removeAll { $0 == content }
            return state
        case .changeHost(let proposedURL) as Settings:
            if case let .settings(editor) = state.takeover {
                state.takeover = .settings(editor.with(host: proposedURL))
            }
            return state
        case .apply(let filterText) as Filter:
            state.filterText = filterText
            return state
        case let selectTest as SelectTest:
            state.selectedTestId = selectTest.testId
            return state
        case .field(let field) as Toggle:
            state.toggles[keyPath: field].toggle()
            return state
        default:
            return state
        }
    }
}
