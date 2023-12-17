#include <inc/mmu.h>
#include <inc/memlayout.h>

.data
// Define the global symbols 'envs', 'pages', 'uvpt', and 'uvpd'
// so that they can be used in C as if they were ordinary global arrays.
	.globl envs
	.set envs, UENVS
	.globl pages
	.set pages, UPAGES
	.globl uvpt
	.set uvpt, UVPT
	.globl uvpd
	.set uvpd, (UVPT+(UVPT>>12)*4)


// Entrypoint - this is where the kernel (or our parent environment)
// starts us running when we are initially loaded into a new environment.
// 入口点-当我们最初加载到一个新环境中时，内核（或我们的父环境）在这里开始运行。
.text
.globl _start
_start:
	// See if we were started with arguments on the stack 如果有参数的话，可以从这里开始
    cmpl $USTACKTOP, %esp
	jne args_exist

	// If not, push dummy argc/argv arguments.
	// This happens when we are loaded by the kernel,
	// because the kernel does not know about passing arguments.
    // 如果没有参数，则推送虚构的argc/argv参数。
    // 这发生在内核加载时，因为内核无法确定传递的参数
	pushl $0
	pushl $0

args_exist:
	call libmain
1:	jmp 1b

