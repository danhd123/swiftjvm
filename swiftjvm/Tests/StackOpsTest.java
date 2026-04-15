// swiftjvm/Tests/StackOpsTest.java
class StackBox { int field; long longField; }

class StackOpsTest {
    public static void main(String[] args) {
        // dup_x1: obj.field = v where the assigned value is also used
        // Bytecode: aload obj, iconst 42, dup_x1, putfield, istore x
        StackBox obj = new StackBox();
        int x = (obj.field = 42);
        System.out.println(x);         // 42
        System.out.println(obj.field); // 42

        // dup_x2 Form 1: arr[i] = v where all three operands are cat-1
        // Bytecode: aload arr, iconst_1, bipush 99, dup_x2, iastore, istore y
        int[] arr = new int[3];
        int y = (arr[1] = 99);
        System.out.println(y);       // 99
        System.out.println(arr[1]);  // 99

        // dup2_x1 Form 2: obj.longField = lv (cat-2 value, cat-1 objectref)
        // Bytecode: aload obj, ldc2_w 100L, dup2_x1, putfield, lstore lv
        long lv = (obj.longField = 100L);
        System.out.println(lv);            // 100
        System.out.println(obj.longField); // 100

        // dup2_x2 Form 2: larr[0] = lv (cat-2 value, two cat-1 operands under it)
        // Bytecode: aload larr, iconst_0, ldc2_w 200L, dup2_x2, lastore, lstore lz
        long[] larr = new long[3];
        long lz = (larr[0] = 200L);
        System.out.println(lz);      // 200
        System.out.println(larr[0]); // 200

        System.out.println("StackOpsTest OK");
    }
}
