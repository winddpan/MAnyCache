//
//  MemoryStorage.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

#if canImport(UIKit)
    import UIKit
#endif

public struct MemoryStorageConfig {
    public let countLimit: Int
    public let byteLimit: Int

    public init(countLimit: Int, byteLimit: Int) {
        self.countLimit = countLimit
        self.byteLimit = byteLimit
    }

    public static let `default` = MemoryStorageConfig(countLimit: Int.max, byteLimit: Int.max)
}

final class MemoryStorage {
    private let cache = NSCache<NSString, Entity>()
    let lock = NSRecursiveLock()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    init(name: String, config: MemoryStorageConfig) {
        cache.name = name
        cache.countLimit = config.countLimit
        cache.totalCostLimit = config.byteLimit

        #if canImport(UIKit)
            NotificationCenter.default.addObserver(self, selector: #selector(_onMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        #endif
    }

    @objc private func _onMemoryWarning() {
        removeAll()
    }
}

extension MemoryStorage: StorageProtocol {
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        cache.removeAllObjects()
    }

    func removeEntity(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        cache.removeObject(forKey: key as NSString)
    }

    func entity(forKey key: String) -> Entity? {
        lock.lock(); defer { lock.unlock() }
        return cache.object(forKey: key as NSString)
    }

    func setEntity(_ entity: Entity, forKey key: String, cost: StorageCost) throws -> Int {
        lock.lock(); defer { lock.unlock() }
        cache.setObject(entity, forKey: key as NSString, cost: cost.cost)
        return cost.cost
    }

    func containsEntity(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return cache.object(forKey: key as NSString) != nil
    }

    func removeAllExpires() {
        lock.lock(); defer { lock.unlock() }
        
    }
}
