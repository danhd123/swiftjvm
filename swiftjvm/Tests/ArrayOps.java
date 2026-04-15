// Exercises: newarray, anewarray, arraylength,
//            iaload/iastore, laload/lastore, faload/fastore,
//            daload/dastore, aaload/aastore,
//            baload/bastore, caload/castore, saload/sastore
class ArrayOps {
    public static void main(String[] args) {
        // int array — newarray + iaload/iastore + arraylength
        int[] ints = new int[5];
        ints[2] = 42;
        if (ints[2] != 42)   { throw new RuntimeException("int store/load"); }
        if (ints.length != 5) { throw new RuntimeException("int arraylength"); }
        if (ints[0] != 0)    { throw new RuntimeException("int default"); }

        // long array
        long[] longs = new long[3];
        longs[1] = 9876543210L;
        if (longs[1] != 9876543210L) { throw new RuntimeException("long store/load"); }

        // float array
        float[] floats = new float[2];
        floats[0] = 3.14f;
        if (floats[0] != 3.14f) { throw new RuntimeException("float store/load"); }

        // double array
        double[] doubles = new double[3];
        doubles[0] = 1.5;
        if (doubles[0] != 1.5) { throw new RuntimeException("double store/load"); }

        // reference array — anewarray + aaload/aastore
        Object[] objs = new Object[4];
        if (objs.length != 4) { throw new RuntimeException("anewarray length"); }
        if (objs[0] != null)  { throw new RuntimeException("anewarray default null"); }

        // byte array — truncation to 8-bit signed
        byte[] bytes = new byte[2];
        bytes[0] = 127;
        bytes[1] = (byte) 200;          // truncates to -56
        if (bytes[0] != 127) { throw new RuntimeException("byte store 127"); }
        if (bytes[1] != -56) { throw new RuntimeException("byte truncation"); }

        // char array — 16-bit unsigned
        char[] chars = new char[2];
        chars[0] = 'A';
        if (chars[0] != 65) { throw new RuntimeException("char store/load"); }

        // short array — 16-bit signed truncation
        short[] shorts = new short[2];
        shorts[0] = 32767;
        if (shorts[0] != 32767) { throw new RuntimeException("short store/load"); }
    }
}
