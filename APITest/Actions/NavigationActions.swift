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

public struct SelectTest: ReSwift.Action {
    let testId: API.APITestDescriptor.Id
}

extension API.APITestDescriptor {
    public var select: SelectTest { .init(testId: self.id) }
}

public struct Toggle: ReSwift.Action {
    let field: WritableKeyPath<AppState.Toggles, Bool>
}
