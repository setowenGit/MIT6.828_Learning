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
##### [实验环境配置(其他报错问题可看评论区)](https://blog.csdn.net/Rcary/article/details/125547980?utm_source=app&app_version=4.17.0)

---

## Lecture 6

[看这个笔记](https://zhuzilin.github.io/blog/6.828-note5-virtual-memory/)

在内核中使用虚拟地址（VA）的主要原因包括以下几点：

* 内存管理：通过使用虚拟地址，内核可以更灵活地管理物理内存，并实现内存映射、分页和其他高级内存管理功能
* 安全性：虚拟地址可以提供一定程度的安全保护，因为它们可以被映射到不同的物理地址，从而增加系统的安全性
* 抽象屏蔽硬件差异：使用虚拟地址可以让内核屏蔽不同硬件平台之间的差异，使得内核可以更容易地移植到不同的硬件架构上
* 如果没有page table，很容易有memory fragmentation（内存碎片？）。比如先分配64K, 释放，之后分配4K，4K占据了64K的地方，之后再分配64K就没法弄了

如果page table就仅仅是一个PTE的array，会出现什么问题呢？

* 首先是太大了，2^20条，每条32bit，整个table就会是4 MB了，这对于早期的机器太大了。并且对于一个小的程序，它不需要那么多内存，可能只需要几百page，剩下的就浪费了。所以x86使用了一个"two-level page table"以节省空间。除了在RAM中 分配PTE，还在内存中存一个叫page directory(PD)的东西。
* PD也是一个array，其每一个entry被称为PDE，我们来看一下这个PDE的结构，PDE的前20位也是一个PPN，其指向的page是一个用于存page table的page，存的每个page table会指向1024个PTE。在PD中有1024个PDE，所以就指向了2^20个PTE。
* 刚刚提到了对于一个小程序，可能不需要那么多PTE，所以有的PDE可以是invalid，从而可以让address space变得很小。

page table被存在哪里呢？
* 被存在RAM中，MMU会读取或存储PTE。操作系统可以读写PTE。

MMU如何知道page table在RAM的哪里呢？
* cr3存了PD的地址。PD里面（间接）存了PTE的PA，而这些PTE不一定是连续的。

## HW 4: xv6 lazy page allocation

 操作系统可以在页表硬件上玩的许多巧妙的把戏之一是堆内存的惰性分配。
 
 Xv6应用程序使用sbrk()系统调用向内核请求堆内存。在我们给你的内核中，sbrk()分配物理内存并将其映射到进程的虚拟地址空间。有些程序分配内存，但从不使用它，例如实现大型稀疏数组。
 
 复杂的内核会**延迟每个内存页面的分配，直到应用程序尝试使用该页面**——这是由页面错误发出的信号，内核将通过分配物理内存，将其清零并对其进行映射来处理该页面错误。在本练习中，您将把这个惰性分配特性添加到xv6中。

### Part1. Eliminate allocation from sbrk()

 修改sbrk(n)。sbrk()本来是将进程的内存大小增加n个字节，并且返回新分配区域的起始地址。现在需要改成只将进程的大小（myproc()->sz）增加n但不分配区域，并返回原来的大小

修改sysproc.c的sys_sbrk函数

 ```c++
 int
sys_sbrk(void)
{
  int addr;
  int n;

  if(argint(0, &n) < 0)
    return -1;
  addr = myproc()->sz;
  /* if(growproc(n) < 0) // 不直接分配内存
    return -1;*/ 
  myproc()->sz += n; // new add // 仅对sz进行增加
  return addr;
}
 ```

### Part2. Lazy allocation

[参考这个csdn](https://blog.csdn.net/qq_43012789/article/details/107765484)

修改trap.c中的代码，通过将新分配的物理内存页面映射到错误地址来响应用户空间的页面错误，然后返回到用户空间，让进程继续执行。在产生“pid 3 sh: trap 14”消息的cprintf调用之前添加代码。

修改trap.c的trap函数

```c++
default:
    if(myproc() == 0 || (tf->cs&3) == 0){
      // In kernel, it must be our mistake.
      cprintf("unexpected trap %d from cpu %d eip %x (cr2=0x%x)\n",
              tf->trapno, cpuid(), tf->eip, rcr2());
      panic("trap");
    }

    /*new add*/
    // char *mem;
    // uint a;
    a = PGROUNDDOWN(rcr2()); // 使用PGROUNDDOWN(va)将有问题的虚拟地址向下舍入到页面边界，得到起始虚拟地址
    for(;a<myproc()->sz;a+=PGSIZE){ // 循环遍历从起始虚拟地址开始到进程的大小（myproc()->sz）结束，每次增加一个页面大小
      mem = kalloc(); // 分配物理内存页面
      if(mem==0){ // 如果分配失败，打印错误信息并释放之前已经分配的内存，然后返回
       cprintf("allocuvm out of memory\n");
       deallocuvm(myproc()->pgdir,myproc()->sz,myproc()->tf->eax);
       return ;
      }
      memset(mem,0,PGSIZE); // 使用memset函数将分配的物理内存清零，确保数据的干净状态
      // 调用mappages函数将虚拟地址映射到物理地址，并设置相应的页表项（PTE）。如果映射失败，打印错误信息，释放内存，然后返回
      if(mappages(myproc()->pgdir,(char *)a, PGSIZE, V2P(mem), PTE_W|PTE_U)<0){
        cprintf("alloccuvm out of memory(2)\n");
        deallocuvm(myproc()->pgdir,myproc()->sz,myproc()->tf->eax);
        kfree(mem);
        return ;
      }
     // cprintf("mem\n");
    }
    break;

    // In user space, assume process misbehaved.
    cprintf("pid %d %s: trap %d err %d on cpu %d "
            "eip 0x%x addr 0x%x--kill proc\n",
            myproc()->pid, myproc()->name, tf->trapno,
            tf->err, cpuid(), tf->eip, rcr2());
    myproc()->killed = 1;
  
```

## Lecture 7

[看这个笔记](https://zhuzilin.github.io/blog/6.828-note6-using-virtual-memory/)

xv6和JOS都是OS设计的例子，但是他们和真正的OS相比还是有很大差距的，以下就是其中一些真正OS的优化

* guard page to protect against stack overflow：user stack后面放一个没有被map的page，这样如果stack overflow了，会得到page fault，当application跑到guard page上来的时候分配more stack
* one zero-filled page：观察到很多时候一些memory从来不会被写入，而因为所有的内存都会用0进行初始化，所以可以使用一个zeroed page for all zero mappings。当需要zero-filled page的时候，就map到这个zeroed page，在写入的时候，先拷贝这个公共的zeroed-filled page给另一个内存空间，然后再对这个新的内存空间进行写操作，与父子进程一开始fork后共享内存空间相似
* copy-on-write fork：很多时候都是fork之后马上exec，如果赋值了会很浪费，所以把parent和child的内存先共享着，并且把child的内存设置为copy on write，也就是有写入的时候再复制
* demanding paging：现在的exec可能会把整个文件都加载到内存中，这样会很慢，并且有可能没必要。可以先分配page，并标记为on demand，on default从file中读取对应的page
* 用比物理内存更大的虚拟内存：有的时候可能需要比物理内存还大的内存。解决方法就是把内存中不常用的部分存在硬盘上。在硬盘和内存之间 page in and out数据
  * 使用PTE来检测什么时候需要disk access
  * 用page table来找到least recent used disk block 并把其写回硬盘（LRU）
* memory-mapped files：通过load, store而不是read, write, lseek来access files以轻松访问文件的某一部分，用memory offset而不是seeking
##### The UVPD (User Virtual Page Directory)

下图和下面的代码很好的演示了如何能够找到一个虚拟地址

![](fig/2024-05-06-19-37-01.png)

```
page directory = pd = lcr3();
page table = pt = *(pd + 4*PDX);
page = *(pt + 4*PTX);
```

但是这种方式我们该如何用VA来访问PD或者某一个page table呢？或者说PD和PT也应该有自己的映射才对

采用的方法是通过让PD自己指向自己，也就是两步都是指向自己的开头，在JOS中V是0x3BD（V是page directory的一个索引，里面存放的指针指向的是page directory自己）。UVPD（应该就是page directory）是 (0x3BD<<22)|(0x3BD<<12)，然后如下图：

![](fig/2024-05-06-19-40-45.png)

这样如果PDX和PTX都是V，两次之后还是会指向PD，如果PDX=V但是PTX!=V，那么运行之后就会指向某一个page table。通过以上的方式，我们就把虚拟地址映射到了PD和PT了。

## HW 5: xv6 CPU alarm

在本练习中，将在xv6中添加一项功能，当进程使用CPU时间时，它会定期向进程发出警报。这对于希望限制占用多少CPU时间的受计算限制的进程，或者希望进行计算但又希望采取一些周期性操作的进程可能很有用。更一般地说，您将实现用户级中断/故障处理程序的原始形式；例如，您可以使用类似的东西来处理应用程序中的页面错误。

需要添加一个新的alarm(interval, handler)系统调用。如果一个应用程序调用了alarm(n,fn), 那么在程序消耗每个n“ticks”的CPU时间之后，内核将调用应用程序函数fn。 当fn返回时，应用程序将从中断处继续。 tick是xv6中相当随意的时间单位，由硬件定时器产生中断的频率决定。

把下述样例程序放到文件alarmtest.c中。该程序调用alarm(10，periodic)，要求内核每10秒钟强制调用periodic()，然后旋转一会儿

* 新增alarmtest.c文件

```c++
#include "types.h"
#include "stat.h"
#include "user.h"

void periodic();

int
main(int argc, char *argv[])
{
  int i;
  printf(1, "alarmtest starting\n");
  alarm(10, periodic);
  for(i = 0; i < 25*5000000; i++){
    if((i % 250000) == 0)
      write(2, ".", 1);
  }
  exit();
}

void
periodic()
{
  printf(1, "alarm!\n");
}
```

* 参考HW3,添加系统调用
  * syscall.c: extern int sys_alarm(void);
  * syscall.c: [SYS_alarm]   sys_alarm,
  * syscall.h: #define SYS_alarm  24
  * user.h:    int alarm(int, void (*)());
  * usys.S:    SYSCALL(alarm)

* sysproc.c添加函数

```c++
int
sys_alarm(void) 
{
	// 间隔 
	int interval;
	// 函数指针
	void (*handler)(void);
	
	if(argint(0, &interval) < 0)
		return -1;
	if(argptr(1, (char **)&handler, 1) < 0)
		return -1;

	myproc()->alarminterval = interval;
	myproc()->alarmhandler = handler;
	return 0;
}
```

* proc.h结构体中增加成员

```c++
int alarminterval;              
void (*alarmhandler)();
int ticks;
```

* trap.c中的trap函数增加情况

```c++
case T_IRQ0 + IRQ_TIMER:
    if(cpuid() == 0){
      acquire(&tickslock);
      ticks++;
	  
      wakeup(&ticks);
      release(&tickslock);
    }
    /*new add*/
  	if(myproc() != 0 && (tf->cs & 3) == 3){
  		myproc()->ticks++;
  		// 没有alarm任务的proc, 不会进入以下if,因为alarminterval为0
  		if(myproc()->ticks == myproc()->alarminterval) {
  			myproc()->ticks = 0;
  			tf->esp -= 4;
  			// eip压栈
  			*(uint *)(tf->esp) = tf->eip;
  			tf->eip = (uint)myproc()->alarmhandler; // 执行alarm系统调用
  	  	}
  	}
    lapiceoi();
    break;
```

运行效果如下

![](fig/2024-05-06-20-25-41.png)

## Lab 3: User Environments

lab3 比 lab2 多了以下文件

![](fig/2024-05-07-20-04-57.png)

在这个lab中，进程就是环境，环境就是进程
### Part A: User Environments and Exception Handling

在kern/env.c中，内核维护了与环境有关的三个主要全局变量：

```c++
#define LOG2NENV		10
#define NENV			(1 << LOG2NENV)  // 最大进程数量

struct Env *envs = NULL;		    // All environments 所有进程
struct Env *curenv = NULL;		    // The current env  现在运行的进程
static struct Env *env_free_list;	// Free environment list  空闲的进程
```

* 一旦JOS启动并运行，envs指针将指向Env代表系统中所有环境的结构数组。JOS内核将最多支持 NENV 个活动环境
* JOS内核将所有非活动Env结构保留在env_free_list上。这种设计可以轻松分配和释放环境，因为只需将它们添加到空闲列表中或从空闲列表中删除
* 内核使用该curenv符号在任何给定时间跟踪当前正在执行的环境。在启动期间，在运行第一个环境之前， curenv初始设置为NULL

在inc/env.h中，定义了结构体Env

```c++
enum {
	ENV_FREE = 0, // 空闲状态，此时进程位于env_free_list中
	ENV_DYING,    // 挂死进程，之后就会被释放
	ENV_RUNNABLE, // 就绪状态
	ENV_RUNNING,  // 正在运行状态
	ENV_NOT_RUNNABLE // 阻塞状态，如该进程正在等待某个信号量
};

enum EnvType {
	ENV_TYPE_USER = 0,
};

struct Trapframe {
	struct PushRegs tf_regs;
	uint16_t tf_es;
	uint16_t tf_padding1;
	uint16_t tf_ds;
	uint16_t tf_padding2;
	uint32_t tf_trapno;
	/* below here defined by x86 hardware */
	uint32_t tf_err;
	uintptr_t tf_eip;
	uint16_t tf_cs;
	uint16_t tf_padding3;
	uint32_t tf_eflags;
	/* below here only when crossing rings, such as from user to kernel */
	uintptr_t tf_esp;
	uint16_t tf_ss;
	uint16_t tf_padding4;
} __attribute__((packed));

struct Env {
	struct Trapframe env_tf;	// Saved registers  保存进程的寄存器现场值
	struct Env *env_link;		// Next free Env    指向env_free_list中下一个空闲的进程
	envid_t env_id;			    // Unique environment identifier  独一无二的进程ID
	envid_t env_parent_id;		// env_id of this env's parent    该进程的父进程，该进程就是由父进程fork出来的
	enum EnvType env_type;		// Indicates special system environments  进程类型
	unsigned env_status;		// Status of the environment  进程状态
	uint32_t env_runs;		    // Number of times environment has run
	// Address space
	pde_t *env_pgdir;		// Kernel virtual address of page dir 保存此进程的page directory的内核虚拟地址
};
```

* 要运行进程，内核必须使用该进程保存的寄存器和对应的地址空间设置CPU
* 在JOS中，单个环境不像xv6中的进程那样有自己的内核堆栈。内核中一次只能有一个活动的JOS环境，因此JOS只需要一个内核堆栈。

##### exercise 1

在Lab 2中，您在mem_init()中为pages[]数组分配了内存，这是一个内核用来跟踪哪些页面是空闲的，哪些不是空闲的表。您现在需要进一步修改mem_init()，以分配一个类似的Env结构数组，称为envs

修改kern/pmap.c中的mem_init()，以分配和映射envs数组。这个数组完全由分配的Env结构的NENV个实例组成，就像您分配pages数组的方式一样。和pages数组一样，内存支持envs也应该在UENVS（在inc/memlayout.h中定义）上映射用户只读，这样用户进程就可以从这个数组中读取

```c++
envs = (struct Env*)boot_alloc(sizeof(struct Env)*NENV);
memset(envs, 0, sizeof(struct Env)*NENV);

boot_map_region(kern_pgdir, UENVS, ROUNDUP((NENV * sizeof(struct Env)), PGSIZE), PADDR(envs), PTE_U);
```

##### exercise 2

现在需要在kern/env.c文件中写代码来运行用户环境。因为操作系统暂时还没有实现文件系统，所以将设置内核来加载一个静态二进制映像，它嵌入在内核本身中，每个二进制映像（也就是elf文件）被加载到不同的环境中

在kern/init.c文件中的i386_init函数中，将会看到在环境中运行其中一个二进制映像的代码。然而，设置用户环境的关键代码还不完整，需要去完成以下函数

* env_init()：初始化envs数组中的所有Env结构，并将它们添加到env_free_list中。还调用env_init_percpu，它使用特权级别0（内核）和特权级别3（用户）的单独段来配置分割硬件
* env_setup_vm()：为新环境分配一个页面目录，并初始化新环境的地址空间的内核部分
* region_alloc()：为环境分配和映射物理内存
* load_icode()：您将需要解析一个ELF二进制映像，就像boot loader已经做的那样，并将其内容加载到新环境的用户地址空间中
* env_create()：使用env_alloc分配一个环境，并调用load_icode来将一个ELF二进制文件加载到其中
* env_run()：启动以用户模式运行的给定环境

下面是代码的调用图，直到调用用户代码为止，可供参考：

* start (kern/entry.S)：kernel的entry，也就是boot loader加载kernel的entry
* i386_init (kern/init.c)：上面的entry调用了这个函数，对kernel进行初始化
  * cons_init：初始化console
  * mem_init：初始化kernel address space
  * env_init：初始化所有的环境
  * trap_init (still incomplete at this point)：初始化中断
  * env_create：创建一个用户环境
  * env_run：运行用户环境
    * env_pop_tf：从trapframe中还原这个用户环境所需要的寄存器状态

如果一切顺利，您的系统应该进入用户空间并执行hello二进制文件，直到它使用int指令进行系统调用

**env_init**：确保所有的环境envs是空闲的状态,并初始化它们的 id 为 0,接着将它们插入到 env_free_list当中,确保环境在free list中的顺序与它们在envs数组中的顺序相同（即:使第一个调用的 env_alloc()返回envs[0]）
```c++
void
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
  for (int i = NENV - 1; i >= 0; --i) {
      envs[i].env_id = 0;
      envs[i].env_status = ENV_FREE;
      envs[i].env_link = env_free_list;
      env_free_list = &envs[i];
  }
	// Per-CPU part of the initialization
	env_init_percpu();
}
```

**env_setup_vm**: 直接把内核的页表目录拿过来用就行，且为Page Directory分配的新page应该增加引用统计次数pp_ref，UTOP以上的地址对用户应该为可读可写的，唯独UVPT是只可读

```c++
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct PageInfo *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;

	// LAB 3: Your code here.
	e->env_pgdir = (pde_t *) page2kva(p);
    //复制内核页目录, 因为在UTOP之上与kern_pgdir是一样的，所以可以直接把kern_pgdir的内容全部拷贝过来
    memcpy((void *) e->env_pgdir, kern_pgdir, PGSIZE); 
    p->pp_ref++;

	// 唯独UVPT这个地方是不一样的，因为要放的是自己的页表目录，所以只可读
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

	return 0;
}
```

**region_alloc**: 为env环境分配 len个字节物理地址内存, 并且将此物理地址映射到环境地址空间的虚拟地址va上，一个给 load_icode() 用的辅助函数，这里和 lab2 的函数原理类似

```c++
static void
region_alloc(struct Env *e, void *va, size_t len)
{
	// LAB 3: Your code here.
	// (But only if you need it for load_icode.)
	void *begin = (void *) ROUNDDOWN((uint32_t) va, PGSIZE), *end = (void *) ROUNDUP((uint32_t) va + len, PGSIZE);
    struct PageInfo *p = NULL;
    for (void *curVa = begin; curVa < end; curVa += PGSIZE) {
        p = page_alloc(ALLOC_ZERO);
		if(!p) {
          panic("region alloc error! error:%e", -E_NO_MEM);
        }
        if (page_insert(e->env_pgdir, p, curVa, PTE_U | PTE_W)) {
            panic("region alloc error! error:%e", -E_NO_MEM);
        }
    }
}
```

**load_icode**：首先需要了解ELF，Proghdr和Secthdr这三个与elf文件有关的结构体

![](fig/2024-05-09-18-22-01.png)

```c++
// elf文件整体结构体
struct Elf {
	uint32_t e_magic;	 // ELF 文件的标识符，必须等于 ELF_MAGIC，用于标识文件是否为 ELF 格式
	uint8_t  e_elf[12];  // 保留的 12 字节，通常不使用
	uint16_t e_type;     // 描述 ELF 文件的类型，比如可执行文件、共享目标文件等
	uint16_t e_machine;  // 描述目标体系结构的标识符，指示了文件运行的平台
	uint32_t e_version;  // ELF 文件的版本号
	uint32_t e_entry;    // 程序的入口点（即程序启动时执行的第一条指令的地址）
	uint32_t e_phoff;    // 程序头表（Program Header Table）在文件中的偏移量，即程序头表的起始位置
	uint32_t e_shoff;    // 节头表（Section Header Table）在文件中的偏移量，即节头表的起始位置
	uint32_t e_flags;    // 特定标志的位掩码，用于描述文件的属性
	uint16_t e_ehsize;   // ELF 头的大小，以字节为单位
	uint16_t e_phentsize;// 程序头表中每个条目的大小
	uint16_t e_phnum;    // 程序头表中条目的数量
	uint16_t e_shentsize;// 节头表中每个条目的大小
	uint16_t e_shnum;    // 节头表中条目的数量
	uint16_t e_shstrndx; // 节头表中字符串表节的索引
};

// 程序头表结构体
struct Proghdr {
	uint32_t p_type;     // 段（segment）的类型，描述了段的用途和属性，比如代码段、数据段等
	uint32_t p_offset;   // 段在文件中的偏移量，即段的起始位置距文件开始的字节偏移量
	uint32_t p_va;       // 段在内存中的虚拟地址（Virtual Address），即段加载到内存后在虚拟地址空间中的地址
	uint32_t p_pa;       // 段在内存中的物理地址（Physical Address），即段加载到内存后在物理地址空间中的地址
	uint32_t p_filesz;   // 段在文件中的大小，以字节为单位
	uint32_t p_memsz;    // 段在内存中的大小，以字节为单位。通常大于等于 p_filesz，表示在内存中需要分配的空间大小
	uint32_t p_flags;    // 段的标志位，描述了段的属性，比如可读、可写、可执行等
	uint32_t p_align;    // 段在文件和内存中的对齐要求，即段在文件中和内存中的起始地址的对齐方式
};

// 节头表结构体
struct Secthdr {
	uint32_t sh_name;    // 节名称在字符串表中的偏移量或索引，用于定位节的名称
	uint32_t sh_type;    // 节的类型，描述了节的内容和属性，比如代码节、数据节、符号表节等
	uint32_t sh_flags;   // 节的标志位，描述了节的属性，比如可读、可写、可执行等
	uint32_t sh_addr;    // 节在内存中的虚拟地址，如果节在内存中被加载，则表示其在内存中的起始地址
	uint32_t sh_offset;  // 节在文件中的偏移量，即节的起始位置距文件开始的字节偏移量
	uint32_t sh_size;    // 节在文件中的大小，以字节为单位
	uint32_t sh_link;    // 与该节相关联的其他节的索引，具体含义取决于节的类型
	uint32_t sh_info;    // 额外的节信息，具体含义取决于节的类型
	uint32_t sh_addralign;// 节在文件和内存中的对齐要求，即节在文件中和内存中的起始地址的对齐方式
	uint32_t sh_entsize; // 如果节包含固定大小的条目，则为每个条目的大小；否则为 0
};
```

ELF 文件中的程序头表（Program Header Table）和节头表（Section Header Table）有以下区别：

程序头表（Program Header Table）：

* 用于描述可执行文件或可装载文件在内存中的段（segments）布局
* 包含了每个段在文件中的偏移量、大小、加载地址等信息
* 在运行时由操作系统加载，用于映射文件内容到内存
* 典型的段包括代码段、数据段、动态链接信息段等

节头表（Section Header Table）：

* 用于描述 ELF 文件中的各个节（sections）的布局和属性
* 每个节包含了特定类型的信息，如代码、数据、符号表、字符串表等
* 包含了每个节在文件中的偏移量、大小、类型等信息
* 主要用于链接器（linker）和调试器（debugger）等工具处理 ELF 文件时定位和处理各个节

```c++
static void
load_icode(struct Env *e, uint8_t *binary)
{
	// LAB 3: Your code here.
	struct Elf *elf;
    struct Proghdr *ph, *eph;

    elf = (struct Elf *) binary;
    ph = (struct Proghdr *) ((uint8_t *) elf + elf->e_phoff); // 取到第一个段
    eph = ph + elf->e_phnum; // 取到最后一个段之后

    lcr3(PADDR(e->env_pgdir)); //设置当前的页目录寄存器为 当前环境(进程)的页目录物理地址,为什么要这么做？因为下面的memset、memcpy函数默认以页目录寄存器存的值为页目录

    for (; ph < eph; ph++) {
        if (ph->p_type != ELF_PROG_LOAD) continue;
        region_alloc(e, (void *) ph->p_va, ph->p_memsz); // 为每个段分配物理内存
        memset((void *) ph->p_va, 0, ph->p_memsz); // 先全部清零
        memcpy((void *) ph->p_va, binary + ph->p_offset, ph->p_filesz); // 再把段的内容写到这个内存上
    }
    e->env_tf.tf_eip = elf->e_entry; // 配置好用户环境的内核栈,相当于就是首次运行到这个环境之后, e_entry是作为第一个要进入并执行的代码区域.(入口代码具体参考kern/entry.S文件)

    lcr3(PADDR(kern_pgdir));
	
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.
	// LAB 3: Your code here.
	region_alloc(e, (void *) (USTACKTOP - PGSIZE), PGSIZE);
}
```

**env_create**：先初始化该环境（实际是对新的环境结构体new_e的各个成员的赋值），接着调用load_icode将该环境需要运行的用户进程从elf文件中载入进内存中

```c++
void
env_create(uint8_t *binary, enum EnvType type)
{
	// LAB 3: Your code here.
	struct Env *new_e;
    int r;
    if ((r = env_alloc(&new_e, 0)) != 0)
        panic("env_alloc: %e", r);
    load_icode(new_e, binary);
    new_e->env_type = type;
}
```
其中的env_alloc对结构体指针new_e所指向的环境的各个成员进行赋值如下

```c++
e->env_parent_id = parent_id;
e->env_type = ENV_TYPE_USER;
e->env_status = ENV_RUNNABLE;
e->env_runs = 0;

// 为段寄存器设置适当的初始值.
// GD_UD是GDT中的用户数据段选择器,
// GD_UT是用户文本段选择器(见inc/memlayout.h).
// 每个段寄存器的低2位包含请求者权限级别(俗称RPL); 3表示用户模式.
// 当我们切换权限级别时,硬件会进行各种检查,涉及到RPL和描述符本身所存储的描述符权限级别（俗称DPL）
#define GD_UT     0x18     // user text
#define GD_UD     0x20     // user data
e->env_tf.tf_ds = GD_UD | 3;
e->env_tf.tf_es = GD_UD | 3;
e->env_tf.tf_ss = GD_UD | 3;
e->env_tf.tf_esp = USTACKTOP;
e->env_tf.tf_cs = GD_UT | 3;
```

**env_run**：若是进行环境切换（通过curenv是否为NULL来判断是否是环境切换，一开始没有环境运行时curenv是NULL），接着将新环境指针赋给curenv，接着将新环境的状态改为running，旧环境的状态改为runnable，再更新环境运行次数，再将页目录设为新环境的页目录，最后恢复寄存器现场

```c++
void
env_run(struct Env *e)
{
	// LAB 3: Your code here.
	if (curenv != NULL && curenv->env_status == ENV_RUNNING)
        curenv->env_status = ENV_RUNNABLE;
    curenv = e;
    curenv->env_status = ENV_RUNNING;
    curenv->env_runs++;
    lcr3(PADDR(curenv->env_pgdir));

    cprintf("start env_pop and running...\n"); // 临时加上，为了确认程序是否运行到此处

    env_pop_tf(&curenv->env_tf);
	// panic("env_run not yet implemented");
}
```

其中恢复现场的函数的实现如下

```c++
void
env_pop_tf(struct Trapframe *tf)
{
	asm volatile(
		"\tmovl %0,%%esp\n"
		"\tpopal\n"
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret\n"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
}
```

完成后，运行操作系统，在初始化好env后，会将hello这个elf文件通过env_create函数加载到第一个环境中，该函数被宏包装后放入i386_init中

```c++
#define ENV_CREATE(x, type)						\
	do {								\
		extern uint8_t ENV_PASTE3(_binary_obj_, x, _start)[];	\
		env_create(ENV_PASTE3(_binary_obj_, x, _start),		\
			   type);					\
	} while (0)

#endif // !JOS_KERN_ENV_H

ENV_CREATE(user_hello, ENV_TYPE_USER); // 其中user_hello就是对应了hello的elf文件
```

运行后显示报错，如图

![](fig/2024-05-09-23-35-05.png)

这是因为现在还没有实现中断，所以会在user_hello第一次进行system call的时候报triple fault的错。这是因为：当CPU发现它没有设置来处理这个系统调用中断，它将生成一个一般保护异常，发现它不能处理，生成一个双故障异常，发现它不能处理，最后放弃所谓的“三重故障”

但是字符串“start env_pop and running...”已经被打印，说明程序已经运行到env_run函数了，接下来就是进入env_pop_tf函数，然后进入中断，但中断现在还没实现，所以接下来就会报错

为了验证只有中断这个已知的问题，进行打断点后单步调试

将断点打在env_pop_tf函数，然后输入c快进到这个断点处，然后不断输入si单步调试，可看到后面开始出现问号 (in ??) ，表示已经出错了

![](fig/2024-05-09-23-48-50.png)

##### exercise 3

阅读[《80386 Programmer's Manual》的第九章](https://pdos.csail.mit.edu/6.828/2018/readings/i386/c09.htm)了解异常和中断

[参考翻译](https://jianzzz.github.io/2017/08/26/%E5%BC%82%E5%B8%B8%E5%92%8C%E4%B8%AD%E6%96%AD/)

中断和异常的区别是，中断interrupts用于处理处理器外部的异步事件，异常exceptions用于处理处理器在执行指令时检测到的情况
* 外部中断的两个来源：
  * 可屏蔽中断Maskable interrupts，通过INTR pin来发送信号
    * 允许中断标志位IF（interrupt-enable flag）控制着是否接受经由INTR pin的外部中断信号。当IF=0，禁止INTR中断；当IF=1，允许INTR中断。处理器接收到RESET信号后，将清除IF和其他标志位
      * 显式改变IF：CLI(Clear Interrupt-Enable Flag)和STI(Set Interrupt-Enable Flag)显式改变IF
      * 隐式改变IF：1、指令PUSHF将会在栈上存储所有的标识，包括IF。2、任务切换和指令POPF、IRET将加载标志寄存器，会修改IF。3、中断门interrupt gates自动重置IF，禁止中断  
  * 不可屏蔽中断Nonmaskable interrupts，通过NMI (Non-Maskable Interrupt) pin来发送信号
    * 如果正在执行一个不可屏蔽中断的处理程序，处理器将忽略其他来自NMI pin的中断信号，直至执行IRET指令 
* 异常的两个来源：
  * 处理器检测。进一步分为故障faults、陷阱traps和中止aborts
  * 编程。指令INTO、INT 3、INT n、BOUND可以引发异常。这些指令通常被称为“软件中断”，但处理器把它们当作异常处理

异常被分为故障（Faults）、陷阱（Traps）、终止（Aborts）
* 故障：在指令开始执行之前或在指令执行期间检测到。如果在指令期间检测到故障，则报告故障，机器恢复到允许重新启动指令的状态
* 陷阱：在检测到异常的指令之后立即在指令边界报告的异常
* 终止：既不允许获取引起异常的指令的精确位置，也不允许重启导致异常的程序。终止用于报告严重的错误，比如硬件错误和不一致、系统表的非法值

处理器只在一条指令结束及下一条指令开始之际处理异常和中断。在指令边界，处理器通过某些条件和标识设置禁止某些异常和中断

> 指令边界（instruction boundaries）是在编程或计算机系统中，指令或代码段之间的分隔点或边界。这些边界可以表示不同的功能模块、程序段或代码块之间的分隔点。在程序中，指令边界的存在有助于组织和管理代码结构，提高代码的可读性、维护性和可重用性。同时，指令边界也有助于实现代码的模块化和封装，使得代码更易于理解和维护

软件经常需要使用成对的指令来改变堆栈段，比如MOV SS, AX、MOV ESP, StackTop。如果SS已经改变而ESP还未收到相应的改变的时候处理异常或中断，中断或异常处理程序执行期间栈指针SS:ESP是不一致的。为了防止这种情况的发生，80386在执行MOV SS和POP SS指令之后，在下一条指令的指令边界内禁止NMI、INTR、debug exceptions、single-step traps。但是页错误和保护错误仍可能发生，若使用80386 LSS指令，则不会出现这些问题

**异常和中断的优先级**：低优先级的异常被丢弃，低优先级的中断保持等待。在中断处理程序返回控制权的时候，被丢弃的异常将被重新发现

```
HIGHEST     Faults except debug faults (除了调试故障以外的其他故障)
  |         Trap instructions INTO, INT n, INT 3
  |         Debug traps for this instruction
  |         Debug faults for next instruction
  |         NMI interrupt
LOWEST      INTR interrupt
```

> 调试故障或陷阱是指为了调试和诊断目的而人为引入的故障或陷阱
> 
> 在实际应用中，调试陷阱（debug traps）可以通过在代码中插入**调试断点、设置条件断点或者使用特定的调试指令**来实现。当程序执行到设定的调试陷阱位置时，调试器会暂停程序执行，并提供相应的调试信息，使得程序员能够检查程序状态并进行调试

**中断描述符表**

> IDT (Interrupt Descriptor Table)：中断描述符表是用于处理中断和异常的数据结构。在 x86 架构中，IDT 是一个由中断描述符组成的表，每个中断描述符包含了处理特定中断或异常时应该跳转到的处理程序地址
> 
> GDT (Global Descriptor Table)：全局描述符表是用于管理内存分段的数据结构。在 x86 架构中，GDT 存储了系统中所有段的描述符，包括代码段、数据段、堆栈段等。每个描述符包含了段的基地址、限制、访问权限等信息
> 
> LDT (Local Descriptor Table)：局部描述符表是一种特殊的描述符表，用于存储特定进程或任务的段描述符。每个进程都可以有自己的 LDT，用于管理私有段或与其他进程隔离的段

处理器使用IDTR寄存器来定位IDT表的位置。这个寄存器中含有IDT表32位的基地址和16位的长度（限长）值。IDT表基地址应该对齐在8字节边界上以提高处理器的访问效率。限长值是以字节为单位的IDT表的长度

LIDT和SIDT指令分别用于加载和保存IDTR寄存器的内容
* LIDT用于创建IDT时的操作系统初始化代码中
* SIDT用于把IDTR中的基地址和限长内容复制到内存中

![](fig/2024-05-10-21-43-51.png)

IDT可能包括3种描述符：
* Task gates（用于任务切换）
* Interrupt gates（用于处理中断请求（IRQ）和异常）
* Trap gates（用于捕获和处理一些需要在特权级别下运行的异常，如系统调用）

![](fig/2024-05-10-21-45-25.png)

通用寄存器EFLAGS保存的是CPU的执行状态和控制信息，在这里只需要关注两个寄存器：IF和TF
* TF(Trap Flag)：跟踪标志。置1则开启单步执行调试模式，置0则关闭。在单步执行模式下，处理器在每条指令后产生一个调试异常，这样在每条指令执行后都可以查看执行程序的状态
* IF(Interrupt enable)：中断许可标志。控制处理器对可屏蔽硬件中断请求的响应。置1则开启可屏蔽硬件中断响应，置0则关闭。IF标志不影响异常和不可屏蔽终端NMI的产生

![](fig/2024-05-10-21-50-54.png)

**中断过程**

中断门或陷阱门间接指向一个处理程序，该程序将在当前执行任务的上下文中被执行。中断门或陷阱门的选择器（selector）指向了GDT或当前LDT的一个可执行段描述符。中断门或陷阱门的偏移部分指向了中断或异常处理程序的起始位置

![](fig/2024-05-10-22-09-11.png)

就像CALL指令导致控制转移一样，中断或异常处理程序的控制转移使用了栈存储了返回原先程序需要的信息。一个中断将在指针指向中断指令之前将EFLAGS进栈，如下图所示。某些异常会导致error code进栈，异常处理函数可以通过error code判断是什么异常

![](fig/2024-05-10-22-12-04.png)

中断程序离开程序的方法也不同于普通程序，它将使用IRET指令离开。通过中断门或陷阱门的中断在当前TF作为EFLAGS的一部分被保存到栈后，将清零TF。通过这个动作处理器可以防止使用单步调试活动影响中断响应。随后IRET指令恢复EFLAGS在栈上的值，也恢复了TF
* 经由中断门的中断将重置IF，防止其他中断干扰当前的中断处理程序，随后IRET指令恢复EFLAGS在栈上的值
* 经由陷阱门的中断将不改变IF

任务门间接指向一个任务，任务门的选择器指向GDT的TSS描述符

![](fig/2024-05-10-22-18-31.png)

经由任务门的中断或陷阱的结果是出现一个任务切换。使用一个单独任务来处理中断有两个优点：
* 整个上下文将被自动保存
* 通过LDT或页目录给予处理程序单独的地址空间，使其独立于其他任务

当80386操作系统使用中断任务时，实际上有两个调度器：软件调度器(操作系统的一部分)和硬件调度器(处理器的中断机制的一部分)。软件调度器的设计应该考虑一种情况：在启用中断时，硬件调度器随时可能派遣一个中断任务