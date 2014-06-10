package DeltaR::Command::load;
use Mojo::Base 'Mojolicious::Command';

sub run
{
   my ($self, $client_log ) = @_;
   my $ret = 1;
   my $dq = $self->app->dr;

   if ( $client_log eq 'usage' )
   {
      usage();
   }
   elsif ( -r $client_log )
   {
      $ret = $dq->insert_client_log( $client_log );
   }
   else
   {
      warn "cannot read $client_log, $!";
      $ret = 2
   }

   return $ret;
}


sub usage
{
   print <<END;
USAGE:
load [file]

- load
Load agent log into Delta Reporting database.

END
}

1;
