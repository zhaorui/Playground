#include <stdio.h>
#include <sys/stat.h>

int main(int argc, char **argv)
{
    umask(022);
    FILE *fp = fopen("/tmp/secret", "w");
    return 0;
}
