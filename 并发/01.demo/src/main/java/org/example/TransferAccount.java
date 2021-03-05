package org.example;

/**
 * 
 * create-date: 2020/5/23-20:08
 */
public class TransferAccount implements  Runnable{

    private Account fromAccount; //转出账户
    private Account toAccount; //转入账户
    private int amount;
    Allocator allocator;

    public TransferAccount(Account fromAccount, Account toAccount, int amount,Allocator allocator) {
        this.fromAccount = fromAccount;
        this.toAccount = toAccount;
        this.amount = amount;
        this.allocator=allocator;
    }


    @Override
    public void run() {
        while(true){
            if(allocator.apply(fromAccount,toAccount)) {
                try {
                    synchronized (fromAccount) {
                        synchronized (toAccount) {
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
                }finally {
                    allocator.free(fromAccount,toAccount);
                }
            }
        }
    }

    public static void main(String[] args) {
        Account fromAccount=new Account("Mic",100000);
        Account toAccount=new Account("花花",300000);
        Allocator allocator=new Allocator();
        Thread a =new Thread(new TransferAccount(fromAccount,toAccount,10,allocator));
        Thread b=new Thread(new TransferAccount(toAccount,fromAccount,30,allocator));

        a.start();
        b.start();
    }
}
