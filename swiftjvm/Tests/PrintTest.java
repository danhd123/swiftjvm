// Exercises: ldc (String), getstatic (System.out), invokevirtual (println/print)
class PrintTest {
    public static void main(String[] args) {
        // println(String)
        System.out.println("hello, world");

        // println(int)
        System.out.println(42);

        // println(long)
        System.out.println(9876543210L);

        // println(float)
        System.out.println(3.14f);

        // println(double)
        System.out.println(1.5);

        // println(boolean) — Z descriptor
        System.out.println(true);
        System.out.println(false);

        // println() — no arg, just newline
        System.out.println();

        // print without newline, then println
        System.out.print("foo");
        System.out.println("bar");
    }
}
