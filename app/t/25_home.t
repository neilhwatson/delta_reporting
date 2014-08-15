use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('DeltaR');

$t->ua->max_redirects(1);

$t->get_ok('/')
 ->status_is(200, 'Load /home' )
 ->text_is( 'html body div div ul li a', 'Delta Reporting', 'First menu item is wrong' )

 ->content_like( qr/
    var\s+host_data\s+=\s+\[\s*\{\S*
      ( ("value":"\d+")|("label":"(Active|Missing)") )
      |
      ( ("label":"(Active|Missing)")|("value":"\d+") )
    /msix,
    '/home host count')

 ->content_like( qr/
    var\s+host_data\s+=\s+\[\s*\{\S*
      ( ("value":"\d+")|("label":"(kept|notkept|repaired)") )
      |
      ( ("label":"(kept|notkept|repaired)")|("value":"\d+") )
    /msix,
    '/home promise count');

done_testing();

=pod

=head1 SYNOPSIS

This is for testing the home page.

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
