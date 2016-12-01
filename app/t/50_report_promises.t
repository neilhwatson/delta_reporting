use lib './lib';
use Test::More;
use Test::Mojo;
use Storable;
use Regexp::Common q/net/;
use strict;
use warnings;

my %test_params = (
   # A copy of the test data that was inserted.
   promiser        => '/etc/dr_test_kept',
   promise_outcome => 'kept',
   promisee        => 'mojolicious',
   promise_handle  => 'handle_dr_test',
);

my $data_file = '/tmp/delta_reporting_test_data';
my $shared_data = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

my $html_table_content = qr(
      <td>$test_params{promiser}</td>
      .*
      <td>$test_params{promisee}</td>
      .*
      <td>$test_params{promise_handle}</td>
      .*
      <td>$test_params{promise_outcome}</td>
      .*
      <td>$shared_data->{data}{timestamp_regex}</td>
)msix;

my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

$t->post_ok( '/report/promises' =>
   form => {
      report_title     => 'DR test suite',
      promiser         => '\\;',
      promisee         => '\\;',
      promise_outcome  => '\\;',
      promise_handle   => 'my-handle',
      class            => 'any;',
      hostname         => 'ettin;',
      ip_address       => '10.com',
      policy_server    => '; DELETE FROM',
      latest_record    => 0,
      timestamp        => '$400;',
      gmt_offset       => '\\;400; EXIT',
      delta_minutes    => '; DROP TABLES',
   })
   ->status_is(200)
   ->content_like( qr/\QERROR: These inputs for Validator::\E/
      , '/repot/promises error header' )
   ->content_like( qr/promiser/i
      , '/report/promises promiser input error' )
   ->content_like( qr/promisee/i
      , '/report/promises promisee input error' )
   ->content_like( qr/promise_outcome/i
     , '/report/promises promise_outcome input error' )
   ->content_like( qr/promise_handle/i
     , '/report/promises promise_handle input error' )
   ->content_like( qr/class/i
     , '/report/promises class input error' )
   ->content_like( qr/hostname/i
     , '/report/promises hostname input error' )
   ->content_like( qr/ip_address/i
     , '/report/promises ip_address input error' )
   ->content_like( qr/policy_server/i
     , '/report/promises policy_server input error' )
   ->content_like( qr/timestamp/i
     , '/report/promises timestamp input error' )
   ->content_like( qr/gmt_offset/i
     , '/report/promises gmt_offset input error' )
   ->content_like( qr/delta_minutes/i
     , '/report/promises delta_minutes input error' )
   ;

# Web query for a promise status in the past minute
$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => $shared_data->{data}{ip_address},
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 0,
      timestamp       => $shared_data->{data}{query_timestamp},
      gmt_offset      => $shared_data->{data}{gmt_offset},
      delta_minutes   => -1
   })

# Test the query results
   ->status_is(200)
   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/promises last minute dataTable script' )
   ->content_like( $html_table_content, '/report/promises dr_test last minute' ); 

# Web query for a promise status, the last known record
$t->post_ok( '/report/promises' =>
   form => {
      report_title    => 'DR test suite',
      promiser        => $test_params{promiser},
      hostname        => '%',
      ip_address      => $shared_data->{data}{ip_address},
      policy_server   => '%',
      promise_outcome => $test_params{promise_outcome},
      promisee        => $test_params{promisee},
      promise_handle  => $test_params{promise_handle},
      latest_record   => 1,
   })

# Test the query results
   ->status_is(200)
   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/promises latest record dataTable script' )
   ->content_like( $html_table_content, '/report/promises dr_test latest record' );

# Cli query for promise stamped less than minute ago
my $query_command = "script/query"
   . " -pr $test_params{promiser}"
   . " -ip $shared_data->{data}{ip_address}"
   . " -po $test_params{promise_outcome}"
   . " -pe $test_params{promisee}"
   . " -ph $test_params{promise_handle}"
   . " -t '$shared_data->{data}{query_timestamp}$shared_data->{data}{gmt_offset}'"
   . " -d -1";
my $query_results = qx{ $query_command };

# Test query results
like( $query_results, qr{
   # Table header
   Promiser \s+ Promisee \s+ Promise \s handle \s+ Promise \s outcome
   \s+ Timestamp \s+ Hostname \s+ IP \s address \s+ Policy \s server
   \s+ ---------------------------------------------------------[-]+
   # Table data
   \s+ /etc/dr_test_kept                # promiser 
   \s+ mojolicious                      # promisee 
   \s+ handle_dr_test                   # promise handle
   \s+ kept                             # promise outcome
   \s+ $shared_data->{data}{date_regex} # date/time
   \s+ unknown                         # hostname
   \s+ 2001:db8::2                     # ip address
   \s+ $RE{net}{domain}{-nospace}      # domain name
   }mxs,

   "Check CLI output for last minute promise report"
);

# Cli query for the lasted known status of a promise
$query_command = "script/query"
   . " -pr $test_params{promiser}"
   . " -ip $shared_data->{data}{ip_address}"
   . " -po $test_params{promise_outcome}"
   . " -pe $test_params{promisee}"
   . " -ph $test_params{promise_handle}"
   . " -l";
$query_results = qx{ $query_command };

# Test query results
like( $query_results, qr{
   # Table header
   Promiser \s+ Promisee \s+ Promise \s handle \s+ Promise \s outcome
   \s+ Timestamp \s+ Hostname \s+ IP \s address \s+ Policy \s server
   \s+ ---------------------------------------------------------[-]+
   # Table data
   \s+ /etc/dr_test_kept                # promiser 
   \s+ mojolicious                      # promisee 
   \s+ handle_dr_test                   # promise handle
   \s+ kept                             # promise outcome
   \s+ $shared_data->{data}{date_regex} # date/time
   \s+ unknown                         # hostname
   \s+ 2001:db8::2                     # ip address
   \s+ $RE{net}{domain}{-nospace}      # domain name
   }mxs,

   "Check CLI output for last minute class memberhsip"
);

done_testing();

=pod

=head1 SYNOPSIS

This is for testing a promise report. It queries for the promise loaded in a
previous test.

=head1 LICENSE

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2016 Neil H. Watson http://watson-wilson.ca

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
