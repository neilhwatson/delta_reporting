#!/usr/bin/env perl

use Test::More tests => 1;
use lib './lib';
use v5.10;
use strict;
use warnings;

my $tz = qx/ date '+%z' /;

like( $tz, qr/\A [+-]{1}\d{1,4} \Z/x, "date %z must return numeric timezone" );

=pod

=head1 SYNOPSIS

Test misc functions.

=head1 CAVEATS

AIX users may need to set env XPG_SUS_ENV=ON to get numeric timezone from
date '+%z'

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


