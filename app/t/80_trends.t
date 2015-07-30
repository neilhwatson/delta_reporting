use strict;
use warnings;
use Test::More;
use Test::Mojo;
use Storable;
use Regexp::Common qw/number/;

my $data_file = '/tmp/delta_reporting_test_data';
my $stored = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

my $stats_table_body_regex = qr{
   <td>\s*Correlation\s*</td>
   .*
   <td>\s*$RE{num}{real}\s*</td>
   .*
   <td>\s*Intercept\s*</td>
   .*
   <td>\s*$RE{num}{real}\s*</td>
   .*
   <td>\s*Slope\s*</td>
   .*
   <td>\s*$RE{num}{real}\s*</td>
   .*
   <td>\s*Stderr\s*</td>
   .*
   <td>\s*$RE{num}{real}\s*</td>
}misx;

my $t = Test::Mojo->new('DeltaR');
$t->ua->max_redirects(1);

my %trend_report = (
   kept     => 'kept',
   notkept  => 'not kept',
   repaired => 'repaired'
);

for my $next_report ( keys %trend_report ) {
   my $promise_column = qr/$trend_report{$next_report}/i;

   $t->get_ok("/trend/$next_report")
      ->status_is(200)

      ->element_exists( 'html head title' => "promises $trend_report{$next_report} trend",
         "/trend/$next_report has wrong title" )

      ->content_like( qr{
         <th>Promises</th>
         .*
         <th>Value</th>
         .*
         $stats_table_body_regex
         }misx, "/trend/$next_report Promises stats table" )
    
      ->content_like( qr{
         <th>Hosts</th>
         .*
         <th>Value</th>
         .*
         $stats_table_body_regex
         }misx, "/trend/$next_report Hosts stats table" )
      
      ->content_like( qr{
         <th.*?>\s*Date\s*</th>
         .*
         <th.*?>\s*Hosts\s*</th>
         .*
         <th.*?>\s*$promise_column\s*</th>
         .*
         <td>$stored->{data}{datestamp_yesterday}</td>
      }misx, "/trend/$next_report Raw data" )

      ->text_like( 'html body div script' => qr/dataTable/,
         "/trend/$next_report dataTable script" )

      ->content_like( qr{
         var
         \s+
         dr_data \s+ = \s+\[\{ \S* "slope": $RE{num}{real}
         }msix,
         "trend/$next_report dr_data javascript variable");
}

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
