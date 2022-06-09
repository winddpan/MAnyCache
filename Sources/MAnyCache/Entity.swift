//
//  Entity.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

final class Entity {
    var object: CacheSerializable
    var expiry: Expiry
    var cost: Int

    init(object: CacheSerializable, cost: Int, expiry: Expiry) {
        self.object = object
        self.cost = cost
        self.expiry = expiry
    }
}
