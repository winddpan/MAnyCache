//
//  AnyCache.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

open class AnyCache {
    let memoryStorage: MemoryStorage
    let diskStorage: DiskStorage
    let ioQueue = DispatchQueue(label: "com.anyCache.ioQueue")
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
        ioQueue.async {
            self.diskStorage.removeAll()
        }
    }

    open func removeObject(forKey key: String) {
        memoryStorage.removeEntity(forKey: key)
        diskStorage.removeEntity(forKey: key)
    }

    open func object<T: CacheSerializable>(forKey key: String, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        ioQueue.async {
            do {
                let object = try self.object(forKey: key, as: type)
                completion(.success(object))
            } catch {
                completion(.failure(error))
            }
        }
    }

    open func object<T: CacheSerializable>(forKey key: String, as type: T.Type) throws -> T {
        do {
            let entity = try memoryStorage.storageEntity(forKey: key, as: type)
            // as! always succeed
            return entity.object as! T
        } catch {
            switch error {
            case StorageError.isExpired:
                memoryStorage.removeEntity(forKey: key)
                diskStorage.removeEntity(forKey: key)
            case StorageError.notFound:
                break
            default:
                throw error
            }
        }

        do {
            let entity = try diskStorage.storageEntity(forKey: key, as: type)
            _ = try memoryStorage.setEntity(entity, forKey: key, cost: .unknow)
            // as! always succeed
            return entity.object as! T
        } catch {
            if case .isExpired = error as? StorageError {
                diskStorage.removeEntity(forKey: key)
            }
            throw error
        }
    }

    open func setObject<T: CacheSerializable>(_ object: T, forKey key: String, expiry: Expiry = .never) throws {
        let entity = Entity(object: object, expiry: expiry)
        let cost = try diskStorage.setEntity(entity, forKey: key, cost: .unknow)
        _ = try memoryStorage.setEntity(entity, forKey: key, cost: .bytes(cost))

        memoryStorage.removeAllExpires()
        diskStorage.removeAllExpires()
    }

    open func containsObject(forKey key: String) -> Bool {
        return memoryStorage.containsEntity(forKey: key) || diskStorage.containsEntity(forKey: key)
    }

    open func setObject<T: Codable>(_ object: T, forKey key: String, expiry: Expiry = .never) throws {
        try setObject(CodableWrapper(object), forKey: key, expiry: expiry)
    }

    open func object<T: Codable>(forKey key: String, as type: T.Type, completion: @escaping (Result<T, Error>) -> Void) {
        return object(forKey: key, as: CodableWrapper<T>.self, completion: { result in
            switch result {
            case let .success(wrapper):
                completion(.success(wrapper.object))
            case let .failure(error):
                completion(.failure(error))
            }
        })
    }

    open func object<T: Codable>(forKey key: String, as type: T.Type) throws -> T {
        return try object(forKey: key, as: CodableWrapper<T>.self).object
    }
}

private extension AnyCache {
    func _trimRecursively() {
        DispatchQueue.main.asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            guard let self = self else { return }
            self.ioQueue.async {
                self.memoryStorage.removeAllExpires()
                self.diskStorage.removeAllExpires()
            }
            self._trimRecursively()
        }
    }
}

private extension StorageProtocol {
    func storageEntity<T: CacheSerializable>(forKey key: String, as type: T.Type) throws -> Entity {
        guard let entity = entity(forKey: key) else {
            throw StorageError.notFound
        }
        guard !entity.expiry.isExpired else {
            removeEntity(forKey: key)
            throw StorageError.isExpired
        }
        if entity.object is T {
            return entity
        }
        let data = try entity.object.serialize()
        let newObj = try T.deserialize(from: data)
        entity.object = newObj
        return entity
    }
}
