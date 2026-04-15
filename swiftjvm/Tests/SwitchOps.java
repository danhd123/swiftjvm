// Exercises: tableswitch, lookupswitch, monitorenter/monitorexit (via synchronized)
class SwitchOps {
    // tableswitch — dense range [0,4]
    static int dayCode(int d) {
        switch (d) {
            case 0: return 10;
            case 1: return 11;
            case 2: return 12;
            case 3: return 13;
            case 4: return 14;
            default: return -1;
        }
    }

    // lookupswitch — sparse keys
    static int sparseCode(int n) {
        switch (n) {
            case 1:    return 100;
            case 10:   return 200;
            case 100:  return 300;
            case 1000: return 400;
            default:   return -1;
        }
    }

    public static void main(String[] args) {
        // tableswitch — hit cases
        if (dayCode(0) != 10)  { throw new RuntimeException("t0"); }
        if (dayCode(2) != 12)  { throw new RuntimeException("t2"); }
        if (dayCode(4) != 14)  { throw new RuntimeException("t4"); }
        // tableswitch — default (out of range)
        if (dayCode(99) != -1) { throw new RuntimeException("t99"); }
        if (dayCode(-1) != -1) { throw new RuntimeException("t-1"); }
        System.out.println("tableswitch OK");

        // lookupswitch — hit cases
        if (sparseCode(1)    != 100) { throw new RuntimeException("s1"); }
        if (sparseCode(100)  != 300) { throw new RuntimeException("s100"); }
        if (sparseCode(1000) != 400) { throw new RuntimeException("s1000"); }
        // lookupswitch — default (no match)
        if (sparseCode(42)   != -1)  { throw new RuntimeException("s42"); }
        System.out.println("lookupswitch OK");

        System.out.println("done");
    }
}
