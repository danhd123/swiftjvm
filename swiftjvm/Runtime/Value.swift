//
//  Value.swift
//  swiftjvm
//
//  Created by Claude on 4/13/26.
//

/// A JVM computational value — covers all types that can appear on the operand
/// stack or in a local variable slot.
enum Value {
    case int(Int32)
    case long(Int64)
    case float(Float)
    case double(Double)
    case reference(Object?)   // nil == Java null
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
}
