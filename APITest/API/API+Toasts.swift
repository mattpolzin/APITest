//
//  Toasts.swift
//  APITest
//
//  Created by Mathew Polzin on 7/16/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import APIModels
import ReSwift
import CombineAPIRequest
import JSONAPICombine

extension API {
    static func toast(given condition: @autoclosure () -> Bool, message: String) -> Toast? {
        guard condition() else { return nil }

        return Toast.apiError(message: message)
    }

    static func anyRequestFailureToast(message: String) -> (Error) -> ReSwift.Action? {
        return { error in
            toast(
                given: error is RequestFailure,
                message: message
            )
        }
    }

    static func missingPrimaryResourceToast(message: String) -> (Error) -> ReSwift.Action? {
        return { error in
            toast(
                given: (error as? ResponseFailure)?.isMissingPrimaryResource ?? false,
                message: message
            )
        }
    }

    static func responseDecodingErrorToast(message: String) -> (Error) -> ReSwift.Action? {
        return { error in
            toast(
                given: (error as? ResponseFailure)?.isResponseDecoding ?? false,
                message: message
            )
        }
    }
}
