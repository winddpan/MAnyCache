//
//  Entity.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

public final class Entity {
    public internal(set) var object: CacheSerializable
    public internal(set) var expiry: Expiry

    init(object: CacheSerializable, expiry: Expiry) {
        self.object = object
        self.expiry = expiry
    }
}
