package DeltaR::Query;

use strict;
use warnings;
use feature 'say';
use DeltaR::Validator;
use Net::DNS;
use Sys::Hostname::Long 'hostname_long';
use Try::Tiny;
use Carp;

# TODO can probably dumb these for $self-->{dbh}
# TODO change to inside out?
# TODO change args to arg to reduce code.
our $dbh;
our $record_limit;
our $agent_table;
our $promise_counts;
our $inventory_table;
our $inventory_limit;
our $delete_age;
our $reduce_age;
our $logger;

sub new {
   my ( $class, $args ) = @_;

   $dbh             = $args->{'dbh'};
   # Safely quote config values that will end up in SQL statements.
   $agent_table     = quote_ident( $args->{'agent_table'} );
   $promise_counts  = quote_ident( $args->{'promise_counts'} );
   $inventory_table = quote_ident( $args->{'inventory_table'} );

   $inventory_limit = $args->{'inventory_limit'};
   $record_limit    = $args->{'record_limit'};
   $delete_age      = $args->{'delete_age'};
   $reduce_age      = $args->{'reduce_age'};
   $logger          = $args->{'logger'};

   # TODO do not need to bless args?
   my $self = bless $args, $class;
   return $self;
};

sub quote_ident {
   my $string = shift;
   my $query = "SELECT quote_ident( '$string' )";

   my $results = $dbh->query( $query );
   my $quoted_strings = $results->arrays;
   return $quoted_strings->[0][0];
}

sub quote_literal {
   my $string= shift;
   my $query = "SELECT quote_literal( '$string' )";

   my $results = $dbh->query( $query );
   my $quoted_strings = $results->arrays;
   return $quoted_strings->[0][0];
}

sub table_cleanup {
   my $self = shift;
   my $return;
   my @clean_operations = (
      "VACUUM $agent_table",
      "REINDEX TABLE $agent_table",
   );

   for my $next_op ( @clean_operations ) {
      $dbh->query( $next_op );
   }
   return;
}

sub delete_records {
   my $self  = shift;
   my $query = "DELETE FROM $agent_table WHERE timestamp < now()
      - interval '$delete_age days'";

   $dbh->query( $query );
   return;
}

sub reduce_records {
   my $self = shift;

   my @reduce_operations = (

      "SELECT * INTO TEMP tmp_agent_log FROM $agent_table
         WHERE timestamp < now() - interval '$reduce_age days'",

      "DELETE FROM $agent_table WHERE timestamp < now()
         - interval '$reduce_age days'",

      qq{ INSERT INTO $agent_table SELECT 
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
      },
   );

   # Queue up queries
   my $tx = $dbh->begin;
   for my $next_op ( @reduce_operations )
   {
      $dbh->query( $next_op );
   }
   $tx->commit;
   return;
}

sub count_records {
   my $self = shift;
   my $query = "SELECT reltuples FROM pg_class WHERE relname = ?";

   my $results = $dbh->query( $query, ( $agent_table ));
   my $record_counts = $results->arrays;

   return $record_counts->[0][0];
}

sub query_missing {
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

   my $results = $dbh->query( $query, ( $record_limit, $inventory_limit ));
   return $results->arrays;
}

sub query_recent_promise_counts {
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

   my $results = $dbh->query( $query );
   return $results->arrays;
}

sub query_inventory {
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
      my $results = $dbh->query( $class_query )
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

   my $results = $dbh->query( $inventory_query, @bind_params )
      or warn "$inventory_query error $!";
   return $results->arrays;
}

sub query_promises {
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
      hostname ip_address policy_server/ ) {
      push @bind_params, $query_params->{$param};
   }

   if ( $query_params->{'latest_record'} == 1 ) {
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
   elsif ( $query_params->{'latest_record'} == 0 ) {
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

   my $results = $dbh->query( $query, @bind_params );
   return $results->arrays;
}

# This is not used in production, but in testing to insert sample historical data.
sub insert_promise_counts {
   my ( $self, $historical_trends ) = @_;
   
   my $query = qq{ INSERT INTO $promise_counts
      ( datestamp, hosts, kept, notkept, repaired )
      VALUES ( ?, ?, ?, ?, ? )
   };

   # Begin transaction queue
   my $tx = $dbh->begin;

   for my $next_trend ( @{ $historical_trends } ){
      $dbh->query( $query, @{ $next_trend } );
   }
   $tx->commit;
   return 1;
}

sub insert_yesterdays_promise_counts {
   my $self  = shift;
   my $query = <<END_QUERY;
INSERT INTO $promise_counts ( datestamp, hosts, kept, notkept, repaired )
   SELECT
     date_trunc('day', timestamp) AS timestamp,
     COUNT(DISTINCT CASE WHEN class = 'any' THEN ip_address ELSE NULL END) AS hosts,
     COUNT(CASE promise_outcome WHEN 'kept' THEN 1 END) AS kept,
     COUNT(CASE promise_outcome WHEN 'notkept' THEN 1 END) AS notkept,
     COUNT(CASE promise_outcome WHEN 'repaired' THEN 1 END) AS repaired
   FROM $agent_table 
   WHERE timestamp >= CURRENT_DATE - INTERVAL '1 DAY'
     AND timestamp  < CURRENT_DATE 
     AND NOT EXISTS (
        SELECT 1 FROM $promise_counts WHERE datestamp = timestamp 
     )
   GROUP BY date_trunc('day', timestamp)
;
END_QUERY

   $dbh->query( $query );
   return;
}

sub query_promise_count {
   my ( $self, $fields ) = @_;

   my $query = "SELECT datestamp";
   for my $field ( @{ $fields} ) {
      $query .= sprintf ', %s', quote_ident( $field );
   }
   $query .= sprintf ' FROM %s', $promise_counts; 

   my $results = $dbh->query( $query );
   return $results->arrays;
}

sub query_classes {
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
   for my $param ( qw/ class hostname ip_address policy_server/ ) {
      push @bind_params, $query_params->{$param};
   }

   if ( $query_params->{'latest_record'} == 1 ) {
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
   elsif ( $query_params->{'latest_record'} == 0 ) {
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

   my $results = $dbh->query( $query, @bind_params );
   return $results->arrays;
}

sub get_timestamp_clause {
   my $query_params = shift;
   my $delta_sign;
   my $first_time_limit;
   my $second_time_limit;

   # Alter timestamps for DB consumption.
   for my $i ( qw/ delta_minutes gmt_offset / ) {
      if ( $query_params->{$i} !~ m/^[-+]/ ) {
         $query_params->{$i} = '+'.$query_params->{$i};
      }
   }
   $query_params->{timestamp} = $query_params->{timestamp}.$query_params->{gmt_offset};
   delete $query_params->{gmt_offset};
   if ( $query_params->{delta_minutes} =~ m/^([-+])(\d{1,4})/ ) {
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

   my $results = $dbh->query( $query );
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

   # Queue up db transactions
   my $tx = $dbh->begin;
   for my $table ( @tables ) {
      $dbh->query( "DROP TABLE IF EXISTS $table CASCADE" );
   }
   $tx->commit;
   return 1;
}

sub create_tables
{
   my $self = shift;
   my @create_tables = (
      qq{ CREATE TABLE $agent_table
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
      },

      qq{ CREATE INDEX client_by_timestamp ON $agent_table USING btree
         (timestamp, class)
      },

      qq{ CREATE TABLE $inventory_table
         (
            "rowId" serial NOT NULL, -- auto generated row id
            class text
         )
         WITH ( OIDS=FALSE )
      },

      qq{ INSERT INTO $inventory_table ( class )
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
      },

      qq{ CREATE TABLE $promise_counts
         (
            rowid serial NOT NULL,
            datestamp date,
            hosts integer,
            kept integer,
            notkept integer,
            repaired integer
         )
         WITH ( OIDS=FALSE )
      },

      qq{ CREATE INDEX promise_counts_idx ON $promise_counts
         USING btree( datestamp )
      },

      qq{ GRANT SELECT ON $agent_table, $promise_counts, $inventory_table TO
         deltar_ro
      },

      qq{ GRANT ALL ON $agent_table, $promise_counts, $inventory_table TO
         deltar_rw
      },
   );

   # Queue up transactions
   my $tx = $dbh->begin;
   for my $next_table ( @create_tables ) {
      $dbh->query( $next_table );
   }
   $tx->commit;

   return 1;
}

sub insert_client_log
{
   my ( $self, $client_log ) = @_;
   my %record;
   my $query = <<END_QUERY;
INSERT INTO $agent_table
(class, timestamp, hostname, ip_address, promise_handle,
promiser, promise_outcome, promisee, policy_server)
SELECT ?,?,?,?,?,?,?,?,? 
WHERE NOT EXISTS (
   SELECT 1 FROM $agent_table WHERE
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
END_QUERY

   # Slurp log file.
   open( my $fh, "<", "$client_log" ) or do {
      $logger->error_warn( "Could not open file [$client_log]" );
      return 0;
   };
   my @lines = <$fh>;
   close $fh;

   # Get ip address from file name.
   if ( $client_log =~ m{ ([^/]+) \.log\Z }msx ) {
      $record{ip_address} = $1;
      $record{hostname} = get_ptr( $record{ip_address} );
   }

   $record{policy_server} = hostname_long();
   
   # Get ready for db insert transactions
   my $tx = $dbh->begin;

   # Process each line of file
   LINE: for my $next_line ( @lines ) {

      # Blank some data
      for my $k ( qw/ timestamp class promise_handle promiser
         promise_outcome promisee / ) {
         $record{$k} = '';
      }

      chomp $next_line;
      (
         $record{timestamp},
         $record{class},
         $record{promise_handle},
         $record{promiser},
         $record{promise_outcome},
         $record{promisee}
      )  = split /\s*;;\s*/, $next_line;

      my $delta_validator = DeltaR::Validator->new({ input => \%record });
      my @errors = $delta_validator->validate_loading_data();
      if ( ( scalar @errors ) > 0 ){
            $logger->error_warn( "@errors, skipping record" );
            next LINE;
      }

      # Truncate long fields to guard against overflow.
      for my $next_field ( keys %record ) {
         $record{ $next_field } = substr( $record{ $next_field }, 0, 250 );
      }

      # Queue up queries for every line
      $dbh->query( $query, (
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
      ));
   }

   # Now commit queries
   $tx->commit;

   return;
}

sub validate_form_inputs {
   my ( $self, $query_params ) = @_; 
   my $errors = test_for_invalid_data({ inputs => $query_params });
   return $errors;
}

sub test_for_invalid_data {
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
   for my $k ( keys %{ $params->{valid_inputs} } ) {
      $default_valid_inputs{$k} = $params->{valid_inputs}->{$k};
   }
   my $valid_inputs      = \%default_valid_inputs;
   my $inputs            = $params->{inputs};
   my $max_record_length = exists $params->{max_record_length} ?
      $params->{max_record_length} : 24;
   my @errors;

   for my $p ( keys %{ $inputs } ) {
      if ( $valid_inputs->{$p} ) {
         if (
            $inputs->{$p} !~ m/$valid_inputs->{$p}/
            or $inputs->{$p}  =~ m/;/
            ) {
            push @errors, "$p '$inputs->{$p}' not allowed. Permitted format: $valid_inputs->{$p}";
         }
         elsif ( length( $inputs->{$p} ) > $max_record_length ) {
            push @errors, "Error [$p], [$inputs->{$p}] is too long. Maximum length is [$max_record_length].";
         }
      }
   }
   return \@errors;
}

sub get_ptr {
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
