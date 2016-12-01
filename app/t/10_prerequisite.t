use lib './lib';
use Test::More;
use Test::Exception;
use Test::Mojo;
use POSIX( 'strftime' );
use Storable;
use feature 'say';
use strict;
use warnings;

my $timestamp           = strftime "%Y-%m-%dT%H:%M:%S%z", localtime; 
my $datestamp_yesterday = strftime "%Y-%m-%d", localtime( time - 60**2 *24 );
my $timestamp_less_minute = strftime "%Y-%m-%d %H:%M:%S", localtime( time - 60 );

my @config_data = <DATA>;

my %stored = (
   file => '/tmp/delta_reporting_test_data',
   data =>
   {
      log_timestamp       => $timestamp,
      datestamp_yesterday => $datestamp_yesterday,
      subnet              => '2001:db8::',
      missing_ip_address  => '2001:db8::1',
      ip_address          => '2001:db8::2',
      config              => 'DeltaR.conf',

# Matching 2015-07-30 13:02:22-04 style date stamps
# Must store as a string because Storable cannot store regexp
      date_regex          => q{
         \d{4}-\d{2}-\d{2}  # Year
         \s
         \d{2}:\d{2}:\d{2}  # Time
         [+-]\d{2,4}        # Timezone
      },
   }
);

sub store_test_data {
   my $data = shift;

   store( $data, $data->{file} ) or
      die "could not store data in [$data->{file}], [$!]";

   return 1;
}

sub build_test_conf {
   my $invalid_db_name = shift;
   my $conf = $stored{data}{config};

   open( my $conf_file, '>', $conf ) or die "Cannot open [$conf], [$!]";

   for my $next_line (@config_data) {

      # Insert broken db name if given
      if ( defined $invalid_db_name and $next_line =~ m/\s+db_name\s+/ ) {
         print $conf_file qq{db_name => "$invalid_db_name",\n}
            or die "Cannot write [$next_line] to [$conf], [$!]";
      }
      else {
         print $conf_file $next_line
            or die "Cannot write [$next_line] to [$conf], [$!]";
      }
   }
   close $conf_file;
   return 1
}

#
# Main matter
#

## Build and store shared data
if ( $timestamp =~ m/ \A
   ( \d{4}-\d{2}-\d{2} ) # Date
   T
   ( \d{2}:\d{2}:\d{2} ) # hh:mm:ss
   ( [-+]{1}\d{4} )      # GMT offset
   \Z
   /x )
{
   $stored{data}{query_timestamp} = "$1 $2";
   $stored{data}{datestamp}       = "$1";
   $stored{data}{timestamp_regex} = $1.'\s'.$2.'[-+]{1}\d{2,4}';
   $stored{data}{gmt_offset}      = $3;
}
else {
   die "Could not parse timestamp [$timestamp] for storage.";
}
$stored{data}{timestamp_less_minute} = $timestamp_less_minute;

ok( store_test_data( \%stored ), "Store shared test data" )
   or BAIL_OUT( "Failed to backup [$stored{data}{config}]" );

# Test invalid config validation
my $invalid_db_name = 'Illegal ; #$&db name';
build_test_conf( $invalid_db_name );
ok( ! eval { Test::Mojo->new( 'DeltaR' ) }, "Validator must fail" );

## Load proper config 
build_test_conf();

## Load app 
my $t = Test::Mojo->new( 'DeltaR' );

ok( $t->app->config->{db_name} eq 'delta_reporting_test'
   , 'Confirm config test database' )
   or BAIL_OUT( "Config test failed" );

## Initialize test database
$t->ua->max_redirects(1);
lives_and {
   $t->get_ok( '/initialize_database' )
   ->status_is( 200, 'Initialize database' )->or( sub {
      warn "Initialize database error ".$t->tx->res->body;
   });
} '/initialze_database';

done_testing();

=pod

=head1 SYNOPSIS

This file stores shared data for other tests.

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

__DATA__
# This is a temp config for the test plan.

{
   db_name         => "delta_reporting_test",
   db_user         => "deltar_ro",
   db_pass         => "",
   db_wuser        => "deltar_rw",
   db_wpass        => "",
   db_host         => "localhost",
   record_limit    => 1000, # Limit the number of records returned by a query.
   agent_table     => "agent_log",
   promise_counts  => "promise_counts",
   inventory_table => "inventory_table",
   inventory_limit => 20, # mintes to look backwards for inventory query
   client_log_dir  => "/var/cfengine/delta_reporting/log/client_logs",
   delete_age      => 90, # (days) Delete records older than this.
   reduce_age      => 10, # (days) Reduce duplicate records older than this to one per day

   hypnotoad       => {
      proxy          => 1,
      production     => 1,
      listen         => [ 'http://localhost:8080' ],
   },
};
