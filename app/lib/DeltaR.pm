package DeltaR;

use Mojo::Base qw( Mojolicious );
use DeltaR::Graph;
use DeltaR::Query;
use DBI;

sub startup
{
   my $self = shift;
   my $config = $self->plugin('config', file => 'DeltaR.conf' );
   my $record_limit = $config->{record_limit};
   my $inventory_limit = $config->{inventory_limit};

   # use commands from DeltaR::Command namespace
   push @{$self->commands->namespaces}, 'DeltaR::Command';

## Helpers
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

## Routes
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
 
   $r->get( '/form/promises')->to('form#class_or_promise', template => 'form/promises', record_limit => $record_limit );
   $r->get( '/form/classes' )->to('form#class_or_promise', template => 'form/classes', record_limit => $record_limit );

   $r->get('/report/missing'  )->to('report#missing',   record_limit => $record_limit );
   $r->get('/report/inventory')->to('report#inventory', record_limit => $record_limit );
   $r->post('/report/classes' )->to('report#classes',   record_limit => $record_limit );
   $r->post('/report/promises')->to('report#promises',  record_limit => $record_limit );

   $r->get( '/initialize_database' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      $dq->create_tables;
   } => '/database_initialized');

   $r->get( '/database_initialized' => 'database_initialized');

   $r->get( '/trend/kept'     => \&trend)->to( subject => 'Kept' );
   $r->get( '/trend/notkept'  => \&trend)->to( subject => 'NotKept' );
   $r->get( '/trend/repaired' => \&trend)->to( subject => 'Repaired' );

   $r->get( '/pps' => \&percent_promise_summary)->to();
}

sub percent_promise_summary
{
   my $self = shift;
   my @columns = ( 'Date', 'Hosts', 'Kept', 'Repaired', 'Not kept' );
   my $dq = $self->app->dr;
   my $rows = $dq->query_promise_count( 'hosts', 'kept', 'repaired', 'notkept' );

   my $gr = DeltaR::Graph->new();
   my $host_series = $gr->nvd3_2column_timeseries(
      key => "Hosts",
      x_column => 0,
      y_column => 1,
      rows => $rows
      );

   my $percent_series = $gr->nvd3_percent_promise_series( rows => $rows );

   my $json_host_series = $gr->encode_to_json( \%$host_series );
   my $json_percent_series = $gr->encode_to_json( \@$percent_series );

   $self->stash(
      title          => "Promise percent summary",
      rows           => $rows,
      percent_series => $json_percent_series,
      host_series    => $json_host_series,
      columns        => \@columns 
   );

   $self->render( template => 'pps' );
}

sub trend
{
   my $self = shift;
   my $subject = $self->param('subject');
   my $column = lc $subject;
   $subject = 'Not Kept' if ( $subject eq 'NotKept' );
   my $dq = $self->app->dr;
   my @columns = ( 'Date', 'Hosts', $subject );
   my $rows = $dq->query_promise_count( 'hosts', $column );

   my $gr = DeltaR::Graph->new();
   my ( $hosts_series, $hosts_stats ) = $gr->nvd3_scatter_series( 
      key => 'Hosts',
      column => 1,
      rows => $rows
   );

   my ( $promise_series, $promise_stats ) = $gr->nvd3_scatter_series( 
      key => $subject,
      column => 2,
      rows => $rows
   );
   my @json_data_series = ( \%$hosts_series, \%$promise_series );
   my $json_data_series = $gr->encode_to_json( \@json_data_series );

   $self->stash(
      title         => "Promises $subject trend",
      rows          => $rows,
      dr_data       => $json_data_series,
      hosts_stats   => $hosts_stats,
      promise_stats => $promise_stats,
      columns       => \@columns 
   );

   $self->render( template => 'trend' );
}

1;

=pod

=head1 SYNOPSIS

This is the main Delta Reporting module. Start up and routing are controlled here.

=cut
