#include <inc/mmu.h>
#include <inc/memlayout.h>

// Page fault upcall entrypoint.

// This is where we ask the kernel to redirect us to whenever we cause
// a page fault in user space (see the call to sys_set_pgfault_handler
// in pgfault.c).
//
// When a page fault actually occurs, the kernel switches our ESP to
// point to the user exception stack if we're not already on the user
// exception stack, and then it pushes a UTrapframe onto our user
// exception stack:
//
//	trap-time esp
//	trap-time eflags
//	trap-time eip
//	utf_regs.reg_eax
//	...
//	utf_regs.reg_esi
//	utf_regs.reg_edi
//	utf_err (error code)
//	utf_fault_va            <-- %esp
//
// If this is a recursive fault, the kernel will reserve for us a
// blank word above the trap-time esp for scratch work when we unwind
// the recursive call.
//
// We then have call up to the appropriate page fault handler in C
// code, pointed to by the global variable '_pgfault_handler'.

.text
.globl _pgfault_upcall
_pgfault_upcall:
	// Call the C page fault handler.
	pushl %esp			// function argument: pointer to UTF
	movl _pgfault_handler, %eax
	call *%eax
	addl $4, %esp			// pop function argument.
                            // %esp = UTrapframe.utf_esp
	
	// Now the C page fault handler has returned and you must return
	// to the trap time state.
	// Push trap-time %eip onto the trap-time stack.
	//
	// Explanation:
	//   We must prepare the trap-time stack for our eventual return to
	//   re-execute the instruction that faulted.
	//   Unfortunately, we can't return directly from the exception stack:
	//   We can't call 'jmp', since that requires that we load the address
	//   into a register, and all registers must have their trap-time
	//   values after the return.
	//   We can't call 'ret' from the exception stack either, since if we
	//   did, %esp would have the wrong value.
	//   So instead, we push the trap-time %eip onto the *trap-time* stack!
	//   Below we'll switch to that stack and call 'ret', which will
	//   restore %eip to its pre-fault value.
	//说明：
    ////我们必须为最终返回准备陷阱时间堆栈，
    /// 以便重新执行出错的指令。
    /// 不幸的是，我们不能直接从异常堆栈返回：
    ///     我们不能调用“jmp”，因为这要求我们将地址加载到寄存器中，
    ///     并且所有寄存器在返回后都必须有其陷阱时间值。
    ///     我们也无法从异常堆栈中调用“ret”，因为如果调用，%esp将具有错误的值。
    ///     因此，我们将切换到下面的堆栈并调用“ret”，这将把%eip恢复到故障前的值。
	//   In the case of a recursive fault on the exception stack,
	//   note that the word we're pushing now will fit in the
	//   blank word that the kernel reserved for us.
	//
	// Throughout the remaining code, think carefully about what
	// registers are available for intermediate calculations.  You
	// may find that you have to rearrange your code in non-obvious
	// ways as registers become unavailable as scratch space.
	//
    // 在异常堆栈出现递归故障的情况下，注意我们现在推送的字将适合内核为我们保留的空白字。
    // 在整个剩余的代码中，仔细思考哪些寄存器可以用于中间计算。
    // 你可能会发现你必须以非明显的方式重新安排你的代码，因为寄存器成为不可用的划痕空间。
	// LAB 4: Your code here.
    addl $8, %esp                 // esp+8 -> PushRegs   over utf_fault_va utf_err
    movl 32(%esp), %eax         // eax = (esp+0x20 -> utf_eip )
    subl $4, 40(%esp)           // for trap time eip 保留32bit,   esp+48 = utf_esp
    movl 40(%esp), %edx         // %edx = utf_esp-4
    movl %eax, (%edx)             // %eax = eip ----> esp-4  以至于ret可以直接读取其继续执行的地址

    ;// Restore the trap-time registers.  After you do this, you
	// can no longer modify any general-purpose registers.
	// LAB 4: Your code here.
    popal
	// Restore eflags from the stack.  After you do this, you can
	// no longer use arithmetic operations or anything else that
	// modifies eflags.
	// LAB 4: Your code here.
    addl $4, %esp      // esp+4 -> utf_eflags
    popfl
	// Switch back to the adjusted trap-time stack.
	// LAB 4: Your code here.
    popl %esp
	// Return to re-execute the instruction that faulted.
	// LAB 4: Your code here.
    ret