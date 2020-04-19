//
//  URLStringValidator.swift
//  APITest
//
//  Created by Mathew Polzin on 4/18/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation

enum URLStringValidator: Validator {
    static func isValid(_ value: String) -> Bool {
        guard let urlComponents = URLComponents(string: value) else {
            return false
        }
        guard urlComponents.scheme != nil, urlComponents.host != nil else {
            return false
        }
        return true
    }
}
