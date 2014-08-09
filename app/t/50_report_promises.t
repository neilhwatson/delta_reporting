use Test::More;
use Test::Mojo;
use Storable;

my %test_params = (
   # A copy of the test data that was inserted.
   promiser        => '/etc/dr_test_kept',
   promise_outcome => 'kept',
   promisee        => 'mojolicious',
   promise_handle  => 'handle_dr_test',
);

$data_file = '/tmp/delta_reporting_test_data';
my $stored = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

my $content = qr(
      <td>$test_params{promiser}</td>
      .*
      <td>$test_params{promisee}</td>
      .*
      <td>$test_params{promise_handle}</td>
      .*
      <td>$test_params{promise_outcome}</td>
      .*
      <td>$stored->{data}{timestamp_regex}</td>
)msix;

my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => $stored->{data}{ip_address},
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 0,
      timestamp       => $stored->{data}{query_timestamp},
      gmt_offset      => $stored->{data}{gmt_offset},
      delta_minutes   => -1
   })
   ->status_is(200)

   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/promises last munute dataTable script' )

   ->content_like( $content, '/report/promises dr_test last minute' ); 

$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => $stored->{data}{ip_address},
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 1,
   })
   ->status_is(200)

   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/promises latest record dataTable script' )

   ->content_like( $content, '/report/promises dr_test latest record' );

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
