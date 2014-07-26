use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Data::Dumper;

my $log_file = '/tmp/2001:db8::2.log';
my $timestamp = strftime "%Y-%m-%dT%H:%M:%S%z", localtime; 

sub build_client_log
{
   open( FH, ">", $log_file ) or do
      { 
         warn "Cannot open [$log_file], [$!]";
         return 1;
      };
      
   foreach my $line (<DATA>)
   {
      $line = $timestamp. ' ;; '. $line;
      print FH $line or do
         {
            warn "Cannot write log, [$!]";
            return 2;
         };
   }
   close FH;
   return 0;
}

sub insert_data_from_client_log
{
   my $load_cmd = "./script/load '$log_file'";
   my $return = system( $load_cmd );
   unlink $log_file or warn "Cannot unlink  [$log_file]";
   if ( $return != 0 )
   {
      warn "Error $load_cmd return status [$return]"
   }
   return $return;
}

ok( build_client_log()             == 0, 'Build client log' );
ok( insert_data_from_client_log()  == 0, 'Insert client log' );

done_testing();

=pod

=head1 SYNOPSIS

This is for testing the loading of client data.

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
