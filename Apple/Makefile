CC= gcc
CXX= g++
CFLAGS=
CXXFLAGS= -g
LDFLAGS= -framework Security\
	 -framework CoreFoundation\
	 -lcrypto\

CXX_PROG=signdata
CC_PROG=

CXX_OBJ= signdata.o
CC_OBJ= 


all: $(CXX_PROG) $(CC_PROG) subdir
	
# Make rules would be executed line by line, so if you write a for loop,
# put them in one line using '\', also use () to create a sub-shell so we
# could stay in our current directory, when Make process of subdir is done
# Question: why it's $$i but not $i ?
subdir:
	for i in $(DIRS); do \
	    (cd $$i && echo "making $$i" && $(MAKE)) || exit 1; \
	done


$(CXX_PROG): $(CXX_OBJ)
	$(CXX) -o $@ $@.o $(LDFLAGS)

$(CC_PROG): $(CC_OBJ)

signdata.o: signdata.cpp

clean:
	rm -rf *.o $(CXX_PROG) $(CC_PROG)

.PHONY: subdir
