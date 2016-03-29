package DeltaR::Report;

use Mojo::Base 'Mojolicious::Controller';
use DeltaR::Validator;

sub missing
{
   my $self = shift;
   my $rows = $self->app->dr->query_missing();

   $self->render(
      title       => "Missing hosts",
      small_title => "not seen in 24 hours",
      rows        => $rows,
      columns     => [ 'Hostname', 'IP Address', 'Policy server' ],
      template    => 'report/rtable',
   );
   return;
}

sub inventory
{
   my $self = shift;
   my $rows = $self->app->dr->query_inventory();

   $self->render(
      title       => 'Inventory report',
      small_title => "from the past ". $self->app->config->{inventory_limit} ." minutes",
      rows        => $rows,
      columns     => [ 'Class','Count' ],
      template    => 'report/rtable',
   );
   return;
}

sub classes
{
   my $self = shift;
   my %query_params;
   my $latest_record = 0;

   if ( $self->param('latest_record') )
   {
      $latest_record = $self->param('latest_record');
   }
   else
   {
      %query_params = (
         timestamp     => $self->param('timestamp'),
         gmt_offset    => $self->param('gmt_offset'),
         delta_minutes => $self->param('delta_minutes'),
      );
   }

   %query_params = (
      %query_params,
      class         => $self->param('class'),
      hostname      => $self->param('hostname'),
      ip_address    => $self->param('ip_address'),
      policy_server => $self->param('policy_server'),
      latest_record => $latest_record,
   );

   # Validate user input
   my $delta_validator
      = DeltaR::Validator->new({ input => \%query_params });
   my @validator_errors = $delta_validator->class_query_form();
   if ( (scalar @validator_errors) > 0 ) {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@validator_errors 
      );
      return $self->render( template => 'error', format => 'html' );
   }

   # Truncate long fields to guard against overflow.
   for my $next_field ( keys %query_params ) {
      $query_params{ $next_field }
         = substr( $query_params{ $next_field }, 0, 250 );
   }

   my $rows = $self->app->dr->query_classes( \%query_params );
   
   $self->render(
      title    => $self->param('report_title'),
      rows     => $rows,
      columns  => [ 'Class','Timestamp','Hostname','IP Address','Policy Server' ],
      template => 'report/rtable',
   );
   return;
}

sub promises
{
   my $self = shift;
   my %query_params;
   my $latest_record = 0;

   if ( $self->param('latest_record') )
   {
      $latest_record = $self->param('latest_record');
   }
   else
   {
      %query_params = (
         timestamp     => $self->param('timestamp'),
         gmt_offset    => $self->param('gmt_offset'),
         delta_minutes => $self->param('delta_minutes'),
      );
   }

   %query_params = (
      %query_params,
      promiser        => $self->param('promiser'),
      promisee        => $self->param('promisee'),
      promise_handle  => $self->param('promise_handle'),
      promise_outcome => $self->param('promise_outcome'),
      hostname        => $self->param('hostname'),
      ip_address      => $self->param('ip_address'),
      policy_server   => $self->param('policy_server'),
      latest_record   => $latest_record,
   );

   # Validate user input
   my $delta_validator
      = DeltaR::Validator->new({ input => \%query_params });
   my @validator_errors = $delta_validator->promise_query_form();
   if ( (scalar @validator_errors) > 0 ) {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@validator_errors 
      );
      return $self->render( template => 'error', format => 'html' );
   }

   # Truncate long fields to guard against overflow.
   for my $next_field ( keys %query_params ) {
      $query_params{ $next_field }
         = substr( $query_params{ $next_field }, 0, 250 );
   }

   my $rows = $self->app->dr->query_promises( \%query_params );
   
   $self->render(
      title    => $self->param('report_title'),
      rows     => $rows,
      columns  => [ 'Promiser', 'Promisee', 'Promise handle', 'Promise outcome',
         'Timestamp', 'Hostname','IP Address','Policy Server' ],
      template => 'report/rtable',
   );
   return;
}

1;

=pod

=head1 SYNOPSIS

This module contains subs for generating and populating report tables.

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
