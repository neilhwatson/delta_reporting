use lib './lib';
use Test::More;
use Test::Mojo;
use Storable;
use Regexp::Common q/net/;
use strict;
use warnings;

  
# duplicate of test data from load test
my %test_params = (
   class => 'dr_test_class'
);

my $data_file = '/tmp/delta_reporting_test_data';
my $shared_data = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

# Regex of returned web content for later testing
my $html_table_content = qr(
   <td>$test_params{class}</td>
   .*
   <td>$shared_data->{data}{timestamp_regex}</td>
)msix;

# Params to use for test queries
my $query_params = {
   report_title  => 'DR test suite',
   class         => 'any;',
   hostname      => 'ettin;',
   ip_address    => '10.com',
   policy_server => '; DELETE FROM',
   timestamp     => '$400;',
   gmt_offset    => '\\;400; EXIT',
   delta_minutes => '; DROP TABLES',
};

my @input_errors = ( qw/
   class
   delta_minutes
   gmt_offset
   hostname
   ip_address
   policy_server
   timestamp
/);

# Test invalid CLI query params.
subtest 'Invalid CLI input' => sub {
   my @args;
   for my $next_param ( keys %{ $query_params } )
   {
      next if ( $next_param eq 'report_title' );
      push @args, '--'.$next_param, "\'$query_params->{$next_param}\'";
   }

   # Build command line and send results to a file
   my $command_output_file = '/tmp/'.$$.'_command_output_file';
   my $command = './script/query '
      . join( ' ', @args ) .' 2>&1 1>'
      . $command_output_file;
   ok ( system( $command ), 'CLI should return none zero status' )
      or warn "not ok .... CLI query command [$command]"
      . " did NOT return false [$?].";

   # Read command output and test its contents
   open my $fh, "$command_output_file"
      or warn "Cannot open [$command_output_file] [$!]";
   my $command_output = do { local $/, <$fh> };
   close $fh;
   unlink "$command_output_file";

   # Test command output against expected errors
   for my $next_error ( @input_errors ) {
      like( $command_output, qr/
         \QERROR: These inputs for Validator::\E .* $next_error /msx
         , "CLI query classes [$next_error]"
      )
         or warn "Failure in CLI query classes [$next_error]";
   }
   done_testing();
};

# Start web ui testing
my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

# Feed class input form with error triggering params and test results
$t->post_ok( '/report/classes' => form => $query_params )
   ->status_is(200)
   ->content_like( qr/\QERROR: These inputs for Validator::\E/
      , "/report/classes error header" )
   ->content_like( qr/class/i
      , '/report/classes class input error' )
   ->content_like( qr/hostname/i
      , '/report/classes hostname input error' )
   ->content_like( qr/ip_address/i
      , '/report/classes ip_address input error' )
   ->content_like( qr/policy_server/i
      , '/report/classes policy_server input error' )
   ->content_like( qr/timestamp/i
      , '/report/classes timestamp input error' )
   ->content_like( qr/gmt_offset/i
      , '/report/classes gmt_offset input error' )
   ->content_like( qr/delta_minutes/i
      , '/report/classes delta_minutes input error' )
;


# Web Query for record stamped less than one minute ago
$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => $shared_data->{data}{ip_address},
      policy_server => '%',
      latest_record => 0,
      timestamp     => $shared_data->{data}{query_timestamp},
      gmt_offset    => $shared_data->{data}{gmt_offset},
      delta_minutes => '-1',
   })
# Test returned results
   ->status_is(200)
   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/classes last minute minus delta dataTable script' )
   ->content_like( $html_table_content
      , '/report/classes dr_test_class last minute with minus delta' );

# Web Query for record stamped less than one minute ago, but using +1 delta
$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => $shared_data->{data}{ip_address},
      policy_server => '%',
      latest_record => 0,
      timestamp     => $shared_data->{data}{timestamp_less_minute},
      gmt_offset    => $shared_data->{data}{gmt_offset},
      delta_minutes => '+1',
   })
# Test returned results
   ->status_is(200)
   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/classes last minute plus delta dataTable script' )
   ->content_like( $html_table_content
      , '/report/classes dr_test_class last minute with plus delta' );

# Web query for the lastest known record
$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => $shared_data->{data}{ip_address},
      policy_server => '%',
      latest_record => 1,
   })

# Test returned results
   ->status_is(200)
   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/classes latest record dataTable script' )
   ->content_like( $html_table_content, '/report/classes dr_test_class latest record' );

# Cli query for record class stamped less than minute ago
my $query_command = "script/query"
   . " -c $test_params{class}"
   . " -ip $shared_data->{data}{ip_address}"
   . " -t '$shared_data->{data}{query_timestamp}$shared_data->{data}{gmt_offset}'"
   . " -d -1";
my $query_results = qx{ $query_command };

# Test returned results
like( $query_results, qr{
   Class \s+ Time \s+ Hostname \s+ IP \s Address \s+ Policy \s Server # Head
   \s+ ---------------------------------------------------------[-]+ # Head line
   \s+ dr_test_class                    # class 
   \s+ $shared_data->{data}{date_regex} # date/time
   \s+ unknown                          # hostname
   \s+ 2001:db8::2                      # ip address
   \s+ $RE{net}{domain}{-nospace}       # domain name
   }mxs,

   "Check CLI output for last minute class memberhsip"
);

# Cli query for latest known record
$query_command = "script/query"
   . " -c $test_params{class}"
   . " -ip $shared_data->{data}{ip_address}"
   . " -l";
$query_results = qx{ $query_command };

# Test returned results
like( $query_results, qr{
   Class \s+ Time \s+ Hostname \s+ IP \s Address \s+ Policy \s Server # Head
   \s+ ---------------------------------------------------------[-]+ # Head line
   \s+ dr_test_class                    # class 
   \s+ $shared_data->{data}{date_regex} # date/time
   \s+ unknown                          # hostname
   \s+ 2001:db8::2                      # ip address
   \s+ $RE{net}{domain}{-nospace}       # domain name
   }mxs,

   "Check CLI output for last minute class memberhsip"
);

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
