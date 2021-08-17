//
//  DiskStorage.swift
//  AnyCache
//
//  Created by PAN on 2021/8/13.
//

import Foundation

public struct DiskStorageConfig {
    public let fileManager: FileManager
    public let countLimit: Int
    public let byteLimit: Int

    public init(fileManager: FileManager = .default, countLimit: Int, byteLimit: Int) {
        self.fileManager = fileManager
        self.countLimit = countLimit
        self.byteLimit = byteLimit
    }

    public static let `default` = DiskStorageConfig(fileManager: .default, countLimit: Int.max, byteLimit: Int.max)
}

final class DiskStorage {
    let name: String
    let fileManager: FileManager
    let config: DiskStorageConfig
    let lock = NSRecursiveLock()

    private lazy var directory: String = {
        let dstPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!
        return (dstPath as NSString).appendingPathComponent("AnyCache/\(name)")
    }()

    init(name: String, config: DiskStorageConfig) {
        self.name = name
        self.config = config
        self.fileManager = config.fileManager
    }

    func fileUrl(_ key: String) -> URL {
        let filename = key.toBase64String()
        let path = (directory as NSString).appendingPathComponent(filename)
        return URL(fileURLWithPath: path, isDirectory: false)
    }

    func createDirectory() throws {
        guard !fileManager.fileExists(atPath: directory) else {
            return
        }
        try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true, attributes: nil)
    }
}

extension DiskStorage: StorageProtocol {
    struct ResourceObject {
        let url: URL
        let expire: Date
        let create: Date
        let size: Int

        init?(url: URL, size: Int, fileExtendedAttributes: Any) {
            guard let attributes = fileExtendedAttributes as? [String: Any],
                  let __expire = attributes["expire"] as? Data,
                  let __create = attributes["create"] as? Data,
                  let _expire = String(data: __expire, encoding: .utf8),
                  let _create = String(data: __create, encoding: .utf8),
                  let expire = TimeInterval(_expire),
                  let create = TimeInterval(_create)
            else {
                return nil
            }
            self.url = url
            self.size = size
            self.expire = Date(timeIntervalSince1970: expire)
            self.create = Date(timeIntervalSince1970: create)
        }
    }

    var allKeys: [String] {
        lock.lock(); defer { lock.unlock() }

        let resoucesKey: [URLResourceKey] = [.isDirectoryKey, .isHiddenKey]
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: directory),
                                                      includingPropertiesForKeys: resoucesKey,
                                                      options: .skipsSubdirectoryDescendants)
        else {
            return []
        }
        var keys: [String] = []
        while let url = enumerator.nextObject() {
            if let url = url as? URL,
               let resourceValues = try? url.resourceValues(forKeys: Set(resoucesKey)),
               resourceValues.isDirectory == false,
               resourceValues.isHidden == false,
               let key = url.lastPathComponent.fromBase64String()
            {
                keys.append(key)
            }
        }
        return keys
    }

    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        try? fileManager.removeItem(atPath: directory)
    }

    func removeEntity(forKey key: String) {
        lock.lock(); defer { lock.unlock() }
        let fileUrl = fileUrl(key)
        try? fileManager.removeItem(at: fileUrl)
    }

    func entity(forKey key: String) -> Entity? {
        lock.lock(); defer { lock.unlock() }
        let url = fileUrl(key)
        if let data = fileManager.contents(atPath: url.path), let attributes = try? fileManager.attributesOfItem(atPath: url.path) {
            guard let extendAttributes = attributes[.fileExtendedAttributes],
                  let resouce = ResourceObject(url: url, size: 0, fileExtendedAttributes: extendAttributes)
            else {
                return nil
            }
            return Entity(object: data, expiry: Expiry(from: resouce.expire))
        }
        return nil
    }

    func setEntity(_ entity: Entity, forKey key: String, cost: StorageCost) throws -> Int {
        lock.lock(); defer { lock.unlock() }
        try createDirectory()
        let url = fileUrl(key)
        let data = try entity.object.serialize()
        let attributes = [FileAttributeKey.fileExtendedAttributes: ["expire": "\(entity.expiry.date.timeIntervalSince1970)".data(using: .utf8)!,
                                                                    "create": "\(Date().timeIntervalSince1970)".data(using: .utf8)!]]
        _ = fileManager.createFile(atPath: url.path, contents: data, attributes: nil)
        try fileManager.setAttributes(attributes, ofItemAtPath: url.path)
        return data.count
    }

    func containsEntity(forKey key: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let url = fileUrl(key)
        return fileManager.fileExists(atPath: url.path)
    }

    func removeAllExpires() {
        lock.lock(); defer { lock.unlock() }
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: directory), includingPropertiesForKeys: nil, options: .skipsSubdirectoryDescendants) else {
            return
        }

        var filesOnUsed = [ResourceObject]()
        var filesToDelete = [URL]()

        while let url = enumerator.nextObject() {
            guard let url = url as? URL else { continue }
            guard let attributes = try? fileManager.attributesOfItem(atPath: url.path) else { continue }
            guard let size = attributes[.size] as? Int else { continue }
            guard let extendedAttributes = attributes[.fileExtendedAttributes] else { continue }
            guard let resourceObject = ResourceObject(url: url, size: size, fileExtendedAttributes: extendedAttributes) else { continue }
            if resourceObject.expire.timeIntervalSinceNow < 0 {
                filesToDelete.append(url)
            } else {
                filesOnUsed.append(resourceObject)
            }
        }

        filesOnUsed = filesOnUsed.sorted(by: {
            let expire1 = $0.expire.timeIntervalSince1970
            let expire2 = $1.expire.timeIntervalSince1970
            let creation1 = $0.create.timeIntervalSince1970
            let creation2 = $1.create.timeIntervalSince1970
            if expire1 == expire2 {
                return creation1 > creation2
            }
            return expire1 > expire2
        })

        // find oversizes
        if config.byteLimit > 0 {
            var usedSize: Int = 0
            for (i, file) in filesOnUsed.enumerated() {
                usedSize += file.size
                if usedSize > config.byteLimit {
                    let overCostFiles = Array(filesOnUsed[i ..< filesOnUsed.count]).map { $0.url }
                    filesOnUsed = Array(filesOnUsed[0 ..< i])
                    filesToDelete.append(contentsOf: overCostFiles)
                    break
                }
            }
        }

        // find overcount
        if config.countLimit > 0, filesOnUsed.count > config.countLimit {
            let overCountFiles = Array(filesOnUsed[config.countLimit ..< filesOnUsed.count]).map { $0.url }
            filesToDelete.append(contentsOf: overCountFiles)
        }

        // delete expires & oversizes
        for url in filesToDelete {
            try? fileManager.removeItem(at: url)
        }
    }
}

private extension FileAttributeKey {
    static let fileExtendedAttributes = FileAttributeKey("NSFileExtendedAttributes")
}
