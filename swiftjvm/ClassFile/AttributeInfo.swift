//
//  AttributeInfo.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/26/23.
//

import Foundation

extension UInt8 : ExpressibleByStringLiteral {
    public typealias ExtendedGraphemeClusterLiteralType = String
    public typealias UnicodeScalarLiteralType = String
    
    public init(stringLiteral value: StringLiteralType){
        self.init(([UInt8]() + value.utf8)[0])
    }
    
    public init(extendedGraphemeClusterLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }
    
    public init(unicodeScalarLiteral value: String){
        self.init(([UInt8]() + value.utf8)[0])
    }
}

class AttributeInfo : NSObject {
    struct Header {
        let attributeNameIndex : UInt16
        let attributeLength : UInt32
        init(data:Data, cursor:inout Int) {
            attributeNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            attributeLength = NSSwapBigIntToHost(readFromData(data, cursor: &cursor))
        }
    }
    
    let header : Header
    init(header:Header) {
        self.header = header
        super.init()
    }
    static func fromData(_ data:Data, cursor:inout Int, constantPool:ConstantPool) -> AttributeInfo {
        let header = AttributeInfo.Header(data: data, cursor: &cursor)
        switch (constantPool[header.attributeNameIndex]! as! Utf8Constant).string {
        case "ConstantValue":
            return ConstantValueAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Code":
            return CodeAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "StackMapTable":
            return StackMapTableAttribute(header: header, data: data, cursor: &cursor)
        case "Exceptions":
            return ExceptionTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "InnerClasses":
            return InnerClassAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "EnclosingMethod":
            return EnclosingMethodAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Synthetic":
            return SyntheticAttribute(header: header)
        case "Signature":
            return SignatureAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "SourceFile":
            return SourceFileAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "SourceDebugExtension":
            return SourceDebugExtension(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "LineNumberTable":
            return LineNumberTableAttribute(header: header, data: data, cursor: &cursor)
        case "LocalVariableTable":
            return LocalVariableTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "LocalVariableTypeTable":
            return LocalVariableTypeTableAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Deprecated":
            return DeprecatedAttribute(header: header)
        case "RuntimeVisibleAnnotations":
            return RuntimeVisibleAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeInvisibleAnnotations":
            return RuntimeInvisibleAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeVisibleParamterAnnotations":
            return RuntimeVisibleParameterAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeInvisibleParameterAnnotations":
            return RuntimeInvisibleParameterAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeVisibleTypeAnnotations":
            return RuntimeVisibleTypeAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "RuntimeInvisibleTypeAnnotations":
            return RuntimeInvisibleTypeAnnotationsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "AnnotationDefault":
            return AnnotationDefaultAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "BootstrapMethods":
            return BootstrapMethodsAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "MethodParameters":
            return MethodParametersAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Module":
            return ModuleAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "ModulePackages":
            return ModulePackagesAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "ModuleMainClass":
            return ModuleMainClassAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "NestHost":
            return NestHostAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "NestMembers":
            return NestMembersAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "Record":
            return RecordAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        case "PermittedSubclasses":
            return PermittedSubclassesAttribute(header: header, data: data, cursor: &cursor, constantPool: constantPool)
        default:
            return UnknownAttribute(header: header, data: data, cursor: &cursor)
        }
    }
}

class ConstantValueAttribute : AttributeInfo {
    let constantValueIndex : UInt16
    let classConstant : ClassConstant //ooh, caching!
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        constantValueIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        classConstant = constantPool[constantValueIndex]!
        super.init(header: header)
    }
}

class CodeAttribute: AttributeInfo {
    
    struct ExceptionEntry {
        let startPC : UInt16
        let endPC : UInt16
        let handlerPC : UInt16
        let catchType : UInt16
        init(data:Data, cursor:inout Int) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            endPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            handlerPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            catchType = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        }
    }
    
    let maxStack : UInt16
    let maxLocals : UInt16
    let codeLength : UInt32
    let code : Data
    let exceptionTableLength : UInt16
    let exceptionTable : [ExceptionEntry]
    let attributesCount : UInt16
    let attributes : [AttributeInfo]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        maxStack = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        maxLocals = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        codeLength = NSSwapBigIntToHost(readFromData(data, cursor: &cursor))
        code = (data as NSData).subdata(with: NSMakeRange(cursor, Int(codeLength)))
        cursor += Int(codeLength)
        exceptionTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localTable = [ExceptionEntry]()
        for _ in 0..<exceptionTableLength {
            localTable.append(ExceptionEntry(data: data, cursor: &cursor))
        }
        exceptionTable = localTable
        attributesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localAttrs = [AttributeInfo]()
        for _ in 0..<attributesCount {
            localAttrs.append(AttributeInfo.fromData(data, cursor: &cursor, constantPool: constantPool))
        }
        attributes = localAttrs
        super.init(header: header)
    }
}

class ExceptionTableAttribute: AttributeInfo {
    let numberOfExceptions : UInt16
    let exceptionIndexTable : [UInt16]
    let exceptions : [ClassOrModuleOrPackageConstant]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        numberOfExceptions = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localIndexes = [UInt16]()
        for _ in 0..<numberOfExceptions {
            localIndexes.append(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        }
        exceptionIndexTable = localIndexes
        exceptions = exceptionIndexTable.map() { index in
            constantPool[index] as! ClassOrModuleOrPackageConstant
        }
        super.init(header: header)
    }
}

class InnerClassAttribute: AttributeInfo {
    
    struct InnerClass {
        
        struct AccessFlags: OptionSet {
            let rawValue: UInt16
            init(rawValue: UInt16) { self.rawValue = rawValue }
            
            static var None         : AccessFlags { return AccessFlags(rawValue: 0x0000) }
            static var Public       : AccessFlags { return AccessFlags(rawValue: 0x0001) }
            static var Private      : AccessFlags { return AccessFlags(rawValue: 0x0002) }
            static var Protected    : AccessFlags { return AccessFlags(rawValue: 0x0004) }
            static var Static       : AccessFlags { return AccessFlags(rawValue: 0x0008) }
            static var Final        : AccessFlags { return AccessFlags(rawValue: 0x0010) }
            static var Interface    : AccessFlags { return AccessFlags(rawValue: 0x0200) }
            static var Abstract     : AccessFlags { return AccessFlags(rawValue: 0x0400) }
            static var Synthetic    : AccessFlags { return AccessFlags(rawValue: 0x1000) }
            static var Annotation   : AccessFlags { return AccessFlags(rawValue: 0x2000) }
            static var Enum         : AccessFlags { return AccessFlags(rawValue: 0x4000) }
            
        }

        let innerClassInfoIndex : UInt16
        let outerClassInfoIndex : UInt16
        let innerNameIndex : UInt16
        let innerClassAccessFlagss : AccessFlags
        // cached types:
        let innerClassRef : ClassOrModuleOrPackageConstant
        let outerClassRef : ClassOrModuleOrPackageConstant?
        let innerName : Utf8Constant?
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            innerClassInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            outerClassInfoIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            innerNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            innerClassAccessFlagss = AccessFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            innerClassRef = constantPool[innerClassInfoIndex]! as! ClassOrModuleOrPackageConstant
            outerClassRef = constantPool[outerClassInfoIndex] as? ClassOrModuleOrPackageConstant
            innerName = constantPool[innerNameIndex] as? Utf8Constant
        }
    }
    
    let numberOfClasses : UInt16
    let classes : [InnerClass]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        numberOfClasses = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localClasses = [InnerClass]()
        for _ in 0..<numberOfClasses {
            localClasses.append(InnerClass(data: data, cursor: &cursor, constantPool: constantPool))
        }
        classes = localClasses
        super.init(header: header)
    }
}

class EnclosingMethodAttribute: AttributeInfo {
    let classIndex : UInt16
    let methodIndex : UInt16
    //cached types:
    let classRef : ClassOrModuleOrPackageConstant
    let methodRef : NameAndTypeConstant? // yes really
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        classIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        methodIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        classRef = constantPool[classIndex]! as! ClassOrModuleOrPackageConstant
        methodRef = constantPool[methodIndex] as? NameAndTypeConstant
        super.init(header: header)
    }
}

class SyntheticAttribute: AttributeInfo {
}

class SignatureAttribute: AttributeInfo {
    let signatureIndex : UInt16
    //cached:
    let signature : Utf8Constant
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        signatureIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        signature = constantPool[signatureIndex]! as! Utf8Constant
        super.init(header: header)
    }
}

class SourceFileAttribute: AttributeInfo {
    let sourceFileIndex : UInt16
    //cached:
    let sourceFile : Utf8Constant
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        sourceFileIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        sourceFile = constantPool[sourceFileIndex]! as! Utf8Constant
        super.init(header: header)
    }
}

class SourceDebugExtension: AttributeInfo {
    let debugExtension : Data
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        debugExtension = (data as NSData).subdata(with: NSMakeRange(cursor, Int(header.attributeLength)))
        cursor += Int(header.attributeLength)
        super.init(header: header)
    }
}
class LineNumberTableAttribute: AttributeInfo {
    
    struct LineNumberEntry {
        let startPC : UInt16
        let lineNumber : UInt16
        init(startPC:UInt16, lineNumber:UInt16) {
            self.startPC = startPC
            self.lineNumber = lineNumber
        }
    }
    
    let lineNumberTableLength : UInt16
    let lineNumberTable : [LineNumberEntry]
    init(header:Header, data:Data, cursor:inout Int) {
        lineNumberTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var localTable = [LineNumberEntry]()
        for _ in 0..<lineNumberTableLength {
            let startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            let lineNumber = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            localTable.append(LineNumberEntry(startPC:startPC, lineNumber:lineNumber))
        }
        lineNumberTable = localTable
        super.init(header: header)
    }
}

class LocalVariableTableAttribute: AttributeInfo {
    
    struct LocalVariableEntry {
        let startPC : UInt16
        let length : UInt16
        let nameIndex : UInt16
        let descriptorIndex : UInt16
        let index : UInt16
        //cached:
        let name : Utf8Constant
        let descriptor : Utf8Constant
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            name = constantPool[nameIndex]! as! Utf8Constant
            descriptor = constantPool[descriptorIndex]! as! Utf8Constant
        }
    }
    
    let localVariableTableLength : UInt16
    let localVariableTable : [LocalVariableEntry]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        localVariableTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempTable = [LocalVariableEntry]()
        for _ in 0..<localVariableTableLength {
            tempTable.append(LocalVariableEntry(data: data, cursor: &cursor, constantPool: constantPool))
        }
        localVariableTable = tempTable
        super.init(header: header)
    }
}

class LocalVariableTypeTableAttribute: AttributeInfo {
    
    struct LocalVariableEntry {
        let startPC : UInt16
        let length : UInt16
        let nameIndex : UInt16
        let signatureIndex : UInt16
        let index : UInt16
        //cached:
        let name : Utf8Constant
        let signature : Utf8Constant
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            startPC = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            length = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            signatureIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            name = constantPool[nameIndex]! as! Utf8Constant
            signature = constantPool[signatureIndex]! as! Utf8Constant
        }
    }
    
    let localVariableTableLength : UInt16
    let localVariableTable : [LocalVariableEntry]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        localVariableTableLength = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempTable = [LocalVariableEntry]()
        for _ in 0..<localVariableTableLength {
            tempTable.append(LocalVariableEntry(data: data, cursor: &cursor, constantPool: constantPool))
        }
        localVariableTable = tempTable
        super.init(header: header)
    }
}

class DeprecatedAttribute: AttributeInfo {
}

class RuntimeVisibleAnnotationsAttribute: AttributeInfo {
    let annotations : CountedAnnotations
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        annotations = CountedAnnotations(data:data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class RuntimeInvisibleAnnotationsAttribute: AttributeInfo {
    let annotations : CountedAnnotations
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        annotations = CountedAnnotations(data:data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class RuntimeVisibleParameterAnnotationsAttribute: AttributeInfo {
    let numParameters : UInt8
    let paramaterAnnotations : [CountedAnnotations]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        numParameters = readFromData(data, cursor: &cursor)
        var tempParams = [CountedAnnotations]()
        for _ in 0..<numParameters {
            tempParams.append(CountedAnnotations(data: data, cursor: &cursor, constantPool: constantPool))
        }
        paramaterAnnotations = tempParams;
        super.init(header: header)
    }
}

class RuntimeInvisibleParameterAnnotationsAttribute: AttributeInfo {
    let numParameters : UInt8
    let paramaterAnnotations : [CountedAnnotations]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        numParameters = readFromData(data, cursor: &cursor)
        var tempParams = [CountedAnnotations]()
        for _ in 0..<numParameters {
            tempParams.append(CountedAnnotations(data: data, cursor: &cursor, constantPool: constantPool))
        }
        paramaterAnnotations = tempParams;
        super.init(header: header)
    }
}

class RuntimeVisibleTypeAnnotationsAttribute: AttributeInfo {
    let annotations: CountedTypeAnnotations
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        annotations = CountedTypeAnnotations(data: data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class RuntimeInvisibleTypeAnnotationsAttribute: AttributeInfo {
    let annotations: CountedTypeAnnotations
    init(header:Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        annotations = CountedTypeAnnotations(data: data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class AnnotationDefaultAttribute: AttributeInfo {
    let defaultValue : Annotation.ElementValuePair
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        defaultValue = Annotation.ElementValuePair.fromData(data, cursor: &cursor, constantPool: constantPool)
        super.init(header: header)
    }
}

class BootstrapMethodsAttribute: AttributeInfo {
    struct BootstrapMethod {
        let bootstrapMethodRefIndex : UInt16
        let numBootstrapArguments : UInt16
        let bootstrapArgumentsIndexes : [UInt16]
        //cached:
        let bootstrapMethodRef : MethodOrFieldRefConstant
        let bootstrapArguments : [ClassConstant]
        init(data:Data, cursor:inout Int, constantPool:ConstantPool) {
            bootstrapMethodRefIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            numBootstrapArguments = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempIndicies = [UInt16]()
            for _ in 0..<numBootstrapArguments {
                tempIndicies.append(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            }
            bootstrapArgumentsIndexes = tempIndicies
            
            bootstrapMethodRef = constantPool[bootstrapMethodRefIndex]! as! MethodOrFieldRefConstant
            bootstrapArguments = bootstrapArgumentsIndexes.map() { index in
                constantPool[index] as! ClassOrModuleOrPackageConstant
            }
        }
    }
    
    let numBootstrapMethods : UInt16
    let bootstrapMethods : [BootstrapMethod]
    init(header:Header, data:Data, cursor:inout Int, constantPool:ConstantPool) {
        numBootstrapMethods = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempMethods = [BootstrapMethod]()
        for _ in 0..<numBootstrapMethods {
            tempMethods.append(BootstrapMethod(data: data, cursor: &cursor, constantPool: constantPool))
        }
        bootstrapMethods = tempMethods
        super.init(header: header)
    }
}

class MethodParametersAttribute: AttributeInfo {
    struct Parameter {
        struct AccessFlags: OptionSet {
            let rawValue: UInt16
            init(rawValue: UInt16) { self.rawValue = rawValue }
            
            static var None         : AccessFlags { return AccessFlags(rawValue: 0x0000) }
            static var Final        : AccessFlags { return AccessFlags(rawValue: 0x0010) }
            static var Synthetic    : AccessFlags { return AccessFlags(rawValue: 0x1000) }
            static var Mandated     : AccessFlags { return AccessFlags(rawValue: 0x8000) }
        }
        let nameIndex: UInt16
        let accessFlags: AccessFlags
        // cached:
        let name: Utf8Constant
        init(data:Data, cursor: inout Int, constantPool: ConstantPool) {
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            accessFlags = AccessFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            name = constantPool[nameIndex] as! Utf8Constant
        }
    }
    let parametersCount: UInt8
    let parameters: [Parameter]
    init(header:Header, data:Data, cursor: inout Int, constantPool:ConstantPool) {
        parametersCount = readFromData(data, cursor: &cursor)
        var tempParamters = [Parameter]()
        for _ in 0..<parametersCount {
            let parameter = Parameter(data: data, cursor: &cursor, constantPool: constantPool)
            tempParamters.append(parameter)
        }
        parameters = tempParamters
        super.init(header: header)
    }
}

class ModuleAttribute: AttributeInfo {
    struct ModuleFlags: OptionSet {
        let rawValue: UInt16
        init(rawValue: UInt16) { self.rawValue = rawValue }
        
        static var None         : ModuleFlags { return ModuleFlags(rawValue: 0x0000) }
        static var Open         : ModuleFlags { return ModuleFlags(rawValue: 0x0020) }
        static var Synthetic    : ModuleFlags { return ModuleFlags(rawValue: 0x1000) }
        static var Mandated     : ModuleFlags { return ModuleFlags(rawValue: 0x8000) }
    }
    
    struct Requires {
        struct RequiresFlags: OptionSet {
            let rawValue: UInt16
            init(rawValue: UInt16) { self.rawValue = rawValue }
            
            static var None         : RequiresFlags { return RequiresFlags(rawValue: 0x0000) }
            static var Transitive   : RequiresFlags { return RequiresFlags(rawValue: 0x0020) }
            static var StaticPhase  : RequiresFlags { return RequiresFlags(rawValue: 0x0040) }
            static var Synthetic    : RequiresFlags { return RequiresFlags(rawValue: 0x1000) }
            static var Mandated     : RequiresFlags { return RequiresFlags(rawValue: 0x8000) }
        }
        
        let requiresIndex: UInt16
        let flags: RequiresFlags
        let versionIndex: UInt16
        // cached:
        let requires: ClassOrModuleOrPackageConstant
        let version: Utf8Constant
        init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
            requiresIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            flags = RequiresFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            versionIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            requires = constantPool[requiresIndex] as! ClassOrModuleOrPackageConstant
            version = constantPool[versionIndex] as! Utf8Constant
        }
    }
    
    struct ExportsOpens { // Exports and Opens have the same interface, they're just used differently
        struct ExportsOpensFlags: OptionSet {
            let rawValue: UInt16
            init(rawValue: UInt16) { self.rawValue = rawValue }
            
            static var None         : ExportsOpensFlags { return ExportsOpensFlags(rawValue: 0x0000) }
            static var Synthetic    : ExportsOpensFlags { return ExportsOpensFlags(rawValue: 0x1000) }
            static var Mandated     : ExportsOpensFlags { return ExportsOpensFlags(rawValue: 0x8000) }
        }

        let exportsOpensIndex: UInt16
        let exportsOpensFlags: ExportsOpensFlags
        let exportsOpensToCount: UInt16
        let exportsOpensToIndex: [UInt16]
        // cached:
        let exportsOpens: ClassOrModuleOrPackageConstant
        let exportsOpensTo: [ClassOrModuleOrPackageConstant]
        
        init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
            exportsOpensIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            exportsOpens = constantPool[exportsOpensIndex] as! ClassOrModuleOrPackageConstant
            exportsOpensFlags = ExportsOpensFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
            exportsOpensToCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempIndexes = [UInt16]()
            var tempExportsTo = [ClassOrModuleOrPackageConstant]()
            for _ in 0 ..< exportsOpensToCount {
                let index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                tempIndexes.append(index)
                tempExportsTo.append(constantPool[index] as! ClassOrModuleOrPackageConstant)
            }
            exportsOpensToIndex = tempIndexes
            exportsOpensTo = tempExportsTo
        }
    }
    struct Provides {
        let providesIndex: UInt16
        let providesWithCount: UInt16
        let providesWithIndex: [UInt16]
        // cached:
        let provides: ClassOrModuleOrPackageConstant
        let providesWith: [ClassOrModuleOrPackageConstant]
        
        init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
            providesIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            provides = constantPool[providesIndex] as! ClassOrModuleOrPackageConstant
            providesWithCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempIndexes = [UInt16]()
            var tempProvides = [ClassOrModuleOrPackageConstant]()
            for _ in 0 ..< providesWithCount {
                let index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
                tempIndexes.append(index)
                tempProvides.append(constantPool[index] as! ClassOrModuleOrPackageConstant)
            }
            providesWithIndex = tempIndexes
            providesWith = tempProvides
        }
    }

    
    let moduleNameIndex: UInt16
    let moduleFlags: ModuleFlags
    let moduleVersionIndex: UInt16
    
    let requiresCount: UInt16
    let requires: [Requires]
    
    let exportsCount: UInt16
    let exports: [ExportsOpens]
    
    let opensCount: UInt16
    let opens: [ExportsOpens]
    
    let usesCount: UInt16
    let usesIndex: [UInt16]
    
    let providesCount: UInt16
    let provides: [Provides]
    // Cached
    let moduleName: String
    let moduleVersion: String
    let uses: [ClassOrModuleOrPackageConstant]
    init(header:Header, data:Data, cursor: inout Int, constantPool: ConstantPool) {
        moduleNameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        moduleName = (constantPool[moduleNameIndex] as! Utf8Constant).string as String
        moduleFlags = ModuleFlags(rawValue: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        moduleVersionIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        moduleVersion = (constantPool[moduleVersionIndex] as! Utf8Constant).string as String
        requiresCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempRequires = [Requires]()
        for _ in 0..<requiresCount {
            tempRequires.append(Requires(data: data, cursor: &cursor, constantPool: constantPool))
        }
        requires = tempRequires
        exportsCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempExports = [ExportsOpens]()
        for _ in 0..<exportsCount {
            tempExports.append(ExportsOpens(data: data, cursor: &cursor, constantPool: constantPool))
        }
        exports = tempExports
        opensCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempOpens = [ExportsOpens]()
        for _ in 0..<opensCount {
            tempOpens.append(ExportsOpens(data: data, cursor: &cursor, constantPool: constantPool))
        }
        opens = tempOpens
        usesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempUsesIndexes = [UInt16]()
        var tempUses = [ClassOrModuleOrPackageConstant]()
        for _ in 0..<usesCount {
            let tempIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            tempUsesIndexes.append(tempIndex)
            tempUses.append(constantPool[tempIndex] as! ClassOrModuleOrPackageConstant)
        }
        usesIndex = tempUsesIndexes
        uses = tempUses
        providesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempProvides = [Provides]()
        for _ in 0..<providesCount {
            tempProvides.append(Provides(data: data, cursor: &cursor, constantPool: constantPool))
        }
        provides = tempProvides
        super.init(header: header)
    }
}

class ModulePackagesAttribute: AttributeInfo {
    let packageCount: UInt16
    let packageIndex: [UInt16]
    // cached:
    let packages: [ClassOrModuleOrPackageConstant]
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        packageCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempIndexes = [UInt16]()
        var tempPackages = [ClassOrModuleOrPackageConstant]()
        for _ in 0..<packageCount {
            let index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            tempIndexes.append(index)
            tempPackages.append(constantPool[index] as! ClassOrModuleOrPackageConstant)
        }
        packageIndex = tempIndexes
        packages = tempPackages
        super.init(header: header)
    }
}

class ModuleMainClassAttribute: AttributeInfo {
    let mainClassIndex: UInt16
    // cached:
    let mainClass: ClassOrModuleOrPackageConstant
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        mainClassIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        mainClass = constantPool[mainClassIndex] as! ClassOrModuleOrPackageConstant
        super.init(header: header)
    }
}
class NestHostAttribute: AttributeInfo {
    let hostClassIndex: UInt16
    // cached:
    let hostClass: ClassOrModuleOrPackageConstant
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        hostClassIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        hostClass = constantPool[hostClassIndex] as! ClassOrModuleOrPackageConstant
        super.init(header: header)
    }
}
class NestMembersAttribute: AttributeInfo {
    let numberOfClasses: UInt16
    let classesIndex: [UInt16] // internal name is classes. but it's actually indicies
    // cached:
    let classes: [ClassOrModuleOrPackageConstant]
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        numberOfClasses = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempIndexes = [UInt16]()
        var tempClasses = [ClassOrModuleOrPackageConstant]()
        for _ in 0..<numberOfClasses {
            let index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            tempIndexes.append(index)
            tempClasses.append(constantPool[index] as! ClassOrModuleOrPackageConstant)
        }
        classesIndex = tempIndexes
        classes = tempClasses
        super.init(header: header)
    }
}
class RecordAttribute: AttributeInfo {
    struct ComponentInfo {
        let nameIndex: UInt16
        let descriptorIndex: UInt16
        let attributesCount: UInt16
        let attributes: [AttributeInfo]
        // cached:
        let name: Utf8Constant
        let descriptor: Utf8Constant
        init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
            nameIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            name = constantPool[nameIndex] as! Utf8Constant
            descriptorIndex = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            descriptor = constantPool[descriptorIndex] as! Utf8Constant
            attributesCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var tempAttributes = [AttributeInfo]()
            for _ in 0..<attributesCount {
                tempAttributes.append(AttributeInfo.fromData(data, cursor: &cursor, constantPool: constantPool))
            }
            attributes = tempAttributes
        }
    }
    let componentsCount: UInt16
    let components: [ComponentInfo]
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        componentsCount = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempComponents = [ComponentInfo]()
        for _ in 0..<componentsCount {
            tempComponents.append(ComponentInfo(data: data, cursor: &cursor, constantPool: constantPool))
        }
        components = tempComponents
        super.init(header: header)
    }
}

class PermittedSubclassesAttribute: AttributeInfo {
    let numberOfClasses: UInt16
    let classesIndex: [UInt16] // internal name is classes. but it's actually indicies
    // cached:
    let classes: [ClassOrModuleOrPackageConstant]
    init(header: Header, data: Data, cursor: inout Int, constantPool: ConstantPool) {
        numberOfClasses = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
        var tempIndexes = [UInt16]()
        var tempClasses = [ClassOrModuleOrPackageConstant]()
        for _ in 0..<numberOfClasses {
            let index = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            tempIndexes.append(index)
            tempClasses.append(constantPool[index] as! ClassOrModuleOrPackageConstant)
        }
        classesIndex = tempIndexes
        classes = tempClasses
        super.init(header: header)
    }
}


class UnknownAttribute: AttributeInfo {
    let info : Data
    init(header:Header, data:Data, cursor:inout Int) {
        info = (data as NSData).subdata(with: NSMakeRange(cursor, Int(header.attributeLength)))
        cursor += Int(header.attributeLength)
        super.init(header: header)
    }
}
