/* See COPYRIGHT for copyright information. */
/*
==================================================================================
名称	   				|			参数									|							作用
PADDR	   			| 内核虚拟地址kva						| 将内核虚拟地址kva转成对应的物理地址
KADDR	   			| 物理地址pa								| 将物理地址pa转化为内核虚拟地址
page2pa	   		| 页信息结构structPageInfo	| 通过*空闲页*结构得到这一页起始位置的物理地址
pa2page	   		| 物理地址pa								| 通过物理地址pa获取这一页对应的页结构体struct PageInfo
page2kva	  	| 页信息结构structPageInfo	| 通过*空闲页*结构得到这一页起始位置的虚拟地址
PDX						| 线性地址la	   						| 获得该线性地址la对应的页目录项索引
PTX						| 线性地址la	   						| 获得该线性地址la在二级页表中对应的页表项索引
PTE_ADDR(pte)	| 页表项或页目录项的值				| 获得对应的页表基址或者物理地址基址(低12位为0)
==================================================================================
*/
#ifndef JOS_KERN_PMAP_H
#define JOS_KERN_PMAP_H
#ifndef JOS_KERNEL
# error "This is a JOS kernel header; user programs should not #include it"
#endif

#include <inc/memlayout.h>
#include <inc/assert.h>
struct Env;
extern char bootstacktop[], bootstack[];

extern struct PageInfo *pages;
extern size_t npages;

extern pde_t *kern_pgdir;


/* This macro takes a kernel virtual address -- an address that points above
 * KERNBASE, where the machine's maximum 256MB of physical memory is mapped --
 * and returns the corresponding physical address.  It panics if you pass it a
 * non-kernel virtual address.
 * 这个宏接受一个内核"虚拟地址" (一个指向 大于KERNBASE 的地址，其中映射了机器最大256MB的物理内存）
   并返回相应的物理地址。
   如果你给它传递一个非内核虚拟地址，它会返回错误地址。
*/
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx\n", kva);
	return (physaddr_t)kva - KERNBASE;
}

/* This macro takes a physical address and returns the corresponding kernel
 * virtual address.  It panics if you pass an invalid physical address. */
/* 该宏获取物理地址并返回相应的内核虚拟地址。如果你传递了一个无效的物理地址，它就会混乱*/
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
	return (void *)(pa + KERNBASE);
}


enum {
	// For page_alloc, zero the returned physical page.
	ALLOC_ZERO = 1<<0,
};

void	mem_init(void);

void	page_init(void);
struct PageInfo *page_alloc(int alloc_flags);
void	page_free(struct PageInfo *pp);
int	page_insert(pde_t *pgdir, struct PageInfo *pp, void *va, int perm);
void	page_remove(pde_t *pgdir, void *va);
struct PageInfo *page_lookup(pde_t *pgdir, void *va, pte_t **pte_store);
void	page_decref(struct PageInfo *pp);

void	tlb_invalidate(pde_t *pgdir, void *va);

void *	mmio_map_region(physaddr_t pa, size_t size);

int	user_mem_check(struct Env *env, const void *va, size_t len, int perm);
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct PageInfo *pp) // 返回一个物理地址
{
	return (pp - pages) << PGSHIFT;
}

static inline struct PageInfo*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
}

static inline void*
page2kva(struct PageInfo *pp)
{
	return KADDR(page2pa(pp));
}

pte_t *pgdir_walk(pde_t *pgdir, const void *va, int create);

#endif /* !JOS_KERN_PMAP_H */
