import Foundation

extension Frame {

    // MARK: - Object creation

    func executeNew(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
        else { fatalError("new: malformed constant pool at \(index)") }
        let className = classNameConst.string as String

        // ── Native: StringBuilder / StringBuffer ──────────────────────────────
        if className == "java/lang/StringBuilder" || className == "java/lang/StringBuffer" {
            push(.stringBuilder(StringBuilderBuffer()))
            return .continue
        }

        guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
            fatalError("new: class not found: \(className)")
        }
        if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
            cls.clinitNeedsToBeRun = false
            pc = lastInstructionStart
            return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
        }
        push(.reference(Object(clazz: cls)))
        return .continue
    }

    // MARK: - Exception throwing

    func executeAThrow() -> ExecutionResult {
        guard case .reference(let objOpt) = pop(), let obj = objOpt
        else { fatalError("athrow: NullPointerException — null reference thrown") }
        if let handlerPC = findExceptionHandler(at: lastInstructionStart, for: obj) {
            pc = handlerPC
            push(.reference(obj))
            return .continue   // handler found in this frame
        }
        return .thrown(.reference(obj))   // no local handler — unwind
    }

    // MARK: - Type checks

    func executeCheckCast(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
        else { fatalError("checkcast: malformed constant pool at \(index)") }
        let targetName = classNameConst.string as String
        let value = pop()
        switch value {
        case .reference(nil):
            push(value)   // null passes any checkcast per JVM spec
        case .reference(let obj?):
            if !isAssignableTo(obj, targetName: targetName) {
                fatalError("checkcast: ClassCastException — \(obj.clazz.name) cannot be cast to \(targetName)")
            }
            push(value)
        case .array:
            push(value)   // array cast: accept (no deep type check yet)
        case .stringBuilder:
            push(value)   // StringBuilder/StringBuffer — pass through
        default:
            fatalError("checkcast: unexpected value type on stack")
        }
        return .continue
    }

    func executeInstanceOf(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
        else { fatalError("instanceof: malformed constant pool at \(index)") }
        let targetName = classNameConst.string as String
        let value = pop()
        switch value {
        case .reference(nil):
            push(.int(0))   // null instanceof anything = false
        case .reference(let obj?):
            push(.int(isAssignableTo(obj, targetName: targetName) ? 1 : 0))
        case .array:
            push(.int(targetName.hasPrefix("[") ? 1 : 0))
        case .stringBuilder:
            let sbNames = ["java/lang/StringBuilder", "java/lang/StringBuffer",
                           "java/lang/Object", "java/lang/CharSequence", "java/lang/Appendable"]
            push(.int(sbNames.contains(targetName) ? 1 : 0))
        default:
            fatalError("instanceof: unexpected value type on stack")
        }
        return .continue
    }

    // MARK: - Exception handler lookup

    /// Searches this frame's exception table for a handler covering `throwPC`
    /// that matches `obj`'s type. Returns the handler PC if found, else nil.
    func findExceptionHandler(at throwPC: Int, for obj: Object) -> Int? {
        guard let table = codeAttribute?.exceptionTable else { return nil }
        for entry in table {
            guard throwPC >= Int(entry.startPC) && throwPC < Int(entry.endPC) else { continue }
            if entry.catchType == 0 { return Int(entry.handlerPC) }   // finally
            guard let classConst = constantPool[entry.catchType] as? ClassOrModuleOrPackageConstant,
                  let nameConst  = constantPool[classConst.nameIndex] as? Utf8Constant
            else { continue }
            if isAssignableTo(obj, targetName: nameConst.string as String) {
                return Int(entry.handlerPC)
            }
        }
        return nil
    }

    // MARK: - Type assignability

    func isAssignableTo(_ obj: Object, targetName: String) -> Bool {
        if targetName == "java/lang/Object" { return true }
        var cls: Class? = obj.clazz
        while let c = cls {
            if c.name == targetName { return true }
            for ifaceIdx in c.classFile.interfaceIndicies {
                if let ifaceConst = c.classFile.constantPool[ifaceIdx] as? ClassOrModuleOrPackageConstant,
                   let ifaceNameConst = c.classFile.constantPool[ifaceConst.nameIndex] as? Utf8Constant,
                   ifaceNameConst.string as String == targetName { return true }
            }
            let superName = c.classFile.superclassName
            guard !superName.isEmpty && superName != "java/lang/Object" else { break }
            if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) { cls = s }
            else { break }
        }
        return false
    }
}
