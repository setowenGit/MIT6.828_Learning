#ifndef JOS_INC_MMU_H
#define JOS_INC_MMU_H

/*
 * This file contains definitions for the x86 memory management unit (MMU),
 * including paging- and segmentation-related data structures and constants,
 * the %cr0, %cr4, and %eflags registers, and traps.

 * 该文件包含x86内存管理单元（MMU）的定义。
 * 包括与分页和分段有关的数据结构和常量。
 * %cr0, %cr4, 和 %eflags 寄存器，以及陷入指令.(陷入指令作用:计算机操作系统的中断处理机制，利用它完成系统调用和程序请求)
 */

/*
 *
 *	Part 1.  Paging data structures and constants.
 *  第一部分。 分页数据结构和常量。
 *
 */

// A linear address 'la' has a three-part structure as follows:
// 一个线性地址'la'有以下三部分结构：| 页目录索引 PDX | 页表索引 PTX | 页内偏移量 PGDFF |
//							    \           页号            /
//
// +--------10------+-------10-------+---------12----------+
// | Page Directory |   Page Table   | Offset within Page  |
// |      Index     |      Index     |                     |
// +----------------+----------------+---------------------+
//  \--- PDX(la) --/ \--- PTX(la) --/ \---- PGOFF(la) ----/
//  \---------- PGNUM(la) ----------/
//
// The PDX, PTX, PGOFF, and PGNUM macros decompose linear addresses as shown.分析如图所示
// To construct a linear address la from PDX(la), PTX(la), and PGOFF(la),
// 构造一个线性地址需要 页目录索引 页表索引 页内偏移量
// use PGADDR(PDX(la), PTX(la), PGOFF(la)).

// page number field of address 线性地址的页号
#define PGNUM(la)	(((uintptr_t) (la)) >> PTXSHIFT) 

// page directory index 页面目录索引
#define PDX(la)		((((uintptr_t) (la)) >> PDXSHIFT) & 0x3FF)

// page table index 页表索引
#define PTX(la)		((((uintptr_t) (la)) >> PTXSHIFT) & 0x3FF)

// offset in page 页中的偏移量
#define PGOFF(la)	(((uintptr_t) (la)) & 0xFFF)

// construct linear address from indexes and offset 从索引和偏移量构建线性地址
#define PGADDR(d, t, o)	((void*) ((d) << PDXSHIFT | (t) << PTXSHIFT | (o)))

// Page directory and page table constants.页目录和页表常量。
#define NPDENTRIES	1024		// page directory entries per page directory 每页目录有1024个页表
#define NPTENTRIES	1024		// page table entries per page table 每个页表拥有1024个页表项

#define PGSIZE		4096		// bytes mapped by a page 4KB/页表项
#define PGSHIFT		12		// log2(PGSIZE) 2^12 = 2^10(2KB) ^ 2 =  4096(4KB)

#define PTSIZE		(PGSIZE*NPTENTRIES) // bytes mapped by a page directory entry 4MB/页表
#define PTSHIFT		22		// log2(PTSIZE)

#define PTXSHIFT	12		// offset of PTX in a linear address 线性地址中PTX的偏移量
#define PDXSHIFT	22		// offset of PDX in a linear address 线性地址中PDX的偏移量

// Page table/directory entry flags.
// 页表/页目录入口标志。
#define PTE_P		0x001	// Present 存在（Present）标志，用于指明表项对地址转换是否有效
#define PTE_W		0x002	// Writeable 可写
#define PTE_U		0x004	// User 用户
#define PTE_PWT		0x008	// Write-Through CPU向cache写入数据时，
							// 同时向memory(后端存储)也写一份，使cache和memory的数据保持一致。
#define PTE_PCD		0x010	// Cache-Disable 缓存-禁用
#define PTE_A		0x020	// Accessed 已访问
#define PTE_D		0x040	// Dirty 脏页
#define PTE_PS		0x080	// Page Size 页面大小
#define PTE_G		0x100	// Global 全局

// The PTE_AVAIL bits aren't used by the kernel or interpreted by the
// hardware, so user processes are allowed to set them arbitrarily.
// PTE_AVAIL位没有被内核使用，也没有被硬件耦合。因此，用户进程可以任意使用它们。
#define PTE_AVAIL	0xE00	// Available for software use 是否可供软件使用


// Flags in PTE_SYSCALL may be used in system calls.  (Others may not.)
// 这个标识是指：只能够被系统调用(其他不能)
#define PTE_SYSCALL	(PTE_AVAIL | PTE_P | PTE_W | PTE_U)

// Address in page table or page directory entry
// pte(页表项的基地址)或pde(页目录的基地址)
#define PTE_ADDR(pte)	((physaddr_t) (pte) & ~0xFFF)

// Control Register flags 控制寄存器的标志
#define CR0_PE		0x00000001	// Protection Enable  启用保护功能
#define CR0_MP		0x00000002	// Monitor coProcessor  监控协处理器
#define CR0_EM		0x00000004	// Emulation  仿真
#define CR0_TS		0x00000008	// Task Switched  任务切换
#define CR0_ET		0x00000010	// Extension Type  扩展类型
#define CR0_NE		0x00000020	// Numeric Errror  数值错误
#define CR0_WP		0x00010000	// Write Protect  写入保护
#define CR0_AM		0x00040000	// Alignment Mask  对齐屏蔽
#define CR0_NW		0x20000000	// Not Writethrough  不穿透写入
#define CR0_CD		0x40000000	// Cache Disable  禁用缓存
#define CR0_PG		0x80000000	// Paging  分页

#define CR4_PCE		0x00000100	// Performance counter enable  性能计数器启用
#define CR4_MCE		0x00000040	// Machine Check Enable  机器检查启用
#define CR4_PSE		0x00000010	// Page Size Extensions  页面大小扩展
#define CR4_DE		0x00000008	// Debugging Extensions  调试扩展
#define CR4_TSD		0x00000004	// Time Stamp Disable  禁用时间戳
#define CR4_PVI		0x00000002	// Protected-Mode Virtual Interrupts  受保护模式的虚拟中断
#define CR4_VME		0x00000001	// V86 Mode Extensions  V86模式扩展

// Eflags register
#define FL_CF		0x00000001	// Carry Flag  进位标志
#define FL_PF		0x00000004	// Parity Flag  奇偶校验标志
#define FL_AF		0x00000010	// Auxiliary carry Flag  辅助进位标志
#define FL_ZF		0x00000040	// Zero Flag  零标志
#define FL_SF		0x00000080	// Sign Flag  符号旗
#define FL_TF		0x00000100	// Trap Flag  陷阱标志
#define FL_IF		0x00000200	// Interrupt Flag  中断标志
#define FL_DF		0x00000400	// Direction Flag  方向旗
#define FL_OF		0x00000800	// Overflow Flag  溢出标志
#define FL_IOPL_MASK	0x00003000	// I/O Privilege Level bitmask I/O等级位
#define FL_IOPL_0	0x00000000	//   IOPL == 0
#define FL_IOPL_1	0x00001000	//   IOPL == 1
#define FL_IOPL_2	0x00002000	//   IOPL == 2
#define FL_IOPL_3	0x00003000	//   IOPL == 3
#define FL_NT		0x00004000	// Nested Task  嵌套任务
#define FL_RF		0x00010000	// Resume Flag  恢复标志
#define FL_VM		0x00020000	// Virtual 8086 mode  虚拟8086模式
#define FL_AC		0x00040000	// Alignment Check  对齐检查
#define FL_VIF		0x00080000	// Virtual Interrupt Flag  虚拟中断标志
#define FL_VIP		0x00100000	// Virtual Interrupt Pending  虚拟中断挂起
#define FL_ID		0x00200000	// ID flag  ID标志

// Page fault error codes
#define FEC_PR		0x1	// Page fault caused by protection violation
#define FEC_WR		0x2	// Page fault caused by a write 由写入引发的页故障
#define FEC_U		0x4	// Page fault occured while in user mode 在用户模式下引发的页故障


/*
 *
 *	Part 2.  Segmentation data structures and constants.
 *  第二部分.  分割数据结构和常量。
 *
 */

#ifdef __ASSEMBLER__

/*
 * Macros to build GDT entries in assembly.
 */
#define SEG_NULL						\
	.word 0, 0;						\
	.byte 0, 0, 0, 0
#define SEG(type,base,lim)					\
	.word (((lim) >> 12) & 0xffff), ((base) & 0xffff);	\
	.byte (((base) >> 16) & 0xff), (0x90 | (type)),		\
		(0xC0 | (((lim) >> 28) & 0xf)), (((base) >> 24) & 0xff)

#else	// not __ASSEMBLER__

#include <inc/types.h>

// Segment Descriptors
struct Segdesc {
	unsigned sd_lim_15_0 : 16;  // Low bits of segment limit
	unsigned sd_base_15_0 : 16; // Low bits of segment base address
	unsigned sd_base_23_16 : 8; // Middle bits of segment base address
	unsigned sd_type : 4;       // Segment type (see STS_ constants)
	unsigned sd_s : 1;          // 0 = system, 1 = application
	unsigned sd_dpl : 2;        // Descriptor Privilege Level
	unsigned sd_p : 1;          // Present
	unsigned sd_lim_19_16 : 4;  // High bits of segment limit
	unsigned sd_avl : 1;        // Unused (available for software use)
	unsigned sd_rsv1 : 1;       // Reserved
	unsigned sd_db : 1;         // 0 = 16-bit segment, 1 = 32-bit segment
	unsigned sd_g : 1;          // Granularity: limit scaled by 4K when set
	unsigned sd_base_31_24 : 8; // High bits of segment base address
};
// Null segment
#define SEG_NULL	{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
// Segment that is loadable but faults when used
#define SEG_FAULT	{ 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1, 0, 0 }
// Normal segment
#define SEG(type, base, lim, dpl) 					\
{ ((lim) >> 12) & 0xffff, (base) & 0xffff, ((base) >> 16) & 0xff,	\
    type, 1, dpl, 1, (unsigned) (lim) >> 28, 0, 0, 1, 1,		\
    (unsigned) (base) >> 24 }
#define SEG16(type, base, lim, dpl) (struct Segdesc)			\
{ (lim) & 0xffff, (base) & 0xffff, ((base) >> 16) & 0xff,		\
    type, 1, dpl, 1, (unsigned) (lim) >> 16, 0, 0, 1, 0,		\
    (unsigned) (base) >> 24 }

#endif /* !__ASSEMBLER__ */

// Application segment type bits
#define STA_X		0x8	    // Executable segment
#define STA_E		0x4	    // Expand down (non-executable segments)
#define STA_C		0x4	    // Conforming code segment (executable only)
#define STA_W		0x2	    // Writeable (non-executable segments)
#define STA_R		0x2	    // Readable (executable segments)
#define STA_A		0x1	    // Accessed

// System segment type bits
#define STS_T16A	0x1	    // Available 16-bit TSS
#define STS_LDT		0x2	    // Local Descriptor Table
#define STS_T16B	0x3	    // Busy 16-bit TSS
#define STS_CG16	0x4	    // 16-bit Call Gate
#define STS_TG		0x5	    // Task Gate / Coum Transmitions
#define STS_IG16	0x6	    // 16-bit Interrupt Gate
#define STS_TG16	0x7	    // 16-bit Trap Gate
#define STS_T32A	0x9	    // Available 32-bit TSS
#define STS_T32B	0xB	    // Busy 32-bit TSS
#define STS_CG32	0xC	    // 32-bit Call Gate
#define STS_IG32	0xE	    // 32-bit Interrupt Gate
#define STS_TG32	0xF	    // 32-bit Trap Gate


/*
 *
 *	Part 3.  Traps.
 *
 */

#ifndef __ASSEMBLER__

// Task state segment format (as described by the Pentium architecture book)
struct Taskstate {
	uint32_t ts_link;	// Old ts selector
	uintptr_t ts_esp0;	// Stack pointers and segment selectors
	uint16_t ts_ss0;	//   after an increase in privilege level
	uint16_t ts_padding1;
	uintptr_t ts_esp1;
	uint16_t ts_ss1;
	uint16_t ts_padding2;
	uintptr_t ts_esp2;
	uint16_t ts_ss2;
	uint16_t ts_padding3;
	physaddr_t ts_cr3;	// Page directory base
	uintptr_t ts_eip;	// Saved state from last task switch
	uint32_t ts_eflags;
	uint32_t ts_eax;	// More saved state (registers)
	uint32_t ts_ecx;
	uint32_t ts_edx;
	uint32_t ts_ebx;
	uintptr_t ts_esp;
	uintptr_t ts_ebp;
	uint32_t ts_esi;
	uint32_t ts_edi;
	uint16_t ts_es;		// Even more saved state (segment selectors)
	uint16_t ts_padding4;
	uint16_t ts_cs;
	uint16_t ts_padding5;
	uint16_t ts_ss;
	uint16_t ts_padding6;
	uint16_t ts_ds;
	uint16_t ts_padding7;
	uint16_t ts_fs;
	uint16_t ts_padding8;
	uint16_t ts_gs;
	uint16_t ts_padding9;
	uint16_t ts_ldt;
	uint16_t ts_padding10;
	uint16_t ts_t;		// Trap on task switch
	uint16_t ts_iomb;	// I/O map base address
};

// Gate descriptors for interrupts and traps 中断和陷阱的门描述符
struct Gatedesc {
	unsigned gd_off_15_0 : 16;   // low 16 bits of offset in segment
	unsigned gd_sel : 16;        // segment selector
	unsigned gd_args : 5;        // # args, 0 for interrupt/trap gates
	unsigned gd_rsv1 : 3;        // reserved(should be zero I guess)
	unsigned gd_type : 4;        // type(STS_{TG,IG32,TG32})
	unsigned gd_s : 1;           // must be 0 (system)
	unsigned gd_dpl : 2;         // descriptor(meaning new) privilege level
	unsigned gd_p : 1;           // Present
	unsigned gd_off_31_16 : 16;  // high bits of offset in segment
};

// Set up a normal interrupt/trap gate descriptor. 设置一个通用的中断/陷阱门描述符
// - istrap: 1 for a trap (= exception) gate, 0 for an interrupt gate. 1表示陷阱（=异常），0表示中断
    //   see section 9.6.1.3 of the i386 reference: "The difference between
    //   an interrupt gate and a trap gate is in the effect on IF (the
    //   interrupt-enable flag). An interrupt that vectors through an
    //   interrupt gate resets IF, thereby preventing other interrupts from
    //   interfering with the current interrupt handler. A subsequent IRET
    //   instruction restores IF to the value in the EFLAGS image on the
    //   stack. An interrupt through a trap gate does not change IF."
// - sel: Code segment selector for interrupt/trap handler 中断/陷阱处理程序的代码段选择器
// - off: Offset in code segment for interrupt/trap handler 中断/陷阱处理程序在代码段中的偏移量
// - dpl: Descriptor Privilege Level - 描述符权限级别
//	  the privilege level required for software to invoke
//	  this interrupt/trap gate explicitly using an int instruction.

#define SETGATE(gate, istrap, sel, off, dpl)			\
{								\
	(gate).gd_off_15_0 = (uint32_t) (off) & 0xffff;		\
	(gate).gd_sel = (sel);					\
	(gate).gd_args = 0;					\
	(gate).gd_rsv1 = 0;					\
	(gate).gd_type = (istrap) ? STS_TG32 : STS_IG32;	\
	(gate).gd_s = 0;					\
	(gate).gd_dpl = (dpl);					\
	(gate).gd_p = 1;					\
	(gate).gd_off_31_16 = (uint32_t) (off) >> 16;		\
}

// Set up a call gate descriptor.
#define SETCALLGATE(gate, sel, off, dpl)           	        \
{								\
	(gate).gd_off_15_0 = (uint32_t) (off) & 0xffff;		\
	(gate).gd_sel = (sel);					\
	(gate).gd_args = 0;					\
	(gate).gd_rsv1 = 0;					\
	(gate).gd_type = STS_CG32;				\
	(gate).gd_s = 0;					\
	(gate).gd_dpl = (dpl);					\
	(gate).gd_p = 1;					\
	(gate).gd_off_31_16 = (uint32_t) (off) >> 16;		\
}

// Pseudo-descriptors used for LGDT, LLDT and LIDT instructions.
struct Pseudodesc {
	uint16_t pd_lim;		// Limit
	uint32_t pd_base;		// Base address
} __attribute__ ((packed));

#endif /* !__ASSEMBLER__ */

#endif /* !JOS_INC_MMU_H */
