use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Storable;

my $data_file = '/tmp/delta_reporting_test_data';
my $stored = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

my $t = Test::Mojo->new('DeltaR');
$t->ua->max_redirects(1);

$t->get_ok('/report/pps')
   ->status_is(200)

   ->element_exists( 'html head title' => 'Promises percent summary',
      '/report/pps has wrong title' )

   ->content_like( qr{
      <th.*?>\s*Date\s*</th>
      .*
      <th.*?>\s*Hosts\s*</th>
      .*
      <th.*?>\s*Kept\s*</th>
      .*
      <th.*?>\s*Repaired\s*</th>
      .*
      <th.*?>\s*Not\skept\s*</th>
      .*
      <td>$stored->{data}{datestamp_yesterday}</td>
   }misx, '/report/pps Raw data' )

   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/pps dataTable script' )

   ->content_like( qr{ var \s+ pps_data \s+ = \s+ \[ \s* \{ \S*"key":"Kept"
      }msix,
      '/report/pps pps_data javascript variable')

   ->content_like( qr{ var \s+ host_data \s+ = \s+ \[ \s* \{ \S* "key":"Hosts"
      }msix,
      '/report/pps host_data javascript variable');

done_testing();

=pod

=head1 SYNOPSIS

This is for testing the trend reports.

=head2 Requirements

Relies on the test data inserted in the database in a previous test.

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
