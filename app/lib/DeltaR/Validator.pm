package DeltaR::Validator;

use strict;
use warnings;
use Carp;
use Mojolicious::Validator;
use Mojolicious::Validator::Validation;
use Regexp::Common qw/ net number /;

my %input;
my %my_RE;

sub new {
   my ( $class, $arg_ref ) = @_;
   my $self = bless {}, $class;

   croak "Missing input arg" unless defined $arg_ref->{input};

   $input{$self} = $arg_ref->{input};

   # Common Regexes for later reuse
   my $sql_wildcards = '%_';
   $my_RE{$self} = {
      ip_address     => qr/
         (?: $RE{net}{IPv6} ) |
         (?: $RE{net}{IPv4} )
      /msx,

      hostname_or_ip => qr/
         (?: $RE{net}{IPv6} ) |
         (?: $RE{net}{IPv4} ) |
         (?: $RE{net}{domain}{-nospace}{-rfc1101} )
      /msx,

      yyyy_mm_dd      => qr/ \d{4}-\d{2}-\d{2}         /msx,
      hh_mm_ss        => qr/ \d{2}:\d{2}:\d{2}         /msx,
      time_offset     => qr/[+-]{0,1} \d{1,4}          /msx,
      unsigned_int    => qr/$RE{num}{int}{-sign => ''} /msx,
      promise_outcome => qr/ (?:not)?kept | repaired   /msx,
      promisee        => qr{ [\w/\s\d\.\-\:]+          }msx,
      promiser        => qr/ .*                        /msx,
      sql_wildcard    => $sql_wildcards,

      query_hostname        => qr/\A [\w\d\.\-$sql_wildcards]+  \Z/msx,
      query_policy_server   => qr/\A [\w\d\.:\-$sql_wildcards]+ \Z/msx,
      query_ip_address      => qr/\A [a-f0-9\.:$sql_wildcards]+ \Z/imsx,
      query_latest_record   => qr/\A [01]{1}                    \Z/msx,
   };
   return $self;
}

sub promise_query_form {
   my $self = shift;
   my %form_regexes = (
      hostname        => qr/ $my_RE{$self}{query_hostname}             \Z/msx,
      ip_address      => qr/ $my_RE{$self}{query_ip_address}           \Z/msx,
      policy_server   => qr/ $my_RE{$self}{query_policy_server}        \Z/msx,
      latest_record   => qr/ $my_RE{$self}{query_latest_record}        \Z/msx,
      promise_handle  => qr/\A [\w\d$my_RE{$self}{sql_wildcard}     ]+ \Z/msx,
      promiser        => qr{\A
                         [\w\d\s\-/$my_RE{$self}{sql_wildcard} ]+      \Z}msx,
      promisee        => qr/\A
                         [\w\s\d\.\-:$my_RE{$self}{sql_wildcard}    ]+ \Z/msx,
      promise_outcome => qr/\A
                         (?: $my_RE{$self}{promise_outcome} | empty )  \Z/msx,
   );

   # These parms are require for time queries and not the latest record.
   if ( $input{$self}{latest_record} == 0 ) {
      %form_regexes = (
         %form_regexes,
         gmt_offset      => qr/\A $my_RE{$self}{time_offset} \Z/msx,
         delta_minutes   => qr/\A $my_RE{$self}{time_offset} \Z/msx,
         timestamp       => qr/\A 
            $my_RE{$self}{yyyy_mm_dd}
            \Q \E # A single space
            $my_RE{$self}{hh_mm_ss}
         \Z/mxs,
      );
   }
   return $self->_validate( \%form_regexes );
}

sub class_query_form {
   my $self = shift;
   # TODO allow for wild cards
   my %form_regexes = (
      class           => qr/\A [\w\d$my_RE{$self}{sql_wildcard}]+ \Z/msx,
      hostname        => qr/ $my_RE{$self}{query_hostname}        \Z/msx,
      ip_address      => qr/ $my_RE{$self}{query_ip_address}      \Z/msx,
      policy_server   => qr/ $my_RE{$self}{query_policy_server}   \Z/msx,
      latest_record   => qr/ $my_RE{$self}{query_latest_record}   \Z/msx,
   );

   # These parms are require for time queries and not the latest record.
   if ( $input{$self}{latest_record} == 0 ) {
      %form_regexes = (
         %form_regexes,
         gmt_offset      => qr/\A $my_RE{$self}{time_offset} \Z/msx,
         delta_minutes   => qr/\A $my_RE{$self}{time_offset} \Z/msx,
         timestamp       => qr/\A 
            $my_RE{$self}{yyyy_mm_dd}
            \Q \E # A single space
            $my_RE{$self}{hh_mm_ss}
         \Z/mxs,
      );
   }
   return $self->_validate( \%form_regexes );
}

sub client_log {
   # Validate data before it is loaded
   my $self = shift;

   # Here is the allowed config file types
   my %input_regexes= (
      class           => qr/\A \w+ \Z/msx,
      promise_handle  => qr/\A \w+ \Z/msx,
      promiser        => qr/\A .*  \Z/msx,
      hostname        => qr/\A $RE{net}{domain}{-nospace}{-rfc1101}   \Z/msx,
      ip_address      => qr/\A (?: $my_RE{$self}{ip_address}        ) \Z/msx,
      policy_server   => qr/\A (?: $my_RE{$self}{hostname_or_ip}    ) \Z/msx,
      promisee        => qr/\A $my_RE{$self}{promisee}                \Z/msx,
      promise_outcome => qr/\A
                         (?: $my_RE{$self}{promise_outcome} | empty ) \Z/msx,
      timestamp       => qr/\A 
         $my_RE{$self}{yyyy_mm_dd}
         T
         $my_RE{$self}{hh_mm_ss}
         $my_RE{$self}{time_offset}
      \Z/mxs,
   );

   return $self->_validate( \%input_regexes );
}

sub config_file{
   my $self = shift;

   # Here is the allowed config file types
   my %config_regexes = (
      db_name         => qr/\A \w+                           \Z/msx,
      db_user         => qr/\A \w+                           \Z/msx,
      db_wuser        => qr/\A \w+                           \Z/msx,
      db_host         => qr/\A $my_RE{$self}{hostname_or_ip} \Z/msx,
      agent_table     => qr/\A \w+                           \Z/msx,
      promise_counts  => qr/\A \w+                           \Z/msx,
      inventory_table => qr/\A \w+                           \Z/msx,
      record_limit    => qr/\A $my_RE{$self}{unsigned_int}   \Z/msx,
      inventory_limit => qr/\A $my_RE{$self}{unsigned_int}   \Z/msx,
      delete_age      => qr/\A $my_RE{$self}{unsigned_int}   \Z/msx,
      reduce_age      => qr/\A $my_RE{$self}{unsigned_int}   \Z/msx,
   );

   return $self->_validate( \%config_regexes );
}

sub _validate {
   my ( $self, $test_ref ) = @_;

   # ({ tests => \%regexes, required|optional => [01] })
   warn "Missing self"         unless defined $self;
   warn "Missing test hashref" unless defined $test_ref;
   my @caller = caller(1);
   ( my $caller_sub = $caller[3] ) =~ s/\A\w+:://g;

   my $validator = Mojolicious::Validator->new;
   my $validation
      = Mojolicious::Validator::Validation->new(validator => $validator);

   # Validate allowed config types with actaul config data
   for my $next_test ( keys %{ $test_ref } ) {
      $validation->input({ $next_test => $input{ $self }{ $next_test } });
      $validation->required( $next_test)->like( $test_ref->{$next_test});
   }

   my $names = 0;
   $names = $validation->failed;
   if ( scalar  @{ $names } > 0 ){
      return (
         "ERROR: These inputs for $caller_sub are invalid: " , @{$names} );
   }
   return;
}

sub DESTROY {
   my $dead_body = $_[0];
   delete $input{$dead_body};
   delete $my_RE{$dead_body};
   my $super = $dead_body->can("SUPER::DESTROY");
   goto &$super if $super;
}

=pod

=head1 SYNOPSIS

Validate Delta Reporting inputs of different types.

=over 3

   my $delta_validator
      = DeltaR::Validator->new({ input => $input_to_validate });

   # Validate Delta Reporting config file input
   my @validator_errors = $delta_validator->config_file();
   croak @validator_errors if ( (scalar @validator_errors) > 0 );

=back

Returns an array of errors if there are any.

=cut

1;
