//
//  Frame.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

// MARK: - ExecutionResult

/// Returned by each call to `executeNextInstruction()` so that `Thread.execute()`
/// can manage the frame stack without Frame holding a back-reference to Thread.
enum ExecutionResult {
    /// Execution continues in the current frame.
    case `continue`
    /// The current method returned. Pop the frame; if `value` is non-nil and there
    /// is a caller frame, push the value onto the caller's operand stack.
    case returned(Value?)
    /// Push `frame` onto the thread's frame stack and continue execution there.
    case invoke(frame: Frame)
    /// An exception was thrown and no handler was found in the current frame.
    /// Thread.execute() should unwind frames until a handler is found.
    case thrown(Value)
}

// MARK: - Argument count parsing

/// Returns the number of arguments encoded in a JVM method descriptor.
///
///     "(II)I"                  → 2
///     "([Ljava/lang/String;)V" → 1
///     "()V"                   → 0
func parseArgumentCount(descriptor: String) -> Int {
    var count = 0
    var chars = descriptor.dropFirst() // drop leading '('
    while let c = chars.first, c != ")" {
        chars = chars.dropFirst()
        switch c {
        case "L":
            count += 1
            // skip over the fully-qualified class name up to and including ';'
            while let inner = chars.first, inner != ";" { chars = chars.dropFirst() }
            chars = chars.dropFirst() // drop ';'
        case "[":
            // array-type prefix: the enclosed element type will be counted as the argument
            continue
        default:
            count += 1 // primitive: B C D F I J S Z
        }
    }
    return count
}

// MARK: - Frame

class Frame {
    let owningClass: Class
    let constantPool: ConstantPool
    let method: MethodInfo
    var localVariables: [LocalVariable]
    var operandStack: [Value] = []
    var pc: Int = 0
    /// PC of the most recently started instruction — used by Thread to locate
    /// the right exception-table range when unwinding into this frame.
    var lastInstructionStart: Int = 0

    var codeAttribute: CodeAttribute? {
        method.attributes.first { $0 is CodeAttribute } as? CodeAttribute
    }

    /// Creates a frame ready for execution.  `arguments` are placed into local
    /// variable slots starting at 0, honouring the JVM 2-slot rule: category-2
    /// types (long, double) occupy two consecutive slots, with a `.placeholder`
    /// written into the upper slot.  Remaining slots (up to `maxLocals`) are nil.
    init(owningClass: Class, method: MethodInfo, arguments: [Value] = []) {
        self.owningClass = owningClass
        self.constantPool = owningClass.classFile.constantPool
        self.method = method
        let maxLocals = Int(
            (method.attributes.first { $0 is CodeAttribute } as? CodeAttribute)?.maxLocals ?? 0
        )
        // Build the local variable array, inserting placeholder upper slots for
        // category-2 arguments so that slot indices match what javac generates.
        var slots: [LocalVariable] = []
        for arg in arguments {
            slots.append(LocalVariable(arg))
            switch arg {
            case .long, .double:
                slots.append(LocalVariable(.placeholder))
            default:
                break
            }
        }
        let count = max(maxLocals, slots.count)
        while slots.count < count { slots.append(LocalVariable()) }
        self.localVariables = slots
    }

    // MARK: - Operand stack helpers

    func push(_ v: Value) { operandStack.append(v) }

    @discardableResult
    func pop() -> Value { operandStack.removeLast() }

    func peek() -> Value { operandStack.last! }

    // MARK: - Local variable helpers

    private func pushLocal(_ idx: Int) {
        guard idx < localVariables.count, let v = localVariables[idx].value else {
            fatalError("Load from uninitialized local variable \(idx)")
        }
        if case .placeholder = v {
            fatalError("Loaded category-2 upper slot at local variable \(idx)")
        }
        push(v)
    }

    private func setLocal(_ idx: Int, _ value: Value) {
        while localVariables.count <= idx { localVariables.append(LocalVariable()) }
        localVariables[idx] = LocalVariable(value)
    }

    /// Store a category-2 value (long or double) at `index` and write a
    /// `.placeholder` sentinel into `index + 1` to catch accidental loads.
    private func storeWide(_ value: Value, at index: Int) {
        setLocal(index, value)
        setLocal(index + 1, .placeholder)
    }

    // MARK: - Branch helper

    /// Reads the 2-byte signed branch offset from `code` at the current `pc`,
    /// then — if `condition` is true — sets `pc` to `instructionStart + offset`.
    /// Always returns `.continue`.
    private func readBranchOffset(code: Data) -> Int {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        return Int(Int16(bitPattern: UInt16(hi << 8 | lo)))
    }

    // MARK: - Instruction dispatch

    func executeNextInstruction() -> ExecutionResult {
        guard let codeAttr = codeAttribute else {
            fatalError("Frame.executeNextInstruction: method '\(method.name.string)' has no Code attribute")
        }
        let code = codeAttr.code
        let instructionStart = pc
        lastInstructionStart = pc
        let rawOpcode: UInt8 = code[pc]; pc += 1

        guard let opcode = BytecodeInstruction.Opcode(rawValue: rawOpcode) else {
            fatalError("Unknown opcode 0x\(String(rawOpcode, radix: 16)) at pc \(instructionStart) in \(method.name.string)")
        }

        switch opcode {

        // ── nop ──────────────────────────────────────────────────────────────
        case .nop:
            return .continue

        // ── integer constants ─────────────────────────────────────────────────
        case .iconst_m1: push(.int(-1)); return .continue
        case .iconst_0:  push(.int( 0)); return .continue
        case .iconst_1:  push(.int( 1)); return .continue
        case .iconst_2:  push(.int( 2)); return .continue
        case .iconst_3:  push(.int( 3)); return .continue
        case .iconst_4:  push(.int( 4)); return .continue
        case .iconst_5:  push(.int( 5)); return .continue

        case .bipush:
            let byte = Int8(bitPattern: code[pc]); pc += 1
            push(.int(Int32(byte)))
            return .continue

        case .sipush:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            push(.int(Int32(Int16(bitPattern: UInt16(hi << 8 | lo)))))
            return .continue

        // ── integer loads ─────────────────────────────────────────────────────
        case .iload:
            let idx = Int(code[pc]); pc += 1
            pushLocal(idx)
            return .continue

        case .iload_0: pushLocal(0); return .continue
        case .iload_1: pushLocal(1); return .continue
        case .iload_2: pushLocal(2); return .continue
        case .iload_3: pushLocal(3); return .continue

        // ── integer stores ────────────────────────────────────────────────────
        case .istore:
            let idx = Int(code[pc]); pc += 1
            setLocal(idx, pop())
            return .continue

        case .istore_0: setLocal(0, pop()); return .continue
        case .istore_1: setLocal(1, pop()); return .continue
        case .istore_2: setLocal(2, pop()); return .continue
        case .istore_3: setLocal(3, pop()); return .continue

        // ── integer arithmetic ────────────────────────────────────────────────
        case .iadd:
            let b = pop().asInt!, a = pop().asInt!
            push(.int(a &+ b)); return .continue

        case .isub:
            let b = pop().asInt!, a = pop().asInt!
            push(.int(a &- b)); return .continue

        case .imul:
            let b = pop().asInt!, a = pop().asInt!
            push(.int(a &* b)); return .continue

        case .idiv:
            let b = pop().asInt!, a = pop().asInt!
            guard b != 0 else { fatalError("idiv: ArithmeticException / by zero") }
            push(.int(a / b)); return .continue

        case .irem:
            let b = pop().asInt!, a = pop().asInt!
            guard b != 0 else { fatalError("irem: ArithmeticException / by zero") }
            push(.int(a % b)); return .continue

        case .ineg:
            push(.int(0 &- pop().asInt!)); return .continue

        // ── stack manipulation ────────────────────────────────────────────────
        case .pop:
            _ = pop(); return .continue

        case .dup:
            push(peek()); return .continue

        // ── integer compare-and-branch (against 0) ────────────────────────────
        case .ifeq:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v == 0 { pc = instructionStart + offset }
            return .continue

        case .ifne:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v != 0 { pc = instructionStart + offset }
            return .continue

        case .iflt:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v < 0 { pc = instructionStart + offset }
            return .continue

        case .ifge:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v >= 0 { pc = instructionStart + offset }
            return .continue

        case .ifgt:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v > 0 { pc = instructionStart + offset }
            return .continue

        case .ifle:
            let v = pop().asInt!
            let offset = readBranchOffset(code: code)
            if v <= 0 { pc = instructionStart + offset }
            return .continue

        // ── integer compare-and-branch (two operands) ─────────────────────────
        case .if_icmpeq:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a == b { pc = instructionStart + offset }
            return .continue

        case .if_icmpne:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a != b { pc = instructionStart + offset }
            return .continue

        case .if_icmplt:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a < b { pc = instructionStart + offset }
            return .continue

        case .if_icmpge:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a >= b { pc = instructionStart + offset }
            return .continue

        case .if_icmpgt:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a > b { pc = instructionStart + offset }
            return .continue

        case .if_icmple:
            let b = pop().asInt!, a = pop().asInt!
            let offset = readBranchOffset(code: code)
            if a <= b { pc = instructionStart + offset }
            return .continue

        // ── reference-null branches ───────────────────────────────────────────
        case .ifnull:
            let offset = readBranchOffset(code: code)
            let ref = pop()
            if case .reference(let r) = ref, r == nil { pc = instructionStart + offset }
            else if case .array(_) = ref { /* non-null array — don't branch */ }
            return .continue

        case .ifnonnull:
            let offset = readBranchOffset(code: code)
            let ref = pop()
            if case .reference(let r) = ref, r != nil { pc = instructionStart + offset }
            else if case .array(_) = ref { pc = instructionStart + offset }
            return .continue

        // ── unconditional branch ──────────────────────────────────────────────
        case .goto:
            let offset = readBranchOffset(code: code)
            pc = instructionStart + offset
            return .continue

        // ── return ────────────────────────────────────────────────────────────
        case .return:
            return .returned(nil)

        case .ireturn:
            return .returned(pop())

        // ── int bitwise ───────────────────────────────────────────────────────
        case .iand:
            let b = pop().asInt!, a = pop().asInt!; push(.int(a & b)); return .continue
        case .ior:
            let b = pop().asInt!, a = pop().asInt!; push(.int(a | b)); return .continue
        case .ixor:
            let b = pop().asInt!, a = pop().asInt!; push(.int(a ^ b)); return .continue

        // ── int shifts (count masked to 5 bits per JVM spec) ─────────────────
        case .ishl:
            let count = pop().asInt! & 0x1f; let value = pop().asInt!
            push(.int(value << count)); return .continue
        case .ishr:
            let count = pop().asInt! & 0x1f; let value = pop().asInt!
            push(.int(value >> count)); return .continue
        case .iushr:
            let count = pop().asInt! & 0x1f; let value = pop().asInt!
            push(.int(Int32(bitPattern: UInt32(bitPattern: value) >> UInt32(count))))
            return .continue

        // ── long bitwise ──────────────────────────────────────────────────────
        case .land:
            let b = pop().asLong!, a = pop().asLong!; push(.long(a & b)); return .continue
        case .lor:
            let b = pop().asLong!, a = pop().asLong!; push(.long(a | b)); return .continue
        case .lxor:
            let b = pop().asLong!, a = pop().asLong!; push(.long(a ^ b)); return .continue

        // ── long shifts (count is Int32, masked to 6 bits per JVM spec) ──────
        case .lshl:
            let count = Int64(pop().asInt! & 0x3f); let value = pop().asLong!
            push(.long(value << count)); return .continue
        case .lshr:
            let count = Int64(pop().asInt! & 0x3f); let value = pop().asLong!
            push(.long(value >> count)); return .continue
        case .lushr:
            let count = UInt64(pop().asInt! & 0x3f); let value = pop().asLong!
            push(.long(Int64(bitPattern: UInt64(bitPattern: value) >> count)))
            return .continue

        // ── reference loads ───────────────────────────────────────────────────
        case .aconst_null:
            push(.reference(nil)); return .continue
        case .aload:
            let idx = Int(code[pc]); pc += 1
            pushLocal(idx)
            return .continue
        case .aload_0: pushLocal(0); return .continue
        case .aload_1: pushLocal(1); return .continue
        case .aload_2: pushLocal(2); return .continue
        case .aload_3: pushLocal(3); return .continue

        // ── reference stores ──────────────────────────────────────────────────
        case .astore:
            let idx = Int(code[pc]); pc += 1
            setLocal(idx, pop())
            return .continue
        case .astore_0: setLocal(0, pop()); return .continue
        case .astore_1: setLocal(1, pop()); return .continue
        case .astore_2: setLocal(2, pop()); return .continue
        case .astore_3: setLocal(3, pop()); return .continue

        // ── reference return ──────────────────────────────────────────────────
        case .areturn:
            return .returned(pop())

        // ── static fields ─────────────────────────────────────────────────────
        case .getstatic:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let classConst = constantPool[fieldRef.classIndex] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("getstatic: malformed constant pool at \(index)") }
            let className = classNameConst.string as String
            let fieldName = nameConst.string as String
            // Native stub: java/lang/System.out → PrintStream sentinel.
            // No JDK class files are available, so we handle this directly.
            if className == "java/lang/System" && fieldName == "out" {
                push(.printStream)
                return .continue
            }
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("getstatic: class not found: \(className)")
            }
            if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
                cls.clinitNeedsToBeRun = false
                pc -= 3
                return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
            }
            guard let value = cls.staticFields[fieldName] else {
                fatalError("getstatic: field not found: \(fieldName) in \(className)")
            }
            push(value)
            return .continue

        case .putstatic:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let classConst = constantPool[fieldRef.classIndex] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("putstatic: malformed constant pool at \(index)") }
            let className = classNameConst.string as String
            let fieldName = nameConst.string as String
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("putstatic: class not found: \(className)")
            }
            if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
                cls.clinitNeedsToBeRun = false
                pc -= 3
                return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
            }
            cls.staticFields[fieldName] = pop()
            return .continue

        // ── object creation ───────────────────────────────────────────────────
        case .new:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
            else { fatalError("new: malformed constant pool at \(index)") }
            let className = classNameConst.string as String
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("new: class not found: \(className)")
            }
            if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
                cls.clinitNeedsToBeRun = false
                pc -= 3
                return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
            }
            push(.reference(Object(clazz: cls)))
            return .continue

        // ── athrow ────────────────────────────────────────────────────────────
        case .athrow:
            guard case .reference(let objOpt) = pop(), let obj = objOpt
            else { fatalError("athrow: NullPointerException — null reference thrown") }
            if let handlerPC = findExceptionHandler(at: instructionStart, for: obj) {
                pc = handlerPC
                push(.reference(obj))
                return .continue   // handler found in this frame
            }
            return .thrown(.reference(obj))   // no local handler — unwind

        case .getfield:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            // classIndex is intentionally unused: field lookup is by name via
            // obj.instanceFields, keyed at Object init time in subclass-first
            // order by allInstanceFields() — the declaring class is not needed.
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("getfield: malformed constant pool at \(index)") }
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

        case .putfield:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            // classIndex intentionally unused — see getfield comment above.
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("putfield: malformed constant pool at \(index)") }
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

        // ── arrays ────────────────────────────────────────────────────────────
        case .newarray:
            let atype = Int(code[pc]); pc += 1
            guard let count = pop().asInt, count >= 0 else {
                fatalError("newarray: invalid count")
            }
            let (descriptor, defaultValue): (String, Value)
            switch atype {
            case 4:  (descriptor, defaultValue) = ("Z", .int(0))   // boolean
            case 5:  (descriptor, defaultValue) = ("C", .int(0))   // char
            case 6:  (descriptor, defaultValue) = ("F", .float(0)) // float
            case 7:  (descriptor, defaultValue) = ("D", .double(0))// double
            case 8:  (descriptor, defaultValue) = ("B", .int(0))   // byte
            case 9:  (descriptor, defaultValue) = ("S", .int(0))   // short
            case 10: (descriptor, defaultValue) = ("I", .int(0))   // int
            case 11: (descriptor, defaultValue) = ("J", .long(0))  // long
            default: fatalError("newarray: unknown atype \(atype)")
            }
            push(.array(JVMArray(elementDescriptor: descriptor, count: Int(count), default: defaultValue)))
            return .continue

        case .anewarray:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
            else { fatalError("anewarray: malformed constant pool at \(index)") }
            let className = classNameConst.string as String
            guard let count = pop().asInt, count >= 0 else {
                fatalError("anewarray: invalid count")
            }
            push(.array(JVMArray(elementDescriptor: "L\(className);", count: Int(count), default: .reference(nil))))
            return .continue

        case .arraylength:
            guard let arr = pop().asArray else {
                fatalError("arraylength: expected array reference on stack")
            }
            push(.int(Int32(arr.count)))
            return .continue

        // ── array loads ───────────────────────────────────────────────────────
        case .iaload, .baload, .caload, .saload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("\(opcode): expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("\(opcode): index \(index) out of bounds for length \(arr.count)") }
            push(arr.elements[Int(index)])
            return .continue

        case .laload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("laload: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("laload: index \(index) out of bounds for length \(arr.count)") }
            push(arr.elements[Int(index)])
            return .continue

        case .faload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("faload: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("faload: index \(index) out of bounds for length \(arr.count)") }
            push(arr.elements[Int(index)])
            return .continue

        case .daload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("daload: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("daload: index \(index) out of bounds for length \(arr.count)") }
            push(arr.elements[Int(index)])
            return .continue

        case .aaload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("aaload: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("aaload: index \(index) out of bounds for length \(arr.count)") }
            push(arr.elements[Int(index)])
            return .continue

        // ── array stores ──────────────────────────────────────────────────────
        case .iastore, .lastore, .fastore, .dastore, .aastore:
            let value = pop()
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("\(opcode): expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("\(opcode): index \(index) out of bounds for length \(arr.count)") }
            arr.elements[Int(index)] = value
            return .continue

        case .bastore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("bastore: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("bastore: index \(index) out of bounds for length \(arr.count)") }
            arr.elements[Int(index)] = .int(Int32(Int8(truncatingIfNeeded: value)))
            return .continue

        case .castore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("castore: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("castore: index \(index) out of bounds for length \(arr.count)") }
            arr.elements[Int(index)] = .int(Int32(value & 0xFFFF))
            return .continue

        case .sastore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("sastore: expected array") }
            guard index >= 0 && Int(index) < arr.count else { fatalError("sastore: index \(index) out of bounds for length \(arr.count)") }
            arr.elements[Int(index)] = .int(Int32(Int16(truncatingIfNeeded: value)))
            return .continue

        // ── invokespecial ─────────────────────────────────────────────────────
        case .invokespecial:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
                  let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
                  let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
            else { fatalError("invokespecial: malformed constant pool at \(index)") }
            let className  = classNameConst.string as String
            let methodName = nameConst.string as String
            let descriptor = descConst.string as String
            let argCount   = parseArgumentCount(descriptor: descriptor)
            // Pop args in reverse, then pop 'this' — this lands in slot 0.
            let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
            let thisValue = pop()
            // java/lang/Object.<init> is a no-op: no JDK stubs are loaded, and
            // Object's constructor has no behavior visible to our programs.
            // Args and 'this' are already popped; discard and continue.
            // Guard on methodName too: only <init> is safely skippable; any
            // other invokespecial to java/lang/Object (e.g. super.toString())
            // should fatalError so it's diagnosed rather than silently dropped.
            // No JDK stubs — treat <init> on the standard exception/Object hierarchy as no-ops.
            let jdkInitNoOps = ["java/lang/Object", "java/lang/Throwable",
                                 "java/lang/Exception", "java/lang/RuntimeException", "java/lang/Error"]
            if jdkInitNoOps.contains(className) && methodName == "<init>" { return .continue }
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("invokespecial: class not found: \(className)")
            }
            // Walk the superclass chain from the resolved class upward.
            // Track calleeClass separately: Frame.owningClass drives the constant
            // pool, so it must be the class that *declares* the method, not just
            // the class named in the invokespecial constant pool entry.
            var calleeMethod: MethodInfo?
            var calleeClass: Class?
            var searchCls: Class? = cls
            while let c = searchCls {
                if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                    calleeMethod = m
                    calleeClass  = c
                    break
                }
                let superName = c.classFile.superclassName
                guard !superName.isEmpty && superName != "java/lang/Object" else { break }
                if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                    searchCls = s
                } else { break }
            }
            guard let calleeMethod, let calleeClass else {
                fatalError("invokespecial: method not found: \(methodName)\(descriptor) in \(className)")
            }
            let calleeFrame = Frame(
                owningClass: calleeClass,
                method: calleeMethod,
                arguments: [thisValue] + args
            )
            return .invoke(frame: calleeFrame)

        // ── method invocation ─────────────────────────────────────────────────
        case .invokevirtual:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
                  let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
                  let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
            else { fatalError("invokevirtual: malformed constant pool at \(index)") }
            let className  = classNameConst.string as String
            let methodName = nameConst.string as String
            let descriptor = descConst.string as String
            let argCount   = parseArgumentCount(descriptor: descriptor)
            let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
            let receiver = pop()

            // ── Native dispatch: java/io/PrintStream ──────────────────────────
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

            // ── Virtual dispatch on user-defined classes ───────────────────────
            guard let objOptional = receiver.asReference else {
                fatalError("invokevirtual: expected reference on stack for \(methodName)")
            }
            guard let obj = objOptional else {
                fatalError("invokevirtual: NullPointerException — null receiver for \(methodName)")
            }
            var calleeMethod: MethodInfo?
            var calleeClass: Class?
            var searchCls: Class? = obj.clazz
            while let c = searchCls {
                if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                    calleeMethod = m
                    calleeClass  = c
                    break
                }
                let superName = c.classFile.superclassName
                guard !superName.isEmpty && superName != "java/lang/Object" else { break }
                if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                    searchCls = s
                } else { break }
            }
            guard let calleeMethod, let calleeClass else {
                fatalError("invokevirtual: method not found: \(methodName)\(descriptor) in \(obj.clazz.name)")
            }
            return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                        arguments: [receiver] + args))

        case .invokestatic:
            return executeInvokeStatic(code: code)

        // ── iinc ──────────────────────────────────────────────────────────────
        case .iinc:
            let idx   = Int(code[pc]); pc += 1
            let delta = Int32(Int8(bitPattern: code[pc])); pc += 1
            guard idx < localVariables.count,
                  let v = localVariables[idx].value,
                  case .int(let cur) = v
            else { fatalError("iinc: invalid local variable \(idx)") }
            localVariables[idx] = LocalVariable(.int(cur &+ delta))
            return .continue

        // ── long constants ────────────────────────────────────────────────────
        case .lconst_0: push(.long(0)); return .continue
        case .lconst_1: push(.long(1)); return .continue

        // ── long loads ────────────────────────────────────────────────────────
        case .lload:
            let idx = Int(code[pc]); pc += 1
            pushLocal(idx); return .continue
        case .lload_0: pushLocal(0); return .continue
        case .lload_1: pushLocal(1); return .continue
        case .lload_2: pushLocal(2); return .continue
        case .lload_3: pushLocal(3); return .continue

        // ── long stores ───────────────────────────────────────────────────────
        case .lstore:
            let idx = Int(code[pc]); pc += 1
            storeWide(pop(), at: idx); return .continue
        case .lstore_0: storeWide(pop(), at: 0); return .continue
        case .lstore_1: storeWide(pop(), at: 1); return .continue
        case .lstore_2: storeWide(pop(), at: 2); return .continue
        case .lstore_3: storeWide(pop(), at: 3); return .continue

        // ── long arithmetic ───────────────────────────────────────────────────
        case .ladd:
            let b = pop().asLong!, a = pop().asLong!
            push(.long(a &+ b)); return .continue
        case .lsub:
            let b = pop().asLong!, a = pop().asLong!
            push(.long(a &- b)); return .continue
        case .lmul:
            let b = pop().asLong!, a = pop().asLong!
            push(.long(a &* b)); return .continue
        case .ldiv:
            let b = pop().asLong!, a = pop().asLong!
            guard b != 0 else { fatalError("ldiv: ArithmeticException / by zero") }
            push(.long(a / b)); return .continue
        case .lrem:
            let b = pop().asLong!, a = pop().asLong!
            guard b != 0 else { fatalError("lrem: ArithmeticException / by zero") }
            push(.long(a % b)); return .continue
        case .lneg:
            push(.long(0 &- pop().asLong!)); return .continue

        // ── long compare & return ─────────────────────────────────────────────
        case .lcmp:
            let b = pop().asLong!, a = pop().asLong!
            push(.int(a < b ? -1 : a == b ? 0 : 1)); return .continue
        case .lreturn:
            return .returned(pop())

        // ── float constants ───────────────────────────────────────────────────
        case .fconst_0: push(.float(0.0)); return .continue
        case .fconst_1: push(.float(1.0)); return .continue
        case .fconst_2: push(.float(2.0)); return .continue

        // ── float loads ───────────────────────────────────────────────────────
        case .fload:
            let idx = Int(code[pc]); pc += 1
            pushLocal(idx); return .continue
        case .fload_0: pushLocal(0); return .continue
        case .fload_1: pushLocal(1); return .continue
        case .fload_2: pushLocal(2); return .continue
        case .fload_3: pushLocal(3); return .continue

        // ── float stores ──────────────────────────────────────────────────────
        case .fstore:
            let idx = Int(code[pc]); pc += 1
            setLocal(idx, pop()); return .continue
        case .fstore_0: setLocal(0, pop()); return .continue
        case .fstore_1: setLocal(1, pop()); return .continue
        case .fstore_2: setLocal(2, pop()); return .continue
        case .fstore_3: setLocal(3, pop()); return .continue

        // ── float arithmetic ──────────────────────────────────────────────────
        case .fadd:
            let b = pop().asFloat!, a = pop().asFloat!
            push(.float(a + b)); return .continue
        case .fsub:
            let b = pop().asFloat!, a = pop().asFloat!
            push(.float(a - b)); return .continue
        case .fmul:
            let b = pop().asFloat!, a = pop().asFloat!
            push(.float(a * b)); return .continue
        case .fdiv:
            let b = pop().asFloat!, a = pop().asFloat!
            push(.float(a / b)); return .continue
        case .frem:
            let b = pop().asFloat!, a = pop().asFloat!
            push(.float(a.truncatingRemainder(dividingBy: b))); return .continue
        case .fneg:
            push(.float(-pop().asFloat!)); return .continue

        // ── float compare ─────────────────────────────────────────────────────
        // fcmpl: NaN → -1  |  fcmpg: NaN → +1
        case .fcmpl:
            let b = pop().asFloat!, a = pop().asFloat!
            if a.isNaN || b.isNaN    { push(.int(-1)) }
            else if a < b            { push(.int(-1)) }
            else if a == b           { push(.int( 0)) }
            else                     { push(.int( 1)) }
            return .continue
        case .fcmpg:
            let b = pop().asFloat!, a = pop().asFloat!
            if a.isNaN || b.isNaN    { push(.int( 1)) }
            else if a < b            { push(.int(-1)) }
            else if a == b           { push(.int( 0)) }
            else                     { push(.int( 1)) }
            return .continue
        case .freturn:
            return .returned(pop())

        // ── double constants ──────────────────────────────────────────────────
        case .dconst_0: push(.double(0.0)); return .continue
        case .dconst_1: push(.double(1.0)); return .continue

        // ── double loads ──────────────────────────────────────────────────────
        case .dload:
            let idx = Int(code[pc]); pc += 1
            pushLocal(idx); return .continue
        case .dload_0: pushLocal(0); return .continue
        case .dload_1: pushLocal(1); return .continue
        case .dload_2: pushLocal(2); return .continue
        case .dload_3: pushLocal(3); return .continue

        // ── double stores ─────────────────────────────────────────────────────
        case .dstore:
            let idx = Int(code[pc]); pc += 1
            storeWide(pop(), at: idx); return .continue
        case .dstore_0: storeWide(pop(), at: 0); return .continue
        case .dstore_1: storeWide(pop(), at: 1); return .continue
        case .dstore_2: storeWide(pop(), at: 2); return .continue
        case .dstore_3: storeWide(pop(), at: 3); return .continue

        // ── double arithmetic ─────────────────────────────────────────────────
        case .dadd:
            let b = pop().asDouble!, a = pop().asDouble!
            push(.double(a + b)); return .continue
        case .dsub:
            let b = pop().asDouble!, a = pop().asDouble!
            push(.double(a - b)); return .continue
        case .dmul:
            let b = pop().asDouble!, a = pop().asDouble!
            push(.double(a * b)); return .continue
        case .ddiv:
            let b = pop().asDouble!, a = pop().asDouble!
            push(.double(a / b)); return .continue
        case .drem:
            let b = pop().asDouble!, a = pop().asDouble!
            push(.double(a.truncatingRemainder(dividingBy: b))); return .continue
        case .dneg:
            push(.double(-pop().asDouble!)); return .continue

        // ── double compare ────────────────────────────────────────────────────
        case .dcmpl:
            let b = pop().asDouble!, a = pop().asDouble!
            if a.isNaN || b.isNaN    { push(.int(-1)) }
            else if a < b            { push(.int(-1)) }
            else if a == b           { push(.int( 0)) }
            else                     { push(.int( 1)) }
            return .continue
        case .dcmpg:
            let b = pop().asDouble!, a = pop().asDouble!
            if a.isNaN || b.isNaN    { push(.int( 1)) }
            else if a < b            { push(.int(-1)) }
            else if a == b           { push(.int( 0)) }
            else                     { push(.int( 1)) }
            return .continue
        case .dreturn:
            return .returned(pop())

        // ── type conversions ──────────────────────────────────────────────────
        case .i2l:
            guard case .int(let v)    = pop() else { fatalError("i2l: expected int") }
            push(.long(Int64(v)));   return .continue
        case .i2f:
            guard case .int(let v)    = pop() else { fatalError("i2f: expected int") }
            push(.float(Float(v)));  return .continue
        case .i2d:
            guard case .int(let v)    = pop() else { fatalError("i2d: expected int") }
            push(.double(Double(v))); return .continue

        case .l2i:
            guard case .long(let v)   = pop() else { fatalError("l2i: expected long") }
            push(.int(Int32(truncatingIfNeeded: v))); return .continue
        case .l2f:
            guard case .long(let v)   = pop() else { fatalError("l2f: expected long") }
            push(.float(Float(v)));  return .continue
        case .l2d:
            guard case .long(let v)   = pop() else { fatalError("l2d: expected long") }
            push(.double(Double(v))); return .continue

        case .f2i:
            guard case .float(let v)  = pop() else { fatalError("f2i: expected float") }
            let r32: Int32
            if v.isNaN              { r32 = 0 }
            else if v >=  2147483648.0 { r32 = Int32.max }
            else if v < -2147483648.0  { r32 = Int32.min }
            else                    { r32 = Int32(v) }
            push(.int(r32)); return .continue
        case .f2l:
            guard case .float(let v)  = pop() else { fatalError("f2l: expected float") }
            let r64f: Int64
            if v.isNaN              { r64f = 0 }
            else if v >=  9.223372036854776e18 { r64f = Int64.max }
            else if v < -9.223372036854776e18  { r64f = Int64.min }
            else                    { r64f = Int64(v) }
            push(.long(r64f)); return .continue
        case .f2d:
            guard case .float(let v)  = pop() else { fatalError("f2d: expected float") }
            push(.double(Double(v))); return .continue

        case .d2i:
            guard case .double(let v) = pop() else { fatalError("d2i: expected double") }
            let r32d: Int32
            if v.isNaN              { r32d = 0 }
            else if v >=  2147483648.0 { r32d = Int32.max }
            else if v < -2147483648.0  { r32d = Int32.min }
            else                    { r32d = Int32(v) }
            push(.int(r32d)); return .continue
        case .d2l:
            guard case .double(let v) = pop() else { fatalError("d2l: expected double") }
            let r64d: Int64
            if v.isNaN              { r64d = 0 }
            else if v >=  9.223372036854776e18 { r64d = Int64.max }
            else if v < -9.223372036854776e18  { r64d = Int64.min }
            else                    { r64d = Int64(v) }
            push(.long(r64d)); return .continue
        case .d2f:
            guard case .double(let v) = pop() else { fatalError("d2f: expected double") }
            push(.float(Float(v)));  return .continue

        case .i2b:
            guard case .int(let v)    = pop() else { fatalError("i2b: expected int") }
            push(.int(Int32(Int8(truncatingIfNeeded: v)))); return .continue
        case .i2c:
            guard case .int(let v)    = pop() else { fatalError("i2c: expected int") }
            push(.int(Int32(UInt16(truncatingIfNeeded: v)))); return .continue
        case .i2s:
            guard case .int(let v)    = pop() else { fatalError("i2s: expected int") }
            push(.int(Int32(Int16(truncatingIfNeeded: v)))); return .continue

        // ── constant pool loads ───────────────────────────────────────────────
        case .ldc:
            let index = UInt16(code[pc]); pc += 1
            switch constantPool[index] {
            case let c as IntegerConstant: push(.int(c.value))
            case let c as FloatConstant:   push(.float(c.value))
            case let c as StringRefConstant:
                guard let utf8 = constantPool[c.stringIndex] as? Utf8Constant
                else { fatalError("ldc: StringRefConstant points to non-Utf8 at \(c.stringIndex)") }
                push(.string(utf8.string as String))
            default: fatalError("ldc: unexpected constant pool type at index \(index)")
            }
            return .continue

        case .ldc_w:
            let hi = UInt16(code[pc]); pc += 1
            let lo = UInt16(code[pc]); pc += 1
            let idxW = hi << 8 | lo
            switch constantPool[idxW] {
            case let c as IntegerConstant: push(.int(c.value))
            case let c as FloatConstant:   push(.float(c.value))
            case let c as StringRefConstant:
                guard let utf8 = constantPool[c.stringIndex] as? Utf8Constant
                else { fatalError("ldc_w: StringRefConstant points to non-Utf8 at \(c.stringIndex)") }
                push(.string(utf8.string as String))
            default: fatalError("ldc_w: unexpected constant pool type at index \(idxW)")
            }
            return .continue

        case .ldc2_w:
            let hi = UInt16(code[pc]); pc += 1
            let lo = UInt16(code[pc]); pc += 1
            let idx2 = hi << 8 | lo
            switch constantPool[idx2] {
            case let c as LongConstant:   push(.long(c.value))
            case let c as DoubleConstant: push(.double(c.value))
            default: fatalError("ldc2_w: expected Long or Double at index \(idx2)")
            }
            return .continue

        // ── category-2 stack ops ──────────────────────────────────────────────
        case .pop2:
            // In our model long/double are single stack items (category 2 = 1 slot).
            _ = pop(); return .continue

        case .dup2:
            // Category-2 (long/double): duplicate the single item.
            // Category-1: duplicate the top two items.
            let top = pop()
            switch top {
            case .long, .double:
                push(top); push(top)
            default:
                let second = pop()
                push(second); push(top); push(second); push(top)
            }
            return .continue

        // ── checkcast / instanceof ────────────────────────────────────────────
        case .checkcast:
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
                push(value)  // null passes any checkcast per JVM spec
            case .reference(let obj?):
                if !isAssignableTo(obj, targetName: targetName) {
                    fatalError("checkcast: ClassCastException — \(obj.clazz.name) cannot be cast to \(targetName)")
                }
                push(value)
            case .array:
                push(value)  // array cast: accept (no deep type check yet)
            default:
                fatalError("checkcast: unexpected value type on stack")
            }
            return .continue

        case .instanceof:
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
                push(.int(0))  // null instanceof anything = false
            case .reference(let obj?):
                push(.int(isAssignableTo(obj, targetName: targetName) ? 1 : 0))
            case .array:
                push(.int(targetName.hasPrefix("[") ? 1 : 0))
            default:
                fatalError("instanceof: unexpected value type on stack")
            }
            return .continue

        // ── invokeinterface ───────────────────────────────────────────────────
        case .invokeinterface:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            pc += 2  // skip count byte and trailing 0
            guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
                  let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
            else { fatalError("invokeinterface: malformed constant pool at \(index)") }
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
            var calleeMethod: MethodInfo?
            var calleeClass: Class?
            var searchCls: Class? = obj.clazz
            while let c = searchCls {
                if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                    calleeMethod = m
                    calleeClass  = c
                    break
                }
                let superName = c.classFile.superclassName
                guard !superName.isEmpty && superName != "java/lang/Object" else { break }
                if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                    searchCls = s
                } else { break }
            }
            guard let calleeMethod, let calleeClass else {
                fatalError("invokeinterface: method not found: \(methodName)\(descriptor) in \(obj.clazz.name)")
            }
            return .invoke(frame: Frame(owningClass: calleeClass, method: calleeMethod,
                                        arguments: [receiver] + args))

        default:
            fatalError("Unimplemented opcode \(opcode) at pc \(instructionStart) in \(method.name.string)")
        }
    }

    // MARK: - Exception handling helpers

    /// Searches this frame's exception table for a handler covering `throwPC`
    /// that matches `obj`'s type.  Returns the handler PC if found, else nil.
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

    // MARK: - isAssignableTo

    private func isAssignableTo(_ obj: Object, targetName: String) -> Bool {
        if targetName == "java/lang/Object" { return true }
        var cls: Class? = obj.clazz
        while let c = cls {
            if c.name == targetName { return true }
            // Check directly-implemented interfaces at this level.
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

    // MARK: - invokestatic

    private func executeInvokeStatic(code: Data) -> ExecutionResult {
        let hi = Int(code[pc]); pc += 1
        let lo = Int(code[pc]); pc += 1
        let index = UInt16(hi << 8 | lo)

        guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
              let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
              let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
              let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
              let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
              let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
        else {
            fatalError("invokestatic: malformed constant pool entry at index \(index)")
        }

        let className  = classNameConst.string as String
        let methodName = nameConst.string as String
        let descriptor = descConst.string as String
        let argCount   = parseArgumentCount(descriptor: descriptor)

        // Pop arguments in reverse order so slot 0 holds the first argument.
        let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()

        let classResult = Runtime.vm.findOrCreateClass(named: className)
        guard case .success(let cls) = classResult, let cls else {
            fatalError("invokestatic: class not found: \(className)")
        }
        guard let calleeMethod = cls.findMethod(named: methodName, descriptor: descriptor) else {
            fatalError("invokestatic: method not found: \(methodName)\(descriptor) in \(className)")
        }

        let calleeFrame = Frame(owningClass: cls, method: calleeMethod, arguments: args)
        return .invoke(frame: calleeFrame)
    }
}
