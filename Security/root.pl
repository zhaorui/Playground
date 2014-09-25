#!/usr/bin/perl -w

open FILE, "/etc/sudoers";

while (<FILE>)
{
    print $_;
}
