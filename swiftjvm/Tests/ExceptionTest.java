// Exercises: athrow, exception table lookup, stack unwinding, catch
class MyException extends Throwable {
    MyException() {}
}

class AnotherException extends Throwable {
    AnotherException() {}
}

class ExceptionTest {
    static void risky() throws MyException {
        throw new MyException();
    }

    static void maybeSafe(boolean doThrow) throws MyException {
        if (doThrow) {
            throw new MyException();
        }
        System.out.println("no throw");
    }

    public static void main(String[] args) throws AnotherException {
        // basic catch after throw through a method call (stack unwinding)
        try {
            risky();
            System.out.println("FAIL: should have thrown");
        } catch (MyException e) {
            System.out.println("caught");
        }

        // catch does not fire when no exception is thrown
        try {
            maybeSafe(false);
        } catch (MyException e) {
            System.out.println("FAIL: spurious catch");
        }

        // catch fires when exception thrown inside same try
        try {
            maybeSafe(true);
            System.out.println("FAIL: should have thrown");
        } catch (MyException e) {
            System.out.println("caught direct");
        }

        // throw directly inside the try block (handler in same frame)
        try {
            throw new MyException();
        } catch (MyException e) {
            System.out.println("caught inline");
        }

        System.out.println("done");
    }
}
