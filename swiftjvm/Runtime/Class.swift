//
//  Class.swift
//  swiftjvm
//

import Foundation

class Class {
    let classFile: ClassFile
    var clinitRun: Bool = false

    init(classFile: ClassFile) {
        self.classFile = classFile
    }

    // Internal JVM class name, e.g. "java/lang/String"
    var name: String {
        let classConstant = classFile.constantPool[classFile.thisClassIndex] as! ClassOrModuleOrPackageConstant
        let nameConstant = classFile.constantPool[classConstant.nameIndex] as! Utf8Constant
        return nameConstant.string as String
    }

    var methods: [MethodInfo] { classFile.methods }

    func findMethod(named name: String, descriptor: String) -> MethodInfo? {
        methods.first {
            $0.name.string as String == name &&
            $0.descriptor.string as String == descriptor
        }
    }
}
