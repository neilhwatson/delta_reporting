package DeltaR::Validator;

use strict;
use warnings;
use Carp;
use Mojolicious::Validator;
use Mojolicious::Validator::Validation;
use Regexp::Common qw/ net number /;

my %input;
my %regex;

sub new {
   my ( $class, $arg_ref ) = @_;
   my $self = bless {}, $class;

   croak "Missing iput arg" unless defined $arg_ref->{input};

   $input{$self} = $arg_ref->{input};

   # set validation regexes and who they apply to
   $regex{$self} = {
      word => {
         regex  => qr/\A \w+ \Z/msx,
         config => [ qw/ db_name db_user db_wuser agent_table promise_counts
            inventory_table / ],
      },
      number => {
         regex  => qr/$RE{num}{int}{-sign => ''}/msx,
         config => [qw/ record_limit inventory_limit delete_age reduce_age/],
      },
      host => {
         regex  => qr/
            (?: $RE{net}{IPv6} ) |
            (?: $RE{net}{IPv4} ) |
            # domain that start with a number
            (?: $RE{net}{domain}{-nospace}{-rfc1101} )
            /mxs,
         config => [ qw/ db_host / ],
      },
   };
   return $self;
}

sub validate_config {
   my $self = shift;
   my $return;

   my $validator = Mojolicious::Validator->new;
   my $validation
      = Mojolicious::Validator::Validation->new(validator => $validator);

   for my $next_regex ( keys %{ $regex{$self} } ){

      if ( exists $regex{ $self }{ $next_regex }{ config } ) {
         for my $next_config ( @{ $regex{ $self }{ $next_regex }{ config }}){

            my $config_name  = $next_config;
            my $config_value = $input{ $self }{ $next_config };
            my $valid_regex  = $regex{ $self }{ $next_regex}{regex};

            $validation->input({ $config_name => $config_value });
            $validation->required( $config_name)->like( $valid_regex );
         }
      }
   }
   # qr/ \A $RE{net}{domain}{-nospace} \Z /mxs );

   my $names = 0;
   $names = $validation->failed;
   if ( scalar  @{ $names } > 0 ){
      warn "ERROR: These settings in config file are invalid: @{$names}";
      return;
   }
   return 1;
}

=pod

=head1 SYNOPSIS

Validate Delta Reporting input of different types.

=over 3

   my $delta_validator
      = DeltaR::Validator->new({ input => $input_to_validate });

   # Validate Delta Reporting config file input
   $delta_validator->validate_config();

=back

=cut

1;
