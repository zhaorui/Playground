#Makefile Template for Play Ground of Code

CC= gcc
CXX= g++
CFLAGS= 
CXXFLAGS= 
LDFLAGS= 

#Add the target binary here
Progs=flock 

all: $(Progs)

#Add the target object file here, for instace
flock.o: flock.c

clean:
	rm -rf *.o $(Progs)
