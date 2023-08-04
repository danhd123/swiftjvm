//
//  FieldDescriptor.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/3/23.
//

import Foundation

class FieldDescriptor {
    let size: UInt8
    init(constant: Utf8Constant) {
        let strType = constant.string as String
        switch strType {
        case "B":
            size = 1
        case "C":
            size = 2
        case "D":
            size = 8
        case "F":
            size = 4
        case "I":
            size = 4
        case "J":
            size = 8
        case "S":
            size = 2
        case "Z":
            size = 1
        default:
            size = UInt8(MemoryLayout<UnsafePointer<AnyClass>>.size)
        }
    }
}
