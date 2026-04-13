//
//  Class.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/3/23.
//

import Foundation

class Class {
    let name: String
    let superclass: Class?
    let interfaces: [Class]
    let sourceFile: String?
    var fields: [Field] = []
    var methods: [MethodInfo] = [] // not actually sure this is necessary.
    
    let firstFieldIndex: UInt16
    let numTotalFields: UInt16
    var clinitNeedsToBeRun: Bool = false
    var clinit: MethodInfo? // this is definitely necessary
    
    init(classFile: ClassFile) {
        methods = classFile.methods
        let needsStaticCheck = classFile.majorVersion >= 51
        let needsNoArgsCheck = classFile.majorVersion >= 53
        for method in methods {
            if needsStaticCheck && method.accessFlags.rawValue & MethodInfo.AccessFlags.Static.rawValue == 0 { continue }
            if needsNoArgsCheck && method.descriptor.string != "()V" { continue }
            if method.name.string != "<clinit>" { continue }
            clinit = method
            clinitNeedsToBeRun = true
            break // really I should make sure there's not more than 1, but that might be handled by validation later.
        }
        name = classFile.className
        let superclassResult = Runtime.vm.findOrCreateClass(named: classFile.superclassName)
        switch superclassResult {
        case .success(let success):
            superclass = success
        case .failure(let error):
            print("Failed to find or create superclass named: \(classFile.superclassName), \(error)")
            superclass = nil
        }
    }
}

extension Class : Equatable, Hashable {
    static func == (lhs: Class, rhs: Class) -> Bool {
        lhs.name == rhs.name && lhs.superclass == rhs.superclass
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(superclass)
    }
}
