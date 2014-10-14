#!/usr/bin/perl -w 

use IO::Socket::UNIX;

unlink("print/socket");
my $socket = IO::Socket::UNIX->new(
    Local   => "print/socket",
    Type    => SOCK_STREAM,
    Listen  => SOMAXCONN
) or exit(-1);

print "socket created\n";

chmod(0660, "print/socket");

while (my $client = $socket->accept())
{
    while(<$client>)
    {
        print $_;
    }
    print("client: $client");
    close($client);
}
