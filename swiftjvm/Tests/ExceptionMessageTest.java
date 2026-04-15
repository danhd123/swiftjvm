// swiftjvm/Tests/ExceptionMessageTest.java
class ExceptionMessageTest {
    static void checkMessage() {
        try {
            throw new RuntimeException("something went wrong");
        } catch (RuntimeException e) {
            System.out.println(e.getMessage());          // something went wrong
            System.out.println(e.getLocalizedMessage()); // something went wrong
        }
    }

    static void checkNoMessage() {
        try {
            throw new IllegalArgumentException("bad arg");
        } catch (Exception e) {
            System.out.println(e.getMessage());          // bad arg
        }
    }

    static void checkNullMessage() {
        try {
            throw new RuntimeException();
        } catch (RuntimeException e) {
            System.out.println(e.getMessage() == null ? "null" : e.getMessage()); // null
        }
    }

    public static void main(String[] args) {
        checkMessage();
        checkNoMessage();
        checkNullMessage();
        System.out.println("ExceptionMessageTest OK");
    }
}
