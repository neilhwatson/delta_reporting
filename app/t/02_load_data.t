use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );

my $t = Test::Mojo->new('DeltaR');

sub build_client_log
{
   my $log_file = '/tmp/2001:db8::2.log';
   my $timestamp = strftime "%Y-%m-%dT%H:%m:%S%z", localtime; 

   open( my $fh, ">", $log_file ) or die
      "Cannot open [$log_file], [$!]";

   foreach my $line (<data>)
   {
      write $timestamp. ' ;; '. $line or die "Cannot write log, [$!]";
   }
   close $fh;

   return 0;
}

my $log = build_client_log();
$t = $t->success($log);

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

# timestamp ;; class ;; promise_handle ;; promiser ;; promise_outcome ;; promisee
# Insert timestamp dynamically ( 2014-06-29T14:33:49-0400 )
__DATA__
dr_test_class ;; empty ;; empty ;; empty ;; empty
dr_test_kept ;; handle_dr_test ;; /etc/dr_test ;; ;; kept ;; mojolicious
