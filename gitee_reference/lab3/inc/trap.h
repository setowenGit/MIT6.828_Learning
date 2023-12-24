#ifndef JOS_INC_TRAP_H
#define JOS_INC_TRAP_H

// Trap numbers
// These are processor defined:
#define T_DIVIDE     0		// divide error 除法错误(eg:分母为0)
#define T_DEBUG      1		// debug exception 调试异常
#define T_NMI        2		// non-maskable interrupt   非屏蔽中断
#define T_BRKPT      3		// breakpoint 断点
#define T_OFLOW      4		// overflow 溢出
#define T_BOUND      5		// bounds check 边界检查
#define T_ILLOP      6		// illegal opcode 非法操作码
#define T_DEVICE     7		// device not available 设备无法使用
#define T_DBLFLT     8		// double fault 双重故障
/* #define T_COPROC  9 */	// reserved (not generated by recent processors) 保留(当前的处理器无法产生)
#define T_TSS       10		// invalid task switch segment 任务转换段失效
#define T_SEGNP     11		// segment not present 段不存在
#define T_STACK     12		// stack exception 栈异常
#define T_GPFLT     13		// general protection fault 一般保护故障
#define T_PGFLT     14		// page fault 页面失败(故障)
/* #define T_RES    15 */	// reserved 保留
#define T_FPERR     16		// floating point error 浮点错误
#define T_ALIGN     17		// aligment check 对称性检查
#define T_MCHK      18		// machine check 机器检查
#define T_SIMDERR   19		// SIMD floating point error SIMD浮点错误

// These are arbitrarily chosen, but with care not to overlap
// processor defined exceptions or interrupt vectors.
#define T_SYSCALL   48		// system call
#define T_DEFAULT   500		// catchall

#define IRQ_OFFSET	32	// IRQ 0 corresponds to int IRQ_OFFSET

// Hardware IRQ numbers. We receive these as (IRQ_OFFSET+IRQ_WHATEVER)
#define IRQ_TIMER        0
#define IRQ_KBD          1
#define IRQ_SERIAL       4
#define IRQ_SPURIOUS     7
#define IRQ_IDE         14
#define IRQ_ERROR       19

#ifndef __ASSEMBLER__

#include <inc/types.h>

struct PushRegs {
	/* registers as pushed by pusha */
	uint32_t reg_edi;
	uint32_t reg_esi;
	uint32_t reg_ebp;
	uint32_t reg_oesp;		/* Useless */
	uint32_t reg_ebx;
	uint32_t reg_edx;
	uint32_t reg_ecx;
	uint32_t reg_eax;
} __attribute__((packed));

struct Trapframe {
	struct PushRegs tf_regs;
	uint16_t tf_es;
	uint16_t tf_padding1;
	uint16_t tf_ds;
	uint16_t tf_padding2;
	uint32_t tf_trapno; //错误编号
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


#endif /* !__ASSEMBLER__ */

#endif /* !JOS_INC_TRAP_H */