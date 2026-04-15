extension Frame {

    // MARK: - String native dispatch

    /// Executes a native String instance method. Returns the result Value to push,
    /// or nil for void methods.
    func executeStringMethod(methodName: String, descriptor: String,
                             receiver s: String, args: [Value]) -> Value? {
        func arg0String() -> String {
            if case .string(let v) = args[0] { return v }
            return "null"
        }
        switch methodName {
        case "toString", "intern":
            return .string(s)
        case "toCharArray":
            let arr = JVMArray(elementDescriptor: "C", count: s.unicodeScalars.count, default: .int(0))
            for (i, scalar) in s.unicodeScalars.enumerated() {
                arr.elements[i] = .int(Int32(scalar.value))
            }
            return .array(arr)
        case "length":
            return .int(Int32(s.count))
        case "isEmpty":
            return .int(s.isEmpty ? 1 : 0)
        case "charAt":
            let idx = Int(args[0].asInt!)
            guard idx >= 0 && idx < s.count else { fatalError("String.charAt: index \(idx) out of bounds") }
            let scalar = s.unicodeScalars[s.unicodeScalars.index(s.unicodeScalars.startIndex, offsetBy: idx)]
            return .int(Int32(scalar.value))
        case "equals":
            return .int(s == arg0String() ? 1 : 0)
        case "equalsIgnoreCase":
            return .int(s.lowercased() == arg0String().lowercased() ? 1 : 0)
        case "compareTo":
            return .int(Int32(s < arg0String() ? -1 : s > arg0String() ? 1 : 0))
        case "hashCode":
            return .int(Int32(truncatingIfNeeded: s.hashValue))
        case "startsWith":
            return .int(s.hasPrefix(arg0String()) ? 1 : 0)
        case "endsWith":
            return .int(s.hasSuffix(arg0String()) ? 1 : 0)
        case "contains":
            return .int(s.contains(arg0String()) ? 1 : 0)
        case "indexOf":
            if descriptor == "(I)I" {
                let ch = Character(UnicodeScalar(UInt32(args[0].asInt!))!)
                if let r = s.firstIndex(of: ch) {
                    return .int(Int32(s.distance(from: s.startIndex, to: r)))
                }
                return .int(-1)
            } else {
                let target = arg0String()
                if let r = s.range(of: target) {
                    return .int(Int32(s.distance(from: s.startIndex, to: r.lowerBound)))
                }
                return .int(-1)
            }
        case "lastIndexOf":
            let target = arg0String()
            if let r = s.range(of: target, options: .backwards) {
                return .int(Int32(s.distance(from: s.startIndex, to: r.lowerBound)))
            }
            return .int(-1)
        case "substring":
            let start = Int(args[0].asInt!)
            if args.count == 1 {
                guard start <= s.count else { fatalError("String.substring: begin > length") }
                return .string(String(s.dropFirst(start)))
            } else {
                let end = Int(args[1].asInt!)
                guard start <= end && end <= s.count else { fatalError("String.substring: bounds error") }
                let startIdx = s.index(s.startIndex, offsetBy: start)
                let endIdx   = s.index(s.startIndex, offsetBy: end)
                return .string(String(s[startIdx..<endIdx]))
            }
        case "concat":
            return .string(s + arg0String())
        case "toUpperCase":
            return .string(s.uppercased())
        case "toLowerCase":
            return .string(s.lowercased())
        case "trim":
            return .string(s.trimmingCharacters(in: .whitespaces))
        case "strip":
            return .string(s.trimmingCharacters(in: .whitespacesAndNewlines))
        case "replace":
            if descriptor == "(CC)Ljava/lang/String;" {
                let from = Character(UnicodeScalar(UInt32(args[0].asInt!))!)
                let to   = Character(UnicodeScalar(UInt32(args[1].asInt!))!)
                return .string(s.replacingOccurrences(of: String(from), with: String(to)))
            }
            return .string(s.replacingOccurrences(of: arg0String(),
                with: args.count > 1 ? (args[1].asString ?? "null") : "null"))
        default:
            fatalError("invokevirtual: unsupported String method: \(methodName)\(descriptor)")
        }
    }
}
