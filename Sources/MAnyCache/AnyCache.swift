//
//  AnyCache.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

open class AnyCache {
    private let memoryStorage: MemoryStorage
    private let diskStorage: DiskStorage
    private let trimQueue = DispatchQueue(label: "com.anyCache.trimQueue")
    private let debouncer = Debouncer(seconds: 0.1)
    open var autoTrimInterval: TimeInterval = 60

    public init(name: String,
                memoryStorageConfig: MemoryStorageConfig = .default,
                diskStorageConfig: DiskStorageConfig = .default)
    {
        memoryStorage = MemoryStorage(name: name, config: memoryStorageConfig)
        diskStorage = DiskStorage(name: name, config: diskStorageConfig)
        _trimRecursively()
    }

    open var allKeys: [String] {
        return diskStorage.allKeys
    }

    open func removeAll() {
        memoryStorage.removeAll()
        diskStorage.removeAll()
    }

    open func removeObject(forKey key: String) {
        memoryStorage.removeEntity(forKey: key)
        diskStorage.removeEntity(forKey: key)
    }

    open func object<T: CacheSerializable>(forKey key: String, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        if let entity = memoryStorage.entity(forKey: key) {
            do {
                let object = try loadEntity(key: key, entity: entity, as: type)
                completion(.success(object))
            } catch {
                completion(.failure(error))
            }
        } else {
            diskStorage.entity(forKey: key) { [weak self] entity in
                guard let self = self else { return }
                if let entity = entity {
                    do {
                        let object = try self.loadEntity(key: key, entity: entity, as: type)
                        try? self.memoryStorage.setEntity(entity, forKey: key)
                        completion(.success(object))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    completion(.failure(StorageError.notFound))
                }
            }
        }
    }

    open func object<T: CacheSerializable>(forKey key: String, as type: T.Type) throws -> T {
        if let entity = memoryStorage.entity(forKey: key) {
            return try loadEntity(key: key, entity: entity, as: T.self)
        } else if let entity = diskStorage.entity(forKey: key) {
            try? memoryStorage.setEntity(entity, forKey: key)
            return try loadEntity(key: key, entity: entity, as: T.self)
        }
        throw StorageError.notFound
    }

    open func setObject<T: CacheSerializable>(_ object: T, forKey key: String, expiry: Expiry = .never) throws {
        let entity = Entity(object: object, cost: 0, expiry: expiry)
        try diskStorage.setEntity(entity, forKey: key)
        try memoryStorage.setEntity(entity, forKey: key)

        debouncer.debounce { [weak self] in
            self?.trimQueue.async { [weak self] in
                self?.memoryStorage.removeAllExpires()
                self?.diskStorage.removeAllExpires()
            }
        }
    }

    open func containsObject(forKey key: String) -> Bool {
        return memoryStorage.containsEntity(forKey: key) || diskStorage.containsEntity(forKey: key)
    }

    open func setObject<T: Codable>(_ object: T, forKey key: String, expiry: Expiry = .never) throws {
        try setObject(CodableContainer(object), forKey: key, expiry: expiry)
    }

    open func object<T: Codable>(forKey key: String, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        return object(forKey: key, as: CodableContainer<T>.self, completion: { result in
            completion(result.map { $0.object })
        })
    }

    open func object<T: Codable>(forKey key: String, as type: T.Type) throws -> T {
        return try object(forKey: key, as: CodableContainer<T>.self).object
    }
}

private extension AnyCache {
    func _trimRecursively() {
        trimQueue.asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            guard let self = self else { return }
            self.memoryStorage.removeAllExpires()
            self.diskStorage.removeAllExpires()
            self._trimRecursively()
        }
    }

    func loadEntity<T: CacheSerializable>(key: String, entity: Entity, as type: T.Type) throws -> T {
        if entity.expiry.isExpired {
            memoryStorage.removeEntity(forKey: key)
            diskStorage.removeEntity(forKey: key)
            throw StorageError.isExpired
        } else {
            if let obj = entity.object as? T {
                return obj
            }
            let data = try entity.object.serialize()
            let newObj = try T.deserialize(from: data)
            entity.object = newObj
            entity.cost = data.count
            return newObj
        }
    }
}
