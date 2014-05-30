package DeltaR::Report;

use Mojo::Base 'Mojolicious::Controller';

sub missing
{
   my $self = shift;
   my $dq = $self->app->dr;
   my $rows = $dq->query_missing();

   $self->render(
      title    => "Missings host from the past 24 hours",
      rows     => $rows,
      columns  => [ 'Hostname', 'IP Address', 'Policy server' ],
      template => 'report/rtable',
   );
}

sub inventory
{
   my $self = shift;
   my $dq = $self->app->dr;
   my $rows = $dq->query_inventory();

   $self->render(
      title    => "Inventory report",
      rows     => $rows,
      columns  => [ 'Class','Count' ],
      template => 'report/rtable',
   );
}

sub classes
{
   my $self = shift;
   my $dq = $self->app->dr;
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

   my @errors = $dq->validate( %query_params );
   if ( @errors )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $dq->query_classes( %query_params );
   
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
   my $dq = $self->app->dr;
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

   my @errors = $dq->validate( %query_params );
   if ( @errors )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $dq->query_promises( %query_params );
   
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

=cut
