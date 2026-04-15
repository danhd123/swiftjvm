extension Frame {

    // MARK: - Arithmetic, bitwise, and numeric comparisons

    func executeArithmetic(opcode: BytecodeInstruction.Opcode) -> ExecutionResult {
        switch opcode {
        // ── int ──────────────────────────────────────────────────────────────
        case .iadd:  let b = pop().asInt!, a = pop().asInt!; push(.int(a &+ b))
        case .isub:  let b = pop().asInt!, a = pop().asInt!; push(.int(a &- b))
        case .imul:  let b = pop().asInt!, a = pop().asInt!; push(.int(a &* b))
        case .idiv:
            let b = pop().asInt!, a = pop().asInt!
            guard b != 0 else { fatalError("idiv: ArithmeticException / by zero") }
            push(.int(a / b))
        case .irem:
            let b = pop().asInt!, a = pop().asInt!
            guard b != 0 else { fatalError("irem: ArithmeticException / by zero") }
            push(.int(a % b))
        case .ineg:  push(.int(0 &- pop().asInt!))
        case .iand:  let b = pop().asInt!, a = pop().asInt!; push(.int(a & b))
        case .ior:   let b = pop().asInt!, a = pop().asInt!; push(.int(a | b))
        case .ixor:  let b = pop().asInt!, a = pop().asInt!; push(.int(a ^ b))
        case .ishl:  let count = pop().asInt! & 0x1f; let value = pop().asInt!; push(.int(value << count))
        case .ishr:  let count = pop().asInt! & 0x1f; let value = pop().asInt!; push(.int(value >> count))
        case .iushr:
            let count = pop().asInt! & 0x1f; let value = pop().asInt!
            push(.int(Int32(bitPattern: UInt32(bitPattern: value) >> UInt32(count))))
        // ── long ─────────────────────────────────────────────────────────────
        case .ladd:  let b = pop().asLong!, a = pop().asLong!; push(.long(a &+ b))
        case .lsub:  let b = pop().asLong!, a = pop().asLong!; push(.long(a &- b))
        case .lmul:  let b = pop().asLong!, a = pop().asLong!; push(.long(a &* b))
        case .ldiv:
            let b = pop().asLong!, a = pop().asLong!
            guard b != 0 else { fatalError("ldiv: ArithmeticException / by zero") }
            push(.long(a / b))
        case .lrem:
            let b = pop().asLong!, a = pop().asLong!
            guard b != 0 else { fatalError("lrem: ArithmeticException / by zero") }
            push(.long(a % b))
        case .lneg:  push(.long(0 &- pop().asLong!))
        case .land:  let b = pop().asLong!, a = pop().asLong!; push(.long(a & b))
        case .lor:   let b = pop().asLong!, a = pop().asLong!; push(.long(a | b))
        case .lxor:  let b = pop().asLong!, a = pop().asLong!; push(.long(a ^ b))
        case .lshl:  let count = Int64(pop().asInt! & 0x3f); let value = pop().asLong!; push(.long(value << count))
        case .lshr:  let count = Int64(pop().asInt! & 0x3f); let value = pop().asLong!; push(.long(value >> count))
        case .lushr:
            let count = UInt64(pop().asInt! & 0x3f); let value = pop().asLong!
            push(.long(Int64(bitPattern: UInt64(bitPattern: value) >> count)))
        case .lcmp:
            let b = pop().asLong!, a = pop().asLong!
            push(.int(a < b ? -1 : a == b ? 0 : 1))
        // ── float ─────────────────────────────────────────────────────────────
        case .fadd:  let b = pop().asFloat!, a = pop().asFloat!; push(.float(a + b))
        case .fsub:  let b = pop().asFloat!, a = pop().asFloat!; push(.float(a - b))
        case .fmul:  let b = pop().asFloat!, a = pop().asFloat!; push(.float(a * b))
        case .fdiv:  let b = pop().asFloat!, a = pop().asFloat!; push(.float(a / b))
        case .frem:  let b = pop().asFloat!, a = pop().asFloat!; push(.float(a.truncatingRemainder(dividingBy: b)))
        case .fneg:  push(.float(-pop().asFloat!))
        case .fcmpl:
            let b = pop().asFloat!, a = pop().asFloat!
            if a.isNaN || b.isNaN { push(.int(-1)) } else if a < b { push(.int(-1)) } else if a == b { push(.int(0)) } else { push(.int(1)) }
        case .fcmpg:
            let b = pop().asFloat!, a = pop().asFloat!
            if a.isNaN || b.isNaN { push(.int( 1)) } else if a < b { push(.int(-1)) } else if a == b { push(.int(0)) } else { push(.int(1)) }
        // ── double ────────────────────────────────────────────────────────────
        case .dadd:  let b = pop().asDouble!, a = pop().asDouble!; push(.double(a + b))
        case .dsub:  let b = pop().asDouble!, a = pop().asDouble!; push(.double(a - b))
        case .dmul:  let b = pop().asDouble!, a = pop().asDouble!; push(.double(a * b))
        case .ddiv:  let b = pop().asDouble!, a = pop().asDouble!; push(.double(a / b))
        case .drem:  let b = pop().asDouble!, a = pop().asDouble!; push(.double(a.truncatingRemainder(dividingBy: b)))
        case .dneg:  push(.double(-pop().asDouble!))
        case .dcmpl:
            let b = pop().asDouble!, a = pop().asDouble!
            if a.isNaN || b.isNaN { push(.int(-1)) } else if a < b { push(.int(-1)) } else if a == b { push(.int(0)) } else { push(.int(1)) }
        case .dcmpg:
            let b = pop().asDouble!, a = pop().asDouble!
            if a.isNaN || b.isNaN { push(.int( 1)) } else if a < b { push(.int(-1)) } else if a == b { push(.int(0)) } else { push(.int(1)) }
        default:
            fatalError("executeArithmetic: unexpected opcode \(opcode)")
        }
        return .continue
    }

    // MARK: - Type conversions

    func executeConversion(opcode: BytecodeInstruction.Opcode) -> ExecutionResult {
        switch opcode {
        case .i2l:
            guard case .int(let v)    = pop() else { fatalError("i2l: expected int") }
            push(.long(Int64(v)))
        case .i2f:
            guard case .int(let v)    = pop() else { fatalError("i2f: expected int") }
            push(.float(Float(v)))
        case .i2d:
            guard case .int(let v)    = pop() else { fatalError("i2d: expected int") }
            push(.double(Double(v)))
        case .l2i:
            guard case .long(let v)   = pop() else { fatalError("l2i: expected long") }
            push(.int(Int32(truncatingIfNeeded: v)))
        case .l2f:
            guard case .long(let v)   = pop() else { fatalError("l2f: expected long") }
            push(.float(Float(v)))
        case .l2d:
            guard case .long(let v)   = pop() else { fatalError("l2d: expected long") }
            push(.double(Double(v)))
        case .f2i:
            guard case .float(let v)  = pop() else { fatalError("f2i: expected float") }
            if v.isNaN                  { push(.int(0)) }
            else if v >=  2147483648.0  { push(.int(Int32.max)) }
            else if v < -2147483648.0   { push(.int(Int32.min)) }
            else                        { push(.int(Int32(v))) }
        case .f2l:
            guard case .float(let v)  = pop() else { fatalError("f2l: expected float") }
            if v.isNaN                         { push(.long(0)) }
            else if v >=  9.223372036854776e18 { push(.long(Int64.max)) }
            else if v < -9.223372036854776e18  { push(.long(Int64.min)) }
            else                               { push(.long(Int64(v))) }
        case .f2d:
            guard case .float(let v)  = pop() else { fatalError("f2d: expected float") }
            push(.double(Double(v)))
        case .d2i:
            guard case .double(let v) = pop() else { fatalError("d2i: expected double") }
            if v.isNaN                  { push(.int(0)) }
            else if v >=  2147483648.0  { push(.int(Int32.max)) }
            else if v < -2147483648.0   { push(.int(Int32.min)) }
            else                        { push(.int(Int32(v))) }
        case .d2l:
            guard case .double(let v) = pop() else { fatalError("d2l: expected double") }
            if v.isNaN                         { push(.long(0)) }
            else if v >=  9.223372036854776e18 { push(.long(Int64.max)) }
            else if v < -9.223372036854776e18  { push(.long(Int64.min)) }
            else                               { push(.long(Int64(v))) }
        case .d2f:
            guard case .double(let v) = pop() else { fatalError("d2f: expected double") }
            push(.float(Float(v)))
        case .i2b:
            guard case .int(let v)    = pop() else { fatalError("i2b: expected int") }
            push(.int(Int32(Int8(truncatingIfNeeded: v))))
        case .i2c:
            guard case .int(let v)    = pop() else { fatalError("i2c: expected int") }
            push(.int(Int32(UInt16(truncatingIfNeeded: v))))
        case .i2s:
            guard case .int(let v)    = pop() else { fatalError("i2s: expected int") }
            push(.int(Int32(Int16(truncatingIfNeeded: v))))
        default:
            fatalError("executeConversion: unexpected opcode \(opcode)")
        }
        return .continue
    }
}
