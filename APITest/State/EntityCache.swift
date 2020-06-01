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
import JSONAPIResourceCache
import ReSwift

public struct EntityCache: Equatable, ResourceCache {

    var testSources: ResourceHash<API.OpenAPISource>
    var testProperties: ResourceHash<API.APITestProperties>
    var tests: ResourceHash<API.APITestDescriptor>
    var messages: ResourceHash<API.APITestMessage>

    var testLogs: [API.APITestDescriptor.Id: String]

    public init() {
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

extension API.OpenAPISourceDescription: Materializable {
    public static var cachePath: WritableKeyPath<EntityCache, ResourceHash<API.OpenAPISource>> { \.testSources }
}

extension API.APITestPropertiesDescription: Materializable {
    public static var cachePath: WritableKeyPath<EntityCache, ResourceHash<API.APITestProperties>> { \.testProperties }
}

extension API.APITestDescriptorDescription: Materializable {
    public static var cachePath: WritableKeyPath<EntityCache, ResourceHash<API.APITestDescriptor>> { \.tests }
}

extension API.APITestMessageDescription: Materializable {
    public static var cachePath: WritableKeyPath<EntityCache, ResourceHash<API.APITestMessage>> { \.messages }
}

extension JSONAPI.Id where
            IdentifiableType: JSONAPI.ResourceObjectProxy,
            IdentifiableType.Description: Materializable,
            IdentifiableType.Description.IdentifiableType == IdentifiableType,
            IdentifiableType.Description.IdentifiableType.EntityRawIdType == RawType,
            IdentifiableType.Description.ResourceCacheType == EntityCache {

    func materialized(from state: AppState) -> Self.IdentifiableType? {
        return materialized(from: state.entities)
    }
}
