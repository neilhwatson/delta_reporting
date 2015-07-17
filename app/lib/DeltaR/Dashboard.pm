package  DeltaR::Dashboard;

use Mojo::JSON 'encode_json';

sub new
{
   my ( $class, $arg ) = @_;
   my $self = bless $arg, $class;
   return $self;
}

sub hostcount 
{
   my ( $self ) = @_;

   my $active = $self->{dr}->query_inventory( 'cfengine' );
   $active    = $active->[0][1];

   my $missing = @{ $self->{dr}->query_missing() };

   # Combine missing and active host counts as JSON
   my @hostcount = (
      {
         label => "Active",
         value => $active
      },
      {
         label => "Missing",
         value => $missing
      }
   );
   my $hostcount_json = encode_json( \@hostcount );
   return $hostcount_json;
}

sub promisecount
{
   my ( $self, $arg ) = @_;

      my @promise_count = (
         {
            label => 'kept',
            value => 0
         },
         {
            label => 'notkept',
            value => 0
         },
         {
            label => 'repaired',
            value => 0
         }
      );

      my $promise_count =
         $self->{dr}->query_recent_promise_counts( $arg->{from} );

      OUTER: for my $i  ( @{ $promise_count } )
      {
         for my $d ( @promise_count )
         {
            if ( $i->[0] eq $d->{label} )
            {
               $d->{value} = $i->[1];
               next OUTER;
            }
         }
      }
      my $promisecount_json = encode_json( \@promise_count );
      return $promisecount_json;
}

1;

=pod

=head1 SYNOPSIS

This module holds subs for dashboard data.

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
