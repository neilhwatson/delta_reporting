package  DeltaR::Dashboard;

use Mojo::JSON 'encode_json';

our $dbh;

sub new {
   my ( $class, $arg ) = @_;
   $dbh = $arg->{dbh};
   return bless $arg, $class
}

use Data::Dumper;
sub hostcount {
   my ( $self ) = @_;

   my $class_members_ref = $dbh->query_inventory( 'cfengine' );
   $active_hosts = $class_members_ref->[0][1];

   my $missing_hosts = @{ $dbh->query_missing() };

   # Combine missing and active host counts as JSON
   my @hostcount = (
      {
         label => "Active",
         value => $active_hosts
      },
      {
         label => "Missing",
         value => $missing_hosts
      }
   );
   return encode_json( \@hostcount );
}

sub promisecount {
   my ( $self, $arg ) = @_;

      my @promise_counts = (
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

      my $promise_counts_ref
         = $dbh->query_recent_promise_counts( $arg->{newer_than} );

      NEXT_LABEL: for my $next_label ( @{ $promise_counts_ref } )
      {
         for my $next_promise_count ( @promise_counts )
         {
            if ( $next_label->[0] eq $next_promise_count->{label} )
            {
               $next_promise_count->{value} = $next_label->[1];
               next NEXT_LABEL;
            }
         }
      }
      return encode_json( \@promise_counts );
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
