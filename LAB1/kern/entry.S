/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>

# Shift Right Logical 
#define SRL(val, shamt)		(((val) >> (shamt)) & ~(-1 << (32 - (shamt))))


###################################################################
# The kernel (this code) is linked at address ~(KERNBASE + 1 Meg), 
# but the bootloader loads it at address ~1 Meg.
#	
# RELOC(x) maps a symbol x from its link address to its actual
# location in physical memory (its load address).	 
###################################################################

#define	RELOC(x) ((x) - KERNBASE)

#define MULTIBOOT_HEADER_MAGIC (0x1BADB002)
#define MULTIBOOT_HEADER_FLAGS (0)
#define CHECKSUM (-(MULTIBOOT_HEADER_MAGIC + MULTIBOOT_HEADER_FLAGS))

###################################################################
# entry point
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
# RELOC重定位信息的占位符，这表明在链接过程中需要确定_start符号的地址
# _start符号是全局可见的，并且它的地址将在稍后的链接过程中确定。
# 我理解的是_start符号就相当于entry入口
.globl		_start
_start = RELOC(entry)

# 在这里才正式进入内核入口
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

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	# 设置cr3页目录基址寄存器，保存页目录表的物理地址
	movl	$(RELOC(entry_pgdir)), %eax
	movl	%eax, %cr3

	# Turn on paging.
	# 设置cr0开启分页
	movl	%cr0, %eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
	movl	%eax, %cr0
	
	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	# 进入下面的relocated段
	mov	$relocated, %eax
	jmp	*%eax

relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	# 清除帧指针寄存器（EBP）
	# 这样一旦我们开始调试C代码，
	# 堆栈回溯将正常终止。
	movl	$0x0,%ebp			# nuke frame pointer

	# Set the stack pointer
	# 设置esp堆栈指针
	movl	$(bootstacktop),%esp

	# now to C code
	# 现在进入C函数，正式进行内核初始化
	call	i386_init

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin


.data
###################################################################
# boot stack
###################################################################
	.p2align	PGSHIFT		# force page alignment
	.globl		bootstack
bootstack:
	.space		KSTKSIZE
	.globl		bootstacktop   
bootstacktop:

