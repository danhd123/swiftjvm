//
//  StackMapTableAttribute.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

class StackMapTableAttribute: AttributeInfo {

    class StackMapFrame: NSObject {

        enum Tag {
            case same(UInt8)
            case sameLocals1StackItem(UInt8)
            case sameLocals1StackItemExtended
            case chop(UInt8)
            case sameFrameExtended
            case append(UInt8)
            case fullFrame
            static func fromRaw(_ rawValue:UInt8) -> Tag? {
                switch rawValue {
                case 0...63:
                    return same(rawValue)
                case 64...127:
                    return sameLocals1StackItem(rawValue)
                case 247:
                    return sameLocals1StackItemExtended
                case 248...250:
                    return chop(rawValue)
                case 251:
                    return sameFrameExtended
                case 252...254:
                    return append(rawValue)
                case 255:
                    return fullFrame
                default:
                    return nil
                }
            }
            func value() -> UInt8 {
                switch self {
                case let .same(rawValue):
                    return rawValue
                case let .sameLocals1StackItem(rawValue):
                    return rawValue
                case .sameLocals1StackItemExtended:
                    return 247
                case let .chop(rawValue):
                    return rawValue
                case .sameFrameExtended:
                    return 251
                case let .append(rawValue):
                    return rawValue
                case .fullFrame:
                    return 255
                }
            }
        }

        enum VerificationTypeInfo {
            case top
            case integer
            case float
            case long
            case double
            case null
            case object(UInt16)
            case uninitialized(UInt16)
            static func fromRaw(_ rawValue:UInt8, poolIndexOrOffset:UInt16 = 0) -> VerificationTypeInfo? {
                switch rawValue {
                case 0:
                    return top
                case 1:
                    return integer
                case 2:
                    return float
                case 4: // *sigh*
                    return long
                case 3: //yes really
                    return double
                case 5:
                    return null
                case 6:
                    return object(poolIndexOrOffset)
                case 7:
                    return uninitialized(poolIndexOrOffset)
                default:
                    return nil
                }
            }

        }

        let frameType : Tag
        init(frameType:Tag) {
            self.frameType = frameType
            super.init()
        }

        static func readVerificationTypeInfoFromData(_ data:Data, cursor:inout Int) throws -> VerificationTypeInfo {
            let temp1 : UInt8 = readFromData(data, cursor: &cursor)
            let result: VerificationTypeInfo?
            if temp1 == 6 || temp1 == 7 {
                result = VerificationTypeInfo.fromRaw(temp1, poolIndexOrOffset: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            }
            else {
                result = VerificationTypeInfo.fromRaw(temp1)
            }
            guard let vti = result else {
                throw ClassFileError.unknownEnumValue("VerificationTypeInfo", temp1)
            }
            return vti
        }

        static func fromData(_ data:Data, cursor:inout Int) throws -> StackMapFrame {
            let rawTag: UInt8 = readFromData(data, cursor: &cursor)
            guard let tag = StackMapFrame.Tag.fromRaw(rawTag) else {
                throw ClassFileError.unknownEnumValue("StackMapFrame.Tag", rawTag)
            }
            switch tag {
            case .same:
                return SameFrame(frameType: tag)
            case .sameLocals1StackItem:
                return try SameLocals1StackItemFrame(frameType: tag, data: data, cursor: &cursor)
            case .sameLocals1StackItemExtended:
                return try SameLocals1StackItemFrameExtended(frameType: tag, data: data, cursor: &cursor)
            case .chop:
                return ChopFrame(frameType: tag, data: data, cursor: &cursor)
            case .sameFrameExtended:
                return SameFrameExtended(frameType: tag, data: data, cursor: &cursor)
            case .append:
                return try AppendFrame(frameType: tag, data: data, cursor: &cursor)
            case .fullFrame:
                return try FullFrame(frameType: tag, data: data, cursor: &cursor)
            }
        }
    }

    class SameFrame: StackMapFrame {
    }

    class SameLocals1StackItemFrame: StackMapFrame {
        let stackItem : VerificationTypeInfo
        init(frameType: Tag, data:Data, cursor:inout Int) throws {
            let temp1 : UInt8 = readFromData(data, cursor: &cursor)
            let result: VerificationTypeInfo?
            if temp1 == 6 || temp1 == 7 {
                result = VerificationTypeInfo.fromRaw(temp1, poolIndexOrOffset: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            }
            else {
                result = VerificationTypeInfo.fromRaw(temp1)
            }
            guard let vti = result else {
                throw ClassFileError.unknownEnumValue("VerificationTypeInfo", temp1)
            }
            stackItem = vti
            super.init(frameType: frameType)
        }
    }

    class SameLocals1StackItemFrameExtended: StackMapFrame {
        let offsetDelta : UInt16
        let stackItem : VerificationTypeInfo
        init(frameType: Tag, data:Data, cursor:inout Int) throws {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            stackItem = try StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor)
            super.init(frameType: frameType)
        }
    }

    class ChopFrame: StackMapFrame {
        let offsetDelta : UInt16
        init(frameType: Tag, data:Data, cursor:inout Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            super.init(frameType: frameType)
        }
    }

    class SameFrameExtended: StackMapFrame {
        let offsetDelta : UInt16
        init(frameType: Tag, data:Data, cursor:inout Int) {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            super.init(frameType: frameType)
        }
    }

    class AppendFrame: StackMapFrame {
        let offsetDelta : UInt16
        let locals : [VerificationTypeInfo]
        init(frameType: Tag, data:Data, cursor:inout Int) throws {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            let k = frameType.value() - 251
            var tempLocals = [VerificationTypeInfo]()
            for _ in 0..<k {
                tempLocals.append(try StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor))
            }
            locals = tempLocals
            super.init(frameType: frameType)
        }
    }

    class FullFrame: StackMapFrame {
        let offsetDelta : UInt16
        let numberOfLocals : UInt16
        let locals : [VerificationTypeInfo]
        let numberOfStackItems : UInt16
        let stack : [VerificationTypeInfo]
        init(frameType: Tag, data:Data, cursor:inout Int) throws {
            offsetDelta = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numberOfLocals = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempLocals = [VerificationTypeInfo]()
            for _ in 0..<numberOfLocals {
                tempLocals.append(try StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor))
            }
            locals = tempLocals
            numberOfStackItems = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempStack = [VerificationTypeInfo]()
            for _ in 0..<numberOfStackItems {
                tempStack.append(try StackMapFrame.readVerificationTypeInfoFromData(data, cursor: &cursor))
            }
            stack = tempStack
            super.init(frameType: frameType)
        }

    }

    let numberOfEntries : UInt16
    let entries : [StackMapFrame]
    init(header:Header, data:Data, cursor:inout Int) throws {
        numberOfEntries = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localEntries = [StackMapFrame]()
        for _ in 0..<numberOfEntries {
            localEntries.append(try StackMapFrame.fromData(data, cursor:&cursor))
        }
        entries = localEntries
        super.init(header: header)
    }
}
