#include <stdio.h>
#include <unistd.h>
#include <sys/file.h>

int main(int argc, char *argv[])
{
    int fd = open("./lockfile", O_RDWR|O_CREAT, 0644);
    close(fd);
    return 0;
}
