// swiftjvm/Tests/StringBuilderTest.java
class StringBuilderTest {
    public static void main(String[] args) {
        // basic append and toString
        StringBuilder sb = new StringBuilder();
        sb.append("hello");
        sb.append(" world");
        sb.append(42);
        System.out.println(sb.toString());       // hello world42

        // constructor with initial String, chained append
        String s = new StringBuilder("prefix-").append("suffix").toString();
        System.out.println(s);                   // prefix-suffix

        // length()
        System.out.println(new StringBuilder("abc").length()); // 3

        // various primitive append types
        StringBuilder sb2 = new StringBuilder();
        sb2.append(true).append(" ").append('X').append(" ").append(3.14);
        System.out.println(sb2.toString());      // true X 3.14

        // long and float
        StringBuilder sb3 = new StringBuilder();
        sb3.append(100L).append(" ").append(2.5f);
        System.out.println(sb3.toString());      // 100 2.5

        System.out.println("StringBuilderTest OK");
    }
}
