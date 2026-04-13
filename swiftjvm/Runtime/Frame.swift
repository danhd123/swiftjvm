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

    var codeAttribute: CodeAttribute? {
        method.attributes.first { $0 is CodeAttribute } as? CodeAttribute
    }

    /// Creates a frame ready for execution.  `arguments` are placed into local
    /// variable slots 0..N-1; remaining slots (up to `maxLocals`) are nil.
    init(owningClass: Class, method: MethodInfo, arguments: [Value] = []) {
        self.owningClass = owningClass
        self.constantPool = owningClass.classFile.constantPool
        self.method = method
        let maxLocals = Int(
            (method.attributes.first { $0 is CodeAttribute } as? CodeAttribute)?.maxLocals ?? 0
        )
        let count = max(maxLocals, arguments.count)
        self.localVariables = (0..<count).map { i in
            LocalVariable(i < arguments.count ? arguments[i] : nil)
        }
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
        push(v)
    }

    private func setLocal(_ idx: Int, _ value: Value) {
        while localVariables.count <= idx { localVariables.append(LocalVariable()) }
        localVariables[idx] = LocalVariable(value)
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

        // ── method invocation ─────────────────────────────────────────────────
        case .invokestatic:
            return executeInvokeStatic(code: code)

        default:
            fatalError("Unimplemented opcode \(opcode) at pc \(instructionStart) in \(method.name.string)")
        }
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
        var args: [Value] = (0..<argCount).map { _ in pop() }.reversed()

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
