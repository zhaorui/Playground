#include <stdio.h>

typedef int io (int in);

io x_func;

int x_func(int in)
{
    return in--;
}

int io_untouch(int in)
{
    return in;
}

int io_plus_one(int in)
{
    return in+1;
}

int io_double(int in)
{
    return in*2;
}

int main(int argc, char ** argv)
{
    io *x = x_func;
    io *fun = io_double;
    printf("result is %d\n", fun(10));
    return 0;
}
