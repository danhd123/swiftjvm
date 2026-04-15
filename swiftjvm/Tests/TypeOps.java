// Exercises: checkcast, instanceof, invokevirtual (virtual dispatch),
//            invokeinterface (interface dispatch)
interface Speakable {
    String speak();
}

class Animal {
    String name() { return "animal"; }
}

class Dog extends Animal implements Speakable {
    String name() { return "dog"; }
    public String speak() { return "woof"; }
}

class Cat extends Animal implements Speakable {
    String name() { return "cat"; }
    public String speak() { return "meow"; }
}

class TypeOps {
    public static void main(String[] args) {
        // instanceof — true cases
        Object d = new Dog();
        if (!(d instanceof Dog))    { throw new RuntimeException("d instanceof Dog"); }
        if (!(d instanceof Animal)) { throw new RuntimeException("d instanceof Animal"); }

        // instanceof — false case
        if (d instanceof Cat) { throw new RuntimeException("d !instanceof Cat"); }

        // instanceof null — always false
        Object n = null;
        if (n instanceof Dog) { throw new RuntimeException("null instanceof Dog"); }

        // checkcast — succeeds
        Dog dog = (Dog) d;
        System.out.println(dog.name());   // "dog" via invokevirtual

        // virtual dispatch through supertype reference
        Animal a = new Cat();
        System.out.println(a.name());     // "cat" — virtual, not "animal"

        // invokeinterface
        Speakable s1 = (Speakable) d;
        Speakable s2 = (Speakable) a;
        System.out.println(s1.speak());   // "woof"
        System.out.println(s2.speak());   // "meow"

        System.out.println("TypeOps OK");
    }
}
