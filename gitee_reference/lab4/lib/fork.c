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

    // err & FEC_WR -> 确保是由写故障引起的故障
    // uvpd[PDX(addr)] & PTE_P 确保当前页目录项存在
    // uvpt[PGNUM(addr)] & PTE_P 确保当前页面项存在
    // uvpt[PGNUM(addr)] & PTE_COW 确保当前页面项是满足 "写时复制"
    if (! ( (err & FEC_WR) && (uvpd[PDX(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_COW))){
        panic("Neither the fault is a write nor COW page. \n");
    }
    // Allocate a new page, map it at a temporary location (PFTEMP),
    // copy the data from the old page to the new page, then move the new
    // page to the old page's address.
    // 从临时地址(PFTEMP)分配一个新的页，接着拷贝源页面上的数据到新页上，最后 将新页作为替换页表中的旧页映射地址
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
        //因为sys_page_alloc底层调用的page_insert, 而page_insert会对PFTEMP产生映射，So要取消这个映射关系.
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
// TODO 因为sys_page_map底层是page_insert，而page_insert是会根据perm参数重新赋权限之的，所以若不标识'COW'，此页面将会无法进行写时复制 违反了最初的可COW的规定
//
// Returns: 0 on success, < 0 on error.
// It is also OK to panic on error.
//
static int
duppage(envid_t envid, unsigned pn)
{
    int r;
    // LAB 4: Your code here.
    int perm = PTE_U | PTE_P;
    if ((uvpt[pn] & PTE_W) || (uvpt[pn] & PTE_COW)) {
        perm |= PTE_COW;
        //“ The envid_t == 0 is special, and stands for the current environment.”
        if ((r = sys_page_map(0, (void *) (pn * PGSIZE), envid, (void *) (pn * PGSIZE), perm)) < 0) {
            panic("duppage: %e\n", r);
        }

        if ((r = sys_page_map(0, (void *) (pn * PGSIZE), 0, (void *) (pn * PGSIZE), perm)) < 0) {
            panic("duppage: %e\n", r);
        }
    } else if ((r = sys_page_map(0, (void *) (pn * PGSIZE), envid, (void *) (pn * PGSIZE), perm)) < 0) {
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
// 具备写时拷贝的用户级fork。
// 妥当地设置我们的页面故障处理程序。
// 创建一个子程序。
// 将我们的地址空间和页面故障处理程序设置复制到子程序中。
// 然后将子程序标记为可运行并返回。
//
// 返回：子节点的envid给父节点，0给子节点，错误时<0。
// 出错时可以调用 panic。
//
// 提示：
// 使用 uvpd, uvpt 和 duppage。
// 记住要在子进程中修复 "thisenv"。
// 两个用户异常栈都不应该被标记为写时复制，所以你必须为子进程的用户异常栈分配一个新页面。
envid_t
fork(void)
{
    // LAB 4: Your code here.
    extern void _pgfault_upcall(void);
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
        // uvpd是有1024个pde的一维数组，而uvpt是有2^20(=1024)个pte的一维数组,与物理页号刚好一一对应
        if ((uvpd[PDX(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_P) && (uvpt[PGNUM(addr)] & PTE_U)) {
            duppage(envid, PGNUM(addr));
        }
    }

    int r;
    if ((r = sys_page_alloc(envid, (void *) (UXSTACKTOP - PGSIZE), PTE_U | PTE_W | PTE_P)) < 0)
        panic("sys_page_alloc: %e", r);

    sys_env_set_pgfault_upcall(envid, _pgfault_upcall);
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
