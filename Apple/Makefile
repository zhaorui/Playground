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


all: $(CXX_PROG) $(CC_PROG)

$(CXX_PROG): $(CXX_OBJ)
	$(CXX) -o $@ $@.o $(LDFLAGS)

$(CC_PROG): $(CC_OBJ)

signdata.o: signdata.cpp

clean:
	rm -rf *.o $(CXX_PROG) $(CC_PROG)
