//
//  APIMiddleware.swift
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

                let state = getState()!

                switch action {
                case let .request(source) as API.StartTest:

                    let relationships: API.NewAPITestDescriptor.Description.Relationships

                    switch source {
                    case .default:
                        relationships = .init()
                    case .existing(id: let sourceId):
                        relationships = .init(openAPISource: .init(id: sourceId))
                    case .new(uri: let uri):
                        fatalError("unimplemented API call for a new OpenAPISource with uri \(uri)")
                    }

                    let testDescriptor = API.NewAPITestDescriptor(attributes: .none, relationships: relationships, meta: .none, links: .none)

                    let document = API.NewAPITestDescriptorDocument(
                        apiDescription: .none,
                        body: .init(resourceObject: testDescriptor),
                        includes: .none,
                        meta: .none,
                        links: .none
                    )

                    do {
                        try self.jsonApiRequest(
                            .post,
                            host: state.host,
                            path: "/api_tests",
                            body: document) { (_: API.SingleAPITestDescriptorDocument) -> EntityCache in

                                return EntityCache()
                        }
                    } catch {
                        // TODO: better error handling
                        print("Failure to send request: \(error)")
                    }

                case .request as API.GetAllTests:

                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/api_tests") { (response: API.BatchAPITestDescriptorDocument) -> EntityCache in
                            guard let primaryResources = response.body.primaryResource?.values,
                                let includes = response.body.includes?.values else {
                                    print("failed to retrieve primary resources and includes from batch test descriptor response")
                                    // TODO: better error handling
                                    return EntityCache()
                            }

                            var entities = EntityCache()

                            entities.add(primaryResources)
                            for include in includes {
                                switch include {
                                case .a(let source):
                                    entities.add(source)
                                case .b(let message):
                                    entities.add(message)
                                }
                            }

                            return entities
                    }

                case let .request(id, includeSource, includeMessages) as API.GetTest:
                    var includes = [String]()

                    if includeSource { includes.append("openAPISource") }
                    if includeMessages { includes.append("messages") }

                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/api_tests/\(id.rawValue.uuidString)",
                        including: includes) { (response: API.SingleAPITestDescriptorDocument) -> EntityCache in
                            guard let primaryResource = response.body.primaryResource?.value,
                                let includes = response.body.includes?.values else {
                                    print("failed to retrieve primary resources and includes from single test descriptor response")
                                    // TODO: better error handling
                                    return EntityCache()
                            }

                            var entities = EntityCache()

                            entities.add(primaryResource)
                            for include in includes {
                                switch include {
                                case .a(let source):
                                    entities.add(source)
                                case .b(let message):
                                    entities.add(message)
                                }
                            }

                            return entities
                    }

                case .request as API.GetAllSources:
                    self.jsonApiRequest(
                        .get,
                        host: state.host,
                        path: "/openapi_sources") { (response: API.BatchOpenAPISourceDocument) -> EntityCache in
                            guard let primaryResources = response.body.primaryResource?.values else {
                                    print("failed to retrieve primary resources from batch openapi source response")
                                    // TODO: better error handling
                                    return EntityCache()
                            }

                            var entities = EntityCache()

                            entities.add(primaryResources)

                            return entities
                    }

                case .start as API.WatchTests:
                    self.testWatchController.connectIfNeeded(to: state.host)

                case .stop as API.WatchTests:
                    self.testWatchController.disconnect()

                case .toggleOpen as Settings where state.settingsEditor == nil:
                    // this means the settings editor was just closed.
                    self.testWatchController.connectIfNeeded(to: state.host)

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
                        print(String(describing: failure))
                    case .finished:
                        break
                    }
                    self.requests.removeValue(forKey: requestId)
            },
                receiveValue: { response in
                    guard let status = (response.response as? HTTPURLResponse)?.statusCode else {
                        print("something went really wrong with request. no status code. response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard status >= 200 && status < 300 else {
                        print("request failed with status code: \(status)")
                        print("response body: \(String(data: response.data, encoding: .utf8) ?? "Not UTF8 encoded")")
                        return
                    }

                    guard let value = try? Self.decode(Response.self, from: response.data) else {
                            print("failed to decode JSON:API response")
                            // TODO: better error handling
                            return
                    }

                    store.dispatch(entities(value).asUpdate)
        })

        self.requests[requestId] = inFlightRequest

        return inFlightRequest
    }

    enum HttpVerb: String, Equatable {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }
}
