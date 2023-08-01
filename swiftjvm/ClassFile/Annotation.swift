//
//  Annotation.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

extension AttributeInfo {
    struct Annotation {
        
        class ElementValuePair : NSObject {
            
            enum Tag : UInt8 {
                case byte = "B"
                case char = "C"
                case double = "D"
                case float = "F"
                case integer = "I"
                case long = "J"
                case short = "S"
                case boolean = "Z"
                case string = "s"
                case `enum` = "e"
                case `class` = "c"
                case annotation = "@"
                case array = "["
            }
            
            let tag : Tag
            static func fromData(_ data:Data, cursor:inout Int, constantPool:ConstantPool) -> ElementValuePair {
                let tag = Tag(rawValue: readFromData(data, cursor: &cursor))!
                switch tag {
                case .byte, .char, .double, .float, .integer, .long, .short, .boolean, .string:
                    return ConstValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .enum:
                    return EnumValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .class:
                    return ClassValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .annotation:
                    return AnnotationValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                case .array:
                    return ArrayValue(tag: tag, data: data, cursor: &cursor, constantPool: constantPool)
                }
            }
            init(tag:Tag) {
                self.tag = tag;
                super.init()
            }
        }
        
        class ConstValue: ElementValuePair {
            let constValueIndex : UInt16
            //cached
            let constant : ClassConstant
            init(tag:Tag, data:Data, cursor:inout Int, constantPool:ConstantPool) {
                constValueIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                constant = constantPool[constValueIndex]!
                super.init(tag: tag)
            }
        }
        
        class EnumValue: ElementValuePair {
            let typeNameIndex : UInt16
            let constNameIndex : UInt16
            //cached
            let typeName : Utf8Constant
            let constName : Utf8Constant
            init(tag:Tag, data:Data, cursor:inout Int, constantPool:ConstantPool) {
                typeNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                constNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                typeName = constantPool[typeNameIndex]! as! Utf8Constant
                constName = constantPool[constNameIndex]! as! Utf8Constant
                super.init(tag: tag)
            }
        }
        
        class ClassValue: ElementValuePair {
            let classInfoIndex : UInt16
            //cached
            let classInfo : ClassOrModuleOrPackageConstant
            init(tag:Tag, data:Data, cursor:inout Int, constantPool:ConstantPool) {
                classInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                classInfo = constantPool[classInfoIndex]! as! ClassOrModuleOrPackageConstant
                super.init(tag: tag)
            }
        }
        
        class AnnotationValue: ElementValuePair {
            let annotation : Annotation
            init(tag:Tag, data:Data, cursor:inout Int, constantPool:ConstantPool) {
                annotation = Annotation(data: data, cursor: &cursor, constantPool: constantPool)
                super.init(tag: tag)
            }
        }
        
        class ArrayValue: ElementValuePair {
            let numValues : UInt16
            let values : [ElementValuePair]
            init(tag:Tag, data:Data, cursor:inout Int, constantPool:ConstantPool) {
                numValues = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                var tempValues = [ElementValuePair]()
                for _ in 0..<numValues {
                    tempValues.append(ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool))
                }
                values = tempValues
                super.init(tag: tag)
            }
        }
        
        let typeIndex : UInt16
        let numElementValuePairs : UInt16
        let elementValuePairs : [ElementValuePair]
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            typeIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numElementValuePairs = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempEVPs = [ElementValuePair]()
            for _ in 0..<numElementValuePairs {
                tempEVPs.append(ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool))
            }
            elementValuePairs = tempEVPs
        }
    }
    struct CountedAnnotations {
        let numAnnotations : UInt16
        let annotations : [Annotation]
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            numAnnotations = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempAnnotations = [Annotation]()
            for _ in 0..<numAnnotations {
                tempAnnotations.append(Annotation(data: data, cursor: &cursor, constantPool: constantPool))
            }
            annotations = tempAnnotations
        }
    }
    
    struct CountedTypeAnnotations {
        let numAnnotations: UInt16
        let annotations : [TypeAnnotation]
        init(data: Data, cursor: inout Int, constantPool:ConstantPool) {
            numAnnotations = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempAnnotations = [TypeAnnotation]()
            for _ in 0..<numAnnotations {
                tempAnnotations.append(TypeAnnotation(data: data, cursor: &cursor, constantPool: constantPool))
            }
            annotations = tempAnnotations
        }
    }

}
