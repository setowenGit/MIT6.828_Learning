#include <inc/assert.h>
#include <inc/x86.h>
#include <kern/spinlock.h>
#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/monitor.h>

void sched_halt(void);

// Choose a user environment to run and run it.
void
sched_yield(void) {
    struct Env *idle;

    // Implement simple round-robin scheduling.
    //
    // Search through 'envs' for an ENV_RUNNABLE environment in
    // circular fashion starting just after the env this CPU was
    // last running.  Switch to the first such environment found.
    //
    // If no envs are runnable, but the environment previously
    // running on this CPU is still ENV_RUNNING, it's okay to
    // choose that environment.
    //
    // Never choose an environment that's currently running on
    // another CPU (env_status == ENV_RUNNING). If there are
    // no runnable environments, simply drop through to the code
    // below to halt the cpu.

    // 实现简单的轮流调度。
    // 在'envs'中搜索一个 ENV_RUNNABLE 环境，
    // 以循环的方式从这个 CPU 最后运行的环境开始。 切换到第一个发现的环境。
    //
    // 如果没有可运行的环境，但是之前在这个CPU上运行的环境仍然是ENV_RUNNING的，
    // 那么就可以选择那个环境。
    //
    // 不要选择目前正在另一个CPU上运行的环境（env_status == ENV_RUNNING）。如果没有可运行的环境，只需跳过下面的代码来停止cpu的运行。
    // LAB 4: Your code here.
    size_t start = 0;
    if(curenv){
        start = ENVX(curenv->env_id) + 1;
    }
    for(uint32_t i = 0; i < NENV; i++){
        size_t index = (start + i) % NENV;
        if(envs[index].env_status == ENV_RUNNABLE){
            env_run(&envs[index]);
        }
    }
    if(curenv && curenv->env_status == ENV_RUNNING && curenv->env_cpunum == cpunum()){
        env_run(curenv);
    }
    // sched_halt never returns
    sched_halt();

}

// Halt this CPU when there is nothing to do. Wait until the
// timer interrupt wakes it up. This function never returns.
//
void
sched_halt(void) {
    int i;

    // For debugging and testing purposes, if there are no runnable
    // environments in the system, then drop into the kernel monitor.
    for (i = 0; i < NENV; i++) {
        if ((envs[i].env_status == ENV_RUNNABLE ||
             envs[i].env_status == ENV_RUNNING ||
             envs[i].env_status == ENV_DYING))
            break;
    }
    if (i == NENV) {
        cprintf("No runnable environments in the system!\n");
        while (1)
            monitor(NULL);
    }

    // Mark that no environment is running on this CPU
    curenv = NULL;
    lcr3(PADDR(kern_pgdir));

    // Mark that this CPU is in the HALT state, so that when
    // timer interupts come in, we know we should re-acquire the
    // big kernel lock
    xchg(&thiscpu->cpu_status, CPU_HALTED);

    // Release the big kernel lock as if we were "leaving" the kernel
    unlock_kernel();

    // Reset stack pointer, enable interrupts and then halt.
    asm volatile (
            "movl $0, %%ebp\n"
            "movl %0, %%esp\n"
            "pushl $0\n"
            "pushl $0\n"
            // Uncomment the following line after completing exercise 13
            "sti\n" // 取消屏蔽中断
            "1:\n"
            "hlt\n"
            "jmp 1b\n"
            : : "a" (thiscpu->cpu_ts.ts_esp0));
}

