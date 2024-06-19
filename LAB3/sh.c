#include <stdlib.h>
#include <unistd.h>
#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <assert.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>

// Simplifed xv6 shell.

#define MAXARGS 10

// All commands have at least a type. Have looked at the type, the code
// typically casts the *cmd to some specific cmd type.
struct cmd {
  int type;          //  ' ' (exec), | (pipe), '<' or '>' for redirection
};

struct execcmd {
  int type;              // ' '
  char *argv[MAXARGS];   // arguments to the command to be exec-ed
};

struct redircmd {
  int type;          // < or > 
  struct cmd *cmd;   // the command to be run (e.g., an execcmd)
  char *file;        // the input/output file
  int flags;         // flags for open() indicating read or write
  int fd;            // the file descriptor number to use for the file
};

struct pipecmd {
  int type;          // |
  struct cmd *left;  // left side of pipe
  struct cmd *right; // right side of pipe
};

int fork1(void);  // Fork but exits on failure.
struct cmd *parsecmd(char*);

// Execute cmd.  Never returns.
void
runcmd(struct cmd *cmd)
{
  int p[2], r;
  struct execcmd *ecmd;
  struct pipecmd *pcmd;
  struct redircmd *rcmd;

  if(cmd == 0)
    _exit(0);
  
  switch(cmd->type){
  default:
    fprintf(stderr, "unknown runcmd\n");
    _exit(-1);

  case ' ':
    ecmd = (struct execcmd*)cmd;
    if(ecmd->argv[0] == 0)
      _exit(0);
    // fprintf(stderr, "exec not implemented\n");
    // Your code here (逻辑：若当前路径找不到该命令，则明确为在bin中找，若仍找不到，则继续明确为在/usr/bin中找)
    // execv会停止执行当前的进程，并且以argv[0]应用进程替换被停止执行的进程，进程ID没有改变，argv为该进程参数，一般正常执行时该函数不会返回
    if(execv(ecmd->argv[0],ecmd->argv)==-1){ 
		char mypath[20]="/bin/";
		strcat(mypath,ecmd->argv[0]);
		if(execv(mypath,ecmd->argv)==-1){
			strcpy(mypath,"/usr/bin/");
			strcat(mypath, ecmd->argv[0]);
			if(execv(mypath,ecmd->argv)==-1){
				fprintf(stderr, "Command %s can't find\n", ecmd->argv[0]);
				_exit(0);
			}
		}
	}
    break;

  case '>':
  case '<':
    rcmd = (struct redircmd*)cmd;
    // fprintf(stderr, "redir not implemented\n");
    // Your code here ...(实现I/O的重定向，需先释放对应的文件描述符(close)，再通过打开需要重定向目标文件(open))
    close(rcmd->fd);
  	if(open(rcmd->file, rcmd->flags, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)<0){
		fprintf(stderr, "file %s can't find\n", rcmd->file);
		_exit(0);
  	}
    runcmd(rcmd->cmd);
    break;

  case '|':
    pcmd = (struct pipecmd*)cmd;
    // fprintf(stderr, "pipe not implemented\n");
    // Your code here ...
    if(pipe(p) < 0){ // 建立一个缓冲区，并把缓冲区通过 fd 形式给程序调用。它将 p[0] 修改为缓冲区的读取端， p[1] 修改为缓冲区的写入端
		fprintf(stderr,"Fail to create a pipe\n");
		_exit(0);
    }

    /* 子进程执行*/
    if(fork1() == 0){// 这里判断的意思是，当前进程是子进程是执行括号下面的指令，否则不执行（因为子进程才会返回0）
    //child one:read from stdin(0), write to the right end of pipe(p[1])
      close(1); // fd中0代表读出，1代表写入
      dup(p[1]); // 产生并返回与传入参数fd指向同一文件的fd。产生的fd总是空闲的最小fd
      close(p[0]);
      close(p[1]);
      runcmd(pcmd->left);
    }
    wait(&r);

      /* 子进程执行 */
    if(fork1() == 0){
    //child two:read from the left end of pipe(p[0]), write to stdout(1)
      close(0);
      dup(p[0]);
      close(p[0]);
      close(p[1]);
      runcmd(pcmd->right);
    }
      
      /* 父进程，子进程都执行 */
    close(p[0]);
    close(p[1]);
    wait(&r);
    break;
  }    
  _exit(0);
}

int
getcmd(char *buf, int nbuf)
{
  if (isatty(fileno(stdin))) // 检查设备类型是否为stdin
    fprintf(stdout, "6.828$ ");
  memset(buf, 0, nbuf); // 初始化buf
  if(fgets(buf, nbuf, stdin) == 0)
    return -1; // EOF
  return 0;
}

/* 主函数 */
int
main(void)
{
  static char buf[100];
  int fd, r;

  // Read and run input commands. 若是在stdin输入流得到命令则进行
  while(getcmd(buf, sizeof(buf)) >= 0){ 
    if(buf[0] == 'c' && buf[1] == 'd' && buf[2] == ' '){ // 判断是否要更改当前目录，也就是判断是否命令是cd
      // Clumsy but will have to do for now.
      // Chdir has no effect on the parent if run in the child.
      buf[strlen(buf)-1] = 0;  // chop \n
      if(chdir(buf+3) < 0) // chdir：将当前目录改为参数里的目录
        fprintf(stderr, "cannot cd %s\n", buf+3);
      continue;
    }
    if(fork1() == 0) // 创建新进程成功，则解析命令参数后执行该命令
      runcmd(parsecmd(buf));
    wait(&r);
  }
  exit(0);
}

int
fork1(void)
{
  int pid;
  
  pid = fork();
  if(pid == -1)
    perror("fork");
  return pid;
}

struct cmd*
execcmd(void)
{
  struct execcmd *cmd;

  cmd = malloc(sizeof(*cmd));
  memset(cmd, 0, sizeof(*cmd));
  cmd->type = ' ';
  return (struct cmd*)cmd;
}

struct cmd*
redircmd(struct cmd *subcmd, char *file, int type)
{
  struct redircmd *cmd;

  cmd = malloc(sizeof(*cmd));
  memset(cmd, 0, sizeof(*cmd));
  cmd->type = type;
  cmd->cmd = subcmd;
  cmd->file = file;
  cmd->flags = (type == '<') ?  O_RDONLY : O_WRONLY|O_CREAT|O_TRUNC;
  cmd->fd = (type == '<') ? 0 : 1; // fd中0代表读出，1代表写入
  return (struct cmd*)cmd;
}

struct cmd*
pipecmd(struct cmd *left, struct cmd *right)
{
  struct pipecmd *cmd;

  cmd = malloc(sizeof(*cmd));
  memset(cmd, 0, sizeof(*cmd));
  cmd->type = '|';
  cmd->left = left;
  cmd->right = right;
  return (struct cmd*)cmd;
}

// Parsing

char whitespace[] = " \t\r\n\v";
char symbols[] = "<|>";

int
gettoken(char **ps, char *es, char **q, char **eq)
{
  char *s;
  int ret;
  
  s = *ps;
  while(s < es && strchr(whitespace, *s))
    s++;
  if(q)
    *q = s;
  ret = *s;
  switch(*s){
  case 0:
    break;
  case '|':
  case '<':
    s++;
    break;
  case '>':
    s++;
    break;
  default:
    ret = 'a';
    while(s < es && !strchr(whitespace, *s) && !strchr(symbols, *s))
      s++;
    break;
  }
  if(eq)
    *eq = s;
  
  while(s < es && strchr(whitespace, *s))
    s++;
  *ps = s;
  return ret;
}

int
peek(char **ps, char *es, char *toks)
{
  char *s;
  
  s = *ps;// 解引用
  while(s < es && strchr(whitespace, *s)) // 查找字符串whitespace中首次出现*s的位置
    s++;
  *ps = s;
  return *s && strchr(toks, *s);
}

struct cmd *parseline(char**, char*);
struct cmd *parsepipe(char**, char*);
struct cmd *parseexec(char**, char*);

// make a copy of the characters in the input buffer, starting from s through es.
// null-terminate the copy to make it a string.
char 
*mkcopy(char *s, char *es)
{
  int n = es - s;
  char *c = malloc(n+1);
  assert(c);
  strncpy(c, s, n);
  c[n] = 0;
  return c;
}

struct cmd*
parsecmd(char *s)
{
  char *es;
  struct cmd *cmd;

  es = s + strlen(s);
  cmd = parseline(&s, es);
  peek(&s, es, ""); // 
  if(s != es){
    fprintf(stderr, "leftovers: %s\n", s);
    exit(-1);
  }
  return cmd;
}

struct cmd*
parseline(char **ps, char *es)
{
  struct cmd *cmd;
  cmd = parsepipe(ps, es);
  return cmd;
}

struct cmd*
parsepipe(char **ps, char *es)
{
  struct cmd *cmd;

  cmd = parseexec(ps, es);
  if(peek(ps, es, "|")){
    gettoken(ps, es, 0, 0);
    cmd = pipecmd(cmd, parsepipe(ps, es));
  }
  return cmd;
}

struct cmd*
parseredirs(struct cmd *cmd, char **ps, char *es)
{
  int tok;
  char *q, *eq;

  while(peek(ps, es, "<>")){
    tok = gettoken(ps, es, 0, 0);
    if(gettoken(ps, es, &q, &eq) != 'a') {
      fprintf(stderr, "missing file for redirection\n");
      exit(-1);
    }
    switch(tok){
    case '<':
      cmd = redircmd(cmd, mkcopy(q, eq), '<');
      break;
    case '>':
      cmd = redircmd(cmd, mkcopy(q, eq), '>');
      break;
    }
  }
  return cmd;
}

struct cmd*
parseexec(char **ps, char *es)
{
  char *q, *eq;
  int tok, argc;
  struct execcmd *cmd;
  struct cmd *ret;
  
  // 构造cmd结构体
  ret = execcmd();
  cmd = (struct execcmd*)ret;

  argc = 0;
  ret = parseredirs(ret, ps, es);
  while(!peek(ps, es, "|")){
    if((tok=gettoken(ps, es, &q, &eq)) == 0)
      break;
    if(tok != 'a') {
      fprintf(stderr, "syntax error\n");
      exit(-1);
    }
    cmd->argv[argc] = mkcopy(q, eq);
    argc++;
    if(argc >= MAXARGS) {
      fprintf(stderr, "too many args\n");
      exit(-1);
    }
    ret = parseredirs(ret, ps, es);
  }
  cmd->argv[argc] = 0;
  return ret;
}