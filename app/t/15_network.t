#!/usr/bin/env perl

use Test::More tests => 3;
use Sys::Hostname::Long 'hostname_long';
use Regexp::Common qw/ net number /;
use Net::DNS::Resolver;
use Data::Dumper;
use lib './lib';
use DeltaR::Query;
use feature 'say';
use strict;
use warnings;

#
# Platforms an differ in how they do DNS lookups. Test here.
# 

my $ip_regex = qr/\A
   (?:
      (?: $RE{net}{IPv6} ) |
      (?: $RE{net}{IPv4} )
   )
\Z/msx;

my $fqhn_regex = qr/\A $RE{net}{domain}{-nospace}{-rfc1101}\.? \Z/x;

# Get FQHN hostname
my $fqhn = hostname_long();
warn 'FQDN is '.$fqhn;

# Get IP from FQHN
my $ip = _get_ip( $fqhn );
warn 'ip is '.$ip;

# Now PTR lookup ip using DeltaR's prod subroutine.
my $ptr_fqhn  = DeltaR::Query::_get_ptr( $ip );
warn 'final hostname is '.$ptr_fqhn;

like( $fqhn,     $fqhn_regex, 'Sys::Hostname::Long Can resolve hostname' );
like( $ip,       $ip_regex,   'Can resolve ip address' );
like( $ptr_fqhn, $fqhn_regex, 'DeltaR::Query::_get_ptr returns fqhn' );

#
# subs
#
sub _get_ip {
	my $fqhn = shift;
	my $query;
	my $res = Net::DNS::Resolver->new;


	# Try AAAA first, because modules will do this automatically.
	$query = $res->query( $fqhn, 'AAAA' );
	if ($query) {
		foreach my $rr ($query->answer) {
			next unless $rr->type eq "AAAA";
			return $rr->address;
		}
	}

	# Now try A. 
	undef $query;
	$query = $res->query( $fqhn, 'A' );
	if ($query) {
		foreach my $rr ($query->answer) {
			next unless $rr->type eq "A";
			return $rr->address;
		}
	}
	
   return 'unknow';
}

	

=pod

=head1 SYNOPSIS

This file test network functions.

=head1 LICENSE

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2013 Evolve Thinking http://evolvethinking.com

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

=cut


