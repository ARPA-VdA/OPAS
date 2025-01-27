package Bobo::Controller::Divulgazione;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

# !! notifiche
sub notifiche {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Divulgazione notifiche");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # Render template "divulgazione/notifiche.html.ep" with message
    $self->render('divulgazione/notifiche');
}

sub get_stations_grants {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Divulgazione get_stations_grants");

    my $userid = $self->session('it.ecometer.bobo');

    # get group stations grants by an ajax call
    my $stations = $self->dbdivulgazione->get_notification_stations_grants($userid);

    my $json;

    if (defined $stations) {
        $json = {
            res => "OK",
            stations => $stations
        };
    }
    else {
       $json = {
            res => "ERR"
        };
    }

    $self->render(json => $json);
}

sub put_grants {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Divulgazione put_grants");

    $self->helperDumperPostData('Divulgazione', 'put_grants', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $grants = decode_json(encode_utf8($params->{'grants'}));

    my $res = 1;

    if ($self->dbdivulgazione->update_notification_stations_grants($grants)) {
        $self->app->log->debug("Success");
    }
    else {
        $self->app->log->debug("Error");
        $res = 0;
    }

    $self->render(json => $res);
}

1;

=head1 notifiche

Render della pagina di notifiche della stazione.

Argomenti:  /

Return:     /

=cut

=head1 get_stations_grants

Funzione per recuperare le informazioni relative alle stazioni in base ai permessi dell'utente loggato.

Argomenti:  * id dell'utente ('userid');

Return:     json contenente la risposta "OK" e le stazioni, oppure solamente la risposta "ERR".

=cut

=head1 put_grants

Funzione per inserire/modificare, oppure eliminare, i permessi notifiche delle stazioni.

Argomenti:  * oggetto contenente i relativi permessi ('params');

Return:     json contenente:

            - Se OK: 1

            - Se KO: 0

=cut