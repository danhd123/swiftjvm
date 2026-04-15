// swiftjvm/Tests/StringConcatTest.java
class StringConcatTest {
    public static void main(String[] args) {
        // Simple dynamic concat — generates invokedynamic makeConcatWithConstants
        int i = 42;
        String s1 = "value=" + i;
        System.out.println(s1);          // value=42

        double d = 3.14;
        String s2 = "pi=" + d;
        System.out.println(s2);          // pi=3.14

        String name = "world";
        String s3 = "hello " + name + "!";
        System.out.println(s3);          // hello world!

        // Numeric + numeric
        int a = 1, b = 2;
        System.out.println("sum=" + (a + b)); // sum=3

        // Null reference
        Object o = null;
        System.out.println("o=" + o);   // o=null

        System.out.println("StringConcatTest OK");
    }
}
