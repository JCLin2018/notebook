package org.example;

/**
 * 
 * create-date: 2020/5/23-20:30
 */
public class JoinDemo {


    private static int i=10;

    public static void main(String[] args) throws InterruptedException {
        Thread t=new Thread(()->{
            i=30;
            try {
                Thread.sleep(3000);
            } catch (InterruptedException e) {
                e.printStackTrace();
            }
        });
        //Callable/Future（阻塞）
        //
        t.start();
//        Thread.sleep(?); //你怎么知道多久能够执行完毕？
        //t线程中的执行结果对于main线程可见.
        t.join(); //Happens-Before模型 |
        //我希望t线程的执行结果可见
        System.out.println("i:"+i);
    }

}
