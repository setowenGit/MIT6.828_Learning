#include <inc/x86.h>
#include <inc/elf.h>

/**********************************************************************
 * This a dirt simple boot loader, whose sole job is to boot
 * an ELF kernel image from the first IDE hard disk.
 *
 * DISK LAYOUT
 *  * This program(boot.S and main.c) is the bootloader.  It should
 *    be stored in the first sector of the disk.
 *
 *  * The 2nd sector onward holds the kernel image.
 *
 *  * The kernel image must be in ELF format.
 *
 * BOOT UP STEPS
 *  * when the CPU boots it loads the BIOS into memory and executes it
 *
 *  * the BIOS intializes devices, sets of the interrupt routines, and
 *    reads the first sector of the boot device(e.g., hard-drive)
 *    into memory and jumps to it.
 *
 *  * Assuming this boot loader is stored in the first sector of the
 *    hard-drive, this code takes over...
 *
 *  * control starts in boot.S -- which sets up protected mode,
 *    and a stack so C code then run, then calls bootmain()
 *
 *  * bootmain() in this file takes over, reads in the kernel and jumps to it.
 **********************************************************************/

/**********************************************************************
 * 这是个简单的启动加载器，它的唯一工作是启动
 * 从第一个IDE硬盘上启动一个ELF内核镜像。
 *
 * DISK LAYOUT
 * 这个程序（boot.S和main.c）是引导加载器。 它应该
 * 储存在磁盘的第一个扇区。
 *
 * * 第二个扇区以后存放内核镜像。
 *
 * * 内核镜像必须是ELF格式。
 *
 * 启动步骤
 * *当CPU启动时，它将BIOS加载到内存并执行它
 *
 * BIOS启动设备，设置中断程序，并读取启动设备的第一个扇区。
 * 读取启动设备（例如，硬盘）的第一个扇区。
 * 读取启动设备（如硬盘）的第一个扇区并跳转到它。
 *
 * 假设这个引导程序存储在硬盘的第一个扇区中，那么这段代码就会把启动设备的第一个扇区读出来。
 * 硬盘的第一个扇区，这段代码就会接管...
 *
 * * 控制权从boot.S开始 -- 它设置了保护模式。
 * 和一个堆栈，这样C语言的代码就可以运行，然后调用bootmain()
 *
 * 这个文件中的bootmain()接管，读入内核并跳转到它。
 **********************************************************************/
 
#define SECTSIZE	512
#define ELFHDR		((struct Elf *) 0x10000) // scratch space

void readsect(void*, uint32_t);
void readseg(uint32_t, uint32_t, uint32_t);

void
bootmain(void)
{
	struct Proghdr *ph, *eph;

	// read 1st page off disk
	readseg((uint32_t) ELFHDR, SECTSIZE*8, 0);

	// is this a valid ELF?
	if (ELFHDR->e_magic != ELF_MAGIC)
		goto bad;

	// load each program segment (ignores ph flags) ELF头部有描述ELF文件应加载到内存什么位置的描述表,先将描述表的头地址存在ph
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	// 按照描述表将ELF文件中数据载入内存
	for (; ph < eph; ph++)
		// p_pa is the load address of this segment (as well
		// as the physical address)
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);

	// call the entry point from the ELF header 根据ELF头部储存的入口信息，找到内核的入口
	// note: does not return!
	((void (*)(void)) (ELFHDR->e_entry))();

bad:
	outw(0x8A00, 0x8A00);
	outw(0x8A00, 0x8E00);
	while (1)
		/* do nothing */;
}

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked
void
readseg(uint32_t pa, uint32_t count, uint32_t offset)
{
	uint32_t end_pa;

	end_pa = pa + count;

	// round down to sector boundary
	pa &= ~(SECTSIZE - 1);

	// translate from bytes to sectors, and kernel starts at sector 1 加1因为0扇区被引导占用,ELF文件从1扇区开始
	offset = (offset / SECTSIZE) + 1;

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	while (pa < end_pa) {
		// Since we haven't enabled paging yet and we're using
		// an identity segment mapping (see boot.S), we can
		// use physical addresses directly.  This won't be the
		// case once JOS enables the MMU.
		readsect((uint8_t*) pa, offset);
		pa += SECTSIZE;
		offset++;
	}
}

void
waitdisk(void)
{
	// wait for disk reaady
	while ((inb(0x1F7) & 0xC0) != 0x40)
		/* do nothing */;
}

void
readsect(void *dst, uint32_t offset)
{
	// wait for disk to be ready
	waitdisk();

	outb(0x1F2, 1);		// count = 1 设置读取扇区的数目为1
	outb(0x1F3, offset);
	outb(0x1F4, offset >> 8);
	outb(0x1F5, offset >> 16);
	outb(0x1F6, (offset >> 24) | 0xE0);
	outb(0x1F7, 0x20);	// cmd 0x20 - read sectors 0x20命令，读取扇区

	// wait for disk to be ready
	waitdisk();

	// read a sector 读取到dst位置
	insl(0x1F0, dst, SECTSIZE/4);
}

