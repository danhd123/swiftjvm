# Object Creation + Instance Fields Design

**Date:** 2026-04-14
**Branch:** object-creation

---

## Context

All static-world opcodes are implemented. This phase adds the object model: allocating heap objects, reading and writing instance fields, and invoking instance methods (constructors, private methods, super calls) via `invokespecial`.

---

## Opcodes Covered

| Opcode | Description |
|---|---|
| `new` | Allocate a new object, push reference |
| `aload` / `aload_0..3` | Load reference from local variable |
| `astore` / `astore_0..3` | Store reference into local variable |
| `areturn` | Return a reference value from a method |
| `getfield` | Read an instance field |
| `putfield` | Write an instance field |
| `invokespecial` | Invoke constructor, private method, or super method |

---

## Section 1: Object Representation

### `Object.swift`

Replace the current stub:

```swift
class Object {
    let clazz: ClassFile
    let fields: [Field]         // always empty — unused
    init(clazz: ClassFile) { ... }
}
```

With:

```swift
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

### `Class.swift` — `allInstanceFields()`

Walks the superclass chain bottom-up (subclass first), using `classFile.superclassName` + `findOrCreateClass` at each step rather than the `superclass: Class?` pointer (which may be nil for on-demand-loaded classes). Uses a `seen` set so subclass fields shadow same-named superclass fields.

```swift
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

---

## Section 2: `aload`, `astore`, `areturn`, `new`

### `aload_0..3` and `aload <index>`

One-liners that call the existing `pushLocal(index)` helper — identical to `iload_N` but for reference slots.

### `astore_0..3` and `astore <index>`

One-liners that call `setLocal(index, value)` — identical to `istore_N`.

### `areturn`

Pops the top of stack and returns `.returned(value)`, same as `ireturn`.

### `new`

1. Read 2-byte constant pool index → `ClassOrModuleOrPackageConstant` → class name
2. `findOrCreateClass(named: className)`
3. If `cls.clinitNeedsToBeRun`: set to false, back up `pc` by 3, return `.invoke(clinitFrame)`
4. Allocate `Object(clazz: cls)` — populates `instanceFields` with zero defaults
5. Push `.reference(object)` onto operand stack
6. Return `.continue`

The object is uninitialized at this point. The immediately following `invokespecial <init>` fills in actual field values via `putfield` calls inside the constructor body.

---

## Section 3: `getfield` and `putfield`

Same constant pool resolution as `getstatic`/`putstatic` (FieldRef → class name + field name). No clinit needed — `new` already triggered it.

### `getfield`

1. Resolve field name from constant pool
2. Pop `objectref` — fatalError if nil (NullPointerException; exceptions not yet implemented)
3. Push `obj.instanceFields[fieldName]!`

### `putfield`

1. Resolve field name from constant pool
2. Pop `value`, then pop `objectref` — fatalError if nil
3. `obj.instanceFields[fieldName] = value`

---

## Section 4: `invokespecial`

Covers constructors (`<init>`), private methods, and `super.foo()` calls. All three use identical mechanics: resolution is by the *class named in the constant pool*, not the runtime class of `this`. This is what makes super dispatch correct — `super.foo()` emits `invokespecial Animal.foo` regardless of the actual subclass.

### Execution steps

1. Read 2-byte constant pool index; resolve class name, method name, descriptor — same pattern as `invokestatic`
2. Parse arg count from descriptor (does **not** include `this`)
3. Pop args in reverse order, then pop `this` objectref
4. `findOrCreateClass(named: resolvedClassName)` — the constant pool class, not the runtime class of `this`
5. `findMethod(named:descriptor:)` on that class; if not found, walk the superclass chain via `classFile.superclassName` + `findOrCreateClass` until found or chain exhausted
6. Run `<clinit>` with the pc-rewind trick if needed
7. Build `Frame(owningClass: cls, method: calleeMethod, arguments: [thisValue] + args)` — `this` lands in slot 0; wide-type slot layout rules apply as usual
8. Return `.invoke(frame:)`

For `<init>`: `this` is already a fully allocated `Object` (created by the preceding `new`). The constructor body mutates `instanceFields` via `putfield` calls. No special constructor handling is needed beyond step 7.

---

## Test File: `ObjectCreation.java`

```java
class ObjectCreation {
    int x;
    int y;
    long id;

    ObjectCreation(int x, int y, long id) {
        this.x = x;          // putfield
        this.y = y;
        this.id = id;
    }

    int sumXY() {
        return x + y;        // getfield x2, iadd
    }

    static ObjectCreation make(int x, int y, long id) {
        return new ObjectCreation(x, y, id);  // new, dup, invokespecial <init>, areturn
    }

    public static void main(String[] args) {
        ObjectCreation o = make(3, 4, 100L);
        o.sumXY();           // expect 7
    }
}
```

Exercises: `new`, `dup` (already implemented), `invokespecial <init>`, `putfield`, `getfield`, `aload_0`, `areturn`, `invokespecial` instance method.

---

## Files Modified

| File | Change |
|---|---|
| `swiftjvm/Runtime/Object.swift` | Replace stub with `Class` ref + `instanceFields` dict |
| `swiftjvm/Runtime/Class.swift` | Add `allInstanceFields()` helper |
| `swiftjvm/Runtime/Frame.swift` | Add `aload`/`astore`/`areturn`/`new`/`getfield`/`putfield`/`invokespecial` cases |
| `swiftjvm/Tests/ObjectCreation.java` | New smoke test |

---

## Verification

```bash
cd /Users/danielhd/src/swiftjvm
javac swiftjvm/Tests/ObjectCreation.java -d swiftjvm/Tests
xcodebuild -project swiftjvm.xcodeproj -scheme swiftjvm -configuration Debug build
./path/to/swiftjvm swiftjvm/Tests/ObjectCreation.class   # expect exit 0
```
