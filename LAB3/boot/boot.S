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

