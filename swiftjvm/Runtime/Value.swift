//
//  Value.swift
//  swiftjvm
//
//  Created by Claude on 4/13/26.
//

/// Backing store for java.lang.StringBuilder / StringBuffer.
/// A class so that all Value aliases share the same mutable buffer.
final class StringBuilderBuffer {
    var content: String
    init(_ initial: String = "") { self.content = initial }
}

/// A JVM computational value — covers all types that can appear on the operand
/// stack or in a local variable slot.
enum Value {
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case reference(Object?)   // nil == Java null
    case array(JVMArray)
    case string(String)       // Java String constant (native representation)
    case printStream          // sentinel for java.io.PrintStream (System.out)
    case stringBuilder(StringBuilderBuffer)  // sentinel for java.lang.StringBuilder/StringBuffer
    case returnAddress(Int)
    /// Sentinel written into the *upper* local-variable slot of a category-2
    /// value (long or double).  Loading this slot is always a bug.
    case placeholder
}

extension Value {
    var asInt: Int32? {
        if case .int(let v) = self { return v } else { return nil }
    }
    var asLong: Int64? {
        if case .long(let v) = self { return v } else { return nil }
    }
    var asFloat: Float? {
        if case .float(let v) = self { return v } else { return nil }
    }
    var asDouble: Double? {
        if case .double(let v) = self { return v } else { return nil }
    }
    var asReference: Object?? {
        if case .reference(let v) = self { return v } else { return nil }
    }
    var asArray: JVMArray? {
        if case .array(let a) = self { return a } else { return nil }
    }
    var asString: String? {
        if case .string(let s) = self { return s } else { return nil }
    }
}
