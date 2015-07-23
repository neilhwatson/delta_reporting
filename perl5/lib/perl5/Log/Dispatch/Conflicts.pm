package # hide from PAUSE
    Log::Dispatch::Conflicts;

use strict;
use warnings;

# this module was generated with Dist::Zilla::Plugin::Conflicts 0.17

use Dist::CheckConflicts
    -dist      => 'Log::Dispatch',
    -conflicts => {
        'Log::Dispatch::File::Stamped' => '0.10',
    },
    -also => [ qw(
        Carp
        Devel::GlobalDestruction
        Dist::CheckConflicts
        Fcntl
        Module::Runtime
        Params::Validate
        Scalar::Util
        Sys::Syslog
        base
        strict
        warnings
    ) ],

;

1;

# ABSTRACT: Provide information on conflicts for Log::Dispatch
# Dist::Zilla: -PodWeaver
