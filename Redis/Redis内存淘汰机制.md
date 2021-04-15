# Redis内存回收

## 1.最大内存设置

Redis默认不设置，32位系统最多使用3GB内存（隐性控制）；64位系统不限制内存。

## 2.过期策略

### 2.1惰性过期（被动淘汰）



### 2.2定期过期



## 3.淘汰策略

Redis内存淘汰策略，是指当内存使用达到最大内存极限时，需要使用淘汰算法来决定清理掉哪些数据，以保证新数据的存入。

动态修改淘汰策略：

```sh
config set maxmemory-policy volatile-lru
```



### 3.1 LRU算法

最近最少使用。判断最近被使用的时间，目前最远的数据有限被淘汰。

volatile-lru：

allkeys-lru：



### 3.2 LFU算法

最不常用，按照使用频率删除。

volatile-lfu：

allkeys-lfu：



### 3.3 随机Random

volatile-random：

allkeys-random：











