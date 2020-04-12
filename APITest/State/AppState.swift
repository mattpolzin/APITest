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
    var entityCache: EntityCache

    init() {
        entityCache = .init()
    }
}

extension AppState {
    static func reducer(action: ReSwift.Action, state: AppState?) -> AppState {
        var state = state ?? AppState()

        switch action {
        case let .response(entities) as API.EntityUpdate:
            state.entityCache.merge(with: entities)
            return state
        default:
            return state
        }
    }
}
