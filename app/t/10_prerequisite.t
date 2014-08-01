use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Storable;
use File::Copy 'copy';

my $timestamp           = strftime "%Y-%m-%dT%H:%M:%S%z", localtime; 
my $datestamp_yesterday = strftime "%Y-%m-%d", localtime( time - 60**2 *24 );

my %stored = (
   file => '/tmp/delta_reporting_test_data',
   data =>
   {
      log_timestamp       => $timestamp,
      datestamp_yesterday => $datestamp_yesterday,
      subnet              => '2001:db8::',
      ip_address          => '2001:db8::1',
      config              => 'DeltaR.conf',
   }
);

sub store_test_data
{
   my $data = shift;
   if ( store $data, $data->{file} )
   {
      return 1;
   }
   else
   {
      warn "could not store data in [$data->{file}], [$!]";
      return;
   }
}

sub build_test_conf
{
   my $conf = $stored{data}{config};
   copy( $conf, "$conf.backup" ) or do
   {
      warn "Cannot backup [$stored{data}{config}], [$!]";
      return;
   };

   open( FH, '>', $conf ) or do
   {
      warn "Cannot open [$conf], [$!]";
      return;
   };

   foreach my $line (<DATA>)
   {
      print FH $line or do
      {
         warn "Cannot write [$line] to [$conf], [$!]";
         return;
      };
   }
   close FH;
   return 1
}

#
# Main matter
#
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
else
{
   die "Could not parse timestamp [$timestamp] for storage.";
}

ok( store_test_data( \%stored ), "Store shared test data" )
   or BAIL_OUT( "Failed to backup [$stored{data}{config}]" );
ok( build_test_conf(), "Build test configuration" )
   or BAIL_OUT( "Failed to build [$stored{data}{config}]" );

my $t = Test::Mojo->new( 'DeltaR' );

my $config = $t->app->plugin( 'config', file => 'DeltaR.conf' );
ok( $config->{db_name} eq 'delta_reporting_test', 'Confirm config test database' )
   or BAIL_OUT( "Config test failed" );

$t->ua->max_redirects(1);
$t->get_ok( '/initialize_database' ) ->status_is(200);

done_testing();

=pod

=head1 SYNOPSIS

This file stores shared data for other tests.

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

__DATA__
# This is a temp config for the test plan.

{
   db_name         => "delta_reporting_test",
   db_user         => "postgres",
   db_pass         => "",
   db_host         => "127.0.0.1",
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
      listen         => [ 'http://<ip>:8080' ],
   },
};
