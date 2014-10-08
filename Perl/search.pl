#!/usr/bin/perl -w
# pl8.pl -  query California license plate database
 
use strict;
use LWP::UserAgent;
my $plate = $ARGV[0] || die "Plate to search for?\n";
$plate = uc $plate;
$plate =~ tr/O/0/;  # we use zero for letter-oh

#die "$plate is invalid.\n"
# unless $plate =~ m/^[A-Z0-9]{2,7}$/
#    and $plate !~ m/^\d+$/;  # no all-digit plates
 
my $browser = LWP::UserAgent->new;
my $response = $browser->post(
  'http://www.baidu.com',
  [
    'plate'  => $plate,
    'search' => 'Check Plate Availability'
  ],
);
die "Error: ", $response->status_line
 unless $response->is_success;

print $response->content;

if($response->content =~ m/is unavailable/) {
  print "$plate is already taken.\n";
} elsif($response->content =~ m/and available/) {
  print "$plate is AVAILABLE!\n";
} else {
  print "$plate... Can't make sense of response?!\n";
}
exit;
