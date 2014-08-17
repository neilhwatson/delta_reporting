package DeltaR::Graph;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::JSON 'encode_json';
use feature 'say';
use Statistics::LineFit;
use Time::Local;

sub trend
{
   my $self = shift;
   my $subject = $self->param('subject');
   my $column = lc $subject;
   $subject = 'Not Kept' if ( $subject eq 'NotKept' );
   my $dq = $self->app->dr;
   my @columns = ( 'Date', 'Hosts', $subject );
   my $rows = $dq->query_promise_count( 'hosts', $column );

   my ( $hosts_series, $hosts_stats ) = nvd3_scatter_series( 
      key => 'Hosts',
      column => 1,
      rows => $rows
   );
   my ( $promise_series, $promise_stats ) = nvd3_scatter_series( 
      key => $subject,
      column => 2,
      rows => $rows
   );
   my @json_data_series = ( \%$hosts_series, \%$promise_series );
   my $json_data_series = encode_json( \@json_data_series );

   $self->render(
      template      => 'report/trend',
      title         => "Promises $subject trend",
      rows          => $rows,
      dr_data       => $json_data_series,
      hosts_stats   => $hosts_stats,
      promise_stats => $promise_stats,
      columns       => \@columns 
   );
}

sub percent_promise_summary
{
   my $self = shift;
   my @columns = ( 'Date', 'Hosts', 'Kept', 'Repaired', 'Not kept' );
   my $dq = $self->app->dr;
   my $rows = $dq->query_promise_count( 'hosts', 'kept', 'repaired', 'notkept' );

   my $host_series = nvd3_2column_timeseries(
      key => "Hosts",
      x_column => 0,
      y_column => 1,
      rows => $rows
      );
   my $json_host_series = encode_json( \%$host_series );

   my $percent_series = nvd3_percent_promise_series( rows => $rows );
   my $json_percent_series = encode_json( \@$percent_series );

   $self->render(
      template       => 'report/pps',
      title          => "Promise percent summary",
      rows           => $rows,
      percent_series => $json_percent_series,
      host_series    => $json_host_series,
      columns        => \@columns 
   );
}

sub nvd3_2column_timeseries
# Build nvd3 data series
{
   my %params = @_;
   my %series;

   $series{key} = $params{key};
   
   for my $r ( @{$params{rows}} )
   {
      my $epoch = convert_to_epoch( $r->[$params{x_column}] );
      my $y = $r->[$params{y_column}];

      my $rec = {};
      $rec->{x} = $epoch;
      $rec->{y} = $y;
      push @{ $series{values} }, $rec;
   } 
   return \%series;
}

sub nvd3_percent_promise_series
# Build nvd3 data series for percent bar graph
{
   my %params = @_;
   my ( @series, $rec );

   $series[0]{key} = "Kept";
   $series[1]{key} = "Repaired";
   $series[2]{key} = "Not kept";

   for my $r ( @{$params{rows}} )
   {
      my $epoch = convert_to_epoch( $r->[0] );

      my $percent = calc_percent(
         kept => $r->[2],
         repaired => $r->[3],
         notkept => $r->[4],
      );

      $rec = {};
      $rec->{x} = $epoch;
      $rec->{y} = $percent->{kept};
      push @{ $series[0]{values} }, $rec;

      $rec = {};
      $rec->{x} = $epoch;
      $rec->{y} = $percent->{repaired};
      push @{ $series[1]{values} }, $rec;

      $rec = {};
      $rec->{x} = $epoch;
      $rec->{y} = $percent->{notkept};
      push @{ $series[2]{values} }, $rec;
   }
   return \@series
}

sub calc_percent
{
   my %params = @_;
   my ( %percent, $sum );
   my @values = values %params;
   $sum += $_ for @values;

   for my $k ( keys %params )
   {
      # Guard against divide by zero;
      if ( $sum == 0 )
      {
         $percent{$k} = 0;
      }
      else
      {
         $percent{$k} = int( $params{$k} / $sum * 100 );
      }
   }
   return \%percent;
}

sub nvd3_scatter_series
# Build nvd3 data series for scatter plus line graph.
{
   my %params = @_;
   my ( @x_axis, @y_axis );
   my %series;
   $series{key} = $params{key};
   my $column = $params{column};
   my $rows = $params{rows};

   for my $r ( @$rows )
   {
      my $epoch = convert_to_epoch( $r->[0] );
      push @x_axis, $epoch;
      my $y = $r->[$column];
      push @y_axis, $y;

      my $rec = {};
      $rec->{x} = $epoch;
      $rec->{y} = $y;
      push @{ $series{values} }, $rec;

   }
   my %stats = regression( x => \@x_axis, y => \@y_axis );

   for my $k ( qw/Slope Intercept/ )
   {
      $series{ lc $k } = $stats{$k};
   }

   return ( \%series, \%stats );
}

sub regression
{
   my %params = @_;
   my @x = @{ $params{x} };
   my @y = @{ $params{y} };
   my %stats;

   my $lineFit = Statistics::LineFit->new( 0, 1 );
   $lineFit->setData( \@x, \@y ) or warn "Invalid regression data\n";
   ( $stats{Intercept}, $stats{Slope} ) = $lineFit->coefficients();
   $stats{Stderr} = $lineFit->sigma();
   $stats{Correlation} = $lineFit->rSquared();

   return %stats;
}

sub convert_to_epoch
{
   my $date = shift;
   my ( $y, $m, $d ) = split /-/, $date;
   return timelocal( '59', '59', '23', $d, $m-1, $y );
}

1;

=pod

=head1 SYNOPSIS

This module holds subs used for generating graph pages.

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

