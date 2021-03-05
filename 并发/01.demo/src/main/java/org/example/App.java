package org.example;

/**
 * Hello world!
 *
 */
public class App {

    private static volatile Object[] object=new Object[10];

    public static void main(String[] args) {
        object[0]=1; //lock
        object=new Object[2];
    }

}
