//
//  ClassConstant.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

func readFromData<T: BitwiseCopyable>(_ data: Data, cursor:inout Int) -> T {
    let size = MemoryLayout<T>.size
    let value = data.withUnsafeBytes { bytes in
        bytes.loadUnaligned(fromByteOffset: cursor, as: T.self)
    }
    cursor += size
    return value
}

typealias ConstantPool = [UInt16: ClassConstant]

class ClassConstant: NSObject {

    enum Tag : UInt8 {
        case utf8               = 1
        case integer            = 3
        case float              = 4
        case long               = 5
        case double             = 6
        case classRef           = 7
        case stringRef          = 8
        case fieldRef           = 9
        case methodRef          = 10
        case interfaceMethodRef = 11
        case nameAndType        = 12
        case methodHandle       = 15
        case methodType         = 16
        case invokeDynamic      = 18
        case module             = 19
        case package            = 20
    }

    let tag : Tag
    init(withTag tag:Tag) {
        self.tag = tag
        super.init()
    }
    static func withTag(_ tagVal: UInt8, cursor: inout Int, data: Data) throws -> ClassConstant {
        guard let tag = Tag(rawValue: tagVal) else {
            throw ClassFileError.unknownConstantTag(tagVal)
        }
        switch tag {
        case .classRef, .module, .package:
            return ClassOrModuleOrPackageConstant(tag: tag, cursor: &cursor, data: data)
        case .fieldRef, .methodRef, .interfaceMethodRef:
            return MethodOrFieldRefConstant(tag: tag, cursor: &cursor, data: data)
        case .stringRef:
            return StringRefConstant(tag: tag, cursor: &cursor, data: data)
        case .integer:
            return IntegerConstant(tag: tag, cursor: &cursor, data: data)
        case .float:
            return FloatConstant(tag: tag, cursor: &cursor, data: data)
        case .long:
            return LongConstant(tag: tag, cursor: &cursor, data: data)
        case .double:
            return DoubleConstant(tag: tag, cursor: &cursor, data: data)
        case .nameAndType:
            return NameAndTypeConstant(tag: tag, cursor: &cursor, data: data)
        case .utf8:
            return try Utf8Constant(tag: tag, cursor: &cursor, data: data)
        case .methodHandle:
            return try MethodHandleConstant(tag: tag, cursor: &cursor, data: data)
        case .methodType:
            return MethodTypeConstant(tag: tag, cursor: &cursor, data: data)
        case .invokeDynamic:
            return InvokeDynamicConstant(tag: tag, cursor: &cursor, data: data)
        }
    }
}

class ClassOrModuleOrPackageConstant : ClassConstant { // Tag will delinate ClassRef, ModuleRef and PackageRef
    let nameIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodOrFieldRefConstant : ClassConstant { // Tag will delineate FieldRef, MethodRef, and InterfaceMethodRef
    let classIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        classIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class StringRefConstant : ClassConstant {
    let stringIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        stringIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class IntegerConstant : ClassConstant {
    let value : Int32
    init(tag:Tag, cursor:inout Int, data:Data) {
        value = Int32(NSSwapBigIntToHost(readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class FloatConstant : ClassConstant {
    let value : Float
    init(tag:Tag, cursor:inout Int, data:Data) {
        value = NSSwapBigFloatToHost(NSSwappedFloat(v: readFromData(data, cursor: &cursor)))
        super.init(withTag: tag)
    }
}

class LongConstant : ClassConstant {
    let value : Int64
    init(tag:Tag, cursor:inout Int, data:Data) {
        var temp4 : UInt32 = readFromData(data, cursor: &cursor)
        let localLong = UInt64(temp4) << 32
        temp4 = readFromData(data, cursor: &cursor)
        value = Int64(NSSwapBigLongLongToHost(localLong + UInt64(temp4)))
        super.init(withTag: tag)
    }
}

class DoubleConstant : ClassConstant {
    let value : Double
    init(tag:Tag, cursor:inout Int, data:Data) {
        var temp4 : UInt32 = readFromData(data, cursor: &cursor)
        var temp8 = UInt64(temp4) << 32
        temp4 = readFromData(data, cursor: &cursor)
        temp8 += UInt64(temp4)
        value = NSSwapBigDoubleToHost(NSSwappedDouble(v: temp8))
        super.init(withTag: tag)
    }
}

class NameAndTypeConstant : ClassConstant {
    let nameIndex : UInt16
    let descriptorIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class Utf8Constant : ClassConstant {
    let length : UInt16
    let string : NSString
    init(tag:Tag, cursor:inout Int, data:Data) throws {
        length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        guard let tempString = NSString(data: (data as NSData).subdata(with: NSMakeRange(cursor, Int(length))), encoding: String.Encoding.utf8.rawValue) else {
            throw ClassFileError.invalidUtf8
        }
        string = tempString
        cursor += Int(length)
        super.init(withTag: tag)
    }
}


class MethodHandleConstant: ClassConstant {

    enum Kind : UInt8 {
        case getField = 1
        case getStatic
        case putField
        case putStatic
        case invokeVirtual
        case invokeStatic
        case invokeSpecial
        case newInvokeSpecial
        case invokeInterface
    }

    let referenceKind : Kind
    let referenceIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) throws {
        let rawValue: UInt8 = readFromData(data, cursor: &cursor)
        guard let kind = Kind(rawValue: rawValue) else {
            throw ClassFileError.unknownEnumValue("MethodHandle.Kind", rawValue)
        }
        referenceKind = kind
        referenceIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class MethodTypeConstant : ClassConstant {
    let descriptorIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}

class InvokeDynamicConstant: ClassConstant {
    let bootstrapMethodAttrIndex : UInt16
    let nameAndTypeIndex : UInt16
    init(tag:Tag, cursor:inout Int, data:Data) {
        bootstrapMethodAttrIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        nameAndTypeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        super.init(withTag: tag)
    }
}
