//
//  OSSideEffectMiddlewareController.swift
//  APITest
//
//  Created by Mathew Polzin on 7/16/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift
import UIKit
import JSONAPI
import APIModels

final class OSSideEffectMiddlewareController {

    func middleware(dispatch: @escaping DispatchFunction, getState: @escaping () -> AppState?) -> (@escaping DispatchFunction) -> DispatchFunction {
        return { next in
            return { action in
                // this middleware passes the action on and then handles it after reduction.

                next(action)

                guard let state = getState() else { return }

                switch action {
                case .longPressMessage(let messageId) as TestDetails:
                    guard let message = messageId.materialized(from: state) else {
                        dispatch(Toast.pasteboardError(message: "Failed to copy message text."))
                        return
                    }
                    UIPasteboard.general.string = message.copyableText
                    dispatch(TestDetails.highlightMessage(messageId, turnedOn: true))
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { dispatch(TestDetails.highlightMessage(messageId, turnedOn: false)) }
                default:
                    break
                }
            }
        }
    }
}

fileprivate extension JSONAPI.ResourceObject where Description == API.APITestMessageDescription {
    /// A string that can be copied to the clipboard to share
    /// the message easily.
    var copyableText: String {
        return [
            "[\(self.messageType.rawValue)] \(self.message)",
            self.path.map { "→ \($0)" },
            self.context.map { "→ \($0)" }
            ].compactMap { $0 }.joined(separator: "\n")
    }
}
