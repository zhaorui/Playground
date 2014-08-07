#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
    FILE *fp = fopen("/dev/random", "r");
    if(!fp){
        perror("randgetter");
        exit(-1);
    }

    long long value = 0;
    int i;
    for (i=0; i<sizeof(value); i++){
        value <<= 8;
        value |= fgetc(fp);
    }

    printf("random number is: %lld\n", value);
    fclose(fp);
}
