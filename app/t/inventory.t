use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('DeltaR');

$t->ua->max_redirects(1);

$t->get_ok('/report/inventory')
 ->status_is(200)

 ->element_exists( 'html head title' => 'Inventory Report',
    '/report/inventory has wrong title' )

 ->content_like( qr(
    <td>any</td>
    \s*
    <td>\d+</td>
    )msix, 'Inventory tables has no any class' )

 ->text_like( 'html body div script' => qr/dataTable/, 'Missing dataTable script' );

done_testing();

=pod

=head1 SYNOPSIS

This is for testing the inventory report.

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
