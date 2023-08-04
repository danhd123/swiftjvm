//
//  StackFrame.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

struct Frame {
    let currentClass: ClassOrModuleOrPackageConstant
    let constantPool: ConstantPool
    let method: MethodInfo
    var localVariables: [LocalVariable]
    var operandStack: [Operand]
    
    init(classFile: ClassFile, constantPool: ConstantPool, method: MethodInfo, localVariables: [LocalVariable] = [], operandStack: [Operand] = []) {
        self.constantPool = constantPool
        self.localVariables = localVariables
        self.operandStack = operandStack
        self.currentClass = self.constantPool[classFile.thisClassIndex] as! ClassOrModuleOrPackageConstant
        self.method = method
        // TODO: figure out how to get the current method. might need to be passed in
    }
    func execute() {
        print("interpreter code goes here")
    }
}
