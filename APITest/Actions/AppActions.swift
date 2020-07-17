//
//  NavigationActions.swift
//  APITest
//
//  Created by Mathew Polzin on 4/11/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import APIModels
import ReSwift

struct SelectTest: ReSwift.Action {
    let testId: API.APITestDescriptor.Id
}

extension API.APITestDescriptor {
    var select: SelectTest { .init(testId: self.id) }
}

enum NewTest: ReSwift.Action {
    case open
    case dismiss
    case newSource
    case changeSourceUri(String?)
    case changeServerOverride(String?)
    case cancelNewSource
}

enum Toggle: ReSwift.Action {
    case field(WritableKeyPath<AppState.Toggles, Bool>)

}

enum TestDetails: ReSwift.Action {
    case toggleDetailsLogsOrMessages
    case longPressMessage(API.APITestMessage.Id)
    case highlightMessage(API.APITestMessage.Id, turnedOn: Bool)
}

enum Settings: ReSwift.Action {
    case toggleOpen
    case changeHost(proposedURL: String)
}

enum Filter: ReSwift.Action {
    case apply(String)
}

enum Help: ReSwift.Action {
    case open
    case close
}

enum Toast: ReSwift.Action {
    case show(Content)
    case hide(Content)

    static func networkError(message: String) -> Self {
        .show(.init(title: "Network Error", message: message, style: .error))
    }

    static func serverError(message: String) -> Self {
        .show(.init(title: "Server Error", message: message, style: .error))
    }

    static func apiError(message: String) -> Self {
        .show(.init(title: "API Error", message: message, style: .error))
    }

    static func pasteboardError(message: String) -> Self {
        .show(.init(title: "Copy Failed", message: message, style: .error))
    }

    struct Content: Equatable, Identifiable {
        let id: Int
        let title: String
        let message: String
        let style: Style

        private static var idCounter: Int = 0

        init(title: String, message: String, style: Style) {
            self.id = Self.idCounter
            Self.idCounter += 1

            self.title = title
            self.message = message
            self.style = style
        }

        enum Style: Equatable {
            case info
            case warning
            case error
        }
    }
}
