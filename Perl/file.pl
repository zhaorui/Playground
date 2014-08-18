#!/usr/bin/perl -w

while (<>)
{
    chomp;
    @words = split(/:/);
    foreach my $line (@words)
    {
        print "$line\n";
    }

}

open my $fd, "<", "./lock";

while (<$fd>)
{
    my $line = $_;
    $line =~ s/([a-z])/\U$1/gi;
    print "\$_: $_";
    print "\$line: $line";

}

my $Greeting = "\UGood Morning!";
print "$Greeting \n";
