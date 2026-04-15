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

    // Static helper: exercises getfield without needing invokevirtual
    static int sumXY(ObjectCreation o) {
        return o.x + o.y;   // getfield x2, iadd, ireturn
    }

    static ObjectCreation make(int x, int y, long id) {
        return new ObjectCreation(x, y, id); // new, dup, invokespecial <init>, areturn
    }

    public static void main(String[] args) {
        ObjectCreation o = make(3, 4, 100L);
        sumXY(o);           // invokestatic, getfield x2 — expect 7
    }
}
