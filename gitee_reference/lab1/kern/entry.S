/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>

# Shift Right Logical 
#define SRL(val, shamt)		(((val) >> (shamt)) & ~(-1 << (32 - (shamt))))


###################################################################
# The kernel (this code) is linked at address ~(KERNBASE + 1 Meg), 
# but the bootloader loads it at address ~1 Meg.
#
# 内核（这段代码）在地址~（KERNBASE + 1 Meg）处被链接。
# 但引导程序在地址~1Meg处加载它。
#	
# RELOC(x) maps a symbol x from its link address to its actual
# location in physical memory (its load address).	 
#	
# RELOC(x)作用是将链接地址x转化为物理地址(在物理内存中的位置)
###################################################################


#define	RELOC(x) ((x) - KERNBASE)

#define MULTIBOOT_HEADER_MAGIC (0x1BADB002)
#define MULTIBOOT_HEADER_FLAGS (0)
#define CHECKSUM (-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS))

###################################################################
# entry point
# 入口
###################################################################

.text

# The Multiboot header
.align 4
.long MULTIBOOT_HEADER_MAGIC
.long MULTIBOOT_HEADER_FLAGS
.long CHECKSUM

# '_start' specifies the ELF entry point.  Since we haven't set up
# virtual memory when the bootloader enters this code, we need the
# bootloader to jump to the *physical* address of the entry point.
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot

	# We haven't set up virtual memory yet, so we're running from
	# the physical address the boot loader loaded the kernel at: 1MB
	# (plus a few bytes).  However, the C code is linked to run at
	# KERNBASE+1MB.  Hence, we set up a trivial page directory that
	# translates virtual addresses [KERNBASE, KERNBASE+4MB) to
	# physical addresses [0, 4MB).  This 4MB region will be
	# sufficient until we set up our real page table in mem_init
	# in lab 2.
	# 因为我们还没有设置虚拟内存,所以我们从boot loader加载内核时的物理地址是:1MB（加上几个字节）.
    # 当然了，C代码现在已经被链接并到运行在KERNBASE+1MB上了.所以呢，我们设置了一个临时的页面目录,
	# 它可以将虚拟地址[KERNBASE, KERNBASE+4MB]转换为 物理地址[0, 4MB]。
	# 这个4MB的区域是足够的了(对于目前的实验)，直到我们在实验二mem_init中再建立真正的页表.
	# 

	# Load the physical address of entry_pgdir into cr3.
	# entry_pgdir is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
	movl	%eax, %cr3
	# Turn on paging.
	movl	%cr0, %eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax #CR0_PG开启分页 CR0_PE开启保护模式 CR0_WP 开启写入保护
	movl	%eax, %cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering C code.
	# 现在分页功能已经启用，但我们仍在低EIP下运行(为什么会这样？).
	# 因为在进入C代码之前，先跳入了KERNBASE之上(的物理地址)
	mov	$relocated, %eax
	jmp	*%eax
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	# 清除帧指针寄存器（EBP）
	# 这样一旦我们开始调试C代码，
	# 堆栈回溯将正常终止。

	movl	$0x0,%ebp			# nuke frame pointer 作用为：清除ebp指针

	# Set the stack pointer
	# 设置esp堆栈指针
	movl	$(bootstacktop),%esp

	# now to C code
	# 现在进入C函数
	call	i386_init

	# Should never get here, but in case we do, just spin.
	# 应该永远不会到这里，但万一我们到了，就跳转到spin吧 。
spin:	jmp	spin


.data
###################################################################
# boot stack
# 启动堆栈
###################################################################
	.p2align	PGSHIFT		# force page alignment 强制的页面对齐
	.globl		bootstack
bootstack:
	.space		KSTKSIZE 	# KSTKSIZE是 KernelStackSize的缩写
					# 在(inc/memlayout)中定义为↓	
				       # define KSTKSIZE (8*PGSIZE=32KB)[其中PGSIZE=4096=4KB]
	.globl		bootstacktop   
bootstacktop:

