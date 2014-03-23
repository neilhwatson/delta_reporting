#!/usr/bin/perl 

use Mojolicious::Lite;
use Mojo::Log;
plugin 'Config';

use POSIX qw(strftime);
use DBI;

use Data::Dumper; # TODO Remove for production
use lib 'lib';
use DeltaR;

my $gmt_offset   = strftime "%z", localtime;
my $record_limit = app->config("record_limit");
my $inventory_limit => app->config("inventory_limit");

app->attr( dbh => sub
{
   my $self = shift;
   my $db_name = app->config("db_name");
   my $db_user = app->config("db_user");
   my $db_pass = app->config("db_pass");
   my $db_host = app->config("db_host");

   my $dbh = DBI->connect(
         "DBI:Pg:dbname=$db_name; host=$db_host",
         "$db_user", "$db_pass",
         { RaiseError => 1 }
   );
   
   return $dbh;
});

app->attr( dr => sub
{
   my $self = shift;
   my $dr = DeltaR->new( 
      agent_table     => app->config("agent_table"),
      inventory_table => app->config("inventory_table"),
      inventory_limit => app->config("inventory_limit"),
      db_user         => app->config("db_user"),
      db_name         => app->config("db_name"),
      record_limit    => $record_limit,
      dbh             => $self->app->dbh,
   );
   return $dr
});

get '/inventory' => sub
{
   my $self = shift;
   my $dr = $self->app->dr;
	my $rows = $dr->query_inventory();

   $self->stash(
      title        => "Inventory report",
      record_limit => $record_limit,
      rows         => $rows,
      columns      => [ 'Class','Count' ]
   );
} => 'rtable';

get '/promises' => sub
{
   my $self = shift;
   my $timestamp    = strftime "%F %T", localtime;
   $self->stash(
      record_limit => $record_limit,
      timestamp    => $timestamp,
      gmt_offset   => $gmt_offset
   );
} => 'promises';

post '/report_promises' => sub
{
   my $self = shift;
   my $dr = $self->app->dr;
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

	my @errors = $dr->validate( %query_params );
   if ( @errors )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $dr->query_promises( %query_params );
   
   $self->stash(
      title        => $self->param('report_title'),
      record_limit => $record_limit,
      rows         => $rows,
      columns      => [ 'Promiser', 'Promisee', 'Promise handle', 'Promise outcome',
         'Timestamp', 'Hostname','IP Address','Policy Server' ]
   );
} => "rtable" ;


get '/classes' => sub
{
   my $self = shift;
   my $timestamp    = strftime "%F %T", localtime;
   $self->stash(
      record_limit => $record_limit,
      timestamp    => $timestamp,
      gmt_offset   => $gmt_offset
   );
} => 'classes';

post '/report_classes' => sub
{
   my $self = shift;
   my $dr = $self->app->dr;
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

	my @errors = $dr->validate( %query_params );
   if ( @errors )
   {
      $self->stash(
         title  => $self->param('report_title'),
         errors => \@errors
      );
      return $self->render( template => 'error', format => 'html' );
   }

   my $rows = $dr->query_classes( %query_params );
   
   $self->stash(
      title        => $self->param('report_title'),
      record_limit => $record_limit,
      rows         => $rows,
      columns      => [ 'Class','Timestamp','Hostname','IP Address','Policy Server' ]
   );
} => "rtable" ;

get '/initialize_database' => sub
{
   my $self = shift;
   my $dr = $self->app->dr;
   $dr->create_tables;
} => '/database_initialized';

get '/load' => sub
{
   my $self = shift;
   my $dr = $self->app->dr;
   my $log_dir = app->config('client_log_dir');
   my $client_log = $self->param("client_log");

   if ( $dr->insert_client_log( "$log_dir/$client_log" ) )
   {
      $self->render( text => "SUCCESS loading $log_dir/$client_log" );
   }
   else
   {
      # TODO return something other than 200
      $self->render( text => "FAIL loading $log_dir/$client_log" );
   }
};

get '/database_initialized' => 'database_initialized';

get '/' => 'home';

get '/about' => sub 
{
   my $self = shift;
   my $dr = $self->app->dr;
   my $number_of_records = $dr->count_records;
   $self->stash(
      title => "About Delta Reporting",
      number_of_records => $number_of_records );
   
} => 'about';

get '/help' => sub
{
   my $self = shift;
   $self->stash( title => "Delta Reporting Help" );
} => 'help';

#app->log( Mojo::Log->new( path => '/var/log/delta_reporting.log', level => 'debug' ) );

app->start;
