
obj/boot/boot.out:     file format elf32-i386


Disassembly of section .text:

00007c00 <start>:
.set CR0_PE_ON,      0x1         # protected mode enable flag 这个变量是开启A20地址线的标志，为1是开启保护模式

.globl start
start:
  .code16                     # Assemble for 16-bit mode
  cli                         # Disable interrupts 关中断
    7c00:	fa                   	cli    
  cld                         # String operations increment 将direct flag标志位清零，这意味着自动增加源索引和目标索引的指令(如MOVS)将同时增加它们
    7c01:	fc                   	cld    

  # Set up the important data segment registers (DS, ES, SS). 相当于全部置0
  xorw    %ax,%ax             # Segment number zero
    7c02:	31 c0                	xor    %eax,%eax
  movw    %ax,%ds             # -> Data Segment
    7c04:	8e d8                	mov    %eax,%ds
  movw    %ax,%es             # -> Extra Segment
    7c06:	8e c0                	mov    %eax,%es
  movw    %ax,%ss             # -> Stack Segment
    7c08:	8e d0                	mov    %eax,%ss

00007c0a <seta20.1>:
  #   1MB wrap around to zero by default.  This code undoes this.
  #   由于历史原因A20地址位由键盘控制器芯片8042管理。所以要给8042发命令激活A20
  #   8042有两个IO端口：0x60和0x64， 激活流程位： 发送0xd1命令到0x64端口 --> 发送0xdf到0x60

seta20.1:
  inb     $0x64,%al               # Wait for not busy 从0x64读取8位并传到a寄存器的低8位
    7c0a:	e4 64                	in     $0x64,%al
  testb   $0x2,%al                # 进行与运算，但不会改变a寄存器的值，只会改变标志位，发送命令之前，要等待键盘输入缓冲区为空，这通过8042的状态寄存器的第2bit来观察
    7c0c:	a8 02                	test   $0x2,%al
  jnz     seta20.1                # ZF标志位不为0时跳转，如果状态寄存器的第2位为1，就跳到seta20.1符号处执行，知道第2位为0，代表缓冲区为空
    7c0e:	75 fa                	jne    7c0a <seta20.1>

  movb    $0xd1,%al               # 0xd1 -> port 0x64
    7c10:	b0 d1                	mov    $0xd1,%al
  outb    %al,$0x64               # 发送0xd1到0x64端口
    7c12:	e6 64                	out    %al,$0x64

00007c14 <seta20.2>:

seta20.2:
  inb     $0x64,%al               # Wait for not busy
    7c14:	e4 64                	in     $0x64,%al
  testb   $0x2,%al
    7c16:	a8 02                	test   $0x2,%al
  jnz     seta20.2
    7c18:	75 fa                	jne    7c14 <seta20.2>

  movb    $0xdf,%al               # 0xdf -> port 0x60
    7c1a:	b0 df                	mov    $0xdf,%al
  outb    %al,$0x60               # 与上述相似，发送0xdf到0x60端口
    7c1c:	e6 60                	out    %al,$0x60
  # and segment translation that makes virtual addresses 
  # identical to their physical addresses, so that the 
  # effective memory map does not change during the switch.
  # A20激活完成，转入保护模式

  lgdt    gdtdesc                 # lgdt命令加载全局描述符，指定一个临时的GDT，来翻译逻辑地址。这里使用的GDT通过gdtdesc段定义。它翻译得到的物理地址和虚拟地址相同，所以转换过程中内存映射不会改变
    7c1e:	0f 01 16             	lgdtl  (%esi)
    7c21:	64                   	fs
    7c22:	7c 0f                	jl     7c33 <protcseg+0x1>

  # 打开保护模式标志位，相当于按下了保护模式的开关。cr0寄存器的第0位就是这个开关，通过CR0_PE_ON或cr0寄存器，将第0位置1
  movl    %cr0, %eax
    7c24:	20 c0                	and    %al,%al
  orl     $CR0_PE_ON, %eax        # 或运算
    7c26:	66 83 c8 01          	or     $0x1,%ax
  movl    %eax, %cr0
    7c2a:	0f 22 c0             	mov    %eax,%cr0
  
  # Jump to next instruction, but in 32-bit code segment.
  # Switches processor into 32-bit mode.
  ljmp    $PROT_MODE_CSEG, $protcseg  # PROT_MODE_CSEG是0x8，选择子选择了GDT中的第1个段描述符，即保护模式下跳转到代码段（详细见下图）
    7c2d:	ea 32 7c 08 00 66 b8 	ljmp   $0xb866,$0x87c32

00007c32 <protcseg>:

  .code32                     # Assemble for 32-bit mode
protcseg:
  # Set up the protected-mode data segment registers 重新初始化各个段寄存器
  movw    $PROT_MODE_DSEG, %ax    # Our data segment selector
    7c32:	66 b8 10 00          	mov    $0x10,%ax
  movw    %ax, %ds                # -> DS: Data Segment
    7c36:	8e d8                	mov    %eax,%ds
  movw    %ax, %es                # -> ES: Extra Segment
    7c38:	8e c0                	mov    %eax,%es
  movw    %ax, %fs                # -> FS
    7c3a:	8e e0                	mov    %eax,%fs
  movw    %ax, %gs                # -> GS
    7c3c:	8e e8                	mov    %eax,%gs
  movw    %ax, %ss                # -> SS: Stack Segment
    7c3e:	8e d0                	mov    %eax,%ss
  
  # Set up the stack pointer and call into C.
  movl    $start, %esp            # 栈顶设定在start处，也就是地址0x7c00处
    7c40:	bc 00 7c 00 00       	mov    $0x7c00,%esp
  call bootmain                   # call函数将返回地址入栈，将控制权交给bootmain
    7c45:	e8 c1 00 00 00       	call   7d0b <bootmain>

00007c4a <spin>:

  # If bootmain returns (it shouldn't), loop.
spin:
  jmp spin
    7c4a:	eb fe                	jmp    7c4a <spin>

00007c4c <gdt>:
	...
    7c54:	ff                   	(bad)  
    7c55:	ff 00                	incl   (%eax)
    7c57:	00 00                	add    %al,(%eax)
    7c59:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
    7c60:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

00007c64 <gdtdesc>:
    7c64:	17                   	pop    %ss
    7c65:	00 4c 7c 00          	add    %cl,0x0(%esp,%edi,2)
    7c69:	00 90 90 55 89 e5    	add    %dl,-0x1a76aa70(%eax)

00007c6c <waitdisk>:
	}
}

void
waitdisk(void)
{
    7c6c:	55                   	push   %ebp
    7c6d:	89 e5                	mov    %esp,%ebp

static inline uint8_t
inb(int port)
{
	uint8_t data;
	asm volatile("inb %w1,%0" : "=a" (data) : "d" (port));
    7c6f:	ba f7 01 00 00       	mov    $0x1f7,%edx
    7c74:	ec                   	in     (%dx),%al
	// wait for disk reaady
	while ((inb(0x1F7) & 0xC0) != 0x40)
    7c75:	25 c0 00 00 00       	and    $0xc0,%eax
    7c7a:	83 f8 40             	cmp    $0x40,%eax
    7c7d:	75 f5                	jne    7c74 <waitdisk+0x8>
		/* do nothing */;
}
    7c7f:	5d                   	pop    %ebp
    7c80:	c3                   	ret    

00007c81 <readsect>:

void
readsect(void *dst, uint32_t offset)
{
    7c81:	55                   	push   %ebp
    7c82:	89 e5                	mov    %esp,%ebp
    7c84:	57                   	push   %edi
    7c85:	8b 7d 0c             	mov    0xc(%ebp),%edi
	// wait for disk to be ready
	waitdisk();
    7c88:	e8 df ff ff ff       	call   7c6c <waitdisk>
}

static inline void
outb(int port, uint8_t data)
{
	asm volatile("outb %0,%w1" : : "a" (data), "d" (port));
    7c8d:	ba f2 01 00 00       	mov    $0x1f2,%edx
    7c92:	b0 01                	mov    $0x1,%al
    7c94:	ee                   	out    %al,(%dx)
    7c95:	b2 f3                	mov    $0xf3,%dl
    7c97:	89 f8                	mov    %edi,%eax
    7c99:	ee                   	out    %al,(%dx)

	outb(0x1F2, 1);		// count = 1 设置读取扇区的数目为1
	outb(0x1F3, offset);
	outb(0x1F4, offset >> 8);
    7c9a:	89 f8                	mov    %edi,%eax
    7c9c:	c1 e8 08             	shr    $0x8,%eax
    7c9f:	b2 f4                	mov    $0xf4,%dl
    7ca1:	ee                   	out    %al,(%dx)
	outb(0x1F5, offset >> 16);
    7ca2:	89 f8                	mov    %edi,%eax
    7ca4:	c1 e8 10             	shr    $0x10,%eax
    7ca7:	b2 f5                	mov    $0xf5,%dl
    7ca9:	ee                   	out    %al,(%dx)
	outb(0x1F6, (offset >> 24) | 0xE0);
    7caa:	c1 ef 18             	shr    $0x18,%edi
    7cad:	89 f8                	mov    %edi,%eax
    7caf:	83 c8 e0             	or     $0xffffffe0,%eax
    7cb2:	b2 f6                	mov    $0xf6,%dl
    7cb4:	ee                   	out    %al,(%dx)
    7cb5:	b2 f7                	mov    $0xf7,%dl
    7cb7:	b0 20                	mov    $0x20,%al
    7cb9:	ee                   	out    %al,(%dx)
	outb(0x1F7, 0x20);	// cmd 0x20 - read sectors 0x20命令，读取扇区

	// wait for disk to be ready
	waitdisk();
    7cba:	e8 ad ff ff ff       	call   7c6c <waitdisk>
}

static inline void
insl(int port, void *addr, int cnt)
{
	asm volatile("cld\n\trepne\n\tinsl"
    7cbf:	8b 7d 08             	mov    0x8(%ebp),%edi
    7cc2:	b9 80 00 00 00       	mov    $0x80,%ecx
    7cc7:	ba f0 01 00 00       	mov    $0x1f0,%edx
    7ccc:	fc                   	cld    
    7ccd:	f2 6d                	repnz insl (%dx),%es:(%edi)

	// read a sector 读取到dst位置
	insl(0x1F0, dst, SECTSIZE/4);
}
    7ccf:	5f                   	pop    %edi
    7cd0:	5d                   	pop    %ebp
    7cd1:	c3                   	ret    

00007cd2 <readseg>:

// Read 'count' bytes at 'offset' from kernel into physical address 'pa'.
// Might copy more than asked
void
readseg(uint32_t pa, uint32_t count, uint32_t offset)
{
    7cd2:	55                   	push   %ebp
    7cd3:	89 e5                	mov    %esp,%ebp
    7cd5:	57                   	push   %edi
    7cd6:	56                   	push   %esi
    7cd7:	53                   	push   %ebx
    7cd8:	8b 5d 08             	mov    0x8(%ebp),%ebx
    7cdb:	8b 75 10             	mov    0x10(%ebp),%esi
	uint32_t end_pa;

	end_pa = pa + count;
    7cde:	8b 7d 0c             	mov    0xc(%ebp),%edi
    7ce1:	01 df                	add    %ebx,%edi

	// round down to sector boundary
	pa &= ~(SECTSIZE - 1);
    7ce3:	81 e3 00 fe ff ff    	and    $0xfffffe00,%ebx

	// translate from bytes to sectors, and kernel starts at sector 1 加1因为0扇区被引导占用,ELF文件从1扇区开始
	offset = (offset / SECTSIZE) + 1;
    7ce9:	c1 ee 09             	shr    $0x9,%esi
    7cec:	46                   	inc    %esi

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	while (pa < end_pa) {
    7ced:	eb 10                	jmp    7cff <readseg+0x2d>
		// Since we haven't enabled paging yet and we're using
		// an identity segment mapping (see boot.S), we can
		// use physical addresses directly.  This won't be the
		// case once JOS enables the MMU.
		readsect((uint8_t*) pa, offset);
    7cef:	56                   	push   %esi
    7cf0:	53                   	push   %ebx
    7cf1:	e8 8b ff ff ff       	call   7c81 <readsect>
		pa += SECTSIZE;
    7cf6:	81 c3 00 02 00 00    	add    $0x200,%ebx
		offset++;
    7cfc:	46                   	inc    %esi
    7cfd:	58                   	pop    %eax
    7cfe:	5a                   	pop    %edx
	offset = (offset / SECTSIZE) + 1;

	// If this is too slow, we could read lots of sectors at a time.
	// We'd write more to memory than asked, but it doesn't matter --
	// we load in increasing order.
	while (pa < end_pa) {
    7cff:	39 fb                	cmp    %edi,%ebx
    7d01:	72 ec                	jb     7cef <readseg+0x1d>
		// case once JOS enables the MMU.
		readsect((uint8_t*) pa, offset);
		pa += SECTSIZE;
		offset++;
	}
}
    7d03:	8d 65 f4             	lea    -0xc(%ebp),%esp
    7d06:	5b                   	pop    %ebx
    7d07:	5e                   	pop    %esi
    7d08:	5f                   	pop    %edi
    7d09:	5d                   	pop    %ebp
    7d0a:	c3                   	ret    

00007d0b <bootmain>:
void readsect(void*, uint32_t);
void readseg(uint32_t, uint32_t, uint32_t);

void
bootmain(void)
{
    7d0b:	55                   	push   %ebp
    7d0c:	89 e5                	mov    %esp,%ebp
    7d0e:	56                   	push   %esi
    7d0f:	53                   	push   %ebx
	struct Proghdr *ph, *eph;

	// read 1st page off disk
	readseg((uint32_t) ELFHDR, SECTSIZE*8, 0);
    7d10:	6a 00                	push   $0x0
    7d12:	68 00 10 00 00       	push   $0x1000
    7d17:	68 00 00 01 00       	push   $0x10000
    7d1c:	e8 b1 ff ff ff       	call   7cd2 <readseg>

	// is this a valid ELF?
	if (ELFHDR->e_magic != ELF_MAGIC)
    7d21:	83 c4 0c             	add    $0xc,%esp
    7d24:	81 3d 00 00 01 00 7f 	cmpl   $0x464c457f,0x10000
    7d2b:	45 4c 46 
    7d2e:	75 39                	jne    7d69 <bootmain+0x5e>
		goto bad;

	// load each program segment (ignores ph flags) ELF头部有描述ELF文件应加载到内存什么位置的描述表,先将描述表的头地址存在ph
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
    7d30:	8b 1d 1c 00 01 00    	mov    0x1001c,%ebx
    7d36:	81 c3 00 00 01 00    	add    $0x10000,%ebx
	eph = ph + ELFHDR->e_phnum;
    7d3c:	0f b7 05 2c 00 01 00 	movzwl 0x1002c,%eax
    7d43:	c1 e0 05             	shl    $0x5,%eax
    7d46:	8d 34 03             	lea    (%ebx,%eax,1),%esi
	// 按照描述表将ELF文件中数据载入内存
	for (; ph < eph; ph++)
    7d49:	eb 14                	jmp    7d5f <bootmain+0x54>
		// p_pa is the load address of this segment (as well
		// as the physical address)
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
    7d4b:	ff 73 04             	pushl  0x4(%ebx)
    7d4e:	ff 73 14             	pushl  0x14(%ebx)
    7d51:	ff 73 0c             	pushl  0xc(%ebx)
    7d54:	e8 79 ff ff ff       	call   7cd2 <readseg>

	// load each program segment (ignores ph flags) ELF头部有描述ELF文件应加载到内存什么位置的描述表,先将描述表的头地址存在ph
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	// 按照描述表将ELF文件中数据载入内存
	for (; ph < eph; ph++)
    7d59:	83 c3 20             	add    $0x20,%ebx
    7d5c:	83 c4 0c             	add    $0xc,%esp
    7d5f:	39 f3                	cmp    %esi,%ebx
    7d61:	72 e8                	jb     7d4b <bootmain+0x40>
		// as the physical address)
		readseg(ph->p_pa, ph->p_memsz, ph->p_offset);

	// call the entry point from the ELF header 根据ELF头部储存的入口信息，找到内核的入口
	// note: does not return!
	((void (*)(void)) (ELFHDR->e_entry))();
    7d63:	ff 15 18 00 01 00    	call   *0x10018
}

static inline void
outw(int port, uint16_t data)
{
	asm volatile("outw %0,%w1" : : "a" (data), "d" (port));
    7d69:	ba 00 8a 00 00       	mov    $0x8a00,%edx
    7d6e:	b8 00 8a ff ff       	mov    $0xffff8a00,%eax
    7d73:	66 ef                	out    %ax,(%dx)
    7d75:	b8 00 8e ff ff       	mov    $0xffff8e00,%eax
    7d7a:	66 ef                	out    %ax,(%dx)
    7d7c:	eb fe                	jmp    7d7c <bootmain+0x71>
