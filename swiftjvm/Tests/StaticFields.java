// StaticFields.java — exercises getstatic, putstatic, and static initializers
class StaticFields {
    static int   counter = 0;
    static long  total   = 0L;
    static float ratio   = 0.0f;

    static void increment(int n) {
        counter += n;                       // getstatic, iadd, putstatic
        total   += n;                       // getstatic, i2l, ladd, putstatic
        ratio    = (float) counter / n;     // getstatic, i2f, fdiv, putstatic
    }

    static int   getCounter() { return counter; }   // getstatic, ireturn
    static long  getTotal()   { return total;   }   // getstatic, lreturn
    static float getRatio()   { return ratio;   }   // getstatic, freturn

    public static void main(String[] args) {
        increment(5);
        increment(3);
        getCounter();   // 8
        getTotal();     // 8L
        getRatio();     // 8.0f / 3 ≈ 2.666...
    }
}
