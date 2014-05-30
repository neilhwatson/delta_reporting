package DeltaR::Form;

use Mojo::Base 'Mojolicious::Controller';
use POSIX qw( strftime );

sub class_or_promise
{
   my $self = shift;
   my $gmt_offset = strftime "%z", localtime;
   my $timestamp  = strftime "%F %T", localtime;
   $self->stash(
      timestamp    => $timestamp,
      gmt_offset   => $gmt_offset
   );
}

1;

=pod

=head1 SYNOPSIS

This module controls report forms.

=cut
