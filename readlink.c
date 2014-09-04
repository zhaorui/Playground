#include <stdio.h>
#include <unistd.h>
#include <string.h>

int main(int argc, char **argv)
{
    char linkdest[512];
    int length;

    memset(linkdest, 0, 512);
    if ((length = readlink("/etc/cacloginconfig.plist", linkdest, sizeof(linkdest)-1)) == -1)
    {
       printf("Error\n");
    }
    else
    {
        printf("%s\n", linkdest);
    }

    return 0;
}
