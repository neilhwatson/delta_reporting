package DeltaR;

use Mojo::Base qw( Mojolicious );
#use DeltaR::Graph;
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
 
   $r->get( '/initialize_database' => sub
   {
      my $self = shift;
      my $dq = $self->app->dr;
      $dq->create_tables;
   } => '/database_initialized');

   $r->get( '/database_initialized' => 'database_initialized');

   $r->get( '/form/promises')->to('form#class_or_promise', template => 'form/promises', record_limit => $record_limit );
   $r->get( '/form/classes' )->to('form#class_or_promise', template => 'form/classes', record_limit => $record_limit );

   $r->get('/report/missing'  )->to('report#missing',   record_limit => $record_limit );
   $r->get('/report/inventory')->to('report#inventory', record_limit => $record_limit );
   $r->post('/report/classes' )->to('report#classes',   record_limit => $record_limit );
   $r->post('/report/promises')->to('report#promises',  record_limit => $record_limit );

   $r->get( '/trend/kept'     )->to( 'graph#trend', subject => 'Kept' );
   $r->get( '/trend/notkept'  )->to( 'graph#trend', subject => 'NotKept' );
   $r->get( '/trend/repaired' )->to( 'graph#trend', subject => 'Repaired' );

   $r->get('/report/pps')->to('graph#percent_promise_summary');
}
1;

=pod

=head1 SYNOPSIS

This is the main Delta Reporting module. Start up and routing are controlled here.

=cut
