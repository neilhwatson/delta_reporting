package DeltaR::Command::prune;
use Mojo::Base 'Mojolicious::Command';

sub run
{
   my ($self, $target) = @_;
   my $dq = $self->app->dr;

   if ( $target eq 'delete' )
   {
      $dq->delete_records;
      $dq->table_cleanup;
   }
   elsif ( $target eq 'reduce' )
   {
      $dq->reduce_records;
      $dq->table_cleanup;
   }
   else
   {
      usage();
   }

}

sub usage
{
   print <<END;
USAGE:
prune [delete|reduce]

- delete
Deletes records older than days defined in DeltaR.conf.

- reduce
Reduces duplicate records older than day defined in DeltaR.conf to just one per day.

END
}

1;
