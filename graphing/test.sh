#!/usr/bin/gnuplot

#set output "test.png"
set title "Promises not kept"
set xlabel "Date"
set ylabel "Count"
set rmargin 7

set border linewidth 2
set style line 1 linecolor rgb 'blue' linetype 1 linewidth 2
set style line 2 linecolor rgb 'black' linetype 1 linewidth 2
set style fill solid

set xdata time
set timefmt "%Y-%m-%d"
set format x "%Y-%m-%d"
set grid front
set grid
set autoscale

# 1e8 reduces the epoch seconds for a less flat line.
h(x) = m2 * x + b2
fit h(x) 'test.dat' using 1:3 via m2,b2
p(x) = m1 * x + b1
fit p(x) 'test.dat' using 1:2 via m1,b1

#set terminal png enhanced size 1024,768
plot 'test.dat' using 1:2 title 'Promises not kept' with boxes lc rgb "orange", \
p(x) title 'Promise Trend' with lines linestyle 1, \
h(x) title 'Host Trend' with lines linestyle 2

pause -1
