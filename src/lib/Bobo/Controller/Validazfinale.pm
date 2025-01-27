package Bobo::Controller::Validazfinale;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub validaz_finale {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub validaz_finale");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get codes
    my $codes = $self->dbvalidazfinale->get_validation_codes($user_id);
    $self->stash(codes => $codes);

    # get users
    my $users = $self->dbcommon->get_portal_users_by_user($user_id);
    $self->stash(users => $users);

    $self->helperGetPortalPageOptions();

    # -------------------------------------------------------
    # render page
    # -------------------------------------------------------
    $self->render('dati/validaz_finale');
}

sub get_validation_per_year {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub get_validation_per_year");

    my $year = $self->param('year'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("Anno: $year");

    my $user_id = $self->session('it.ecometer.bobo');

    my $json;
    my $codes = $self->dbvalidazfinale->get_portal_codes($user_id);
    my $data = $self->dbvalidazfinale->get_validation_per_year($user_id, $year, $stid);

    if (defined $data) {
        $json = {
            res => "OK",
            codes => $codes,
            data => $data
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_validation_table {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub get_validation_table");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post
    my $param = $self->param('param'); # post
    my $conv = $self->param('conv'); # post

    $stid = decode_json(encode_utf8($stid));
    $param = decode_json(encode_utf8($param));

    my $user_id = $self->session('it.ecometer.bobo');

    my $codes = $self->dbvalidazfinale->get_portal_codes($user_id);
    my $data = $self->dbvalidazfinale->get_validation_table($user_id, $from, $to, $stid, $param, $conv);

    my $json = {
        res => "OK",
        codes => $codes,
        data => $data
    };

    # render
    $self->render(json => $json);
}

sub get_station_data_by_stprid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub get_station_data_by_stprid");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stprid = $self->param('stprid'); # post
    my $conv = $self->param('conv'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");

    # get data from date 'from' to date 'to'
    my $json;
    my $data = $self->dbdatamanager->get_data_per_validation_by_stprid($from, $to, $stprid, $conv);

    if (defined $data) {
        $json = {
            res => "OK",
            data => $data
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_activities_log {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub get_activities_log");

    my $from = $self->param('from'); # post
    my $to   = $self->param('to');   # post
    my $lvl  = $self->param('lvl');  # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post
    my $usid = $self->param('usid'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Stazione: $stid");

    my $user_id = $self->session('it.ecometer.bobo');

    # get data from date 'from' to date 'to'
    my $json;
    my $data = $self->dbvalidazfinale->get_activities_log($user_id, $from, $to, $lvl, $prid, $stid, $usid);

    if (defined $data) {
        $json = {
            res => "OK",
            data => $data
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub put_final_validation {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Validazfinale sub put_final_validation");

    $self->helperDumperPostData('Validazfinale', 'put_final_validation', $self->req->body_params);

    my $from   = $self->param('from'); # post
    my $to     = $self->param('to'); # post
    my $stprid = $self->param('stprid'); # post
    my $code   = $self->param('code'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Stprid: $stprid, codice: $code");

    my $user_id = $self->session('it.ecometer.bobo');

    my $res = $self->dbvalidazfinale->update_final_validity_code($user_id, $stprid, $from, $to, $code);

    my $json;
    if ($res >= 0) {
        $json = {
            res => "OK",
            rows => $res
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

1;

=head1 validaz_finale

Render della pagina relativa alla validazione multilivello.

Argomenti:  /

Return:     /

=cut

=head1 get_validation_per_year

Funzione per recuperare le validazioni effettuate in un determinato anno per i parametri di una
determinata stazione.

Argomenti:  * anno ('year');

           * id della stazione ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK", i dati e i relativi codici di validazione, oppure il messaggio "ERR".

=cut

=head1 get_validation_table

Funzione per recuperare i dati sospetti di una determinata stazione visibili dall'utente
loggato all'interno dello strumento 'Validazione'.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * oggetto contenente i parametri ('param');

           * valore booleano relativo alla visualizzazione dei dati convertiti ('conv');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK", i dati e i relativi codici di validazione, oppure il messaggio "ERR".

=cut

=head1 get_station_data_by_stprid

Funzione per recuperare i dati di determinati parametri associati ad una stazione
in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id relativo ad un determinato parametro associato ad una determinata stazione ('stprid');

           * valore booleano relativo alla visualizzazione dei dati convertiti ('conv');

Return:     se presenti: json contenente i dati e il messaggio "OK"

           altrimenti: json di errore;

=cut

=head1 get_activities_log

Funzione per recuperare il registro delle attivita' eseguite dagli utenti.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * tipo di validazione applicata ('lvl');

           * id del parametro ('prid');

           * id della stazione ('stid');

           * id dell'utente che ha effettuato le attivita' ('usid');

           * id dell'utente loggato ('user_id');

Return:     se presenti: json contenente i dati e il messaggio "OK"

           altrimenti: json di errore;

=cut

=head1 put_final_validation

Funzione per recuperare i dati di determinati parametri associati ad una stazione
in un determinato periodo temporale ed effettuarne le la validazione finale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id relativo ad un determinato parametro associato ad una determinata stazione ('stprid');

           * codice di validazione applicato dall'utente ('code');

Return:     se presenti: json contenente i dati e il messaggio "OK"

           altrimenti: json di errore;

=cut