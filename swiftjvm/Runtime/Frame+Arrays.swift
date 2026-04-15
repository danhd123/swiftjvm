import Foundation

extension Frame {

    // MARK: - Array operations

    func executeArrayOp(opcode: BytecodeInstruction.Opcode, code: Data) -> ExecutionResult {
        switch opcode {

        // ── creation ──────────────────────────────────────────────────────────
        case .newarray:
            let atype = Int(code[pc]); pc += 1
            guard let count = pop().asInt, count >= 0 else { fatalError("newarray: invalid count") }
            let (descriptor, defaultValue): (String, Value)
            switch atype {
            case 4:  (descriptor, defaultValue) = ("Z", .int(0))    // boolean
            case 5:  (descriptor, defaultValue) = ("C", .int(0))    // char
            case 6:  (descriptor, defaultValue) = ("F", .float(0))  // float
            case 7:  (descriptor, defaultValue) = ("D", .double(0)) // double
            case 8:  (descriptor, defaultValue) = ("B", .int(0))    // byte
            case 9:  (descriptor, defaultValue) = ("S", .int(0))    // short
            case 10: (descriptor, defaultValue) = ("I", .int(0))    // int
            case 11: (descriptor, defaultValue) = ("J", .long(0))   // long
            default: fatalError("newarray: unknown atype \(atype)")
            }
            push(.array(JVMArray(elementDescriptor: descriptor, count: Int(count), default: defaultValue)))

        case .anewarray:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
            else { fatalError("anewarray: malformed constant pool at index") }
            let className = classNameConst.string as String
            guard let count = pop().asInt, count >= 0 else { fatalError("anewarray: invalid count") }
            push(.array(JVMArray(elementDescriptor: "L\(className);", count: Int(count), default: .reference(nil))))

        case .arraylength:
            guard let arr = pop().asArray else { fatalError("arraylength: expected array") }
            push(.int(Int32(arr.count)))

        // ── loads ─────────────────────────────────────────────────────────────
        case .iaload, .laload, .faload, .daload, .aaload, .baload, .caload, .saload:
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("\(opcode): expected array") }
            guard index >= 0 && Int(index) < arr.count else {
                fatalError("\(opcode): index \(index) out of bounds for length \(arr.count)")
            }
            push(arr.elements[Int(index)])

        // ── stores ────────────────────────────────────────────────────────────
        case .iastore, .lastore, .fastore, .dastore, .aastore:
            let value = pop()
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("\(opcode): expected array") }
            guard index >= 0 && Int(index) < arr.count else {
                fatalError("\(opcode): index \(index) out of bounds for length \(arr.count)")
            }
            arr.elements[Int(index)] = value

        case .bastore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("bastore: expected array") }
            guard index >= 0 && Int(index) < arr.count else {
                fatalError("bastore: index \(index) out of bounds for length \(arr.count)")
            }
            arr.elements[Int(index)] = .int(Int32(Int8(truncatingIfNeeded: value)))

        case .castore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("castore: expected array") }
            guard index >= 0 && Int(index) < arr.count else {
                fatalError("castore: index \(index) out of bounds for length \(arr.count)")
            }
            arr.elements[Int(index)] = .int(Int32(value & 0xFFFF))

        case .sastore:
            let value = pop().asInt!
            let index = pop().asInt!
            guard let arr = pop().asArray else { fatalError("sastore: expected array") }
            guard index >= 0 && Int(index) < arr.count else {
                fatalError("sastore: index \(index) out of bounds for length \(arr.count)")
            }
            arr.elements[Int(index)] = .int(Int32(Int16(truncatingIfNeeded: value)))

        default:
            fatalError("executeArrayOp: unexpected opcode \(opcode)")
        }
        return .continue
    }
}
