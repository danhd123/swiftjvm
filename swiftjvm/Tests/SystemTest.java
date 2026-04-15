// swiftjvm/Tests/SystemTest.java
class SystemTest {
    public static void main(String[] args) {
        System.out.println("before exit");
        System.exit(0);
        System.out.println("after exit"); // must not print
    }
}
