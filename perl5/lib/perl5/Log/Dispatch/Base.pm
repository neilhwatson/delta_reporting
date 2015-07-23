package Log::Dispatch::Base;

use strict;
use warnings;

our $VERSION = '2.45';

sub _get_callbacks {
    shift;
    my %p = @_;

    return unless exists $p{callbacks};

    return @{ $p{callbacks} }
        if ref $p{callbacks} eq 'ARRAY';

    return $p{callbacks}
        if ref $p{callbacks} eq 'CODE';

    return;
}

sub _apply_callbacks {
    my $self = shift;
    my %p    = @_;

    my $msg = delete $p{message};
    foreach my $cb ( @{ $self->{callbacks} } ) {
        $msg = $cb->( message => $msg, %p );
    }

    return $msg;
}

sub add_callback {
    my $self  = shift;
    my $value = shift;

    Carp::carp("given value $value is not a valid callback")
        unless ref $value eq 'CODE';

    $self->{callbacks} ||= [];
    push @{ $self->{callbacks} }, $value;

    return;
}

1;

# ABSTRACT: Code shared by dispatch and output objects.

__END__

=pod

=head1 NAME

Log::Dispatch::Base - Code shared by dispatch and output objects.

=head1 VERSION

version 2.45

=head1 SYNOPSIS

  use Log::Dispatch::Base;

  ...

  @ISA = qw(Log::Dispatch::Base);

=head1 DESCRIPTION

Unless you are me, you probably don't need to know what this class
does.

=for Pod::Coverage add_callback

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2015 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
