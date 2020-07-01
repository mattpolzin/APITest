//
//  Combine+ReSwift.swift
//  APITest
//
//  Created by Mathew Polzin on 6/29/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import Combine
import ReSwift
import JSONAPIResourceCache
import JSONAPICombine
import CombineReSwift

protocol CachableEntities {
    var cacheAction: ReSwift.Action { get }
}

extension SingleEntityResultPair: CachableEntities where Primary.Cache == EntityCache {
    var cacheAction: Action { allEntities.asUpdate }
}

extension ManyEntityResultPair: CachableEntities where Primary.Cache == EntityCache {
    var cacheAction: Action { allEntities.asUpdate }
}

extension Publisher where Output: CachableEntities {
    func cache() -> Publishers.FlatMap<Publishers.Sequence<[ReSwift.Action], Failure>, Self> {
        self.dispatch(\.cacheAction)
    }
}
