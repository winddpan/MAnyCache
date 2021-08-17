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

//        for i in 0 ..< 100 {
//            try? self.cache.setObject("\(i)\(i)\(i)\(i)\(i)\(i)", forKey: "\(i)")
//        }
//
//        try? self.cache.setObject(UIImage.init(named: "OIP-C.jpeg")!, forKey: "image")
//        let image = try? self.cache.object(forKey: "image", as: UIImage.self)
//
        
        do {
            let image = try self.cache.object(forKey: "image", as: Data.self)
            print(image)

        } catch  {
            print(error)
        }

        
        print(self.cache.allKeys)

        
        
    }
}
