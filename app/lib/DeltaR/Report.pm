package DeltaR::Report;

use Mojo::Base 'Mojolicious::Controller';

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

   my $errors = 
      $self->app->dr->validate_form_inputs( \%query_params );
   if ( @{ $errors } )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => $errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $self->app->dr->query_classes( \%query_params );
   
   $self->render(
      title    => $self->param('report_title'),
      rows     => $rows,
      columns  => [ 'Class','Timestamp','Hostname','IP Address','Policy Server' ],
      template => 'report/rtable',
   );
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

   my $errors =
      $self->app->dr->validate_form_inputs( \%query_params );
   if ( @{ $errors } )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => $errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $self->app->dr->query_promises( \%query_params );
   
   $self->render(
      title    => $self->param('report_title'),
      rows     => $rows,
      columns  => [ 'Promiser', 'Promisee', 'Promise handle', 'Promise outcome',
         'Timestamp', 'Hostname','IP Address','Policy Server' ],
      template => 'report/rtable',
   );
}

1;

=pod

=head1 SYNOPSIS

This module contains subs for generating and populating report tables.

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
