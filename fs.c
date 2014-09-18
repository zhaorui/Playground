#include <sys/statvfs.h>
#include <stdio.h>

int main(int argc, char **argv)
{
    struct statvfs vfs;
    printf("size of statvfs structure: %d\n", sizeof(struct statvfs));
    statvfs("/dev/root", &vfs);

    //list out information of file system
    printf("block size: %ld\n",vfs.f_bsize);
    printf("fundamental block size: %ld\n",vfs.f_frsize);
    printf("total blocks: %llu\n",(unsigned long long)vfs.f_blocks);
    printf("free blocks: %llu\n",(unsigned long long)vfs.f_bfree);
    printf("total number of i_nodes %llu\n",(unsigned long long)vfs.f_files);
    printf("number of free i_node %llu\n",(unsigned long long)vfs.f_ffree);
    printf("max length of file name: %lu\n",vfs.f_namemax);
    return 0;
}
