package DeltaR::Validator;

use strict;
use warnings;
use Carp;
use Mojolicious::Validator;
use Mojolicious::Validator::Validation;
use Regexp::Common qw/ net number /;
use Data::Dumper; # TODO remove

my %input;
my %my_RE;

sub new {
   my ( $class, $arg_ref ) = @_;
   my $self = bless {}, $class;

   croak "Missing input arg" unless defined $arg_ref->{input};

   $input{$self} = $arg_ref->{input};

   # Set validation regexes and what they apply to

   # Common Regexes for later reuse
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
      promiser        => qr{ [\w/\s\d\.\-\:=]+         }msx,
         

   };
   return $self;
}

sub validate_class_form {
   my $self = shift;
   my %input_regexes= (
      delta_minutes   => qr/\A $my_RE{$self}{time_offset}           \Z/msx,
      gmt_offset      => qr/\A $my_RE{$self}{time_offset}           \Z/msx,
   );
}

sub validate_loading_data {
   # Validate data before it is loaded
   my $self = shift;

   # Here is the allowed config file types
   my %input_regexes= (
      class           => qr/\A \w+ \Z/msx,
      hostname        => qr/\A $RE{net}{domain}{-nospace}{-rfc1101}   \Z/msx,
      ip_address      => qr/\A $my_RE{$self}{ip_address}              \Z/msx,
      policy_server   => qr/\A $my_RE{$self}{hostname_or_ip}          \Z/msx,
      promise_handle  => qr/\A \w+                            | empty \Z/msx,
      promise_outcome => qr/\A $my_RE{$self}{promise_outcome} | empty \Z/msx,
      promisee        => qr/\A $my_RE{$self}{promisee}        | empty \Z/msx,
      promiser        => qr/\A $my_RE{$self}{promiser}        | empty \Z/msx,
      timestamp       => qr/\A 
         $my_RE{$self}{yyyy_mm_dd}
         T
         $my_RE{$self}{hh_mm_ss}
         $my_RE{$self}{time_offset}
      \Z/mxs,
   );

   my $validator = Mojolicious::Validator->new;
   my $validation
      = Mojolicious::Validator::Validation->new(validator => $validator);

   # Validate allowed config types with actaul config data
   for my $next_test ( keys %input_regexes ) {
      $validation->input({ $next_test => $input{ $self }{ $next_test } });
      $validation->required( $next_test)->like( $input_regexes{$next_test});
   }

   # TODO
   my $names = 0;
   $names = $validation->failed;
   if ( scalar  @{ $names } > 0 ){
      return ( "ERROR: These inputs were invalid: ", @{$names} );
   }
   return;
}

sub validate_config {
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

   my $validator = Mojolicious::Validator->new;
   my $validation
      = Mojolicious::Validator::Validation->new(validator => $validator);

   # Validate allowed config types with actaul config data
   for my $next_test ( keys %config_regexes ) {
      $validation->input({ $next_test => $input{ $self }{ $next_test } });
      $validation->required( $next_test)->like( $config_regexes{$next_test});
   }

   my $names = 0;
   $names = $validation->failed;
   if ( scalar  @{ $names } > 0 ){
      return ( "ERROR: These config file settings are invalid:" , @{$names} );
   }
   return;
}

=pod

=head1 SYNOPSIS

Validate Delta Reporting inputs of different types.

=over 3

   my $delta_validator
      = DeltaR::Validator->new({ input => $input_to_validate });

   # Validate Delta Reporting config file input
   $delta_validator->validate_config();

=back

Returns an array of errors if there are any.

=cut

1;
