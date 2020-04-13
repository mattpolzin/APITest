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

    var selectedTestId: API.APITestDescriptor.Id?

    var toggles: Toggles

    init() {
        entities = .init()
        toggles = .init(messages: .init())
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
    static func reducer(action: ReSwift.Action, state: AppState?) -> AppState {
        var state = state ?? AppState()

        switch action {
        case let .response(entities) as API.EntityUpdate:
            state.entities.merge(with: entities)
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
