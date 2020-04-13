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

final class APIMiddlewareController {

    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var nextRequestId: Int = 0
    var requests: [Int: AnyCancellable] = [:]

    func middleware(dispatch: @escaping DispatchFunction, getState: @escaping () -> AppState?) -> (@escaping DispatchFunction) -> DispatchFunction {
        return { next in
            return { action in
                switch action {
                case .request as API.StartTest:
                    var request = URLRequest(url: URL(string: "http://localhost:8080/api_tests")!)
                    request.httpMethod = "POST"
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = """
{
    "data": {
        "type": "api_test_descriptor",
        "relationships": {
        }
    }
}
""".data(using: .utf8)!

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
                            receiveValue: { _, _ in

                        }
                    )

                    self.requests[requestId] = inFlightRequest

                case .request as API.GetAllTests:
                    var request = URLRequest(url: URL(string: "http://localhost:8080/api_tests")!)
                    request.httpMethod = "GET"

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
                            receiveValue: { value in
                                guard let batch = try? self.decoder.decode(API.BatchAPITestDescriptorDocument.self, from: value.data),
                                    let primaryResources = batch.body.primaryResource?.values,
                                    let includes = batch.body.includes?.values else {
                                    print("failed to decode batch test descriptor response")
                                    // TODO
                                    return
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

                                store.dispatch(entities.asUpdate)
                        }
                    )

                    self.requests[requestId] = inFlightRequest

                case let .request(id, includeSource, includeMessages) as API.GetTest:
                    var urlComponents = URLComponents(url: URL(string: "http://localhost:8080/api_tests/\(id.rawValue.uuidString)")!, resolvingAgainstBaseURL: false)!

                    var includes = [String]()

                    if includeSource { includes.append("openAPISource") }
                    if includeMessages { includes.append("messages") }

                    urlComponents.queryItems = [.init(name: "include", value: includes.joined(separator: ","))]

                    var request = URLRequest(url: urlComponents.url!)
                    request.httpMethod = "GET"

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
                            receiveValue: { value in
                                guard let batch = try? self.decoder.decode(API.SingleAPITestDescriptorDocument.self, from: value.data),
                                    let primaryResource = batch.body.primaryResource?.value,
                                    let includes = batch.body.includes?.values else {
                                        print("failed to decode single test descriptor response")
                                        // TODO
                                        return
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

                                store.dispatch(entities.asUpdate)
                        }
                    )

                    self.requests[requestId] = inFlightRequest

                default:
                    break
                }

                next(action)
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
