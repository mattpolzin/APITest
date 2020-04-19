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

    var recentlyUsedSource: API.OpenAPISource.Id?

    var toggles: Toggles

    var modal: Modal

    var settingsEditor: SettingsEditor?

    init() {
        entities = .init()
        host = URL(string: "http://localhost:8080")!
        toggles = .init(messages: .init())
        modal = .none
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
    struct SettingsEditor: Equatable {
        @Validated<URLStringValidator>
        var host: String
    }
}

extension AppState {
    enum Modal: Equatable {
        case none
        case newTest

        var isNewTest: Bool {
            guard case .newTest = self else {
                return false
            }
            return true
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
            state.modal = .newTest
            return state
        case .dismiss as NewTest:
            state.modal = .none
            return state
        case .toggleOpen as Settings:
            if let editor = state.settingsEditor {
                if let host = URL(string: editor.host) {
                    state.host = host
                }
                state.settingsEditor = nil
            } else {
                state.settingsEditor = .init(host: state.host.absoluteString)
            }
            return state
        case .changeHost(let proposedURL) as Settings:
            state.settingsEditor?.host = proposedURL
            return state
        case let selectTest as SelectTest:
            state.selectedTestId = selectTest.testId
            return state
        case let toggle as Toggle:
            state.toggles[keyPath: toggle.field].toggle()
            return state
        default:
            return state
        }
    }
}
