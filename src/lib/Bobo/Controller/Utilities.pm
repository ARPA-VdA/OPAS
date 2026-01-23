package Bobo::Controller::Utilities;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

# !! CALENDARIO
sub calendario {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities calendario");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # Render template "planning/calendario.html.ep" with message
    $self->render('utilities/calendario');
}

sub get_calendar_events {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_calendar_events");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post

    $self->app->log->debug("From: $from - To: $to");

    my $user_id = $self->session('it.ecometer.bobo');

    # get tickets
    my $tickets = $self->dbplanperiferia->get_calendar_tickets($user_id, $from, $to);
    my $auto_calibs = $self->dbtaratureaut->get_all_events_by_dates($user_id, $from, $to);
    my $rep_calibs = $self->dbqatarature->get_reports_events_by_dates($user_id, $from, $to);
    my $rep_mains = $self->dbqamanutenzioni->get_reports_events_by_dates($user_id, $from, $to);
    my $rep_insp = $self->dbqasopralluoghi->get_reports_events_by_dates($user_id, $from, $to);

    my $json;
    if (defined $tickets) {
        $json = {
            res             => "OK",
            tickets         => $tickets,
            auto_calibs     => $auto_calibs,
            rep_calibs      => $rep_calibs,
            rep_mains       => $rep_mains,
            rep_inspections => $rep_insp
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # return
    $self->render(json => $json);
}

# !! WARNING STRUMENTI
sub warning {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities warnings");

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # get page options
    $self->helperGetPortalPageOptions();

    # Render template "dati/warning.html.ep" with message
    $self->render('dati/warning');
}

sub get_instruments_messages {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_instruments_messages");

    my $user_id = $self->session('it.ecometer.bobo');

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    $self->app->log->debug("Data inizio: $from");
    $self->app->log->debug("Data fine: $to");

    my $prov = $self->param('prov'); # post
    my $stat = $self->param('stat'); # post
    my $type = $self->param('type'); # post

    # get warnings by dates sent by an ajax call
    my $warnings;
    if ($type == 1) { # SWAM
        $warnings = $self->dbhome->get_swam_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 2) { # TECORA
        $warnings = $self->dbhome->get_tecora_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 3) { # DERENDA
        $warnings = $self->dbhome->get_derenda_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 4) { # ENVEA
        $warnings = $self->dbhome->get_envea_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 5) { # METONE
        $warnings = $self->dbhome->get_metone_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 6) { # FIDAS
        $warnings = $self->dbhome->get_fidas_messages_bydate($user_id, $from, $to, $prov, $stat);
    }
    elsif ($type == 7) { # Teledyne
        $warnings = $self->dbhome->get_teledyne_messages_bydate( $user_id, $from, $to, $prov, $stat);
    }
    else {
        # nothing to do
    }

    my $json = {
        res => "OK",
        warnings => $warnings
    };

    # return
    $self->render(json => $json);
}

# !! DATI ISTANTANEI
sub istantanei {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    # my $provinces = $self->dbcommon->get_provinces( $user_id );
    # $self->stash(provinces => $provinces);

    # Render template "dati/istantanei.html.ep" with message
    $self->render('dati/istantanei');
}

sub get_inst_data_table {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Mapper sub get_inst_data_table");

    my $station_id = $self->param('stid'); # post

    my $data = $self->dbdatamanager->get_inst_data_table($station_id);

    # check result
    my $json;
    if ($data && $data != -1) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            data => $data
        };
    }
    elsif ($data && $data == -1) {
        $json = {
            res => 'NOT'
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'ERR'
        };
    }

    # return
    $self->render(json => $json);
}

# !! ALLARMI
sub allarmi {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # Render template "dati/allarmi.html.ep" with message
    $self->render('dati/allarmi');
}

sub get_alarms_bydate {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_alarms_bydate");

    my $user_id = $self->session('it.ecometer.bobo');

    my $dateFrom = $self->param('dateFrom'); # post
    my $dateTo = $self->param('dateTo'); # post
    $self->app->log->debug("Data inizio: $dateFrom");
    $self->app->log->debug("Data fine: $dateTo");

    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $stat = $self->param('stat'); # post
    my $flag = $self->param('flag'); # post

    # get alarms by dates sent by an ajax call
    my $alarms = $self->dbhome->get_alarms_bydate($user_id, $dateFrom, $dateTo, $net, $prov, $stat, $flag);

    my $json = {
        res => "OK",
        alarms => $alarms
    };

    # render
    $self->render(json => $json);
}

# !! FILE PATH
sub filepath {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # Render template "dati/filepath.html.ep" with message
    $self->render('dati/filepath');
}

sub get_files {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_files");

    my $user_id = $self->session('it.ecometer.bobo');
    my $net = $self->param('net'); # post

    my $files = $self->dbutilities->get_files($user_id, $net);

    my $json = {
        res => "OK",
        files => $files
    };

    # render
    $self->render(json => $json);
}

# !! REPORT AUTOMATICI
sub automatici {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # Render template "dati/allarmi.html.ep" with message
    $self->render('report/automatici');
}

sub get_ws_status_bydate {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_ws_status_bydate");

    my $user_id = $self->session('it.ecometer.bobo');

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post

    $self->app->log->debug("Data inizio: $from");

    # get reports by dates sent by an ajax call
    my $status;
    if ($type eq 'siral') {
        $status = $self->dbutilities->get_siral_status_bydate($from);
    }
    elsif ($type eq 'aer') {
        $self->app->log->debug("Data fine: $to");
        $status = $self->dbutilities->get_aernostrum_status_bydate($from, $to);
    }

    my $json = {
        res => "OK",
        status => $status
    };

    # return
    $self->render(json => $json);
}

# !! MAPPA DEL PORTALE
sub map {
    my $self = shift;
    $self->app->log->debug("Bobo::Controller::Utilities sub map");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # Render template "utilities/faq.html.ep" with message
    $self->render("utilities/map");
}

# !! HELP
# redirect to login page
sub help {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub help");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $html_url;
    my $page = $self->stash->{'page'} ? $self->stash->{'page'} : 'homepage';

    # if logout return to main homepage
    if ($page eq 'logout') {
        $self->redirect_to('/') and return 0;
    }
    else {
        # set help page path
        my $path = $self->app->home->rel_file('public/bobo-help/'.$page);
        $self->app->log->debug($path);
        # if the help page directory exists, set html url to the page
        if (-d $path){
            $html_url = $page.'/'.$page;
            $self->app->log->debug("$html_url");
        }
        # if the help page directory does not exist, set html url to the "in progress" page
        else {
            $html_url = 'in_progress';
            $self->app->log->debug("$html_url");
        }

        $self->stash(html_url => $html_url);

        # -------------------------------------------------------
        # render login form
        # -------------------------------------------------------
        $self->render(template => 'utilities/help');
    }
}

# !! NOTIFIER
sub get_notifications {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub get_notifications");

    my $user_id = $self->session('it.ecometer.bobo');
    my $pending = $self->dbutilities->get_pending_jobs($user_id);
    my $notifications = $self->dbutilities->get_finished_jobs($user_id);

    my $json = {
        res => "OK",
        pending => $pending,
        notifications => $notifications
    };

    # render
    $self->render(json => $json);
}

sub put_notification_ack {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities sub put_notification_ack");

    my $id = $self->param('id'); # post
    $self->dbutilities->update_job_ack($id);

    # render
    $self->render(json => 1);
}

# !! DOCS
sub docs{
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Utilities docs");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # Render template "planning/calendario.html.ep" with message
    $self->render('utilities/docs');
}


1;

=head1 calendario

Render della pagina di visualizzazione del calendario.

Argomenti:  /

Return:     /

=cut

=head1 get_calendar_events

Funzione che recupera le informazioni relative ali eventi presenti a calendario.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id dell'utente ('user_id');

Return:     json contenente il messaggio "OK", e gli eventi disponibili, oppure il messaggio "ERR".

=cut

=head1 warning

Render della pagina di visualizzazione dei warning degli strumenti.

Argomenti:  /

Return:     /

=cut

=head1 get_instruments_messages

Funzione che recupera i messaggi di warning, suddivisi per categoria, per un determinato periodo temporale e,
se presenti gli id, per una determinata provincia/stazione.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stat');

           * id della categoria/tipologia di strumento ('type');

Return:     json contenente il messaggio "OK", e i messaggi disponibili.

=cut

=head1 istantanei

Render della pagina di visualizzazione dei dati istantanei delle stazioni.

Argomenti:  /

Return:     /

=cut

=head1 get_inst_data_table

Funzione che recupera, se presenti, i dati istantanei disponibili per una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente:

           - se tutto è andato a buon fine, il messaggio "OK" e i dati disponibili.

           - se non sono presenti dati, il messaggio "NOT"

           - il messaggio "ERR", in caso di errore durante il recupero dei dati

=cut

=head1 allarmi

Render della pagina di visualizzazione degli allarmi.

Argomenti:  /

Return:     /

=cut

=head1 get_alarms_bydate

Funzione per recuperare gli allarmi scattati in un determinato periodo temporale
con la possibilita' di filtrare i dati estratti per rete, provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('dateFrom');

           * data di fine ('dateTo');

           * eventuale id della rete ('net');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

           * valore booleano che indica se nascondere o meno gli allarmi di tipo 'Porta aperta' ('flag');

Return:     Risultato della query;

=cut

=head1 filepath

Render della pagina di visualizzazione relativa ai percorsi dei file (file path).

Argomenti:  /

Return:     /

=cut

=head1 get_files

Funzione che recupera la lista dei file disponibile per una specifica rete per l'utente corrente.

Argomenti:  * id dell'utente ('user_id');

           * id della rete ('net');

Return:     json contenente il messaggio "OK" e la lista dei file:
            { res => "OK", files => [ ... ] }

=cut


=head1 automatici

Render della pagina di visualizzazione dei report di analisi inviati automaticamente.

Argomenti:  /

Return:     /

=cut

=head1 get_ws_status_bydate

Funzione per recuperare i report di analisi dei dati inviati automaticamente dal sistema in un determinato
periodo temporale.

Argomenti:  * id dell'utente ('user_id');

           * tipologia del report ('type');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente il messaggio "OK" e i report disponibili.

=cut

=head1 map

Render della pagina di visualizzazione della mappa del portale.

Argomenti:  /

Return:     /

=cut

=head1 help

Render della pagina di documentazione relativa alla pagina corrente.

Argomenti:  * pagina corrente ('page') da STASH;

Return:     /

=cut

=head1 get_notifications

Funzione che recupera le richieste nella coda di job visibili all'utente, sia quelle completate sia quelle ancora in pending.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente il messaggio "OK" e le richieste ancora in pending e quelle completate.

=cut

=head1 put_notification_ack

Funzione che effettua l'update di una determinata richiesta nella coda di job inserendone l'acknowledge.

Argomenti:  * id della richiesta ('id');

Return:     json contenente il valore 1.

=cut
