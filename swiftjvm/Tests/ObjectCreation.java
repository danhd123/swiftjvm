// ObjectCreation.java — exercises new, invokespecial, getfield, putfield, areturn
class ObjectCreation {
    int x;
    int y;
    long id;

    ObjectCreation(int x, int y, long id) {
        this.x  = x;        // aload_0, iload_1, putfield
        this.y  = y;        // aload_0, iload_2, putfield
        this.id = id;       // aload_0, lload_3, putfield
    }

    int sumXY() {
        return x + y;       // aload_0, getfield x2, iadd, ireturn
    }

    static ObjectCreation make(int x, int y, long id) {
        return new ObjectCreation(x, y, id); // new, dup, invokespecial <init>, areturn
    }

    public static void main(String[] args) {
        ObjectCreation o = make(3, 4, 100L);
        o.sumXY();          // expect 7
    }
}
