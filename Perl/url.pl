#!/usr/bin/perl -w

use URI::Escape;
use URI;

$str1 = uri_escape("hello world");
$str2 = uri_escape("sample[01]");
$str3 = uri_escape("赵睿");
print "https://bill.com/",$str1,"/",$str2,"/",$str3,"\n";

my $url = URI->new('http://user:password@example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('http://example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('//example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('nfs://example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('smb://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder');
print $url->scheme(),"\n";
print $url->userinfo(),"\n";
#print $url->host(),"\n";
#print $url->port(),"\n";
print $url->path(),"\n";
#print $url->query(),"\n";
