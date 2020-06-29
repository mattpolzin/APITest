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

    var nextRequestId: Int = 0
    var requests: [Int: AnyCancellable] = [:]

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
                                    .publish
                                    .mapPrimaryAndEntities()
                                    .dispatch(
                                        \.cacheAction,
                                        { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                                    )
                                    .dispatchError(
                                        { error in (error as? RequestFailure).map { _ in Toast.apiError(message: "Failed to start a new test run") } }
                                    )
                            )
                            return
                        }

                        self.perform(
                            try! API.Request
                                .newSource(host: state.host, uri: uri)
                                .publish
                                .mapPrimaryAndEntities()
                                .chain(try! API.Request.newProperties(host: state.host, apiHostOverride: apiHostOverride))
                                .mapPrimaryAndEntities()
                                .dispatch(
                                    \.cacheAction,
                                    { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                                )
                                .dispatchError(
                                    { error in (error as? RequestFailure).map { _ in Toast.apiError(message: "Failed to start a new test run") } }
                                )
                        )
                        return
                    }

                    self.perform(
                        try! API.Request
                            .newTest(host: state.host, propertiesId: propertiesId)
                            .publish
                            .mapEntities()
                            .dispatch(\.cacheAction)
                            .dispatchError { error in (error as? RequestFailure).map { _ in Toast.apiError(message: "Failed to start a new test run") } }
                    )

                case .request as API.GetAllTests:
                    self.perform(
                        try! API.Request
                            .allTests(host: state.host)
                            .publish
                            .mapEntities()
                            .dispatch(\.cacheAction)
                            .dispatchError(
                                { error in (error as? RequestFailure).flatMap { $0.isMissingPrimaryResource ? Toast.apiError(message: "Failed to retrieve primary resources and includes from batch test descriptor response") : nil } }
                            )
                    )

                case let request as API.GetTest:
                    switch request.requestType {
                    case .descriptor(let includeMessages, let (includeProperties, alsoIncludeSource)):
                        var includes = [String]()

                        if includeProperties {
                            includes.append("testProperties")
                            if alsoIncludeSource { includes.append("testProperties.openAPISource") }
                        }
                        if includeMessages { includes.append("messages") }

                        self.jsonApiRequest(
                            .get,
                            host: state.host,
                            path: "/api_tests/\(request.id.rawValue.uuidString)",
                            including: includes
                        ) { (response: API.SingleAPITestDescriptorDocument) -> EntityCache in
                            guard let entities = response.resourceCache() else {
                                    print("failed to retrieve primary resources and includes from single test descriptor response")
                                    store.dispatch(Toast.apiError(message: "Failed to retrieve primary resources and includes from single test descriptor response"))
                                    return EntityCache()
                            }

                            return entities
                        }

                    case .rawLogs:
                        self.plaintextRequest(
                            .get,
                            host: state.host,
                            path: "/api_tests/\(request.id.rawValue.uuidString)/logs"
                        ) { logs in
                            var entities = EntityCache()

                            entities.testLogs[request.id] = logs

                            return entities
                        }
                    }

                case .request as API.GetAllSources:
                    self.perform(
                        try! API.Request
                            .allSources(host: state.host)
                            .publish
                            .mapEntities()
                            .dispatch(\.cacheAction)
                            .dispatchError(
                                { error in (error as? RequestFailure).flatMap { $0.isMissingPrimaryResource ? Toast.apiError(message: "Failed to retrieve primary resources from batch openapi source response") : nil } }
                            )
                    )

                case .request as API.GetAllProperties:
                    self.perform(
                        try! API.Request
                            .allProperties(host: state.host)
                            .publish
                            .mapEntities()
                            .dispatch(\.cacheAction)
                            .dispatchError(
                                { error in (error as? RequestFailure).flatMap { $0.isMissingPrimaryResource ? Toast.apiError(message: "Failed to retrieve primary resources from batch api test properties response") : nil } }
                            )
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

    deinit {
        for request in requests.values {
            request.cancel()
        }
        requests.removeAll()
    }
}

extension APIMiddlewareController {

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        return try decoder.decode(type, from: data)
    }

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        return try encoder.encode(value)
    }

    @discardableResult
    func plaintextRequest(
        _ verb: HttpVerb,
        host: URL,
        path: String,
        parsingWith entities: @escaping (String) -> EntityCache
    ) -> AnyCancellable {
        var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: false)!

        urlComponents.path = path

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = verb.rawValue
        request.addValue("text/plain", forHTTPHeaderField: "Content-Type")

        let requestId = self.nextRequestId
        self.nextRequestId += 1

        let inFlightRequest = URLSession.shared
            .dataTaskPublisher(for: request)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .failure(let failure):
                        DispatchQueue.main.async {
                            store.dispatch(Toast.apiError(message: failure.localizedDescription))
                        }
                        print(String(describing: failure))
                    case .finished:
                        break
                    }
                    DispatchQueue.main.async {
                        self.requests.removeValue(forKey: requestId)
                    }
            },
                receiveValue: { response in
                    guard let status = (response.response as? HTTPURLResponse)?.statusCode else {
                        print("something went really wrong with request to \(request.url?.absoluteString ?? "unknown url"). no status code. response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard status >= 200 && status < 300 else {
                        print("request to \(request.url?.absoluteString ?? "unknown url") failed with status code: \(status)")
                        print("response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard let value = String(data: response.data, encoding: .utf8) else {
                        print("failed to decode JSON:API response from \(request.url?.absoluteString ?? "unknown url")")
                        DispatchQueue.main.async {
                            store.dispatch(Toast.apiError(message: "Failed to decode plaintext response"))
                        }
                        return
                    }

                    let update = entities(value).asUpdate

                    DispatchQueue.main.async {
                        store.dispatch(update)
                    }
            })

        self.requests[requestId] = inFlightRequest

        return inFlightRequest
    }

    @discardableResult
    func jsonApiRequest<Request: EncodableJSONAPIDocument, Response: CodableJSONAPIDocument>(
        _ verb: HttpVerb,
        host: URL,
        path: String,
        body: Request,
        including includes: [String] = [],
        parsingWith entities: @escaping (Response) -> EntityCache
    ) throws -> AnyCancellable {
        let bodyData = try Self.encode(body)
        return jsonApiRequest(verb, host: host, path: path, bodyData: bodyData, including: includes, parsingWith: entities)
    }

    @discardableResult
    func jsonApiRequest<Response: CodableJSONAPIDocument>(
        _ verb: HttpVerb,
        host: URL,
        path: String,
        bodyData: Data? = nil,
        including includes: [String] = [],
        parsingWith entities: @escaping (Response) -> EntityCache
    ) -> AnyCancellable {
        var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: false)!

        urlComponents.path = path
        if includes.count > 0 {
            urlComponents.queryItems = [.init(name: "include", value: includes.joined(separator: ","))]
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = verb.rawValue
        request.httpBody = bodyData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestId = self.nextRequestId
        self.nextRequestId += 1

        let inFlightRequest = URLSession.shared
            .dataTaskPublisher(for: request)
            .sink(
                receiveCompletion: { result in
                    switch result {
                    case .failure(let failure):
                        DispatchQueue.main.async {
                            store.dispatch(Toast.apiError(message: failure.localizedDescription))
                        }
                        print(String(describing: failure))
                    case .finished:
                        break
                    }
                    DispatchQueue.main.async {
                        self.requests.removeValue(forKey: requestId)
                    }
            },
                receiveValue: { response in
                    guard let status = (response.response as? HTTPURLResponse)?.statusCode else {
                        print("something went really wrong with request to \(request.url?.absoluteString ?? "unknown url"). no status code. response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard status >= 200 && status < 300 else {
                        print("request to \(request.url?.absoluteString ?? "unknown url") failed with status code: \(status)")
                        print("response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard let value = try? Self.decode(Response.self, from: response.data) else {
                        print("failed to decode JSON:API response from \(request.url?.absoluteString ?? "unknown url")")
                        DispatchQueue.main.async {
                            store.dispatch(Toast.apiError(message: "Failed to decode JSON:API response"))
                        }
                        return
                    }

                    let update = entities(value).asUpdate

                    DispatchQueue.main.async {
                        store.dispatch(update)
                    }
        })

        self.requests[requestId] = inFlightRequest

        return inFlightRequest
    }
}

extension APIMiddlewareController {

    /// Performs some published task that results in
    /// Actions and subscribes the Store to that
    /// publisher.
    func perform<RequestPublisher: Publisher>(_ publisher: RequestPublisher) where RequestPublisher.Output == ReSwift.Action {
        publisher.mapError { $0 as? RequestFailure ?? .unknown(String(describing: $0)) }
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
                body: document
            )
        }

        static func newProperties(host: URL, source: SingleEntityResultPair<API.OpenAPISource>?, apiHostOverride: URL?) throws -> APIRequest<API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            let document = try API.newPropertiesDocument(from: source, apiHostOverride: apiHostOverride)

            return try APIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: document
            )
        }

        static func newProperties(host: URL, apiHostOverride: URL?) throws -> PartialAPIRequest<SingleEntityResultPair<API.OpenAPISource>?, API.CreateAPITestPropertiesDocument, API.SingleAPITestPropertiesDocument> {
            try PartialAPIRequest(
                .post,
                host: host,
                path: "/api_test_properties",
                body: { try API.newPropertiesDocument(from: $0, apiHostOverride: apiHostOverride) }
            )
        }

        /// Create tests with `nil` properties Id to allow the server to pick
        /// default properties.
        static func newTest(host: URL, propertiesId: API.APITestProperties.Id?) throws -> APIRequest<API.CreateAPITestDescriptorDocument, API.SingleAPITestDescriptorDocument> {
            let relationships = API.NewAPITestDescriptor.Description.Relationships(
                testProperties: propertiesId.map { .init(id: $0) }
            )
            let testDescriptor = API.NewAPITestDescriptor(
                attributes: .none,
                relationships: relationships,
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
                body: document
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
    }
}

enum HttpVerb: String, Equatable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

struct PartialAPIRequest<Context, Request: Encodable, Response: Decodable> {
    let method: HttpVerb
    let url: (Context) throws -> URL
    let bodyData: (Context) throws -> Data?

    func `for`(context: Context) throws -> APIRequest<Request, Response> {
        return APIRequest(
            method: method,
            url: try url(context),
            bodyData: try bodyData(context)
        )
    }

    init(
        _ method: HttpVerb,
        url: @escaping (Context) -> URL,
        body: @escaping (Context) throws -> Request?,
        responseType: Response.Type
    ) {
        self.method = method
        self.url = url
        self.bodyData = { context in try APIMiddlewareController.encoder
            .encode(body(context)) }
    }

    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        body: @escaping (Context) throws -> Request?,
        including includes: [String] = [],
        responseType: Response.Type
    ) throws {
        try self.init(
            method,
            host: host,
            path: path,
            body: body,
            including: includes
        )
    }

    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        body: @escaping (Context) throws -> Request?,
        including includes: [String] = []
    ) throws {
        var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: false)!

        urlComponents.path = path
        if includes.count > 0 {
            urlComponents.queryItems = [.init(name: "include", value: includes.joined(separator: ","))]
        }

        guard let url = urlComponents.url else {
            throw RequestFailure.urlConstruction(String(describing: urlComponents))
        }
        self.url = { _ in url }

        self.method = method
        self.bodyData = { context in try APIMiddlewareController.encoder
            .encode(body(context)) }
    }
}

struct APIRequest<Request, Response: Decodable> {
    let method: HttpVerb
    let url: URL
    let bodyData: Data?

    var publish: Publishers.Decode<Publishers.TryMap<URLSession.DataTaskPublisher, JSONDecoder.Input>, Response, JSONDecoder> {

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = bodyData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { (data, response) in
                guard let status = (response as? HTTPURLResponse)?.statusCode else {
                    print("something went really wrong with request to \(request.url?.absoluteString ?? "unknown url"). no status code. response body: \(String(data: data, encoding: .utf8) ?? "Not UTF8 encoded")")
                    throw RequestFailure.unknown("something went really wrong with request to \(request.url?.absoluteString ?? "unknown url"). no status code. response body: \(String(data: data, encoding: .utf8) ?? "Not UTF8 encoded")")
                }

                guard status >= 200 && status < 300 else {
                    print("request to \(request.url?.absoluteString ?? "unknown url") failed with status code: \(status)")
                    print("response body: \(String(data: data, encoding: .utf8) ?? "Not UTF8 encoded")")
                    throw URLError(.init(rawValue: status))
                }

                return data
            }
            .decode(type: Response.self, decoder: APIMiddlewareController.decoder)
    }
}

extension APIRequest where Request == Void {
    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        including includes: [String] = [],
        responseType: Response.Type
    ) throws {
        try self.init(
            method,
            host: host,
            path: path,
            including: includes
        )
    }

    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        including includes: [String] = []
    ) throws {
        self.method = method
        self.bodyData = nil

        var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: false)!

        urlComponents.path = path
        if includes.count > 0 {
            urlComponents.queryItems = [.init(name: "include", value: includes.joined(separator: ","))]
        }

        guard let url = urlComponents.url else {
            throw RequestFailure.urlConstruction(String(describing: urlComponents))
        }
        self.url = url
    }
}

extension APIRequest where Request: Encodable {
    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        body: Request,
        including includes: [String] = []
    ) throws {
        try self.init(
            method,
            host: host,
            path: path,
            body: body,
            including: includes
        )
    }

    init(
        _ method: HttpVerb,
        host: URL,
        path: String,
        body: Request,
        including includes: [String] = [],
        responseType: Response.Type
    ) throws {
        self.method = method
        self.bodyData = try APIMiddlewareController.encoder
            .encode(body)

        var urlComponents = URLComponents(url: host, resolvingAgainstBaseURL: false)!

        urlComponents.path = path
        if includes.count > 0 {
            urlComponents.queryItems = [.init(name: "include", value: includes.joined(separator: ","))]
        }

        guard let url = urlComponents.url else {
            throw RequestFailure.urlConstruction(String(describing: urlComponents))
        }
        self.url = url
    }

    static func transformation<Other>(
        _ method: HttpVerb,
        host: URL,
        path: String,
        including includes: [String] = [],
        requestBodyConstructor: @escaping (Other) throws -> Request,
        responseType: Response.Type
    ) -> (Other) throws -> APIRequest {
        return { existingDocument in
            try APIRequest(
                method,
                host: host,
                path: path,
                body: try requestBodyConstructor(existingDocument),
                including: includes,
                responseType: responseType
            )
        }
    }
}

extension Publisher {

    func chain<Request: Encodable, Response: Decodable>(
        _ partialRequest: PartialAPIRequest<Output?, Request, Response>
    ) -> Publishers.FlatMap<Publishers.Decode<Publishers.TryMap<URLSession.DataTaskPublisher, JSONDecoder.Input>, Response, JSONDecoder>, Publishers.TryMap<Self, APIRequest<Request, Response>>> {
        self
            .tryMap(partialRequest.for(context:))
            .flatMap { $0.publish }
    }

    func chain<Request: Encodable, Response: Decodable>(
        _ partialRequest: PartialAPIRequest<Output, Request, Response>
    ) -> Publishers.FlatMap<Publishers.Decode<Publishers.TryMap<URLSession.DataTaskPublisher, JSONDecoder.Input>, Response, JSONDecoder>, Publishers.TryMap<Self, APIRequest<Request, Response>>> {
        self
            .tryMap(partialRequest.for(context:))
            .flatMap { $0.publish }
    }

    func chain<Request: Encodable, Response: Decodable>(
        _ method: HttpVerb,
        host: URL,
        path: String,
        including includes: [String] = [],
        requestBodyConstructor: @escaping (Output) throws -> Request,
        responseType: Response.Type
    ) -> Publishers.FlatMap<Publishers.Decode<Publishers.TryMap<URLSession.DataTaskPublisher, JSONDecoder.Input>, Response, JSONDecoder>, Publishers.TryMap<Self, APIRequest<Request, Response>>> {
        self.tryMap(
            APIRequest.transformation(
                method,
                host: host,
                path: path,
                including: includes,
                requestBodyConstructor: requestBodyConstructor,
                responseType: responseType
            )
        )
        .flatMap { $0.publish }
    }
}

protocol CachableEntities {
    var cacheAction: ReSwift.Action { get }
}

struct SingleEntityResultPair<Primary: CacheableResource>: CachableEntities where Primary.Cache == EntityCache {
    let primaryResource: Primary
    let allEntities: EntityCache

    var cacheAction: Action { allEntities.asUpdate }
}

struct ManyEntityResultPair<Primary: CacheableResource>: CachableEntities where Primary.Cache == EntityCache {
    let primaryResources: [Primary]
    let allEntities: EntityCache

    var cacheAction: Action { allEntities.asUpdate }
}

// Single, no includes
extension Publisher where
    Output: EncodableJSONAPIDocument,
    Output.BodyData.PrimaryResourceBody: SingleResourceBodyProtocol,
    Output.BodyData.PrimaryResourceBody.PrimaryResource: CacheableResource,
    Output.BodyData.IncludeType == NoIncludes,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == EntityCache {

    func mapEntities() -> Publishers.TryMap<Self, EntityCache> {
        self.tryMap(Self.extractEntities)
    }

    func mapPrimaryAndEntities() -> Publishers.TryMap<Self, SingleEntityResultPair<Output.BodyData.PrimaryResourceBody.PrimaryResource>> {
        self.tryMap(Self.extractPrimaryAndEntities)
    }

    static func extractEntities(from document: Output) throws -> EntityCache {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let entities = document.resourceCache() else {
            throw RequestFailure.unknown("Somehow found a document that is not an error document but also failed to create entities.")
        }
        return entities
    }

    static func extractPrimaryAndEntities(from document: Output) throws -> SingleEntityResultPair<Output.BodyData.PrimaryResourceBody.PrimaryResource> {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let primary = document.body.primaryResource?.value, let entities = document.resourceCache() else {
            throw RequestFailure.missingPrimaryResource(String(describing: Output.PrimaryResourceBody.PrimaryResource.self))
        }
        return .init(primaryResource: primary, allEntities: entities)
    }
}

// Single, some includes
extension Publisher where
    Output: EncodableJSONAPIDocument,
    Output.BodyData.PrimaryResourceBody: SingleResourceBodyProtocol,
    Output.BodyData.PrimaryResourceBody.PrimaryResource: CacheableResource,
    Output.BodyData.IncludeType: CacheableResource,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == Output.BodyData.IncludeType.Cache,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == EntityCache {

    func mapEntities() -> Publishers.TryMap<Self, EntityCache> {
        self.tryMap(Self.extractEntities)
    }

    func mapPrimaryAndEntities() -> Publishers.TryMap<Self, SingleEntityResultPair<Output.BodyData.PrimaryResourceBody.PrimaryResource>> {
        self.tryMap(Self.extractPrimaryAndEntities)
    }

    static func extractEntities(from document: Output) throws -> EntityCache {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let entities = document.resourceCache() else {
            throw RequestFailure.unknown("Somehow found a document that is not an error document but also failed to create entities.")
        }
        return entities
    }

    static func extractPrimaryAndEntities(from document: Output) throws -> SingleEntityResultPair<Output.BodyData.PrimaryResourceBody.PrimaryResource> {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let primary = document.body.primaryResource?.value, let entities = document.resourceCache() else {
            throw RequestFailure.missingPrimaryResource(String(describing: Output.PrimaryResourceBody.PrimaryResource.self))
        }
        return .init(primaryResource: primary, allEntities: entities)
    }
}

// Many, no includes
extension Publisher where
    Output: EncodableJSONAPIDocument,
    Output.BodyData.PrimaryResourceBody: ManyResourceBodyProtocol,
    Output.BodyData.PrimaryResourceBody.PrimaryResource: CacheableResource,
    Output.BodyData.IncludeType == NoIncludes,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == EntityCache {

    func mapEntities() -> Publishers.TryMap<Self, EntityCache> {
        self.tryMap(Self.extractEntities)
    }

    func mapPrimaryAndEntities() -> Publishers.TryMap<Self, ManyEntityResultPair<Output.PrimaryResourceBody.PrimaryResource>> {
        self.tryMap(Self.extractPrimaryAndEntities)
    }

    static func extractEntities(from document: Output) throws -> EntityCache {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let entities = document.resourceCache() else {
            throw RequestFailure.unknown("Somehow found a document that is not an error document but also failed to create entities.")
        }
        return entities
    }

    static func extractPrimaryAndEntities(from document: Output) throws -> ManyEntityResultPair<Output.PrimaryResourceBody.PrimaryResource> {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let primary = document.body.primaryResource?.values, let entities = document.resourceCache() else {
            throw RequestFailure.missingPrimaryResource(String(describing: Output.PrimaryResourceBody.PrimaryResource.self))
        }
        return .init(primaryResources: primary, allEntities: entities)
    }
}

// Many, some includes
extension Publisher where
    Output: EncodableJSONAPIDocument,
    Output.BodyData.PrimaryResourceBody: ManyResourceBodyProtocol,
    Output.BodyData.PrimaryResourceBody.PrimaryResource: CacheableResource,
    Output.BodyData.IncludeType: CacheableResource,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == Output.BodyData.IncludeType.Cache,
    Output.BodyData.PrimaryResourceBody.PrimaryResource.Cache == EntityCache {

    func mapEntities() -> Publishers.TryMap<Self, EntityCache> {
        self.tryMap(Self.extractEntities)
    }

    func mapPrimaryAndEntities() -> Publishers.TryMap<Self, ManyEntityResultPair<Output.PrimaryResourceBody.PrimaryResource>> {
        self.tryMap(Self.extractPrimaryAndEntities)
    }

    static func extractEntities(from document: Output) throws -> EntityCache {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let entities = document.resourceCache() else {
            throw RequestFailure.unknown("Somehow found a document that is not an error document but also failed to create entities.")
        }
        return entities
    }

    static func extractPrimaryAndEntities(from document: Output) throws -> ManyEntityResultPair<Output.PrimaryResourceBody.PrimaryResource> {

        if let errors = document.body.errors {
            throw RequestFailure.errorResponse(errors)
        }
        guard let primary = document.body.primaryResource?.values, let entities = document.resourceCache() else {
            throw RequestFailure.missingPrimaryResource(String(describing: Output.PrimaryResourceBody.PrimaryResource.self))
        }
        return .init(primaryResources: primary, allEntities: entities)
    }
}

extension Publisher {
    func dispatch(_ actionHandlers: ((Output) -> ReSwift.Action)...) -> Publishers.FlatMap<Publishers.Sequence<[ReSwift.Action], Failure>, Self> {
        self.flatMap { output in
            Publishers.Sequence(sequence: actionHandlers.map { action in action(output) })
        }
    }
}

extension Publisher where Output == ReSwift.Action {
    /// Dispatch actions in place of errors. Any non-nil
    /// result of any action handlers will be dispatched.
    /// If all handlers return nil, the error will be propogated
    /// as unhandled.
    func dispatchError(_ actionHandlers: ((Failure) -> ReSwift.Action?)...) -> Publishers.Catch<Self, Publishers.Concatenate<Self, Publishers.Sequence<[ReSwift.Action], Failure>>> {
        self.catch { error in
            let actions = actionHandlers.compactMap { $0(error) }
            guard actions.count > 0 else {
                return self.append([])
            }
            return self.append(Publishers.Sequence(sequence: actions))
        }
    }
}

extension Publishers.Sequence where Elements == [ReSwift.Action] {
    /// Dispatch actions in place of errors. Any non-nil
    /// result of any action handlers will be dispatched.
    /// If all handlers return nil, the error will be propogated
    /// as unhandled.
    func dispatchError(_ actionHandlers: ((Failure) -> ReSwift.Action?)...) -> Publishers.Catch<Self, Publishers.Sequence<[ReSwift.Action], Failure>> {
        self.catch { error in
            let actions = actionHandlers.compactMap { $0(error) }
            guard actions.count > 0 else {
                return self
            }
            return Publishers.Sequence(sequence: actions)
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

public enum RequestFailure: Swift.Error {
    case unknown(String)
    case urlConstruction(String)
    case missingPrimaryResource(String)
    case errorResponse([Swift.Error])

    var isMissingPrimaryResource: Bool {
        guard case .missingPrimaryResource = self else {
            return false
        }
        return true
    }
}
