package DeltaR::Command::trends;
use Mojo::Base 'Mojolicious::Command';

sub run
{
   my ( $self, $target ) = @_;
   my $ret = 1;
   my $dq = $self->app->dr;

   if ( $target && $target eq 'usage' )
   {
      usage();
   }
   else
   {
      $dq->insert_yesterdays_promise_counts;
   }
}

sub usage
{
   print <<END;
USAGE:
trends

Populates trending table.

END
}

1;

=pod

=head SYNOPSIS

This module provides a command to create trending data

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
