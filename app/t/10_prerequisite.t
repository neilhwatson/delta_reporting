use Test::More;
use Test::Mojo;
use POSIX( 'strftime' );
use Storable;

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

#
# Main matter
#
my $timestamp = strftime "%Y-%m-%dT%H:%M:%S%z", localtime; 
my %stored = (
   file => '/tmp/delta_reporting_test_data',
   data =>
   {
      log_timestamp => $timestamp,
      ip_address    => '2001:db8::2',
   }
);

if ( $timestamp =~ m/ \A
   ( \d{4}-\d{2}-\d{2} ) # Date
   T
   ( \d{2}:\d{2}:\d{2} ) # hh:mm:ss
   ( [-+]{1}\d{4} )      # GMT offset
   \Z
   /x )
{
   $stored{data}{query_timestamp} = "$1 $2";
   $stored{data}{timestamp_regex} = $1.'\s'.$2.'[-+]{1}\d{2,4}';
   $stored{data}{gmt_offset}      = $3;
}
else
{
   die "Could not parse timestamp [$timestamp] for storage.";
}

ok( store_test_data( \%stored ), "Store shared test data" );

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
