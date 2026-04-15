//
//  Frame.swift
//  swiftjvm
//
//  Created by Daniel DeCovnick on 8/2/23.
//

import Foundation

// MARK: - Helpers

extension Int32 {
    /// Read a big-endian signed 32-bit integer from `data` starting at byte `offset`.
    init(bigEndianBytes data: Data, at offset: Int) {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        self = Int32(bitPattern: b0 << 24 | b1 << 16 | b2 << 8 | b3)
    }
}

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

    func pushLocal(_ idx: Int) {
        guard idx < localVariables.count, let v = localVariables[idx].value else {
            fatalError("Load from uninitialized local variable \(idx)")
        }
        if case .placeholder = v {
            fatalError("Loaded category-2 upper slot at local variable \(idx)")
        }
        push(v)
    }

    func setLocal(_ idx: Int, _ value: Value) {
        while localVariables.count <= idx { localVariables.append(LocalVariable()) }
        localVariables[idx] = LocalVariable(value)
    }

    /// Store a category-2 value (long or double) at `index` and write a
    /// `.placeholder` sentinel into `index + 1` to catch accidental loads.
    func storeWide(_ value: Value, at index: Int) {
        setLocal(index, value)
        setLocal(index + 1, .placeholder)
    }

    // MARK: - Branch helper

    /// Reads the 2-byte signed branch offset from `code` at the current `pc`,
    /// advancing `pc` by 2. Returns the signed offset.
    func readBranchOffset(code: Data) -> Int {
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

        case .nop:
            return .continue

        // ── constants & ldc ───────────────────────────────────────────────────
        case .iconst_m1, .iconst_0, .iconst_1, .iconst_2, .iconst_3, .iconst_4, .iconst_5,
             .lconst_0, .lconst_1,
             .fconst_0, .fconst_1, .fconst_2,
             .dconst_0, .dconst_1,
             .aconst_null,
             .bipush, .sipush,
             .ldc, .ldc_w, .ldc2_w:
            return executeLoadConstant(opcode: opcode, code: code)

        // ── local variable access ─────────────────────────────────────────────
        case .iload,  .iload_0,  .iload_1,  .iload_2,  .iload_3,
             .lload,  .lload_0,  .lload_1,  .lload_2,  .lload_3,
             .fload,  .fload_0,  .fload_1,  .fload_2,  .fload_3,
             .dload,  .dload_0,  .dload_1,  .dload_2,  .dload_3,
             .aload,  .aload_0,  .aload_1,  .aload_2,  .aload_3,
             .istore, .istore_0, .istore_1, .istore_2, .istore_3,
             .lstore, .lstore_0, .lstore_1, .lstore_2, .lstore_3,
             .fstore, .fstore_0, .fstore_1, .fstore_2, .fstore_3,
             .dstore, .dstore_0, .dstore_1, .dstore_2, .dstore_3,
             .astore, .astore_0, .astore_1, .astore_2, .astore_3,
             .iinc, .wide:
            return executeLocalAccess(opcode: opcode, code: code)

        // ── stack manipulation ────────────────────────────────────────────────
        case .pop, .pop2, .dup, .dup2,
             .dup_x1, .dup_x2, .dup2_x1, .dup2_x2, .swap:
            return executeStackOp(opcode: opcode)

        // ── arithmetic, bitwise, shifts, numeric comparisons ──────────────────
        case .iadd, .isub, .imul, .idiv, .irem, .ineg,
             .ladd, .lsub, .lmul, .ldiv, .lrem, .lneg,
             .fadd, .fsub, .fmul, .fdiv, .frem, .fneg,
             .dadd, .dsub, .dmul, .ddiv, .drem, .dneg,
             .iand, .ior, .ixor, .ishl, .ishr, .iushr,
             .land, .lor, .lxor, .lshl, .lshr, .lushr,
             .lcmp, .fcmpl, .fcmpg, .dcmpl, .dcmpg:
            return executeArithmetic(opcode: opcode)

        // ── type conversions ──────────────────────────────────────────────────
        case .i2l, .i2f, .i2d, .l2i, .l2f, .l2d,
             .f2i, .f2l, .f2d, .d2i, .d2l, .d2f,
             .i2b, .i2c, .i2s:
            return executeConversion(opcode: opcode)

        // ── control flow ──────────────────────────────────────────────────────
        case .ifeq, .ifne, .iflt, .ifge, .ifgt, .ifle,
             .if_icmpeq, .if_icmpne, .if_icmplt, .if_icmpge, .if_icmpgt, .if_icmple,
             .ifnull, .ifnonnull,
             .if_acmpeq, .if_acmpne,
             .goto, .goto_w,
             .tableswitch, .lookupswitch:
            return executeControl(opcode: opcode, code: code)

        // ── returns ───────────────────────────────────────────────────────────
        case .return:
            return .returned(nil)
        case .ireturn, .lreturn, .freturn, .dreturn, .areturn:
            return .returned(pop())

        // ── fields ────────────────────────────────────────────────────────────
        case .getstatic:    return executeGetStatic(code: code)
        case .putstatic:    return executePutStatic(code: code)
        case .getfield:     return executeGetField(code: code)
        case .putfield:     return executePutField(code: code)

        // ── arrays ────────────────────────────────────────────────────────────
        case .newarray, .anewarray, .arraylength,
             .iaload, .laload, .faload, .daload, .aaload, .baload, .caload, .saload,
             .iastore, .lastore, .fastore, .dastore, .aastore, .bastore, .castore, .sastore:
            return executeArrayOp(opcode: opcode, code: code)

        // ── object lifecycle & type checks ────────────────────────────────────
        case .new:          return executeNew(code: code)
        case .athrow:       return executeAThrow()
        case .checkcast:    return executeCheckCast(code: code)
        case .instanceof:   return executeInstanceOf(code: code)
        case .monitorenter, .monitorexit:
            _ = pop()   // no-op in single-threaded interpreter
            return .continue

        // ── method invocation ─────────────────────────────────────────────────
        case .invokespecial:    return executeInvokeSpecial(code: code)
        case .invokevirtual:    return executeInvokeVirtual(code: code)
        case .invokestatic:     return executeInvokeStatic(code: code)
        case .invokeinterface:  return executeInvokeInterface(code: code)

        default:
            fatalError("Unimplemented opcode \(opcode) at pc \(instructionStart) in \(method.name.string)")
        }
    }
}
