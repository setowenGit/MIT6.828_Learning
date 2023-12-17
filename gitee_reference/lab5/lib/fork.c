// implement fork from user space

#include <inc/string.h>
#include <inc/lib.h>

// PTE_COW marks copy-on-write page table entries.
// It is one of the bits explicitly allocated to user processes (PTE_AVAIL).
#define PTE_COW        0x800

//
// Custom page fault handler - if faulting page is copy-on-write,
// map in our own private writable copy.
//
static void
pgfault(struct UTrapframe *utf) {
    void *addr = (void *) utf->utf_fault_va;
    uint32_t err = utf->utf_err;
    int r;

    // Check that the faulting access was (1) a write, and (2) to a
    // copy-on-write page.  If not, panic.
    // Hint:
    //   Use the read-only page table mappings at uvpt
    //   (see <inc/memlayout.h>).
    // LAB 4: Your code here.
    if (!((err & FEC_WR) && (uvpd[PDX(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_P) &&
          (uvpt[PGNUM(addr)] & PTE_COW))) {
        panic("Neither the fault is a write nor COW page. \n");
    }
    // Allocate a new page, map it at a temporary location (PFTEMP),
    // copy the data from the old page to the new page, then move the new
    // page to the old page's address.
    // Hint:
    //   You should make three system calls.
    // LAB 4: Your code here.
    envid_t envid = sys_getenvid();
    addr = ROUNDDOWN(addr, PGSIZE);
    int ret;
    if ((ret = sys_page_alloc(envid, (void *) PFTEMP, PTE_P | PTE_W | PTE_U)) < 0) {
        panic("Pgfault Error: %e", ret);
    }

    memcpy((void *) PFTEMP, (const void *) addr, PGSIZE);

    if ((ret = sys_page_map(envid, (void *) PFTEMP, envid, addr, PTE_P | PTE_W | PTE_U) < 0)) {
        panic("Pgfault Error: %e", ret);
    }
    if ((ret = sys_page_unmap(envid, (void *) PFTEMP)) < 0) {
        panic("Pgfault Error: %e", ret);
    }
}

//
// Map our virtual page pn (address pn*PGSIZE) into the target envid
// at the same virtual address.  If the page is writable or copy-on-write,
// the new mapping must be created copy-on-write, and then our mapping must be
// marked copy-on-write as well.  (Exercise: Why do we need to mark ours
// copy-on-write again if it was already copy-on-write at the beginning of
// this function?)
//
/// 将虚拟页面pn（地址pn*PGSIZE）映射到同一虚拟地址的目标envid。
/// 如果页面是可写的或写时复制的，则必须创建新映射“写时复制”，然后我们的映射也必须标记为写时复制。
/// (练习：如果在函数开始时已经是写时复制，为什么我们需要再次标记写时复制？)
// TODO 因为新的页面若不标识'COW' 则当创建新进程时，此页面将会无法进行写时复制 违反了最初的可COW的规定
//
// Returns: 0 on success, < 0 on error.
// It is also OK to panic on error.
//
static int
duppage(envid_t envid, unsigned pn) {
    int r;
    // LAB 4: Your code here.
    int perm = PTE_U | PTE_P;
    if (uvpt[pn] & PTE_SHARE) {
        perm |= PTE_SHARE;
        if (0 > (r = sys_page_map(sys_getenvid(), (void *) (pn * PGSIZE), envid, (void *) (pn * PGSIZE), PTE_SYSCALL))){
            panic("duppage: %e\n", r);
        }
    } else if ((uvpt[pn] & PTE_W) || (uvpt[pn] & PTE_COW)) {
        perm |= PTE_COW;
        if ((r = sys_page_map(sys_getenvid(), (void *) (pn * PGSIZE), envid, (void *) (pn * PGSIZE), perm)) < 0) {
            panic("duppage: %e\n", r);
        }
        if ((r = sys_page_map(sys_getenvid(), (void *) (pn * PGSIZE), sys_getenvid(), (void *) (pn * PGSIZE), perm)) < 0) {
            panic("duppage: %e\n", r);
        }
    } else if ((r = sys_page_map(sys_getenvid(), (void *) (pn * PGSIZE), envid, (void *) (pn * PGSIZE), perm)) < 0) {
        panic("duppage: %e\n", r);
    }

    return 0;
}

//
// User-level fork with copy-on-write.
// Set up our page fault handler appropriately.
// Create a child.
// Copy our address space and page fault handler setup to the child.
// Then mark the child as runnable and return.
//
// Returns: child's envid to the parent, 0 to the child, < 0 on error.
// It is also OK to panic on error.
//
// Hint:
//   Use uvpd, uvpt, and duppage.
//   Remember to fix "thisenv" in the child process.
//   Neither user exception stack should ever be marked copy-on-write,
//   so you must allocate a new page for the child's user exception stack.
//
// 这段代码是实现带有写时复制（COW）的用户级进程复制（fork）的代码。它需要做以下几件事情：
// 设置合适的页面错误处理程序（page fault handler）。
// 创建一个子进程。
// 将当前进程的地址空间和页面错误处理程序复制到子进程。
// 将子进程标记为可运行状态并返回其envid。
// 如果发生错误，则返回值小于0，此时也可以选择直接崩溃（panic）。
// 此外，需要注意以下几点：
// 在子进程中需要修正"thisenv"指针。
// 不能将任何一个用户异常栈标记为写时复制，因此需要为子进程的用户异常栈分配新的页面。
// 该函数中会用到uvpd、uvpt和duppage等函数。
envid_t
fork(void) {
    // LAB 4: Your code here.
    extern void _pgfault_upcall(void); //_pgfault_upcall位于pfentry.S
    set_pgfault_handler(pgfault);
    envid_t envid = sys_exofork();
    if (envid < 0)
        panic("sys_exofork: %e", envid);
    if (envid == 0) {
        // We're the child.
        // The copied value of the global variable 'thisenv'
        // is no longer valid (it refers to the parent!).
        // Fix it and return 0.
        thisenv = &envs[ENVX(sys_getenvid())];
        return 0;
    }

    uint32_t addr;
    for (addr = 0; addr < USTACKTOP; addr += PGSIZE) {
        // uvpd是有1024个pde的一维数组,而uvpt是有2^20个pte的一维数组,与物理页号刚好一一对应
        if ((uvpd[PDX(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_U)) {
            duppage(envid, PGNUM(addr));
        }
    }

    int r;
    if ((r = sys_page_alloc(envid, (void *) (UXSTACKTOP - PGSIZE), PTE_U | PTE_W | PTE_P)) < 0) //为子进程分配一个全新的异常栈空间
        panic("sys_page_alloc: %e", r);

    sys_env_set_pgfault_upcall(envid, _pgfault_upcall); //设置子进程的页错误函数
    // Start the child environment running
    if ((r = sys_env_set_status(envid, ENV_RUNNABLE)) < 0)
        panic("sys_env_set_status: %e", r);

    return envid;
}

// Challenge!
int
sfork(void) {
    panic("sfork not implemented");
    return -E_INVAL;
}
