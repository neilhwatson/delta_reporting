package DeltaR::Command::prune;
use Mojo::Base 'Mojolicious::Command';

sub run
{
   my ($self, $target) = @_;
   my $dq = $self->app->dw;

   if ( $target eq 'delete' )
   {
      $dq->delete_records;
   }
   elsif ( $target eq 'reduce' )
   {
      $dq->reduce_records;
   }
   else
   {
      usage();
   }
   $dq->table_cleanup;
   return;
}

sub usage
{
   print <<END;
USAGE:
prune [delete|reduce]

- delete
Deletes records older than days defined in DeltaR.conf.

- reduce
Reduces duplicate records older than day defined in DeltaR.conf to just one per day.

END
   return;
}

1;

=pod

=head1 SYNOPSIS

This module provides a command to control the database table size by reducing records.

=head1 LICENSE

Delta Reporting is a central server compliance log that uses CFEngine.

Copyright (C) 2016 Neil H. Watson http://watson-wilson.ca

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
