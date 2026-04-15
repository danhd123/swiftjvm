import Foundation

extension Frame {

    // MARK: - Constants

    func executeLoadConstant(opcode: BytecodeInstruction.Opcode, code: Data) -> ExecutionResult {
        switch opcode {
        case .iconst_m1: push(.int(-1))
        case .iconst_0:  push(.int( 0))
        case .iconst_1:  push(.int( 1))
        case .iconst_2:  push(.int( 2))
        case .iconst_3:  push(.int( 3))
        case .iconst_4:  push(.int( 4))
        case .iconst_5:  push(.int( 5))
        case .lconst_0:  push(.long(0))
        case .lconst_1:  push(.long(1))
        case .fconst_0:  push(.float(0.0))
        case .fconst_1:  push(.float(1.0))
        case .fconst_2:  push(.float(2.0))
        case .dconst_0:  push(.double(0.0))
        case .dconst_1:  push(.double(1.0))
        case .aconst_null: push(.reference(nil))
        case .bipush:
            let byte = Int8(bitPattern: code[pc]); pc += 1
            push(.int(Int32(byte)))
        case .sipush:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            push(.int(Int32(Int16(bitPattern: UInt16(hi << 8 | lo)))))
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
        case .ldc2_w:
            let hi = UInt16(code[pc]); pc += 1
            let lo = UInt16(code[pc]); pc += 1
            let idx2 = hi << 8 | lo
            switch constantPool[idx2] {
            case let c as LongConstant:   push(.long(c.value))
            case let c as DoubleConstant: push(.double(c.value))
            default: fatalError("ldc2_w: expected Long or Double at index \(idx2)")
            }
        default:
            fatalError("executeLoadConstant: unexpected opcode \(opcode)")
        }
        return .continue
    }

    // MARK: - Local variable access

    func executeLocalAccess(opcode: BytecodeInstruction.Opcode, code: Data) -> ExecutionResult {
        switch opcode {
        // int loads
        case .iload:   let idx = Int(code[pc]); pc += 1; pushLocal(idx)
        case .iload_0: pushLocal(0)
        case .iload_1: pushLocal(1)
        case .iload_2: pushLocal(2)
        case .iload_3: pushLocal(3)
        // int stores
        case .istore:   let idx = Int(code[pc]); pc += 1; setLocal(idx, pop())
        case .istore_0: setLocal(0, pop())
        case .istore_1: setLocal(1, pop())
        case .istore_2: setLocal(2, pop())
        case .istore_3: setLocal(3, pop())
        // long loads
        case .lload:   let idx = Int(code[pc]); pc += 1; pushLocal(idx)
        case .lload_0: pushLocal(0)
        case .lload_1: pushLocal(1)
        case .lload_2: pushLocal(2)
        case .lload_3: pushLocal(3)
        // long stores
        case .lstore:   let idx = Int(code[pc]); pc += 1; storeWide(pop(), at: idx)
        case .lstore_0: storeWide(pop(), at: 0)
        case .lstore_1: storeWide(pop(), at: 1)
        case .lstore_2: storeWide(pop(), at: 2)
        case .lstore_3: storeWide(pop(), at: 3)
        // float loads
        case .fload:   let idx = Int(code[pc]); pc += 1; pushLocal(idx)
        case .fload_0: pushLocal(0)
        case .fload_1: pushLocal(1)
        case .fload_2: pushLocal(2)
        case .fload_3: pushLocal(3)
        // float stores
        case .fstore:   let idx = Int(code[pc]); pc += 1; setLocal(idx, pop())
        case .fstore_0: setLocal(0, pop())
        case .fstore_1: setLocal(1, pop())
        case .fstore_2: setLocal(2, pop())
        case .fstore_3: setLocal(3, pop())
        // double loads
        case .dload:   let idx = Int(code[pc]); pc += 1; pushLocal(idx)
        case .dload_0: pushLocal(0)
        case .dload_1: pushLocal(1)
        case .dload_2: pushLocal(2)
        case .dload_3: pushLocal(3)
        // double stores
        case .dstore:   let idx = Int(code[pc]); pc += 1; storeWide(pop(), at: idx)
        case .dstore_0: storeWide(pop(), at: 0)
        case .dstore_1: storeWide(pop(), at: 1)
        case .dstore_2: storeWide(pop(), at: 2)
        case .dstore_3: storeWide(pop(), at: 3)
        // reference loads
        case .aload:   let idx = Int(code[pc]); pc += 1; pushLocal(idx)
        case .aload_0: pushLocal(0)
        case .aload_1: pushLocal(1)
        case .aload_2: pushLocal(2)
        case .aload_3: pushLocal(3)
        // reference stores
        case .astore:   let idx = Int(code[pc]); pc += 1; setLocal(idx, pop())
        case .astore_0: setLocal(0, pop())
        case .astore_1: setLocal(1, pop())
        case .astore_2: setLocal(2, pop())
        case .astore_3: setLocal(3, pop())
        // iinc
        case .iinc:
            let idx   = Int(code[pc]); pc += 1
            let delta = Int32(Int8(bitPattern: code[pc])); pc += 1
            guard idx < localVariables.count,
                  let v = localVariables[idx].value,
                  case .int(let cur) = v
            else { fatalError("iinc: invalid local variable \(idx)") }
            localVariables[idx] = LocalVariable(.int(cur &+ delta))
        // wide prefix — re-reads the sub-opcode with a 16-bit index
        case .wide:
            let wideOpcode = BytecodeInstruction.Opcode(rawValue: code[pc])!; pc += 1
            let wideIdx = Int(code[pc]) << 8 | Int(code[pc + 1]); pc += 2
            switch wideOpcode {
            case .iload, .lload, .fload, .dload, .aload:
                push(localVariables[wideIdx].value!)
            case .istore, .lstore, .fstore, .dstore, .astore:
                setLocal(wideIdx, pop())
            case .iinc:
                let wideConst = Int(Int16(bitPattern: UInt16(code[pc]) << 8 | UInt16(code[pc + 1]))); pc += 2
                guard case .int(let v) = localVariables[wideIdx].value else { fatalError("wide iinc: not int") }
                setLocal(wideIdx, .int(v &+ Int32(wideConst)))
            default:
                fatalError("wide: unsupported opcode \(wideOpcode)")
            }
        default:
            fatalError("executeLocalAccess: unexpected opcode \(opcode)")
        }
        return .continue
    }

    // MARK: - Stack manipulation

    func executeStackOp(opcode: BytecodeInstruction.Opcode) -> ExecutionResult {
        switch opcode {
        case .pop:
            _ = pop()
        case .pop2:
            _ = pop()   // category-2 values are a single stack slot in this implementation
        case .dup:
            push(peek())
        case .dup2:
            let top = pop()
            switch top {
            case .long, .double:
                push(top); push(top)
            default:
                let second = pop()
                push(second); push(top); push(second); push(top)
            }
        default:
            fatalError("executeStackOp: unexpected opcode \(opcode)")
        }
        return .continue
    }
}
