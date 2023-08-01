//
//  MethodInfo.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

struct MethodInfo {
    
    struct AccessFlags: OptionSet {
        let rawValue: UInt16
        init(rawValue: UInt16) { self.rawValue = rawValue }
        
        static var None         : AccessFlags { return AccessFlags(rawValue: 0x0000) }
        static var Public       : AccessFlags { return AccessFlags(rawValue: 0x0001) }
        static var Private      : AccessFlags { return AccessFlags(rawValue: 0x0002) }
        static var Protected    : AccessFlags { return AccessFlags(rawValue: 0x0004) }
        static var Static       : AccessFlags { return AccessFlags(rawValue: 0x0008) }
        static var Final        : AccessFlags { return AccessFlags(rawValue: 0x0010) }
        static var Bridge       : AccessFlags { return AccessFlags(rawValue: 0x0040) }
        static var Varargs      : AccessFlags { return AccessFlags(rawValue: 0x0080) }
        static var Native       : AccessFlags { return AccessFlags(rawValue: 0x0100) }
        static var Abstract     : AccessFlags { return AccessFlags(rawValue: 0x0400) }
        static var Strict       : AccessFlags { return AccessFlags(rawValue: 0x0800) }
        static var Synthetic    : AccessFlags { return AccessFlags(rawValue: 0x1000) }
        
    }

    let accessFlags : AccessFlags
    let nameIndex : UInt16
    let descriptorIndex : UInt16
    let attributesCount : UInt16
    let attributes : [AttributeInfo]
    //cached
    let name : Utf8Constant
    let descriptor : Utf8Constant
    init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
        accessFlags = AccessFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        attributesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempAttributes = [AttributeInfo]()
        for _ in 0..<attributesCount {
            tempAttributes.append(AttributeInfo.fromData(data, cursor: &cursor, constantPool: constantPool))
        }
        attributes = tempAttributes
        
        name = constantPool[nameIndex]! as! Utf8Constant
        descriptor = constantPool[descriptorIndex]! as! Utf8Constant
    }
}
