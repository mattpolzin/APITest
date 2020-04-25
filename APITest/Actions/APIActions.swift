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
        case request(RequestSource)

        enum RequestSource: Equatable {
            case `default`
            case new(uri: String)
            case existing(id: API.OpenAPISource.Id)
        }
    }

    struct GetTest: ReSwift.Action {
        let id: API.APITestDescriptor.Id
        let requestType: RequestType

        enum RequestType {
            case descriptor(includeMessages: Bool, includeSource: Bool)
            case rawLogs
        }

        static func requestDescriptor(id: API.APITestDescriptor.Id, includeMessages: Bool, includeSource: Bool) -> Self {
            .init(id: id, requestType: .descriptor(includeMessages: includeMessages, includeSource: includeSource))
        }

        static func requestRawLogs(id: API.APITestDescriptor.Id) -> Self {
            .init(id: id, requestType: .rawLogs)
        }
    }

    enum GetAllTests: ReSwift.Action {
        case request
    }

    enum GetAllSources: ReSwift.Action {
        case request
    }

    enum WatchTests: ReSwift.Action {
        case start
        case stop
    }
}
