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

final class APITestWatcherController {
    var websocket: WebSocket?

    private let eventLoopGroup: EventLoopGroup

    init() {
        eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    func connect() {
        WebSocket.connect(to: "ws://localhost:8080/watch", on: eventLoopGroup) { [weak self] websocket in
            guard let self = self else  { return }
            self.websocket = websocket

            websocket.onText(self.onText)
        }.whenFailure { error in
            print(error)
            // TODO
        }
    }

    func disconnect() {
        websocket?.close()
            .whenFailure { error in
                print(error)
                // TODO
        }
    }

    private func onText(websocket: WebSocket, text: String) {
        print("received websocket update")
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            guard let document = try text.data(using: .utf8).map({ try decoder.decode(API.SingleAPITestDescriptorDocument.self, from: $0) }) else {
                print("no document?")
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
            // TODO
        }
    }
}
