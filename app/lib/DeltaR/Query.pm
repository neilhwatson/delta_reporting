package DeltaR::Query;

use strict;
use warnings;
use feature 'say';
use Net::DNS;
use Sys::Hostname::Long 'hostname_long';
use Try::Tiny;
use Carp qw/ croak /;
# use Data::Dumper; # TODO remove later

# TODO can probably dumb these for $self-->{dbh}
# TODO change to inside out?
# TODO change args to arg to reduce code.
our $dbh;
our $mdb;
our $record_limit;
our $agent_table;
our $promise_counts;
our $inventory_table;
our $inventory_limit;
our $delete_age;
our $reduce_age;
our $logger;

sub new 
{
   my ( $class, $args ) = @_;

   # Safely quote config values that will end up in SQL statements.
   # This dual dbh, mdb is temporary until mojo::pg is fully envoked.
   my $quote_ident;
   if ( defined $args->{dbh} ) {
      $dbh         = $args->{'dbh'};
      $quote_ident = \&quote_ident_dbh;
      
   }
   elsif ( defined $args->{mdb} ) {
      $mdb         = $args->{'mdb'};
      $quote_ident = \&quote_ident_mdb;
   }

   $agent_table     = $quote_ident->( $args->{'agent_table'} );
   $promise_counts  = $quote_ident->( $args->{'promise_counts'} );
   $inventory_table = $quote_ident->( $args->{'inventory_table'} );

   $inventory_limit = $args->{'inventory_limit'};
   $record_limit    = $args->{'record_limit'};
   $delete_age      = $args->{'delete_age'};
   $reduce_age      = $args->{'reduce_age'};
   $logger          = $args->{'logger'};

   my $self = bless $args, $class;
   return $self;
};

sub quote_ident_mdb {
   my $string = shift;
   my $query = "SELECT quote_ident( '$string' )";

   my $results = $mdb->query( $query );
   my $quoted_strings = $results->arrays;
   return $quoted_strings->[0][0];
}

sub quote_ident_dbh {
   my $string = shift;
   my $query = "SELECT quote_ident( '$string' )";

   my $data = sql_prepare_and_execute( '', {
      query  => $query,
      return => 'fetchall_arrayref'
   });
   return $data->[0][0];
}

sub quote_literal{
   my $string= shift;
   my $query = "SELECT quote_literal( '$string' )";

   my $results = $mdb->query( $query );
   my $quoted_strings = $results->arrays;
   return $quoted_strings->[0][0];
}

sub sql_prepare_and_execute {
   # TODO self not required?
   my ( $self, $args ) = @_;
   my $return      = exists $args->{return}      ? $args->{return}
                   : 'none';
   my $bind_params = exists $args->{bind_params} ? $args->{bind_params}
                   : [];
   my $query       = $args->{query};
   my $data;

   my $caller = ( caller(1) )[3]; # Calling subroutine

   my $sth = $dbh->prepare( $query )
      or $logger->error_die(
         "SQL prepare error: [$dbh->errstr], caller: [$caller]" );

   my $bind_parms_length = scalar( @{ $bind_params } );
   if ( $bind_parms_length > 0 )
   {
      for my $param_list ( @{ $bind_params } )
      {
         my $exception;
         $data = try
         {
            return $sth->execute( @{ $param_list } );
         }
         catch
         {
            $exception = $_;
         };
         if ( $exception )
         {
            $logger->error_warn(
               "Exception [$exception], SQL error [$dbh->errstr]" );
            $logger->error_die(  "Caller [$caller], query [$query]" );
         }
      }
   }
      else
   {
      my $exception;
      $data = try
      {
         return $sth->execute();
      }
      catch
      {
         $exception = $_;
      };
      if ( $exception )
      {
         $logger->error_warn(
            "Exception [$exception], SQL error [$dbh->errstr]" );
         $logger->error_die(  "Caller [$caller], query [$query]" );
      }
   }
   if ( $return eq 'fetchall_arrayref' )
   {
      $data = $sth->fetchall_arrayref();
   }

   #$logger->info( "$caller" );

   return $data;
}

sub table_cleanup
{
   my $self = shift;
   my $return;
   my @query;
   push @query, sprintf "VACUUM %s"       , $dbh->quote_identifier( $agent_table );
   push @query, sprintf "REINDEX TABLE %s", $dbh->quote_identifier( $agent_table );

   for my $q ( @query )
   {
      sql_prepare_and_execute( $self, { query  => $q});
   }
   return;
}

sub delete_records
{
   my $self = shift;

   my $query = sprintf "DELETE FROM %s WHERE timestamp < now() - interval %s",
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote( "$delete_age days" );

   return sql_prepare_and_execute( $self, { query  => $query});
}

sub reduce_records
{
   my $self = shift;

   my @query;

   push @query, sprintf "SELECT * INTO TEMP tmp_agent_log FROM %s
      WHERE timestamp < now() - interval %s",
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote( "$reduce_age days" );

   push @query, sprintf "DELETE FROM %s WHERE timestamp < now() - interval %s",
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote( "$reduce_age days" );

   push @query, sprintf <<END,
INSERT INTO %s SELECT 
   class, hostname, ip_address, promise_handle, promiser,
   promisee, policy_server, "rowId", timestamp, promise_outcome
   FROM (
      SELECT *, row_number() OVER w
      FROM tmp_agent_log
      WINDOW w AS (
         PARTITION BY class, ip_address, hostname, promiser, date_trunc(\'day\', timestamp)
         ORDER BY timestamp DESC
         )   
      ) t1
   WHERE row_number = 1;
END
      $dbh->quote_identifier( $agent_table );

   for my $q ( @query )
   {
      sql_prepare_and_execute( $self, { query  => $q});
   }

   return;
}

sub count_records
{
   my $self = shift;
   my $query = "SELECT reltuples FROM pg_class WHERE relname = ?";

   my $results = $mdb->query( $query, ( $agent_table ));
   my $record_counts = $results->arrays;

   return $record_counts->[0][0];
}

sub query_missing
{
   my $self = shift;
   my $query = <<"END_QUERY";
(SELECT DISTINCT hostname, ip_address, policy_server FROM $agent_table
WHERE class = 'any'
   AND timestamp < ( now() - interval '24' hour )
   AND timestamp > ( now() - interval '48' hour )
   LIMIT ? )
EXCEPT
(SELECT DISTINCT hostname, ip_address, policy_server FROM $agent_table 
WHERE class = 'any'
   AND timestamp > ( now() - interval '24' hour )
   LIMIT ? )
END_QUERY

   my $results = $mdb->query( $query, ( $record_limit, $inventory_limit ));
   return $results->arrays;
}

sub query_recent_promise_counts
{
   my ( $self, $interval ) = @_;
   my $query = <<"END_QUERY";
SELECT promise_outcome, count( promise_outcome ) FROM
(
   SELECT promise_outcome FROM $agent_table
   WHERE timestamp >= ( now() - interval '$interval' minute )
   AND promise_outcome != 'empty'
)
AS promise_count
GROUP BY promise_outcome,promise_count;
END_QUERY

   my $results = $mdb->query( $query );
   return $results->arrays;
}

sub query_inventory
{
   my ( $self, $class ) = @_;
   my ( $x, @bind_params );

   my $inventory_query = <<"END_QUERY";
SELECT class,COUNT( class )
FROM(
   SELECT class,ip_address FROM $agent_table 
   WHERE timestamp > ( now() - interval '$inventory_limit' minute )
   AND (
END_QUERY

   # Get all inventory classes if none are provided.
   if ( not defined $class or $class eq '' )
   {
      my $class_query = "SELECT class FROM $inventory_table"; 
      my $results = $mdb->query( $class_query )
         or warn "$class_query error $!";
      my $class_arrayref = $results->arrays;       

      # Build returned hard classes into final inventory query.
      for my $row ( @ {$class_arrayref } )
      {
         $x++;
         my $or = '';
         if ( $x > 1 ) { $or = 'OR' };

         push @bind_params, $row->[0];
         $inventory_query .= qq/ $or lower(class) LIKE lower(?) ESCAPE '!' /;
      }
   }
   # Or query only the provided class.
   else
   {
      push @bind_params, $class;
      $inventory_query .= qq/ class = lower(?) /;
   }

   $inventory_query .= <<'END_QUERY';
)
   GROUP BY class,ip_address
)
AS class_count
GROUP BY class
ORDER BY class
END_QUERY

   my $results = $mdb->query( $inventory_query, @bind_params )
      or warn "$inventory_query error $!";
   return $results->arrays;
}

sub query_promises
{
   my $self = shift;
   my $query_params = shift;
   my $query;
   my $common_query_section = <<END;
FROM $agent_table WHERE 
lower(promiser) LIKE lower(?) ESCAPE '!'
AND lower(promisee) LIKE lower(?) ESCAPE '!'
AND lower(promise_handle) LIKE lower(?) ESCAPE '!'
AND promise_outcome LIKE ? ESCAPE '!'
AND promise_outcome != 'empty'
AND lower(hostname) LIKE lower(?) ESCAPE '!'
AND lower(ip_address) LIKE lower(?) ESCAPE '!'
AND lower(policy_server) LIKE lower(?) ESCAPE '!'
END

   my @bind_params;
   for my $param ( qw/ promiser promisee promise_handle promise_outcome
      hostname ip_address policy_server/ )
   {
      push @bind_params, $query_params->{$param};
   }

   if ( $query_params->{'latest_record'} == 1 )
   {
      $query = <<END;
SELECT promiser,promisee,promise_handle,promise_outcome,max(timestamp)
AS maxtime,hostname,ip_address,policy_server
$common_query_section
GROUP BY promise_outcome,promiser,promise_handle,promisee,hostname,ip_address,policy_server
ORDER BY maxtime DESC
LIMIT ?
END
      push @bind_params, $record_limit;
   }
   elsif ( $query_params->{'latest_record'} == 0 )
   {
      my %timestamp = get_timestamp_clause( $query_params );

      $query = <<END;
SELECT promiser,promisee,promise_handle,promise_outcome,timestamp,
hostname,ip_address,policy_server 
$common_query_section
$timestamp{clause}
ORDER BY timestamp DESC
LIMIT ? 
END
      push @bind_params, ( @{ $timestamp{bind_params} }, $record_limit );
   }

   my $results = $mdb->query( $query, @bind_params );
   return $results->arrays;
}

sub insert_promise_counts
# This is not used in production, but in testing to insert sample historical data.
{
   my ( $self, $bind_params ) = @_;
   my $return      = 1;
   
   my $query = sprintf <<END,
INSERT INTO %s ( datestamp, hosts, kept, notkept, repaired )
VALUES ( ?, ?, ?, ?, ? )
END
      $dbh->quote_identifier( $promise_counts );

   return sql_prepare_and_execute( $self, {
      query       => $query,
      bind_params => $bind_params,
   });
}

sub insert_yesterdays_promise_counts
{
   my $self  = shift;
   my $query = sprintf <<END,
INSERT INTO %s ( datestamp, hosts, kept, notkept, repaired )
   SELECT
     date_trunc('day', timestamp) AS timestamp,
     COUNT(DISTINCT CASE WHEN class = 'any' THEN ip_address ELSE NULL END) AS hosts,
     COUNT(CASE promise_outcome WHEN 'kept' THEN 1 END) AS kept,
     COUNT(CASE promise_outcome WHEN 'notkept' THEN 1 END) AS notkept,
     COUNT(CASE promise_outcome WHEN 'repaired' THEN 1 END) AS repaired
   FROM %s 
   WHERE timestamp >= CURRENT_DATE - INTERVAL '1 DAY'
     AND timestamp  < CURRENT_DATE 
     AND NOT EXISTS (
        SELECT 1 FROM %s WHERE datestamp = timestamp 
     )
   GROUP BY date_trunc('day', timestamp)
;
END
      $dbh->quote_identifier( $promise_counts ),
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote_identifier( $promise_counts );

   return sql_prepare_and_execute( $self, { query => $query });
}

sub query_promise_count
{
   my ( $self, $fields ) = @_;

   my $query = "SELECT datestamp";
   for my $field ( @{ $fields} )
   {
      $query .= sprintf ', %s', quote_ident_mdb( $field );
   }
   $query .= sprintf ' FROM %s', $promise_counts; 

   my $results = $mdb->query( $query );
   return $results->arrays;
}

sub query_classes
{
   my $self         = shift;
   my $query_params = shift;
   my $query;
   my $common_query_section = <<END_COMMON_QUERY;
FROM $agent_table WHERE lower(class) LIKE lower(?) ESCAPE '!'
AND lower(hostname) LIKE lower(?) ESCAPE '!'
AND lower(ip_address) LIKE lower(?) ESCAPE '!'
AND lower(policy_server) LIKE lower(?) ESCAPE '!'
END_COMMON_QUERY

   my @bind_params;
   for my $param ( qw/ class hostname ip_address policy_server/ )
   {
      push @bind_params, $query_params->{$param};
   }

   if ( $query_params->{'latest_record'} == 1 )
   {
      $query = <<END_QUERY;
SELECT class,max(timestamp)
AS maxtime,hostname,ip_address,policy_server
$common_query_section
GROUP BY class,hostname,ip_address,policy_server
ORDER BY maxtime DESC
LIMIT ?
END_QUERY

      push @bind_params, $record_limit;
   }
   elsif ( $query_params->{'latest_record'} == 0 )
   {
      my %timestamp = get_timestamp_clause( $query_params );

      $query = <<END_QUERY;
SELECT class,timestamp,hostname,ip_address,policy_server
$common_query_section
$timestamp{clause}
ORDER BY timestamp DESC
LIMIT ? 
END_QUERY
      push @bind_params, ( @{ $timestamp{bind_params} }, $record_limit );
   }

   my $results = $mdb->query( $query, @bind_params );
   return $results->arrays;
}

sub get_timestamp_clause {
   my $query_params = shift;
   my $delta_sign;
   my $first_time_limit;
   my $second_time_limit;

   # Alter timestamps for DB consumption.
   for my $i ( qw/ delta_minutes gmt_offset / )
   {
      if ( $query_params->{$i} !~ m/^[-+]/ )
      {
         $query_params->{$i} = '+'.$query_params->{$i};
      }
   }
   $query_params->{timestamp} = $query_params->{timestamp}.$query_params->{gmt_offset};
   delete $query_params->{gmt_offset};
   if ( $query_params->{delta_minutes} =~ m/^([-+])(\d{1,4})/ )
   {
      $delta_sign = $1;
      $query_params->{delta_minutes} = $2;

      if ( $delta_sign eq '-' )
      {
         $first_time_limit = '<=';
         $second_time_limit = '>=';
      }
      elsif ( $delta_sign eq '+' )
      {
         $first_time_limit = '=>';
         $second_time_limit = '=<';
      }
   }
   else {
      croak "Cannot match delta minutes";
   }
   my @bind_params;
   push @bind_params, $query_params->{delta_minutes};

   my $sql_quoted_timestamp = quote_literal( $query_params->{timestamp} );
   my $clause = sprintf <<END_CLAUSE,
AND timestamp $first_time_limit %s::timestamp 
AND timestamp $second_time_limit ( %s::timestamp $delta_sign ? * interval '1 minute' )
END_CLAUSE
   $sql_quoted_timestamp, $sql_quoted_timestamp;
   
   return (
      bind_params => \@bind_params,
      clause      => $clause,
   );
}

sub query_latest_record {
   my $self = shift;
   my $query = <<"END_QUERY";
SELECT timestamp FROM $agent_table ORDER BY timestamp desc LIMIT 1
END_QUERY

   my $results = $mdb->query( $query );
   my $data = $results->arrays;
   return $data->[0][0];
}

sub drop_tables
# This is not used in production, but in testing.
{
   my $self = shift;
   my $return = 1;
   my @tables = (
      "$agent_table",
      "$inventory_table",
      # "client_by_timestamp ", # dropped by default?
      "$promise_counts",
      # "promise_counts_idx ", # dropped by default?
   );

   for my $table ( @tables )
   {
      my $query = sprintf "DROP TABLE IF EXISTS %s CASCADE",
         $dbh->quote_identifier( $table );

      $return = sql_prepare_and_execute( $self, { query => $query });
   }
   return $return;
}

sub create_tables
{
   my $self = shift;
   my @queries;

   my $query = sprintf <<END,
CREATE TABLE %s 
(
   class text,
   hostname text,
   ip_address text,
   promise_handle text,
   promiser text,
   promisee text,
   policy_server text,
   "rowId" serial NOT NULL, -- auto generated row id
   timestamp timestamp with time zone,
   promise_outcome text, -- result of promise if applicable
   CONSTRAINT primary_key PRIMARY KEY ("rowId")
)
WITH ( OIDS=FALSE )
END
      $dbh->quote_identifier( $agent_table );
   push @queries, $query;

   $query = sprintf <<END,
CREATE INDEX client_by_timestamp ON %s USING btree (timestamp, class)
END
      $dbh->quote_identifier( $agent_table );
   push @queries, $query;

   $query = sprintf <<END,
CREATE TABLE %s 
(
   "rowId" serial NOT NULL, -- auto generated row id
	class text
)
WITH ( OIDS=FALSE )
END
      $dbh->quote_identifier( $inventory_table );
   push @queries, $query;

   $query = sprintf "INSERT INTO %s ( class ) ",
      $dbh->quote_identifier( $inventory_table );
   $query .= <<END;
VALUES 
   ('am_policy_hub'),
   ('any'),
   ('centos%'),
   ('cfengine_3%'),
   ('community%'),
   ('debian%'),
   ('enterprise%'),
   ('fedora%'),
   ('ipv4_%'),
   ('linux%'),
   ('policy_server'),
   ('pure_%'),
   ('redhat%'),
   ('solaris%'),
   ('sun4%'),
   ('suse%'),
   ('ubuntu%'),
   ('virt_%'),
   ('vmware%'),
   ('xen%'),
   ('zone_%')
END
   push @queries, $query;

   $query = sprintf <<END,
CREATE TABLE %s 
(
   rowid serial NOT NULL,
   datestamp date,
   hosts integer,
   kept integer,
   notkept integer,
   repaired integer
)
WITH ( OIDS=FALSE )
END
      $dbh->quote_identifier( $promise_counts );
   push @queries, $query;

   $query = sprintf <<END,
CREATE INDEX promise_counts_idx ON %s USING btree( datestamp )
END
      $dbh->quote_identifier( $promise_counts );
   push @queries, $query;

   $query = sprintf <<END,
GRANT SELECT ON $agent_table, $promise_counts, $inventory_table TO deltar_ro
END
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote_identifier( $promise_counts ),
      $dbh->quote_identifier( $inventory_table );
   push @queries, $query;

   $query = sprintf <<END,
GRANT ALL ON $agent_table, $promise_counts, $inventory_table TO deltar_rw
END
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote_identifier( $promise_counts ),
      $dbh->quote_identifier( $inventory_table );
   push @queries, $query;

   for my $q ( @queries )
   {
      sql_prepare_and_execute( $self, { query => $q });
   }
   return;
}

sub insert_client_log
{
   my ( $self, $client_log ) = @_;
   my @bind_params;
   my %record;
   my $query = sprintf <<END,
INSERT INTO %s 
(class, timestamp, hostname, ip_address, promise_handle,
promiser, promise_outcome, promisee, policy_server)
SELECT ?,?,?,?,?,?,?,?,? 
WHERE NOT EXISTS (
   SELECT 1 FROM %s WHERE
class = ?
AND timestamp = ?
AND hostname = ?
AND ip_address = ?
AND promise_handle = ?
AND promiser = ?
AND promise_outcome = ?
AND promisee = ?
AND policy_server = ?
   );
END
   $dbh->quote_identifier( $agent_table ),
   $dbh->quote_identifier( $agent_table );

   open( my $fh, "<", "$client_log" ) or do {
      $logger->error_warn( "Could not open file [$client_log]" );
      return 0;
   };
   my @lines = <$fh>;
   close $fh;

   if ( $client_log =~ m:([^/]+)\.log$: )
   {
      $record{ip_address} = $1;
      $record{hostname} = get_ptr( $record{ip_address} );
   }

   $record{policy_server} = hostname_long();
   
   for my $l ( @lines )
   {
      for my $k ( qw/ timestamp class promise_handle promiser
         promise_outcome promisee / )
      {
         $record{$k} = '';
      }

      chomp $l;
      (
         $record{timestamp},
         $record{class},
         $record{promise_handle},
         $record{promiser},
         $record{promise_outcome},
         $record{promisee}
      )  = split /\s*;;\s*/, $l;

      my $errors = validate_load_inputs( \%record );
      if ( $#{ $errors } > 0 ){
         for my $err ( @{ $errors } )
         {
            $logger->error_warn( "validation error [$err], skipping record" )
         }
         next;
      };

      push @bind_params,  [
         $record{class},
         $record{timestamp},
         $record{hostname},
         $record{ip_address},
         $record{promise_handle},
         $record{promiser},
         $record{promise_outcome},
         $record{promisee},
         $record{policy_server},
         $record{class},
         $record{timestamp},
         $record{hostname},
         $record{ip_address},
         $record{promise_handle},
         $record{promiser},
         $record{promise_outcome},
         $record{promisee},
         $record{policy_server},
      ];
   }
   sql_prepare_and_execute(
      $self, 
      {
         query       => $query,
         bind_params => \@bind_params,
   });
   return 1;
}

sub validate_load_inputs
# Valid inputs for loading client logs
{
   my $record = shift;
   my %valid_inputs = (
      promise_outcome => '^kept|repaired|notkept|empty$',
      timestamp       => '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[-+]{1}\d{4}$',
   );
   
   my $errors = test_for_invalid_data({
      valid_inputs      => \%valid_inputs,
      max_record_length => 125,
      inputs            => $record
   });
   return $errors;
}

sub validate_form_inputs
{
   my ( $self, $query_params ) = @_; 
   my $errors = test_for_invalid_data({ inputs => $query_params });
   return $errors;
}

sub test_for_invalid_data
{
   my ( $params ) = @_;

   my %default_valid_inputs = (
      class           => '^[%\w]+$',
      delta_minutes   => '^[+-]{0,1}\d{1,4}$',
      gmt_offset      => '^[+-]{0,1}\d{1,4}$',
      hostname        => '^[%\w\-\.]+$',
      ip_address      => '^[%\d\.:a-fA-F]+$',
      policy_server   => '^([%\d\.:a-fA-F]+)|([%\w\-\.]+)$',
      promise_handle  => '^[%\w]+$',
      promise_outcome => '^%|kept|repaired|notkept$',
      promisee        => '^[%\w/\s\d\.\-\\:]+$',
      promiser        => '^[%\w/\s\d\.\-\\:=]+$',
      timestamp       => '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$',
      latest_record   => '0|1',
   );

   # Merge parameter valid inputs into defaults. Use to allow incoming params
   # to override the default_valid_inputs.
   for my $k ( keys %{ $params->{valid_inputs} } )
   {
      $default_valid_inputs{$k} = $params->{valid_inputs}->{$k};
   }
   my $valid_inputs      = \%default_valid_inputs;
   my $inputs            = $params->{inputs};
   my $max_record_length = exists $params->{max_record_length} ?
      $params->{max_record_length} : 24;
   my @errors;

   for my $p ( keys %{ $inputs } )
   {
      if ( $valid_inputs->{$p} )
      {
         if (
            $inputs->{$p} !~ m/$valid_inputs->{$p}/
            or $inputs->{$p}  =~ m/;/
            )
         {
            push @errors, "$p '$inputs->{$p}' not allowed. Permitted format: $valid_inputs->{$p}";
         }
         elsif ( length( $inputs->{$p} ) > $max_record_length )
         {
            push @errors, "Error [$p], [$inputs->{$p}] is too long. Maximum length is [$max_record_length].";
         }
      }
   }
   return \@errors;
}

sub get_ptr
{
   my $ip = shift;
   my $hostname = 'unknown';
   my $res = Net::DNS::Resolver->new;
   my $query= $res->query( $ip, "PTR" );

   if ( $query )
   {
      for my $rr ( $query->answer )
      {
         next unless $rr->type eq "PTR";
         $hostname = $rr->rdatastr;
      }
   }
   return $hostname;
}

1;

=pod

=head1 SYNOPSIS

This module handles all database queries.

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
