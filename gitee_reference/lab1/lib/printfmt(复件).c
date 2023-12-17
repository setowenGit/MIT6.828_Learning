// Stripped-down primitive printf-style formatting routines,
// used in common by printf, sprintf, fprintf, etc.
// This code is also used by both the kernel and user programs.
// 删减了原始的printf风格的格式化例程。
// 由printf、sprintf、fprintf等共同使用。
// 这段代码也被内核和用户程序所使用。

#include <inc/types.h>
#include <inc/stdio.h>
#include <inc/string.h>
#include <inc/stdarg.h>
#include <inc/error.h>

/*
 * Space or zero padding and a field width are supported for the numeric
 * formats only.
 *
 * The special format %e takes an integer error code
 * and prints a string describing the error.
 * The integer may be positive or negative,
 * so that -E_NO_MEM and E_NO_MEM are equivalent.
 */
/*
 * 空间或零填充和字段宽度只支持数字格式。
 * 只支持数字格式。
 *
 * 特殊格式%e接收一个整数错误代码
 * 并打印出一个描述错误的字符串。
 * 该整数可以是正数或负数。
 * 因此，-E_NO_MEM和E_NO_MEM是等同的。
 */

static const char * const error_string[MAXERROR] =
{
	[E_UNSPECIFIED]	= "unspecified error",	// 未指定的错误
	[E_BAD_ENV]	= "bad environment",  	// 失败环境
	[E_INVAL]	= "invalid parameter",	// 无效的参数
	[E_NO_MEM]	= "out of memory",	// 内存不足
	[E_NO_FREE_ENV]	= "out of environments",// 没有环境
	[E_FAULT]	= "segmentation fault", // 分段故障
};

/*
 * Print a number (base <= 16) in reverse order,
 * using specified putch function and associated pointer putdat.
 */
/*
 * 按相反顺序打印一个数字（基数<=16）。
 * 使用指定的putch函数和相关的指针putdat。
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	//首先递归地打印所有前面的（更有意义的）数字
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		// 在第一个数字之前打印任何需要的垫字符
		while (--width > 0)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	// 然后打印这个（最没有意义的）数字
	putch("0123456789abcdef"[num % base], putdat);
}

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
// 从varargs列表中获得一个各种可能大小的无符号int。
// 取决于lflag参数。
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
		return va_arg(*ap, unsigned long long);
	else if (lflag)
		return va_arg(*ap, unsigned long);
	else
		return va_arg(*ap, unsigned int);
}

/* Same as getuint but signed - can't use getuint
   because of sign extension
   与getuint相同，但有符号 - 不能使用getuint
   因为有符号扩展 */
static long long
getint(va_list *ap, int lflag)
{
	// 0 -> int， 1 -> long，2 -> long long
	if (lflag >= 2)
		return va_arg(*ap, long long);
	else if (lflag)
		return va_arg(*ap, long);
	else
		return va_arg(*ap, int);
}


// Main function to format and print a string.

// 主函数用于格式化和打印一个字符串。
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{	// putch是printf中定义的函数；fmt为printf传输的字符串
	// putdat是长度指针(为什么是void*指针？因为void指针表示任何类型的指针，任何类型的指针都可赋值)
	register const char *p;
	register int ch, err;
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0') // '\0' 代表字符串的结束标志
				return;
			putch(ch, putdat);
		}

		// Process a %-escape sequence
		// 处理一个 %-escape 序列

		padc = ' '; //填充字符，默认填充的字符为空格
		width = -1; // 字段宽度, 最后通过从precision获值
		precision = -1; // 字符宽度-临时量
		lflag = 0;/* 长标志,lflag = 0 -> int，1 -> long，2 -> long long */
		altflag = 0;/* 强制输出进制标识符号,即: %#x 输出16进制标识符 0X  */
	reswitch: // 重新转换
		switch (ch = *(unsigned char *) fmt++) { // 注意这里--> fmt++

		// flag to pad on the right
		// (前提是未占满字段宽度)表示是 在%-escape序列的右边 进行填充(默认为边)
		case '-':
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces
		// (前提是未占满字段宽度)表示是 在%-escape序列中 用0而不是空格 来填充
		case '0':
			padc = '0';
			goto reswitch;

		// width field
		// 字段宽度 
		case '1':
		case '2':
		case '3':
		case '4':
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0'; 
				// 计算精度 eg:%123，字符宽度就是123。
				ch = *fmt; // 当前的字符(当前字符不是知道了吗？为什么还要获取？)↓
					   // 因为每次switch后 fmt自动+1，所以当前fmt是下一个
				if (ch < '0' || ch > '9') //当下一个字符 无法转换为精度时break
							  //eg:%123a, 当3计算完后会自动跳出
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int); /* 在print中, %后的 * 代表此输出的字符宽度
						      (超出则截断，少于则用填充字符补上，默认在左边
						      填入空格，eg:%5d == %*d) */
			goto process_precision;

		case '.':
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		/* 长标志,lflag = 0 -> int，1 -> long，2 -> long long */
		case 'l':
			lflag++;
			goto reswitch;

		// character
		//字符
		case 'c':
			putch(va_arg(ap, int), putdat); /* va_arg(ap, int)传入下一个的参数 (如果是字符串则传入头地址也就是第一个字符)(为什么是下一个？因为最开始的参数是 %-escape 序列)
							 */
			break;

		// error message
		// 错误信息
		case 'e':
			err = va_arg(ap, int);
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
			else
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~')) /* 如果强制前缀标志并且超出ASCII范围,则返回 ?, 我们常见的乱码就是这么来的 */
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
			break;

		// (signed) decimal
		// (有符号)十进制
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
			goto number;

		// unsigned decimal
		// 无符号十进制
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
			goto number;

		// (unsigned) octal
		// （无符号）八进制
		case 'o':
			// Replace this with your code.
			putch('0', putdat);
			num = getuint(&ap, lflag); 
			base = 8;
			goto number;


		// pointer
		// 指针
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);//uintptr_t是32位无符号整型
								//unsigned long long 是64位无符号整型
			base = 16;
			goto number;

		// (unsigned) hexadecimal
		// (无符号) 十六进制
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
		number:
			printnum(putch, putdat, num, base, width, padc);
			//putch 函数, putdat 长度, num 数字, base 进制, width 位宽, padc 填充符号
			break;

		// escaped '%' character		
		//转义的“%”字符

		case '%':
			putch(ch, putdat);
			break;

		// unrecognized escape sequence - just print it literally
		//无法识别的转义序列-只需逐字打印即可
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
				/* do nothing */;
			break;
		}
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	vprintfmt(putch, putdat, fmt, ap);
	va_end(ap);
}

struct sprintbuf {
	char *buf;
	char *ebuf;
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
	b->cnt++;
	if (b->buf < b->ebuf)
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;

	// print the string to the buffer
	//将字符串打印到缓冲区
	vprintfmt((void*)sprintputch, &b, fmt, ap);

	// null terminate the buffer
	//null终止缓冲区
	*b.buf = '\0';

	return b.cnt;
}

int
snprintf(char *buf, int n, const char *fmt, ...)
{
	va_list ap;
	int rc;

	va_start(ap, fmt);
	rc = vsnprintf(buf, n, fmt, ap);
	va_end(ap);

	return rc;
}


