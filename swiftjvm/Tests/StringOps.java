// Exercises: String instance methods, String.valueOf static methods
class StringOps {
    static void check(boolean cond, String label) {
        if (!cond) { throw new RuntimeException(label); }
    }

    public static void main(String[] args) {
        // length / isEmpty
        check("hello".length() == 5, "length");
        check("".isEmpty(), "isEmpty");
        check(!"x".isEmpty(), "!isEmpty");

        // charAt
        check("abc".charAt(0) == 'a', "charAt 0");
        check("abc".charAt(2) == 'c', "charAt 2");

        // equals / equalsIgnoreCase
        check("foo".equals("foo"), "equals true");
        check(!"foo".equals("bar"), "equals false");
        check("Foo".equalsIgnoreCase("fOO"), "equalsIgnoreCase");

        // startsWith / endsWith / contains
        check("hello".startsWith("hel"), "startsWith");
        check("hello".endsWith("llo"), "endsWith");
        check("hello".contains("ell"), "contains");

        // indexOf
        check("hello".indexOf("ll") == 2, "indexOf str");
        check("hello".indexOf('e') == 1, "indexOf char");
        check("hello".indexOf('z') == -1, "indexOf miss");

        // substring
        check("hello".substring(2).equals("llo"), "substring 1-arg");
        check("hello".substring(1, 4).equals("ell"), "substring 2-arg");

        // concat
        check("foo".concat("bar").equals("foobar"), "concat");

        // case
        check("Hello".toUpperCase().equals("HELLO"), "toUpperCase");
        check("Hello".toLowerCase().equals("hello"), "toLowerCase");

        // trim
        check("  hi  ".trim().equals("hi"), "trim");

        // String.valueOf
        check(String.valueOf(42).equals("42"), "valueOf int");
        check(String.valueOf(3L).equals("3"), "valueOf long");
        check(String.valueOf(true).equals("true"), "valueOf bool");

        System.out.println("StringOps OK");
    }
}
