package # hide from PAUSE
    Log::Dispatch::Conflicts;

use strict;
use warnings;

use Dist::CheckConflicts
    -dist      => 'Log::Dispatch',
    -conflicts => {
        'Log::Dispatch::File::Stamped' => '0.10',
    },

;

1;

# ABSTRACT: Provide information on conflicts for Log::Dispatch

__END__

=pod

=encoding UTF-8

=head1 NAME

Log::Dispatch::Conflicts - Provide information on conflicts for Log::Dispatch

=head1 VERSION

version 2.42

=head1 AUTHOR

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2014 by Dave Rolsky.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut
