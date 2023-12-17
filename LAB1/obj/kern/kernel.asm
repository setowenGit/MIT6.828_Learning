
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
_start = RELOC(entry)

# 在这里才正式进入内核入口
.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# 这个4MB的区域是足够的了(对于目前的实验)，直到我们在实验二mem_init中再建立真正的页表.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	# 设置cr3页目录基址寄存器，保存页目录表的物理地址
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 80 11 00       	mov    $0x118000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3

	# Turn on paging.
	# 设置cr0开启分页
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0
	
	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	# 进入下面的relocated段
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	# 清除帧指针寄存器（EBP）
	# 这样一旦我们开始调试C代码，
	# 堆栈回溯将正常终止。
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	# 设置esp堆栈指针
	movl	$(bootstacktop),%esp
f0100034:	bc 00 80 11 f0       	mov    $0xf0118000,%esp

	# now to C code
	# 现在进入C函数，正式进行内核初始化
	call	i386_init
f0100039:	e8 5f 00 00 00       	call   f010009d <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <test_backtrace>:
#include <kern/console.h>

// Test the stack backtrace function (lab 1 only)
void
test_backtrace(int x)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("entering test_backtrace %d\n", x);
f010004a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010004e:	c7 04 24 60 18 10 f0 	movl   $0xf0101860,(%esp)
f0100055:	e8 38 09 00 00       	call   f0100992 <cprintf>
	if (x > 0)
f010005a:	85 db                	test   %ebx,%ebx
f010005c:	7e 0d                	jle    f010006b <test_backtrace+0x2b>
		test_backtrace(x-1);
f010005e:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0100061:	89 04 24             	mov    %eax,(%esp)
f0100064:	e8 d7 ff ff ff       	call   f0100040 <test_backtrace>
f0100069:	eb 1c                	jmp    f0100087 <test_backtrace+0x47>
	else
		mon_backtrace(0, 0, 0);
f010006b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100072:	00 
f0100073:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010007a:	00 
f010007b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100082:	e8 d1 06 00 00       	call   f0100758 <mon_backtrace>
	cprintf("leaving test_backtrace %d\n", x);
f0100087:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010008b:	c7 04 24 7c 18 10 f0 	movl   $0xf010187c,(%esp)
f0100092:	e8 fb 08 00 00       	call   f0100992 <cprintf>
}
f0100097:	83 c4 14             	add    $0x14,%esp
f010009a:	5b                   	pop    %ebx
f010009b:	5d                   	pop    %ebp
f010009c:	c3                   	ret    

f010009d <i386_init>:

void
i386_init(void)
{
f010009d:	55                   	push   %ebp
f010009e:	89 e5                	mov    %esp,%ebp
f01000a0:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000a3:	b8 40 a9 11 f0       	mov    $0xf011a940,%eax
f01000a8:	2d 00 a3 11 f0       	sub    $0xf011a300,%eax
f01000ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000b1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000b8:	00 
f01000b9:	c7 04 24 00 a3 11 f0 	movl   $0xf011a300,(%esp)
f01000c0:	e8 41 13 00 00       	call   f0101406 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000c5:	e8 77 04 00 00       	call   f0100541 <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000ca:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000d1:	00 
f01000d2:	c7 04 24 97 18 10 f0 	movl   $0xf0101897,(%esp)
f01000d9:	e8 b4 08 00 00       	call   f0100992 <cprintf>

	// Test the stack backtrace function (lab 1 only)
	test_backtrace(5);
f01000de:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f01000e5:	e8 56 ff ff ff       	call   f0100040 <test_backtrace>
	// 	cprintf("x %d, y %x, z %d\n", x, y, z);
	// }

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f01000ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000f1:	e8 1f 07 00 00       	call   f0100815 <monitor>
f01000f6:	eb f2                	jmp    f01000ea <i386_init+0x4d>

f01000f8 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000f8:	55                   	push   %ebp
f01000f9:	89 e5                	mov    %esp,%ebp
f01000fb:	56                   	push   %esi
f01000fc:	53                   	push   %ebx
f01000fd:	83 ec 10             	sub    $0x10,%esp
f0100100:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f0100103:	83 3d 44 a9 11 f0 00 	cmpl   $0x0,0xf011a944
f010010a:	75 3d                	jne    f0100149 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f010010c:	89 35 44 a9 11 f0    	mov    %esi,0xf011a944

	// Be extra sure that the machine is in as reasonable state
	asm volatile("cli; cld");
f0100112:	fa                   	cli    
f0100113:	fc                   	cld    

	va_start(ap, fmt);
f0100114:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f0100117:	8b 45 0c             	mov    0xc(%ebp),%eax
f010011a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010011e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100121:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100125:	c7 04 24 b2 18 10 f0 	movl   $0xf01018b2,(%esp)
f010012c:	e8 61 08 00 00       	call   f0100992 <cprintf>
	vcprintf(fmt, ap);
f0100131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100135:	89 34 24             	mov    %esi,(%esp)
f0100138:	e8 22 08 00 00       	call   f010095f <vcprintf>
	cprintf("\n");
f010013d:	c7 04 24 ee 18 10 f0 	movl   $0xf01018ee,(%esp)
f0100144:	e8 49 08 00 00       	call   f0100992 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100149:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100150:	e8 c0 06 00 00       	call   f0100815 <monitor>
f0100155:	eb f2                	jmp    f0100149 <_panic+0x51>

f0100157 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f0100157:	55                   	push   %ebp
f0100158:	89 e5                	mov    %esp,%ebp
f010015a:	53                   	push   %ebx
f010015b:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f010015e:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f0100161:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100164:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100168:	8b 45 08             	mov    0x8(%ebp),%eax
f010016b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010016f:	c7 04 24 ca 18 10 f0 	movl   $0xf01018ca,(%esp)
f0100176:	e8 17 08 00 00       	call   f0100992 <cprintf>
	vcprintf(fmt, ap);
f010017b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010017f:	8b 45 10             	mov    0x10(%ebp),%eax
f0100182:	89 04 24             	mov    %eax,(%esp)
f0100185:	e8 d5 07 00 00       	call   f010095f <vcprintf>
	cprintf("\n");
f010018a:	c7 04 24 ee 18 10 f0 	movl   $0xf01018ee,(%esp)
f0100191:	e8 fc 07 00 00       	call   f0100992 <cprintf>
	va_end(ap);
}
f0100196:	83 c4 14             	add    $0x14,%esp
f0100199:	5b                   	pop    %ebx
f010019a:	5d                   	pop    %ebp
f010019b:	c3                   	ret    

f010019c <delay>:

// Stupid I/O delay routine necessitated by historical PC design flaws
// 采用读IO操作模拟延时
static void
delay(void)
{
f010019c:	55                   	push   %ebp
f010019d:	89 e5                	mov    %esp,%ebp

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010019f:	ba 84 00 00 00       	mov    $0x84,%edx
f01001a4:	ec                   	in     (%dx),%al
f01001a5:	ec                   	in     (%dx),%al
f01001a6:	ec                   	in     (%dx),%al
f01001a7:	ec                   	in     (%dx),%al
	inb(0x84);
	inb(0x84);
	inb(0x84);
	inb(0x84);
}
f01001a8:	5d                   	pop    %ebp
f01001a9:	c3                   	ret    

f01001aa <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f01001aa:	55                   	push   %ebp
f01001ab:	89 e5                	mov    %esp,%ebp
f01001ad:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01001b2:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f01001b3:	a8 01                	test   $0x1,%al
f01001b5:	74 08                	je     f01001bf <serial_proc_data+0x15>
f01001b7:	b2 f8                	mov    $0xf8,%dl
f01001b9:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01001ba:	0f b6 c0             	movzbl %al,%eax
f01001bd:	eb 05                	jmp    f01001c4 <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f01001bf:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f01001c4:	5d                   	pop    %ebp
f01001c5:	c3                   	ret    

f01001c6 <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01001c6:	55                   	push   %ebp
f01001c7:	89 e5                	mov    %esp,%ebp
f01001c9:	53                   	push   %ebx
f01001ca:	83 ec 04             	sub    $0x4,%esp
f01001cd:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f01001cf:	eb 29                	jmp    f01001fa <cons_intr+0x34>
		if (c == 0)
f01001d1:	85 c0                	test   %eax,%eax
f01001d3:	74 25                	je     f01001fa <cons_intr+0x34>
			continue;
		cons.buf[cons.wpos++] = c;
f01001d5:	8b 15 24 a5 11 f0    	mov    0xf011a524,%edx
f01001db:	88 82 20 a3 11 f0    	mov    %al,-0xfee5ce0(%edx)
f01001e1:	8d 42 01             	lea    0x1(%edx),%eax
f01001e4:	a3 24 a5 11 f0       	mov    %eax,0xf011a524
		if (cons.wpos == CONSBUFSIZE)
f01001e9:	3d 00 02 00 00       	cmp    $0x200,%eax
f01001ee:	75 0a                	jne    f01001fa <cons_intr+0x34>
			cons.wpos = 0;
f01001f0:	c7 05 24 a5 11 f0 00 	movl   $0x0,0xf011a524
f01001f7:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f01001fa:	ff d3                	call   *%ebx
f01001fc:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001ff:	75 d0                	jne    f01001d1 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f0100201:	83 c4 04             	add    $0x4,%esp
f0100204:	5b                   	pop    %ebx
f0100205:	5d                   	pop    %ebp
f0100206:	c3                   	ret    

f0100207 <cons_putc>:

// output a character to the console
// 输出一个字符
static void
cons_putc(int c)
{
f0100207:	55                   	push   %ebp
f0100208:	89 e5                	mov    %esp,%ebp
f010020a:	57                   	push   %edi
f010020b:	56                   	push   %esi
f010020c:	53                   	push   %ebx
f010020d:	83 ec 2c             	sub    $0x2c,%esp
f0100210:	89 c6                	mov    %eax,%esi
f0100212:	bb 01 32 00 00       	mov    $0x3201,%ebx
f0100217:	bf fd 03 00 00       	mov    $0x3fd,%edi
f010021c:	eb 05                	jmp    f0100223 <cons_putc+0x1c>

	// 读取串口的线路状态寄存器LSR，若还不能使用，则等待
	for (i = 0;
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; 
	     i++)
		delay();
f010021e:	e8 79 ff ff ff       	call   f010019c <delay>
f0100223:	89 fa                	mov    %edi,%edx
f0100225:	ec                   	in     (%dx),%al
serial_putc(int c)
{
	int i;

	// 读取串口的线路状态寄存器LSR，若还不能使用，则等待
	for (i = 0;
f0100226:	a8 20                	test   $0x20,%al
f0100228:	75 03                	jne    f010022d <cons_putc+0x26>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800; 
f010022a:	4b                   	dec    %ebx
f010022b:	75 f1                	jne    f010021e <cons_putc+0x17>
	     i++)
		delay();

	outb(COM1 + COM_TX, c);// 向串口的发送寄存器输出字符c
f010022d:	89 f2                	mov    %esi,%edx
f010022f:	89 f0                	mov    %esi,%eax
f0100231:	88 55 e7             	mov    %dl,-0x19(%ebp)
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100234:	ba f8 03 00 00       	mov    $0x3f8,%edx
f0100239:	ee                   	out    %al,(%dx)
f010023a:	bb 01 32 00 00       	mov    $0x3201,%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010023f:	bf 79 03 00 00       	mov    $0x379,%edi
f0100244:	eb 05                	jmp    f010024b <cons_putc+0x44>
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
		delay();
f0100246:	e8 51 ff ff ff       	call   f010019c <delay>
f010024b:	89 fa                	mov    %edi,%edx
f010024d:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f010024e:	84 c0                	test   %al,%al
f0100250:	78 03                	js     f0100255 <cons_putc+0x4e>
f0100252:	4b                   	dec    %ebx
f0100253:	75 f1                	jne    f0100246 <cons_putc+0x3f>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100255:	ba 78 03 00 00       	mov    $0x378,%edx
f010025a:	8a 45 e7             	mov    -0x19(%ebp),%al
f010025d:	ee                   	out    %al,(%dx)
f010025e:	b2 7a                	mov    $0x7a,%dl
f0100260:	b0 0d                	mov    $0xd,%al
f0100262:	ee                   	out    %al,(%dx)
f0100263:	b0 08                	mov    $0x8,%al
f0100265:	ee                   	out    %al,(%dx)
// 用于在CGA（Color Graphics Adapter）显示器上打印字符
static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f0100266:	f7 c6 00 ff ff ff    	test   $0xffffff00,%esi
f010026c:	75 06                	jne    f0100274 <cons_putc+0x6d>
		c |= 0x0700;
f010026e:	81 ce 00 07 00 00    	or     $0x700,%esi

	switch (c & 0xff) {
f0100274:	89 f0                	mov    %esi,%eax
f0100276:	25 ff 00 00 00       	and    $0xff,%eax
f010027b:	83 f8 09             	cmp    $0x9,%eax
f010027e:	74 78                	je     f01002f8 <cons_putc+0xf1>
f0100280:	83 f8 09             	cmp    $0x9,%eax
f0100283:	7f 0b                	jg     f0100290 <cons_putc+0x89>
f0100285:	83 f8 08             	cmp    $0x8,%eax
f0100288:	0f 85 9e 00 00 00    	jne    f010032c <cons_putc+0x125>
f010028e:	eb 10                	jmp    f01002a0 <cons_putc+0x99>
f0100290:	83 f8 0a             	cmp    $0xa,%eax
f0100293:	74 39                	je     f01002ce <cons_putc+0xc7>
f0100295:	83 f8 0d             	cmp    $0xd,%eax
f0100298:	0f 85 8e 00 00 00    	jne    f010032c <cons_putc+0x125>
f010029e:	eb 36                	jmp    f01002d6 <cons_putc+0xcf>
	// 将光标位置减1，并将对应屏幕缓冲区位置的字符设置为空格
	case '\b':
		if (crt_pos > 0) {
f01002a0:	66 a1 34 a5 11 f0    	mov    0xf011a534,%ax
f01002a6:	66 85 c0             	test   %ax,%ax
f01002a9:	0f 84 e2 00 00 00    	je     f0100391 <cons_putc+0x18a>
			crt_pos--;
f01002af:	48                   	dec    %eax
f01002b0:	66 a3 34 a5 11 f0    	mov    %ax,0xf011a534
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01002b6:	0f b7 c0             	movzwl %ax,%eax
f01002b9:	81 e6 00 ff ff ff    	and    $0xffffff00,%esi
f01002bf:	83 ce 20             	or     $0x20,%esi
f01002c2:	8b 15 30 a5 11 f0    	mov    0xf011a530,%edx
f01002c8:	66 89 34 42          	mov    %si,(%edx,%eax,2)
f01002cc:	eb 78                	jmp    f0100346 <cons_putc+0x13f>
		}
		break;
	// 光标下移一个单位
	case '\n':
		crt_pos += CRT_COLS;
f01002ce:	66 83 05 34 a5 11 f0 	addw   $0x50,0xf011a534
f01002d5:	50 
		/* fallthru */
	// 将光标位置移动到当前行的开头
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01002d6:	66 8b 0d 34 a5 11 f0 	mov    0xf011a534,%cx
f01002dd:	bb 50 00 00 00       	mov    $0x50,%ebx
f01002e2:	89 c8                	mov    %ecx,%eax
f01002e4:	ba 00 00 00 00       	mov    $0x0,%edx
f01002e9:	66 f7 f3             	div    %bx
f01002ec:	66 29 d1             	sub    %dx,%cx
f01002ef:	66 89 0d 34 a5 11 f0 	mov    %cx,0xf011a534
f01002f6:	eb 4e                	jmp    f0100346 <cons_putc+0x13f>
		break;
	// 连续打印5个空格字符
	case '\t':
		cons_putc(' ');
f01002f8:	b8 20 00 00 00       	mov    $0x20,%eax
f01002fd:	e8 05 ff ff ff       	call   f0100207 <cons_putc>
		cons_putc(' ');
f0100302:	b8 20 00 00 00       	mov    $0x20,%eax
f0100307:	e8 fb fe ff ff       	call   f0100207 <cons_putc>
		cons_putc(' ');
f010030c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100311:	e8 f1 fe ff ff       	call   f0100207 <cons_putc>
		cons_putc(' ');
f0100316:	b8 20 00 00 00       	mov    $0x20,%eax
f010031b:	e8 e7 fe ff ff       	call   f0100207 <cons_putc>
		cons_putc(' ');
f0100320:	b8 20 00 00 00       	mov    $0x20,%eax
f0100325:	e8 dd fe ff ff       	call   f0100207 <cons_putc>
f010032a:	eb 1a                	jmp    f0100346 <cons_putc+0x13f>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f010032c:	66 a1 34 a5 11 f0    	mov    0xf011a534,%ax
f0100332:	0f b7 c8             	movzwl %ax,%ecx
f0100335:	8b 15 30 a5 11 f0    	mov    0xf011a530,%edx
f010033b:	66 89 34 4a          	mov    %si,(%edx,%ecx,2)
f010033f:	40                   	inc    %eax
f0100340:	66 a3 34 a5 11 f0    	mov    %ax,0xf011a534
		break;
	}

	// What is the purpose of this? 检查光标位置是否超过屏幕缓冲区的大小
	if (crt_pos >= CRT_SIZE) {
f0100346:	66 81 3d 34 a5 11 f0 	cmpw   $0x7cf,0xf011a534
f010034d:	cf 07 
f010034f:	76 40                	jbe    f0100391 <cons_putc+0x18a>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t)); // 将屏幕缓冲区的内容向前移动一行，2~n行的数据（CRT_SIZE - CRT_COLS）个，移动到1~n-1行的位置
f0100351:	a1 30 a5 11 f0       	mov    0xf011a530,%eax
f0100356:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010035d:	00 
f010035e:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100364:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100368:	89 04 24             	mov    %eax,(%esp)
f010036b:	e8 e0 10 00 00       	call   f0101450 <memmove>
		// 将最后一行的属性值设置为默认值，字符设置为空格，即用空格擦出字符
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f0100370:	8b 15 30 a5 11 f0    	mov    0xf011a530,%edx
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t)); // 将屏幕缓冲区的内容向前移动一行，2~n行的数据（CRT_SIZE - CRT_COLS）个，移动到1~n-1行的位置
		// 将最后一行的属性值设置为默认值，字符设置为空格，即用空格擦出字符
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100376:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f010037b:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t)); // 将屏幕缓冲区的内容向前移动一行，2~n行的数据（CRT_SIZE - CRT_COLS）个，移动到1~n-1行的位置
		// 将最后一行的属性值设置为默认值，字符设置为空格，即用空格擦出字符
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100381:	40                   	inc    %eax
f0100382:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100387:	75 f2                	jne    f010037b <cons_putc+0x174>
			crt_buf[i] = 0x0700 | ' ';
		// 将光标位置移动到上一行的对应位置
		crt_pos -= CRT_COLS;
f0100389:	66 83 2d 34 a5 11 f0 	subw   $0x50,0xf011a534
f0100390:	50 
	}

	/* move that little blinky thing */
	// 更新CGA控制寄存器来移动光标位置
	outb(addr_6845, 14);
f0100391:	8b 0d 2c a5 11 f0    	mov    0xf011a52c,%ecx
f0100397:	b0 0e                	mov    $0xe,%al
f0100399:	89 ca                	mov    %ecx,%edx
f010039b:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010039c:	66 8b 35 34 a5 11 f0 	mov    0xf011a534,%si
f01003a3:	8d 59 01             	lea    0x1(%ecx),%ebx
f01003a6:	89 f0                	mov    %esi,%eax
f01003a8:	66 c1 e8 08          	shr    $0x8,%ax
f01003ac:	89 da                	mov    %ebx,%edx
f01003ae:	ee                   	out    %al,(%dx)
f01003af:	b0 0f                	mov    $0xf,%al
f01003b1:	89 ca                	mov    %ecx,%edx
f01003b3:	ee                   	out    %al,(%dx)
f01003b4:	89 f0                	mov    %esi,%eax
f01003b6:	89 da                	mov    %ebx,%edx
f01003b8:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c); // 串口打印
	lpt_putc(c); // 并行端口打印
	cga_putc(c); // cga彩色屏幕打印
}
f01003b9:	83 c4 2c             	add    $0x2c,%esp
f01003bc:	5b                   	pop    %ebx
f01003bd:	5e                   	pop    %esi
f01003be:	5f                   	pop    %edi
f01003bf:	5d                   	pop    %ebp
f01003c0:	c3                   	ret    

f01003c1 <kbd_proc_data>:
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01003c1:	55                   	push   %ebp
f01003c2:	89 e5                	mov    %esp,%ebp
f01003c4:	53                   	push   %ebx
f01003c5:	83 ec 14             	sub    $0x14,%esp

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01003c8:	ba 64 00 00 00       	mov    $0x64,%edx
f01003cd:	ec                   	in     (%dx),%al
	int c;
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
f01003ce:	0f b6 c0             	movzbl %al,%eax
f01003d1:	a8 01                	test   $0x1,%al
f01003d3:	0f 84 e0 00 00 00    	je     f01004b9 <kbd_proc_data+0xf8>
		return -1;
	// Ignore data from mouse.
	if (stat & KBS_TERR)
f01003d9:	a8 20                	test   $0x20,%al
f01003db:	0f 85 df 00 00 00    	jne    f01004c0 <kbd_proc_data+0xff>
f01003e1:	b2 60                	mov    $0x60,%dl
f01003e3:	ec                   	in     (%dx),%al
f01003e4:	88 c2                	mov    %al,%dl
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01003e6:	3c e0                	cmp    $0xe0,%al
f01003e8:	75 11                	jne    f01003fb <kbd_proc_data+0x3a>
		// E0 escape character
		shift |= E0ESC;
f01003ea:	83 0d 28 a5 11 f0 40 	orl    $0x40,0xf011a528
		return 0;
f01003f1:	bb 00 00 00 00       	mov    $0x0,%ebx
f01003f6:	e9 ca 00 00 00       	jmp    f01004c5 <kbd_proc_data+0x104>
	} else if (data & 0x80) {
f01003fb:	84 c0                	test   %al,%al
f01003fd:	79 33                	jns    f0100432 <kbd_proc_data+0x71>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01003ff:	8b 0d 28 a5 11 f0    	mov    0xf011a528,%ecx
f0100405:	f6 c1 40             	test   $0x40,%cl
f0100408:	75 05                	jne    f010040f <kbd_proc_data+0x4e>
f010040a:	88 c2                	mov    %al,%dl
f010040c:	83 e2 7f             	and    $0x7f,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f010040f:	0f b6 d2             	movzbl %dl,%edx
f0100412:	8a 82 20 19 10 f0    	mov    -0xfefe6e0(%edx),%al
f0100418:	83 c8 40             	or     $0x40,%eax
f010041b:	0f b6 c0             	movzbl %al,%eax
f010041e:	f7 d0                	not    %eax
f0100420:	21 c1                	and    %eax,%ecx
f0100422:	89 0d 28 a5 11 f0    	mov    %ecx,0xf011a528
		return 0;
f0100428:	bb 00 00 00 00       	mov    $0x0,%ebx
f010042d:	e9 93 00 00 00       	jmp    f01004c5 <kbd_proc_data+0x104>
	} else if (shift & E0ESC) {
f0100432:	8b 0d 28 a5 11 f0    	mov    0xf011a528,%ecx
f0100438:	f6 c1 40             	test   $0x40,%cl
f010043b:	74 0e                	je     f010044b <kbd_proc_data+0x8a>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f010043d:	88 c2                	mov    %al,%dl
f010043f:	83 ca 80             	or     $0xffffff80,%edx
		shift &= ~E0ESC;
f0100442:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100445:	89 0d 28 a5 11 f0    	mov    %ecx,0xf011a528
	}

	shift |= shiftcode[data];
f010044b:	0f b6 d2             	movzbl %dl,%edx
f010044e:	0f b6 82 20 19 10 f0 	movzbl -0xfefe6e0(%edx),%eax
f0100455:	0b 05 28 a5 11 f0    	or     0xf011a528,%eax
	shift ^= togglecode[data];
f010045b:	0f b6 8a 20 1a 10 f0 	movzbl -0xfefe5e0(%edx),%ecx
f0100462:	31 c8                	xor    %ecx,%eax
f0100464:	a3 28 a5 11 f0       	mov    %eax,0xf011a528

	c = charcode[shift & (CTL | SHIFT)][data];
f0100469:	89 c1                	mov    %eax,%ecx
f010046b:	83 e1 03             	and    $0x3,%ecx
f010046e:	8b 0c 8d 20 1b 10 f0 	mov    -0xfefe4e0(,%ecx,4),%ecx
f0100475:	0f b6 1c 11          	movzbl (%ecx,%edx,1),%ebx
	if (shift & CAPSLOCK) {
f0100479:	a8 08                	test   $0x8,%al
f010047b:	74 18                	je     f0100495 <kbd_proc_data+0xd4>
		if ('a' <= c && c <= 'z')
f010047d:	8d 53 9f             	lea    -0x61(%ebx),%edx
f0100480:	83 fa 19             	cmp    $0x19,%edx
f0100483:	77 05                	ja     f010048a <kbd_proc_data+0xc9>
			c += 'A' - 'a';
f0100485:	83 eb 20             	sub    $0x20,%ebx
f0100488:	eb 0b                	jmp    f0100495 <kbd_proc_data+0xd4>
		else if ('A' <= c && c <= 'Z')
f010048a:	8d 53 bf             	lea    -0x41(%ebx),%edx
f010048d:	83 fa 19             	cmp    $0x19,%edx
f0100490:	77 03                	ja     f0100495 <kbd_proc_data+0xd4>
			c += 'a' - 'A';
f0100492:	83 c3 20             	add    $0x20,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100495:	f7 d0                	not    %eax
f0100497:	a8 06                	test   $0x6,%al
f0100499:	75 2a                	jne    f01004c5 <kbd_proc_data+0x104>
f010049b:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01004a1:	75 22                	jne    f01004c5 <kbd_proc_data+0x104>
		cprintf("Rebooting!\n");
f01004a3:	c7 04 24 e4 18 10 f0 	movl   $0xf01018e4,(%esp)
f01004aa:	e8 e3 04 00 00       	call   f0100992 <cprintf>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004af:	ba 92 00 00 00       	mov    $0x92,%edx
f01004b4:	b0 03                	mov    $0x3,%al
f01004b6:	ee                   	out    %al,(%dx)
f01004b7:	eb 0c                	jmp    f01004c5 <kbd_proc_data+0x104>
	uint8_t stat, data;
	static uint32_t shift;

	stat = inb(KBSTATP);
	if ((stat & KBS_DIB) == 0)
		return -1;
f01004b9:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
f01004be:	eb 05                	jmp    f01004c5 <kbd_proc_data+0x104>
	// Ignore data from mouse.
	if (stat & KBS_TERR)
		return -1;
f01004c0:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01004c5:	89 d8                	mov    %ebx,%eax
f01004c7:	83 c4 14             	add    $0x14,%esp
f01004ca:	5b                   	pop    %ebx
f01004cb:	5d                   	pop    %ebp
f01004cc:	c3                   	ret    

f01004cd <serial_intr>:
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004cd:	55                   	push   %ebp
f01004ce:	89 e5                	mov    %esp,%ebp
f01004d0:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
f01004d3:	80 3d 00 a3 11 f0 00 	cmpb   $0x0,0xf011a300
f01004da:	74 0a                	je     f01004e6 <serial_intr+0x19>
		cons_intr(serial_proc_data);
f01004dc:	b8 aa 01 10 f0       	mov    $0xf01001aa,%eax
f01004e1:	e8 e0 fc ff ff       	call   f01001c6 <cons_intr>
}
f01004e6:	c9                   	leave  
f01004e7:	c3                   	ret    

f01004e8 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01004e8:	55                   	push   %ebp
f01004e9:	89 e5                	mov    %esp,%ebp
f01004eb:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01004ee:	b8 c1 03 10 f0       	mov    $0xf01003c1,%eax
f01004f3:	e8 ce fc ff ff       	call   f01001c6 <cons_intr>
}
f01004f8:	c9                   	leave  
f01004f9:	c3                   	ret    

f01004fa <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01004fa:	55                   	push   %ebp
f01004fb:	89 e5                	mov    %esp,%ebp
f01004fd:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f0100500:	e8 c8 ff ff ff       	call   f01004cd <serial_intr>
	kbd_intr();
f0100505:	e8 de ff ff ff       	call   f01004e8 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f010050a:	8b 15 20 a5 11 f0    	mov    0xf011a520,%edx
f0100510:	3b 15 24 a5 11 f0    	cmp    0xf011a524,%edx
f0100516:	74 22                	je     f010053a <cons_getc+0x40>
		c = cons.buf[cons.rpos++];
f0100518:	0f b6 82 20 a3 11 f0 	movzbl -0xfee5ce0(%edx),%eax
f010051f:	42                   	inc    %edx
f0100520:	89 15 20 a5 11 f0    	mov    %edx,0xf011a520
		if (cons.rpos == CONSBUFSIZE)
f0100526:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010052c:	75 11                	jne    f010053f <cons_getc+0x45>
			cons.rpos = 0;
f010052e:	c7 05 20 a5 11 f0 00 	movl   $0x0,0xf011a520
f0100535:	00 00 00 
f0100538:	eb 05                	jmp    f010053f <cons_getc+0x45>
		return c;
	}
	return 0;
f010053a:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010053f:	c9                   	leave  
f0100540:	c3                   	ret    

f0100541 <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f0100541:	55                   	push   %ebp
f0100542:	89 e5                	mov    %esp,%ebp
f0100544:	57                   	push   %edi
f0100545:	56                   	push   %esi
f0100546:	53                   	push   %ebx
f0100547:	83 ec 2c             	sub    $0x2c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f010054a:	66 8b 15 00 80 0b f0 	mov    0xf00b8000,%dx
	*cp = (uint16_t) 0xA55A;
f0100551:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100558:	5a a5 
	if (*cp != 0xA55A) {
f010055a:	66 a1 00 80 0b f0    	mov    0xf00b8000,%ax
f0100560:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100564:	74 11                	je     f0100577 <cons_init+0x36>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100566:	c7 05 2c a5 11 f0 b4 	movl   $0x3b4,0xf011a52c
f010056d:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f0100570:	be 00 00 0b f0       	mov    $0xf00b0000,%esi
f0100575:	eb 16                	jmp    f010058d <cons_init+0x4c>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100577:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010057e:	c7 05 2c a5 11 f0 d4 	movl   $0x3d4,0xf011a52c
f0100585:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100588:	be 00 80 0b f0       	mov    $0xf00b8000,%esi
		*cp = was;
		addr_6845 = CGA_BASE;
	}

	/* Extract cursor location */
	outb(addr_6845, 14);
f010058d:	8b 0d 2c a5 11 f0    	mov    0xf011a52c,%ecx
f0100593:	b0 0e                	mov    $0xe,%al
f0100595:	89 ca                	mov    %ecx,%edx
f0100597:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f0100598:	8d 59 01             	lea    0x1(%ecx),%ebx

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010059b:	89 da                	mov    %ebx,%edx
f010059d:	ec                   	in     (%dx),%al
f010059e:	0f b6 f8             	movzbl %al,%edi
f01005a1:	c1 e7 08             	shl    $0x8,%edi
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005a4:	b0 0f                	mov    $0xf,%al
f01005a6:	89 ca                	mov    %ecx,%edx
f01005a8:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005a9:	89 da                	mov    %ebx,%edx
f01005ab:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f01005ac:	89 35 30 a5 11 f0    	mov    %esi,0xf011a530

	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005b2:	0f b6 d8             	movzbl %al,%ebx
f01005b5:	09 df                	or     %ebx,%edi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005b7:	66 89 3d 34 a5 11 f0 	mov    %di,0xf011a534
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005be:	bb fa 03 00 00       	mov    $0x3fa,%ebx
f01005c3:	b0 00                	mov    $0x0,%al
f01005c5:	89 da                	mov    %ebx,%edx
f01005c7:	ee                   	out    %al,(%dx)
f01005c8:	b2 fb                	mov    $0xfb,%dl
f01005ca:	b0 80                	mov    $0x80,%al
f01005cc:	ee                   	out    %al,(%dx)
f01005cd:	b9 f8 03 00 00       	mov    $0x3f8,%ecx
f01005d2:	b0 0c                	mov    $0xc,%al
f01005d4:	89 ca                	mov    %ecx,%edx
f01005d6:	ee                   	out    %al,(%dx)
f01005d7:	b2 f9                	mov    $0xf9,%dl
f01005d9:	b0 00                	mov    $0x0,%al
f01005db:	ee                   	out    %al,(%dx)
f01005dc:	b2 fb                	mov    $0xfb,%dl
f01005de:	b0 03                	mov    $0x3,%al
f01005e0:	ee                   	out    %al,(%dx)
f01005e1:	b2 fc                	mov    $0xfc,%dl
f01005e3:	b0 00                	mov    $0x0,%al
f01005e5:	ee                   	out    %al,(%dx)
f01005e6:	b2 f9                	mov    $0xf9,%dl
f01005e8:	b0 01                	mov    $0x1,%al
f01005ea:	ee                   	out    %al,(%dx)

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005eb:	b2 fd                	mov    $0xfd,%dl
f01005ed:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01005ee:	3c ff                	cmp    $0xff,%al
f01005f0:	0f 95 45 e7          	setne  -0x19(%ebp)
f01005f4:	8a 45 e7             	mov    -0x19(%ebp),%al
f01005f7:	a2 00 a3 11 f0       	mov    %al,0xf011a300
f01005fc:	89 da                	mov    %ebx,%edx
f01005fe:	ec                   	in     (%dx),%al
f01005ff:	89 ca                	mov    %ecx,%edx
f0100601:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f0100602:	80 7d e7 00          	cmpb   $0x0,-0x19(%ebp)
f0100606:	75 0c                	jne    f0100614 <cons_init+0xd3>
		cprintf("Serial port does not exist!\n");
f0100608:	c7 04 24 f0 18 10 f0 	movl   $0xf01018f0,(%esp)
f010060f:	e8 7e 03 00 00       	call   f0100992 <cprintf>
}
f0100614:	83 c4 2c             	add    $0x2c,%esp
f0100617:	5b                   	pop    %ebx
f0100618:	5e                   	pop    %esi
f0100619:	5f                   	pop    %edi
f010061a:	5d                   	pop    %ebp
f010061b:	c3                   	ret    

f010061c <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.
// 调用cons_putc，进而输出一个字符
void
cputchar(int c)
{
f010061c:	55                   	push   %ebp
f010061d:	89 e5                	mov    %esp,%ebp
f010061f:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100622:	8b 45 08             	mov    0x8(%ebp),%eax
f0100625:	e8 dd fb ff ff       	call   f0100207 <cons_putc>
}
f010062a:	c9                   	leave  
f010062b:	c3                   	ret    

f010062c <getchar>:

int
getchar(void)
{
f010062c:	55                   	push   %ebp
f010062d:	89 e5                	mov    %esp,%ebp
f010062f:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100632:	e8 c3 fe ff ff       	call   f01004fa <cons_getc>
f0100637:	85 c0                	test   %eax,%eax
f0100639:	74 f7                	je     f0100632 <getchar+0x6>
		/* do nothing */;
	return c;
}
f010063b:	c9                   	leave  
f010063c:	c3                   	ret    

f010063d <iscons>:

int
iscons(int fdnum)
{
f010063d:	55                   	push   %ebp
f010063e:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100640:	b8 01 00 00 00       	mov    $0x1,%eax
f0100645:	5d                   	pop    %ebp
f0100646:	c3                   	ret    
	...

f0100648 <mon_kerninfo>:
	return 0;
}

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100648:	55                   	push   %ebp
f0100649:	89 e5                	mov    %esp,%ebp
f010064b:	83 ec 18             	sub    $0x18,%esp
	extern char _start[], entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f010064e:	c7 04 24 30 1b 10 f0 	movl   $0xf0101b30,(%esp)
f0100655:	e8 38 03 00 00       	call   f0100992 <cprintf>
	cprintf("  _start                  %08x (phys)\n", _start);
f010065a:	c7 44 24 04 0c 00 10 	movl   $0x10000c,0x4(%esp)
f0100661:	00 
f0100662:	c7 04 24 f0 1b 10 f0 	movl   $0xf0101bf0,(%esp)
f0100669:	e8 24 03 00 00       	call   f0100992 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f010066e:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100675:	00 
f0100676:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010067d:	f0 
f010067e:	c7 04 24 18 1c 10 f0 	movl   $0xf0101c18,(%esp)
f0100685:	e8 08 03 00 00       	call   f0100992 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010068a:	c7 44 24 08 4a 18 10 	movl   $0x10184a,0x8(%esp)
f0100691:	00 
f0100692:	c7 44 24 04 4a 18 10 	movl   $0xf010184a,0x4(%esp)
f0100699:	f0 
f010069a:	c7 04 24 3c 1c 10 f0 	movl   $0xf0101c3c,(%esp)
f01006a1:	e8 ec 02 00 00       	call   f0100992 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01006a6:	c7 44 24 08 00 a3 11 	movl   $0x11a300,0x8(%esp)
f01006ad:	00 
f01006ae:	c7 44 24 04 00 a3 11 	movl   $0xf011a300,0x4(%esp)
f01006b5:	f0 
f01006b6:	c7 04 24 60 1c 10 f0 	movl   $0xf0101c60,(%esp)
f01006bd:	e8 d0 02 00 00       	call   f0100992 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01006c2:	c7 44 24 08 40 a9 11 	movl   $0x11a940,0x8(%esp)
f01006c9:	00 
f01006ca:	c7 44 24 04 40 a9 11 	movl   $0xf011a940,0x4(%esp)
f01006d1:	f0 
f01006d2:	c7 04 24 84 1c 10 f0 	movl   $0xf0101c84,(%esp)
f01006d9:	e8 b4 02 00 00       	call   f0100992 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		ROUNDUP(end - entry, 1024) / 1024);
f01006de:	b8 3f ad 11 f0       	mov    $0xf011ad3f,%eax
f01006e3:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
f01006e8:	25 00 fc ff ff       	and    $0xfffffc00,%eax
	cprintf("  _start                  %08x (phys)\n", _start);
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f01006ed:	89 c2                	mov    %eax,%edx
f01006ef:	85 c0                	test   %eax,%eax
f01006f1:	79 06                	jns    f01006f9 <mon_kerninfo+0xb1>
f01006f3:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f01006f9:	c1 fa 0a             	sar    $0xa,%edx
f01006fc:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100700:	c7 04 24 a8 1c 10 f0 	movl   $0xf0101ca8,(%esp)
f0100707:	e8 86 02 00 00       	call   f0100992 <cprintf>
		ROUNDUP(end - entry, 1024) / 1024);
	return 0;
}
f010070c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100711:	c9                   	leave  
f0100712:	c3                   	ret    

f0100713 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100713:	55                   	push   %ebp
f0100714:	89 e5                	mov    %esp,%ebp
f0100716:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < ARRAY_SIZE(commands); i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100719:	c7 44 24 08 49 1b 10 	movl   $0xf0101b49,0x8(%esp)
f0100720:	f0 
f0100721:	c7 44 24 04 67 1b 10 	movl   $0xf0101b67,0x4(%esp)
f0100728:	f0 
f0100729:	c7 04 24 6c 1b 10 f0 	movl   $0xf0101b6c,(%esp)
f0100730:	e8 5d 02 00 00       	call   f0100992 <cprintf>
f0100735:	c7 44 24 08 d4 1c 10 	movl   $0xf0101cd4,0x8(%esp)
f010073c:	f0 
f010073d:	c7 44 24 04 75 1b 10 	movl   $0xf0101b75,0x4(%esp)
f0100744:	f0 
f0100745:	c7 04 24 6c 1b 10 f0 	movl   $0xf0101b6c,(%esp)
f010074c:	e8 41 02 00 00       	call   f0100992 <cprintf>
	return 0;
}
f0100751:	b8 00 00 00 00       	mov    $0x0,%eax
f0100756:	c9                   	leave  
f0100757:	c3                   	ret    

f0100758 <mon_backtrace>:
	return 0;
}

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100758:	55                   	push   %ebp
f0100759:	89 e5                	mov    %esp,%ebp
f010075b:	53                   	push   %ebx
f010075c:	83 ec 14             	sub    $0x14,%esp
	// Your code here.
	uint32_t *ebp;
    ebp = (uint32_t *)read_ebp(); // 读ebp
f010075f:	89 eb                	mov    %ebp,%ebx
    cprintf("Stack backtrace:\n");
f0100761:	c7 04 24 7e 1b 10 f0 	movl   $0xf0101b7e,(%esp)
f0100768:	e8 25 02 00 00       	call   f0100992 <cprintf>
    while(ebp!=0){
f010076d:	e9 90 00 00 00       	jmp    f0100802 <mon_backtrace+0xaa>
        cprintf("  ebp %08x",ebp);
f0100772:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100776:	c7 04 24 90 1b 10 f0 	movl   $0xf0101b90,(%esp)
f010077d:	e8 10 02 00 00       	call   f0100992 <cprintf>
        cprintf("  eip %08x  args",*(ebp+1));
f0100782:	8b 43 04             	mov    0x4(%ebx),%eax
f0100785:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100789:	c7 04 24 9b 1b 10 f0 	movl   $0xf0101b9b,(%esp)
f0100790:	e8 fd 01 00 00       	call   f0100992 <cprintf>
        cprintf("  args");
f0100795:	c7 04 24 a5 1b 10 f0 	movl   $0xf0101ba5,(%esp)
f010079c:	e8 f1 01 00 00       	call   f0100992 <cprintf>
        cprintf(" %08x", *(ebp+2));
f01007a1:	8b 43 08             	mov    0x8(%ebx),%eax
f01007a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007a8:	c7 04 24 95 1b 10 f0 	movl   $0xf0101b95,(%esp)
f01007af:	e8 de 01 00 00       	call   f0100992 <cprintf>
        cprintf(" %08x", *(ebp+3));
f01007b4:	8b 43 0c             	mov    0xc(%ebx),%eax
f01007b7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007bb:	c7 04 24 95 1b 10 f0 	movl   $0xf0101b95,(%esp)
f01007c2:	e8 cb 01 00 00       	call   f0100992 <cprintf>
        cprintf(" %08x", *(ebp+4));
f01007c7:	8b 43 10             	mov    0x10(%ebx),%eax
f01007ca:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007ce:	c7 04 24 95 1b 10 f0 	movl   $0xf0101b95,(%esp)
f01007d5:	e8 b8 01 00 00       	call   f0100992 <cprintf>
        cprintf(" %08x", *(ebp+5));
f01007da:	8b 43 14             	mov    0x14(%ebx),%eax
f01007dd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007e1:	c7 04 24 95 1b 10 f0 	movl   $0xf0101b95,(%esp)
f01007e8:	e8 a5 01 00 00       	call   f0100992 <cprintf>
        cprintf(" %08x\n", *(ebp+6));
f01007ed:	8b 43 18             	mov    0x18(%ebx),%eax
f01007f0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007f4:	c7 04 24 ac 1b 10 f0 	movl   $0xf0101bac,(%esp)
f01007fb:	e8 92 01 00 00       	call   f0100992 <cprintf>
        ebp  = (uint32_t*) *ebp; // 调用函数返回，返回前一个调用函数所对应的堆栈的栈底
f0100800:	8b 1b                	mov    (%ebx),%ebx
{
	// Your code here.
	uint32_t *ebp;
    ebp = (uint32_t *)read_ebp(); // 读ebp
    cprintf("Stack backtrace:\n");
    while(ebp!=0){
f0100802:	85 db                	test   %ebx,%ebx
f0100804:	0f 85 68 ff ff ff    	jne    f0100772 <mon_backtrace+0x1a>
        cprintf(" %08x", *(ebp+5));
        cprintf(" %08x\n", *(ebp+6));
        ebp  = (uint32_t*) *ebp; // 调用函数返回，返回前一个调用函数所对应的堆栈的栈底
    }
	return 0;
}
f010080a:	b8 00 00 00 00       	mov    $0x0,%eax
f010080f:	83 c4 14             	add    $0x14,%esp
f0100812:	5b                   	pop    %ebx
f0100813:	5d                   	pop    %ebp
f0100814:	c3                   	ret    

f0100815 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100815:	55                   	push   %ebp
f0100816:	89 e5                	mov    %esp,%ebp
f0100818:	57                   	push   %edi
f0100819:	56                   	push   %esi
f010081a:	53                   	push   %ebx
f010081b:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010081e:	c7 04 24 fc 1c 10 f0 	movl   $0xf0101cfc,(%esp)
f0100825:	e8 68 01 00 00       	call   f0100992 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010082a:	c7 04 24 20 1d 10 f0 	movl   $0xf0101d20,(%esp)
f0100831:	e8 5c 01 00 00       	call   f0100992 <cprintf>
	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
f0100836:	8d 7d a8             	lea    -0x58(%ebp),%edi
	cprintf("Welcome to the JOS kernel monitor!\n");
	cprintf("Type 'help' for a list of commands.\n");


	while (1) {
		buf = readline("K> ");
f0100839:	c7 04 24 b3 1b 10 f0 	movl   $0xf0101bb3,(%esp)
f0100840:	e8 97 09 00 00       	call   f01011dc <readline>
f0100845:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100847:	85 c0                	test   %eax,%eax
f0100849:	74 ee                	je     f0100839 <monitor+0x24>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010084b:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100852:	be 00 00 00 00       	mov    $0x0,%esi
f0100857:	eb 04                	jmp    f010085d <monitor+0x48>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100859:	c6 03 00             	movb   $0x0,(%ebx)
f010085c:	43                   	inc    %ebx
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f010085d:	8a 03                	mov    (%ebx),%al
f010085f:	84 c0                	test   %al,%al
f0100861:	74 5e                	je     f01008c1 <monitor+0xac>
f0100863:	0f be c0             	movsbl %al,%eax
f0100866:	89 44 24 04          	mov    %eax,0x4(%esp)
f010086a:	c7 04 24 b7 1b 10 f0 	movl   $0xf0101bb7,(%esp)
f0100871:	e8 5b 0b 00 00       	call   f01013d1 <strchr>
f0100876:	85 c0                	test   %eax,%eax
f0100878:	75 df                	jne    f0100859 <monitor+0x44>
			*buf++ = 0;
		if (*buf == 0)
f010087a:	80 3b 00             	cmpb   $0x0,(%ebx)
f010087d:	74 42                	je     f01008c1 <monitor+0xac>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f010087f:	83 fe 0f             	cmp    $0xf,%esi
f0100882:	75 16                	jne    f010089a <monitor+0x85>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100884:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f010088b:	00 
f010088c:	c7 04 24 bc 1b 10 f0 	movl   $0xf0101bbc,(%esp)
f0100893:	e8 fa 00 00 00       	call   f0100992 <cprintf>
f0100898:	eb 9f                	jmp    f0100839 <monitor+0x24>
			return 0;
		}
		argv[argc++] = buf;
f010089a:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
f010089e:	46                   	inc    %esi
f010089f:	eb 01                	jmp    f01008a2 <monitor+0x8d>
		while (*buf && !strchr(WHITESPACE, *buf))
			buf++;
f01008a1:	43                   	inc    %ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008a2:	8a 03                	mov    (%ebx),%al
f01008a4:	84 c0                	test   %al,%al
f01008a6:	74 b5                	je     f010085d <monitor+0x48>
f01008a8:	0f be c0             	movsbl %al,%eax
f01008ab:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008af:	c7 04 24 b7 1b 10 f0 	movl   $0xf0101bb7,(%esp)
f01008b6:	e8 16 0b 00 00       	call   f01013d1 <strchr>
f01008bb:	85 c0                	test   %eax,%eax
f01008bd:	74 e2                	je     f01008a1 <monitor+0x8c>
f01008bf:	eb 9c                	jmp    f010085d <monitor+0x48>
			buf++;
	}
	argv[argc] = 0;
f01008c1:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f01008c8:	00 

	// Lookup and invoke the command
	if (argc == 0)
f01008c9:	85 f6                	test   %esi,%esi
f01008cb:	0f 84 68 ff ff ff    	je     f0100839 <monitor+0x24>
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f01008d1:	c7 44 24 04 67 1b 10 	movl   $0xf0101b67,0x4(%esp)
f01008d8:	f0 
f01008d9:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008dc:	89 04 24             	mov    %eax,(%esp)
f01008df:	e8 9a 0a 00 00       	call   f010137e <strcmp>
f01008e4:	85 c0                	test   %eax,%eax
f01008e6:	74 1b                	je     f0100903 <monitor+0xee>
f01008e8:	c7 44 24 04 75 1b 10 	movl   $0xf0101b75,0x4(%esp)
f01008ef:	f0 
f01008f0:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008f3:	89 04 24             	mov    %eax,(%esp)
f01008f6:	e8 83 0a 00 00       	call   f010137e <strcmp>
f01008fb:	85 c0                	test   %eax,%eax
f01008fd:	75 2c                	jne    f010092b <monitor+0x116>
f01008ff:	b0 01                	mov    $0x1,%al
f0100901:	eb 05                	jmp    f0100908 <monitor+0xf3>
f0100903:	b8 00 00 00 00       	mov    $0x0,%eax
			return commands[i].func(argc, argv, tf);
f0100908:	8d 14 00             	lea    (%eax,%eax,1),%edx
f010090b:	01 d0                	add    %edx,%eax
f010090d:	8b 55 08             	mov    0x8(%ebp),%edx
f0100910:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100914:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100918:	89 34 24             	mov    %esi,(%esp)
f010091b:	ff 14 85 50 1d 10 f0 	call   *-0xfefe2b0(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100922:	85 c0                	test   %eax,%eax
f0100924:	78 1d                	js     f0100943 <monitor+0x12e>
f0100926:	e9 0e ff ff ff       	jmp    f0100839 <monitor+0x24>
		return 0;
	for (i = 0; i < ARRAY_SIZE(commands); i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f010092b:	8b 45 a8             	mov    -0x58(%ebp),%eax
f010092e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100932:	c7 04 24 d9 1b 10 f0 	movl   $0xf0101bd9,(%esp)
f0100939:	e8 54 00 00 00       	call   f0100992 <cprintf>
f010093e:	e9 f6 fe ff ff       	jmp    f0100839 <monitor+0x24>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100943:	83 c4 5c             	add    $0x5c,%esp
f0100946:	5b                   	pop    %ebx
f0100947:	5e                   	pop    %esi
f0100948:	5f                   	pop    %edi
f0100949:	5d                   	pop    %ebp
f010094a:	c3                   	ret    
	...

f010094c <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f010094c:	55                   	push   %ebp
f010094d:	89 e5                	mov    %esp,%ebp
f010094f:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch); // 调用console.c中函数，打印字符
f0100952:	8b 45 08             	mov    0x8(%ebp),%eax
f0100955:	89 04 24             	mov    %eax,(%esp)
f0100958:	e8 bf fc ff ff       	call   f010061c <cputchar>
	*cnt++;
}
f010095d:	c9                   	leave  
f010095e:	c3                   	ret    

f010095f <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f010095f:	55                   	push   %ebp
f0100960:	89 e5                	mov    %esp,%ebp
f0100962:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100965:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);// 调用printfmt.c中函数
f010096c:	8b 45 0c             	mov    0xc(%ebp),%eax
f010096f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100973:	8b 45 08             	mov    0x8(%ebp),%eax
f0100976:	89 44 24 08          	mov    %eax,0x8(%esp)
f010097a:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010097d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100981:	c7 04 24 4c 09 10 f0 	movl   $0xf010094c,(%esp)
f0100988:	e8 11 04 00 00       	call   f0100d9e <vprintfmt>
	return cnt;
}
f010098d:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100990:	c9                   	leave  
f0100991:	c3                   	ret    

f0100992 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0100992:	55                   	push   %ebp
f0100993:	89 e5                	mov    %esp,%ebp
f0100995:	83 ec 18             	sub    $0x18,%esp
	va_list ap;// va等用于传入多参数
	int cnt;

	va_start(ap, fmt);
f0100998:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);// 调用
f010099b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010099f:	8b 45 08             	mov    0x8(%ebp),%eax
f01009a2:	89 04 24             	mov    %eax,(%esp)
f01009a5:	e8 b5 ff ff ff       	call   f010095f <vcprintf>
	va_end(ap);

	return cnt;
}
f01009aa:	c9                   	leave  
f01009ab:	c3                   	ret    

f01009ac <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f01009ac:	55                   	push   %ebp
f01009ad:	89 e5                	mov    %esp,%ebp
f01009af:	57                   	push   %edi
f01009b0:	56                   	push   %esi
f01009b1:	53                   	push   %ebx
f01009b2:	83 ec 10             	sub    $0x10,%esp
f01009b5:	89 c3                	mov    %eax,%ebx
f01009b7:	89 55 e8             	mov    %edx,-0x18(%ebp)
f01009ba:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01009bd:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f01009c0:	8b 0a                	mov    (%edx),%ecx
f01009c2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01009c5:	8b 00                	mov    (%eax),%eax
f01009c7:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01009ca:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)

	while (l <= r) {
f01009d1:	eb 77                	jmp    f0100a4a <stab_binsearch+0x9e>
		int true_m = (l + r) / 2, m = true_m;
f01009d3:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01009d6:	01 c8                	add    %ecx,%eax
f01009d8:	bf 02 00 00 00       	mov    $0x2,%edi
f01009dd:	99                   	cltd   
f01009de:	f7 ff                	idiv   %edi
f01009e0:	89 c2                	mov    %eax,%edx

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009e2:	eb 01                	jmp    f01009e5 <stab_binsearch+0x39>
			m--;
f01009e4:	4a                   	dec    %edx

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009e5:	39 ca                	cmp    %ecx,%edx
f01009e7:	7c 1d                	jl     f0100a06 <stab_binsearch+0x5a>
//		left = 0, right = 657;
//		stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
f01009e9:	6b fa 0c             	imul   $0xc,%edx,%edi

	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009ec:	0f b6 7c 3b 04       	movzbl 0x4(%ebx,%edi,1),%edi
f01009f1:	39 f7                	cmp    %esi,%edi
f01009f3:	75 ef                	jne    f01009e4 <stab_binsearch+0x38>
f01009f5:	89 55 ec             	mov    %edx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f01009f8:	6b fa 0c             	imul   $0xc,%edx,%edi
f01009fb:	8b 7c 3b 08          	mov    0x8(%ebx,%edi,1),%edi
f01009ff:	3b 7d 0c             	cmp    0xc(%ebp),%edi
f0100a02:	73 18                	jae    f0100a1c <stab_binsearch+0x70>
f0100a04:	eb 05                	jmp    f0100a0b <stab_binsearch+0x5f>

		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100a06:	8d 48 01             	lea    0x1(%eax),%ecx
			continue;
f0100a09:	eb 3f                	jmp    f0100a4a <stab_binsearch+0x9e>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100a0b:	8b 4d e8             	mov    -0x18(%ebp),%ecx
f0100a0e:	89 11                	mov    %edx,(%ecx)
			l = true_m + 1;
f0100a10:	8d 48 01             	lea    0x1(%eax),%ecx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a13:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a1a:	eb 2e                	jmp    f0100a4a <stab_binsearch+0x9e>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100a1c:	3b 7d 0c             	cmp    0xc(%ebp),%edi
f0100a1f:	76 15                	jbe    f0100a36 <stab_binsearch+0x8a>
			*region_right = m - 1;
f0100a21:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0100a24:	4f                   	dec    %edi
f0100a25:	89 7d f0             	mov    %edi,-0x10(%ebp)
f0100a28:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100a2b:	89 38                	mov    %edi,(%eax)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a2d:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a34:	eb 14                	jmp    f0100a4a <stab_binsearch+0x9e>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100a36:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0100a39:	8b 4d e8             	mov    -0x18(%ebp),%ecx
f0100a3c:	89 39                	mov    %edi,(%ecx)
			l = m;
			addr++;
f0100a3e:	ff 45 0c             	incl   0xc(%ebp)
f0100a41:	89 d1                	mov    %edx,%ecx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a43:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;

	while (l <= r) {
f0100a4a:	3b 4d f0             	cmp    -0x10(%ebp),%ecx
f0100a4d:	7e 84                	jle    f01009d3 <stab_binsearch+0x27>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100a4f:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100a53:	75 0d                	jne    f0100a62 <stab_binsearch+0xb6>
		*region_right = *region_left - 1;
f0100a55:	8b 55 e8             	mov    -0x18(%ebp),%edx
f0100a58:	8b 02                	mov    (%edx),%eax
f0100a5a:	48                   	dec    %eax
f0100a5b:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100a5e:	89 01                	mov    %eax,(%ecx)
f0100a60:	eb 22                	jmp    f0100a84 <stab_binsearch+0xd8>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a62:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100a65:	8b 01                	mov    (%ecx),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100a67:	8b 55 e8             	mov    -0x18(%ebp),%edx
f0100a6a:	8b 0a                	mov    (%edx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a6c:	eb 01                	jmp    f0100a6f <stab_binsearch+0xc3>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100a6e:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a6f:	39 c1                	cmp    %eax,%ecx
f0100a71:	7d 0c                	jge    f0100a7f <stab_binsearch+0xd3>
//		left = 0, right = 657;
//		stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
f0100a73:	6b d0 0c             	imul   $0xc,%eax,%edx
	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
		     l > *region_left && stabs[l].n_type != type;
f0100a76:	0f b6 54 13 04       	movzbl 0x4(%ebx,%edx,1),%edx
f0100a7b:	39 f2                	cmp    %esi,%edx
f0100a7d:	75 ef                	jne    f0100a6e <stab_binsearch+0xc2>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100a7f:	8b 55 e8             	mov    -0x18(%ebp),%edx
f0100a82:	89 02                	mov    %eax,(%edx)
	}
}
f0100a84:	83 c4 10             	add    $0x10,%esp
f0100a87:	5b                   	pop    %ebx
f0100a88:	5e                   	pop    %esi
f0100a89:	5f                   	pop    %edi
f0100a8a:	5d                   	pop    %ebp
f0100a8b:	c3                   	ret    

f0100a8c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100a8c:	55                   	push   %ebp
f0100a8d:	89 e5                	mov    %esp,%ebp
f0100a8f:	57                   	push   %edi
f0100a90:	56                   	push   %esi
f0100a91:	53                   	push   %ebx
f0100a92:	83 ec 2c             	sub    $0x2c,%esp
f0100a95:	8b 75 08             	mov    0x8(%ebp),%esi
f0100a98:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100a9b:	c7 03 60 1d 10 f0    	movl   $0xf0101d60,(%ebx)
	info->eip_line = 0;
f0100aa1:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100aa8:	c7 43 08 60 1d 10 f0 	movl   $0xf0101d60,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100aaf:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100ab6:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100ab9:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100ac0:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100ac6:	76 12                	jbe    f0100ada <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100ac8:	b8 44 f0 10 f0       	mov    $0xf010f044,%eax
f0100acd:	3d 1d 65 10 f0       	cmp    $0xf010651d,%eax
f0100ad2:	0f 86 50 01 00 00    	jbe    f0100c28 <debuginfo_eip+0x19c>
f0100ad8:	eb 1c                	jmp    f0100af6 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100ada:	c7 44 24 08 6a 1d 10 	movl   $0xf0101d6a,0x8(%esp)
f0100ae1:	f0 
f0100ae2:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100ae9:	00 
f0100aea:	c7 04 24 77 1d 10 f0 	movl   $0xf0101d77,(%esp)
f0100af1:	e8 02 f6 ff ff       	call   f01000f8 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100af6:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100afb:	80 3d 43 f0 10 f0 00 	cmpb   $0x0,0xf010f043
f0100b02:	0f 85 2c 01 00 00    	jne    f0100c34 <debuginfo_eip+0x1a8>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100b08:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100b0f:	b8 1c 65 10 f0       	mov    $0xf010651c,%eax
f0100b14:	2d 98 1f 10 f0       	sub    $0xf0101f98,%eax
f0100b19:	c1 f8 02             	sar    $0x2,%eax
f0100b1c:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100b22:	48                   	dec    %eax
f0100b23:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100b26:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b2a:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100b31:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100b34:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100b37:	b8 98 1f 10 f0       	mov    $0xf0101f98,%eax
f0100b3c:	e8 6b fe ff ff       	call   f01009ac <stab_binsearch>
	if (lfile == 0)
f0100b41:	8b 55 e4             	mov    -0x1c(%ebp),%edx
		return -1;
f0100b44:	b8 ff ff ff ff       	mov    $0xffffffff,%eax

	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
f0100b49:	85 d2                	test   %edx,%edx
f0100b4b:	0f 84 e3 00 00 00    	je     f0100c34 <debuginfo_eip+0x1a8>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100b51:	89 55 dc             	mov    %edx,-0x24(%ebp)
	rfun = rfile;
f0100b54:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100b57:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100b5a:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b5e:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100b65:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100b68:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100b6b:	b8 98 1f 10 f0       	mov    $0xf0101f98,%eax
f0100b70:	e8 37 fe ff ff       	call   f01009ac <stab_binsearch>

	if (lfun <= rfun) {
f0100b75:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100b78:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100b7b:	7f 2e                	jg     f0100bab <debuginfo_eip+0x11f>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100b7d:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100b80:	8d 90 98 1f 10 f0    	lea    -0xfefe068(%eax),%edx
f0100b86:	8b 80 98 1f 10 f0    	mov    -0xfefe068(%eax),%eax
f0100b8c:	b9 44 f0 10 f0       	mov    $0xf010f044,%ecx
f0100b91:	81 e9 1d 65 10 f0    	sub    $0xf010651d,%ecx
f0100b97:	39 c8                	cmp    %ecx,%eax
f0100b99:	73 08                	jae    f0100ba3 <debuginfo_eip+0x117>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100b9b:	05 1d 65 10 f0       	add    $0xf010651d,%eax
f0100ba0:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100ba3:	8b 42 08             	mov    0x8(%edx),%eax
f0100ba6:	89 43 10             	mov    %eax,0x10(%ebx)
f0100ba9:	eb 06                	jmp    f0100bb1 <debuginfo_eip+0x125>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100bab:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100bae:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100bb1:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100bb8:	00 
f0100bb9:	8b 43 08             	mov    0x8(%ebx),%eax
f0100bbc:	89 04 24             	mov    %eax,(%esp)
f0100bbf:	e8 2a 08 00 00       	call   f01013ee <strfind>
f0100bc4:	2b 43 08             	sub    0x8(%ebx),%eax
f0100bc7:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100bca:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100bcd:	eb 01                	jmp    f0100bd0 <debuginfo_eip+0x144>
	       && stabs[lline].n_type != N_SOL
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100bcf:	4f                   	dec    %edi
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100bd0:	39 cf                	cmp    %ecx,%edi
f0100bd2:	7c 24                	jl     f0100bf8 <debuginfo_eip+0x16c>
	       && stabs[lline].n_type != N_SOL
f0100bd4:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0100bd7:	8d 14 85 98 1f 10 f0 	lea    -0xfefe068(,%eax,4),%edx
f0100bde:	8a 42 04             	mov    0x4(%edx),%al
f0100be1:	3c 84                	cmp    $0x84,%al
f0100be3:	74 57                	je     f0100c3c <debuginfo_eip+0x1b0>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100be5:	3c 64                	cmp    $0x64,%al
f0100be7:	75 e6                	jne    f0100bcf <debuginfo_eip+0x143>
f0100be9:	83 7a 08 00          	cmpl   $0x0,0x8(%edx)
f0100bed:	74 e0                	je     f0100bcf <debuginfo_eip+0x143>
f0100bef:	eb 4b                	jmp    f0100c3c <debuginfo_eip+0x1b0>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100bf1:	05 1d 65 10 f0       	add    $0xf010651d,%eax
f0100bf6:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100bf8:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100bfb:	8b 55 d8             	mov    -0x28(%ebp),%edx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100bfe:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100c03:	39 d1                	cmp    %edx,%ecx
f0100c05:	7d 2d                	jge    f0100c34 <debuginfo_eip+0x1a8>
		for (lline = lfun + 1;
f0100c07:	8d 41 01             	lea    0x1(%ecx),%eax
f0100c0a:	eb 04                	jmp    f0100c10 <debuginfo_eip+0x184>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
f0100c0c:	ff 43 14             	incl   0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100c0f:	40                   	inc    %eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100c10:	39 d0                	cmp    %edx,%eax
f0100c12:	74 1b                	je     f0100c2f <debuginfo_eip+0x1a3>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100c14:	8d 0c 40             	lea    (%eax,%eax,2),%ecx
f0100c17:	80 3c 8d 9c 1f 10 f0 	cmpb   $0xa0,-0xfefe064(,%ecx,4)
f0100c1e:	a0 
f0100c1f:	74 eb                	je     f0100c0c <debuginfo_eip+0x180>
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100c21:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c26:	eb 0c                	jmp    f0100c34 <debuginfo_eip+0x1a8>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100c28:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c2d:	eb 05                	jmp    f0100c34 <debuginfo_eip+0x1a8>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;

	return 0;
f0100c2f:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100c34:	83 c4 2c             	add    $0x2c,%esp
f0100c37:	5b                   	pop    %ebx
f0100c38:	5e                   	pop    %esi
f0100c39:	5f                   	pop    %edi
f0100c3a:	5d                   	pop    %ebp
f0100c3b:	c3                   	ret    
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
	       && stabs[lline].n_type != N_SOL
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100c3c:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100c3f:	8b 87 98 1f 10 f0    	mov    -0xfefe068(%edi),%eax
f0100c45:	ba 44 f0 10 f0       	mov    $0xf010f044,%edx
f0100c4a:	81 ea 1d 65 10 f0    	sub    $0xf010651d,%edx
f0100c50:	39 d0                	cmp    %edx,%eax
f0100c52:	72 9d                	jb     f0100bf1 <debuginfo_eip+0x165>
f0100c54:	eb a2                	jmp    f0100bf8 <debuginfo_eip+0x16c>
	...

f0100c58 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100c58:	55                   	push   %ebp
f0100c59:	89 e5                	mov    %esp,%ebp
f0100c5b:	57                   	push   %edi
f0100c5c:	56                   	push   %esi
f0100c5d:	53                   	push   %ebx
f0100c5e:	83 ec 3c             	sub    $0x3c,%esp
f0100c61:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100c64:	89 d7                	mov    %edx,%edi
f0100c66:	8b 45 08             	mov    0x8(%ebp),%eax
f0100c69:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0100c6c:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100c6f:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100c72:	8b 5d 14             	mov    0x14(%ebp),%ebx
f0100c75:	8b 75 18             	mov    0x18(%ebp),%esi
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100c78:	85 c0                	test   %eax,%eax
f0100c7a:	75 08                	jne    f0100c84 <printnum+0x2c>
f0100c7c:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100c7f:	39 45 10             	cmp    %eax,0x10(%ebp)
f0100c82:	77 57                	ja     f0100cdb <printnum+0x83>
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100c84:	89 74 24 10          	mov    %esi,0x10(%esp)
f0100c88:	4b                   	dec    %ebx
f0100c89:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0100c8d:	8b 45 10             	mov    0x10(%ebp),%eax
f0100c90:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100c94:	8b 5c 24 08          	mov    0x8(%esp),%ebx
f0100c98:	8b 74 24 0c          	mov    0xc(%esp),%esi
f0100c9c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0100ca3:	00 
f0100ca4:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100ca7:	89 04 24             	mov    %eax,(%esp)
f0100caa:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100cad:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100cb1:	e8 46 09 00 00       	call   f01015fc <__udivdi3>
f0100cb6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0100cba:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100cbe:	89 04 24             	mov    %eax,(%esp)
f0100cc1:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100cc5:	89 fa                	mov    %edi,%edx
f0100cc7:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100cca:	e8 89 ff ff ff       	call   f0100c58 <printnum>
f0100ccf:	eb 0f                	jmp    f0100ce0 <printnum+0x88>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100cd1:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100cd5:	89 34 24             	mov    %esi,(%esp)
f0100cd8:	ff 55 e4             	call   *-0x1c(%ebp)
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100cdb:	4b                   	dec    %ebx
f0100cdc:	85 db                	test   %ebx,%ebx
f0100cde:	7f f1                	jg     f0100cd1 <printnum+0x79>
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100ce0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100ce4:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100ce8:	8b 45 10             	mov    0x10(%ebp),%eax
f0100ceb:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100cef:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0100cf6:	00 
f0100cf7:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0100cfa:	89 04 24             	mov    %eax,(%esp)
f0100cfd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d00:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d04:	e8 13 0a 00 00       	call   f010171c <__umoddi3>
f0100d09:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d0d:	0f be 80 85 1d 10 f0 	movsbl -0xfefe27b(%eax),%eax
f0100d14:	89 04 24             	mov    %eax,(%esp)
f0100d17:	ff 55 e4             	call   *-0x1c(%ebp)
}
f0100d1a:	83 c4 3c             	add    $0x3c,%esp
f0100d1d:	5b                   	pop    %ebx
f0100d1e:	5e                   	pop    %esi
f0100d1f:	5f                   	pop    %edi
f0100d20:	5d                   	pop    %ebp
f0100d21:	c3                   	ret    

f0100d22 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0100d22:	55                   	push   %ebp
f0100d23:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0100d25:	83 fa 01             	cmp    $0x1,%edx
f0100d28:	7e 0e                	jle    f0100d38 <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0100d2a:	8b 10                	mov    (%eax),%edx
f0100d2c:	8d 4a 08             	lea    0x8(%edx),%ecx
f0100d2f:	89 08                	mov    %ecx,(%eax)
f0100d31:	8b 02                	mov    (%edx),%eax
f0100d33:	8b 52 04             	mov    0x4(%edx),%edx
f0100d36:	eb 22                	jmp    f0100d5a <getuint+0x38>
	else if (lflag)
f0100d38:	85 d2                	test   %edx,%edx
f0100d3a:	74 10                	je     f0100d4c <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0100d3c:	8b 10                	mov    (%eax),%edx
f0100d3e:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100d41:	89 08                	mov    %ecx,(%eax)
f0100d43:	8b 02                	mov    (%edx),%eax
f0100d45:	ba 00 00 00 00       	mov    $0x0,%edx
f0100d4a:	eb 0e                	jmp    f0100d5a <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0100d4c:	8b 10                	mov    (%eax),%edx
f0100d4e:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100d51:	89 08                	mov    %ecx,(%eax)
f0100d53:	8b 02                	mov    (%edx),%eax
f0100d55:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0100d5a:	5d                   	pop    %ebp
f0100d5b:	c3                   	ret    

f0100d5c <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100d5c:	55                   	push   %ebp
f0100d5d:	89 e5                	mov    %esp,%ebp
f0100d5f:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100d62:	ff 40 08             	incl   0x8(%eax)
	if (b->buf < b->ebuf)
f0100d65:	8b 10                	mov    (%eax),%edx
f0100d67:	3b 50 04             	cmp    0x4(%eax),%edx
f0100d6a:	73 08                	jae    f0100d74 <sprintputch+0x18>
		*b->buf++ = ch;
f0100d6c:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0100d6f:	88 0a                	mov    %cl,(%edx)
f0100d71:	42                   	inc    %edx
f0100d72:	89 10                	mov    %edx,(%eax)
}
f0100d74:	5d                   	pop    %ebp
f0100d75:	c3                   	ret    

f0100d76 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100d76:	55                   	push   %ebp
f0100d77:	89 e5                	mov    %esp,%ebp
f0100d79:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100d7c:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100d7f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100d83:	8b 45 10             	mov    0x10(%ebp),%eax
f0100d86:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100d8a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100d8d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d91:	8b 45 08             	mov    0x8(%ebp),%eax
f0100d94:	89 04 24             	mov    %eax,(%esp)
f0100d97:	e8 02 00 00 00       	call   f0100d9e <vprintfmt>
	va_end(ap);
}
f0100d9c:	c9                   	leave  
f0100d9d:	c3                   	ret    

f0100d9e <vprintfmt>:
// 打印核心函数
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100d9e:	55                   	push   %ebp
f0100d9f:	89 e5                	mov    %esp,%ebp
f0100da1:	57                   	push   %edi
f0100da2:	56                   	push   %esi
f0100da3:	53                   	push   %ebx
f0100da4:	83 ec 4c             	sub    $0x4c,%esp
f0100da7:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0100daa:	8b 75 10             	mov    0x10(%ebp),%esi
f0100dad:	eb 12                	jmp    f0100dc1 <vprintfmt+0x23>
	char padc;

	while (1) {
		// 若ch不是‘%’，则打印该字符
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0100daf:	85 c0                	test   %eax,%eax
f0100db1:	0f 84 96 03 00 00    	je     f010114d <vprintfmt+0x3af>
				return;
			putch(ch, putdat);
f0100db7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100dbb:	89 04 24             	mov    %eax,(%esp)
f0100dbe:	ff 55 08             	call   *0x8(%ebp)
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		// 若ch不是‘%’，则打印该字符
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100dc1:	0f b6 06             	movzbl (%esi),%eax
f0100dc4:	46                   	inc    %esi
f0100dc5:	83 f8 25             	cmp    $0x25,%eax
f0100dc8:	75 e5                	jne    f0100daf <vprintfmt+0x11>
f0100dca:	c6 45 dc 20          	movb   $0x20,-0x24(%ebp)
f0100dce:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0100dd5:	bf ff ff ff ff       	mov    $0xffffffff,%edi
f0100dda:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0100de1:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0100de8:	eb 23                	jmp    f0100e0d <vprintfmt+0x6f>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100dea:	89 ce                	mov    %ecx,%esi

		// flag to pad on the right (前提是未占满字段宽度)表示是 在%-escape序列的右边用'-'进行填充
		case '-':
			padc = '-';
f0100dec:	c6 45 dc 2d          	movb   $0x2d,-0x24(%ebp)
f0100df0:	eb 1b                	jmp    f0100e0d <vprintfmt+0x6f>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100df2:	89 ce                	mov    %ecx,%esi
			padc = '-';
			goto reswitch;

		// flag to pad with 0's instead of spaces (前提是未占满字段宽度)表示是 在%-escape序列的右边用'0'进行填充
		case '0':
			padc = '0';
f0100df4:	c6 45 dc 30          	movb   $0x30,-0x24(%ebp)
f0100df8:	eb 13                	jmp    f0100e0d <vprintfmt+0x6f>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100dfa:	89 ce                	mov    %ecx,%esi
			precision = va_arg(ap, int);
			goto process_precision;

		case '.':
			if (width < 0)
				width = 0;
f0100dfc:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
f0100e03:	eb 08                	jmp    f0100e0d <vprintfmt+0x6f>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0100e05:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0100e08:	bf ff ff ff ff       	mov    $0xffffffff,%edi
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e0d:	8a 16                	mov    (%esi),%dl
f0100e0f:	0f b6 c2             	movzbl %dl,%eax
f0100e12:	8d 4e 01             	lea    0x1(%esi),%ecx
f0100e15:	83 ea 23             	sub    $0x23,%edx
f0100e18:	80 fa 55             	cmp    $0x55,%dl
f0100e1b:	0f 87 10 03 00 00    	ja     f0101131 <vprintfmt+0x393>
f0100e21:	0f b6 d2             	movzbl %dl,%edx
f0100e24:	ff 24 95 14 1e 10 f0 	jmp    *-0xfefe1ec(,%edx,4)
f0100e2b:	89 ce                	mov    %ecx,%esi
f0100e2d:	bf 00 00 00 00       	mov    $0x0,%edi
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0100e32:	8d 14 bf             	lea    (%edi,%edi,4),%edx
f0100e35:	8d 7c 50 d0          	lea    -0x30(%eax,%edx,2),%edi
				ch = *fmt; // 注意：因为每次switch后fmt自动+1，所以当前fmt是下一个
f0100e39:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0100e3c:	8d 50 d0             	lea    -0x30(%eax),%edx
f0100e3f:	83 fa 09             	cmp    $0x9,%edx
f0100e42:	77 27                	ja     f0100e6b <vprintfmt+0xcd>
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0100e44:	46                   	inc    %esi
				precision = precision * 10 + ch - '0';
				ch = *fmt; // 注意：因为每次switch后fmt自动+1，所以当前fmt是下一个
				if (ch < '0' || ch > '9')
					break;
			}
f0100e45:	eb eb                	jmp    f0100e32 <vprintfmt+0x94>
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0100e47:	8b 45 14             	mov    0x14(%ebp),%eax
f0100e4a:	8d 50 04             	lea    0x4(%eax),%edx
f0100e4d:	89 55 14             	mov    %edx,0x14(%ebp)
f0100e50:	8b 38                	mov    (%eax),%edi
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e52:	89 ce                	mov    %ecx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0100e54:	eb 15                	jmp    f0100e6b <vprintfmt+0xcd>

		case '.':
			if (width < 0)
f0100e56:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0100e5a:	78 9e                	js     f0100dfa <vprintfmt+0x5c>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e5c:	89 ce                	mov    %ecx,%esi
f0100e5e:	eb ad                	jmp    f0100e0d <vprintfmt+0x6f>
f0100e60:	89 ce                	mov    %ecx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0100e62:	c7 45 e0 01 00 00 00 	movl   $0x1,-0x20(%ebp)
			goto reswitch;
f0100e69:	eb a2                	jmp    f0100e0d <vprintfmt+0x6f>

		process_precision:
			if (width < 0)
f0100e6b:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0100e6f:	79 9c                	jns    f0100e0d <vprintfmt+0x6f>
f0100e71:	eb 92                	jmp    f0100e05 <vprintfmt+0x67>
			goto reswitch;

		// long flag (doubled for long long)
		/* 长标志,lflag = 0 -> int，1 -> long，2 -> long long */
		case 'l':
			lflag++;
f0100e73:	ff 45 d8             	incl   -0x28(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e76:	89 ce                	mov    %ecx,%esi

		// long flag (doubled for long long)
		/* 长标志,lflag = 0 -> int，1 -> long，2 -> long long */
		case 'l':
			lflag++;
			goto reswitch;
f0100e78:	eb 93                	jmp    f0100e0d <vprintfmt+0x6f>
f0100e7a:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		// character 传入新的一个字符到ap中
		case 'c':
			putch(va_arg(ap, int), putdat);
f0100e7d:	8b 45 14             	mov    0x14(%ebp),%eax
f0100e80:	8d 50 04             	lea    0x4(%eax),%edx
f0100e83:	89 55 14             	mov    %edx,0x14(%ebp)
f0100e86:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100e8a:	8b 00                	mov    (%eax),%eax
f0100e8c:	89 04 24             	mov    %eax,(%esp)
f0100e8f:	ff 55 08             	call   *0x8(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e92:	8b 75 d4             	mov    -0x2c(%ebp),%esi
			goto reswitch;

		// character 传入新的一个字符到ap中
		case 'c':
			putch(va_arg(ap, int), putdat);
			break;
f0100e95:	e9 27 ff ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
f0100e9a:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		// error message 错误信息
		case 'e':
			err = va_arg(ap, int);
f0100e9d:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ea0:	8d 50 04             	lea    0x4(%eax),%edx
f0100ea3:	89 55 14             	mov    %edx,0x14(%ebp)
f0100ea6:	8b 00                	mov    (%eax),%eax
f0100ea8:	85 c0                	test   %eax,%eax
f0100eaa:	79 02                	jns    f0100eae <vprintfmt+0x110>
f0100eac:	f7 d8                	neg    %eax
f0100eae:	89 c2                	mov    %eax,%edx
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0100eb0:	83 f8 06             	cmp    $0x6,%eax
f0100eb3:	7f 0b                	jg     f0100ec0 <vprintfmt+0x122>
f0100eb5:	8b 04 85 6c 1f 10 f0 	mov    -0xfefe094(,%eax,4),%eax
f0100ebc:	85 c0                	test   %eax,%eax
f0100ebe:	75 23                	jne    f0100ee3 <vprintfmt+0x145>
				printfmt(putch, putdat, "error %d", err);
f0100ec0:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100ec4:	c7 44 24 08 9d 1d 10 	movl   $0xf0101d9d,0x8(%esp)
f0100ecb:	f0 
f0100ecc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100ed0:	8b 45 08             	mov    0x8(%ebp),%eax
f0100ed3:	89 04 24             	mov    %eax,(%esp)
f0100ed6:	e8 9b fe ff ff       	call   f0100d76 <printfmt>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100edb:	8b 75 d4             	mov    -0x2c(%ebp),%esi
		case 'e':
			err = va_arg(ap, int);
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f0100ede:	e9 de fe ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
			else
				printfmt(putch, putdat, "%s", p);
f0100ee3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ee7:	c7 44 24 08 a6 1d 10 	movl   $0xf0101da6,0x8(%esp)
f0100eee:	f0 
f0100eef:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100ef3:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ef6:	89 14 24             	mov    %edx,(%esp)
f0100ef9:	e8 78 fe ff ff       	call   f0100d76 <printfmt>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100efe:	8b 75 d4             	mov    -0x2c(%ebp),%esi
f0100f01:	e9 bb fe ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
f0100f06:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0100f09:	89 f9                	mov    %edi,%ecx
f0100f0b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100f0e:	89 45 d8             	mov    %eax,-0x28(%ebp)
				printfmt(putch, putdat, "%s", p);
			break;

		// string 字符串
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0100f11:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f14:	8d 50 04             	lea    0x4(%eax),%edx
f0100f17:	89 55 14             	mov    %edx,0x14(%ebp)
f0100f1a:	8b 30                	mov    (%eax),%esi
f0100f1c:	85 f6                	test   %esi,%esi
f0100f1e:	75 05                	jne    f0100f25 <vprintfmt+0x187>
				p = "(null)";
f0100f20:	be 96 1d 10 f0       	mov    $0xf0101d96,%esi
			if (width > 0 && padc != '-')
f0100f25:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0100f29:	0f 8e 84 00 00 00    	jle    f0100fb3 <vprintfmt+0x215>
f0100f2f:	80 7d dc 2d          	cmpb   $0x2d,-0x24(%ebp)
f0100f33:	74 7e                	je     f0100fb3 <vprintfmt+0x215>
				for (width -= strnlen(p, precision); width > 0; width--)
f0100f35:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100f39:	89 34 24             	mov    %esi,(%esp)
f0100f3c:	e8 79 03 00 00       	call   f01012ba <strnlen>
f0100f41:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100f44:	29 c2                	sub    %eax,%edx
f0100f46:	89 55 e4             	mov    %edx,-0x1c(%ebp)
					putch(padc, putdat);
f0100f49:	0f be 45 dc          	movsbl -0x24(%ebp),%eax
f0100f4d:	89 75 d0             	mov    %esi,-0x30(%ebp)
f0100f50:	89 7d cc             	mov    %edi,-0x34(%ebp)
f0100f53:	89 de                	mov    %ebx,%esi
f0100f55:	89 d3                	mov    %edx,%ebx
f0100f57:	89 c7                	mov    %eax,%edi
		// string 字符串
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0100f59:	eb 0b                	jmp    f0100f66 <vprintfmt+0x1c8>
					putch(padc, putdat);
f0100f5b:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100f5f:	89 3c 24             	mov    %edi,(%esp)
f0100f62:	ff 55 08             	call   *0x8(%ebp)
		// string 字符串
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0100f65:	4b                   	dec    %ebx
f0100f66:	85 db                	test   %ebx,%ebx
f0100f68:	7f f1                	jg     f0100f5b <vprintfmt+0x1bd>
f0100f6a:	8b 7d cc             	mov    -0x34(%ebp),%edi
f0100f6d:	89 f3                	mov    %esi,%ebx
f0100f6f:	8b 75 d0             	mov    -0x30(%ebp),%esi
// Main function to format and print a string.
// 打印核心函数
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
f0100f72:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100f75:	85 c0                	test   %eax,%eax
f0100f77:	79 05                	jns    f0100f7e <vprintfmt+0x1e0>
f0100f79:	b8 00 00 00 00       	mov    $0x0,%eax
f0100f7e:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0100f81:	29 c2                	sub    %eax,%edx
f0100f83:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0100f86:	eb 2b                	jmp    f0100fb3 <vprintfmt+0x215>
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0100f88:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f0100f8c:	74 18                	je     f0100fa6 <vprintfmt+0x208>
f0100f8e:	8d 50 e0             	lea    -0x20(%eax),%edx
f0100f91:	83 fa 5e             	cmp    $0x5e,%edx
f0100f94:	76 10                	jbe    f0100fa6 <vprintfmt+0x208>
					putch('?', putdat);
f0100f96:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100f9a:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0100fa1:	ff 55 08             	call   *0x8(%ebp)
f0100fa4:	eb 0a                	jmp    f0100fb0 <vprintfmt+0x212>
				else
					putch(ch, putdat);
f0100fa6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100faa:	89 04 24             	mov    %eax,(%esp)
f0100fad:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0100fb0:	ff 4d e4             	decl   -0x1c(%ebp)
f0100fb3:	0f be 06             	movsbl (%esi),%eax
f0100fb6:	46                   	inc    %esi
f0100fb7:	85 c0                	test   %eax,%eax
f0100fb9:	74 21                	je     f0100fdc <vprintfmt+0x23e>
f0100fbb:	85 ff                	test   %edi,%edi
f0100fbd:	78 c9                	js     f0100f88 <vprintfmt+0x1ea>
f0100fbf:	4f                   	dec    %edi
f0100fc0:	79 c6                	jns    f0100f88 <vprintfmt+0x1ea>
f0100fc2:	8b 7d 08             	mov    0x8(%ebp),%edi
f0100fc5:	89 de                	mov    %ebx,%esi
f0100fc7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100fca:	eb 18                	jmp    f0100fe4 <vprintfmt+0x246>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0100fcc:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100fd0:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0100fd7:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0100fd9:	4b                   	dec    %ebx
f0100fda:	eb 08                	jmp    f0100fe4 <vprintfmt+0x246>
f0100fdc:	8b 7d 08             	mov    0x8(%ebp),%edi
f0100fdf:	89 de                	mov    %ebx,%esi
f0100fe1:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100fe4:	85 db                	test   %ebx,%ebx
f0100fe6:	7f e4                	jg     f0100fcc <vprintfmt+0x22e>
f0100fe8:	89 7d 08             	mov    %edi,0x8(%ebp)
f0100feb:	89 f3                	mov    %esi,%ebx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100fed:	8b 75 d4             	mov    -0x2c(%ebp),%esi
f0100ff0:	e9 cc fd ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
f0100ff5:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0100ff8:	83 7d d8 01          	cmpl   $0x1,-0x28(%ebp)
f0100ffc:	7e 10                	jle    f010100e <vprintfmt+0x270>
		return va_arg(*ap, long long);
f0100ffe:	8b 45 14             	mov    0x14(%ebp),%eax
f0101001:	8d 50 08             	lea    0x8(%eax),%edx
f0101004:	89 55 14             	mov    %edx,0x14(%ebp)
f0101007:	8b 30                	mov    (%eax),%esi
f0101009:	8b 78 04             	mov    0x4(%eax),%edi
f010100c:	eb 28                	jmp    f0101036 <vprintfmt+0x298>
	else if (lflag)
f010100e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0101012:	74 12                	je     f0101026 <vprintfmt+0x288>
		return va_arg(*ap, long);
f0101014:	8b 45 14             	mov    0x14(%ebp),%eax
f0101017:	8d 50 04             	lea    0x4(%eax),%edx
f010101a:	89 55 14             	mov    %edx,0x14(%ebp)
f010101d:	8b 30                	mov    (%eax),%esi
f010101f:	89 f7                	mov    %esi,%edi
f0101021:	c1 ff 1f             	sar    $0x1f,%edi
f0101024:	eb 10                	jmp    f0101036 <vprintfmt+0x298>
	else
		return va_arg(*ap, int);
f0101026:	8b 45 14             	mov    0x14(%ebp),%eax
f0101029:	8d 50 04             	lea    0x4(%eax),%edx
f010102c:	89 55 14             	mov    %edx,0x14(%ebp)
f010102f:	8b 30                	mov    (%eax),%esi
f0101031:	89 f7                	mov    %esi,%edi
f0101033:	c1 ff 1f             	sar    $0x1f,%edi

		// (signed) decimal
		// (有符号)十进制
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0101036:	85 ff                	test   %edi,%edi
f0101038:	78 0a                	js     f0101044 <vprintfmt+0x2a6>
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010103a:	b8 0a 00 00 00       	mov    $0xa,%eax
f010103f:	e9 ac 00 00 00       	jmp    f01010f0 <vprintfmt+0x352>
		// (signed) decimal
		// (有符号)十进制
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
				putch('-', putdat);
f0101044:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101048:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010104f:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0101052:	f7 de                	neg    %esi
f0101054:	83 d7 00             	adc    $0x0,%edi
f0101057:	f7 df                	neg    %edi
			}
			base = 10;
f0101059:	b8 0a 00 00 00       	mov    $0xa,%eax
f010105e:	e9 8d 00 00 00       	jmp    f01010f0 <vprintfmt+0x352>
f0101063:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
			goto number;

		// unsigned decimal
		// 无符号十进制
		case 'u':
			num = getuint(&ap, lflag);
f0101066:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101069:	8d 45 14             	lea    0x14(%ebp),%eax
f010106c:	e8 b1 fc ff ff       	call   f0100d22 <getuint>
f0101071:	89 c6                	mov    %eax,%esi
f0101073:	89 d7                	mov    %edx,%edi
			base = 10;
f0101075:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f010107a:	eb 74                	jmp    f01010f0 <vprintfmt+0x352>
f010107c:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
			// Replace this with your code.
			// putch('X', putdat);
			// putch('X', putdat);
			// putch('X', putdat);
			// break;
			putch('0', putdat);
f010107f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101083:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010108a:	ff 55 08             	call   *0x8(%ebp)
			num = getuint(&ap, lflag);
f010108d:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101090:	8d 45 14             	lea    0x14(%ebp),%eax
f0101093:	e8 8a fc ff ff       	call   f0100d22 <getuint>
f0101098:	89 c6                	mov    %eax,%esi
f010109a:	89 d7                	mov    %edx,%edi
			base = 8;
f010109c:	b8 08 00 00 00       	mov    $0x8,%eax
			goto number;
f01010a1:	eb 4d                	jmp    f01010f0 <vprintfmt+0x352>
f01010a3:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		// pointer
		// 指针
		case 'p':
			putch('0', putdat);
f01010a6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01010aa:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01010b1:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01010b4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01010b8:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01010bf:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01010c2:	8b 45 14             	mov    0x14(%ebp),%eax
f01010c5:	8d 50 04             	lea    0x4(%eax),%edx
f01010c8:	89 55 14             	mov    %edx,0x14(%ebp)
		// pointer
		// 指针
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01010cb:	8b 30                	mov    (%eax),%esi
f01010cd:	bf 00 00 00 00       	mov    $0x0,%edi
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01010d2:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f01010d7:	eb 17                	jmp    f01010f0 <vprintfmt+0x352>
f01010d9:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		// (unsigned) hexadecimal
		// (无符号) 十六进制
		case 'x':
			num = getuint(&ap, lflag);
f01010dc:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01010df:	8d 45 14             	lea    0x14(%ebp),%eax
f01010e2:	e8 3b fc ff ff       	call   f0100d22 <getuint>
f01010e7:	89 c6                	mov    %eax,%esi
f01010e9:	89 d7                	mov    %edx,%edi
			base = 16;
f01010eb:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f01010f0:	0f be 55 dc          	movsbl -0x24(%ebp),%edx
f01010f4:	89 54 24 10          	mov    %edx,0x10(%esp)
f01010f8:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f01010fb:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01010ff:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101103:	89 34 24             	mov    %esi,(%esp)
f0101106:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010110a:	89 da                	mov    %ebx,%edx
f010110c:	8b 45 08             	mov    0x8(%ebp),%eax
f010110f:	e8 44 fb ff ff       	call   f0100c58 <printnum>
			break;
f0101114:	8b 75 d4             	mov    -0x2c(%ebp),%esi
f0101117:	e9 a5 fc ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
f010111c:	89 4d d4             	mov    %ecx,-0x2c(%ebp)

		// escaped '%' character
		//转义的“%”字符
		case '%':
			putch(ch, putdat);
f010111f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101123:	89 04 24             	mov    %eax,(%esp)
f0101126:	ff 55 08             	call   *0x8(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101129:	8b 75 d4             	mov    -0x2c(%ebp),%esi

		// escaped '%' character
		//转义的“%”字符
		case '%':
			putch(ch, putdat);
			break;
f010112c:	e9 90 fc ff ff       	jmp    f0100dc1 <vprintfmt+0x23>

		// unrecognized escape sequence - just print it literally
		//无法识别的转义序列-只需逐字打印即可
		default:
			putch('%', putdat);
f0101131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101135:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f010113c:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f010113f:	eb 01                	jmp    f0101142 <vprintfmt+0x3a4>
f0101141:	4e                   	dec    %esi
f0101142:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0101146:	75 f9                	jne    f0101141 <vprintfmt+0x3a3>
f0101148:	e9 74 fc ff ff       	jmp    f0100dc1 <vprintfmt+0x23>
				/* do nothing */;
			break;
		}
	}
}
f010114d:	83 c4 4c             	add    $0x4c,%esp
f0101150:	5b                   	pop    %ebx
f0101151:	5e                   	pop    %esi
f0101152:	5f                   	pop    %edi
f0101153:	5d                   	pop    %ebp
f0101154:	c3                   	ret    

f0101155 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101155:	55                   	push   %ebp
f0101156:	89 e5                	mov    %esp,%ebp
f0101158:	83 ec 28             	sub    $0x28,%esp
f010115b:	8b 45 08             	mov    0x8(%ebp),%eax
f010115e:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0101161:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101164:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101168:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010116b:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0101172:	85 c0                	test   %eax,%eax
f0101174:	74 30                	je     f01011a6 <vsnprintf+0x51>
f0101176:	85 d2                	test   %edx,%edx
f0101178:	7e 33                	jle    f01011ad <vsnprintf+0x58>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010117a:	8b 45 14             	mov    0x14(%ebp),%eax
f010117d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101181:	8b 45 10             	mov    0x10(%ebp),%eax
f0101184:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101188:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010118b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010118f:	c7 04 24 5c 0d 10 f0 	movl   $0xf0100d5c,(%esp)
f0101196:	e8 03 fc ff ff       	call   f0100d9e <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f010119b:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010119e:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01011a1:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01011a4:	eb 0c                	jmp    f01011b2 <vsnprintf+0x5d>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01011a6:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01011ab:	eb 05                	jmp    f01011b2 <vsnprintf+0x5d>
f01011ad:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01011b2:	c9                   	leave  
f01011b3:	c3                   	ret    

f01011b4 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01011b4:	55                   	push   %ebp
f01011b5:	89 e5                	mov    %esp,%ebp
f01011b7:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01011ba:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01011bd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011c1:	8b 45 10             	mov    0x10(%ebp),%eax
f01011c4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01011c8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01011cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01011cf:	8b 45 08             	mov    0x8(%ebp),%eax
f01011d2:	89 04 24             	mov    %eax,(%esp)
f01011d5:	e8 7b ff ff ff       	call   f0101155 <vsnprintf>
	va_end(ap);

	return rc;
}
f01011da:	c9                   	leave  
f01011db:	c3                   	ret    

f01011dc <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01011dc:	55                   	push   %ebp
f01011dd:	89 e5                	mov    %esp,%ebp
f01011df:	57                   	push   %edi
f01011e0:	56                   	push   %esi
f01011e1:	53                   	push   %ebx
f01011e2:	83 ec 1c             	sub    $0x1c,%esp
f01011e5:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01011e8:	85 c0                	test   %eax,%eax
f01011ea:	74 10                	je     f01011fc <readline+0x20>
		cprintf("%s", prompt);
f01011ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01011f0:	c7 04 24 a6 1d 10 f0 	movl   $0xf0101da6,(%esp)
f01011f7:	e8 96 f7 ff ff       	call   f0100992 <cprintf>

	i = 0;
	echoing = iscons(0);
f01011fc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101203:	e8 35 f4 ff ff       	call   f010063d <iscons>
f0101208:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010120a:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f010120f:	e8 18 f4 ff ff       	call   f010062c <getchar>
f0101214:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0101216:	85 c0                	test   %eax,%eax
f0101218:	79 17                	jns    f0101231 <readline+0x55>
			cprintf("read error: %e\n", c);
f010121a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010121e:	c7 04 24 88 1f 10 f0 	movl   $0xf0101f88,(%esp)
f0101225:	e8 68 f7 ff ff       	call   f0100992 <cprintf>
			return NULL;
f010122a:	b8 00 00 00 00       	mov    $0x0,%eax
f010122f:	eb 69                	jmp    f010129a <readline+0xbe>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0101231:	83 f8 08             	cmp    $0x8,%eax
f0101234:	74 05                	je     f010123b <readline+0x5f>
f0101236:	83 f8 7f             	cmp    $0x7f,%eax
f0101239:	75 17                	jne    f0101252 <readline+0x76>
f010123b:	85 f6                	test   %esi,%esi
f010123d:	7e 13                	jle    f0101252 <readline+0x76>
			if (echoing)
f010123f:	85 ff                	test   %edi,%edi
f0101241:	74 0c                	je     f010124f <readline+0x73>
				cputchar('\b');
f0101243:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010124a:	e8 cd f3 ff ff       	call   f010061c <cputchar>
			i--;
f010124f:	4e                   	dec    %esi
f0101250:	eb bd                	jmp    f010120f <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101252:	83 fb 1f             	cmp    $0x1f,%ebx
f0101255:	7e 1d                	jle    f0101274 <readline+0x98>
f0101257:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010125d:	7f 15                	jg     f0101274 <readline+0x98>
			if (echoing)
f010125f:	85 ff                	test   %edi,%edi
f0101261:	74 08                	je     f010126b <readline+0x8f>
				cputchar(c);
f0101263:	89 1c 24             	mov    %ebx,(%esp)
f0101266:	e8 b1 f3 ff ff       	call   f010061c <cputchar>
			buf[i++] = c;
f010126b:	88 9e 40 a5 11 f0    	mov    %bl,-0xfee5ac0(%esi)
f0101271:	46                   	inc    %esi
f0101272:	eb 9b                	jmp    f010120f <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0101274:	83 fb 0a             	cmp    $0xa,%ebx
f0101277:	74 05                	je     f010127e <readline+0xa2>
f0101279:	83 fb 0d             	cmp    $0xd,%ebx
f010127c:	75 91                	jne    f010120f <readline+0x33>
			if (echoing)
f010127e:	85 ff                	test   %edi,%edi
f0101280:	74 0c                	je     f010128e <readline+0xb2>
				cputchar('\n');
f0101282:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101289:	e8 8e f3 ff ff       	call   f010061c <cputchar>
			buf[i] = 0;
f010128e:	c6 86 40 a5 11 f0 00 	movb   $0x0,-0xfee5ac0(%esi)
			return buf;
f0101295:	b8 40 a5 11 f0       	mov    $0xf011a540,%eax
		}
	}
}
f010129a:	83 c4 1c             	add    $0x1c,%esp
f010129d:	5b                   	pop    %ebx
f010129e:	5e                   	pop    %esi
f010129f:	5f                   	pop    %edi
f01012a0:	5d                   	pop    %ebp
f01012a1:	c3                   	ret    
	...

f01012a4 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01012a4:	55                   	push   %ebp
f01012a5:	89 e5                	mov    %esp,%ebp
f01012a7:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01012aa:	b8 00 00 00 00       	mov    $0x0,%eax
f01012af:	eb 01                	jmp    f01012b2 <strlen+0xe>
		n++;
f01012b1:	40                   	inc    %eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01012b2:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01012b6:	75 f9                	jne    f01012b1 <strlen+0xd>
		n++;
	return n;
}
f01012b8:	5d                   	pop    %ebp
f01012b9:	c3                   	ret    

f01012ba <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01012ba:	55                   	push   %ebp
f01012bb:	89 e5                	mov    %esp,%ebp
f01012bd:	8b 4d 08             	mov    0x8(%ebp),%ecx
		n++;
	return n;
}

int
strnlen(const char *s, size_t size)
f01012c0:	8b 55 0c             	mov    0xc(%ebp),%edx
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01012c3:	b8 00 00 00 00       	mov    $0x0,%eax
f01012c8:	eb 01                	jmp    f01012cb <strnlen+0x11>
		n++;
f01012ca:	40                   	inc    %eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01012cb:	39 d0                	cmp    %edx,%eax
f01012cd:	74 06                	je     f01012d5 <strnlen+0x1b>
f01012cf:	80 3c 01 00          	cmpb   $0x0,(%ecx,%eax,1)
f01012d3:	75 f5                	jne    f01012ca <strnlen+0x10>
		n++;
	return n;
}
f01012d5:	5d                   	pop    %ebp
f01012d6:	c3                   	ret    

f01012d7 <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01012d7:	55                   	push   %ebp
f01012d8:	89 e5                	mov    %esp,%ebp
f01012da:	53                   	push   %ebx
f01012db:	8b 45 08             	mov    0x8(%ebp),%eax
f01012de:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01012e1:	ba 00 00 00 00       	mov    $0x0,%edx
f01012e6:	8a 0c 13             	mov    (%ebx,%edx,1),%cl
f01012e9:	88 0c 10             	mov    %cl,(%eax,%edx,1)
f01012ec:	42                   	inc    %edx
f01012ed:	84 c9                	test   %cl,%cl
f01012ef:	75 f5                	jne    f01012e6 <strcpy+0xf>
		/* do nothing */;
	return ret;
}
f01012f1:	5b                   	pop    %ebx
f01012f2:	5d                   	pop    %ebp
f01012f3:	c3                   	ret    

f01012f4 <strcat>:

char *
strcat(char *dst, const char *src)
{
f01012f4:	55                   	push   %ebp
f01012f5:	89 e5                	mov    %esp,%ebp
f01012f7:	53                   	push   %ebx
f01012f8:	83 ec 08             	sub    $0x8,%esp
f01012fb:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01012fe:	89 1c 24             	mov    %ebx,(%esp)
f0101301:	e8 9e ff ff ff       	call   f01012a4 <strlen>
	strcpy(dst + len, src);
f0101306:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101309:	89 54 24 04          	mov    %edx,0x4(%esp)
f010130d:	01 d8                	add    %ebx,%eax
f010130f:	89 04 24             	mov    %eax,(%esp)
f0101312:	e8 c0 ff ff ff       	call   f01012d7 <strcpy>
	return dst;
}
f0101317:	89 d8                	mov    %ebx,%eax
f0101319:	83 c4 08             	add    $0x8,%esp
f010131c:	5b                   	pop    %ebx
f010131d:	5d                   	pop    %ebp
f010131e:	c3                   	ret    

f010131f <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f010131f:	55                   	push   %ebp
f0101320:	89 e5                	mov    %esp,%ebp
f0101322:	56                   	push   %esi
f0101323:	53                   	push   %ebx
f0101324:	8b 45 08             	mov    0x8(%ebp),%eax
f0101327:	8b 55 0c             	mov    0xc(%ebp),%edx
f010132a:	8b 75 10             	mov    0x10(%ebp),%esi
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010132d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101332:	eb 0c                	jmp    f0101340 <strncpy+0x21>
		*dst++ = *src;
f0101334:	8a 1a                	mov    (%edx),%bl
f0101336:	88 1c 08             	mov    %bl,(%eax,%ecx,1)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0101339:	80 3a 01             	cmpb   $0x1,(%edx)
f010133c:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010133f:	41                   	inc    %ecx
f0101340:	39 f1                	cmp    %esi,%ecx
f0101342:	75 f0                	jne    f0101334 <strncpy+0x15>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0101344:	5b                   	pop    %ebx
f0101345:	5e                   	pop    %esi
f0101346:	5d                   	pop    %ebp
f0101347:	c3                   	ret    

f0101348 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0101348:	55                   	push   %ebp
f0101349:	89 e5                	mov    %esp,%ebp
f010134b:	56                   	push   %esi
f010134c:	53                   	push   %ebx
f010134d:	8b 75 08             	mov    0x8(%ebp),%esi
f0101350:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0101353:	8b 55 10             	mov    0x10(%ebp),%edx
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0101356:	85 d2                	test   %edx,%edx
f0101358:	75 0a                	jne    f0101364 <strlcpy+0x1c>
f010135a:	89 f0                	mov    %esi,%eax
f010135c:	eb 1a                	jmp    f0101378 <strlcpy+0x30>
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f010135e:	88 18                	mov    %bl,(%eax)
f0101360:	40                   	inc    %eax
f0101361:	41                   	inc    %ecx
f0101362:	eb 02                	jmp    f0101366 <strlcpy+0x1e>
strlcpy(char *dst, const char *src, size_t size)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0101364:	89 f0                	mov    %esi,%eax
		while (--size > 0 && *src != '\0')
f0101366:	4a                   	dec    %edx
f0101367:	74 0a                	je     f0101373 <strlcpy+0x2b>
f0101369:	8a 19                	mov    (%ecx),%bl
f010136b:	84 db                	test   %bl,%bl
f010136d:	75 ef                	jne    f010135e <strlcpy+0x16>
f010136f:	89 c2                	mov    %eax,%edx
f0101371:	eb 02                	jmp    f0101375 <strlcpy+0x2d>
f0101373:	89 c2                	mov    %eax,%edx
			*dst++ = *src++;
		*dst = '\0';
f0101375:	c6 02 00             	movb   $0x0,(%edx)
	}
	return dst - dst_in;
f0101378:	29 f0                	sub    %esi,%eax
}
f010137a:	5b                   	pop    %ebx
f010137b:	5e                   	pop    %esi
f010137c:	5d                   	pop    %ebp
f010137d:	c3                   	ret    

f010137e <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010137e:	55                   	push   %ebp
f010137f:	89 e5                	mov    %esp,%ebp
f0101381:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101384:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101387:	eb 02                	jmp    f010138b <strcmp+0xd>
		p++, q++;
f0101389:	41                   	inc    %ecx
f010138a:	42                   	inc    %edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010138b:	8a 01                	mov    (%ecx),%al
f010138d:	84 c0                	test   %al,%al
f010138f:	74 04                	je     f0101395 <strcmp+0x17>
f0101391:	3a 02                	cmp    (%edx),%al
f0101393:	74 f4                	je     f0101389 <strcmp+0xb>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0101395:	0f b6 c0             	movzbl %al,%eax
f0101398:	0f b6 12             	movzbl (%edx),%edx
f010139b:	29 d0                	sub    %edx,%eax
}
f010139d:	5d                   	pop    %ebp
f010139e:	c3                   	ret    

f010139f <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f010139f:	55                   	push   %ebp
f01013a0:	89 e5                	mov    %esp,%ebp
f01013a2:	53                   	push   %ebx
f01013a3:	8b 45 08             	mov    0x8(%ebp),%eax
f01013a6:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01013a9:	8b 55 10             	mov    0x10(%ebp),%edx
	while (n > 0 && *p && *p == *q)
f01013ac:	eb 03                	jmp    f01013b1 <strncmp+0x12>
		n--, p++, q++;
f01013ae:	4a                   	dec    %edx
f01013af:	40                   	inc    %eax
f01013b0:	41                   	inc    %ecx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01013b1:	85 d2                	test   %edx,%edx
f01013b3:	74 14                	je     f01013c9 <strncmp+0x2a>
f01013b5:	8a 18                	mov    (%eax),%bl
f01013b7:	84 db                	test   %bl,%bl
f01013b9:	74 04                	je     f01013bf <strncmp+0x20>
f01013bb:	3a 19                	cmp    (%ecx),%bl
f01013bd:	74 ef                	je     f01013ae <strncmp+0xf>
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01013bf:	0f b6 00             	movzbl (%eax),%eax
f01013c2:	0f b6 11             	movzbl (%ecx),%edx
f01013c5:	29 d0                	sub    %edx,%eax
f01013c7:	eb 05                	jmp    f01013ce <strncmp+0x2f>
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
f01013c9:	b8 00 00 00 00       	mov    $0x0,%eax
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
}
f01013ce:	5b                   	pop    %ebx
f01013cf:	5d                   	pop    %ebp
f01013d0:	c3                   	ret    

f01013d1 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01013d1:	55                   	push   %ebp
f01013d2:	89 e5                	mov    %esp,%ebp
f01013d4:	8b 45 08             	mov    0x8(%ebp),%eax
f01013d7:	8a 4d 0c             	mov    0xc(%ebp),%cl
	for (; *s; s++)
f01013da:	eb 05                	jmp    f01013e1 <strchr+0x10>
		if (*s == c)
f01013dc:	38 ca                	cmp    %cl,%dl
f01013de:	74 0c                	je     f01013ec <strchr+0x1b>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01013e0:	40                   	inc    %eax
f01013e1:	8a 10                	mov    (%eax),%dl
f01013e3:	84 d2                	test   %dl,%dl
f01013e5:	75 f5                	jne    f01013dc <strchr+0xb>
		if (*s == c)
			return (char *) s;
	return 0;
f01013e7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01013ec:	5d                   	pop    %ebp
f01013ed:	c3                   	ret    

f01013ee <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01013ee:	55                   	push   %ebp
f01013ef:	89 e5                	mov    %esp,%ebp
f01013f1:	8b 45 08             	mov    0x8(%ebp),%eax
f01013f4:	8a 4d 0c             	mov    0xc(%ebp),%cl
	for (; *s; s++)
f01013f7:	eb 05                	jmp    f01013fe <strfind+0x10>
		if (*s == c)
f01013f9:	38 ca                	cmp    %cl,%dl
f01013fb:	74 07                	je     f0101404 <strfind+0x16>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01013fd:	40                   	inc    %eax
f01013fe:	8a 10                	mov    (%eax),%dl
f0101400:	84 d2                	test   %dl,%dl
f0101402:	75 f5                	jne    f01013f9 <strfind+0xb>
		if (*s == c)
			break;
	return (char *) s;
}
f0101404:	5d                   	pop    %ebp
f0101405:	c3                   	ret    

f0101406 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0101406:	55                   	push   %ebp
f0101407:	89 e5                	mov    %esp,%ebp
f0101409:	57                   	push   %edi
f010140a:	56                   	push   %esi
f010140b:	53                   	push   %ebx
f010140c:	8b 7d 08             	mov    0x8(%ebp),%edi
f010140f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101412:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0101415:	85 c9                	test   %ecx,%ecx
f0101417:	74 30                	je     f0101449 <memset+0x43>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0101419:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010141f:	75 25                	jne    f0101446 <memset+0x40>
f0101421:	f6 c1 03             	test   $0x3,%cl
f0101424:	75 20                	jne    f0101446 <memset+0x40>
		c &= 0xFF;
f0101426:	0f b6 d0             	movzbl %al,%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0101429:	89 d3                	mov    %edx,%ebx
f010142b:	c1 e3 08             	shl    $0x8,%ebx
f010142e:	89 d6                	mov    %edx,%esi
f0101430:	c1 e6 18             	shl    $0x18,%esi
f0101433:	89 d0                	mov    %edx,%eax
f0101435:	c1 e0 10             	shl    $0x10,%eax
f0101438:	09 f0                	or     %esi,%eax
f010143a:	09 d0                	or     %edx,%eax
f010143c:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f010143e:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0101441:	fc                   	cld    
f0101442:	f3 ab                	rep stos %eax,%es:(%edi)
f0101444:	eb 03                	jmp    f0101449 <memset+0x43>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0101446:	fc                   	cld    
f0101447:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0101449:	89 f8                	mov    %edi,%eax
f010144b:	5b                   	pop    %ebx
f010144c:	5e                   	pop    %esi
f010144d:	5f                   	pop    %edi
f010144e:	5d                   	pop    %ebp
f010144f:	c3                   	ret    

f0101450 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0101450:	55                   	push   %ebp
f0101451:	89 e5                	mov    %esp,%ebp
f0101453:	57                   	push   %edi
f0101454:	56                   	push   %esi
f0101455:	8b 45 08             	mov    0x8(%ebp),%eax
f0101458:	8b 75 0c             	mov    0xc(%ebp),%esi
f010145b:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;

	s = src;
	d = dst;
	if (s < d && s + n > d) {
f010145e:	39 c6                	cmp    %eax,%esi
f0101460:	73 34                	jae    f0101496 <memmove+0x46>
f0101462:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101465:	39 d0                	cmp    %edx,%eax
f0101467:	73 2d                	jae    f0101496 <memmove+0x46>
		s += n;
		d += n;
f0101469:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010146c:	f6 c2 03             	test   $0x3,%dl
f010146f:	75 1b                	jne    f010148c <memmove+0x3c>
f0101471:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0101477:	75 13                	jne    f010148c <memmove+0x3c>
f0101479:	f6 c1 03             	test   $0x3,%cl
f010147c:	75 0e                	jne    f010148c <memmove+0x3c>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f010147e:	83 ef 04             	sub    $0x4,%edi
f0101481:	8d 72 fc             	lea    -0x4(%edx),%esi
f0101484:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0101487:	fd                   	std    
f0101488:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010148a:	eb 07                	jmp    f0101493 <memmove+0x43>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010148c:	4f                   	dec    %edi
f010148d:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0101490:	fd                   	std    
f0101491:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101493:	fc                   	cld    
f0101494:	eb 20                	jmp    f01014b6 <memmove+0x66>
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101496:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010149c:	75 13                	jne    f01014b1 <memmove+0x61>
f010149e:	a8 03                	test   $0x3,%al
f01014a0:	75 0f                	jne    f01014b1 <memmove+0x61>
f01014a2:	f6 c1 03             	test   $0x3,%cl
f01014a5:	75 0a                	jne    f01014b1 <memmove+0x61>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f01014a7:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f01014aa:	89 c7                	mov    %eax,%edi
f01014ac:	fc                   	cld    
f01014ad:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01014af:	eb 05                	jmp    f01014b6 <memmove+0x66>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f01014b1:	89 c7                	mov    %eax,%edi
f01014b3:	fc                   	cld    
f01014b4:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01014b6:	5e                   	pop    %esi
f01014b7:	5f                   	pop    %edi
f01014b8:	5d                   	pop    %ebp
f01014b9:	c3                   	ret    

f01014ba <memcpy>:
}
#endif

void *
memcpy(void *dst, const void *src, size_t n)
{
f01014ba:	55                   	push   %ebp
f01014bb:	89 e5                	mov    %esp,%ebp
f01014bd:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01014c0:	8b 45 10             	mov    0x10(%ebp),%eax
f01014c3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01014c7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01014ca:	89 44 24 04          	mov    %eax,0x4(%esp)
f01014ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01014d1:	89 04 24             	mov    %eax,(%esp)
f01014d4:	e8 77 ff ff ff       	call   f0101450 <memmove>
}
f01014d9:	c9                   	leave  
f01014da:	c3                   	ret    

f01014db <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01014db:	55                   	push   %ebp
f01014dc:	89 e5                	mov    %esp,%ebp
f01014de:	57                   	push   %edi
f01014df:	56                   	push   %esi
f01014e0:	53                   	push   %ebx
f01014e1:	8b 7d 08             	mov    0x8(%ebp),%edi
f01014e4:	8b 75 0c             	mov    0xc(%ebp),%esi
f01014e7:	8b 5d 10             	mov    0x10(%ebp),%ebx
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01014ea:	ba 00 00 00 00       	mov    $0x0,%edx
f01014ef:	eb 16                	jmp    f0101507 <memcmp+0x2c>
		if (*s1 != *s2)
f01014f1:	8a 04 17             	mov    (%edi,%edx,1),%al
f01014f4:	42                   	inc    %edx
f01014f5:	8a 4c 16 ff          	mov    -0x1(%esi,%edx,1),%cl
f01014f9:	38 c8                	cmp    %cl,%al
f01014fb:	74 0a                	je     f0101507 <memcmp+0x2c>
			return (int) *s1 - (int) *s2;
f01014fd:	0f b6 c0             	movzbl %al,%eax
f0101500:	0f b6 c9             	movzbl %cl,%ecx
f0101503:	29 c8                	sub    %ecx,%eax
f0101505:	eb 09                	jmp    f0101510 <memcmp+0x35>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0101507:	39 da                	cmp    %ebx,%edx
f0101509:	75 e6                	jne    f01014f1 <memcmp+0x16>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f010150b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101510:	5b                   	pop    %ebx
f0101511:	5e                   	pop    %esi
f0101512:	5f                   	pop    %edi
f0101513:	5d                   	pop    %ebp
f0101514:	c3                   	ret    

f0101515 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0101515:	55                   	push   %ebp
f0101516:	89 e5                	mov    %esp,%ebp
f0101518:	8b 45 08             	mov    0x8(%ebp),%eax
f010151b:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	const void *ends = (const char *) s + n;
f010151e:	89 c2                	mov    %eax,%edx
f0101520:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0101523:	eb 05                	jmp    f010152a <memfind+0x15>
		if (*(const unsigned char *) s == (unsigned char) c)
f0101525:	38 08                	cmp    %cl,(%eax)
f0101527:	74 05                	je     f010152e <memfind+0x19>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0101529:	40                   	inc    %eax
f010152a:	39 d0                	cmp    %edx,%eax
f010152c:	72 f7                	jb     f0101525 <memfind+0x10>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010152e:	5d                   	pop    %ebp
f010152f:	c3                   	ret    

f0101530 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101530:	55                   	push   %ebp
f0101531:	89 e5                	mov    %esp,%ebp
f0101533:	57                   	push   %edi
f0101534:	56                   	push   %esi
f0101535:	53                   	push   %ebx
f0101536:	8b 55 08             	mov    0x8(%ebp),%edx
f0101539:	8b 5d 10             	mov    0x10(%ebp),%ebx
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010153c:	eb 01                	jmp    f010153f <strtol+0xf>
		s++;
f010153e:	42                   	inc    %edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010153f:	8a 02                	mov    (%edx),%al
f0101541:	3c 20                	cmp    $0x20,%al
f0101543:	74 f9                	je     f010153e <strtol+0xe>
f0101545:	3c 09                	cmp    $0x9,%al
f0101547:	74 f5                	je     f010153e <strtol+0xe>
		s++;

	// plus/minus sign
	if (*s == '+')
f0101549:	3c 2b                	cmp    $0x2b,%al
f010154b:	75 08                	jne    f0101555 <strtol+0x25>
		s++;
f010154d:	42                   	inc    %edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010154e:	bf 00 00 00 00       	mov    $0x0,%edi
f0101553:	eb 13                	jmp    f0101568 <strtol+0x38>
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101555:	3c 2d                	cmp    $0x2d,%al
f0101557:	75 0a                	jne    f0101563 <strtol+0x33>
		s++, neg = 1;
f0101559:	8d 52 01             	lea    0x1(%edx),%edx
f010155c:	bf 01 00 00 00       	mov    $0x1,%edi
f0101561:	eb 05                	jmp    f0101568 <strtol+0x38>
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101563:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;
	else if (*s == '-')
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0101568:	85 db                	test   %ebx,%ebx
f010156a:	74 05                	je     f0101571 <strtol+0x41>
f010156c:	83 fb 10             	cmp    $0x10,%ebx
f010156f:	75 28                	jne    f0101599 <strtol+0x69>
f0101571:	8a 02                	mov    (%edx),%al
f0101573:	3c 30                	cmp    $0x30,%al
f0101575:	75 10                	jne    f0101587 <strtol+0x57>
f0101577:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f010157b:	75 0a                	jne    f0101587 <strtol+0x57>
		s += 2, base = 16;
f010157d:	83 c2 02             	add    $0x2,%edx
f0101580:	bb 10 00 00 00       	mov    $0x10,%ebx
f0101585:	eb 12                	jmp    f0101599 <strtol+0x69>
	else if (base == 0 && s[0] == '0')
f0101587:	85 db                	test   %ebx,%ebx
f0101589:	75 0e                	jne    f0101599 <strtol+0x69>
f010158b:	3c 30                	cmp    $0x30,%al
f010158d:	75 05                	jne    f0101594 <strtol+0x64>
		s++, base = 8;
f010158f:	42                   	inc    %edx
f0101590:	b3 08                	mov    $0x8,%bl
f0101592:	eb 05                	jmp    f0101599 <strtol+0x69>
	else if (base == 0)
		base = 10;
f0101594:	bb 0a 00 00 00       	mov    $0xa,%ebx
f0101599:	b8 00 00 00 00       	mov    $0x0,%eax
f010159e:	89 de                	mov    %ebx,%esi

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01015a0:	8a 0a                	mov    (%edx),%cl
f01015a2:	8d 59 d0             	lea    -0x30(%ecx),%ebx
f01015a5:	80 fb 09             	cmp    $0x9,%bl
f01015a8:	77 08                	ja     f01015b2 <strtol+0x82>
			dig = *s - '0';
f01015aa:	0f be c9             	movsbl %cl,%ecx
f01015ad:	83 e9 30             	sub    $0x30,%ecx
f01015b0:	eb 1e                	jmp    f01015d0 <strtol+0xa0>
		else if (*s >= 'a' && *s <= 'z')
f01015b2:	8d 59 9f             	lea    -0x61(%ecx),%ebx
f01015b5:	80 fb 19             	cmp    $0x19,%bl
f01015b8:	77 08                	ja     f01015c2 <strtol+0x92>
			dig = *s - 'a' + 10;
f01015ba:	0f be c9             	movsbl %cl,%ecx
f01015bd:	83 e9 57             	sub    $0x57,%ecx
f01015c0:	eb 0e                	jmp    f01015d0 <strtol+0xa0>
		else if (*s >= 'A' && *s <= 'Z')
f01015c2:	8d 59 bf             	lea    -0x41(%ecx),%ebx
f01015c5:	80 fb 19             	cmp    $0x19,%bl
f01015c8:	77 12                	ja     f01015dc <strtol+0xac>
			dig = *s - 'A' + 10;
f01015ca:	0f be c9             	movsbl %cl,%ecx
f01015cd:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01015d0:	39 f1                	cmp    %esi,%ecx
f01015d2:	7d 0c                	jge    f01015e0 <strtol+0xb0>
			break;
		s++, val = (val * base) + dig;
f01015d4:	42                   	inc    %edx
f01015d5:	0f af c6             	imul   %esi,%eax
f01015d8:	01 c8                	add    %ecx,%eax
		// we don't properly detect overflow!
	}
f01015da:	eb c4                	jmp    f01015a0 <strtol+0x70>

		if (*s >= '0' && *s <= '9')
			dig = *s - '0';
		else if (*s >= 'a' && *s <= 'z')
			dig = *s - 'a' + 10;
		else if (*s >= 'A' && *s <= 'Z')
f01015dc:	89 c1                	mov    %eax,%ecx
f01015de:	eb 02                	jmp    f01015e2 <strtol+0xb2>
			dig = *s - 'A' + 10;
		else
			break;
		if (dig >= base)
f01015e0:	89 c1                	mov    %eax,%ecx
			break;
		s++, val = (val * base) + dig;
		// we don't properly detect overflow!
	}

	if (endptr)
f01015e2:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01015e6:	74 05                	je     f01015ed <strtol+0xbd>
		*endptr = (char *) s;
f01015e8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01015eb:	89 13                	mov    %edx,(%ebx)
	return (neg ? -val : val);
f01015ed:	85 ff                	test   %edi,%edi
f01015ef:	74 04                	je     f01015f5 <strtol+0xc5>
f01015f1:	89 c8                	mov    %ecx,%eax
f01015f3:	f7 d8                	neg    %eax
}
f01015f5:	5b                   	pop    %ebx
f01015f6:	5e                   	pop    %esi
f01015f7:	5f                   	pop    %edi
f01015f8:	5d                   	pop    %ebp
f01015f9:	c3                   	ret    
	...

f01015fc <__udivdi3>:
#endif

#ifdef L_udivdi3
UDWtype
__udivdi3 (UDWtype n, UDWtype d)
{
f01015fc:	55                   	push   %ebp
f01015fd:	57                   	push   %edi
f01015fe:	56                   	push   %esi
f01015ff:	83 ec 10             	sub    $0x10,%esp
f0101602:	8b 74 24 20          	mov    0x20(%esp),%esi
f0101606:	8b 4c 24 28          	mov    0x28(%esp),%ecx
static inline __attribute__ ((__always_inline__))
#endif
UDWtype
__udivmoddi4 (UDWtype n, UDWtype d, UDWtype *rp)
{
  const DWunion nn = {.ll = n};
f010160a:	89 74 24 04          	mov    %esi,0x4(%esp)
f010160e:	8b 7c 24 24          	mov    0x24(%esp),%edi
  const DWunion dd = {.ll = d};
f0101612:	89 cd                	mov    %ecx,%ebp
f0101614:	8b 44 24 2c          	mov    0x2c(%esp),%eax
  d1 = dd.s.high;
  n0 = nn.s.low;
  n1 = nn.s.high;

#if !UDIV_NEEDS_NORMALIZATION
  if (d1 == 0)
f0101618:	85 c0                	test   %eax,%eax
f010161a:	75 2c                	jne    f0101648 <__udivdi3+0x4c>
    {
      if (d0 > n1)
f010161c:	39 f9                	cmp    %edi,%ecx
f010161e:	77 68                	ja     f0101688 <__udivdi3+0x8c>
	}
      else
	{
	  /* qq = NN / 0d */

	  if (d0 == 0)
f0101620:	85 c9                	test   %ecx,%ecx
f0101622:	75 0b                	jne    f010162f <__udivdi3+0x33>
	    d0 = 1 / d0;	/* Divide intentionally by zero.  */
f0101624:	b8 01 00 00 00       	mov    $0x1,%eax
f0101629:	31 d2                	xor    %edx,%edx
f010162b:	f7 f1                	div    %ecx
f010162d:	89 c1                	mov    %eax,%ecx

	  udiv_qrnnd (q1, n1, 0, n1, d0);
f010162f:	31 d2                	xor    %edx,%edx
f0101631:	89 f8                	mov    %edi,%eax
f0101633:	f7 f1                	div    %ecx
f0101635:	89 c7                	mov    %eax,%edi
	  udiv_qrnnd (q0, n0, n1, n0, d0);
f0101637:	89 f0                	mov    %esi,%eax
f0101639:	f7 f1                	div    %ecx
f010163b:	89 c6                	mov    %eax,%esi
		}
	    }
	}
    }

  const DWunion ww = {{.low = q0, .high = q1}};
f010163d:	89 f0                	mov    %esi,%eax
f010163f:	89 fa                	mov    %edi,%edx
#ifdef L_udivdi3
UDWtype
__udivdi3 (UDWtype n, UDWtype d)
{
  return __udivmoddi4 (n, d, (UDWtype *) 0);
}
f0101641:	83 c4 10             	add    $0x10,%esp
f0101644:	5e                   	pop    %esi
f0101645:	5f                   	pop    %edi
f0101646:	5d                   	pop    %ebp
f0101647:	c3                   	ret    
    }
#endif /* UDIV_NEEDS_NORMALIZATION */

  else
    {
      if (d1 > n1)
f0101648:	39 f8                	cmp    %edi,%eax
f010164a:	77 2c                	ja     f0101678 <__udivdi3+0x7c>
	}
      else
	{
	  /* 0q = NN / dd */

	  count_leading_zeros (bm, d1);
f010164c:	0f bd f0             	bsr    %eax,%esi
	  if (bm == 0)
f010164f:	83 f6 1f             	xor    $0x1f,%esi
f0101652:	75 4c                	jne    f01016a0 <__udivdi3+0xa4>

		 This special case is necessary, not an optimization.  */

	      /* The condition on the next line takes advantage of that
		 n1 >= d1 (true due to program flow).  */
	      if (n1 > d1 || n0 >= d0)
f0101654:	39 f8                	cmp    %edi,%eax
		{
		  q0 = 1;
		  sub_ddmmss (n1, n0, n1, n0, d1, d0);
f0101656:	bf 00 00 00 00       	mov    $0x0,%edi

		 This special case is necessary, not an optimization.  */

	      /* The condition on the next line takes advantage of that
		 n1 >= d1 (true due to program flow).  */
	      if (n1 > d1 || n0 >= d0)
f010165b:	72 0a                	jb     f0101667 <__udivdi3+0x6b>
f010165d:	3b 4c 24 04          	cmp    0x4(%esp),%ecx
f0101661:	0f 87 ad 00 00 00    	ja     f0101714 <__udivdi3+0x118>
		{
		  q0 = 1;
		  sub_ddmmss (n1, n0, n1, n0, d1, d0);
f0101667:	be 01 00 00 00       	mov    $0x1,%esi
		}
	    }
	}
    }

  const DWunion ww = {{.low = q0, .high = q1}};
f010166c:	89 f0                	mov    %esi,%eax
f010166e:	89 fa                	mov    %edi,%edx
#ifdef L_udivdi3
UDWtype
__udivdi3 (UDWtype n, UDWtype d)
{
  return __udivmoddi4 (n, d, (UDWtype *) 0);
}
f0101670:	83 c4 10             	add    $0x10,%esp
f0101673:	5e                   	pop    %esi
f0101674:	5f                   	pop    %edi
f0101675:	5d                   	pop    %ebp
f0101676:	c3                   	ret    
f0101677:	90                   	nop
    }
#endif /* UDIV_NEEDS_NORMALIZATION */

  else
    {
      if (d1 > n1)
f0101678:	31 ff                	xor    %edi,%edi
f010167a:	31 f6                	xor    %esi,%esi
		}
	    }
	}
    }

  const DWunion ww = {{.low = q0, .high = q1}};
f010167c:	89 f0                	mov    %esi,%eax
f010167e:	89 fa                	mov    %edi,%edx
#ifdef L_udivdi3
UDWtype
__udivdi3 (UDWtype n, UDWtype d)
{
  return __udivmoddi4 (n, d, (UDWtype *) 0);
}
f0101680:	83 c4 10             	add    $0x10,%esp
f0101683:	5e                   	pop    %esi
f0101684:	5f                   	pop    %edi
f0101685:	5d                   	pop    %ebp
f0101686:	c3                   	ret    
f0101687:	90                   	nop
    {
      if (d0 > n1)
	{
	  /* 0q = nn / 0D */

	  udiv_qrnnd (q0, n0, n1, n0, d0);
f0101688:	89 fa                	mov    %edi,%edx
f010168a:	89 f0                	mov    %esi,%eax
f010168c:	f7 f1                	div    %ecx
f010168e:	89 c6                	mov    %eax,%esi
f0101690:	31 ff                	xor    %edi,%edi
		}
	    }
	}
    }

  const DWunion ww = {{.low = q0, .high = q1}};
f0101692:	89 f0                	mov    %esi,%eax
f0101694:	89 fa                	mov    %edi,%edx
#ifdef L_udivdi3
UDWtype
__udivdi3 (UDWtype n, UDWtype d)
{
  return __udivmoddi4 (n, d, (UDWtype *) 0);
}
f0101696:	83 c4 10             	add    $0x10,%esp
f0101699:	5e                   	pop    %esi
f010169a:	5f                   	pop    %edi
f010169b:	5d                   	pop    %ebp
f010169c:	c3                   	ret    
f010169d:	8d 76 00             	lea    0x0(%esi),%esi
	      UWtype m1, m0;
	      /* Normalize.  */

	      b = W_TYPE_SIZE - bm;

	      d1 = (d1 << bm) | (d0 >> b);
f01016a0:	89 f1                	mov    %esi,%ecx
f01016a2:	d3 e0                	shl    %cl,%eax
f01016a4:	89 44 24 0c          	mov    %eax,0xc(%esp)
	  else
	    {
	      UWtype m1, m0;
	      /* Normalize.  */

	      b = W_TYPE_SIZE - bm;
f01016a8:	b8 20 00 00 00       	mov    $0x20,%eax
f01016ad:	29 f0                	sub    %esi,%eax

	      d1 = (d1 << bm) | (d0 >> b);
f01016af:	89 ea                	mov    %ebp,%edx
f01016b1:	88 c1                	mov    %al,%cl
f01016b3:	d3 ea                	shr    %cl,%edx
f01016b5:	8b 4c 24 0c          	mov    0xc(%esp),%ecx
f01016b9:	09 ca                	or     %ecx,%edx
f01016bb:	89 54 24 08          	mov    %edx,0x8(%esp)
	      d0 = d0 << bm;
f01016bf:	89 f1                	mov    %esi,%ecx
f01016c1:	d3 e5                	shl    %cl,%ebp
f01016c3:	89 6c 24 0c          	mov    %ebp,0xc(%esp)
	      n2 = n1 >> b;
f01016c7:	89 fd                	mov    %edi,%ebp
f01016c9:	88 c1                	mov    %al,%cl
f01016cb:	d3 ed                	shr    %cl,%ebp
	      n1 = (n1 << bm) | (n0 >> b);
f01016cd:	89 fa                	mov    %edi,%edx
f01016cf:	89 f1                	mov    %esi,%ecx
f01016d1:	d3 e2                	shl    %cl,%edx
f01016d3:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01016d7:	88 c1                	mov    %al,%cl
f01016d9:	d3 ef                	shr    %cl,%edi
f01016db:	09 d7                	or     %edx,%edi
	      n0 = n0 << bm;

	      udiv_qrnnd (q0, n1, n2, n1, d1);
f01016dd:	89 f8                	mov    %edi,%eax
f01016df:	89 ea                	mov    %ebp,%edx
f01016e1:	f7 74 24 08          	divl   0x8(%esp)
f01016e5:	89 d1                	mov    %edx,%ecx
f01016e7:	89 c7                	mov    %eax,%edi
	      umul_ppmm (m1, m0, q0, d0);
f01016e9:	f7 64 24 0c          	mull   0xc(%esp)

	      if (m1 > n1 || (m1 == n1 && m0 > n0))
f01016ed:	39 d1                	cmp    %edx,%ecx
f01016ef:	72 17                	jb     f0101708 <__udivdi3+0x10c>
f01016f1:	74 09                	je     f01016fc <__udivdi3+0x100>
f01016f3:	89 fe                	mov    %edi,%esi
f01016f5:	31 ff                	xor    %edi,%edi
f01016f7:	e9 41 ff ff ff       	jmp    f010163d <__udivdi3+0x41>

	      d1 = (d1 << bm) | (d0 >> b);
	      d0 = d0 << bm;
	      n2 = n1 >> b;
	      n1 = (n1 << bm) | (n0 >> b);
	      n0 = n0 << bm;
f01016fc:	8b 54 24 04          	mov    0x4(%esp),%edx
f0101700:	89 f1                	mov    %esi,%ecx
f0101702:	d3 e2                	shl    %cl,%edx

	      udiv_qrnnd (q0, n1, n2, n1, d1);
	      umul_ppmm (m1, m0, q0, d0);

	      if (m1 > n1 || (m1 == n1 && m0 > n0))
f0101704:	39 c2                	cmp    %eax,%edx
f0101706:	73 eb                	jae    f01016f3 <__udivdi3+0xf7>
		{
		  q0--;
f0101708:	8d 77 ff             	lea    -0x1(%edi),%esi
		  sub_ddmmss (m1, m0, m1, m0, d1, d0);
f010170b:	31 ff                	xor    %edi,%edi
f010170d:	e9 2b ff ff ff       	jmp    f010163d <__udivdi3+0x41>
f0101712:	66 90                	xchg   %ax,%ax

		 This special case is necessary, not an optimization.  */

	      /* The condition on the next line takes advantage of that
		 n1 >= d1 (true due to program flow).  */
	      if (n1 > d1 || n0 >= d0)
f0101714:	31 f6                	xor    %esi,%esi
f0101716:	e9 22 ff ff ff       	jmp    f010163d <__udivdi3+0x41>
	...

f010171c <__umoddi3>:
#endif

#ifdef L_umoddi3
UDWtype
__umoddi3 (UDWtype u, UDWtype v)
{
f010171c:	55                   	push   %ebp
f010171d:	57                   	push   %edi
f010171e:	56                   	push   %esi
f010171f:	83 ec 20             	sub    $0x20,%esp
f0101722:	8b 44 24 30          	mov    0x30(%esp),%eax
f0101726:	8b 4c 24 38          	mov    0x38(%esp),%ecx
static inline __attribute__ ((__always_inline__))
#endif
UDWtype
__udivmoddi4 (UDWtype n, UDWtype d, UDWtype *rp)
{
  const DWunion nn = {.ll = n};
f010172a:	89 44 24 14          	mov    %eax,0x14(%esp)
f010172e:	8b 74 24 34          	mov    0x34(%esp),%esi
  const DWunion dd = {.ll = d};
f0101732:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101736:	8b 6c 24 3c          	mov    0x3c(%esp),%ebp
  UWtype q0, q1;
  UWtype b, bm;

  d0 = dd.s.low;
  d1 = dd.s.high;
  n0 = nn.s.low;
f010173a:	89 c7                	mov    %eax,%edi
  n1 = nn.s.high;
f010173c:	89 f2                	mov    %esi,%edx

#if !UDIV_NEEDS_NORMALIZATION
  if (d1 == 0)
f010173e:	85 ed                	test   %ebp,%ebp
f0101740:	75 16                	jne    f0101758 <__umoddi3+0x3c>
    {
      if (d0 > n1)
f0101742:	39 f1                	cmp    %esi,%ecx
f0101744:	0f 86 a6 00 00 00    	jbe    f01017f0 <__umoddi3+0xd4>

	  if (d0 == 0)
	    d0 = 1 / d0;	/* Divide intentionally by zero.  */

	  udiv_qrnnd (q1, n1, 0, n1, d0);
	  udiv_qrnnd (q0, n0, n1, n0, d0);
f010174a:	f7 f1                	div    %ecx

      if (rp != 0)
	{
	  rr.s.low = n0;
	  rr.s.high = 0;
	  *rp = rr.ll;
f010174c:	89 d0                	mov    %edx,%eax
f010174e:	31 d2                	xor    %edx,%edx
  UDWtype w;

  (void) __udivmoddi4 (u, v, &w);

  return w;
}
f0101750:	83 c4 20             	add    $0x20,%esp
f0101753:	5e                   	pop    %esi
f0101754:	5f                   	pop    %edi
f0101755:	5d                   	pop    %ebp
f0101756:	c3                   	ret    
f0101757:	90                   	nop
    }
#endif /* UDIV_NEEDS_NORMALIZATION */

  else
    {
      if (d1 > n1)
f0101758:	39 f5                	cmp    %esi,%ebp
f010175a:	0f 87 ac 00 00 00    	ja     f010180c <__umoddi3+0xf0>
	}
      else
	{
	  /* 0q = NN / dd */

	  count_leading_zeros (bm, d1);
f0101760:	0f bd c5             	bsr    %ebp,%eax
	  if (bm == 0)
f0101763:	83 f0 1f             	xor    $0x1f,%eax
f0101766:	89 44 24 10          	mov    %eax,0x10(%esp)
f010176a:	0f 84 a8 00 00 00    	je     f0101818 <__umoddi3+0xfc>
	      UWtype m1, m0;
	      /* Normalize.  */

	      b = W_TYPE_SIZE - bm;

	      d1 = (d1 << bm) | (d0 >> b);
f0101770:	8a 4c 24 10          	mov    0x10(%esp),%cl
f0101774:	d3 e5                	shl    %cl,%ebp
	  else
	    {
	      UWtype m1, m0;
	      /* Normalize.  */

	      b = W_TYPE_SIZE - bm;
f0101776:	bf 20 00 00 00       	mov    $0x20,%edi
f010177b:	2b 7c 24 10          	sub    0x10(%esp),%edi

	      d1 = (d1 << bm) | (d0 >> b);
f010177f:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101783:	89 f9                	mov    %edi,%ecx
f0101785:	d3 e8                	shr    %cl,%eax
f0101787:	09 e8                	or     %ebp,%eax
f0101789:	89 44 24 18          	mov    %eax,0x18(%esp)
	      d0 = d0 << bm;
f010178d:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101791:	8a 4c 24 10          	mov    0x10(%esp),%cl
f0101795:	d3 e0                	shl    %cl,%eax
f0101797:	89 44 24 0c          	mov    %eax,0xc(%esp)
	      n2 = n1 >> b;
	      n1 = (n1 << bm) | (n0 >> b);
f010179b:	89 f2                	mov    %esi,%edx
f010179d:	d3 e2                	shl    %cl,%edx
	      n0 = n0 << bm;
f010179f:	8b 44 24 14          	mov    0x14(%esp),%eax
f01017a3:	d3 e0                	shl    %cl,%eax
f01017a5:	89 44 24 1c          	mov    %eax,0x1c(%esp)
	      b = W_TYPE_SIZE - bm;

	      d1 = (d1 << bm) | (d0 >> b);
	      d0 = d0 << bm;
	      n2 = n1 >> b;
	      n1 = (n1 << bm) | (n0 >> b);
f01017a9:	8b 44 24 14          	mov    0x14(%esp),%eax
f01017ad:	89 f9                	mov    %edi,%ecx
f01017af:	d3 e8                	shr    %cl,%eax
f01017b1:	09 d0                	or     %edx,%eax

	      b = W_TYPE_SIZE - bm;

	      d1 = (d1 << bm) | (d0 >> b);
	      d0 = d0 << bm;
	      n2 = n1 >> b;
f01017b3:	d3 ee                	shr    %cl,%esi
	      n1 = (n1 << bm) | (n0 >> b);
	      n0 = n0 << bm;

	      udiv_qrnnd (q0, n1, n2, n1, d1);
f01017b5:	89 f2                	mov    %esi,%edx
f01017b7:	f7 74 24 18          	divl   0x18(%esp)
f01017bb:	89 d6                	mov    %edx,%esi
	      umul_ppmm (m1, m0, q0, d0);
f01017bd:	f7 64 24 0c          	mull   0xc(%esp)
f01017c1:	89 c5                	mov    %eax,%ebp
f01017c3:	89 d1                	mov    %edx,%ecx

	      if (m1 > n1 || (m1 == n1 && m0 > n0))
f01017c5:	39 d6                	cmp    %edx,%esi
f01017c7:	72 67                	jb     f0101830 <__umoddi3+0x114>
f01017c9:	74 75                	je     f0101840 <__umoddi3+0x124>
	      q1 = 0;

	      /* Remainder in (n1n0 - m1m0) >> bm.  */
	      if (rp != 0)
		{
		  sub_ddmmss (n1, n0, n1, n0, m1, m0);
f01017cb:	8b 44 24 1c          	mov    0x1c(%esp),%eax
f01017cf:	29 e8                	sub    %ebp,%eax
f01017d1:	19 ce                	sbb    %ecx,%esi
		  rr.s.low = (n1 << b) | (n0 >> bm);
f01017d3:	8a 4c 24 10          	mov    0x10(%esp),%cl
f01017d7:	d3 e8                	shr    %cl,%eax
f01017d9:	89 f2                	mov    %esi,%edx
f01017db:	89 f9                	mov    %edi,%ecx
f01017dd:	d3 e2                	shl    %cl,%edx
		  rr.s.high = n1 >> bm;
		  *rp = rr.ll;
f01017df:	09 d0                	or     %edx,%eax
f01017e1:	89 f2                	mov    %esi,%edx
f01017e3:	8a 4c 24 10          	mov    0x10(%esp),%cl
f01017e7:	d3 ea                	shr    %cl,%edx
  UDWtype w;

  (void) __udivmoddi4 (u, v, &w);

  return w;
}
f01017e9:	83 c4 20             	add    $0x20,%esp
f01017ec:	5e                   	pop    %esi
f01017ed:	5f                   	pop    %edi
f01017ee:	5d                   	pop    %ebp
f01017ef:	c3                   	ret    
	}
      else
	{
	  /* qq = NN / 0d */

	  if (d0 == 0)
f01017f0:	85 c9                	test   %ecx,%ecx
f01017f2:	75 0b                	jne    f01017ff <__umoddi3+0xe3>
	    d0 = 1 / d0;	/* Divide intentionally by zero.  */
f01017f4:	b8 01 00 00 00       	mov    $0x1,%eax
f01017f9:	31 d2                	xor    %edx,%edx
f01017fb:	f7 f1                	div    %ecx
f01017fd:	89 c1                	mov    %eax,%ecx

	  udiv_qrnnd (q1, n1, 0, n1, d0);
f01017ff:	89 f0                	mov    %esi,%eax
f0101801:	31 d2                	xor    %edx,%edx
f0101803:	f7 f1                	div    %ecx
	  udiv_qrnnd (q0, n0, n1, n0, d0);
f0101805:	89 f8                	mov    %edi,%eax
f0101807:	e9 3e ff ff ff       	jmp    f010174a <__umoddi3+0x2e>
	  /* Remainder in n1n0.  */
	  if (rp != 0)
	    {
	      rr.s.low = n0;
	      rr.s.high = n1;
	      *rp = rr.ll;
f010180c:	89 f2                	mov    %esi,%edx
  UDWtype w;

  (void) __udivmoddi4 (u, v, &w);

  return w;
}
f010180e:	83 c4 20             	add    $0x20,%esp
f0101811:	5e                   	pop    %esi
f0101812:	5f                   	pop    %edi
f0101813:	5d                   	pop    %ebp
f0101814:	c3                   	ret    
f0101815:	8d 76 00             	lea    0x0(%esi),%esi

		 This special case is necessary, not an optimization.  */

	      /* The condition on the next line takes advantage of that
		 n1 >= d1 (true due to program flow).  */
	      if (n1 > d1 || n0 >= d0)
f0101818:	39 f5                	cmp    %esi,%ebp
f010181a:	72 04                	jb     f0101820 <__umoddi3+0x104>
f010181c:	39 f9                	cmp    %edi,%ecx
f010181e:	77 06                	ja     f0101826 <__umoddi3+0x10a>
		{
		  q0 = 1;
		  sub_ddmmss (n1, n0, n1, n0, d1, d0);
f0101820:	89 f2                	mov    %esi,%edx
f0101822:	29 cf                	sub    %ecx,%edi
f0101824:	19 ea                	sbb    %ebp,%edx

	      if (rp != 0)
		{
		  rr.s.low = n0;
		  rr.s.high = n1;
		  *rp = rr.ll;
f0101826:	89 f8                	mov    %edi,%eax
  UDWtype w;

  (void) __udivmoddi4 (u, v, &w);

  return w;
}
f0101828:	83 c4 20             	add    $0x20,%esp
f010182b:	5e                   	pop    %esi
f010182c:	5f                   	pop    %edi
f010182d:	5d                   	pop    %ebp
f010182e:	c3                   	ret    
f010182f:	90                   	nop
	      umul_ppmm (m1, m0, q0, d0);

	      if (m1 > n1 || (m1 == n1 && m0 > n0))
		{
		  q0--;
		  sub_ddmmss (m1, m0, m1, m0, d1, d0);
f0101830:	89 d1                	mov    %edx,%ecx
f0101832:	89 c5                	mov    %eax,%ebp
f0101834:	2b 6c 24 0c          	sub    0xc(%esp),%ebp
f0101838:	1b 4c 24 18          	sbb    0x18(%esp),%ecx
f010183c:	eb 8d                	jmp    f01017cb <__umoddi3+0xaf>
f010183e:	66 90                	xchg   %ax,%ax
	      n0 = n0 << bm;

	      udiv_qrnnd (q0, n1, n2, n1, d1);
	      umul_ppmm (m1, m0, q0, d0);

	      if (m1 > n1 || (m1 == n1 && m0 > n0))
f0101840:	39 44 24 1c          	cmp    %eax,0x1c(%esp)
f0101844:	72 ea                	jb     f0101830 <__umoddi3+0x114>
f0101846:	89 f1                	mov    %esi,%ecx
f0101848:	eb 81                	jmp    f01017cb <__umoddi3+0xaf>
