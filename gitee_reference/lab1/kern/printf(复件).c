// Simple implementation of cprintf console output for the kernel,
// based on printfmt() and the kernel console's cputchar().

// 内核的cprintf控制台输出的简单实现，
// 基于printfmt（）和 console 中的 cputchar（）。

#include <inc/types.h>
#include <inc/stdio.h>
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt) // 传入要显示的字符
{
	cputchar(ch);
	*cnt++; // cnt 为字符串长度
}

int
vcprintf(const char *fmt, va_list ap)
{
	int cnt = 0; 

	vprintfmt((void*)putch, &cnt, fmt, ap);
	return cnt;
}

int
cprintf(const char *fmt, ...)
{
	va_list ap;
	int cnt;

	va_start(ap, fmt);
	cnt = vcprintf(fmt, ap);
	va_end(ap);

	return cnt;
}

