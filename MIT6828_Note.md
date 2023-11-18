# MIT 6.828 Learning

##### [课程表](https://pdos.csail.mit.edu/6.828/2018/schedule.html)

##### [实验环境配置(其他报错问题可看评论区)](https://blog.csdn.net/Rcary/article/details/125547980?utm_source=app&app_version=4.17.0)

##### [Github参考](https://github.com/setowenGit/MIT6.828_OS)

---

## Lab 1

 * QEMU模拟器：一个现代和相对快速的模拟器。虽然QEMU的内置监视器只提供有限的调试支持，但QEMU可以作为GNU调试器的远程调试目标，我们将在这个实验室中使用它来完成早期引导过程。
 * ```make qemu``` 和 ```make qemu-nox```：开启带有和不带有独立显示窗口的QEMU模拟器
 * PC物理内存空间
   * 对于早起的的16位处理器PC，只能寻址1MB的物理内存，具体来说，8088使用一个16位的段寄存器和一个16位的偏移寄存器。物理地址的计算方式是将段地址左移4位（乘以16，16进制表示下是左移1位）然后加上偏移地址，即可以得到一个20位的地址，进一步地，这使得理论上可以访问$2^{20}$个地址，即1 MB 的物理内存
   * BIOS代码由ROM复制到0xF0000~0x100000的地方，对于现代32位处理器PC，BIOS的一部分代码还会复制到内存的末端

![](fig/2023-11-18-16-35-40.png)

现代32位处理器PC内存如下:

![](fig/2023-11-18-16-19-57.png)

* QEMU的debug模式：先一个终端运行```make qemu-nox-gdb```，后另外一个终端运行```make gdb```，使用```si```来进行调试步进
* 首先QEMU中执行的是BIOS代码，一开机通过硬件电路，BIOS代码直接加载到内存中，CS:IP会指向[0xf000:0xfff0]，CS左移一位就是0xffff0，指向的代码是一个jmp指令

![](fig/2023-11-18-17-15-35.png)