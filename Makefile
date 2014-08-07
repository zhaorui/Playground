#Makefile Template for Play Ground of Code

CC= gcc
CXX= g++
CFLAGS= -g
CXXFLAGS= 
LDFLAGS= 

#Add the target binary here
Progs=flock funcpointer random

all: $(Progs)

#Add the target object file here, for instace
flock.o: flock.c
funcpointer.o: funcpointer.c
random.o: random.c

clean:
	rm -rf *.o $(Progs)
