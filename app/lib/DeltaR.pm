package DeltaR;
use Mojo::Base qw( Mojolicious );

use strict;
use warnings;
use DeltaR::Query;
use DeltaR::Graph;
use POSIX qw( strftime );
use DBI;

sub startup
{
   my $self = shift;
   my $config = $self->plugin('config', file => 'DeltaR.conf' );
   my $gmt_offset   = strftime "%z", localtime;
   my $record_limit = $config->{record_limit};
   my $inventory_limit = $config->{inventory_limit};

   push @{$self->commands->namespaces}, 'DeltaR::Command';

   $self->helper( dbh => sub
   {
      my $self = shift;
      my $db_name = $config->{db_name};
      my $db_user = $config->{db_user};
      my $db_pass = $config->{db_pass};
      my $db_host = $config->{db_host};

      my $dbh = DBI->connect(
            "DBI:Pg:dbname=$db_name; host=$db_host",
            "$db_user", "$db_pass",
            { RaiseError => 1 }
      );
      
      return $dbh;
   });

   $self->helper( dr => sub
   {
      my $self = shift;
      my $dq = DeltaR::Query->new( 
         agent_table     => $config->{agent_table},
         promise_counts  => $config->{promise_counts},
         inventory_table => $config->{inventory_table},
         inventory_limit => $config->{inventory_limit},
         db_user         => $config->{db_user},
         db_name         => $config->{db_name},
         delete_age      => $config->{delete_age},
         reduce_age      => $config->{reduce_age},
         record_limit    => $record_limit,
         dbh             => $self->app->dbh,
      );
      return $dq
   });

   my $r = $self->routes;

   $r->any( '/' => 'home' );

   $r->any( '/help' => sub
   {
      my $self = shift;
      $self->stash( title => "Delta Reporting Help" );
   } => 'help');

   $r->any( '/about' => sub 
   {
      my $self = shift;
      my $dq = $self->app->dr;
      my $number_of_records = $dq->count_records;
      $self->stash(
         title => "About Delta Reporting",
         number_of_records => $number_of_records );
      
   } => 'about');

   $r->get( '/trend/hosts' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      my @columns = qw/Date Hosts/;
      my $rows = $dq->query_hosts_trend( 'hosts' );
   
      my $gr = DeltaR::Graph->new();
      $gr->trends( 
         keys => \@columns,
         data => $rows
      );

      print Dumper( @columns );
      $self->stash(
         title   => "Hosts count and trend",
         rows    => $rows,
         columns => \@columns 
      );
   } => 'trend');

   $r->get( '/missing' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      my $rows = $dq->query_missing();

      $self->stash(
         title        => "Missings host from the past 24 hours",
         record_limit => $record_limit,
         rows         => $rows,
         columns      => [ 'Hostname', 'IP Address', 'Policy server' ]
      );
   } => 'rtable');


   $r->get( '/inventory' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      my $rows = $dq->query_inventory();

      $self->stash(
         title        => "Inventory report",
         record_limit => $record_limit,
         rows         => $rows,
         columns      => [ 'Class','Count' ]
      );
   } => 'rtable');

   $r->get( '/promises' => sub
   {
      my $self = shift;
      my $timestamp    = strftime "%F %T", localtime;
      $self->stash(
         record_limit => $record_limit,
         timestamp    => $timestamp,
         gmt_offset   => $gmt_offset
      );
   } => 'promises');

   $r->post( '/report_promises' => sub
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
      
      $self->stash(
         title        => $self->param('report_title'),
         record_limit => $record_limit,
         rows         => $rows,
         columns      => [ 'Promiser', 'Promisee', 'Promise handle', 'Promise outcome',
            'Timestamp', 'Hostname','IP Address','Policy Server' ]
      );
   } => "rtable");

   $r->get( '/classes' => sub
   {
      my $self = shift;
      my $timestamp    = strftime "%F %T", localtime;
      $self->stash(
         record_limit => $record_limit,
         timestamp    => $timestamp,
         gmt_offset   => $gmt_offset
      );
   } => 'classes');

   $r->post( '/report_classes' => sub
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
      
      $self->stash(
         title        => $self->param('report_title'),
         record_limit => $record_limit,
         rows         => $rows,
         columns      => [ 'Class','Timestamp','Hostname','IP Address','Policy Server' ]
      );
   } => "rtable");

   $r->get( '/initialize_database' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      $dq->create_tables;
   } => '/database_initialized');

   $r->get( '/database_initialized' => 'database_initialized');

}

1;
