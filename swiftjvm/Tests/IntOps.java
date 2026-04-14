// IntOps.java — exercises remaining integer and long opcode gaps
class IntOps {

    // iconst_m1, iconst_0, iconst_3, iconst_4, iconst_5, sipush
    // istore_0..3 + indexed istore; iload_0..3 + indexed iload
    static int constants() {
        int a = -1;    // iconst_m1 → istore_0
        int b = 0;     // iconst_0  → istore_1
        int c = 3;     // iconst_3  → istore_2
        int d = 4;     // iconst_4  → istore_3
        int e = 5;     // iconst_5  → istore 4 (indexed)
        int f = 1000;  // sipush    → istore 5 (indexed)
        return a + b + c + d + e + f;
    }

    // imul, idiv, irem, ineg
    static int arithmetic(int a, int b) {
        return (a * b) + (a / b) + (a % b) + (-a);
    }

    // Zero-compare branches (javac inverts to branch-past-body):
    //   if (x != 0) → ifeq   if (x == 0) → ifne
    //   if (x >= 0) → iflt   if (x <  0) → ifge
    //   if (x <= 0) → ifgt   if (x >  0) → ifle
    static int classify(int x) {
        if (x == 0) return 0;   // ifne  (branch past body if x != 0)
        if (x != 0) return 1;   // ifeq
        if (x >= 0) return 2;   // iflt
        if (x <  0) return 3;   // ifge
        if (x <= 0) return 4;   // ifgt
        if (x >  0) return 5;   // ifle
        return -1;
    }

    // Two-operand int branches (if_icmpgt already exercised by NumericOps):
    //   if (a != b) → if_icmpeq   if (a == b) → if_icmpne
    //   if (a >= b) → if_icmplt   if (a <  b) → if_icmpge
    //   if (a <= b) → if_icmpgt   if (a >  b) → if_icmple
    static void intBranches(int a, int b) {
        if (a != b) return;   // if_icmpeq
        if (a == b) return;   // if_icmpne
        if (a >= b) return;   // if_icmplt
        if (a <  b) return;   // if_icmpge
        if (a <= b) return;   // if_icmpgt
        if (a >  b) return;   // if_icmple
    }

    // lcmp; ladd, lsub, ldiv, lrem, lneg
    // Also exercises lload_0, lload_2 (category-2 args at slots 0 and 2)
    // and indexed lstore/lload for local results
    static long longArith(long a, long b) {
        return (a + b) - (a / b) + (a % b) + (-a);
    }

    // lcmp via branching (lcmp + ifge / lcmp + ifle)
    static int longCompare(long a, long b) {
        if (a < b) return -1;   // lcmp + ifge
        if (a > b) return  1;   // lcmp + ifle
        return 0;
    }

    public static void main(String[] args) {
        constants();
        arithmetic(10, 3);
        classify(0);
        classify(5);
        classify(-5);
        intBranches(1, 2);
        intBranches(2, 2);
        intBranches(3, 2);
        longArith(20L, 3L);
        longCompare(5L, 3L);
        longCompare(3L, 5L);
        longCompare(3L, 3L);
    }
}
