package Bobo::Controller::Planperiferia;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

sub attivita {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia attivita");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get types
    my $types = $self->dbplanperiferia->get_types();
    $self->stash(types => $types);

    # get categories
    my $categories = $self->dbplanperiferia->get_categories();
    $self->stash(categories => $categories);

    # get urgencies
    my $urgencies = $self->dbplanperiferia->get_urgencies();
    $self->stash(urgencies => $urgencies);

    # get frequencies
    my $frequencies = $self->dbplanperiferia->get_frequencies();
    $self->stash(frequencies => $frequencies);

    # get companies
    my $companies = $self->dbcommon->get_companies_by_portal($user_id);
    $self->stash(companies => $companies);

    # get if user company is admin
    my $user = $self->dbcommon->get_user_byid($user_id);
    $self->stash(company_admin => $user->{'company_admin'});

    my $lists = $self->dbemailgest->get_mailing_lists($user_id);
    $self->stash(lists => $lists);

    # Render template "planning/attivita.html.ep" with message
    $self->render('planning/attivita');
}

sub get_equipments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub get_equipments");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    my $dt = $self->param('dt'); # post
    $self->app->log->debug("data e ora: $dt");

    # get instruments from station
    my $instruments = $self->dbcommon->get_instruments_by_station_date($stid, $dt);
    my $cylinders = $self->dbcommon->get_cylinders_by_station_date($stid, $dt);
    my $miscellanies = $self->dbcommon->get_miscellanies_by_station_date($stid, $dt);

    my $json;
    if (defined $instruments) {
        $json = {
            res => "OK",
            instruments => $instruments,
            tanks => $cylinders,
            miscellanies => $miscellanies
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

sub get_maintenances {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub get_maintenances");

    my $tkid = $self->param('tkid'); # post
    $self->app->log->debug("ID ticket: $tkid");

    # get maintenances from ticket
    my $reports = $self->dbplanperiferia->get_maintenances($tkid);

    my $json;
    if (defined $reports) {
        $json = {
            res => "OK",
            reports => $reports
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

sub get_tickets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub get_tickets");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $comp = $self->param('comp'); # post
    my $prov = $self->param('prov'); # post
    my $stid = $self->param('stid'); # post
    my $hide = $self->param('hide'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID company: $comp");
    $self->app->log->debug("Province: $prov - Station: $stid");
    $self->app->log->debug("Ticket chiusi nascosti: $hide");

    my $user_id = $self->session('it.ecometer.bobo');
    my $tickets;

    # get tickets
    $tickets = $self->dbplanperiferia->get_tickets($user_id, $from, $to, $comp, $prov, $stid, $hide);

    my $json;
    if (defined $tickets) {
        $json = {
            res => "OK",
            tickets => $tickets
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

sub get_selected_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub get_selected_ticket");

    my $id = $self->param('id'); # post
    $self->app->log->debug("ID ticket: $id");

    # get tickets
    my $ticket;
    $ticket = $self->dbplanperiferia->get_ticket_by_id($id);

    my $json;
    if (defined $ticket) {
        $json = {
            res => "OK",
            ticket => $ticket
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

sub put_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub put_ticket");

    # dump post data (with user infos)
    $self->helperDumperPostData('Planning', 'put_ticket', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;
    # $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $res = 1;
    my $tkid = $params->{'newtic-id'};

    # if tkid defined -> edit ticket
    if (defined $tkid && $tkid ne "") {
        $self->app->log->debug("Bobo::Controller::Planperiferia edit of ticket");

        $res = $self->dbplanperiferia->update_ticket($params);
    }
    else { # else -> insert new ticket
        $self->app->log->debug("Bobo::Controller::Planperiferia insert of new ticket");

        $tkid = $self->dbplanperiferia->insert_ticket($user_id, $params);
    }

    if (defined $tkid && defined $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_ticket_status {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub put_ticket_status");

    # dump post data (with user infos)
    $self->helperDumperPostData('Planning', 'put_ticket_status', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    # $self->helperDumper($params);

    my $res = -1;
    if ($params->{'changestatus-status'} eq 'taken charge') {
        $res = $self->dbplanperiferia->check_active_tickets($params->{'changestatus-id'});
    }

    if ($res > 0) {
        $self->app->log->debug('Result: NOT OK');
        $self->render(json => -1);
    }
    else {
        my $user_id = $self->session('it.ecometer.bobo');
        $res = $self->dbplanperiferia->insert_ticket_status($user_id, $params);

        if (defined $res) {
            $self->app->log->debug('Result: OK');
            $self->render(json => 1);
        }
        else {
            $self->app->log->debug('Result: ERROR');
            $self->render(json => 0);
        }
    }
}

sub del_selected_ticket {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Planperiferia sub del_selected_ticket");

    # dump post data (with user infos)
    $self->helperDumperPostData('Planning', 'del_selected_ticket', $self->req->body_params);

    my $id = $self->param('id'); # post
    my $flag = $self->param('flag'); # post

    my $res = $self->dbplanperiferia->delete_ticket($id, $flag);

    if (defined $res && $res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

1;

=head1 attivita

Render della pagina di visualizzazione del planning con recupero di tutti i
metadati necessari al popolamento delle select

Argomenti:  /

Return:     /

=cut

=head1 get_equipments

Funzione per recuperare, tramite id stazione e data, le informazioni riguardo agli
strumenti, alle bombole e alle dotazioni di una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * data e ora ('dt');

Return:     json contenente la risposta "OK" e, se presenti, gli strumenti, le bombole e
le dotazioni della stazione. In caso di errore la risposta è "ERR".

=cut

=head1 get_maintenances

Funzione per recuperare tramite id le manutenzioni associabili ad un determinato ticket.

Argomenti:  * id del ticket ('tkid');

Return:     json contenente la risposta "OK" e, se presenti, un array di manutenzioni,
oppure solamente la risposta "ERR".

=cut

=head1 get_tickets

Funzione per recuperare i ticket visibili ad un determinato utente di una determinata
azienda in un determinato periodo temporale.

Argomenti:  * data d'inizio periodo ('from');

           * data di fine periodo ('to');

           * id dell'azienda, se presente ('comp');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e , se presenti, un array di tickets,
oppure solamente la risposta "ERR".

=cut

=head1 get_selected_ticket

Funzione per recuperare tramite id le informazioni di un determinato ticket.

Argomenti:  * id del ticket ('tkid');

Return:     json contenente la risposta "OK" e, se presente, il json del ticket,
oppure solamente la risposta "ERR".

=cut

=head1 put_ticket

Funzione per inserire/modificare un determinato ticket.

Argomenti:  * id dell'utente ('user_id');

           * oggetto (serialize del form lato client) contenente le informazioni del ticket ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_ticket_status

Funzione per inserire lo stato di un determinato ticket.

Argomenti:   * oggetto (serialize del form lato client) contenente le informazioni del ticket ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_ticket

Funzione per eliminare tramite id un determinato ticket.

Argomenti:   * id del ticket ('id');

             * flag true/false ('flag') che, in caso di ticket programmati, stabilisce se l'utente vuole eliminare

             anche i ticket successivi (true) o meno (false);

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut