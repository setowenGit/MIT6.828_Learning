#ifndef JOS_INC_MEMLAYOUT_H
#define JOS_INC_MEMLAYOUT_H

#ifndef __ASSEMBLER__
#include <inc/types.h>
#include <inc/mmu.h>
#endif /* not __ASSEMBLER__ */

/*
 * This file contains definitions for memory management in our OS,
 * which are relevant to both the kernel and user-mode software.
 */

// Global descriptor numbers
#define GD_KT     0x08     // kernel text 内核文本段
#define GD_KD     0x10     // kernel data 内核数据段
#define GD_UT     0x18     // user text
#define GD_UD     0x20     // user data
#define GD_TSS0   0x28     // Task segment selector for CPU 0

/*       虚拟内存分布图： 
 * Virtual memory map:                                Permissions 权限
 *                                                    kernel/user 内核/用户
 *
 *    4 Gig -------->  +------------------------------+                 --+
 *                     |                              | RW/--             | 
 *                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~                   |
 *                     :              .               :                   |
 *                     :              .               :                   |
 *                     :              .               :                 4Gig-256MB
 *                     |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~| RW/--             |
 *                     |                              | RW/--             |
 *                     |   Remapped Physical Memory   | RW/--             |
 *                     |                              | RW/--             |
 *    KERNBASE, ---->  +------------------------------+ 0xf0000000      --+
 *    KSTACKTOP        |     CPU0's Kernel Stack      | RW/--  KSTKSIZE   |
 *                     | - - - - - - - - - - - - - - -|                   |
 *                     |      Invalid Memory (*)      | --/--  KSTKGAP    |
 *                     |            无效内存  (*)      |
 *                     +------------------------------+                   |
 *                     |     CPU1's Kernel Stack      | RW/--  KSTKSIZE   |
 *                     | - - - - - - - - - - - - - - -|                 PTSIZE 4MB 
 *                     |      Invalid Memory (*)      | --/--  KSTKGAP    |
 *                     |            无效内存  (*)      | 
 *                     +------------------------------+                   |
 *                     :              .               :                   |
 *                     :              .               :                   |
 *    MMIOLIM ------>  +------------------------------+ 0xefc00000      --+
 *                     |       Memory-mapped I/O      | RW/--  PTSIZE 4MB
 * ULIM, MMIOBASE -->  +------------------------------+ 0xef800000 上部由内核控制 下部由用户控制
 *                     |  Cur. Page Table (User R-)   | R-/R-  PTSIZE
 *    UVPT      ---->  +------------------------------+ 0xef400000
 *                     |          RO PAGES            | R-/R-  PTSIZE
 *    UPAGES    ---->  +------------------------------+ 0xef000000
 *                     |           RO ENVS            | R-/R-  PTSIZE
 * UTOP,UENVS ------>  +------------------------------+ 0xeec00000
 * UXSTACKTOP -/       |     User Exception Stack     | RW/RW  PGSIZE
 *                     |           用户异常栈          |
 *                     +------------------------------+ 0xeebff000
 *                     |       Empty Memory (*)       | --/--  PGSIZE
 *    USTACKTOP  --->  +------------------------------+ 0xeebfe000
 *                     |      Normal User Stack       | RW/RW  PGSIZE
 *                     +------------------------------+ 0xeebfd000
 *                     |                              |
 *                     |                              |
 *                     ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *                     .                              .
 *                     .                              .
 *                     .                              .
 *                     |~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~|
 *                     |     Program Data & Heap      |
 *    UTEXT -------->  +------------------------------+ 0x00800000      --+
 *    PFTEMP ------->  |       Empty Memory (*)       |                 PTSIZE 
 *                     |                              |                   |
 *    UTEMP -------->  +------------------------------+ 0x00400000      --+
 *                     |       Empty Memory (*)       |                   |
 *                     | - - - - - - - - - - - - - - -|                   |
 *                     |  User STAB Data (optional)   |                 PTSIZE
 *    USTABDATA ---->  +------------------------------+ 0x00200000        |
 *                     |       Empty Memory (*)       |                   |
 *    0 ------------>  +------------------------------+                 --+
 *
 * (*) Note: The kernel ensures that "Invalid Memory" is *never* mapped.
 *     "Empty Memory" is normally unmapped, but user programs may map pages
 *     there if desired.  JOS user programs map pages temporarily at UTEMP.
 *      * (*)注意：内核确保 "无效内存 "永远不会被*映射。
        *  "Empty Memory "通常是不被映射的，但是如果需要的话，用户程序可以在那里映射页面。
        *  JOS用户程序在UTEMP处临时映射页面。
 */


// All physical memory mapped at this address
// 所有物理地址都会从从这里映射 --> 虚拟地址的起始
#define	KERNBASE	0xF0000000

// At IOPHYSMEM (640K) there is a 384K hole for I/O.  From the kernel,
// IOPHYSMEM can be addressed at KERNBASE + IOPHYSMEM.  The hole ends
// at physical address EXTPHYSMEM.
// 在Iophysem（640K）上有一个384K的孔用于输入/输出。
// 从内核来看，Iophysem可以在KERNBASE+Iophysem上寻址。该孔在物理地址extphysem处结束。
#define IOPHYSMEM	0x0A0000
#define EXTPHYSMEM	0x100000

// Kernel stack.内核栈
#define KSTACKTOP	KERNBASE
#define KSTKSIZE	(8*PGSIZE)   		// size of a kernel stack 内核栈空间 32KB
#define KSTKGAP		(8*PGSIZE)   		// size of a kernel stack guard 内核堆栈保护的大小 32KB

// Memory-mapped IO. IO使用的虚拟内存地址范围
#define MMIOLIM		(KSTACKTOP - PTSIZE)
#define MMIOBASE	(MMIOLIM - PTSIZE)
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
#define ULIM		(MMIOBASE)

/*
 * User read-only mappings! Anything below here til UTOP are readonly to user.
 * They are global pages mapped in at env allocation time.
 * 用户只读映射！为止到UTOP以下任何内容都是用户只读的。
 * 它们是在环境分配时映射到的全局页面。
 */

// User read-only virtual page table (see 'uvpt' below)
// 用户只读虚拟页面表（请参阅下面的“uvpt”）
#define UVPT		(ULIM - PTSIZE)
// Read-only copies of the Page structures
// 页面结构的只读副本
#define UPAGES		(UVPT - PTSIZE)
// Read-only copies of the global env structures
// 全局环境结构的只读副本
#define UENVS		(UPAGES - PTSIZE)

/*
 * Top of user VM. User can manipulate VA from UTOP-1 and down!
 */

// Top of user-accessible VM 用户可访问的虚拟机的最大值
#define UTOP		UENVS
// Top of one-page user exception stack 单页用户异常堆栈的顶部
#define UXSTACKTOP	UTOP
// Next page left invalid to guard against exception stack overflow; then:
// Top of normal user stack
// 下一页是无效的, 以防止异常堆栈溢出; 然后:
// 一般用户堆栈的顶部
#define USTACKTOP	(UTOP - 2*PGSIZE)

// Where user programs generally begin 用户程序的起点
#define UTEXT		(2*PTSIZE)

// Used for temporary page mappings.  Typed 'void*' for convenience
// 用于临时映射页。 为方便起见，将其打成 "void*"。
#define UTEMP		((void*) PTSIZE)
// Used for temporary page mappings for the user page-fault handler
// (should not conflict with other temporary page mappings)
// 用于用户页面故障处理的临时页面映射。
// (不应该与其他临时页面映射冲突)
#define PFTEMP		(UTEMP + PTSIZE - PGSIZE)
// The location of the user-level STABS data structure
// 用户级STABS数据结构的位置
#define USTABDATA	(PTSIZE / 2)

// Physical address of startup code for non-boot CPUs (APs)
#define MPENTRY_PADDR	0x7000

#ifndef __ASSEMBLER__

typedef uint32_t pte_t;
typedef uint32_t pde_t; // uint32_t 是一个32位的无符号整型

#if JOS_USER
/*
 * The page directory entry corresponding to the virtual address range
 * [UVPT, UVPT + PTSIZE) points to the page directory itself.  Thus, the page
 * directory is treated as a page table as well as a page directory.
 *
 * One result of treating the page directory as a page table is that all PTEs
 * can be accessed through a "virtual page table" at virtual address UVPT (to
 * which uvpt is set in lib/entry.S).  The PTE for page number N is stored in
 * uvpt[N].  (It's worth drawing a diagram of this!)
 *
 * A second consequence is that the contents of the current page directory
 * will always be available at virtual address (UVPT + (UVPT >> PGSHIFT)), to
 * which uvpd is set in lib/entry.S.
 *
 * 与虚拟地址范围相对应的PDE[UVPT, UVPT + PTSIZE)指向页目录本身。
 * 因此，该页目录被看作是一个页表以及一个页目录。
 *
 * 将页目录作为页表处理的一个结果是，所有的PTEs
 * 可以通过虚拟地址UVPT的 "虚拟页表 "来访问。
 * uvpt在lib/entry.S中被设置为）。 页号为N的PTE被存储在uvpt[N]。 (这值得画一张图！)
 *
 * 第二个结果是，当前页面目录的内容
 * 将在虚拟地址(UVPT + (UVPT >> PGSHIFT))上总是可用的，这个地址是
 * uvpd在lib/entry.S中被设置为该地址。
 */


extern volatile pte_t uvpt[];     // VA of "virtual page table"
extern volatile pde_t uvpd[];     // VA of current page directory
#endif

/*
 * Page descriptor structures, mapped at UPAGES.
 * Read/write to the kernel, read-only to user programs.
 *
 * Each struct PageInfo stores metadata for one physical page.
 * Is it NOT the physical page itself, but there is a one-to-one
 * correspondence between physical pages and struct PageInfo's.
 * You can map a struct PageInfo * to the corresponding physical address
 * with page2pa() in kern/pmap.h.

 * 页描述符结构，在UPAGES映射。
 * 对内核是读/写，对用户程序是只读。
 *
 * 每个结构PageInfo存储一个物理页的元数据。
 * 它不是物理页本身，但是物理页和结构PageInfo之间有一个一对一的对应关系。
 * 你可以将一个PageInfo结构映射到相应的物理地址, 使用kern/pmap.h中的page2pa()。
 
 */
struct PageInfo {
	// Next page on the free list. 空闲列表中的下一页。
	struct PageInfo *pp_link;

	// pp_ref is the count of pointers (usually in page table entries)
	// to this page, for pages allocated using page_alloc.
	// Pages allocated at boot time using pmap.c'sboot_alloc do not have valid reference count fields.
    //
    // pp_ref是指使用page_alloc分配的页面，指向该页面的指针（通常在页表项中）的数量。 
    // 使用pmap.c的boot_alloc在启动时分配的页面没有有效的引用计数域。
	uint16_t pp_ref;
};

#endif /* !__ASSEMBLER__ */
#endif /* !JOS_INC_MEMLAYOUT_H */
