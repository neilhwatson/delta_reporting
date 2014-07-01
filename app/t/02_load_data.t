use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Data::Dumper;

my %test_params;
my $log_file = '/tmp/2001:db8::2.log';
my $timestamp = strftime "%Y-%m-%dT%H:%M:%S%z", localtime; 

# TODO set query time ahead a few seconds?
if ( $timestamp =~ m/ \A
   ( \d{4}-\d{2}-\d{2} ) # Date
   T
   ( \d{2}:\d{2}:\d{2} ) # Timestamp
   ( [-+]{1}\d{4} )      # GMT offset
   \Z
   /x )
{
   $test_params{timestamp} = "$1 $2";
   $test_params{gmt_offset} = $3;
}
print STDERR Dumper( %test_params );

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

sub insert_data
{
   my $load_cmd = "./script/load '$log_file'";
   my $return = system( $load_cmd );
   if ( $return != 0 )
   {
      warn "Error $load_cmd return status [$return]"
   }
   return $return;
}

ok( build_client_log() == 0, 'Build client log' );
ok( insert_data() == 0, 'Insert client log' );

my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => 'dr_test_class',
      hostname      => '%',
      ip_address    => '%',
      policy_server => '%',
      latest_record => 0,
      timestamp     => $test_params{timestamp},
      gmt_offset    => $test_params{gmt_offset},
      delta_minutes => -2
   })
   ->status_is(200)

   ->content_like( qr(
      <td>dr_test_class</td>
      \s*
      <td>$test_params{timestamp}.*?</td>
      )msix
   , '/report/classes dr_test_class ' );

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
