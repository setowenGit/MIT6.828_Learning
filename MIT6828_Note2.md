# MIT 6.828 Learning 2

##### [课程表](https://pdos.csail.mit.edu/6.828/2018/schedule.html)

##### [调试指令列表](https://pdos.csail.mit.edu/6.828/2018/labguide.html)

##### [Github参考](https://github.com/setowenGit/MIT6.828_OS)

##### [Gitee参考](https://gitee.com/rcary/mit6.828/tree/master)

##### [Github参考2](https://github.com/clpsz/mit-jos-2014/tree/master)

##### [知乎参考](https://zhuanlan.zhihu.com/p/166413604)

##### [Github参考3](https://github.com/yunwei37/6.828-2018-labs?tab=readme-ov-file)

##### [lecture的翻译笔记](https://zhuzilin.github.io/blog/tags/6-828/)

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
    a = PGROUNDDOWN(rcr2()); // 使用PGROUNDDOWN（va）将有问题的虚拟地址向下舍入到页面边界
    for(;a<myproc()->sz;a+=PGSIZE){
      mem = kalloc();
      if(mem==0){
       cprintf("allocuvm out of memory\n");
       deallocuvm(myproc()->pgdir,myproc()->sz,myproc()->tf->eax);
       return ;
      }
      memset(mem,0,PGSIZE);
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