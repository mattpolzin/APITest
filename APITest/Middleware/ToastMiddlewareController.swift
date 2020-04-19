//
//  ToastMiddlewareController.swift
//  APITest
//
//  Created by Mathew Polzin on 4/18/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import ReSwift

final class ToastMiddlewareController {

    func middleware(dispatch: @escaping DispatchFunction, getState: @escaping () -> AppState?) -> (@escaping DispatchFunction) -> DispatchFunction {
        return { next in
            return { action in
                next(action)

                guard let state = getState() else { return }

                switch action {
                case .show(let content) as Toast:
                    if state.toastQueue.first == content {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { dispatch(Toast.hide(content)) }
                    }
                case .hide as Toast:
                    if let content = state.toastQueue.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5)) { dispatch(Toast.hide(content)) }
                    }

                default:
                    break
                }
            }
        }
    }
}
