// BitwiseOps.java — exercises bitwise and shift opcodes
class BitwiseOps {
    static int intBitwise(int a, int b) {
        return (a & b) | (a ^ b);               // iand, ior, ixor
    }

    static int intShifts(int x, int n) {
        return (x << n) + (x >> n) + (x >>> n); // ishl, ishr, iushr
    }

    static long longBitwise(long a, long b) {
        return (a & b) | (a ^ b);               // land, lor, lxor
    }

    static long longShifts(long x, int n) {
        return (x << n) + (x >> n) + (x >>> n); // lshl, lshr, lushr
    }

    public static void main(String[] args) {
        intBitwise(0b1100, 0b1010);    // (8) | (6) = 14
        intShifts(1024, 3);            // 8192 + 128 + 128 = 8448
        longBitwise(0b1100L, 0b1010L);
        longShifts(1024L, 3);
    }
}
