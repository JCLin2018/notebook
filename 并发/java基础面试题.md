## 并发编程基础相关问题

什么是多线程并发和并行？

并发：单核cpu切换线程运行，时间片，线程切换
并行：多核cpu同时执行线程

什么是线程安全问题？

线程安全离不开程序执行的原子性、可见性、有序性；如果三者有其中一种不满足，就会引发线程安全问题！
原子性：一个操作不可中断，要么全部成功，要么全部失败。（线程执行指令时 切换其他线程执行！）
可见性：cpu高速缓存引发的可见性问题
有序性：编译器和处理器进行指令重排序导致有序性问题

什么是共享变量的内存可见性问题？

什么是Java中原子性操作？

什么是Java中的CAS操作,AtomicLong实现原理？

什么是Java指令重排序？

Java中Synchronized关键字的内存语义是什么？

Java中Volatile关键字的内存语义是什么？

什么是伪共享,为何会出现，以及如何避免？

什么是可重入锁、乐观锁、悲观锁、公平锁、非公平锁、独占锁、共享锁？

## ThreadLocal 相关问题

讲讲ThreadLocal 的实现原理？

ThreadLocal 作为变量的线程隔离方式，其内部是如何做的？

说说InheritableThreadLocal 的实现原理？

InheritableThreadLocal 是如何弥补 ThreadLocal 不支持继承的特性？

CyclicBarrier内部的实现与 CountDownLatch 有何不同？

随机数生成器 Random 类如何使用 CAS 算法保证多线程下新种子的唯一性？

ThreadLocalRandom 是如何利用 ThreadLocal 的原理来解决 Random 的局限性？

Spring 框架中如何使用 ThreadLocal 实现 request scope 作用域 Bean？

## 锁相关问题

并发包中锁的实现底层（对AQS的理解）？

讲讲独占锁 ReentrantLock 原理？

谈谈读写锁 ReentrantReadWriteLock 原理？

StampedLock 锁原理的理解？

## 并发队列相关问题

谈下对基于链表的非阻塞无界队列 ConcurrentLinkedQueue 原理的理解？

ConcurrentLinkedQueue 内部是如何使用 CAS 非阻塞算法来保证多线程下入队出队操作的线程安全？

基于链表的阻塞队列 LinkedBlockingQueue 原理。

阻塞队列LinkedBlockingQueue 内部是如何使用两个独占锁 ReentrantLock 以及对应的条件变量保证多线程先入队出队操作的线程安全？

为什么不使用一把锁，使用两把为何能提高并发度？

基于数组的阻塞队列 ArrayBlockingQueue 原理。

ArrayBlockingQueue 内部如何基于一把独占锁以及对应的两个条件变量实现出入队操作的线程安全？

谈谈对无界优先级队列 PriorityBlockingQueue 原理？

PriorityBlockingQueue 内部使用堆算法保证每次出队都是优先级最高的元素，元素入队时候是如何建堆的，元素出队后如何调整堆的平衡的？

## JUC 包中线程同步器相关问题

分析下JUC 中倒数计数器 CountDownLatch 的使用与原理？

CountDownLatch 与线程的 Join 方法区别是什么？

讲讲对JUC 中回环屏障 CyclicBarrier 的使用？

CyclicBarrier内部的实现与 CountDownLatch 有何不同？

Semaphore 的内部实现是怎样的？

简单对比同步器实现，谈谈你的看法？

并发组件CopyOnWriteArrayList 是如何通过写时拷贝实现并发安全的 List？