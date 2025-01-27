package Bobo::Controller::Reportistica;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Net::FTP;
use Mojo::JSON qw(decode_json encode_json);

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;
#use Mojo::File qw(path);

# redirect to page
sub reportistica {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get zones
    my $zones = $self->dbreportistica->get_zones($user_id);
    $self->stash(zones => $zones);

    my $users = $self->dbcommon->get_portal_users_by_user($user_id);
    $self->stash(users => $users);

    # render
    $self->render(template => 'statistiche/reportistica');
};

sub get_stations_by_zone {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_stations_by_zone");

    my $zone = $self->param('zone'); # post

    my $stations = $self->dbreportistica->get_stations_by_zone($zone);

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

    # render
    $self->render(json => $json);
}

sub get_params_by_zone {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_params_by_zone");

    my $zone = $self->param('zone'); # post

    my $params = $self->dbreportistica->get_parameters_by_zone($zone);

    my $json;
    if (defined $params) {
        $json = {
            res => "OK",
            params => $params
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

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_reports");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $type = $self->param('type'); # post
    my $zone = $self->param('zone'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Tipo: $type");
    $self->app->log->debug("Zona: $zone");

    my $user_id = $self->session('it.ecometer.bobo');

    # get data from dateFrom to dateTo
    my $json;
    my $reports = $self->dbreportistica->get_reports($user_id, $from, $to, $type, $zone);

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
};

sub get_stats_by_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_stats_by_station");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $header = $self->dbreportistica->get_header_by_station($from, $to, $stid);
    my $data = $self->dbreportistica->get_data_by_station($from, $to, $stid);

    my $json;
    if (defined $header) {
        $json = {
            res => "OK",
            header => $header,
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
};

sub get_stats_by_type {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_stats_by_type");

    my $type = $self->param('type'); # post

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    my $header = $self->dbreportistica->get_header_by_type($type, $user_id);
    my $data = $self->dbreportistica->get_data_by_type($type, $params, $user_id);

    my $json;
    if (defined $header) {
        $json = {
            res => "OK",
            header => $header,
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
};

sub get_check_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub get_check_data");

    my $zone = $self->param('zone'); # post

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Zona: $zone");

    my $user_id = $self->session('it.ecometer.bobo');

    my $json = $self->dbreportistica->check_data($user_id, $zone, $from, $to);

    # render
    $self->app->log->debug("Render back");
    $self->render(json => $json);
};

sub calc_stats_by_type {
    my ($cmd, $jobid) = @_;

    # log
    say 'calc_stats_by_type';

    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script calcolo statistiche";

            # run script via ssh
            say "[SSH] Lancio script creazione pdf via ssh";

            # percorso script
            my $format_cmd = $cmd.' '.$jobid;
            # run local script
            # my $cmd = '/usr/bin/Rscript /data/bin/arpa_lig/stats/stats.R \''.$dt.'\' '.$prov;

            # execute
            say "Running system: $format_cmd";
            return system($format_cmd);
        },
        sub { # second callback resolves promise with subprocess result
            my ($self, $err, $result) = @_;
            say "Fine script calcolo statistiche";
            say $result;
            return $promise->reject($err) if $err;
            $promise->resolve($result);
        }
    );

    # return
    return $promise;
};

async put_stats_calculation => sub {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub put_stats_calculation");

    $self->helperDumperPostData('Reportistica', 'put_stats_calculation', $self->req->body_params);

    my $user_id = $self->session('it.ecometer.bobo');

    my $type = $self->param('stats-type'); # post
    my $zone = $self->param('stats-zone'); # post
    my $signature = $self->param('stats-signature'); # post
    my $note = $self->param('stats-note'); # post

    my $job;
    my $dt;
    if ($type == 1) {
        $job = 6;
        $dt = $self->param('stats-day');
    }
    elsif ($type == 2) {
        $job = 7;
        $dt = '01/'.$self->param('stats-month');
    }
    elsif ($type == 3) {
        $job = 8;
        $dt = '01/01/'.$self->param('stats-year');
    }

    my $json;

    $self->app->log->debug("Type: ". $type);
    $self->app->log->debug("Date: ". $dt);

    my $obj = {
        type => $type,
        dt => $self->helperGetFormattedFulldate($dt),
        zone => $zone,
        usid => $user_id
        # sign => $signature, # NOT USED
        # note => $note       # NOT USED
    };

    if ($self->dbutilities->get_pending_jobs_by_params($job, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        my $cmd = $self->dbutilities->get_job_command($job);
        my $jobid = $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), $job, $obj);

        $self->app->log->debug($cmd.' '.$jobid);
        my $promise = calc_stats_by_type($cmd, $jobid);

        # my $guid = $self->session('guid');
        # my $ws = $self->stash->{websockets}{$guid};

        $promise->then(sub {
            my @results = @_;
            $self->app->log->debug('Into resolved promise!');
        })->catch(sub {
            my $err = @_;
            $self->app->log->debug('Into rejected promise!');
        });

        $self->app->log->debug("Render back");
        $self->render(json => 1);
    }
};

sub put_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub put_pdf");

    my $user_id = $self->session('it.ecometer.bobo');

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $type = $params->{'stats-type'}; # post

    my $dt;
    my $prefix_filename;
    my $script;
    if ($type == 1) {
        $dt = $params->{'stats-day'};
        $prefix_filename = 'report_giornaliero_';
        $script = 'statistiche_giornaliere/report-statistiche-giornaliere.pl';
    }
    elsif ($type == 2) {
        $dt = '01/'.$params->{'stats-month'};
        $prefix_filename = 'report_mensile_';
        $script = 'statistiche_mensili/report-statistiche-mensili.pl';
    }
    elsif ($type == 3) {
        $dt = '01/01/'.$params->{'stats-year'};
        $prefix_filename = 'report_annuale_';
        $script = 'statistiche_annuali/report-statistiche-annuali.pl';
    }

    my $json;

    # store request to audit table
    my $table = 'stat_reportistica';

    # system
    eval {
        $self->app->log->debug("Bobo::Controller::Reportistica insert of new pdf");
        # $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        my $rpid = $self->dbreportistica->insert_report($user_id, $dt, $params);

        $self->app->log->debug("Lancio script creazione pdf");

        # percorso script
        my $cmd = 'ls';

        $self->app->log->debug("Running system: $cmd");

        # execute
        system($cmd);
        $self->app->log->debug("Fine script creazione pdf");
    };

    if ($@) {
        $self->app->log->debug("command failed: $@");

        $json = {
            res => 'ERR',
            desc => 'Errore durante la creazione del pdf'
        };

    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');

        $json = {
            res => 'OK'
        };
    }

    # final render
    $self->render(json => $json);
}

sub del_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Reportistica sub del_report");
    $self->helperDumperPostData('Reportistica', 'del_report', $self->req->body_params);

    my $rpid = $self->param('id'); # post

    $self->app->log->debug("Report id: $rpid");

    my $res = $self->dbreportistica->delete_report_by_id($rpid);

    if ($res == 1) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 reportistica

Render della pagina di visualizzazione della pagina di reportistica.

Argomenti:  /

Return:     /

=cut

=head1 get_stations_by_zone

Funzione per recuperare le informazioni relative alle stazioni associate ad una determinata zona.

Argomenti:  * id della zona ('zone');

Return:     json contenente la risposta "OK" e le stazioni, oppure la risposta "ERR".

=cut

=head1 get_params_by_zone

Funzione per recuperare le informazioni relative ai parametri associati ad una determinata zona.

Argomenti:  * id della zona ('zone');

Return:     json contenente la risposta "OK" e le stazioni, oppure la risposta "ERR".

=cut

=head1 get_reports

Funzione per recuperare i report di una determinata tipologia disponibili per una determinata zona
in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * tipologia di report ('type');

           * id della zona ('zone');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i report, oppure solamente la risposta "ERR".

=cut

=head1 get_stats_by_station

Funzione per recuperare le statistiche disponibili per una determinata stazione
in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le statistiche, oppure solamente la risposta "ERR".

=cut

=head1 get_stats_by_type

Funzione per recuperare le statistiche disponibili di una determinata tipologia, per un determinato parametro
in un determinato periodo temporale.

Argomenti:  * tipologia di report ('type');

           * oggetto contenente le informazioni relative alla zona e ai parametri richiesti ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le statistiche, oppure solamente la risposta "ERR".

=cut

=head1 get_check_data

Funzione per la verifica dei dati disponibili per una determinata zona
in un determinato periodo temporale al fine del calcolo delle statistiche.

Argomenti:  * id della zona ('zone');

           * data d'inizio ('from');

           * data di fine ('to');

           * id dell'utente ('user_id');

Return:     json contenente l'esito della verifica dei dati.

=cut

=head1 calc_stats_by_type

Funzione per il calcolo delle statistiche di una determinata tipologia richiesta; le info necessarie sono contenute
all'interno del job di sistema.

Argomenti:  * comando bash per lo script di calcolo delle statistiche ('cmd');

           * id del job richiesto ('jobid');

Return:     json contenente l'esito del calcolo delle statistiche.

=cut

=head1 put_stats_calculation

Funzione per l'inserimento all'interno del database del job relativo al calcolo delle statistiche.

Argomenti:  * id dell'utente ('user_id');

           * tipologia di report ('type');

           * id della zona ('zone');

           * id dell'utente firmatario del report ('signature');

           * eventuali note ('note');

Return:     json contenente l'esito del calcolo delle statistiche.

=cut

=head1 put_pdf

Funzione di creazione del pdf riassuntivo del calcolo delle statistiche.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative al report statistiche richiesto dall'utente loggato ('params');

Return:     json contenente la risposta "OK" se trovato il file pdf, oppure la risposta "ERR" se
non e' stato trovato.

=cut

=head1 del_report

Funzione per eliminare, dato l'id, un determinato report.

Argomenti:  * id del report ('rpid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut