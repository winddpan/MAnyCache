//
//  ViewController.swift
//  iOS-demo
//
//  Created by PAN on 2021/8/13.
//

import AnyCache
import UIKit

class ViewController: UIViewController {
    let cache = AnyCache(name: "DEMO-DEMO", diskStorageConfig: DiskStorageConfig(countLimit: 0, byteLimit: 0))

    override func viewDidLoad() {
        super.viewDidLoad()

        print(self.cache.allKeys)

        let image = try? self.cache.object(forKey: "image", as: UIImage.self)
        print(image)

        for i in 0 ..< 100 {
            try? self.cache.setObject("\(i)\(i)\(i)\(i)\(i)\(i)", forKey: "\(i)")
        }

        try? self.cache.setObject(UIImage(named: "OIP-C.jpeg")!, forKey: "image")

        do {
            let image = try self.cache.object(forKey: "image", as: UIImage.self)
            print(image)

        } catch {
            print(error)
        }

        print(self.cache.allKeys)

        for i in 0 ..< 99 {
            self.cache.removeObject(forKey: "\(i)")
        }

        print(self.cache.allKeys)
        print(self.cache.containsObject(forKey: "image"))

        self.cache.removeAll()
        print(self.cache.allKeys)
    }
}
