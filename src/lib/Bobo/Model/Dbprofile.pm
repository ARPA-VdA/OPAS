package Bobo::Model::Dbprofile;
use Mojo::Base -base;

use Data::Dumper;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

sub update_user(){
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbprofile - update user");
    $self->app->log->debug($params->{'mod-user-name'});

    # ##################################################################
    # 1- modifica utente
    # ##################################################################
    $self->pg->db->update('bobo.users', {
        us_name     => $params->{'mod-user-name'},
        us_2nd_name => $self->app->helperEscapeParam($params->{'mod-user-secondname'}),
        us_surname  => $params->{'mod-user-surname'},
        us_role     => $self->app->helperEscapeParam($params->{'mod-user-role'}),
        us_mobile   => $self->app->helperEscapeParam($params->{'mod-user-mobile'}),
        us_phone    => $self->app->helperEscapeParam($params->{'mod-user-phone'}),
        us_email    => $params->{'mod-user-email'},
        us_exp_time => $self->app->helperEscapeParam($params->{'mod-user-session'})
    }, { us_id => $params->{'mod-user-id'} });

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       return 0;
    }
    else {
       return 1;
    }
}


1;

=head1 update_user

Funzione che effettua l'update delle informazioni relative
all'utente.

Argomenti:  * informazioni dell'utente ('params');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut