// hello, world
#include <inc/lib.h>

void
umain(int argc, char **argv)
{

    cprintf("hello, world\n");

    cprintf("i am environment %08x\n", thisenv->env_id);  //现在我们已经初始化了thisenv变量了，所以可以打印处来了O(∩_∩)O
}
