package DeltaR::Command::trends;
use Mojo::Base 'Mojolicious::Command';
use DeltaR::Graph;

sub run
{
   my ( $self, $target ) = @_;
   my $ret = 1;
   my $dq = $self->app->dr;
   my $gr = DeltaR::Graph::new;

   if ( $target && $target eq 'usage' )
   {
      usage();
   }
   else
   {
      $dq->insert_yesterdays_promise_counts;
      my $data = $dq->query_promise_counts;
      $ret = $gr->trends( $data );
   }

   return $ret;
}

sub usage
{
   print <<END;
USAGE:
trends

Populates trending table and build trend graphs.

END
}

1;
