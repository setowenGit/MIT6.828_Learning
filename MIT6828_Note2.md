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

现在需要在kern/env.c文件中写代码来运行用户环境。因为暂时还没有一个文件系统，所以将设置内核来加载一个静态二进制映像，它嵌入在内核本身中。JOS将这个二进制文件作为ELF可执行映像嵌入到内核中。

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

因为并没有初始化中断，所以会在user_hello第一次进行system call的时候报triple fault的错。这是因为：当CPU发现它没有设置来处理这个系统调用中断，它将生成一个一般保护异常，发现它不能处理，生成一个双故障异常，发现它不能处理，最后放弃所谓的“三重故障”

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

    // UTOP以下都是可读可写的
    for (pde_t *pde = e->env_pgdir; pde < (pde_t*)((uintptr_t)e->env_pgdir + PGSIZE); ++pde) {
        *pde |= PTE_U | PTE_W;
    }

	// 但是唯独UVPT这个地方是不一样的，因为要放的是自己的页表目录，所以只可读
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

	return 0;
}

```











