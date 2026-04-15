import Foundation

extension Frame {

    // MARK: - invokespecial

    func executeInvokeSpecial(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else { fatalError("invokespecial: malformed constant pool at index") }
        let className  = classNameConst.string as String
        let methodName = nameConst.string as String
        let descriptor = descConst.string as String
        let argCount   = parseArgumentCount(descriptor: descriptor)
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
        let thisValue = pop()
        // No JDK stubs — treat <init> on the standard exception/Object hierarchy as no-ops.
        let jdkInitNoOps = ["java/lang/Object", "java/lang/Throwable",
                             "java/lang/Exception", "java/lang/RuntimeException", "java/lang/Error"]
        if jdkInitNoOps.contains(className) && methodName == "<init>" { return .continue }
        guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
            fatalError("invokespecial: class not found: \(className)")
        }
        // Walk the superclass chain from the resolved class upward.
        var calleeMethod: MethodInfo?
        var calleeClass: Class?
        var searchCls: Class? = cls
        while let c = searchCls {
            if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                calleeMethod = m; calleeClass = c; break
            }
            let superName = c.classFile.superclassName
            guard !superName.isEmpty && superName != "java/lang/Object" else { break }
            if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) { searchCls = s }
            else { break }
        }
        guard let calleeMethod, let calleeClass else {
            fatalError("invokespecial: method not found: \(methodName)\(descriptor) in \(className)")
        }
        return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                    arguments: [thisValue] + args))
    }

    // MARK: - invokevirtual

    func executeInvokeVirtual(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else { fatalError("invokevirtual: malformed constant pool at index") }
        let className  = classNameConst.string as String
        let methodName = nameConst.string as String
        let descriptor = descConst.string as String
        let argCount   = parseArgumentCount(descriptor: descriptor)
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
        let receiver = pop()

        // ── Native dispatch: java/io/PrintStream ──────────────────────────────
        if case .printStream = receiver {
            guard className == "java/io/PrintStream" || className == "java/io/FilterOutputStream"
            else { fatalError("invokevirtual: unexpected receiver class \(className) on PrintStream") }
            switch methodName {
            case "println":
                if args.isEmpty {
                    print("")
                } else {
                    switch args[0] {
                    case .string(let s):  print(s)
                    case .int(let i):
                        if descriptor == "(Z)V" { print(i != 0 ? "true" : "false") }
                        else                    { print(i) }
                    case .long(let l):    print(l)
                    case .float(let f):   print(f)
                    case .double(let d):  print(d)
                    case .reference(let r) where r == nil: print("null")
                    default: fatalError("invokevirtual: println: unsupported argument type \(args[0])")
                    }
                }
            case "print":
                if !args.isEmpty {
                    switch args[0] {
                    case .string(let s):  Swift.print(s, terminator: "")
                    case .int(let i):     Swift.print(i, terminator: "")
                    case .long(let l):    Swift.print(l, terminator: "")
                    case .float(let f):   Swift.print(f, terminator: "")
                    case .double(let d):  Swift.print(d, terminator: "")
                    default: fatalError("invokevirtual: print: unsupported argument type \(args[0])")
                    }
                }
            default:
                fatalError("invokevirtual: unsupported PrintStream method: \(methodName)\(descriptor)")
            }
            return .continue
        }

        // ── Native dispatch: java/lang/String ─────────────────────────────────
        if case .string(let s) = receiver {
            let result = executeStringMethod(methodName: methodName, descriptor: descriptor,
                                             receiver: s, args: args)
            if let result { push(result) }
            return .continue
        }

        // ── Virtual dispatch on user-defined classes ───────────────────────────
        guard let objOptional = receiver.asReference else {
            fatalError("invokevirtual: expected reference on stack for \(methodName)")
        }
        guard let obj = objOptional else {
            fatalError("invokevirtual: NullPointerException — null receiver for \(methodName)")
        }
        guard let (calleeMethod, calleeClass) = virtualLookup(startClass: obj.clazz,
                                                               methodName: methodName,
                                                               descriptor: descriptor) else {
            fatalError("invokevirtual: method not found: \(methodName)\(descriptor) in \(obj.clazz.name)")
        }
        return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                    arguments: [receiver] + args))
    }

    // MARK: - invokeinterface

    func executeInvokeInterface(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        pc += 2  // skip count byte and trailing 0
        guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
              let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else { fatalError("invokeinterface: malformed constant pool at index") }
        let methodName = nameConst.string as String
        let descriptor = descConst.string as String
        let argCount   = parseArgumentCount(descriptor: descriptor)
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
        let receiver = pop()
        guard let objOptional = receiver.asReference else {
            fatalError("invokeinterface: expected reference on stack for \(methodName)")
        }
        guard let obj = objOptional else {
            fatalError("invokeinterface: NullPointerException — null receiver for \(methodName)")
        }
        guard let (calleeMethod, calleeClass) = virtualLookup(startClass: obj.clazz,
                                                               methodName: methodName,
                                                               descriptor: descriptor) else {
            fatalError("invokeinterface: method not found: \(methodName)\(descriptor) in \(obj.clazz.name)")
        }
        return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                    arguments: [receiver] + args))
    }

    // MARK: - invokestatic

    func executeInvokeStatic(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else { fatalError("invokestatic: malformed constant pool entry") }
        let className  = classNameConst.string as String
        let methodName = nameConst.string as String
        let descriptor = descConst.string as String
        let argCount   = parseArgumentCount(descriptor: descriptor)
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()

        // ── Native: java/lang/String static methods ───────────────────────────
        if className == "java/lang/String" {
            switch (methodName, descriptor) {
            case ("valueOf", "(I)Ljava/lang/String;"):
                push(.string(String(args[0].asInt!))); return .continue
            case ("valueOf", "(J)Ljava/lang/String;"):
                push(.string(String(args[0].asLong!))); return .continue
            case ("valueOf", "(F)Ljava/lang/String;"):
                push(.string(String(args[0].asFloat!))); return .continue
            case ("valueOf", "(D)Ljava/lang/String;"):
                push(.string(String(args[0].asDouble!))); return .continue
            case ("valueOf", "(Z)Ljava/lang/String;"):
                push(.string(args[0].asInt! != 0 ? "true" : "false")); return .continue
            case ("valueOf", "(C)Ljava/lang/String;"):
                let c = Character(UnicodeScalar(UInt32(args[0].asInt!))!)
                push(.string(String(c))); return .continue
            case ("valueOf", _):
                if case .string(let s) = args[0] { push(.string(s)) }
                else { push(.string("null")) }
                return .continue
            default:
                fatalError("invokestatic: unsupported String method: \(methodName)\(descriptor)")
            }
        }

        // ── Native: java/lang/Integer static methods ──────────────────────────
        if className == "java/lang/Integer" {
            switch (methodName, descriptor) {
            case ("parseInt", "(Ljava/lang/String;)I"):
                guard case .string(let s) = args[0], let i = Int32(s)
                else { fatalError("invokestatic: Integer.parseInt: not a number") }
                push(.int(i)); return .continue
            case ("toString", "(I)Ljava/lang/String;"):
                push(.string(String(args[0].asInt!))); return .continue
            case ("valueOf", "(I)Ljava/lang/Integer;"):
                push(args[0]); return .continue   // boxed int — treat as primitive
            default:
                fatalError("invokestatic: unsupported Integer method: \(methodName)\(descriptor)")
            }
        }

        guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
            fatalError("invokestatic: class not found: \(className)")
        }
        guard let calleeMethod = cls.findMethod(named: methodName, descriptor: descriptor) else {
            fatalError("invokestatic: method not found: \(methodName)\(descriptor) in \(className)")
        }
        return .invoke(frame: Frame(owningClass: cls, method: calleeMethod, arguments: args))
    }

    // MARK: - Virtual dispatch helper

    /// Walks the superclass chain starting at `startClass` looking for `methodName`+`descriptor`.
    /// Returns (method, declaringClass) if found.
    private func virtualLookup(startClass: Class, methodName: String,
                                descriptor: String) -> (MethodInfo, Class)? {
        var searchCls: Class? = startClass
        while let c = searchCls {
            if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                return (m, c)
            }
            let superName = c.classFile.superclassName
            guard !superName.isEmpty && superName != "java/lang/Object" else { break }
            if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) { searchCls = s }
            else { break }
        }
        return nil
    }
}
