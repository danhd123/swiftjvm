# Object Creation + Instance Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement object allocation, instance field read/write, and `invokespecial` (constructors, private methods, super dispatch) so the interpreter can run basic OO Java programs.

**Architecture:** `Object` is upgraded from a stub to a live heap object with a `[String: Value]` instance-field dictionary, mirroring the `staticFields` pattern on `Class`. Seven new opcode groups are added to `Frame.swift`'s existing switch — `aload`/`astore`/`areturn`, `new`, `getfield`/`putfield`, and `invokespecial` — each following the exact same constant-pool resolution pattern as `invokestatic`.

**Tech Stack:** Swift 5, Xcode project (xcodebuild), javac for test compilation.

---

## File Map

| File | Change |
|---|---|
| `swiftjvm/Runtime/Object.swift` | Replace stub: `clazz: Class`, add `instanceFields: [String: Value]` |
| `swiftjvm/Runtime/Class.swift` | Add `allInstanceFields() -> [FieldInfo]` helper |
| `swiftjvm/Runtime/Frame.swift` | Add 7 opcode groups before the `default:` fatalError |
| `swiftjvm/Tests/ObjectCreation.java` | New smoke test |

---

### Task 1: Add `allInstanceFields()` to Class.swift

**Files:**
- Modify: `swiftjvm/Runtime/Class.swift`

`allInstanceFields()` must exist before `Object.swift` is updated, because `Object.init` calls it. Add it first.

`allInstanceFields()` walks the class hierarchy bottom-up using `classFile.superclassName` + `findOrCreateClass` at each step — **not** the `superclass: Class?` pointer, which may be nil for classes loaded on-demand. A `seen` set ensures subclass fields shadow same-named superclass fields.

- [ ] **Step 1: Add helper after `findStaticField`**

In `Class.swift`, insert after the existing `findStaticField(named:)` method and before `findMethod(named:descriptor:)`:

```swift
    /// Returns all instance (non-static) fields declared on this class and every
    /// superclass, walking the hierarchy bottom-up so subclass fields come first.
    /// Uses classFile.superclassName + findOrCreateClass at each step so the
    /// superclass chain is force-loaded even if the Class.superclass pointer is nil.
    func allInstanceFields() -> [FieldInfo] {
        var seen = Set<String>()
        var result: [FieldInfo] = []
        var current: Class? = self
        while let cls = current {
            for f in cls.classFile.fields
                where f.accessFlags.rawValue & FieldInfo.AccessFlags.Static.rawValue == 0
                   && seen.insert(f.name.string as String).inserted {
                result.append(f)
            }
            let superName = cls.classFile.superclassName
            guard !superName.isEmpty && superName != "java/lang/Object" else { break }
            if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                current = s
            } else { break }
        }
        return result
    }
```

- [ ] **Step 2: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Class.swift
git commit -m "Add Class.allInstanceFields() for instance field layout"
```

---

### Task 2: Update Object.swift

**Files:**
- Modify: `swiftjvm/Runtime/Object.swift`

The current `Object` holds a `ClassFile` and an always-empty `[Field]` array. Replace both with a `Class` reference and a `[String: Value]` instance-fields dictionary populated by `allInstanceFields()` (added in Task 1).

- [ ] **Step 1: Rewrite Object.swift**

Replace the entire file content with:

```swift
//
//  Object.swift
//  swiftjvm
//

import Foundation

class Object {
    let clazz: Class
    var instanceFields: [String: Value]

    init(clazz: Class) {
        self.clazz = clazz
        var fields: [String: Value] = [:]
        for field in clazz.allInstanceFields() {
            let desc = field.descriptor.string as String
            let defaultValue: Value
            switch desc.first {
            case "J":        defaultValue = .long(0)
            case "F":        defaultValue = .float(0)
            case "D":        defaultValue = .double(0)
            case "L", "[":   defaultValue = .reference(nil)
            default:         defaultValue = .int(0)   // I B C S Z
            }
            fields[field.name.string as String] = defaultValue
        }
        self.instanceFields = fields
    }
}
```

- [ ] **Step 2: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Object.swift
git commit -m "Replace Object stub with instanceFields dictionary"
```

---

### Task 3: Add `aload`, `astore`, `areturn` to Frame.swift

**Files:**
- Modify: `swiftjvm/Runtime/Frame.swift`

All three groups reuse existing `pushLocal` / `setLocal` / `pop` helpers — they are one-liners identical in structure to `iload_N`, `istore_N`, and `ireturn`.

- [ ] **Step 1: Locate the insertion point**

Find the comment `// ── static fields` near the top of the opcode switch in `Frame.swift`. Insert the new reference load/store/return section immediately **before** that comment.

- [ ] **Step 2: Insert the three opcode groups**

```swift
        // ── reference loads ───────────────────────────────────────────────────
        case .aload:
            let index = Int(code[pc]); pc += 1
            pushLocal(index)
            return .continue
        case .aload_0: pushLocal(0); return .continue
        case .aload_1: pushLocal(1); return .continue
        case .aload_2: pushLocal(2); return .continue
        case .aload_3: pushLocal(3); return .continue

        // ── reference stores ──────────────────────────────────────────────────
        case .astore:
            let index = Int(code[pc]); pc += 1
            setLocal(index, pop())
            return .continue
        case .astore_0: setLocal(0, pop()); return .continue
        case .astore_1: setLocal(1, pop()); return .continue
        case .astore_2: setLocal(2, pop()); return .continue
        case .astore_3: setLocal(3, pop()); return .continue

        // ── reference return ──────────────────────────────────────────────────
        case .areturn:
            return .returned(pop())
```

- [ ] **Step 3: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Frame.swift
git commit -m "Add aload, astore, areturn opcodes"
```

---

### Task 4: Add `new` opcode to Frame.swift

**Files:**
- Modify: `swiftjvm/Runtime/Frame.swift`

`new` reads a `ClassOrModuleOrPackageConstant` from the constant pool (not a FieldRef — there is no name-and-type here), allocates an `Object`, and pushes the reference. Clinit is triggered with the pc-rewind trick if needed.

- [ ] **Step 1: Insert `new` case before `// ── method invocation`**

```swift
        // ── object creation ───────────────────────────────────────────────────
        case .new:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let classConst = constantPool[index] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant
            else { fatalError("new: malformed constant pool at \(index)") }
            let className = classNameConst.string as String
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("new: class not found: \(className)")
            }
            if cls.clinitNeedsToBeRun, let clinit = cls.clinit {
                cls.clinitNeedsToBeRun = false
                pc -= 3
                return .invoke(frame: Frame(owningClass: cls, method: clinit, arguments: []))
            }
            push(.reference(Object(clazz: cls)))
            return .continue
```

- [ ] **Step 2: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Frame.swift
git commit -m "Add new opcode — object allocation"
```

---

### Task 5: Add `getfield` and `putfield` to Frame.swift

**Files:**
- Modify: `swiftjvm/Runtime/Frame.swift`

Same constant pool resolution as `getstatic`/`putstatic`. Key differences: pop an object reference, fatalError on null, read/write `obj.instanceFields[fieldName]`. No clinit needed here — `new` already triggered it.

- [ ] **Step 1: Insert `getfield` and `putfield` after the `new` case**

```swift
        case .getfield:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("getfield: malformed constant pool at \(index)") }
            let fieldName = nameConst.string as String
            guard let objOptional = pop().asReference else {
                fatalError("getfield: expected reference on stack for field \(fieldName)")
            }
            guard let obj = objOptional else {
                fatalError("getfield: NullPointerException — null objectref for field \(fieldName)")
            }
            guard let value = obj.instanceFields[fieldName] else {
                fatalError("getfield: field not found: \(fieldName) in \(obj.clazz.name)")
            }
            push(value)
            return .continue

        case .putfield:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let fieldRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let nameAndType = constantPool[fieldRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant
            else { fatalError("putfield: malformed constant pool at \(index)") }
            let fieldName = nameConst.string as String
            let value = pop()
            guard let objOptional = pop().asReference else {
                fatalError("putfield: expected reference on stack for field \(fieldName)")
            }
            guard let obj = objOptional else {
                fatalError("putfield: NullPointerException — null objectref for field \(fieldName)")
            }
            obj.instanceFields[fieldName] = value
            return .continue
```

- [ ] **Step 2: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Frame.swift
git commit -m "Add getfield and putfield opcodes"
```

---

### Task 6: Add `invokespecial` to Frame.swift

**Files:**
- Modify: `swiftjvm/Runtime/Frame.swift`

`invokespecial` covers constructors, private methods, and `super.foo()`. Resolution uses the **constant pool class** (not the runtime class of `this`), which is what makes super dispatch correct. Method lookup walks the superclass chain via `classFile.superclassName` + `findOrCreateClass` if not found directly. `this` lands in slot 0; args follow.

Note: clinit is intentionally **not** triggered here. For `<init>` calls `new` already ran it; for private/super calls `this` already exists so the class is initialized.

- [ ] **Step 1: Insert `invokespecial` before `invokestatic` in Frame.swift**

```swift
        // ── invokespecial ─────────────────────────────────────────────────────
        case .invokespecial:
            let hi = Int(code[pc]); pc += 1
            let lo = Int(code[pc]); pc += 1
            let index = UInt16(hi << 8 | lo)
            guard let methodRef = constantPool[index] as? MethodOrFieldRefConstant,
                  let classConst = constantPool[methodRef.classIndex] as? ClassOrModuleOrPackageConstant,
                  let classNameConst = constantPool[classConst.nameIndex] as? Utf8Constant,
                  let nameAndType = constantPool[methodRef.nameAndTypeIndex] as? NameAndTypeConstant,
                  let nameConst = constantPool[nameAndType.nameIndex] as? Utf8Constant,
                  let descConst = constantPool[nameAndType.descriptorIndex] as? Utf8Constant
            else { fatalError("invokespecial: malformed constant pool at \(index)") }
            let className  = classNameConst.string as String
            let methodName = nameConst.string as String
            let descriptor = descConst.string as String
            let argCount   = parseArgumentCount(descriptor: descriptor)
            // Pop args in reverse, then pop 'this' — this lands in slot 0.
            let args: [Value] = (0..<argCount).map { _ in pop() }.reversed()
            let thisValue = pop()
            guard case .success(let cls) = Runtime.vm.findOrCreateClass(named: className), let cls else {
                fatalError("invokespecial: class not found: \(className)")
            }
            // Walk the superclass chain from the resolved class upward.
            var calleeMethod: MethodInfo? = nil
            var searchCls: Class? = cls
            while let c = searchCls {
                if let m = c.findMethod(named: methodName, descriptor: descriptor) {
                    calleeMethod = m
                    break
                }
                let superName = c.classFile.superclassName
                guard !superName.isEmpty && superName != "java/lang/Object" else { break }
                if case .success(let s) = Runtime.vm.findOrCreateClass(named: superName) {
                    searchCls = s
                } else { break }
            }
            guard let calleeMethod else {
                fatalError("invokespecial: method not found: \(methodName)\(descriptor) in \(className)")
            }
            let calleeFrame = Frame(
                owningClass: cls,
                method: calleeMethod,
                arguments: [thisValue] + args
            )
            return .invoke(frame: calleeFrame)
```

- [ ] **Step 2: Build**

```bash
cd /Users/danielhd/src/swiftjvm
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build 2>&1 | grep -E "BUILD (SUCCEEDED|FAILED)|error:"
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Runtime/Frame.swift
git commit -m "Add invokespecial — constructors, private methods, super dispatch"
```

---

### Task 7: Write the test, compile, and run

**Files:**
- Create: `swiftjvm/Tests/ObjectCreation.java`

- [ ] **Step 1: Create ObjectCreation.java**

```java
// ObjectCreation.java — exercises new, invokespecial, getfield, putfield, areturn
class ObjectCreation {
    int x;
    int y;
    long id;

    ObjectCreation(int x, int y, long id) {
        this.x  = x;        // aload_0, iload_1, putfield
        this.y  = y;        // aload_0, iload_2, putfield
        this.id = id;       // aload_0, lload_3, putfield
    }

    int sumXY() {
        return x + y;       // aload_0, getfield x2, iadd, ireturn
    }

    static ObjectCreation make(int x, int y, long id) {
        return new ObjectCreation(x, y, id); // new, dup, invokespecial <init>, areturn
    }

    public static void main(String[] args) {
        ObjectCreation o = make(3, 4, 100L);
        o.sumXY();          // expect 7
    }
}
```

- [ ] **Step 2: Compile**

```bash
cd /Users/danielhd/src/swiftjvm
javac swiftjvm/Tests/ObjectCreation.java -d swiftjvm/Tests
echo "javac exit: $?"
```

Expected: `javac exit: 0`

- [ ] **Step 3: Run through the interpreter**

```bash
SWIFTJVM=/Users/danielhd/Library/Developer/Xcode/DerivedData/swiftjvm-eiykhhbhrkqiijfjgyrvmxngirjf/Build/Products/Debug/swiftjvm
cd /Users/danielhd/src/swiftjvm/swiftjvm/Tests
"$SWIFTJVM" ObjectCreation.class
echo "exit: $?"
```

Expected: `exit: 0`

- [ ] **Step 4: Regression check all previous tests**

```bash
SWIFTJVM=/Users/danielhd/Library/Developer/Xcode/DerivedData/swiftjvm-eiykhhbhrkqiijfjgyrvmxngirjf/Build/Products/Debug/swiftjvm
cd /Users/danielhd/src/swiftjvm/swiftjvm/Tests
for f in NumericOps IntOps FloatOps BitwiseOps StaticFields; do
    "$SWIFTJVM" "$f.class"
    echo "$f: $?"
done
```

Expected: all five print `0`.

- [ ] **Step 5: Commit**

```bash
cd /Users/danielhd/src/swiftjvm
git add swiftjvm/Tests/ObjectCreation.java swiftjvm/Tests/ObjectCreation.class
git commit -m "Add ObjectCreation smoke test"
```
