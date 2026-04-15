import Foundation

extension Frame {

    // MARK: - Control flow

    func executeControl(opcode: BytecodeInstruction.Opcode, code: Data) -> ExecutionResult {
        let instrStart = lastInstructionStart
        switch opcode {

        // ── if-zero branches ──────────────────────────────────────────────────
        case .ifeq:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v == 0 { pc = instrStart + offset }
        case .ifne:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v != 0 { pc = instrStart + offset }
        case .iflt:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v < 0  { pc = instrStart + offset }
        case .ifge:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v >= 0 { pc = instrStart + offset }
        case .ifgt:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v > 0  { pc = instrStart + offset }
        case .ifle:
            let v = pop().asInt!; let offset = readBranchOffset(code: code)
            if v <= 0 { pc = instrStart + offset }

        // ── if-int-compare branches ───────────────────────────────────────────
        case .if_icmpeq:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a == b { pc = instrStart + offset }
        case .if_icmpne:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a != b { pc = instrStart + offset }
        case .if_icmplt:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a < b  { pc = instrStart + offset }
        case .if_icmpge:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a >= b { pc = instrStart + offset }
        case .if_icmpgt:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a > b  { pc = instrStart + offset }
        case .if_icmple:
            let b = pop().asInt!, a = pop().asInt!; let offset = readBranchOffset(code: code)
            if a <= b { pc = instrStart + offset }

        // ── reference-null branches ───────────────────────────────────────────
        case .ifnull:
            let offset = readBranchOffset(code: code)
            let ref = pop()
            if case .reference(let r) = ref, r == nil { pc = instrStart + offset }
            // non-null array or non-null reference: don't branch
        case .ifnonnull:
            let offset = readBranchOffset(code: code)
            let ref = pop()
            if case .reference(let r) = ref, r != nil { pc = instrStart + offset }
            else if case .array(_) = ref              { pc = instrStart + offset }

        // ── unconditional branches ────────────────────────────────────────────
        case .goto:
            let offset = readBranchOffset(code: code)
            pc = instrStart + offset
        case .goto_w:
            let offset = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            pc = instrStart + offset

        // ── tableswitch ───────────────────────────────────────────────────────
        case .tableswitch:
            // Pad pc to the next 4-byte boundary from method start.
            let pad = (4 - ((instrStart + 1) % 4)) % 4
            pc += pad
            let defaultOffset = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            let low  = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            let high = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            let key = pop().asInt!
            if key < low || key > high {
                pc = instrStart + defaultOffset
            } else {
                let offsetIdx = pc + (Int(key) - low) * 4
                pc = instrStart + Int(Int32(bigEndianBytes: code, at: offsetIdx))
            }

        // ── lookupswitch ──────────────────────────────────────────────────────
        case .lookupswitch:
            let pad = (4 - ((instrStart + 1) % 4)) % 4
            pc += pad
            let defaultOffset = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            let npairs = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
            let key = pop().asInt!
            var jumped = false
            for _ in 0..<npairs {
                let match  = Int32(bigEndianBytes: code, at: pc); pc += 4
                let offset = Int(Int32(bigEndianBytes: code, at: pc)); pc += 4
                if key == match {
                    pc = instrStart + offset
                    jumped = true
                    break
                }
            }
            if !jumped { pc = instrStart + defaultOffset }

        default:
            fatalError("executeControl: unexpected opcode \(opcode)")
        }
        return .continue
    }
}
