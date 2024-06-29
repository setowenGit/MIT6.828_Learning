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

## Lecture 9: Locking

lock的简单抽象：

```c++
lock l
acquire(l)
  x = x + 1 -- "critical section"
release(l)
```

我们什么时候需要锁:

* 当2个或更多的线程触及到内存时
* 当至少一个线程写入时

那我们能不能自动加锁呢？比如说每个数据都自动的和一个锁相连，这样太死板，会出现问题，比如说 ```rename("d1/x", "d2/y")```，实行的步骤就会是

* lock d1, erase x, unlock d1
* lock d2 add y unlock d2

这样会导致有一段时间文件消失了，那么信息也就没了...我们需要的是：

* lock d1; lock d2
* erase x, add y
* unlock d2; unlock d1

也就是说程序员需要能够控制中间过程

我们可以把锁想想成如下几点：

* avoid lost update
* create atomic multi-step operations -- hide intermediate states
* maintain invariants on a data structure

**deadlock**: 对于上面的那个rename，对于有2个锁的方案，如果同时运行 ```rename(d1/x, d2/y)和rename(d2/a, d1/b)``` 就会发生死锁。解决方案就是让程序员给所有的锁制定一个顺序，并让代码遵循这个顺序。显然这是很复杂的。

**lock vs tradeoff**: 同时这个解决方案会出现一个tradeoff，因为为了避免死锁，我们需要知道函数里面是怎么上锁的。或者说locks are often not the provate business of individual modules。所以一些时候，我们就 粗暴的在函数两端上锁来使其变为单线程运行的

**Locks and parallleism**: 锁实际上是在避免并行操作。而符合分割数据和锁，或者说设计"fine grained locks"是很难的。所以一般从一个单独的大锁开始，如果有需要再分为多个锁

关于用锁的几点建议：

* 如非必要，请勿分享你的锁
* 从粗粒度的锁开始慢慢细化
* 检测你的代码——哪些锁阻碍了并行性
* 仅在并行性能需要时使用细粒度锁
* 使用自动锁冲突检测器

## HW 7: HW xv6 locks

我们将探索中断与锁机制的一些互相作用的情况

弄清楚如果xv6内核执行下列这段代码,为什么会发生panic的情况？

```c++
struct spinlock lk;
initlock(&lk, "test lock");
acquire(&lk);
acquire(&lk);
```

查看 spinlock.c

```c++
// 上锁（自旋锁）
void
acquire(struct spinlock *lk)
{
  pushcli(); // 失能中断以避免死锁
  if(holding(lk))
    panic("acquire");
  // xchg — 交换操作，它原子性地交换两个操作数的值
  while(xchg(&lk->locked, 1) != 0) 
    ;
  // 避免编译器在优化的时候更改指令顺序，使得锁失效
  __sync_synchronize();
  // Record info about lock acquisition for debugging.
  lk->cpu = mycpu();
  getcallerpcs(&lk, lk->pcs);
}

// 检查该cpu是否已经拥有这个锁，若已经拥有，则不能再次上锁
int
holding(struct spinlock *lock)
{
  int r;
  pushcli();
  r = lock->locked && lock->cpu == mycpu();
  popcli();
  return r;
}
```

所以，根据代码逻辑可以知道，当前cpu已经获取了锁的情况下，再次请求上锁会导致panic

## Lab 4: Preemptive Multitasking

在实验4中，新增了如下新的代码

* kern/cpu.h 多处理器支持的内核私有定义
* kern/mpconfig.c 读取多处理器配置的代码
* kern/lapic.c 驱动每个处理器中的本地 APIC 单元的内核代码
* kern/mpentry.S 非引导 CPU 的汇编语言入口代码
* kern/spinlock.h 自旋锁的内核私有定义，包括大内核锁
* kern/spinlock.c 实现自旋锁的内核代码
* kern/sched.c 您将要实现的调度程序的代码框架

### Part A: Multiprocessor Support and Cooperative Multitasking

#### Multiprocessor Support

我们将使JOS支持“对称多处理”(symmetric multiprocessing, SMP)——一种多处理模型。在这种模型中，所有的处理器都可以同等地使用系统资源，如内存和输入/输出总线。虽然所有的处理器在功能上都是相同的，但在引导过程中，他们可以分为两种类型：

* bootstrap processor (BSP): 负责初始化系统和引导操作系统
* application processors (APs): 只有在操作系统启动并运行之后，应用处理器才被BSP激活

哪个处理器是BSP由硬件和BIOS决定。到目前为止，所有JOS代码都在BSP上运行

在SMP系统中，每个CPU都有一个配套的local APIC(LAPIC)单元。LAPIC单元负责在整个系统中传递中断。LAPIC还为其连接的CPU提供一个唯一的标识符。在本实验中，我们利用了LAPIC单元的以下基本功能(在kern/lapic.c中)

1. 读取LAPIC标识(APIC ID)来判断我们的代码当前运行在哪个处理器上
2. 把STARUP处理器间中断(IPI)从BSP发送到APs以启动其他处理器(参见lapic_startap())
3. 在Part C中，我们对LAPIC的内置定时器进行编程，以触发时钟中断来支持抢占式多任务处理

处理器使用内存映射I/O(MMIO)来访问其LAPIC。在MMIO中，物理存储器的一部分被硬连线到一些IO设备的寄存器，因此通常用于访问存储器的相同的load/store指令可以用于访问设备寄存器。在物理地址0xA0000处可以看到一个IO hole(我们用它来写入VGA显示缓冲区)

LAPIC的 hole 开始于物理地址0xFE000000(4GB位置仅差32MB)，但是这地址太高我们无法访问通过过去的直接映射(虚拟地址0xF0000000映射0x0，即只有256MB)。但是JOS虚拟地址映射预留了4MB空间在MMIOBASE处，我们需要分配映射空间

###### exercise 1

在kern/pmap.c文件中实现mmio_map_region. 要了解如何使用它，需要查看kern/lapic.c中lapic_init的开头。在运行mmio_map_region测试之前，必须做完下一个练习

如下所示

```c++
// 在MMIO区域保留大小字节，并在此位置映射[pa,pa+size]。
// 返回保留区域的基数。size参数不一定是PGSIZE的倍数。
void *
mmio_map_region(physaddr_t pa, size_t size)
{
	static uintptr_t base = MMIOBASE;
	// 预留虚拟内存的大小字节,从基数开始,将物理页[pa,pa+size]映射到虚拟地址[base,base+size].
    // 由于这是设备内存,而不是普通的DRAM,你必须告诉CPU,对这个内存进行缓存访问是不安全的.
    // 幸运的是,pagetables提供了用于此目的的二进制位；只需在PTE_W之外再加上PTE_PCD|PTE_PWT（禁用缓存和write-through）来创建映射
	void *ret = (void *)base;
	size = ROUNDUP(size, PGSIZE);
	if (base + size > MMIOLIM || base + size < base) {
		panic("mmio_map_region reservation overflow\n");
	}
	boot_map_region(kern_pgdir, base, size, pa, PTE_W|PTE_PCD|PTE_PWT);
	base += size; // 注意base是静态的，需要时时更新
	return ret;
}
```

##### Application Processor Bootstrap

AP启动流程：

1. 在启动APs之前，BSP首先应该收集关于多处理器系统的信息，例如CPU的总数，它们的APIC ID，和LAPIC单元的MMIO地址。kern/mpconfig.c中的mp_init()函数通过读取驻留在BIOS内存区域中的MP配置表来检索该信息
2. boot_aps函数(在kern/init.c中)驱动AP引导进程。APs在实模式下启动，就像引导程序在boot/boot.S下启动一样。所以boot_aps会复制AP入口代码地址(kern/mpentry.S)到在实模式下可寻址的存储器位置
3. 与引导加载程序不同，我们可以控制应用程序从哪里开始执行代码，我们将入口代码复制到0x7000(MPETRY_PADDR)，但是任何未使用的、页面对齐的低于640KB的物理地址都可以工作
4. 在这之后，boot_aps()通过向相应AP的LAPIC单元发送STARTUP IPI和一个初始CS:IP地址，AP应该在该地址开始运行其入口代码(MPENTRY_PADDR)，一个接一个地激活APs。在kern/mpentry.S中的入口代码跟boot/boot.S中的代码类似
5. 在一些简单的配置后，它使AP进入开启分页机制的保护模式，然后调用C语言的setup函数mp_main. boot_aps等待AP在其结构CpuInfo的cpu_status字段中发出CPU_STARTED标志信号，然后再唤醒下一个

###### exercise 2

修改kern/pmap.c中实现的page_init()，以避免将MPENTRY_PADDR页面添加到空闲列表中，这样我们就可以安全复制并运行该物理地址上的AP引导代码，代码通过check_page_free_list测试

首先需要理解boot_aps()函数

```c++
// 存储有AP的入口函数地址的物理地址
#define MPENTRY_PADDR	0x7000
// cpu的内核栈，在这里使用数组实现
unsigned char percpu_kstacks[NCPU][KSTKSIZE]
// cpu信息结构体
struct CpuInfo {
	uint8_t cpu_id;                 // cpu的id，对应cpus数组的索引
	volatile unsigned cpu_status;   // cpu的状态
	struct Env *cpu_env;            // cpu中正在运行的进程（环境）
	struct Taskstate cpu_ts;        // 内核栈状态
};

// 启动APs
static void
boot_aps(void)
{
	extern unsigned char mpentry_start[], mpentry_end[];
	void *code;
	struct CpuInfo *c;
	// 将入口函数地址复制到物理地址 MPENTRY_PADDR 所对应的虚拟地址上
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
	// 在循环里每次启动一个AP
	for (c = cpus; c < cpus + ncpu; c++) {
		// 如果cpu结构体c与现在正在运行的cpu结构体相同，说明该AP已经启动了
		if (c == cpus + cpunum())
			continue;
		// mpentry_kstack存有分配给该AP的栈的栈顶地址
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
		// 从MPENTRY_PADDR中存储的AP的入口函数地址开始，启动AP
		lapic_startap(c->cpu_id, PADDR(code));
		// 等待AP发出的CPU_STARTED信号
		while(c->cpu_status != CPU_STARTED)
			;
	}
}
```

* 上面的lapic_startap()函数相当于往一个全局内存lapic中写入数据，从而完成BSP与AP的通讯
* lapic是在lapic_init()函数中通过exercise 1中修改的mmio_map_region()函数实现赋值的,具体来说是代码```lapic = mmio_map_region(lapicaddr, 4096);```
* lapicaddr是LAPIC的IO hole的地址，在mmio_map_region()中就是将这个地址映射到MMIOBASE上，从而BSP可以访问到MMIOBASE上的数据，从而实现与LAPIC以内存映射IO方式的通讯交流

接着要理解mpentry.S汇编文件

* 这段代码其实就是AP的入口函数，是上面boot_aps函数中的以```mpentry_start```为起止地址的代码，上述函数就是将这段代码复制到MPENTRY_PADDR起始的位置上
* 这个汇编文件主要做的事情是跳转到c语言函数mp_main()中

接着要理解mp_main()函数

* 主要完成lapic的初始化，加载GDT以及段描述符，初始化并加载所有CPU的TSS、和 IDT
* 最后将cpu状态设置为CPU_STARTED，那么boot_aps函数将退出while

修改page_init，增加一个判断条件，将MPENTRY_PADDR这一页设置为已使用

```c++
uint32_t mpentry_pn = ((uint32_t) KADDR(MPENTRY_PADDR) - KERNBASE) / PGSIZE;

else if(i == mpentry_pn) {
			pages[i].pp_ref = 1;
		}
```