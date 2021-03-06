# Linux句柄数分析

## 通过lsof查看进程句柄数

1. lsof安装
```sh
yum install lsof
```

2. 使用 lsof -p pid > openfiles.log 命令

   ```sh
   lsof -p <pid> > openfiles.log
   ```

   ```txt
   COMMAND     PID USER   FD      TYPE DEVICE  SIZE/OFF       NODE NAME
   java    3115340 root  cwd       DIR  0,282      4096    2359412 /data
   java    3115340 root  rtd       DIR  0,282      4096    2359416 /
   java    3115340 root  txt       REG  0,282     14384    1704372 /usr/lib/jvm/java-1.8-openjdk/jre/bin/java
   java    3115340 root  mem       REG  253,1              1704372 /usr/lib/jvm/java-1.8-openjdk/jre/bin/java (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704547 /usr/lib/libfreebl3.so.41 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704606 /usr/lib/libsqlite3.so.0.8.6 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704604 /usr/lib/libsoftokn3.so.41 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704579 /usr/lib/libnss3.so.41 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704577 /usr/lib/libnspr4.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704418 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libsunec.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704586 /usr/lib/libnssutil3.so.41 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704595 /usr/lib/libplds4.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704399 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libj2pkcs11.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704415 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libnio.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704476 /usr/lib/jvm/java-1.8-openjdk/jre/lib/resources.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704439 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/cldrdata.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704594 /usr/lib/libplc4.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704447 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunpkcs11.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704445 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunec.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704461 /usr/lib/jvm/java-1.8-openjdk/jre/lib/jce.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704446 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunjce_provider.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704442 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/localedata.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704414 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libnet.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704463 /usr/lib/jvm/java-1.8-openjdk/jre/lib/jsse.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704412 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libmanagement.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              2359384 /data/config/eduz-apis-service-0.0.1-SNAPSHOT.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704477 /usr/lib/jvm/java-1.8-openjdk/jre/lib/rt.jar (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704421 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libzip.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              2363266 /tmp/hsperfdata_root/6 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704402 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libjava.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704420 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/libverify.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704550 /usr/lib/libgcc_s.so.1 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704610 /usr/lib/libstdc++.so.6.0.25 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704425 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/server/libjvm.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1580978 /lib/libz.so.1.2.11 (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1704386 /usr/lib/jvm/java-1.8-openjdk/jre/lib/amd64/jli/libjli.so (stat: No such file or directory)
   java    3115340 root  mem       REG  253,1              1580973 /lib/ld-musl-x86_64.so.1 (stat: No such file or directory)
   java    3115340 root    0u      CHR    1,3       0t0 1459430178 /dev/null
   java    3115340 root    1w     FIFO    0,9       0t0 1459430054 pipe
   java    3115340 root    2w     FIFO    0,9       0t0 1459430055 pipe
   java    3115340 root    3w      REG  253,1     84590    1585182 /data/logs/service_gc.log
   java    3115340 root    4r      REG  0,282  34755302    1704477 /usr/lib/jvm/java-1.8-openjdk/jre/lib/rt.jar
   java    3115340 root    5r      REG  0,282 114530483    2359384 /data/config/eduz-apis-service-0.0.1-SNAPSHOT.jar
   java    3115340 root    6r      REG  0,282 114530483    2359384 /data/config/eduz-apis-service-0.0.1-SNAPSHOT.jar
   java    3115340 root    7r      REG  0,282   1204589    1704442 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/localedata.jar
   java    3115340 root    8r      REG  0,282   4004250    1704439 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/cldrdata.jar
   java    3115340 root    9u     sock    0,7       0t0 1459431489 protocol: UNIX
   java    3115340 root   10u     sock    0,7       0t0 1469181166 protocol: TCP
   java    3115340 root   11u     sock    0,7       0t0 1468429453 protocol: TCP
   java    3115340 root   12w      REG  253,1  13269995    1585256 /data/logs/eduz-apis-service.2021-02-03.txt
   java    3115340 root   13r      REG  0,282    375889    1704463 /usr/lib/jvm/java-1.8-openjdk/jre/lib/jsse.jar
   java    3115340 root   14r      CHR    1,8       0t0 1459430179 /dev/random
   java    3115340 root   15r      CHR    1,9       0t0 1459430183 /dev/urandom
   java    3115340 root   16r      CHR    1,8       0t0 1459430179 /dev/random
   java    3115340 root   17r      CHR    1,8       0t0 1459430179 /dev/random
   java    3115340 root   18r      CHR    1,9       0t0 1459430183 /dev/urandom
   java    3115340 root   19r      CHR    1,9       0t0 1459430183 /dev/urandom
   java    3115340 root   20r      REG  0,282   1133787    1704476 /usr/lib/jvm/java-1.8-openjdk/jre/lib/resources.jar
   java    3115340 root   21r      REG  0,282    109021    1704461 /usr/lib/jvm/java-1.8-openjdk/jre/lib/jce.jar
   java    3115340 root   22r      REG  0,282     41674    1704445 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunec.jar
   java    3115340 root   23u     sock    0,7       0t0 1469195294 protocol: TCP
   java    3115340 root   24u     sock    0,7       0t0 1469429922 protocol: TCP
   java    3115340 root   25u     sock    0,7       0t0 1459437936 protocol: TCP
   java    3115340 root   26r     FIFO    0,9       0t0 1459437937 pipe
   java    3115340 root   27w     FIFO    0,9       0t0 1459437937 pipe
   java    3115340 root   28u  a_inode   0,10         0       6366 [eventpoll]
   java    3115340 root   29r     FIFO    0,9       0t0 1459436917 pipe
   java    3115340 root   30w     FIFO    0,9       0t0 1459436917 pipe
   java    3115340 root   31u  a_inode   0,10         0       6366 [eventpoll]
   java    3115340 root   32u     sock    0,7       0t0 1469202144 protocol: TCP
   java    3115340 root   33r      CHR    1,8       0t0 1459430179 /dev/random
   java    3115340 root   34u     sock    0,7       0t0 1459438885 protocol: UNIX
   java    3115340 root   35u     sock    0,7       0t0 1469179622 protocol: TCP
   java    3115340 root   36u     sock    0,7       0t0 1465466836 protocol: TCP
   java    3115340 root   37u     sock    0,7       0t0 1469385609 protocol: TCP
   java    3115340 root   39r     FIFO    0,9       0t0 1459464536 pipe
   java    3115340 root   40u     sock    0,7       0t0 1469405747 protocol: TCP
   java    3115340 root   41r      REG  0,282    299682    1704446 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunjce_provider.jar
   java    3115340 root   42u     sock    0,7       0t0 1464640536 protocol: TCP
   java    3115340 root   43u     sock    0,7       0t0 1469178244 protocol: TCP
   java    3115340 root   44u     sock    0,7       0t0 1469191756 protocol: TCP
   java    3115340 root   45u     sock    0,7       0t0 1469410997 protocol: TCP
   java    3115340 root   46r      REG  0,282    274010    1704447 /usr/lib/jvm/java-1.8-openjdk/jre/lib/ext/sunpkcs11.jar
   java    3115340 root   47w     FIFO    0,9       0t0 1459464536 pipe
   java    3115340 root   48u  a_inode   0,10         0       6366 [eventpoll]
   java    3115340 root   49u     sock    0,7       0t0 1459465426 protocol: TCP
   java    3115340 root   50u     sock    0,7       0t0 1468826935 protocol: TCP
   java    3115340 root   51u     sock    0,7       0t0 1469421493 protocol: TCP
   ```

3. 查看进程使用的句柄数

   ```sh
   lsof -p <pid> | wc -l
   
   例子：
   lsof -p 998 | wc -l
   959
   ```

4. 查看进程句柄数的排序

   ```sh
   lsof -n |awk '{print $2}'|sort|uniq -c |sort -nr|more 
   ```

   ```txt
   句柄数  进程id
   35040 2159565
   12987 3091444
   11160 1316025
   8165  199218
   6572  2533
   5518  19748
   4528  2555
   3712  498031
   3640  13672
   2211  3116
   2187  3012668
   2046  3115
   1981  3382
   1537  4446
   ```

   




## Q&A

### java.io.IOException 断开的管道 解决方法 ClientAbortException: java.io.IOException: Broken pipe

#### 查看系统句柄数限制

```sh
[root@sdfassd logs]# ulimit -a  
core file size          (blocks, -c) 0  
data seg size           (kbytes, -d) unlimited  
scheduling priority             (-e) 0  
file size               (blocks, -f) unlimited  
pending signals                 (-i) 62819  
max locked memory       (kbytes, -l) 64  
max memory size         (kbytes, -m) unlimited  
open files                      (-n) 65535  
pipe size            (512 bytes, -p) 8  
POSIX message queues     (bytes, -q) 819200  
real-time priority              (-r) 0  
stack size              (kbytes, -s) 10240  
cpu time               (seconds, -t) unlimited  
max user processes              (-u) 62819  
virtual memory          (kbytes, -v) unlimited  
file locks                      (-x) unlimited  
```

 open files竟然是65535，那么就要查看每个进程占用多少句柄，逐一排查