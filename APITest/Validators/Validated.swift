//
//  Validated.swift
//  APITest
//
//  Created by Mathew Polzin on 4/18/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation

protocol Validator {
    associatedtype ValidatedType

    static func isValid(_ value: ValidatedType) -> Bool
}

@propertyWrapper
struct Validated<T: Validator> {
    var wrappedValue: T.ValidatedType
    var projectedValue: Self { self }
    var isValid: Bool { T.isValid(wrappedValue) }
}

extension Validated: Equatable where T.ValidatedType: Equatable {}
