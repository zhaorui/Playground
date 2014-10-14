#!/usr/bin/perl -w

use POSIX qw/ setuid /;
use IO::Socket::UNIX;

setuid(26);

print "uid: $<\n";
print "euid: $>\n";

my $socket = IO::Socket::UNIX->new(
        Peer => "print/socket",
        Type => SOCK_STREAM
    )
or print "socket create failed: $!\n";

print $socket "begin\n";

while(<>)
{
    print $socket $_;
}

#done writting
shutdown($socket, 1);
close($socket);


