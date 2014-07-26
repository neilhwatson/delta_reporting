use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Storable;

my $shared    = retrieve( '/tmp/delta_reporting_test_data' );
my $log_file  = "/tmp/$shared->{data}{ip_address}.log";
my $timestamp = $shared->{data}{log_timestamp};

ok( defined $shared, 'Load shared data' );
ok( build_client_log(), 'Build client log' );
ok( insert_data_from_client_log(), 'Insert client log' );

done_testing();

sub build_client_log
{
   open( FH, ">", $log_file ) or do
      { 
         warn "Cannot open log file [$log_file], [$!]";
         return;
      };
      
   foreach my $line (<DATA>)
   {
      $line = $timestamp. ' ;; '. $line;
      print FH $line or do
      {
         warn "Cannot write [$line] to [$log_file], [$!]";
         return;
      };
   }
   close FH;
   return 1;
}

sub insert_data_from_client_log
{
   my $load_cmd = "./script/load '$log_file'";
   my $return = system( $load_cmd );
   unlink $log_file or warn "Cannot unlink  [$log_file]";
   if ( $return != 0 )
   {
      warn "Error [$load_cmd] return status [$return]";
      return;
   }
   return 1;
}

=pod

=head1 SYNOPSIS

This is loads test data for later query tests.

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

## Test Data
# timestamp ;; class ;; promise_handle ;; promiser ;; promise_outcome ;; promisee
# Insert timestamp dynamically

__DATA__
dr_test_class ;; empty ;; empty ;; empty ;; empty
dr_test_kept ;; handle_dr_test ;; /etc/dr_test ;; kept ;; mojolicious
