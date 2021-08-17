//
//  CodableWrapper.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

struct CodableWrapper<T: Codable>: CacheSerializable {
    let object: T

    init(_ object: T) {
        self.object = object
    }

    func serialize() throws -> Data {
        return try JSONEncoder().encode(object)
    }

    static func deserialize(from data: Data) throws -> CodableWrapper<T> {
        let object = try JSONDecoder().decode(T.self, from: data)
        return CodableWrapper(object)
    }
}
