//
//  Config.swift
//  APITest
//
//  Created by Mathew Polzin on 4/22/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation

fileprivate struct Configuration: Decodable {
    let host: URL

    static let shared: Self = {
        let decoder = JSONDecoder()
        let configPath = Bundle.main.url(forResource: "config", withExtension: "json")!
        let data = try! Data(contentsOf: configPath)
        return try! decoder.decode(Configuration.self, from: data)
    }()
}

enum Config {
    static var host: URL { Configuration.shared.host }
}
