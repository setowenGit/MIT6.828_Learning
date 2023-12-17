// Simple implementation of cprintf console output for the kernel,
// based on printfmt() and the kernel console's cputchar().

// 内核的cprintf控制台输出的简单实现，
// 基于printfmt（）和 console 中的 cputchar（）。

#include <inc/types.h>
#include <inc/stdio.h>
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt) // int ch 传入要显示的字符(为什么传入不是char? 大概是因为字符底层都是以int保存吧，所以默认全用int,eg:ASCII)
{
	cputchar(ch);
	*cnt++;// cnt 为字符串长度，让其传进来的指针所含的值+1
}

int
vcprintf(const char *fmt, va_list ap)
{
	int cnt = 0; /* 输出字符的长度  */

	vprintfmt((void*)putch, &cnt, fmt, ap);
	return cnt; // 返回代表 cnt 为字符串长度
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

