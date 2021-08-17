//
//  StorageProtocol.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

enum StorageCost {
    case bytes(Int)
    case unknow
    
    var cost: Int {
        switch self {
        case .bytes(let value):
            return value
        case .unknow:
            return 0
        }
    }
}

protocol StorageProtocol {
    func removeAll()
    
    func removeAllExpires()

    func removeEntity(forKey key: String)

    func entity(forKey key: String) -> Entity?

    func setEntity(_ entity: Entity, forKey key: String, cost: StorageCost) throws -> Int

    func containsEntity(forKey key: String) -> Bool
}
