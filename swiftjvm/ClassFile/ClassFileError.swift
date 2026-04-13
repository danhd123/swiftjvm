//
//  ClassFileError.swift
//  swiftjvm
//

enum ClassFileError: Error {
    case invalidMagic(UInt32)
    case unknownConstantTag(UInt8)
    case invalidUtf8
    case unknownEnumValue(String, UInt8)
    case invalidConstantPoolIndex(UInt16)
    case invalidConstantPoolType(UInt16)
}
