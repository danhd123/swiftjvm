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
        // ── Native: StringBuilder / StringBuffer <init> ───────────────────────
        let sbClasses = ["java/lang/StringBuilder", "java/lang/StringBuffer"]
        if sbClasses.contains(className) && methodName == "<init>" {
            if case .stringBuilder(let sb) = thisValue {
                if !args.isEmpty {
                    switch args[0] {
                    case .string(let s): sb.content = s
                    case .int:           sb.content = ""   // capacity hint — ignore
                    default:             break
                    }
                }
            }
            return .continue
        }

        // No JDK stubs — treat <init> on the standard exception/Object hierarchy as no-ops.
        // If a String argument is present, save it as the exception's detailMessage.
        let jdkInitNoOps = ["java/lang/Object", "java/lang/Throwable",
                             "java/lang/Exception", "java/lang/RuntimeException",
                             "java/lang/Error", "java/lang/NullPointerException",
                             "java/lang/IllegalArgumentException",
                             "java/lang/IllegalStateException",
                             "java/lang/UnsupportedOperationException",
                             "java/lang/IndexOutOfBoundsException",
                             "java/lang/ArrayIndexOutOfBoundsException",
                             "java/lang/ClassCastException",
                             "java/lang/ArithmeticException",
                             "java/lang/StackOverflowError",
                             "java/lang/OutOfMemoryError"]
        if jdkInitNoOps.contains(className) && methodName == "<init>" {
            // Store the detail message if one was passed
            if !args.isEmpty, case .string(let msg) = args[0],
               case .reference(let objOpt) = thisValue, let obj = objOpt {
                obj.instanceFields["detailMessage"] = .string(msg)
            }
            return .continue
        }
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
                    case .stringBuilder(let sb): print(sb.content)
                    case .reference(let r?): print("\(r.clazz.name)@\(String(UInt(bitPattern: ObjectIdentifier(r)), radix: 16))")
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
                    case .stringBuilder(let sb): Swift.print(sb.content, terminator: "")
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

        // ── Native dispatch: java/lang/StringBuilder / StringBuffer ──────────
        if case .stringBuilder(let sb) = receiver {
            switch methodName {
            case "append":
                let text: String
                switch args[0] {
                case .string(let s):  text = s
                case .int(let i):
                    if descriptor == "(Z)Ljava/lang/StringBuilder;" ||
                       descriptor == "(Z)Ljava/lang/StringBuffer;" {
                        text = i != 0 ? "true" : "false"
                    } else if descriptor == "(C)Ljava/lang/StringBuilder;" ||
                              descriptor == "(C)Ljava/lang/StringBuffer;" {
                        text = String(Character(UnicodeScalar(UInt32(i))!))
                    } else {
                        text = String(i)
                    }
                case .long(let l):    text = String(l)
                case .float(let f):   text = String(f)
                case .double(let d):  text = String(d)
                case .reference(nil): text = "null"
                case .reference(let o?): text = "\(o.clazz.name)@\(String(UInt(bitPattern: ObjectIdentifier(o)), radix: 16))"
                case .stringBuilder(let sb2): text = sb2.content
                default:              text = "?"
                }
                sb.content += text
                push(.stringBuilder(sb))   // chaining: append returns `this`
            case "toString":
                push(.string(sb.content))
            case "length":
                push(.int(Int32(sb.content.count)))
            case "charAt":
                let idx = Int(args[0].asInt!)
                let c = sb.content[sb.content.index(sb.content.startIndex, offsetBy: idx)]
                push(.int(Int32(c.asciiValue ?? 0)))
            case "deleteCharAt":
                let idx = Int(args[0].asInt!)
                let i = sb.content.index(sb.content.startIndex, offsetBy: idx)
                sb.content.remove(at: i)
                push(.stringBuilder(sb))
            case "reverse":
                sb.content = String(sb.content.reversed())
                push(.stringBuilder(sb))
            case "insert":
                if args.count == 2, let offset = args[0].asInt {
                    let s: String
                    switch args[1] {
                    case .string(let sv): s = sv
                    case .int(let i):    s = String(i)
                    default:             s = "?"
                    }
                    let i = sb.content.index(sb.content.startIndex, offsetBy: Int(offset))
                    sb.content.insert(contentsOf: s, at: i)
                }
                push(.stringBuilder(sb))
            case "delete":
                if args.count == 2, let start = args[0].asInt, let end = args[1].asInt {
                    let si = sb.content.index(sb.content.startIndex, offsetBy: Int(start))
                    let ei = sb.content.index(sb.content.startIndex, offsetBy: Int(end))
                    sb.content.removeSubrange(si..<ei)
                }
                push(.stringBuilder(sb))
            case "substring":
                let start = Int(args[0].asInt!)
                let si = sb.content.index(sb.content.startIndex, offsetBy: start)
                if args.count == 2 {
                    let end = Int(args[1].asInt!)
                    let ei = sb.content.index(sb.content.startIndex, offsetBy: end)
                    push(.string(String(sb.content[si..<ei])))
                } else {
                    push(.string(String(sb.content[si...])))
                }
            default:
                fatalError("invokevirtual: unsupported StringBuilder method: \(methodName)\(descriptor)")
            }
            return .continue
        }

        // ── Virtual dispatch on user-defined classes ───────────────────────────
        guard let objOptional = receiver.asReference else {
            fatalError("invokevirtual: expected reference on stack for \(methodName)")
        }
        guard let obj = objOptional else {
            fatalError("invokevirtual: NullPointerException — null receiver for \(methodName)")
        }
        if let (calleeMethod, calleeClass) = virtualLookup(startClass: obj.clazz,
                                                            methodName: methodName,
                                                            descriptor: descriptor) {
            return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                        arguments: [receiver] + args))
        }

        // ── Native fallback: exception / Object methods ────────────────────────
        let msg: String? = {
            if case .string(let s) = obj.instanceFields["detailMessage"] { return s }
            return nil
        }()
        switch methodName {
        case "getMessage", "getLocalizedMessage":
            if let m = msg { push(.string(m)) } else { push(.reference(nil)) }
        case "toString":
            let repr = msg.map { "\(obj.clazz.name): \($0)" } ?? obj.clazz.name
            push(.string(repr))
        case "hashCode":
            push(.int(Int32(truncatingIfNeeded: ObjectIdentifier(obj).hashValue)))
        case "equals":
            if case .reference(let other) = args[0] { push(.int(obj === other ? 1 : 0)) }
            else { push(.int(0)) }
        case "printStackTrace":
            let repr = msg.map { "\(obj.clazz.name): \($0)" } ?? obj.clazz.name
            fputs("\(repr)\n", stderr)
        default:
            fatalError("invokevirtual: method not found: \(methodName)\(descriptor) in \(obj.clazz.name)")
        }
        return .continue
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

        // ── Native: java/lang/System static methods ──────────────────────────
        if className == "java/lang/System" {
            switch (methodName, descriptor) {
            case ("exit", "(I)V"):
                exit(args.isEmpty ? 0 : args[0].asInt!)
            default:
                fatalError("invokestatic: unsupported System method: \(methodName)\(descriptor)")
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

    // MARK: - invokedynamic

    func executeInvokeDynamic(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        pc += 2  // skip two reserved zero bytes

        guard let invokeDyn   = constantPool[index] as? InvokeDynamicConstant,
              let nameAndType = constantPool[invokeDyn.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst   = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst   = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else { fatalError("invokedynamic: malformed constant pool at \(index)") }

        let methodName = nameConst.string as String
        let descriptor = descConst.string as String

        guard methodName == "makeConcatWithConstants" || methodName == "makeConcat" else {
            fatalError("invokedynamic: unsupported bootstrap: \(methodName)")
        }

        let argCount = parseArgumentCount(descriptor: descriptor)
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()

        // makeConcat: concatenate all dynamic args in order (no recipe needed)
        if methodName == "makeConcat" {
            push(.string(args.map { valueToString($0) }.joined()))
            return .continue
        }

        // makeConcatWithConstants: follow the recipe in bootstrap arg[0]
        let bsmIdx = Int(invokeDyn.bootstrapMethodAttrIndex)
        guard let bsma = owningClass.classFile.attributes.first(where: { $0 is BootstrapMethodsAttribute })
                         as? BootstrapMethodsAttribute,
              bsmIdx < bsma.bootstrapMethods.count
        else { fatalError("invokedynamic: missing BootstrapMethods attribute") }

        let bm = bsma.bootstrapMethods[bsmIdx]
        guard !bm.bootstrapArguments.isEmpty,
              let strRef = bm.bootstrapArguments[0] as? StringRefConstant,
              let recipeUtf8 = constantPool[strRef.stringIndex] as? Utf8Constant
        else { fatalError("invokedynamic: cannot resolve recipe from bootstrap arg[0]") }

        let recipe = recipeUtf8.string as String

        // Build the concatenated result from the recipe:
        //   \u0001 → next dynamic argument
        //   \u0002 → next static bootstrap constant (beyond the recipe itself)
        //   other  → literal character
        var result = ""
        var dynIdx   = 0
        var constIdx = 1   // bm.bootstrapArguments[0] is the recipe; [1+] are extra constants
        for scalar in recipe.unicodeScalars {
            switch scalar.value {
            case 1:   // dynamic arg placeholder
                if dynIdx < args.count { result += valueToString(args[dynIdx]); dynIdx += 1 }
            case 2:   // static bootstrap constant placeholder
                if constIdx < bm.bootstrapArguments.count,
                   let sc  = bm.bootstrapArguments[constIdx] as? StringRefConstant,
                   let utf = constantPool[sc.stringIndex] as? Utf8Constant {
                    result += utf.string as String; constIdx += 1
                }
            default:
                result.append(Character(scalar))
            }
        }
        push(.string(result))
        return .continue
    }

    /// Converts any JVM Value to its Java String.valueOf() equivalent.
    private func valueToString(_ v: Value) -> String {
        switch v {
        case .int(let i):        return String(i)
        case .long(let l):       return String(l)
        case .float(let f):      return String(f)
        case .double(let d):     return String(d)
        case .string(let s):     return s
        case .reference(nil):    return "null"
        case .reference(let o?): return "\(o.clazz.name)@\(String(UInt(bitPattern: ObjectIdentifier(o)), radix: 16))"
        case .array:             return "[array]"
        case .stringBuilder(let sb): return sb.content
        default:                 return "?"
        }
    }
}
