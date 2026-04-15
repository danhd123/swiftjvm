// swiftjvm/Tests/RefCompareTest.java
class RefObj {}

class RefCompareTest {
    public static void main(String[] args) {
        RefObj a = new RefObj();
        RefObj b = a;            // same object
        RefObj c = new RefObj(); // different object

        // if_acmpeq: branch if two references are identical
        System.out.println(a == b ? "true" : "false"); // true
        System.out.println(a == c ? "true" : "false"); // false

        // if_acmpne: branch if two references differ
        System.out.println(a != c ? "true" : "false"); // true
        System.out.println(b != c ? "true" : "false"); // true

        // Both same → not-equal is false
        System.out.println(a != b ? "true" : "false"); // false

        System.out.println("RefCompareTest OK");
    }
}
