//
//  Class.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/3/23.
//

import Foundation

class Class {
    let classFile: ClassFile
    let name: String
    var superclass: Class?
    let interfaces: [Class]
    let sourceFile: String?
    var fields: [Field] = []
    var staticFields: [String: Value] = [:]
    var methods: [MethodInfo] = [] // not actually sure this is necessary.

    let firstFieldIndex: UInt16
    let numTotalFields: UInt16
    var clinitNeedsToBeRun: Bool = false
    var clinit: MethodInfo? // this is definitely necessary

    init(classFile: ClassFile) {
        self.classFile = classFile
        interfaces = []
        sourceFile = nil
        firstFieldIndex = 0
        numTotalFields = 0
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
        for field in classFile.fields {
            guard field.accessFlags.rawValue & FieldInfo.AccessFlags.Static.rawValue != 0 else { continue }
            let desc = field.descriptor.string as String
            let defaultValue: Value
            switch desc.first {
            case "J":        defaultValue = .long(0)
            case "F":        defaultValue = .float(0)
            case "D":        defaultValue = .double(0)
            case "L", "[":   defaultValue = .reference(nil)
            default:         defaultValue = .int(0)   // I B C S Z
            }
            staticFields[field.name.string as String] = defaultValue
        }
        // Superclass resolution is deferred to avoid calling back into VM
        // while VM itself is already being mutated (exclusive access violation).
        // VM.loadClass wires this up after preload returns.
        superclass = nil
    }

    func findStaticField(named name: String) -> FieldInfo? {
        classFile.fields.first {
            $0.accessFlags.rawValue & FieldInfo.AccessFlags.Static.rawValue != 0 &&
            $0.name.string as String == name
        }
    }

    /// Returns all instance (non-static) fields declared on this class and every
    /// superclass, walking the hierarchy bottom-up so subclass fields come first.
    /// Uses classFile.superclassName + findOrCreateClass at each step so the
    /// superclass chain is force-loaded even if the Class.superclass pointer is nil.
    func allInstanceFields() -> [FieldInfo] {
        var seen = Set<String>()
        var result: [FieldInfo] = []
        var current: Class? = self
        while let cls = current {
            for f in cls.classFile.fields
                where f.accessFlags.rawValue & FieldInfo.AccessFlags.Static.rawValue == 0
                   && seen.insert(f.name.string as String).inserted {
                result.append(f)
            }
            let superName = cls.classFile.superclassName
            guard !superName.isEmpty && superName != "java/lang/Object" else { break }
            if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                current = s
            } else { break }
        }
        return result
    }

    func findMethod(named name: String, descriptor: String) -> MethodInfo? {
        methods.first {
            $0.name.string as String == name &&
            $0.descriptor.string as String == descriptor
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
