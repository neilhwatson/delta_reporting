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
