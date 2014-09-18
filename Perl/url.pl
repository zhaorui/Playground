#!/usr/bin/perl -w

use URI::Escape;
$str1 = uri_escape("hello world");
$str2 = uri_escape("sample[01]");
$str3 = uri_escape("赵睿");
print "https://bill.com/",$str1,"/",$str2,"/",$str3,"\n";
