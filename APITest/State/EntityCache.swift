//
//  EntityCache.swift
//  APITest
//
//  Created by Mathew Polzin on 4/8/20.
//  Copyright © 2020 Mathew Polzin. All rights reserved.
//

import Foundation
import APIModels
import JSONAPI
import ReSwift

struct EntityCache: Equatable {
    typealias Cache<E: JSONAPI.IdentifiableResourceObjectType> = [E.Id: E]

    var testSources: Cache<API.OpenAPISource>
    var testProperties: Cache<API.APITestProperties>
    var tests: Cache<API.APITestDescriptor>
    var messages: Cache<API.APITestMessage>

    var testLogs: [API.APITestDescriptor.Id: String]

    init() {
        testSources = [:]
        testProperties = [:]
        tests = [:]
        messages = [:]
        testLogs = [:]
    }

    mutating func merge(with other: EntityCache) {
        testSources.merge(other.testSources, uniquingKeysWith: { $1 })
        testProperties.merge(other.testProperties, uniquingKeysWith: { $1 })
        tests.merge(other.tests, uniquingKeysWith: { $1 })
        messages.merge(other.messages, uniquingKeysWith: { $1 })
        testLogs.merge(other.testLogs, uniquingKeysWith: { $1 })
    }
}

extension EntityCache {
    var asUpdate: API.EntityUpdate {
        .response(entities: self)
    }
}

extension EntityCache {
    subscript<T: JSONAPI.ResourceObjectProxy>(id: T.Id) -> T? where T.Description: MaterializableDescription, T.Description.IdentifiableType == T {
        get {
            return self[keyPath: T.Description.cachePath][id]
        }
        set {
            self[keyPath: T.Description.cachePath][id] = newValue
        }
    }

    mutating func add<T: JSONAPI.ResourceObjectProxy>(_ resource: T) where T.Description: MaterializableDescription, T.Description.IdentifiableType == T {
        self[resource.id] = resource
    }

    mutating func add<T: JSONAPI.ResourceObjectProxy>(_ resources: [T]) where T.Description: MaterializableDescription, T.Description.IdentifiableType == T {
        for resource in resources {
            add(resource)
        }
    }
}

protocol MaterializableDescription {
    associatedtype IdentifiableType: JSONAPI.IdentifiableResourceObjectType

    static var cachePath: WritableKeyPath<EntityCache, EntityCache.Cache<IdentifiableType>> { get }
}

extension API.OpenAPISourceDescription: MaterializableDescription {
    static var cachePath: WritableKeyPath<EntityCache, EntityCache.Cache<API.OpenAPISource>> { \.testSources }
}

extension API.APITestPropertiesDescription: MaterializableDescription {
    static var cachePath: WritableKeyPath<EntityCache, EntityCache.Cache<API.APITestProperties>> { \.testProperties }
}

extension API.APITestDescriptorDescription: MaterializableDescription {
    static var cachePath: WritableKeyPath<EntityCache, EntityCache.Cache<API.APITestDescriptor>> { \.tests }
}

extension API.APITestMessageDescription: MaterializableDescription {
    static var cachePath: WritableKeyPath<EntityCache, EntityCache.Cache<API.APITestMessage>> { \.messages }
}

extension JSONAPI.Id where
            IdentifiableType: JSONAPI.ResourceObjectProxy,
            IdentifiableType.Description: MaterializableDescription,
            IdentifiableType.Description.IdentifiableType == IdentifiableType,
            IdentifiableType.Description.IdentifiableType.EntityRawIdType == RawType {

    func materialize(from state: AppState) -> Self.IdentifiableType? {
        return materialize(from: state.entities)
    }

    func materialize(from cache: EntityCache) -> Self.IdentifiableType? {
        return cache[keyPath: Self.IdentifiableType.Description.cachePath][self]
    }
}
