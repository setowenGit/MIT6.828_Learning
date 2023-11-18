# MIT 6.828 Learning

##### [课程表](https://pdos.csail.mit.edu/6.828/2018/schedule.html)

##### [实验环境配置(其他报错问题可看评论区)](https://blog.csdn.net/Rcary/article/details/125547980?utm_source=app&app_version=4.17.0)

##### [Github参考](https://github.com/setowenGit/MIT6.828_OS)

##### [知乎参考](https://zhuanlan.zhihu.com/p/166413604)
---

## Lab 1

### PC Bootstrap

 * QEMU模拟器：一个现代和相对快速的模拟器。虽然QEMU的内置监视器只提供有限的调试支持，但QEMU可以作为GNU调试器的远程调试目标，我们将在这个实验室中使用它来完成早期引导过程。
 * ```make qemu``` 和 ```make qemu-nox```：开启带有和不带有独立显示窗口的QEMU模拟器
 * PC物理内存空间
   * 对于早起的的16位处理器PC，只能寻址1MB的物理内存，具体来说，8088使用一个16位的段寄存器和一个16位的偏移寄存器。物理地址的计算方式是将段地址左移4位（乘以16，16进制表示下是左移1位）然后加上偏移地址，即可以得到一个20位的地址，进一步地，这使得理论上可以访问$2^{20}$个地址，即1 MB 的物理内存
   * BIOS代码由ROM复制到0xF0000~0x100000的地方，对于现代32位处理器PC，BIOS的一部分代码还会复制到内存的末端

![](fig/2023-11-18-16-35-40.png)

现代32位处理器PC内存如下:

![](fig/2023-11-18-16-19-57.png)

* QEMU的debug模式：先一个终端运行```make qemu-nox-gdb```，后另外一个终端运行```make gdb```，使用```si```来进行调试步进
* 首先QEMU中执行的是BIOS代码，一开机通过硬件电路，BIOS代码直接加载到内存中，CS:IP会指向[0xf000:0xfff0]，CS左移一位就是0xffff0，指向的代码是一个jmp指令
* BIOS运行过程中，它设定了中断描述符表，对VGA显示器等设备进行了初始化。在初始化完PCI总线和所有BIOS负责的重要设备后，它就开始搜索软盘、硬盘、或是CD-ROM等可启动的设备。最终，当它找到可引导磁盘时，BIOS从磁盘读取引导加载程序并将控制权转移给它

![](fig/2023-11-18-17-15-35.png)

### The Boot Loader

* 当BIOS找到一个可引导的软盘或硬盘时，它将512字节的引导扇区加载到物理地址0x7c00到0x7dff的内存中，然后使用jmp指令将CS： IP设置为0000：7c00，并将控制传递给引导加载程序。
* 由于扇区最大为512B，boot loader必须满足于512字节。
* boot loader由一个汇编语言源文件 boot/boot.S 和一个C源文件 boot/main.c 组成
* boot loader必须执行两个主要功能：
  *  将处理器从real模式切换到32位保护模式，因为只有在保护模式下，软件才能访问处理器的物理地址空间中超过1MB的所有内存。在受保护的模式下，将[CS:IP]转换为物理地址的偏移量是32位，而不是16位（也就是段地址在十六进制下左移两位）
  *  通过x86的特殊I/O指令直接访问IDE磁盘设备寄存器，从而从硬盘中读取内核（也就是读取操作系统）
* obj/boot/boot.asm 是 boot.S 的反汇编，很有用，可以看到每个指令的确切物理位置 

#### boot.S

主要任务——从real模式切换为保护模式

```asm
#include <inc/mmu.h>

# Start the CPU: switch to 32-bit protected mode, jump into C.
# The BIOS loads this code from the first sector of the hard disk into
# memory at physical address 0x7c00 and starts executing in real mode
# with %cs=0 %ip=7c00.

.set PROT_MODE_CSEG, 0x8         # kernel code segment selector
.set PROT_MODE_DSEG, 0x10        # kernel data segment selector
.set CR0_PE_ON,      0x1         # protected mode enable flag 这个变量是开启A20地址线的标志，为1是开启保护模式

.globl start

start:
  .code16                     # Assemble for 16-bit mode
  cli                         # Disable interrupts 关中断
  cld                         # String operations increment 将direct flag标志位清零，这意味着自动增加源索引和目标索引的指令(如MOVS)将同时增加它们

  # Set up the important data segment registers (DS, ES, SS). 相当于全部置0
  xorw    %ax,%ax             # Segment number zero
  movw    %ax,%ds             # -> Data Segment
  movw    %ax,%es             # -> Extra Segment
  movw    %ax,%ss             # -> Stack Segment

  # Enable A20:
  #   For backwards compatibility with the earliest PCs, physical
  #   address line 20 is tied low, so that addresses higher than
  #   1MB wrap around to zero by default.  This code undoes this.
  #   由于历史原因A20地址位由键盘控制器芯片8042管理。所以要给8042发命令激活A20
  #   8042有两个IO端口：0x60和0x64， 激活流程位： 发送0xd1命令到0x64端口 --> 发送0xdf到0x60

seta20.1:
  inb     $0x64,%al               # Wait for not busy 从0x64读取8位并传到a寄存器的低8位
  testb   $0x2,%al                # 进行与运算，但不会改变a寄存器的值，只会改变标志位，发送命令之前，要等待键盘输入缓冲区为空，这通过8042的状态寄存器的第2bit来观察
  jnz     seta20.1                # ZF标志位不为0时跳转，如果状态寄存器的第2位为1，就跳到seta20.1符号处执行，知道第2位为0，代表缓冲区为空
  movb    $0xd1,%al               # 0xd1 -> port 0x64
  outb    %al,$0x64               # 发送0xd1到0x64端口

seta20.2:
  inb     $0x64,%al               # Wait for not busy
  testb   $0x2,%al
  jnz     seta20.2
  movb    $0xdf,%al               # 0xdf -> port 0x60
  outb    %al,$0x60               # 与上述相似，发送0xdf到0x60端口

  # Switch from real to protected mode, using a bootstrap GDT
  # and segment translation that makes virtual addresses 
  # identical to their physical addresses, so that the 
  # effective memory map does not change during the switch.
  # A20激活完成，转入保护模式

  lgdt    gdtdesc                 # lgdt命令加载全局描述符，指定一个临时的GDT，来翻译逻辑地址。这里使用的GDT通过gdtdesc段定义。它翻译得到的物理地址和虚拟地址相同，所以转换过程中内存映射不会改变

  # 打开保护模式标志位，相当于按下了保护模式的开关。cr0寄存器的第0位就是这个开关，通过CR0_PE_ON或cr0寄存器，将第0位置1
  movl    %cr0, %eax
  orl     $CR0_PE_ON, %eax        # 或运算
  movl    %eax, %cr0

  # Jump to next instruction, but in 32-bit code segment.
  # Switches processor into 32-bit mode.
  ljmp    $PROT_MODE_CSEG, $protcseg  # PROT_MODE_CSEG是0x8，选择子选择了GDT中的第1个段描述符，即保护模式下跳转到代码段（详细见下图）

  .code32                     # Assemble for 32-bit mode
protcseg:
  # Set up the protected-mode data segment registers 重新初始化各个段寄存器
  movw    $PROT_MODE_DSEG, %ax    # Our data segment selector
  movw    %ax, %ds                # -> DS: Data Segment
  movw    %ax, %es                # -> ES: Extra Segment
  movw    %ax, %fs                # -> FS
  movw    %ax, %gs                # -> GS
  movw    %ax, %ss                # -> SS: Stack Segment

  # Set up the stack pointer and call into C.
  movl    $start, %esp            # 栈顶设定在start处，也就是地址0x7c00处
  call bootmain                   # call函数将返回地址入栈，将控制权交给bootmain

  # If bootmain returns (it shouldn't), loop.
spin:
  jmp spin

# Bootstrap GDT
.p2align 2                                # force 4 byte alignment
# 定义全局描述符表
gdt:
  SEG_NULL				# null seg
  SEG(STA_X|STA_R, 0x0, 0xffffffff)	# code seg 代码段
  SEG(STA_W, 0x0, 0xffffffff)	        # data seg 数据段

# 构造gdt结构
gdtdesc:
  .word   0x17                            # sizeof(gdt) - 1
  .long   gdt                             # address gdt
```

保护模式下的寻址方式

![](fig/2023-11-18-21-54-52.png)

#### main.c

主要功能——将内核从硬盘读取进内存，可以把ELF可执行文件简单地看为带有加载信息的标头，后跟几个程序部分，每个程序部分都是一个连续的代码块或数据，其将被加载到指定内存中

内核，也就是操作系统，存储在地址从0x10000开始的内存中

#### exercise 6 问题
CPU从什么时候开始执行32-bit的代码？
* ```ljmp    $PROT_MODE_CSEG, $protcseg```及其之后

是什么导致了从16-bit到32-bit的切换？
* A20的激活，以及```movl    %eax, %cr0```

内核引导器最后执行和内核最先执行的指令是什么？干了什么事情？
* 内核引导器最后一个指令是```((void (*)(void)) (ELFHDR->e_entry))();```，由反汇编代码可看出程序跳转到地址*0x10018（注意是跳转到0x10018里面所存储的地址，而不是0x10018）
* 最后debug可以看到ELFHDR->e_entry的值为1048588。转化为十六进制，就是0x10000c，这个就是内核的入口
* 查看反汇编代码obj/kern/kernel.asm，可以看到，内核第一个指令的地址是0xf010000c，而C代码中函数跳转是到0x10000c
* 这个区别虚拟地址和物理地址的不同导致的。虚拟地址为ELF文件在产生时，连接器给函数绑定的地址。处理器会进行地址映射，将虚拟地址映射到真实物理地址
* 内核最先执行的指令是```readseg((uint32_t) ELFHDR, SECTSIZE*8, 0);```，读取进来的是一个镜像，也就是ELF文件的部分内容。读取进来的信息包含了文件头，真正的读取还要根据文件头中包含的信息执行，之后main里面做的就是将内核一块一块一次读进内存中，即
```c++
for (; ph < eph; ph++)
	readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
```

内核的第一个指令的地址是什么？
* 0xf010000c

内核引导器如何知道应该将多大的磁盘空间拷贝进内存？这个信息存放在哪里？
* 加载内核的过程就是一种加载elf文件的过程
* 解析elf文件可以得到内核每一块的size大小，也就知道要拷贝的内核有多大