#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <unistd.h>

int main(int argc, char **argv, char **envp)
{
    //for(char **i = envp; i != NULL; i++ )
    //{
      //  printf("%s\n", *i);
    //}
    //setuid(0);
    system("whoami");
    //system("bash -c /usr/bin/true");
    return 0;
}
