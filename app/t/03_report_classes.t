use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Data::Dumper;

# TODO new plan. Set time plus random minutes per test.
my $timestamp = strftime "%Y-%m-%dT11:11:11%z", localtime;

my %test_params = (
   # duplicate of test data from load test
   class => 'dr_test_class'
);

if ( $timestamp =~ m/ \A
   ( \d{4}-\d{2}-\d{2} ) # Date
   T
   ( \d{2}:\d{2}:\d{2} ) # hh:mm:ss
   ( [-+]{1}\d{4} )      # GMT offset
   \Z
   /x )
{
   $test_params{timestamp}    = "$1 $2";
   $test_params{gmt_offset}   = $3;
}


my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => '%',
      policy_server => '%',
      latest_record => 0,
      timestamp     => $test_params{timestamp},
      gmt_offset    => $test_params{gmt_offset},
      delta_minutes => -1
   })
   ->status_is(200)

   ->content_like( qr(
      <td>$test_params{class}</td>
      .*
      <td>
         $test_params{date}
         \s+
         $test_params{timestamp}
         [-+]{1}\d{2,4}
      </td>

      )msix
   , '/report/classes dr_test_class last minute' );

$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => '%',
      policy_server => '%',
      latest_record => 1,
   })
   ->status_is(200)

   ->content_like( qr(
      <td>$test_params{class}</td>
      .*
      <td>
         $test_params{date}
         \s+
         $test_params{timestamp}
         [-+]{1}\d{2,4}
      </td>

      )msix
   , '/report/classes dr_test_class latest record' );

done_testing();

=pod

=head1 SYNOPSIS

This is for testing a class report. It queries for the class loaded in a
previous test.

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
