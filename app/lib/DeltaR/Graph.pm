package DeltaR::Graph;

use strict;
use warnings;
use feature 'say';
use Statistics::LineFit;
use Time::Local;
use POSIX 'strftime';
use Mojo::JSON qw(decode_json encode_json);
use Data::Dumper; # TODO remove for production

sub new
{
   my $self = shift;
   bless{};
}

sub nvd3_percent_promise_series
# Build nvd3 data series for percent bar graph
{
   my ( $self, %params ) = @_;
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
   die "Sum is of promises is zero, $!" if ( $sum == 0 );

   foreach my $k ( keys %params )
   {
      $percent{$k} = int( $params{$k} / $sum * 100 );
   }
   return \%percent;
}

sub nvd3_2column_timeseries
# Build nvd3 data series
{
   my ( $self, %params ) = @_;
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


sub nvd3_scatter_series
# Build nvd3 data series for scatter plus line graph.
{
   my ( $self, %params ) = @_;
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

sub encode_to_json
{
   my $self = shift;
   my @data = @_;
   my $json = Mojo::JSON->new;
   my $json_data = $json->encode( @data );
   my $err = $json->error;
   say $err if ( $err );

   return $json_data;
}

sub regression
{
   my %params = @_;
   my @x = @{ $params{x} };
   my @y = @{ $params{y} };
   my %stats;

   my $lineFit = Statistics::LineFit->new( 0, 1 );
   $lineFit->setData( \@x, \@y ) or die "Invalid regression data\n";
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

=pod
Need:
key
table data
=cut

=pod
Return data as array of docs including
key
slope
intercept
array of x:, y: pairs. (date in epoch).
=cut


1;
