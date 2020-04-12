//
//  APIActions.swift
//  APITest
//
//  Created by Mathew Polzin on 4/11/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift
import APIModels

extension API {
    enum EntityUpdate: ReSwift.Action {
        case response(entities: EntityCache)
    }

    enum StartTest: ReSwift.Action {
        case request
    }

    enum GetTest: ReSwift.Action {
        case request(id: API.APITestDescriptor.Id, includeMessages: Bool)
    }

    enum GetAllTests: ReSwift.Action {
        case request
    }
}
