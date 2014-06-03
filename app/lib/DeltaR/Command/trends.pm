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
