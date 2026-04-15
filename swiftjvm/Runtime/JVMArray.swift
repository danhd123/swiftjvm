//
//  JVMArray.swift
//  swiftjvm

/// A JVM array — indexed storage of Values with a fixed count and element type.
/// Arrays are not subclasses of Object because they have no ClassFile; they are
/// stored on the operand stack as Value.array(_) rather than Value.reference(_).
class JVMArray {
    /// JVM type descriptor for individual elements (e.g. "I", "D", "Ljava/lang/Object;").
    let elementDescriptor: String
    var elements: [Value]
    var count: Int { elements.count }

    init(elementDescriptor: String, count: Int, default defaultValue: Value) {
        self.elementDescriptor = elementDescriptor
        self.elements = Array(repeating: defaultValue, count: count)
    }
}
