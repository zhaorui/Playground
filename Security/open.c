#include <fcntl.h> //open
#include <stdio.h>
#include <stdlib.h> //exit
#include <unistd.h> //close

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
    FILE * fp = fopen("/tmp/hello.txt", "ax"/*+x*/);
    if (!fp){
        perror("main::fopen");
        fclose(fp);
    }
    else
    {
        printf("fopen(\"/tmp/hello.txt\",\"ax\") successfully, fd is %d\n", fileno(fp));
        fputs("\tHello world\nMessage from Bill Zhao\n", fp);
    }
    //fseek(fp, 0L, SEEK_SET);
    //catFile(fp);

    //fp = fopen("/var/log/dmesg", "r");
    //catFile(fp);

    int fd = open("/tmp/hello.txt", O_RDWR);
    printf("open sucessfuly, fd is %d\n", fd);

    char buffer[128];
    FILE * _fp = fdopen(fd, "r");
    if(_fp)
        catFile(_fp);
    else
        perror("main::fdopen");
    
    close(fd);
    if(fp)
        fclose(fp);

    return 0;
}
