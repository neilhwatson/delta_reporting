package DeltaR;

use Mojo::Base qw( Mojolicious );
use DeltaR::Query;
use DeltaR::Dashboard;
use Mojo::JSON 'encode_json';
use Log::Log4perl;
use DBI;
use Mojo::Pg;

sub startup
{
   my $self = shift;

# Config
   my $config = {
      db_name         => 'delta_reporting',
      db_user         => "deltar_ro",
      db_pass         => "",
      db_wuser        => "deltar_rw",
      db_wpass        => "",
      db_host         => "localhost",
      secrets         => [ 'secret passphrase', 'old secret passphrase' ],
      # Limit the number of records returned by a query.
      record_limit    => 1000,
      agent_table     => "agent_log",
      promise_counts  => "promise_counts",
      inventory_table => "inventory_table",
      # mintes to look backwards for inventory query
      inventory_limit => 20,
      client_log_dir  => "/var/cfengine/delta_reporting/log/client_logs",
      # (days) Delete records older than this.
      delete_age      => 90,
      # (days) Reduce duplicate records older than this to one per day
      reduce_age      => 10,
      hypnotoad       => {
         proxy      => 1,
         production => 1,
         listen     => [ 'http://localhost:8080' ],
         }
   };

   $self->defaults( small_title => '' );

   if ( -e 'DeltaR.conf' ) {
      $config = $self->plugin('config', file => 'DeltaR.conf' );
   }
   # TODO valid config. Try Mojolicious::Validator;
   
   # use commands from DeltaR::Command namespace
   push @{$self->commands->namespaces}, 'DeltaR::Command';

## Helpers

   $self->helper( mdb => sub {
      my ( $self, $arg_ref ) = @_;

      my $pg = Mojo::Pg->new(
         "postgresql://$config->{db_host}/$config->{db_name}" );
      $pg->options({ RaiseError => 1 });
      $pg->username( $arg_ref->{db_user} );
      $pg->password( $arg_ref->{db_pass} );
      my $dbh = $pg->db;
      return $dbh;
   });
         
   $self->helper( dbh => sub {
      my ( $self, %args ) = @_;
      my $db_name = $config->{db_name};
      my $db_host = $config->{db_host};

      my $dbh = DBI->connect(
            "DBI:Pg:dbname=$db_name; host=$db_host",
            "$args{db_user}", "$args{db_pass}",
            { RaiseError => 1 }
      );
      return $dbh;
   });

   $self->helper( dr2 => sub {
      my $self = shift;
      my $dq = DeltaR::Query->new({
         logger          => $self->logger(),
         agent_table     => $config->{agent_table},
         promise_counts  => $config->{promise_counts},
         inventory_table => $config->{inventory_table},
         inventory_limit => $config->{inventory_limit},
         delete_age      => $config->{delete_age},
         reduce_age      => $config->{reduce_age},
         record_limit    => $config->{record_limit},
         mdb             => $self->mdb({
            db_user => $config->{db_user},
            db_pass => $config->{db_pass},
         }),
      });
      return $dq;
   });

   $self->helper( dr => sub {
      my $self = shift;
      my $dq = DeltaR::Query->new({
         logger          => $self->logger(),
         agent_table     => $config->{agent_table},
         promise_counts  => $config->{promise_counts},
         inventory_table => $config->{inventory_table},
         inventory_limit => $config->{inventory_limit},
         delete_age      => $config->{delete_age},
         reduce_age      => $config->{reduce_age},
         record_limit    => $config->{record_limit},
         dbh             => $self->dbh(
            db_user => $config->{db_user},
            db_pass => $config->{db_pass},
         ),
      });
      return $dq;
   });

   $self->helper( dw => sub {
      my $self = shift;
      my $dq = DeltaR::Query->new({
         logger          => $self->logger(),
         agent_table     => $config->{agent_table},
         promise_counts  => $config->{promise_counts},
         inventory_table => $config->{inventory_table},
         inventory_limit => $config->{inventory_limit},
         delete_age      => $config->{delete_age},
         reduce_age      => $config->{reduce_age},
         record_limit    => $config->{record_limit},
         dbh             => $self->dbh(
            db_user => $config->{db_wuser},
            db_pass => $config->{db_wpass},
         ),
      });
      return $dq;
   });

## logging helper
   $self->helper( logger => sub { 
      my $self = shift;
      Log::Log4perl::init( 'DeltaR_logging.conf' )
         or die 'Cannot open [DeltaR_logging.conf]';
      my $logger = Log::Log4perl->get_logger( $0 );
      return $logger;
   });

##  Dashboard helper
   $self->helper( dashboard => sub {
         my $self      = shift;
         my $dashboard = DeltaR::Dashboard->new({ dbh => $self->dr2 });
         return $dashboard
   });

## Routes
   my $r = $self->routes;

   $r->any( '/' => sub {
      my $self = shift;

      my ( $latest_date, $latest_time ) =
         split /\s/, $self->dr2->query_latest_record();

      my $hostcount = $self->dashboard->hostcount();

      my $promisecount = $self->dashboard->promisecount({
            newer_than => $config->{inventory_limit}
      });

      $self->stash(
         latest_date    => $latest_date,
         latest_time    => $latest_time,
         hostcount      => $hostcount,
         promise_count  => $promisecount,
         inventory_limit => $config->{inventory_limit},
      );
   } => 'home' );

   $r->any( '/help' )->to( 'help', title => 'Help' );

   $r->any( '/about' => sub {
      my $self = shift;
      my $number_of_records = $self->dr->count_records;
      $self->stash(
         title => "About Delta Reporting",
         number_of_records => $number_of_records );
   } => 'about');
 
   $r->get( '/initialize_database' => sub {
      my $self = shift;
      $self->dw->create_tables;
   } => '/database_initialized');

   $r->get( '/database_initialized' => 'database_initialized' );

   $r->get( '/form/promises')->to('form#class_or_promise'
      , template     => 'form/promises'
      , record_limit => $config->{record_limit} );
   $r->get( '/form/classes' )->to('form#class_or_promise'
      , template     => 'form/classes'
      , record_limit => $config->{record_limit} );

   $r->post('/report/classes' )->to('report#classes'
      , record_limit => $config->{record_limit} );
   $r->post('/report/promises')->to('report#promises'
      , record_limit => $config->{record_limit} );

   $r->get('/report/missing'  )->to('report#missing'
      , record_limit => $config->{record_limit} );
   $r->get('/report/inventory')->to('report#inventory'
      , record_limit => $config->{record_limit} );

   $r->get( '/trend/:promise_outcome' )->to( 'graph#trend' );

   $r->get('/report/pps')->to('graph#percent_promise_summary');

   return;
}
1;

=pod

=head1 SYNOPSIS

This is the main Delta Reporting module. Start up and routing are controlled
here.

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
