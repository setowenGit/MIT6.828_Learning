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

/*
	执行命令 符号： “ ”
	重定向命令 > 或者 <
	列表命令，也就是多个命令 符号是分号 ;
	管道命令，需要先建立管道 符号是 |
	返回命令(这个不知道是干嘛的)，符号是 &
*/



// All commands have at least a type. Have looked at the type, the code
// typically casts the *cmd to some specific cmd type.
// 所有命令至少有一个类型。查看了类型和代码通常将*cmd强制转换为某些特定的cmd类型。

struct cmd {
  int type;          //  ' ' (exec), | (pipe), '<' or '>' for redirection
		     //  ' ' (exec), | (pipe), '<'或'>'用于重定向
};

struct execcmd {
  int type;              // ' '
  char *argv[MAXARGS];   // arguments to the command to be exec-ed  要执行的命令的参数
};

struct redircmd {
  int type;          // < or > 
  struct cmd *cmd;   // the command to be run (e.g., an execcmd) 要运行的命令（例如，execcmd）
  char *file;        // the input/output file 输入/输出文件
  int flags;         // flags for open() indicating read or write;   open()的标志表示读或写
  int fd;            // the file descriptor number to use for the file 用于文件的文件描述符编号
};

struct pipecmd {
  int type;          // |
  struct cmd *left;  // left side of pipe 管道左侧
  struct cmd *right; // right side of pipe 管道右侧
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
    // Your code here ...
    char path[20] = "/bin/";
    strcat(path, ecmd->argv[0]);
    if(execv(path, ecmd-> argv) == -1){
    	fprintf(stderr,"Command %s cant't find\n", *(ecmd->argv));
    }
    break;

  case '>':
  case '<':
// "uniq, sort, wc" -> /usr/bin; 
    rcmd = (struct redircmd*)cmd;
     fprintf(stderr, "redir not implemented\n");
    // Your code here ...
    runcmd(rcmd->cmd);
    break;

  case '|':
    pcmd = (struct pipecmd*)cmd;
     fprintf(stderr, "pipe not implemented\n");
    // Your code here ...
    break;
  }    
  _exit(0);
}

int
getcmd(char *buf, int nbuf)
{
  // stdin  是标准输入, 将键盘输入字符将其送到控制台 
  // fileno 取得参数stream指定的文件流所使用的文件描述符
  // isatty 检查设备类型, 判断文件描述符是否是为终端机(控制台)
// in all， 从键盘输入流中读取对应的文件描述符，通过文件描述符检查此时输入的地方是否为控制台
// if true:则输出6.828$作为命令行默认头部
  if (isatty(fileno(stdin))) 
    fprintf(stdout, "6.828$ ");
  memset(buf, 0, nbuf);// 将某一块内存中的内容全部设置为指定的值, 这里是将buf后的nbuf个字节全部赋值为0
  if(fgets(buf, nbuf, stdin) == 0) // 空指针为0，代表没有读到字符或者字符溢出或者发生错误
				   // (但这不是所有系统都这样，Null值根据系统本身设置)
				   // fgets从指定的流中读取数据，每次读取一行. 从stdin(控制台)上读取nbuf个字符，存储在buf上
    return -1; // EOF 表示资料源无更多的资料可读取，在文本的最后存在此字符表示资料结束。
  return 0;
}

int
main(void)
{
  static char buf[100];
  int fd, r;

  // Read and run input commands.
  // 读取并运行输入命令。
  while(getcmd(buf, sizeof(buf)) >= 0){// -1表示读取失败， >=0表示读取成功
    if(buf[0] == 'c' && buf[1] == 'd' && buf[2] == ' '){ // 判断是否为'cd_'指令( _为空格)
      // Clumsy but will have to do for now.虽然是很愚钝的代码，但现在也只能这样做了。
      // Chdir has no effect on the parent if run in the child.如果在子级中运行，子级对父级没有影响。
      buf[strlen(buf)-1] = 0;  //chop \n,最后一个赋为0; strlen返回字符串长度值(遇到'\0'停止,长度不包含'\0')
      if(chdir(buf+3) < 0)//chdir 跳转当前工作目录. 判断能否跳转此子目录, 成功返回0 ，失败返回-1
        fprintf(stderr, "cannot cd %s\n", buf+3); // stderr代表屏幕;
      continue;
    }
    if(fork1() == 0) // 0为创建成功(为什么不是 >=0 ？, )
      runcmd(parsecmd(buf));
    wait(&r);
  }
  fprintf(stdout, "\n已退出6.828命令行\n");
  exit(0);
}

int
fork1(void)
{
  int pid;
  
  pid = fork();// fork用于创建一个新进程，称为子进程
	       // 它与进程（调用fork的进程）同时运行，此进程称为父进程。
	       // 负值：创建子进程失败。
	       // 零：返回到新创建的子进程。
               // 正值：获得子进程的进程id(只在父进程或调用者获得)
  if(pid == -1)
    perror("fork");// 将上一个函数发生错误的原因输出到标准设备(stderr),
		   // 参数 s 所指的字符串会先打印出，后面再加上错误原因字符串
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
  cmd->fd = (type == '<') ? 0 : 1;
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
  
  s = *ps;
  while(s < es && strchr(whitespace, *s))
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
  peek(&s, es, "");
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
  cmd = parsepipe(ps, es); // 检测是否有管道命令，有的话建立管道连接
  return cmd;
}

struct cmd*
parsepipe(char **ps, char *es)//检测是否有管道命令，有的话建立管道连接
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
