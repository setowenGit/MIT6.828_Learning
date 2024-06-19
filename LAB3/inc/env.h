/* See COPYRIGHT for copyright information. */

#ifndef JOS_INC_ENV_H
#define JOS_INC_ENV_H

#include <inc/types.h>
#include <inc/trap.h>
#include <inc/memlayout.h>

typedef int32_t envid_t;

// An environment ID 'envid_t' has three parts:
//
// +1+---------------21-----------------+--------10--------+
// |0|          Uniqueifier             |   Environment    |
// | |                                  |      Index       |
// +------------------------------------+------------------+
//                                       \--- ENVX(eid) --/
//
// The environment index ENVX(eid) equals the environment's index in the
// 'envs[]' array.  The uniqueifier distinguishes environments that were
// created at different times, but share the same environment index.
//
// All real environments are greater than 0 (so the sign bit is zero).
// envid_ts less than 0 signify errors.  The envid_t == 0 is special, and
// stands for the current environment.

#define LOG2NENV		10
#define NENV			(1 << LOG2NENV)  // 最大进程数量
#define ENVX(envid)		((envid) & (NENV - 1))

// Values of env_status in struct Env
enum {
	ENV_FREE = 0, // 空闲状态，此时进程位于env_free_list中
	ENV_DYING,    // 挂死进程，之后就会被释放
	ENV_RUNNABLE, // 就绪状态
	ENV_RUNNING,  // 正在运行状态
	ENV_NOT_RUNNABLE // 阻塞状态，如该进程正在等待某个信号量
};

// Special environment types
enum EnvType {
	ENV_TYPE_USER = 0,
};

struct Env {
	struct Trapframe env_tf;	// Saved registers  保存进程的寄存器现场值
	struct Env *env_link;		// Next free Env    指向env_free_list中下一个空闲的进程
	envid_t env_id;			    // Unique environment identifier  独一无二的进程ID
	envid_t env_parent_id;		// env_id of this env's parent    该进程的父进程，该进程就是由父进程fork出来的
	enum EnvType env_type;		// Indicates special system environments  进程类型
	unsigned env_status;		// Status of the environment  进程状态
	uint32_t env_runs;		    // Number of times environment has run

	// Address space
	pde_t *env_pgdir;		// Kernel virtual address of page dir 保存此进程的page directory的内核虚拟地址
};

#endif // !JOS_INC_ENV_H
