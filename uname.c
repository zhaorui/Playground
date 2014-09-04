#include <sys/utsname.h>
#include <stdio.h>

int main (int argc, char *argv)
{
    struct utsname sysbuff;
    if (uname(&sysbuff) == 0){
        printf("%s\n", sysbuff.sysname);
        printf("%s\n", sysbuff.nodename);
        printf("%s\n", sysbuff.release);
        printf("%s\n", sysbuff.version);
        printf("%s\n", sysbuff.machine);
    }
}
