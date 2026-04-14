// FloatOps.java — exercises float, remaining double, and type-conversion opcodes
class FloatOps {

    // fconst_0, fconst_1, fconst_2; fstore_2/3/indexed; fload_2/3/indexed; fadd
    static float addWithConsts(float a, float b) {
        float zero = 0.0f;  // fconst_0 → fstore_2
        float one  = 1.0f;  // fconst_1 → fstore_3
        float two  = 2.0f;  // fconst_2 → fstore 4 (indexed)
        return a + b + zero + one + two;
    }

    // ldc (float literal not representable by fconst); fsub, fmul, fdiv, frem, fneg; freturn
    static float moreArith(float a, float b) {
        float pi = 3.14159f;   // ldc (float from constant pool)
        return (a - b) * (a / b) + (a % b) + (-a) + pi;
    }

    // fcmpl (val < lo  →  fcmpl + ifge)
    // fcmpg (val > hi  →  fcmpg + ifle)
    static float clamp(float val, float lo, float hi) {
        if (val < lo) return lo;
        if (val > hi) return hi;
        return val;
    }

    // i2f, f2i, f2l, f2d, l2f, d2f
    static float  fromInt(int i)       { return (float)  i; }
    static int    toInt(float f)       { return (int)    f; }
    static long   toLong(float f)      { return (long)   f; }
    static double toDouble(float f)    { return (double) f; }
    static float  fromLong(long l)     { return (float)  l; }
    static float  fromDouble(double d) { return (float)  d; }

    // dconst_0, dconst_1; dstore_0, dstore_2 (no-arg static → slots 0/2); dload_0, dload_2
    static double localDoubles() {
        double a = 1.0;   // dconst_1 → dstore_0
        double b = 0.0;   // dconst_0 → dstore_2
        return a + b;
    }

    // dstore_1, dload_1 (int param pushes double to slot 1)
    static double doubleAtOne(int x) {
        double a = 1.0;   // dconst_1 → dstore_1 (x occupies slot 0)
        return a + x;     // dload_1, i2d, dadd
    }

    // dsub, ddiv, drem, dneg; indexed dstore/dload (locals after category-2 args)
    static double doubleArith(double a, double b) {
        return (a - b) + (a / b) + (a % b) + (-a);
    }

    // dcmpl (a < b  →  dcmpl + ifge)
    // dcmpg (a > b  →  dcmpg + ifle)
    static int compareDoubles(double a, double b) {
        if (a < b) return -1;
        if (a > b) return  1;
        return 0;
    }

    // d2i, d2l; i2d, l2d, l2i
    static int    doubleToInt(double d)    { return (int)    d; }
    static long   doubleToLong(double d)   { return (long)   d; }
    static double intToDouble(int i)       { return (double) i; }
    static double longToDouble(long l)     { return (double) l; }
    static int    longToInt(long l)        { return (int)    l; }

    // i2b, i2c, i2s (int-narrowing conversions)
    static byte  toByte(int i)  { return (byte)  i; }
    static char  toChar(int i)  { return (char)  i; }
    static short toShort(int i) { return (short) i; }

    public static void main(String[] args) {
        addWithConsts(3.0f, 4.0f);
        moreArith(7.0f, 2.0f);
        clamp(10.0f, 0.0f, 5.0f);
        clamp(-1.0f, 0.0f, 5.0f);
        clamp(3.0f, 0.0f, 5.0f);
        fromInt(42);
        toInt(3.7f);
        toLong(3.7f);
        toDouble(3.7f);
        fromLong(100L);
        fromDouble(3.14);
        localDoubles();
        doubleAtOne(5);
        doubleArith(10.0, 3.0);
        compareDoubles(1.0, 2.0);
        compareDoubles(2.0, 2.0);
        compareDoubles(3.0, 2.0);
        doubleToInt(3.7);
        doubleToLong(3.7);
        intToDouble(42);
        longToDouble(100L);
        longToInt(100L);
        toByte(200);
        toChar(65);
        toShort(50000);
    }
}
