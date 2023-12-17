/* See COPYRIGHT for copyright information. */

#ifndef JOS_INC_ERROR_H
#define JOS_INC_ERROR_H

enum {
	// Kernel error codes -- keep in sync with list in lib/printfmt.c. 
	// 内核错误代码 -- 与lib/printfmt.c中的列表保持同步。
	E_UNSPECIFIED	= 1,	// Unspecified or unknown problem 未指定或未知的问题
	E_BAD_ENV	,	// Environment doesn't exist or otherwise  环境不存在或其他问题
				// cannot be used in requested action 不能用于请求的操作中
	E_INVAL		,	// Invalid parameter 无效参数
	E_NO_MEM	,	// Request failed due to memory shortage 由于内存不足导致请求失败 
	E_NO_FREE_ENV	,	// Attempt to create a new environment beyond 试图创建一个新的环境，超过了允许的最大限度
				// the maximum allowed 试图创建的新环境超过了允许的最大值
	E_FAULT		,	// Memory fault 内存故障

	MAXERROR
};

#endif	// !JOS_INC_ERROR_H */
