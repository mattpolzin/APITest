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
import JSONAPI
import JSONAPIResourceCache
import CombineAPIRequest
import CombineReSwift
import JSONAPICombine

final class APIMiddlewareController {

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

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
                    case .new(uri: let uri, apiHostOverride: let apiHostOverride):
                        guard let uri = uri else {
                            self.perform(
                                try! API.Request
                                    .newProperties(host: state.host, source: nil, apiHostOverride: apiHostOverride)
                                    .publisher(using: Self.decoder)
                                    .primaryAndEntities
                                    .dispatch(
                                        \.cacheAction,
                                        { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                                    )
                                    .dispatchError(anyRequestFailureToast(message: "Failed to start a new test run"))
                            )
                            return
                        }

                        self.perform(
                            try! API.Request
                                .newSource(host: state.host, uri: uri)
                                .publisher(using: Self.decoder)
                                .primaryAndEntities
                                .chain(
                                    try! API.Request.newProperties(host: state.host, apiHostOverride: apiHostOverride),
                                    using: Self.decoder
                                )
                                .primaryAndEntities
                                .dispatch(
                                    \.cacheAction,
                                    { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                                )
                                .dispatchError(anyRequestFailureToast(message: "Failed to start a new test run"))
                        )
                        return
                    }

                    self.perform(
                        try! API.Request
                            .newTest(host: state.host, propertiesId: propertiesId)
                            .publisher(using: Self.decoder)
                            .entities
                            .cache()
                            .dispatchError(anyRequestFailureToast(message: "Failed to start a new test run"))
                    )

                case .request as API.GetAllTests:
                    self.perform(
                        try! API.Request
                            .allTests(host: state.host)
                            .publisher(using: Self.decoder)
                            .entities
                            .cache()
                            .dispatchError(missingPrimaryResourceToast(message: "Failed to retrieve primary resources and includes from batch test descriptor response"))
                    )

                case let request as API.GetTest:
                    switch request.requestType {
                    case .descriptor(let includeMessages, let (includeProperties, alsoIncludeSource)):

                        self.perform(
                            try! API.Request
                                .test(host: state.host, id: request.id, includingMessages: includeMessages, includingProperties: (includeProperties, alsoSource: alsoIncludeSource))
                                .publisher(using: Self.decoder)
                                .entities
                                .cache()
                                .dispatchError(missingPrimaryResourceToast(message: "Failed to retrieve primary resources and includes from single test descriptor response"))
                        )

                    case .rawLogs:
                        self.perform(
                            try! API.Request
                                .rawLogs(host: state.host, testId: request.id)
                                .publisher
                                .mapEntities { logs -> EntityCache in
                                    var entities = EntityCache()

                                    entities.testLogs[request.id] = logs

                                    return entities
                                }
                                .cache()
                                .dispatchError(responseDecodingErrorToast(message: "Failed to decode plaintext response"))
                        )
                    }

                case .request as API.GetAllSources:
                    self.perform(
                        try! API.Request
                            .allSources(host: state.host)
                            .publisher(using: Self.decoder)
                            .entities
                            .cache()
                            .dispatchError(missingPrimaryResourceToast(message: "Failed to retrieve primary resources from batch openapi source response"))
                    )

                case .request as API.GetAllProperties:
                    self.perform(
                        try! API.Request
                            .allProperties(host: state.host)
                            .publisher(using: Self.decoder)
                            .entities
                            .cache()
                            .dispatchError(missingPrimaryResourceToast(message: "Failed to retrieve primary resources from batch api test properties response"))
                    )

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

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        return try decoder.decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        return try encoder.encode(value)
    }
}

extension APIMiddlewareController {

    /// Performs some published task that results in
    /// Actions and subscribes the Store to that
    /// publisher.
    func perform<RequestPublisher: Publisher>(_ publisher: RequestPublisher) where RequestPublisher.Output == ReSwift.Action {
        publisher
            // TODO: maybe don't present a toast for all request failures...
            .dispatchError(
                { error in (error as? URLError).map { _ in Toast.apiError(message: "Network Request Failed") } }
            )
            .mapError { $0 as? ResponseFailure ?? .unknown(String(describing: $0)) }
            .print()
            .subscribe(store)
    }
}

extension API {
    enum Request {
        static func newSource(host: URL, uri: String) throws -> APIRequest<API.CreateOpenAPISourceDocument, API.SingleOpenAPISourceDocument> {
            let document = API.newOpenAPISourceDocument(uri: uri)

            return try APIRequest(
                .post,
                host: host,
                path: "/openapi_sources",
                body: document,
                encode: APIMiddlewareController.encoder.encode
            )
        }

        static func newProperties(
            host: URL,
            source: SingleEntityResultPair<API.OpenAPISource>?,
            apiHostOverride: URL?
        ) throws -> APIRequest<API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            let document = try API.newPropertiesDocument(from: source, apiHostOverride: apiHostOverride)

            return try APIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: document,
                encode: APIMiddlewareController.encoder.encode
            )
        }

        static func newProperties(
            host: URL,
            apiHostOverride: URL?
        ) throws -> PartialAPIRequest<SingleEntityResultPair<API.OpenAPISource>?, API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            try PartialAPIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: { try API.newPropertiesDocument(from: $0, apiHostOverride: apiHostOverride) },
                encode: APIMiddlewareController.encoder.encode
            )
        }

        /// Create tests with `nil` properties Id to allow the server to pick
        /// default properties.
        static func newTest(
            host: URL,
            propertiesId: API.APITestProperties.Id?
        ) throws -> APIRequest<API.CreateAPITestDescriptorDocument, API.SingleAPITestDescriptorDocument> {
            let testDescriptor = API.NewAPITestDescriptor(
                attributes: .none,
                relationships: .init(testProperties: propertiesId.map { .init(id: $0) }),
                meta: .none,
                links: .none
            )
            let document = API.CreateAPITestDescriptorDocument(
                body: .init(resourceObject: testDescriptor)
            )

            return try APIRequest(
                .post,
                host: host,
                path: "/api_tests",
                body: document,
                encode: APIMiddlewareController.encoder.encode
            )
        }

        static func test(
            host: URL,
            id: API.APITestDescriptor.Id,
            includingMessages includeMessages: Bool,
            includingProperties includeProperties: (Bool, alsoSource: Bool)
        ) throws -> APIRequest<Void, API.SingleAPITestDescriptorDocument> {
            var includes = [String]()

            if includeProperties.0 {
                includes.append("testProperties")
                if includeProperties.alsoSource { includes.append("testProperties.openAPISource") }
            }
            if includeMessages { includes.append("messages") }

            return try APIRequest(
                .get,
                host: host,
                path: "/api_tests/\(id.rawValue.uuidString)",
                including: includes
            )
        }

        static func allTests(host: URL) throws -> APIRequest<Void, API.BatchAPITestDescriptorDocument> {
            try APIRequest(
                .get,
                host: host,
                path: "/api_tests"
            )
        }

        static func allSources(host: URL) throws -> APIRequest<Void, API.BatchOpenAPISourceDocument> {
            try APIRequest(
                .get,
                host: host,
                path: "/openapi_sources"
            )
        }

        static func allProperties(host: URL) throws -> APIRequest<Void, API.BatchAPITestPropertiesDocument> {
            try APIRequest(
                .get,
                host: host,
                path: "/api_test_properties",
                including: ["openAPISource"]
            )
        }

        static func rawLogs(host: URL, testId: API.APITestDescriptor.Id) throws -> APIRequest<Void, String> {
            try APIRequest(
                .get,
                contentType: .plaintext,
                host: host,
                path: "/api_tests/\(testId.rawValue.uuidString)/logs"
            )
        }
    }
}

extension API {
    /// make a request document to create test properties with the given
    /// OpenAPI source and host override.
    ///
    /// In both cases `nil` is allowed. A `nil` override is
    /// "don't override" and a `nil` source document means the default source
    /// for the server if one is defined.
    static func newPropertiesDocument(from source: SingleEntityResultPair<API.OpenAPISource>?, apiHostOverride: URL?) throws -> API.CreateAPITestPropertiesDocument {
        let properties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: apiHostOverride),
            relationships: .init(openAPISource: source.map { .init(resourceObject: $0.primaryResource) }),
            meta: .none,
            links: .none
        )

        return API.CreateAPITestPropertiesDocument(
            body: .init(resourceObject: properties)
        )
    }

    static func newOpenAPISourceDocument(uri: String) -> API.CreateOpenAPISourceDocument {
        let sourceType: API.SourceType
        if URL(string: uri)?.host != nil {
            sourceType = .url
        } else {
            sourceType = .filepath
        }
        let source = API.NewOpenAPISource(
            attributes: .init(
                createdAt: Date(),
                uri: uri,
                sourceType: sourceType
            ),
            relationships: .none,
            meta: .none,
            links: .none
        )
        return API.CreateOpenAPISourceDocument(
            body: .init(resourceObject: source)
        )
    }
}

func toast(given condition: @autoclosure () -> Bool, message: String) -> Toast? {
    guard condition() else { return nil }

    return Toast.apiError(message: message)
}

func anyRequestFailureToast(message: String) -> (Error) -> ReSwift.Action? {
    return { error in
        toast(
            given: error is RequestFailure,
            message: message
        )
    }
}

func missingPrimaryResourceToast(message: String) -> (Error) -> ReSwift.Action? {
    return { error in
        toast(
            given: (error as? ResponseFailure)?.isMissingPrimaryResource ?? false,
            message: message
        )
    }
}

func responseDecodingErrorToast(message: String) -> (Error) -> ReSwift.Action? {
    return { error in
        toast(
            given: (error as? ResponseFailure)?.isResponseDecoding ?? false,
            message: message
        )
    }
}
