package DeltaR::Command::load;
use Mojo::Base 'Mojolicious::Command';

sub run
{
   my ($self, $client_log ) = @_;
   my $ret = 1;

   if ( $client_log eq 'usage' )
   {
      usage();
   }
   elsif ( -r $client_log )
   {
      $ret = $self->app->dw->insert_client_log( $client_log );
   }
   else
   {
      warn "cannot read $client_log, $!";
      $ret = 2
   }

   return $ret;
}


sub usage
{
   print <<END;
USAGE:
load [file]

- load
Load agent log into Delta Reporting database.

END
   return;
}

1;

=pod

=head1 SYNOPSIS

This module loads agent data into the DR database.

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
