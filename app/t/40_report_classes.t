use Test::More;
use Test::Mojo;
use Storable;

my %test_params = (
   # duplicate of test data from load test
   class => 'dr_test_class'
);

$data_file = '/tmp/delta_reporting_test_data';
my $stored = retrieve( $data_file ) or die "Cannot open [$data_file], [$!]";

my $content = qr(
   <td>$test_params{class}</td>
   .*
   <td>$stored->{data}{timestamp_regex}</td>
)msix;

my $t = Test::Mojo->new( 'DeltaR' );
$t->ua->max_redirects(1);

subtest 'Invalid webform input' => sub
{
      my $query_params = {
         report_title  => 'DR test suite',
         class         => 'any;',
         hostname      => 'ettin;',
         ip_address    => '10.com',
         policy_server => '; DELETE FROM',
         latest_record => 0,
         timestamp     => '$400;',
         gmt_offset    => '\\;400; EXIT',
         delta_minutes => '; DROP TABLES',
      };

      my @errors = 
      (
         {
            regex => qr/class.*not allowed/i,
            name => 'class input error'
         },
         {
            regex => qr/hostname.*not allowed/i,
            name => 'hostname input error'
         },
         {
            regex => qr/ip_address.*not allowed/i,
            name => 'ip_address input error'
         },
         {
            regex => qr/policy_server.*not allowed/i,
            name => 'policy_server input error'
         },
         {
            regex => qr/timestamp.*not allowed/i,
            name => 'timestamp input error'
         },
         {
            regex => qr/gmt_offset.*not allowed/i,
            name => 'gmt_offset input error'
         },
         {
            regex => qr/delta_minutes.*not allowed/i,
            name => 'delta_minutes input error'
         },
      );

   for my $error ( @errors )
   {
      $t->post_ok( '/report/classes' => form => $query_params )
         ->status_is(200)
         ->content_like( $error->{regex}, "/report/classes $error->{name}" );
   }
};

# TODO add command line negative testing.
$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => $stored->{data}{ip_address},
      policy_server => '%',
      latest_record => 0,
      timestamp     => $stored->{data}{query_timestamp},
      gmt_offset    => $stored->{data}{gmt_offset},
      delta_minutes => -1
   })
   ->status_is(200)

   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/classes last minute dataTable script' )

   ->content_like( $content, '/report/classes dr_test_class last minute' );

$t->post_ok( '/report/classes' =>
   form => {
      report_title  => 'DR test suite',
      class         => $test_params{class},
      hostname      => '%',
      ip_address    => $stored->{data}{ip_address},
      policy_server => '%',
      latest_record => 1,
   })
   ->status_is(200)

   ->text_like( 'html body div script' => qr/dataTable/,
      '/report/classes latest record dataTable script' )

   ->content_like( $content, '/report/classes dr_test_class latest record' );

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
