//
//  StorageProtocol.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation


protocol StorageProtocol {
    func removeAll()
    
    func removeAllExpires()

    func removeEntity(forKey key: String)

    func entity(forKey key: String) -> Entity?

    func setEntity(_ entity: Entity, forKey key: String) throws

    func containsEntity(forKey key: String) -> Bool
}
