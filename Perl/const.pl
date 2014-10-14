#!/usr/bin/perl -w

use constant {
    NAME => 0,
    PASSWD => 1,
    UID => 2,
    GID => 3,
};

my @adquery_result = `adquery user`;
my %aduser_info;
foreach (@adquery_result)
{
    chomp;
    my @data = split/:/;
    $aduser_info{$data[NAME]} = [@data];
}

printf "hello, %d",
6;

#for (keys %aduser_info)
#{
#    print "Name: $aduser_info{$_}[NAME]\n";
#    print "Password: $aduser_info{$_}[PASSWD]\n";
#    print "UID: $aduser_info{$_}[UID]\n";
#    print "GID: $aduser_info{$_}[GID]\n";
#}
