#Makefile Template for Play Ground of Code
DIRS= Apple
CC= gcc
CXX= g++
CFLAGS= -g
CXXFLAGS= 
LDFLAGS= 

#Add the target binary here
Progs=flock funcpointer random

all: $(Progs) subdir

# Make rules would be executed line by line, so if you write a for loop,
# put them in one line using '\', also use () to create a sub-shell so we
# could stay in our current directory, when Make process of subdir is done
# Question: why it's $$i but not $i ?
subdir:
	for i in $(DIRS); do \
	    (cd $$i && echo "making $$i" && $(MAKE)) || exit 1; \
	done

#Add the target object file here, for instace
flock.o: flock.c
funcpointer.o: funcpointer.c
random.o: random.c

clean:
	rm -rf *.o $(Progs)
	for i in $(DIRS); do \
	    (cd $$i && echo "make clean $$i" && $(MAKE) clean ) || exit 1; \
	done

.PHONY: subdir
