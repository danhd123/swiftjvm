// swiftjvm/Tests/MultiArrayTest.java
class MultiArrayTest {
    public static void main(String[] args) {
        // 2D int array — generates: multianewarray [[I 2
        int[][] matrix = new int[3][4];
        System.out.println(matrix.length);    // 3
        System.out.println(matrix[0].length); // 4
        System.out.println(matrix[1][2]);     // 0  (default)
        matrix[1][2] = 42;
        System.out.println(matrix[1][2]);     // 42
        System.out.println(matrix[0][0]);     // 0  (untouched)

        // 3D array — generates: multianewarray [[[I 3
        int[][][] cube = new int[2][3][4];
        System.out.println(cube.length);       // 2
        System.out.println(cube[0].length);    // 3
        System.out.println(cube[0][0].length); // 4
        cube[1][2][3] = 7;
        System.out.println(cube[1][2][3]);     // 7

        System.out.println("MultiArrayTest OK");
    }
}
