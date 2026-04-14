// Fib.java
class Fib {
    static int fib(int n) {
        if (n <= 1) return n;
        return fib(n - 1) + fib(n - 2);
    }
    public static void main(String[] args) {
        fib(10); // should return 55 without crashing
    }
}
