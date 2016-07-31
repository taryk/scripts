#!/usr/bin/env perl
#
# Resolves domain names to IP addresses and returns a list of them ready to
# copy and paste into OpenVPN config.
#
# Usage:
#
# $ resolve.pl google.com facebook.com twitter.com >> openvpn.conf
#

use common::sense;
use Net::DNS::Resolver;

my $resolver = Net::DNS::Resolver->new();

for my $domain (@ARGV) {
    my $r = $resolver->search($domain);
    say "### $domain";
    answer:
    for my $answer ($r->answer) {
        next answer if !$answer || $answer->type ne 'A';
        say 'route ' . $answer->address;
    }
}
