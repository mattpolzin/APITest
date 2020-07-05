//
//  APITestWatcherController.swift
//  APITest
//
//  Created by Mathew Polzin on 4/10/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import WebSocketKit
import NIO
import APIModels
import Poly

extension APITestWatcherController {
    enum State {
        case disconnected
        case reconnecting(host: URL)
        case connected(host: URL, websocket: WebSocket)

        var webscoket: WebSocket? {
            guard case .connected(host: _, websocket: let websocket) = self else {
                return nil
            }
            return websocket
        }

        var host: URL? {
            switch self {
            case .reconnecting(host: let host),
                 .connected(host: let host, websocket: _):
                return host
            case .disconnected:
                return nil
            }
        }
    }
}

final class APITestWatcherController {
    private(set) var state: State = .disconnected

    var websocket: WebSocket? { state.webscoket }
    var currentHost: URL? { state.host }

    private let eventLoopGroup: EventLoopGroup

    init() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connectIfNeeded(to hostUrl: URL) {
        guard hostUrl != currentHost || (websocket?.isClosed ?? true) else {
            // if the host is the same and the websocket is non-nil and webscoket is not closed
            // then we just return
            return
        }

        connect(to: hostUrl)
    }

    func connect(to hostUrl: URL) {
        var components = URLComponents(url: hostUrl, resolvingAgainstBaseURL: false)!
        components.scheme = "ws"
        components.path = "/watch"
        WebSocket.connect(to: components.string!, on: eventLoopGroup) { [weak self] websocket in
            guard let self = self else  { return }
            self.state = .connected(host: hostUrl, websocket: websocket)

            websocket.onText(self.onText)
            websocket.onClose.whenComplete(self.onClose(result:))
        }.whenFailure { error in
            print(error)
            DispatchQueue.main.async {
                store.dispatch(Toast.networkError(message: "Failed to start watching tests"))
            }
        }
    }

    func disconnect() {
        // we are already watching for close given a successful connection in `connect()`.
        let _ = websocket?.close()
    }

    private typealias SingleDescriptorOrMessage = Either<API.SingleAPITestMessageDocument.SuccessDocument, API.SingleAPITestDescriptorDocument.SuccessDocument>

    private func onClose(result: Result<Void, Error>) {
        if case .failure(let error) = result {
            // TODO: attempt reconnect on a timed interval
            print(error)
            DispatchQueue.main.async {
                store.dispatch(Toast.networkError(message: "Test watching killed due to error"))
            }
        }
        self.state = .disconnected
    }

    private func onText(websocket: WebSocket, text: String) {
        print("received websocket update")
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let document = try text.data(using: .utf8).map({ try decoder.decode(SingleDescriptorOrMessage.self, from: $0) }) else {
                print("no document?")
                DispatchQueue.main.async {
                    store.dispatch(Toast.serverError(message: "Did not receive expected response body from server when listening for Test updates."))
                }
                return
            }

            let entities: EntityCache

            switch document {
            case .a(let messageDoc):
                print("adding test message")
                entities = messageDoc.resourceCache()

                for include in messageDoc.data.includes.values {
                    switch include {
                    case .a(let descriptor):
                        if [.passed, .failed].contains(descriptor.status) {
                            DispatchQueue.main.async {
                                store.dispatch(API.GetTest.requestRawLogs(id: descriptor.id))
                            }
                        }
                    }
                }
            case .b(let descriptorDoc):
                print("adding test descriptor")
                entities = descriptorDoc.resourceCache()
            }

            let update = entities.asUpdate

            DispatchQueue.main.async {
                store.dispatch(update)
            }
        } catch {
            print(error)
            DispatchQueue.main.async {
                store.dispatch(Toast.networkError(message: error.localizedDescription))
            }
        }
    }
}
