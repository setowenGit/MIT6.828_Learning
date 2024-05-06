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

