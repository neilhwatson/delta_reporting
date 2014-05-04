package DeltaR::Graph;

use strict;
use warnings;
use Statistics::LineFit;
use Data::Dumper; # TODO remove for production

our $gnuplot;

sub new
{
   my $self = shift;
   bless{};
}

sub trends
{
   my ( $self, %params ) = @_;

=pod
Need:
key
table data
=cut

   print Dumper( \%params );
   my @data = @{$params{data}};
   for my $r ( @data )
   {
      print "date = ".$r->[0]."\n";
      print "count = ".$r->[1]."\n";
   }
=pod
Return data as array of docs including
key
slope
intercept
array of x:, y: pairs. (date in epoch).
=cut
}

sub graph
{
   my ( $self, %param ) = @_;
   my $string    = $param{'string'};
   my $y_axis    = $string;
   my $title     = "Promises $string";
   my $data_file = "/tmp/" .$$. "_" .$string. "_trend.data";
   my $png_file  = "/opt/delta_reporting/app/public/media/".$string."_trend.png";
   my $plot      = <<END;
set title '$title'
set output '$png_file'
set xlabel "Date"
set ylabel "Count"
set rmargin 7

set border linewidth 2
set style line 1 linecolor rgb 'orange' linetype 1 linewidth 2
set style line 2 linecolor rgb 'yellow' linetype 1 linewidth 2
set style fill solid

set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m-%d"
set grid front
set grid
set autoscale

# 1e8 reduces the epoch seconds for a less flat line.
p(x) = m1 * x/1e8 +b1
fit p(x) '$data_file' using 1:3 via m1,b1
h(x) = m2 * x/1e8 +b2
fit h(x) '$data_file' using 1:2 via m2,b2

set terminal png enhanced size 1024,768
plot '$data_file' using 1:2 notitle with boxes lc rgb "blue", p(x) title 'Promise count trend' with lines linestyle 1, h(x) title 'Host count trend' with lines linestyle 2
END

   open (DATA_FILE, ">", "$data_file" ) or die "Cannot open $data_file";
   foreach my $k ( sort keys %{ $param{'data'} } )
   {
      say DATA_FILE $k." ".
         $param{'data'}->{$k}->{hosts}." ".
         $param{'data'}->{$k}->{$y_axis};
   }
   close DATA_FILE;

   open (GNUPLOT, "| $gnuplot 2> /dev/null ") or die "Cannot pipe to $gnuplot";
   say GNUPLOT $plot;
   close GNUPLOT;

   unlink $data_file;
}
1;
