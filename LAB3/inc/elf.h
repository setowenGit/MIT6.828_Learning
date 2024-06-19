#ifndef JOS_INC_ELF_H
#define JOS_INC_ELF_H

#define ELF_MAGIC 0x464C457FU	/* "\x7FELF" in little endian */

struct Elf {
	uint32_t e_magic;	 // ELF 文件的标识符，必须等于 ELF_MAGIC，用于标识文件是否为 ELF 格式
	uint8_t e_elf[12];   // 保留的 12 字节，通常不使用
	uint16_t e_type;     // 描述 ELF 文件的类型，比如可执行文件、共享目标文件等
	uint16_t e_machine;  // 描述目标体系结构的标识符，指示了文件运行的平台
	uint32_t e_version;  // ELF 文件的版本号
	uint32_t e_entry;    // 程序的入口点（即程序启动时执行的第一条指令的地址）
	uint32_t e_phoff;    // 程序头表（Program Header Table）在文件中的偏移量，即程序头表的起始位置
	uint32_t e_shoff;    // 节头表（Section Header Table）在文件中的偏移量，即节头表的起始位置
	uint32_t e_flags;    // 特定标志的位掩码，用于描述文件的属性
	uint16_t e_ehsize;   // ELF 头的大小，以字节为单位
	uint16_t e_phentsize;// 程序头表中每个条目的大小
	uint16_t e_phnum;    // 程序头表中条目的数量
	uint16_t e_shentsize;// 节头表中每个条目的大小
	uint16_t e_shnum;    // 节头表中条目的数量
	uint16_t e_shstrndx; // 节头表中字符串表节的索引
};

struct Proghdr {
	uint32_t p_type;     // 段（segment）的类型，描述了段的用途和属性，比如代码段、数据段等
	uint32_t p_offset;   // 段在文件中的偏移量，即段的起始位置距文件开始的字节偏移量
	uint32_t p_va;       // 段在内存中的虚拟地址（Virtual Address），即段加载到内存后在虚拟地址空间中的地址
	uint32_t p_pa;       // 段在内存中的物理地址（Physical Address），即段加载到内存后在物理地址空间中的地址
	uint32_t p_filesz;   // 段在文件中的大小，以字节为单位
	uint32_t p_memsz;    // 段在内存中的大小，以字节为单位。通常大于等于 p_filesz，表示在内存中需要分配的空间大小
	uint32_t p_flags;    // 段的标志位，描述了段的属性，比如可读、可写、可执行等
	uint32_t p_align;    // 段在文件和内存中的对齐要求，即段在文件中和内存中的起始地址的对齐方式
};

struct Secthdr {
	uint32_t sh_name;    // 节名称在字符串表中的偏移量或索引，用于定位节的名称
	uint32_t sh_type;    // 节的类型，描述了节的内容和属性，比如代码节、数据节、符号表节等
	uint32_t sh_flags;   // 节的标志位，描述了节的属性，比如可读、可写、可执行等
	uint32_t sh_addr;    // 节在内存中的地址，如果节在内存中被加载，则表示其在内存中的起始地址
	uint32_t sh_offset;  // 节在文件中的偏移量，即节的起始位置距文件开始的字节偏移量
	uint32_t sh_size;    // 节在文件中的大小，以字节为单位
	uint32_t sh_link;    // 与该节相关联的其他节的索引，具体含义取决于节的类型
	uint32_t sh_info;    // 额外的节信息，具体含义取决于节的类型
	uint32_t sh_addralign;// 节在文件和内存中的对齐要求，即节在文件中和内存中的起始地址的对齐方式
	uint32_t sh_entsize; // 如果节包含固定大小的条目，则为每个条目的大小；否则为 0
};

// Values for Proghdr::p_type
#define ELF_PROG_LOAD		1

// Flag bits for Proghdr::p_flags
#define ELF_PROG_FLAG_EXEC	1
#define ELF_PROG_FLAG_WRITE	2
#define ELF_PROG_FLAG_READ	4

// Values for Secthdr::sh_type
#define ELF_SHT_NULL		0
#define ELF_SHT_PROGBITS	1
#define ELF_SHT_SYMTAB		2
#define ELF_SHT_STRTAB		3

// Values for Secthdr::sh_name
#define ELF_SHN_UNDEF		0

#endif /* !JOS_INC_ELF_H */
