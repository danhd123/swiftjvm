// NumericOps.java — smoke test for long/float/double arithmetic
class NumericOps {
    static long factorial(int n) {
        long result = 1L;
        for (int i = 1; i <= n; i++) result *= (long)i;
        return result;
    }

    static double sumSquares(double a, double b) {
        return a * a + b * b;
    }

    public static void main(String[] args) {
        factorial(10);         // 3628800
        sumSquares(3.0, 4.0);  // 25.0
    }
}
