package DeltaR::Query;

use strict;
use warnings;
use feature 'say';
use Net::DNS;
use Sys::Hostname::Long 'hostname_long';
# use Data::Dumper; # TODO remove

our $dbh;
our $record_limit;
our $agent_table;
our $promise_counts;
our $inventory_table;
our $inventory_limit;
our $delete_age;
our $reduce_age;

sub new 
{
   my $self = shift;
   my %param = @_;
   $record_limit    = $param{'record_limit'};
   $agent_table     = $param{'agent_table'};
   $promise_counts  = $param{'promise_counts'};
   $inventory_table = $param{'inventory_table'};
   $inventory_limit = $param{'inventory_limit'};
   $delete_age      = $param{'delete_age'};
   $reduce_age      = $param{'reduce_age'};
   $dbh             = $param{'dbh'};

   bless{} => __PACKAGE__;
};

# TODO new query sub to reduce code
sub sql_prepare_and_execute
{
   my %args = ( 
      return => 'none',
      @_
   );
   my $return;

   my $sth = $dbh->prepare( $args{query} )
      or die "SQL prepare error: [$dbh->errstr]";
   $return = $sth->execute
      or die "SQL execute error: [$dbh->errstr]";

   if ( $args{return} eq 'fetchall_arrayref' )
   {
      $return = $sth->fetchall_arrayref();
   }
   return $return;
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
      $return = sql_prepare_and_execute( query  => $q,);
   }
   return $return;
}

sub delete_records
{
   my $self = shift;

   my $query = sprintf "DELETE FROM %s WHERE timestamp < now() - interval %s",
      $dbh->quote_identifier( $agent_table ),
      $dbh->quote( "$delete_age days" );

   return sql_prepare_and_execute( query  => $query,);
}

sub reduce_records
{
   my $self = shift;
   my $return;

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
      $return = sql_prepare_and_execute( query  => $q,);
   }

   return $return;
}

# TODO use sql_prepare_and_execute
sub count_records
{
   my $self = shift;
   my $query = "SELECT reltuples FROM pg_class WHERE relname = ?";

   my $sth = $dbh->prepare( $query );
   $sth->execute( $agent_table );
   my $array_ref = $sth->fetchall_arrayref();

   return $array_ref->[0][0];
}

sub query_missing
{
   my $self = shift;
   my $query = sprintf <<END,
(SELECT DISTINCT hostname, ip_address, policy_server FROM %s
WHERE class = 'any'
	AND timestamp < ( now() - interval '24' hour )
   AND timestamp > ( now() - interval '48' hour )
   LIMIT %s )
EXCEPT
(SELECT DISTINCT hostname, ip_address, policy_server FROM %s
WHERE class = 'any'
   AND timestamp > ( now() - interval '24' hour )
   LIMIT %s )
END
   $dbh->quote_identifier( $agent_table ),
   $dbh->quote_identifier( $agent_table ),
   $dbh->quote( $record_limit, { pg_type => SQL_INTEGER } ),
   $dbh->quote( $record_limit, { pg_type => SQL_INTEGER } );
   
   return sql_prepare_and_execute(
      query  => $query,
      return => 'fetchall_arrayref',
   );
}

sub query_recent_promise_counts
{
   my $self     = shift;
   my $interval = shift;
   my $query = <<END;
SELECT promise_outcome, count( promise_outcome ) FROM
(
   SELECT promise_outcome FROM agent_log
   WHERE timestamp >= ( now() - interval '$interval' minute )
   AND promise_outcome != 'empty'
)
AS promise_count
GROUP BY promise_outcome,promise_count;
END

   my $sth;
   $sth = $dbh->prepare( $query )
      or warn "Cannot prepare [$query], [$dbh->errstr]";
   $sth->execute
      or warn "Cannot execute [$query], [$dbh->errstr]";

   return $sth->fetchall_arrayref();
}

sub query_inventory
{
   my $self = shift;
   my $class = shift;
   my ( $like_clauses, $sth );

   if ( not defined $class or $class eq '' )
   {
      my $sth = $dbh->prepare( "SELECT class FROM $inventory_table" )
         || die "Could not prepare inventory query [$dbh->errstr]" ;
      my $class_arrayref = $dbh->selectall_arrayref( $sth ) 
         || die "Could not execute inventory query [$dbh->errstr]" ;

      for my $row ( @$class_arrayref )
      {
         my ( $bind_class ) = @$row;
         $like_clauses .= " OR lower(class) LIKE lower('$bind_class') ESCAPE '!'";
      }
      $like_clauses =~ s/^ OR//;
   }
   else
   {
      $like_clauses = "class = lower('$class')";
   }

   my $query = <<END;
SELECT class,COUNT( class )
FROM(
   SELECT class,ip_address FROM $agent_table
   WHERE timestamp > ( now() - interval '$inventory_limit' minute )
   AND ($like_clauses)
   GROUP BY class,ip_address
)
AS class_count
GROUP BY class
ORDER BY class
END
   $sth = $dbh->prepare( $query ) || die "Could not prepare class query [$dbh->errstr]";
   $sth->execute || die "Could not execute class query [$dbh->errstr]";
   return $sth->fetchall_arrayref();
};

sub validate_load_inputs
# Valid inputs for loading client logs
{
   my $self = shift;
   my $record = shift;
	my $max_length = 72;
	my %valid_inputs = (
		class           => '^[%\w]+$',
		hostname        => '^[\w\-\.]+$',
		ip_address      => '^[\d\.:a-fA-F]+$',
      policy_server   => '^([\d\.:a-fA-F]+)|([\w\-\.]+)$',
		promise_handle  => '^[\w]+$',
		promise_outcome => '^kept|repaired|notkept|empty$',
		promisee        => '^[\w/\s\d\.\-\\:]+$',
		promiser        => '^[\w/\s\d\.\-\\:=]+$',
		timestamp       => '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[-+]{1}\d{4}$',
	);

   my $errors = test_for_invalid_data(
      valid_inputs      => \%valid_inputs,
      max_record_length => $max_length,
      inputs            => $record
   );
   return $errors;
}

sub validate_form_inputs
{
   my $self = shift;
   my $query_params = shift; 

   my $errors = test_for_invalid_data( inputs => $query_params );
   return $errors;
}

sub test_for_invalid_data
{
	my %valid_inputs = (
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
   my %params = @_;
   my $inputs = $params{inputs};
   my $max_record_length = $params{record_length} // 24;
   my $valid_inputs = $params{valid_inputs} // \%valid_inputs;

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
            push @errors, "Error $p too long. Maximum length is $max_record_length.";
         }

      }
   }
   return \@errors;
}

sub query_promises
{
   my $self = shift;
   my $query_params = shift;
   my $query;
   my $delta_sign;
   my $first_time_limit;
   my $second_time_limit;
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

   my @bind_params = qw/ promiser promisee promise_handle promise_outcome hostname ip_address policy_server/;

   if ( $query_params->{'latest_record'} == 1 )
   {
      $query = <<END;
SELECT promiser,promisee,promise_handle,promise_outcome,max(timestamp)
AS maxtime,hostname,ip_address,policy_server
$common_query_section
GROUP BY promise_outcome,promiser,promise_handle,promisee,hostname,ip_address,policy_server
ORDER BY maxtime DESC
LIMIT $record_limit
END

   }
   elsif ( $query_params->{'latest_record'} == 0 )
   {
      my $timestamp_clause = get_timestamp_clause( $query_params );

      $query = <<END;
SELECT promiser,promisee,promise_handle,promise_outcome,timestamp,
hostname,ip_address,policy_server 
$common_query_section
$timestamp_clause
ORDER BY timestamp DESC
LIMIT $record_limit 
END
   }

   my $rows = execute_query(
      query => $query,
      bind_params => \@bind_params,
      query_params => $query_params,
   );
   return $rows
}

sub insert_promise_counts
# This is not used in production, but in testing to insert sample historical data.
{
   my $self = shift;
   my $AoH = shift;
   my $return = 1;
   
   my $sth = $dbh->prepare( <<END
   INSERT INTO $promise_counts ( datestamp, hosts, kept, notkept, repaired )
   VALUES ( ?, ?, ?, ?, ? )
END
   ) or do
   {
      warn "Cannot prepare historical trend data [$dbh->errstr]";
      $return = 0;
   };

   for my $row ( @{ $AoH } )
   {
      $sth->execute( 
         $row->{datestamp},
         $row->{hosts},
         $row->{kept},
         $row->{notkept},
         $row->{repaired}
      ) or do
      {
         warn "cannot insert historical trend data [$dbh->errstr]";
         $return = 0;
      };
   }
   return $return;
}

sub insert_yesterdays_promise_counts
{
   my $self = shift;
   my $query = <<END;
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
END

   my $sth = $dbh->prepare( $query )
      or die "$dbh->errstr Cannot prepare $query";
   $sth->execute
      or die "$dbh->errstr Cannot execute $query";
}

sub query_promise_count
{
   my $self = shift;
   my @fields = @_;
   my $fields = join ',', @fields;
   my $query = "SELECT datestamp, $fields FROM $promise_counts";
   my $sth = $dbh->prepare( $query );
   $sth->execute;
   return $sth->fetchall_arrayref();
}

sub query_classes
{
   my $self = shift;
   my $query_params = shift;
   my $query;
   my $delta_sign;
   my $first_time_limit;
   my $second_time_limit;
   my @bind_params = qw/ class hostname ip_address policy_server/;
   my $common_query_section = <<END;
FROM $agent_table WHERE lower(class) LIKE lower(?) ESCAPE '!'
AND lower(hostname) LIKE lower(?) ESCAPE '!'
AND lower(ip_address) LIKE lower(?) ESCAPE '!'
AND lower(policy_server) LIKE lower(?) ESCAPE '!'
END

   if ( $query_params->{'latest_record'} == 1 )
   {
      $query = <<END;
SELECT class,max(timestamp)
AS maxtime,hostname,ip_address,policy_server
$common_query_section
GROUP BY class,hostname,ip_address,policy_server
ORDER BY maxtime DESC
LIMIT $record_limit
END

   }
   elsif ( $query_params->{'latest_record'} == 0 )
   {
      my $timestamp_clause = get_timestamp_clause( $query_params );

      $query = <<END;
SELECT class,timestamp,hostname,ip_address,policy_server
$common_query_section
$timestamp_clause
ORDER BY timestamp DESC
LIMIT $record_limit 
END
   }

   my $rows = execute_query(
      query => $query,
      bind_params => \@bind_params,
      query_params => $query_params,
   );
   return $rows
}

sub query_latest_record
{
   my $query = <<END;
SELECT timestamp FROM $agent_table 
ORDER BY timestamp desc LIMIT 1
END

   my $sth = $dbh->prepare( $query )
      or warn "Can't prepare query [$query]";

   $sth->execute()
      or warn "Can't execute query [$query] [$sth->errstr]";

   my $array_ref = $sth->fetchall_arrayref();

   return $array_ref->[0][0];
}

sub execute_query
{
   my %params = @_;
   my $query = $params{query};
   my $bind_params = $params{bind_params};
   my $query_params = $params{query_params};

   my $sth;
   $sth = $dbh->prepare( $query )
      or warn "Can't prepare query [$sth->errstr]";

   if ( $bind_params )
   {
      my $param_count = 1;
      for my $qp ( @{ $bind_params } )
      {
         $sth->bind_param( $param_count, $query_params->{$qp} )
            or warn "bind error [$sth->errstr]";
         $param_count++;
      }
   }
   $sth->execute() or warn "bind error [$sth->errstr]";
   return $sth->fetchall_arrayref();
}

sub get_timestamp_clause
{
   my $query_params = shift;
   my $delta_sign;
   my $first_time_limit;
   my $second_time_limit;

   my @integers = qw/ delta_minutes gmt_offset /;
   for my $i ( @integers )
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

  return <<END
AND timestamp $first_time_limit '$query_params->{timestamp}'::timestamp
AND timestamp $second_time_limit ( '$query_params->{timestamp}'::timestamp
$delta_sign $query_params->{delta_minutes} * interval '1 minute' )
END
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

   my $sth;

   for my $table ( @tables )
   {
      $sth = $dbh->prepare( "DROP TABLE IF EXISTS $table CASCADE" );
      $sth->execute or do
      {
         warn "cannot execute drop [$dbh->errstr]";
         $return = 0;
      }
   }
   return $return;
}

sub create_tables
{
   my $self = shift;

   my @queries = ( 
# 
"CREATE TABLE $agent_table
(
class text,
hostname text,
ip_address text,
promise_handle text,
promiser text,
promisee text,
policy_server text,
\"rowId\" serial NOT NULL, -- auto generated row id
timestamp timestamp with time zone,
promise_outcome text, -- result of promise if applicable
CONSTRAINT primary_key PRIMARY KEY (\"rowId\")
)
WITH (
OIDS=FALSE
);",

#
"CREATE INDEX client_by_timestamp ON $agent_table USING btree (timestamp, class);",

#
"CREATE TABLE $inventory_table 
(
   \"rowId\" serial NOT NULL, -- auto generated row id
	class text
)
WITH (
OIDS=FALSE
);",

#
"INSERT INTO $inventory_table ( class ) VALUES
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
('zone_%');
",

#
"CREATE TABLE $promise_counts
(
   rowid serial NOT NULL,
   datestamp date,
   hosts integer,
   kept integer,
   notkept integer,
   repaired integer
)
WITH ( OIDS=FALSE );
",

#
"CREATE INDEX promise_counts_idx ON $promise_counts USING btree( datestamp );",

#
"GRANT SELECT ON $agent_table, $promise_counts, $inventory_table TO deltar_ro;",

#
"GRANT ALL ON $agent_table, $promise_counts, $inventory_table TO deltar_rw;",

);

   for my $query ( @queries )
   {
      my $sth = $dbh->prepare( $query ) or do 
      {
         warn "Cannot prepare [$query], [$dbh->errstr]";
         die;
      };
      $sth->execute or do
      {
         warn "Cannot prepare [$query], [$dbh->errstr]";
         die;
      };
   }
}

sub insert_client_log
{
   my $self = shift;
   my $client_log = shift;
   my %record;
   my $query = <<END;
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
END

   my $fh;
   if ( open( $fh, "<", "$client_log" ) )
   {
      my $sth = $dbh->prepare( $query ) or do
      {
         warn "Cannot prepare insert query [$dbh->errstr]";
         die;
      };

      undef %record;
      if ( $client_log =~ m:([^/]+)\.log$: )
      {
         $record{ip_address} = $1;
         $record{hostname} = get_ptr( $record{ip_address} );
      }

      $record{policy_server} = hostname_long();
      
      while (<$fh>)
      {
         for my $k ( qw/ timestamp class promise_handle promiser
            promise_outcome promisee / )
         {
            $record{$k} = '';
         }

         chomp;
         (
            $record{timestamp},
            $record{class},
            $record{promise_handle},
            $record{promiser},
            $record{promise_outcome},
            $record{promisee}
         )  = split /\s*;;\s*/;

         my $errors = validate_load_inputs( \%record );
         if ( $#{ $errors } > 0 ){
            for my $err ( @{ $errors } ) { warn "validation error [$err]" };
            next;
         };

         $sth->bind_param( 1, $record{class} );
         $sth->bind_param( 2, $record{timestamp} );
         $sth->bind_param( 3, $record{hostname} );
         $sth->bind_param( 4, $record{ip_address} );
         $sth->bind_param( 5, $record{promise_handle} );
         $sth->bind_param( 6, $record{promiser} );
         $sth->bind_param( 7, $record{promise_outcome} );
         $sth->bind_param( 8, $record{promisee} );
         $sth->bind_param( 9, $record{policy_server} );
         $sth->bind_param( 10, $record{class} );
         $sth->bind_param( 11, $record{timestamp} );
         $sth->bind_param( 12, $record{hostname} );
         $sth->bind_param( 13, $record{ip_address} );
         $sth->bind_param( 14, $record{promise_handle} );
         $sth->bind_param( 15, $record{promiser} );
         $sth->bind_param( 16, $record{promise_outcome} );
         $sth->bind_param( 17, $record{promisee} );
         $sth->bind_param( 18, $record{policy_server} );
         $sth->execute or warn "cannot execute load [$dbh->errstr]";
      }
   }
   else
   {
      return 0;
   }
   close $fh;
   return 1;
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
