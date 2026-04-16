# SwiftJVM

A hobby JVM bytecode interpreter written in Swift. Execute Java `.class` files on macOS without the JDK.

> **Note:** This is an exploration project to understand JVM internals and Swift's systems programming capabilities. It is not a production-grade implementation and should not be used to run untrusted code.

## Overview

SwiftJVM implements a stack-based bytecode interpreter that can execute compiled Java programs. It parses `.class` files, maintains execution frames and an operand stack, and dispatches JVM opcodes to implement Java semantics—including object creation, exception handling, arrays, and method dispatch.

The interpreter is single-threaded and includes only hand-written native stubs for commonly-used JDK classes (e.g., `System.out.println`, `String.valueOf`). This makes it suitable for educational study of the JVM specification without the overhead of a full Java runtime.

## Features Implemented

### Core Language

- **Classes & Objects:** `new`, `instanceof`, `checkcast`, object creation with field access
- **Methods:** `invokespecial`, `invokevirtual`, `invokestatic`, `invokeinterface`, `invokedynamic` (string concat)
- **Exceptions:** `try`/`catch`/`finally`, exception unwinding, exception messages with `getMessage()`
- **Arrays:** Single and multi-dimensional arrays via `newarray`, `anewarray`, `multianewarray`
- **Strings:** String constants, `StringBuilder`/`StringBuffer` with chaining, string concatenation via `invokedynamic`

### Opcodes

**142 opcodes** including:
- Constants & stack: `ldc`, `bipush`, `sipush`, `dup`, `dup_x1`, `dup_x2`, `dup2`, `dup2_x1`, `dup2_x2`, `swap`, `pop`, `pop2`
- Local variables: `iload`, `aload`, `istore`, `astore`, `wide`, `iinc`
- Arithmetic: all integer, long, float, double ops (`add`, `sub`, `mul`, `div`, `rem`, `neg`)
- Bitwise & shifts: `and`, `or`, `xor`, `shl`, `shr`, `ushr`
- Type conversions: `i2l`, `f2d`, `d2i`, etc.
- Control flow: all conditional branches, `goto`, `tableswitch`, `lookupswitch`, returns
- Field access: `getstatic`, `putstatic`, `getfield`, `putfield`
- Array access: all element load/store operations
- Comparisons: numeric comparisons, reference identity (`if_acmpeq`, `if_acmpne`), null checks

### Standard Library Stubs

- **java.io.PrintStream:** `print()`, `println()` for all primitive types and `String`
- **java.lang.System:** `System.exit()`, `System.out`
- **java.lang.String:** `valueOf()` for primitives, `parseInt()`, `length()`, `charAt()`, `substring()`, `toUpperCase()`, `toLowerCase()`, and more
- **java.lang.Integer:** `parseInt()`, `valueOf()`, `toString()`
- **java.lang.StringBuilder / StringBuffer:** `append()` (all types), `toString()`, `length()`, `reverse()`, `insert()`, `delete()`, `substring()`
- **JDK Exception classes:** Auto-synthesised stubs for the exception hierarchy—`RuntimeException`, `IllegalArgumentException`, `NullPointerException`, etc.—so exception throwing and catching work without JDK class files

## Building

### Requirements

- macOS with Xcode 15 or later (Swift 5.9+)
- Standard development tools

### Build Steps

```bash
git clone <repo>
cd swiftjvm
xcodebuild -scheme swiftjvm -configuration Debug build
```

The binary will be placed in Xcode's `DerivedData/swiftjvm-*/Build/Products/Debug/swiftjvm`.

## Usage

### Running a Single Class

```bash
./swiftjvm path/to/MyProgram.class
```

The interpreter loads the class file, finds the `main([Ljava/lang/String;)V` method, and executes it. Exit code is 0 on success, 1 if an uncaught exception occurs.

### Test Harness

A convenience script compiles Java sources if needed and runs them:

```bash
./run-tests.sh              # Run all tests
./run-tests.sh TestName     # Run a single test (e.g., StringBuilderTest)
```

The script auto-discovers the latest Xcode binary, recompiles stale `.class` files, and reports pass/fail with colored output.

### Example

```java
// Hello.java
class Hello {
    public static void main(String[] args) {
        System.out.println("Hello from SwiftJVM!");
    }
}
```

```bash
javac Hello.java
./swiftjvm Hello.class
# Output: Hello from SwiftJVM!
```

## Architecture

### High-Level Structure

- **Frame.swift:** Core instruction dispatch loop; each method execution happens in a Frame with operand stack and local variables
- **Frame+*.swift:** Grouped opcode implementations (Frame+Locals, Frame+Control, Frame+Invoke, etc.)
- **Value.swift:** Enum representing all JVM value types (int, long, float, double, reference, array, string, stringBuilder)
- **Object.swift:** Runtime object wrapper with field storage
- **JVMArray.swift:** Typed array implementation
- **Thread.swift:** Execution engine managing frame stack and exception unwinding
- **Runtime.swift:** Global VM state

### Class File Parsing

- **ClassFile.swift:** Parses `.class` format (magic, version, constant pool, methods, attributes)
- **ClassConstant.swift:** Constant pool entry types (UTF-8, Method refs, Invoke Dynamic, etc.)
- **MethodInfo.swift:** Method structure including bytecode and exception tables
- **AttributeInfo.swift:** Class attributes (Code, Exceptions, BootstrapMethods, etc.)

### Execution Model

1. **Parse** the `.class` file and construct a ClassFile struct
2. **Link** classes by resolving superclass chains (deferred to avoid mutations during VM init)
3. **Execute** the main method via a Thread, which maintains a frame stack
4. **Dispatch** each bytecode instruction in the current frame's executeNextInstruction()
5. **Unwind** frames on return; **catch** exceptions via registered exception tables

## Known Limitations

### Single-Threaded

No support for `synchronized`, `monitorenter`, `monitorexit`, or threading APIs. These opcodes are no-ops.

### No JIT Compilation

The interpreter is pure bytecode dispatch—no optimization or compilation to native code. Performance is acceptable for educational purposes but far slower than the HotSpot JVM.

### Limited Standard Library

Only hand-written stubs exist. Loading real JDK class files (e.g., `java.util.HashMap`, `java.nio.*`) will fail with "class not found". Common JDK exception classes are synthesised as stubs.

### No Generics or Type Parameters

The bytecode doesn't carry generic type information, and neither does the interpreter. Type erasure is implicit.

### No Class Reflection

`java.lang.reflect.*` is not implemented. Programs cannot query class metadata at runtime.

### No GC

Objects are managed by Swift's reference counting. Circular references will not be freed. This is sufficient for short-lived test programs.

## Tests

21 automated tests cover:

- Integer and floating-point arithmetic
- Bitwise operations
- Control flow and switches
- Object creation and field access
- Arrays and multi-dimensional arrays
- String operations
- StringBuilder with chaining
- Exception throwing and catching
- Stack manipulation (dup_x1, dup_x2, dup2_x2, swap)
- Reference comparison (if_acmpeq)
- System.exit()
- Invokedynamic string concatenation
- Exception message support

Run all tests with:

```bash
./run-tests.sh
```

Expected output: **21 Passed, 0 Failed**.

## Roadmap / Future Work

### Missing Language Features

- [ ] **Reflection API** — Support `java.lang.Class` queries and `java.lang.reflect.*`
- [ ] **Interfaces** — Full interface dispatch (currently stubbed)
- [ ] **Abstract classes** — Proper inheritance model
- [ ] **Static initializers** — `<clinit>` execution
- [ ] **Enum support** — Enum class parsing and semantics
- [ ] **Annotations** — Annotation parsing and runtime visibility
- [ ] **Generics** — Type parameter support (may require bytecode metadata)

### Missing Opcodes

- [ ] **Floating-point special cases** — NaN, infinity comparisons
- [ ] **Remaining string methods** — `intern()`, `concat()` variants
- [ ] **More array operations** — `arraycopy`, bulk operations
- [ ] **Class initialization ordering** — Proper `<clinit>` sequencing across inheritance

### Standard Library

- [ ] **java.lang.Object** — `wait()`, `notify()`, `clone()` (partial)
- [ ] **java.lang.Throwable** — Stack trace generation
- [ ] **java.util** — Collections framework stubs (ArrayList, HashMap, etc.)
- [ ] **java.io** — File I/O stubs
- [ ] **java.nio** — Buffer and channel APIs

### Performance & Tooling

- [ ] **Bytecode verification** — Proper code attribute validation
- [ ] **Instruction tracing** — Debug logging of executed bytecode
- [ ] **REPL mode** — Interactive class evaluation
- [ ] **Profiling hooks** — Timing and call-graph instrumentation

## References

This implementation is based on:

- [Writing a JVM in Rust](https://andreabergia.com/blog/2023/07/i-have-written-a-jvm-in-rust/) by Andrea Bergia—excellent series on JVM internals
- [The Java Virtual Machine Specification (Java SE 21)](https://docs.oracle.com/javase/specs/jvms/se21/html/index.html)

## License

MIT License. See `LICENSE` file for details.

---

**Questions or contributions?** This is a learning project, and feedback is welcome. Feel free to open issues or submit PRs to improve the interpreter or its documentation.
