package Log::Dispatch::Syslog;
$Log::Dispatch::Syslog::VERSION = '2.42';
use strict;
use warnings;

use Log::Dispatch::Output;

use base qw( Log::Dispatch::Output );

use Params::Validate qw(validate ARRAYREF BOOLEAN HASHREF SCALAR);
Params::Validate::validation_options( allow_extra => 1 );

use Scalar::Util qw( reftype );
use Sys::Syslog 0.28 ();

sub new {
    my $proto = shift;
    my $class = ref $proto || $proto;

    my %p = @_;

    my $self = bless {}, $class;

    $self->_basic_init(%p);
    $self->_init(%p);

    return $self;
}

my ($Ident) = $0 =~ /(.+)/;

sub _init {
    my $self = shift;

    my %p = validate(
        @_, {
            ident => {
                type    => SCALAR,
                default => $Ident
            },
            logopt => {
                type    => SCALAR,
                default => ''
            },
            facility => {
                type    => SCALAR,
                default => 'user'
            },
            socket => {
                type    => SCALAR | ARRAYREF | HASHREF,
                default => undef
            },
            lock => {
                type    => BOOLEAN,
                default => 0,
            },
        }
    );

    $self->{$_} = $p{$_} for qw( ident logopt facility socket lock );
    if ( $self->{lock} ) {
        require threads;
        require threads::shared;
    }

    $self->{priorities} = [
        'DEBUG',
        'INFO',
        'NOTICE',
        'WARNING',
        'ERR',
        'CRIT',
        'ALERT',
        'EMERG'
    ];
}

my $thread_lock;
sub log_message {
    my $self = shift;
    my %p    = @_;

    my $pri = $self->_level_as_number( $p{level} );

    eval {
        threads::shared::lock($thread_lock) if $self->{lock};

        if ( defined $self->{socket} ) {
            Sys::Syslog::setlogsock(
                ref $self->{socket} && reftype( $self->{socket} ) eq 'ARRAY'
                ? @{ $self->{socket} }
                : $self->{socket}
            );
        }

        Sys::Syslog::openlog(
            $self->{ident},
            $self->{logopt},
            $self->{facility}
        );
        Sys::Syslog::syslog( $self->{priorities}[$pri], $p{message} );
        Sys::Syslog::closelog;
    };

    warn $@ if $@ and $^W;
}

1;

# ABSTRACT: Object for logging to system log.

__END__

=pod

=encoding UTF-8

=head1 NAME

Log::Dispatch::Syslog - Object for logging to system log.

=head1 VERSION

version 2.42

=head1 SYNOPSIS

  use Log::Dispatch;

  my $log = Log::Dispatch->new(
      outputs => [
          [
              'Syslog',
              min_level => 'info',
              ident     => 'Yadda yadda'
          ]
      ]
  );

  $log->emerg("Time to die.");

=head1 DESCRIPTION

This module provides a simple object for sending messages to the
system log (via UNIX syslog calls).

Note that logging may fail if you try to pass UTF-8 characters in the
log message. If logging fails and warnings are enabled, the error
message will be output using Perl's C<warn>.

=for Pod::Coverage new log_message

=head1 CONSTRUCTOR

The constructor takes the following parameters in addition to the standard
parameters documented in L<Log::Dispatch::Output>:

=over 4

=item * ident ($)

This string will be prepended to all messages in the system log.
Defaults to $0.

=item * logopt ($)

A string containing the log options (separated by any separator you
like). See the openlog(3) and Sys::Syslog docs for more details.
Defaults to ''.

=item * facility ($)

Specifies what type of program is doing the logging to the system log.
Valid options are 'auth', 'authpriv', 'cron', 'daemon', 'kern',
'local0' through 'local7', 'mail, 'news', 'syslog', 'user',
'uucp'. Defaults to 'user'

=item * socket ($, \@, or \%)

Tells what type of socket to use for sending syslog messages. Valid
options are listed in C<Sys::Syslog>.

If you don't provide this, then we let C<Sys::Syslog> simply pick one
that works, which is the preferred option, as it makes your code more
portable.

If you pass an array reference, it is dereferenced and passed to
C<Sys::Syslog::setlogsock()>.

If you pass a hash reference, it is passed to C<Sys::Syslog::setlogsock()> as
is.

=item * lock ($)

If this is set to a true value, then the calls to C<setlogsock()>,
C<openlog()>, C<syslog()>, and C<closelog()> will all be guarded by a
thread-locked variable.

This is only relevant when running you are using Perl threads in your
application. Setting this to a true value will cause the L<threads> and
L<threads::shared> modules to be loaded.

This defaults to false.

=back

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
