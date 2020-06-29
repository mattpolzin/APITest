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

                    let relationships: API.NewAPITestDescriptor.Description.Relationships

                    switch source {
                    case .default:
                        relationships = .init()
                    case .existing(id: let propertiesId):
                        relationships = .init(testProperties: .init(id: propertiesId))
                    case .new(uri: let uri, apiHostOverride: let apiHostOverride):
                        guard let uri = uri else {
                            let newPropertiesRequest = try! APIRequest(
                                .post,
                                host: state.host,
                                path: "/openapi_sources",
                                body: API.newPropertiesDocument(from: nil, apiHostOverride: apiHostOverride),
                                responseType: API.SingleAPITestPropertiesDocument.self
                            )
                            self.request(
                                newPropertiesRequest
                                    .publish
                                    .mapEntities()
                                    .dispatch(\.cacheAction)
                            )
                            self.startTestWithNewProperties(
                                openAPISource: nil,
                                apiHostOverride: apiHostOverride,
                                state: state
                            )
                            return
                        }

                        let newSourceRequest = try! APIRequest(
                            .post,
                            host: state.host,
                            path: "/openapi_sources",
                            body: API.newOpenAPISourceDocument(uri: uri),
                            responseType: API.SingleOpenAPISourceDocument.self
                        )
                        let newPropertiesRequest = try! PartialAPIRequest(
                            .post,
                            host: state.host,
                            path: "/api_test_properties",
                            body: { try API.newPropertiesDocument(from: $0, apiHostOverride: apiHostOverride) },
                            responseType: API.SingleAPITestPropertiesDocument.self
                        )

                        self.request(
                            newSourceRequest
                                .publish
                                .chain(newPropertiesRequest)
                                .mapPrimaryAndEntities()
                                .dispatch(
                                    \.cacheAction,
                                    { API.StartTest.request(.existing(id: $0.primaryResource.id)) }
                            )
                        )
                        return
                    case .new(uri: let uri, apiHostOverride: let apiHostOverride):
                        guard let uri = uri else {
                            self.startTestWithNewProperties(
                                openAPISource: nil,
                                apiHostOverride: apiHostOverride,
                                state: state
                            )
                            return
                        }

                        let document = API.newOpenAPISourceDocument(uri: uri)

                        // super gross nesting here.
                        // TODO: this whole thing should be flattened
                        // out by refactoring the `jsonApiRequest` methods.
                        do {
                            try self.jsonApiRequest(
                                .post,
                                host: state.host,
                                path: "/openapi_sources",
                                body: document
                            ) { (response: API.SingleOpenAPISourceDocument) in

                                guard let entities = response.resourceCache(),
                                    let source = response.body.primaryResource?.value else {
                                    print("failed to start tests with a new OpenAPI source")
                                    return EntityCache()
                                }

                                self.startTestWithNewProperties(
                                    openAPISource: source,
                                    apiHostOverride: apiHostOverride,
                                    state: state
                                )

                                return entities
                            }
                        } catch {
                            store.dispatch(Toast.apiError(message: "Failed to start a new test run with a new OpenAPI source"))
                            print("Failure to send request: \(error)")
                        }
                        return
                    }

                    let testDescriptor = API.NewAPITestDescriptor(attributes: .none, relationships: relationships, meta: .none, links: .none)

                    let document = API.CreateAPITestDescriptorDocument(
                        body: .init(resourceObject: testDescriptor)
                    )

                    do {
                        try self.jsonApiRequest(
                            .post,
                            host: state.host,
                            path: "/api_tests",
                            body: document
                        ) { (_: API.SingleAPITestDescriptorDocument) -> EntityCache in

                            return EntityCache()
                        }
                    } catch {
                        store.dispatch(Toast.apiError(message: "Failed to start a new test run"))
                        print("Failure to send request: \(error)")
                    }

                case .request as API.GetAllTests:

                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/api_tests"
                    ) { (response: API.BatchAPITestDescriptorDocument) -> EntityCache in
                        guard let entities = response.resourceCache() else {
                                print("failed to retrieve primary resources and includes from batch test descriptor response")
                                store.dispatch(Toast.apiError(message: "Failed to retrieve primary resources and includes from batch test descriptor response"))
                                return EntityCache()
                        }

                        return entities
                    }

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
                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/openapi_sources"
                    ) { (response: API.BatchOpenAPISourceDocument) -> EntityCache in
                        guard let entities = response.resourceCache() else {
                            print("failed to retrieve primary resources from batch openapi source response")
                            store.dispatch(Toast.apiError(message: "Failed to retrieve primary resources from batch openapi source response"))
                            return EntityCache()
                        }

                        return entities
                    }

                case .request as API.GetAllProperties:
                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/api_test_properties",
                        including: ["openAPISource"]
                    ) { (response: API.BatchAPITestPropertiesDocument) -> EntityCache in
                        guard let entities = response.resourceCache() else {
                                print("failed to retrieve primary resources from batch api test properties response")
                                store.dispatch(Toast.apiError(message: "Failed to retrieve primary resources from batch api test properties response"))
                                return EntityCache()
                        }

                        return entities
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

    /// make a request to create test properties with the given
    /// OpenAPI source and host override.
    ///
    /// In both cases `nil` is allowed. A `nil` override is
    /// "don't override" and a `nil` source is the default source
    /// for the server if one is defined.
    func startTestWithNewProperties(openAPISource source: API.OpenAPISource?, apiHostOverride: URL?, state: AppState) {
        let properties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: apiHostOverride),
            relationships: .init(openAPISource: source.map { .init(resourceObject: $0) }),
            meta: .none,
            links: .none
        )

        let document = API.CreateAPITestPropertiesDocument(
            body: .init(resourceObject: properties)
        )

        do {
            try self.jsonApiRequest(
                .post,
                host: state.host,
                path: "/api_test_properties",
                body: document
            ) { (response: API.SingleAPITestPropertiesDocument) in
                guard let entities = response.resourceCache(),
                    let properties = response.body.primaryResource?.value else {
                        print("failed to start tests with a new OpenAPI source")
                        return EntityCache()
                }

                DispatchQueue.main.async {
                    store.dispatch(API.StartTest.request(.existing(id: properties.id)))
                }

                return entities
            }
        } catch {
            print("Failure to send request: \(error)")
        }
    }

    func request<RequestPublisher: Publisher>(_ publisher: RequestPublisher) where RequestPublisher.Output == ReSwift.Action {
        publisher.mapError { $0 as? RequestFailure ?? .unknown(String(describing: $0)) }
        .subscribe(store)
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

struct APIRequest<Request: Encodable, Response: Decodable> {
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

extension APIRequest {
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
    func dispatch(_ actions: ((Output) -> ReSwift.Action)...) -> Publishers.FlatMap<Publishers.Sequence<[ReSwift.Action], Failure>, Self> {
        self.flatMap { output in
            Publishers.Sequence(sequence: actions.map { action in action(output) })
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
    static func newPropertiesDocument(from sourceDocument: API.SingleOpenAPISourceDocument?, apiHostOverride: URL?) throws -> API.CreateAPITestPropertiesDocument {
        let source = sourceDocument?.body.primaryResource?.value
        if sourceDocument != nil, source == nil {
            throw RequestFailure.missingPrimaryResource(String(describing: API.SingleOpenAPISourceDocument.self))
        }
        let properties = API.NewAPITestProperties(
            attributes: .init(apiHostOverride: apiHostOverride),
            relationships: .init(openAPISource: source.map { .init(resourceObject: $0) }),
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
}
