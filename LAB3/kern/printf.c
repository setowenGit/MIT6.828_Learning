// Simple implementation of cprintf console output for the kernel,
// based on printfmt() and the kernel console's cputchar().
// 内核的cprintf控制台输出的简单实现，
// 基于printfmt（）和 console 中的 cputchar()

#include <inc/types.h>
#include <inc/stdio.h>
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
	cputchar(ch); // 调用console.c中函数，打印字符
	*cnt++;
}

int
vcprintf(const char *fmt, va_list ap)
{
	int cnt = 0;

	vprintfmt((void*)putch, &cnt, fmt, ap);// 调用printfmt.c中函数
	return cnt;
}

int
cprintf(const char *fmt, ...)
{
	va_list ap;// va等用于传入多参数
	int cnt;

	va_start(ap, fmt);
	cnt = vcprintf(fmt, ap);// 调用
	va_end(ap);

	return cnt;
}

