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

// TODO: reconnect on disconnect

final class APITestWatcherController {
    var websocket: WebSocket?
    var currentHost: URL?

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
            self.currentHost = hostUrl
            self.websocket = websocket

            websocket.onText(self.onText)
        }.whenFailure { error in
            print(error)
            store.dispatch(Toast.networkError(message: error.localizedDescription))
        }
    }

    func disconnect() {
        websocket?.close()
            .whenFailure { error in
                print(error)
                store.dispatch(Toast.networkError(message: error.localizedDescription))
        }
    }

    private func onText(websocket: WebSocket, text: String) {
        print("received websocket update")
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let document = try text.data(using: .utf8).map({ try decoder.decode(API.SingleAPITestDescriptorDocument.self, from: $0) }) else {
                print("no document?")
                store.dispatch(Toast.serverError(message: "Did not receive expected response body from server when listening for Test updates."))
                return
            }

            var entities = EntityCache()

            if let primaryResource = document.body.primaryResource?.value {
                    entities.add(primaryResource)
            }

            if let includes = document.body.includes?.values {
                for include in includes {
                    switch include {
                    case .a(let source):
                        entities.add(source)
                    case .b(let message):
                        entities.add(message)
                    }
                }
            }

            store.dispatch(entities.asUpdate)
        } catch {
            print(error)
            store.dispatch(Toast.networkError(message: error.localizedDescription))
        }
    }
}
