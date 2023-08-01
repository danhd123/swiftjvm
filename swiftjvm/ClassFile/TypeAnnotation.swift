//
//  TypeAnnotation.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 7/27/23.
//

import Foundation

struct TypeAnnotation {
    enum TargetType : UInt8 {
        case genericClassOrInterface = 0x0
        case genericMethodOrConstructor = 0x1
        case extendsOrImplementsClause = 0x10
        case boundParameterOfGenericClassOrInterface = 0x11
        case boundParameterOfGenericMethodOrConstructor = 0x12
        case fieldOrRecordComponentDeclaration = 0x13
        case returnTypeOfMethodOrConstructedObject = 0x14
        case receiverTypeOfMethodOrConstructor = 0x15
        case formalParameterOfMethodConstructorOrLambda = 0x16
        case throwsClauseOfMethodOrConstructor = 0x17
        
        case localVariable = 0x40
        case resourceVariable = 0x41
        case exceptionParameter = 0x42
        case instanceOfExpression = 0x43
        case newExpression = 0x44
        case methodReferenceExpressionUsingNew = 0x45
        case methodReferenceExpressionUsingIdentifier = 0x46
        case castExpression = 0x47
        case argumentForGenericConstructorExpression = 0x48
        case argumentForGenericMethodInvocationExpression = 0x49
        case argumentForGenericConstructorInMethodReferenceExpressionUsingNew = 0x4A
        case argumentForGenericMethodInMethodReferencExpressioneUsingIdentifier = 0x4B
    }
    
    enum TargetInfo {
        case typeParameterTarget(UInt8)
        case supertypeTarget(UInt16)
        case typeParamterBoundTarget(UInt8, UInt8)
        case emptyTarget
        case formalParameterTarget(UInt8)
        case throwsTarget(UInt16)
        case localvarTarget(UInt16, [LocalVarEntry])
        case catchTarget(UInt16)
        case offsetTarget(UInt16)
        case typeArgumentTarget(UInt16, UInt8)
        struct LocalVarEntry {
            let startPC: UInt16
            let length: UInt16
            let index: UInt16
        }
    }
    struct TypePath {
        let pathLength: UInt8
        let path: [PathElement]
        
        struct PathElement {
            let typePathKind: TypePathKind
            let typeArgumentIndex: UInt8
            
            enum TypePathKind: UInt8 {
                case deeperInArray = 0
                case deeperInNested = 1
                case wildcardTypeArgument = 2
                case typeArgument = 3
            }
        }
        init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
            pathLength = readFromData(data, cursor: &cursor)
            var tempPath = [PathElement]()
            for _ in 0..<pathLength {
                let pathElement = PathElement(typePathKind: PathElement.TypePathKind(rawValue: readFromData(data, cursor: &cursor))!, typeArgumentIndex: readFromData(data, cursor: &cursor))
                tempPath.append(pathElement)
            }
            path = tempPath
        }
    }
    let targetType: TargetType
    let targetInfo: TargetInfo
    let targetPath: TypePath
    let annotation: AttributeInfo.Annotation
    init(data: Data, cursor: inout Int, constantPool: ConstantPool) {
        targetType = TargetType(rawValue: readFromData(data, cursor: &cursor))!
        switch targetType {
        case .genericClassOrInterface, .genericMethodOrConstructor:
            targetInfo = .typeParameterTarget(readFromData(data, cursor: &cursor))
        case .extendsOrImplementsClause:
            targetInfo = .supertypeTarget(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        case .boundParameterOfGenericClassOrInterface, .boundParameterOfGenericMethodOrConstructor:
            targetInfo = .typeParameterTarget(readFromData(data, cursor: &cursor))
        case .fieldOrRecordComponentDeclaration, .returnTypeOfMethodOrConstructedObject, .receiverTypeOfMethodOrConstructor:
            targetInfo = .emptyTarget
        case .formalParameterOfMethodConstructorOrLambda:
            targetInfo = .formalParameterTarget(readFromData(data, cursor: &cursor))
        case .throwsClauseOfMethodOrConstructor:
            targetInfo = .throwsTarget(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        case .localVariable, .resourceVariable:
            let localVarEntryCount: UInt16 = NSSwapBigShortToHost(readFromData(data, cursor: &cursor))
            var localVarEntries = [TargetInfo.LocalVarEntry]()
            for _ in 0..<localVarEntryCount {
                let localVarEntry = TargetInfo.LocalVarEntry(startPC: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)), length: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)), index: NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
                localVarEntries.append(localVarEntry)
            }
            targetInfo = .localvarTarget(localVarEntryCount, localVarEntries)
        case .exceptionParameter:
            targetInfo = .catchTarget(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        case .instanceOfExpression, .newExpression, .methodReferenceExpressionUsingNew, .methodReferenceExpressionUsingIdentifier:
            targetInfo = .offsetTarget(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)))
        case .castExpression, .argumentForGenericConstructorExpression, .argumentForGenericMethodInvocationExpression, .argumentForGenericConstructorInMethodReferenceExpressionUsingNew, .argumentForGenericMethodInMethodReferencExpressioneUsingIdentifier:
            targetInfo = .typeArgumentTarget(NSSwapBigShortToHost(readFromData(data, cursor: &cursor)), readFromData(data, cursor: &cursor))
        }
        targetPath = TypePath(data: data, cursor: &cursor, constantPool: constantPool)
        annotation = AttributeInfo.Annotation(data: data, cursor: &cursor, constantPool: constantPool)
    }
}
