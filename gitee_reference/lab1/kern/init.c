/* See COPYRIGHT for copyright information. */

#include <inc/stdio.h>
#include <inc/string.h>
#include <inc/assert.h>

#include <kern/monitor.h>
#include <kern/console.h>

// Test the stack backtrace function (lab 1 only)
// 测试堆栈回溯功能（仅实验室1）。

void
test_backtrace(int x)
{
	cprintf("entering test_backtrace %d\n", x);
	if (x > 0)
		test_backtrace(x-1);
	mon_backtrace(x, 0, 0);
	cprintf("leaving test_backtrace %d\n", x);
}

/*void
test_backtrace(int x)
{
	for(int i = 0; i < x; i++)
		mon_backtrace(i, 0, 0);

}
*/
void
i386_init(void)
{
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();

	cprintf("Lab1_Exercise_8:\n");
    	int x = 1, y = 3, z = 4;
    	cprintf("x %d, y %x, z %d\n", x, y, z);
	cprintf("6828 decimal is %o octal!\n", 6828);

	// unsigned int i = 0x00646c72;
	unsigned int i = 0x00646c72;
	int j = 1;


Lab1_exercise8_3:
	cprintf("H%x Wo%s\n", 57616, &i);
	
	cprintf("j(#x) = %#x, j(x) = %x. \n" ,j ,j);

	cprintf(">>>>>>>>>>>> x=%d y=%d z=%d k=%d c=%d p=%d m=%d oo=%d \n", 2);

Lab1_exercise9:
	// Test the stack backtrace function (lab 1 only)
	test_backtrace(0);
	test_backtrace(6);
	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
}


/*
 * Variable panicstr contains argument to first call to panic; used as flag
 * to indicate that the kernel has already called panic.
 */
/*
 * 变量panicstr包含第一次调用panic的参数；作为标志使用。
 * 来表示内核已经调用了panic。
 */
const char *panicstr;

/*
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
/*
 * Panic在无法解决的致命错误中被调用。
 * 它打印出 "panic: mesg"，然后进入内核监视器。
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
	va_list ap;

	if (panicstr)
		goto dead;
	panicstr = fmt;

	// Be extra sure that the machine is in as reasonable state
	asm volatile("cli; cld");

	va_start(ap, fmt);
	cprintf("kernel panic at %s:%d: ", file, line);
	vcprintf(fmt, ap);
	cprintf("\n");
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
	va_list ap;

	va_start(ap, fmt);
	cprintf("kernel warning at %s:%d: ", file, line);
	vcprintf(fmt, ap);
	cprintf("\n");
	va_end(ap);
}
