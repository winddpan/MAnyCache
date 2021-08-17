//
//  StringBase64.swift
//  AnyCache
//
//  Created by PAN on 2021/8/16.
//

import Foundation

extension String {
    func toBase64String() -> String {
        let data = data(using: .utf8)!
        return data.base64EncodedString().replacingOccurrences(of: "/", with: "_")
    }
    
    func fromBase64String() -> String? {
        let str = self.replacingOccurrences(of: "_", with: "/")
        if let data = Data(base64Encoded: str) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
