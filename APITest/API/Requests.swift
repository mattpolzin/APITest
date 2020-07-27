//
//  Requests.swift
//  APITest
//
//  Created by Mathew Polzin on 7/15/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import APIModels
import CombineAPIRequest
import JSONAPICombine
import Combine
import ReSwift

fileprivate let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()

fileprivate let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

extension API {
    enum Publish {
        typealias Action = AnyPublisher<ReSwift.Action, Error>

        static func newSource(
            host: URL,
            uri: String?,
            apiHostOverride: URL?,
            parser: API.Parser
        ) throws -> Action {
            guard let uri = uri else {
                return try API.Request
                .newProperties(host: host, source: nil, apiHostOverride: apiHostOverride, parser: parser)
                .publisher(using: decoder)
                .primaryAndEntities
                .dispatch(
                    \.cacheAction,
                    { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                )
                .dispatchError(
                    anyRequestFailureToast(
                        message: "Failed to start a new test run"
                    )
                )
                .eraseToAnyPublisher()
            }

            return try API.Request
            .newSource(host: host, uri: uri)
            .publisher(using: decoder)
            .primaryAndEntities
            .chain(
                try! API.Request.newProperties(host: host, apiHostOverride: apiHostOverride, parser: parser),
                using: decoder
            )
            .primaryAndEntities
            .dispatch(
                \.cacheAction,
                { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
            )
            .dispatchError(
                anyRequestFailureToast(
                    message: "Failed to start a new test run"
                )
            )
            .eraseToAnyPublisher()
        }

        static func newTest(
            host: URL,
            propertiesId: API.APITestProperties.Id?
        ) throws -> Action {
            try API.Request
            .newTest(host: host, propertiesId: propertiesId)
            .publisher(using: decoder)
            .entities
            .cache()
            .dispatchError(
                anyRequestFailureToast(
                    message: "Failed to start a new test run"
                )
            )
            .eraseToAnyPublisher()
        }

        static func allTests(host: URL) throws -> Action {
            try API.Request
            .allTests(host: host)
            .publisher(using: decoder)
            .entities
            .cache()
            .dispatchError(
                missingPrimaryResourceToast(
                    message: "Failed to retrieve primary resources and includes from batch test descriptor response"
                )
            )
            .eraseToAnyPublisher()
        }

        static func test(
            host: URL,
            id: API.APITestDescriptor.Id,
            includingMessages includeMessages: Bool,
            includingProperties includeProperties: (Bool, alsoSource: Bool)
        ) throws -> Action {
            try API.Request
            .test(
                host: host,
                id: id,
                includingMessages: includeMessages,
                includingProperties: includeProperties
            )
            .publisher(using: decoder)
            .entities
            .cache()
            .dispatchError(
                missingPrimaryResourceToast(
                    message: "Failed to retrieve primary resources and includes from single test descriptor response"
                )
            )
            .eraseToAnyPublisher()
        }

        static func rawLogs(host: URL, testId: API.APITestDescriptor.Id) throws -> Action {
            try API.Request
            .rawLogs(host: host, testId: testId)
            .publisher
            .mapEntities { logs -> EntityCache in
                var entities = EntityCache()

                entities.testLogs[testId] = logs

                return entities
            }
            .cache()
            .dispatchError(
                responseDecodingErrorToast(
                    message: "Failed to decode plaintext response"
                )
            )
            .eraseToAnyPublisher()
        }

        static func allSources(host: URL) throws -> Action {
            try API.Request
            .allSources(host: host)
            .publisher(using: decoder)
            .entities
            .cache()
            .dispatchError(
                missingPrimaryResourceToast(
                    message:
                    "Failed to retrieve primary resources from batch openapi source response"
                )
            )
            .eraseToAnyPublisher()
        }

        static func allProperties(host: URL) throws -> Action {
            try API.Request
            .allProperties(host: host)
            .publisher(using: decoder)
            .entities
            .cache()
            .dispatchError(
                missingPrimaryResourceToast(
                    message: "Failed to retrieve primary resources from batch api test properties response"
                )
            )
            .eraseToAnyPublisher()
        }
    }

    enum Request {
        static func newSource(host: URL, uri: String) throws -> APIRequest<API.CreateOpenAPISourceDocument, API.SingleOpenAPISourceDocument> {
            let document = API.newOpenAPISourceDocument(uri: uri)

            return try APIRequest(
                .post,
                host: host,
                path: "/openapi_sources",
                body: document,
                encode: encoder.encode
            )
        }

        static func newProperties(
            host: URL,
            source: SingleEntityResultPair<API.OpenAPISource>?,
            apiHostOverride: URL?,
            parser: API.Parser
        ) throws -> APIRequest<API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            let document = try API.newPropertiesDocument(from: source, apiHostOverride: apiHostOverride, parser: parser)

            return try APIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: document,
                encode: encoder.encode
            )
        }

        static func newProperties(
            host: URL,
            apiHostOverride: URL?,
            parser: API.Parser
        ) throws -> PartialAPIRequest<SingleEntityResultPair<API.OpenAPISource>?, API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            try PartialAPIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: { try API.newPropertiesDocument(from: $0, apiHostOverride: apiHostOverride, parser: parser) },
                encode: encoder.encode
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
                encode: encoder.encode
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
    static func newPropertiesDocument(from source: SingleEntityResultPair<API.OpenAPISource>?, apiHostOverride: URL?, parser: API.Parser) throws -> API.CreateAPITestPropertiesDocument {
        let properties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: apiHostOverride, parser: parser),
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
