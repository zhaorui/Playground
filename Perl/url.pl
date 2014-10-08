#!/usr/bin/perl -w

use URI;
use URI::Escape;
use URI::Split qw /uri_split/; 

#my $urn = 'smb://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder';
#my $urn = 'nfs://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder';
#my $urn = 'afp://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder';
my $urn = 'afp://WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder';

my ($scheme, $auth, $path) = uri_split($urn);

foreach ($scheme, $auth, $path)
{
    if ( $_ ne "" )
    {
        print "$_\n";
    }
}


my $userinfo="";
my $server="";
if ($auth=~/@/)
{
    print "now auth: $auth\n";
    #server = $auth =~ m/([^@]+)$/;
    $auth =~ m/([^@]+)$/;
    $server = $1;
    $auth =~ m/(.*)\@$server$/;
    $userinfo = $1;
}
else
{
    $server = $auth;
}

my $user, $password;
if ( $userinfo eq "" )
{
    $user="";
    $password="";
}
elsif ( $userinfo =~ /^(.*):/ )
{
    $user = $1;
}


#my ($userinfo, $server) =  $auth =~ m/(.*)([^@]+)$/;

print "server: $server\n";
print "userinfo: $userinfo\n";

print "----- Split End -----\n";
exit(0);

$str1 = uri_escape("hello world");
$str2 = uri_escape("sample[01]");
$str3 = uri_escape("赵睿");
print "https://bill.com/",$str1,"/",$str2,"/",$str3,"\n";

my $url = URI->new('http://user:pass@example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('http://example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('//example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('nfs://example.int:4345/hello/myfolder/hello@world.php?user=501');
#my $url = URI->new('smb://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder');
print $url->scheme(),"\n";
print $url->userinfo(),"\n";
#print $url->host(),"\n";
#print $url->port(),"\n";
#print $url->path(),"\n";
#print $url->query(),"\n";


#my $uri = 'smb://obama:password@WIN-BU53IJE38OH.bill.com/smbshare/SMBShareFolder/SMBSubFolder';
#my($scheme, $authority, $path, $query, $fragment) =
#         $uri =~ m|(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?|;
#
#print "$scheme\n";
#print "$authority\n";
#print "$path\n";
#print "$query\n";
#print "$fragment\n";
