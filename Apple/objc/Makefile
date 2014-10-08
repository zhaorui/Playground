CC=clang
CFLAGS=
LDFLAGS= -framework Foundation \
	 -framework AppKit

OBJC_PROG=play alert
OBJC_OBJ=play.o alert.o

all: $(OBJC_PROG)

OBJC_PROG: $(OBJC_OBJ)
	$(CC) -o $@ $@.o $(LDFLAGS)

alert.o: alert.m
play.o: play.m

clean:
	rm -rf *.o $(OBJC_PROG)

.PHONY: all clean
