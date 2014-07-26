use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Data::Dumper;

=pod
The problem is that the regex is trying to match to the second, but
this timestamp is not the same as the timestamp from the load data
test. Must find a way to share the timestamp.
=cut

my $timestamp = strftime "%Y-%m-%dT%H:%M:%S%z", localtime;

my %test_params = (
   # A copy of the test data that was inserted.
   promiser        => '/etc/dr_test',
   promise_outcome => 'kept',
   promisee        => 'mojolicious',
   promise_handle  => 'handle_dr_test',
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

$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => '%',
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 0,
      timestamp       => $test_params{timestamp},
      gmt_offset      => $test_params{gmt_offset},
      delta_minutes   => -2
   })
   ->status_is(200)

   ->content_like( qr(
      <td>$test_params{promiser}</td>
      .*
      <td>$test_params{promisee}</td>
      .*
      <td>$test_params{promise_handle}</td>
      .*
      <td>$test_params{promise_outcome}</td>
      .*
      <td>
         $test_params{timestamp}
         [-+]{1}\d{2,4}
      </td>
      )msix
   , '/report/promises dr_test last minute' );

$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => '%',
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 1,
   })
   ->status_is(200)

   ->content_like( qr(
      <td>$test_params{promiser}</td>
      .*
      <td>$test_params{promisee}</td>
      .*
      <td>$test_params{promise_handle}</td>
      .*
      <td>$test_params{promise_outcome}</td>
      .*
      <td>
         $test_params{timestamp}
         [-+]{1}\d{2,4}
      </td>
      )msix
   , '/report/promises dr_test latest record' );

done_testing();

=pod

=head1 SYNOPSIS

This is for testing a promise report. It queries for the promise loaded in a
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
