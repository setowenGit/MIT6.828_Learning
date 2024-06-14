# MIT 6.828 Learning 2

##### [课程表](https://pdos.csail.mit.edu/6.828/2018/schedule.html)

##### [调试指令列表](https://pdos.csail.mit.edu/6.828/2018/labguide.html)

##### [Github参考](https://github.com/setowenGit/MIT6.828_OS)

##### [Gitee参考](https://gitee.com/rcary/mit6.828/tree/master)

##### [Github参考2](https://github.com/clpsz/mit-jos-2014/tree/master)

##### [知乎参考](https://zhuanlan.zhihu.com/p/166413604)

##### [Github参考3](https://github.com/yunwei37/6.828-2018-labs?tab=readme-ov-file)

##### [lecture的翻译笔记](https://zhuzilin.github.io/blog/tags/6-828/)

##### [CSDN参考](https://blog.csdn.net/qq_43012789?type=blog)

##### [博客园参考](https://www.cnblogs.com/fatsheep9146/p/5451579.html)
##### [实验环境配置(其他报错问题可看评论区)](https://blog.csdn.net/Rcary/article/details/125547980?utm_source=app&app_version=4.17.0)

---

## Lecture 8: Interrupts, System calls, and Exceptions

Interrupts VS Polling

一些设备可以在不到1微秒的时间内生成中断，比如GB ethernet，而中断却需要大约微妙时间量级。因为需要保存和恢复状态，同时中断伴随着cache misses。那么我们该如何处理间隔小于1微秒的中断呢？

可以使用Polling：处理器按一定周期检查设备是否有需要，这种方法虽然在设备很慢的时候很浪费，但是设备很快的时候就很好了，因为不需要保存寄存器等等

* 对high-rate device用polling，慢的用interrupt
* 也可以在polling和interrupt之间相互切换，如果rate is low用interrupt，反之用polling

## HW 6：Threads and Locking

[参考这个笔记](https://blog.csdn.net/userXKk/article/details/107979990)

ph.c主要实现了一个有外链的哈希表的多线程插入和取值

编译运行后如下，其中参数1表示开启1个线程，参数2表示开启2个线程

![](fig/2024-06-14-21-08-26.png)

可发现开启2个线程的时候会报 keys missing 的错误

取值部分不会对内存进行修改，所以不用加锁

而在插入的时候，考虑一种情况，当两个线程同时进入这段代码，且put的局部变量 i 相同时，两个线程会先后对 table[i] 进行赋值，那么会导致一个线程要插入的key覆盖了另一个线程的key，所以会有丢失key的状况

```c++
static void 
insert(int key, int value, struct entry **p, struct entry *n)
{
  struct entry *e = malloc(sizeof(struct entry));
  e->key = key;
  e->value = value;
  e->next = n;
  *p = e;
}

static 
void put(int key, int value)
{
  int i = key % NBUCKET;
  insert(key, value, &table[i], table[i]);
}
```

为了避免发生丢失key的情况，在put插入lock和unlock语句，也就是加入互斥锁

```c++
// 互斥锁数组
pthread_mutex_t lock[NBUCKET];

// 在main函数中初始化互斥锁
for(int i=0;i<NBUCKET;i++) {
    pthread_mutex_init(&lock[i],NULL);
}

// 在insert前后加入互斥锁
static 
void put(int key, int value)
{
  int i = key % NBUCKET;
  pthread_mutex_lock(&lock[i]);
  insert(key, value, &table[i], table[i]);
  pthread_mutex_unlock(&lock[i]);
}
```

重新编译运行，发现mssing为0

![](fig/2024-06-14-21-51-18.png)