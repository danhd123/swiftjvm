import Foundation

extension Frame {

    // MARK: - Static fields

    func executeGetStatic(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[fieldRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
        else { fatalError("getstatic: malformed constant pool at index") }
        let className = classNameConst.string as String
        let fieldName = nameConst.string as String
        // Native stub: java/lang/System.out → PrintStream sentinel.
        if className == "java/lang/System" && fieldName == "out" {
            push(.printStream)
            return .continue
        }
        guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
            fatalError("getstatic: class not found: \(className)")
        }
        if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
            cls.clinitNeedsToBeRun = false
            pc = lastInstructionStart   // re-execute getstatic after clinit
            return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
        }
        guard let value = cls.staticFields[fieldName] else {
            fatalError("getstatic: field not found: \(fieldName) in \(className)")
        }
        push(value)
        return .continue
    }

    func executePutStatic(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[fieldRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
        else { fatalError("putstatic: malformed constant pool at index") }
        let className = classNameConst.string as String
        let fieldName = nameConst.string as String
        guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
            fatalError("putstatic: class not found: \(className)")
        }
        if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
            cls.clinitNeedsToBeRun = false
            pc = lastInstructionStart
            return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
        }
        cls.staticFields[fieldName] = pop()
        return .continue
    }

    // MARK: - Instance fields

    func executeGetField(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        // classIndex is intentionally unused: field lookup is by name via
        // obj.instanceFields, keyed at Object init time — declaring class not needed.
        guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
              let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
        else { fatalError("getfield: malformed constant pool at index") }
        let fieldName = nameConst.string as String
        guard let objOptional = pop().asReference else {
            fatalError("getfield: expected reference on stack for field \(fieldName)")
        }
        guard let obj = objOptional else {
            fatalError("getfield: NullPointerException — null objectref for field \(fieldName)")
        }
        guard let value = obj.instanceFields[fieldName] else {
            fatalError("getfield: field not found: \(fieldName) in \(obj.clazz.name)")
        }
        push(value)
        return .continue
    }

    func executePutField(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)
        guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
              let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
        else { fatalError("putfield: malformed constant pool at index") }
        let fieldName = nameConst.string as String
        let value = pop()
        guard let objOptional = pop().asReference else {
            fatalError("putfield: expected reference on stack for field \(fieldName)")
        }
        guard let obj = objOptional else {
            fatalError("putfield: NullPointerException — null objectref for field \(fieldName)")
        }
        obj.instanceFields[fieldName] = value
        return .continue
    }
}
