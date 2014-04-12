#!/usr/bin/perl 

use strict;
use warnings;

use lib qw(lib ../perl5/lib/perl5/);
use Mojolicious::Commands;

Mojolicious::Commands->start_app('DeltaR');
