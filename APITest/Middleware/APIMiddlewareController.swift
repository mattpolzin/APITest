//
//  APIMiddlewareController.swift
//  APITest
//
//  Created by Mathew Polzin on 4/11/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift
import APIModels
import Combine
import JSONAPICombine

final class APIMiddlewareController {

    let testWatchController: APITestWatcherController = APITestWatcherController()

    func middleware(dispatch: @escaping DispatchFunction, getState: @escaping () -> AppState?) -> (@escaping DispatchFunction) -> DispatchFunction {
        return { next in
            return { action in
                // this middleware passes the action on and then handles it after reduction.

                next(action)

                guard let state = getState() else { return }

                switch action {
                case let .request(source) as API.StartTest:
                    self.testWatchController.connectIfNeeded(to: state.host)

                    let propertiesId: API.APITestProperties.Id?

                    switch source {
                    case .default:
                        propertiesId = nil
                    case .existing(id: let id):
                        propertiesId = id
                    case .new(uri: let uri, apiHostOverride: let apiHostOverride, parser: let parser):
                        self.perform {
                            try API.Publish.newSource(
                                host: state.host,
                                uri: uri,
                                apiHostOverride: apiHostOverride,
                                parser: parser
                            )
                        }
                        return
                    }

                    self.perform {
                        try API.Publish.newTest(
                            host: state.host,
                            propertiesId: propertiesId
                        )
                    }

                case .request as API.GetAllTests:
                    self.perform {
                        try API.Publish.allTests(host: state.host)
                    }

                case let request as API.GetTest:
                    switch request.requestType {
                    case .descriptor(let includeMessages, let (includeProperties, alsoIncludeSource)):

                        self.perform {
                            try API.Publish.test(
                                host: state.host,
                                id: request.id,
                                includingMessages: includeMessages,
                                includingProperties: (includeProperties, alsoSource: alsoIncludeSource)
                            )
                        }

                    case .rawLogs:
                        self.perform {
                            try API.Publish.rawLogs(host: state.host, testId: request.id)
                        }
                    }

                case .request as API.GetAllSources:
                    self.perform {
                        try API.Publish.allSources(host: state.host)
                    }

                case .request as API.GetAllProperties:
                    self.perform {
                        try API.Publish.allProperties(host: state.host)
                    }

                case .start as API.WatchTests:
                    self.testWatchController.connectIfNeeded(to: state.host)

                case .stop as API.WatchTests:
                    self.testWatchController.disconnect()

                case .toggleOpen as Settings where state.takeover.settingsEditor == nil:
                    // this means the settings editor was just closed.
                    self.testWatchController.connectIfNeeded(to: state.host)
                    store.dispatch(API.GetAllTests.request)

                default:
                    break
                }
            }
        }
    }
}

extension APIMiddlewareController {

    /// Performs some published task that results in
    /// Actions and subscribes the Store to that
    /// publisher.
    func perform<RequestPublisher: Publisher>(_ publisher: @escaping () throws -> RequestPublisher) where RequestPublisher.Output == ReSwift.Action {
        Just(publisher)
        .tryMap { try $0() }
        .flatMap { publisher in
            // TODO: maybe don't present a toast for all request failures...
            publisher.dispatchError(
                { error in (error as? URLError).map { _ in Toast.apiError(message: "Network Request Failed") } }
            )
            .mapError { $0 as? ResponseFailure ?? .unknown(String(describing: $0)) }
        }
        .subscribe(store)
    }
}
