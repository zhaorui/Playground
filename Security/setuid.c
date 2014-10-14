#include <unistd.h> //setuid seteuid
#include <stdio.h>

int main(int argc, char **argv)
{
    seteuid(getuid());
    //seteuid(0);
    //setuid(getuid());
    //setuid(0);

    //seteuid(getuid());
    //seteuid(0);
    //setuid(getuid());
    setuid(0);
    setuid(0);

    //seteuid(1);

    printf("real uid:    %d\n", getuid());
    printf("euid:   %d\n", geteuid());
    return 0;
}
