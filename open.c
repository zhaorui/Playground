#include <stdio.h>
#include <stdlib.h> //exit

int catFile(FILE *fp)
{
    char buffer[32];
    while (fgets(buffer, 32, fp))
        printf("%s", buffer);
    if(!feof(fp)){
        perror("catFile::fgets");
        fclose(fp);
        exit(1);
    }
    return 0;
}


int main(int argc, char **argv)
{
    FILE * fp = fopen("/tmp/hello.txt", "w"/*+x*/);
    if (!fp){
        perror("main::fopen");
        fclose(fp);
        return 1;
    }

    fputs("\tHello world\nMessage from Bill Zhao\n", fp);
    //fseek(fp, 0L, SEEK_SET);
    //catFile(fp);

    //fp = fopen("/var/log/dmesg", "r");
    //catFile(fp);

    //int fd = open("/tmp/hello.txt", "r+");

    fclose(fp);
    return 0;
}
