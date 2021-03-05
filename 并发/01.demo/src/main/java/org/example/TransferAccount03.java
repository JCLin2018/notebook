package org.example;

import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;

/**
 * 
 * create-date: 2020/5/23-20:08
 */
public class TransferAccount03 implements  Runnable{

    private Account fromAccount; //转出账户
    private Account toAccount; //转入账户
    private int amount;

    public TransferAccount03(Account fromAccount, Account toAccount, int amount) {
        this.fromAccount = fromAccount;
        this.toAccount = toAccount;
        this.amount = amount;
    }


    @Override
    public void run() {
        Account left=null;
        Account right=null;
        if(fromAccount.hashCode()>toAccount.hashCode()){
            left=toAccount;
            right=fromAccount;
        }
        while(true){
            synchronized (left) { //返回true和false
                synchronized (right) {//返回true和false
                    if (fromAccount.getBalance() >= amount) {
                        fromAccount.debit(amount);
                        toAccount.credit(amount);
                    }
                }
            }
            //转出账户的余额
            System.out.println(fromAccount.getAccountName() + "->" + fromAccount.getBalance());
            //转入账户的余额
            System.out.println(toAccount.getAccountName() + "->" + toAccount.getBalance());
        }
    }

    public static void main(String[] args) {
        Account fromAccount=new Account("Mic",100000);
        Account toAccount=new Account("花花",300000);
        Thread a =new Thread(new TransferAccount03(fromAccount,toAccount,10));
        Thread b=new Thread(new TransferAccount03(toAccount,fromAccount,30));

        a.start();
        b.start();
    }
}
