package Bobo::Controller::Statistiche;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Net::FTP;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

use Mojo::File 'path';
use Time::Moment;

# redirect to page
sub info {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # render page
    $self->render(template => 'statistiche/info');
}

# redirect to page
sub ana_validazione {
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

    # render page
    $self->render(template => 'statistiche/validazione');
}

sub get_user_validation_analysis {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Statistiche sub get_user_validation_analysis");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $json;
    my $data = $self->dbstatistiche->get_user_validation_analysis($user_id, $from, $to, $stid);

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

    # render page
    $self->render(json => $json);
}

sub get_csv_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Statistiche sub get_csv_data");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    # get application path .../public/ path
    my $app_path = $self->app->home->rel_file('public/downloads/statistiche/validazione');
    $self->app->log->debug("Application path: $app_path");

    # get times
    $self->app->log->debug("Formattazione date");
    my $tm = Time::Moment->now;
    my $head_time = $tm->strftime("{%Y%m%d_%H%M%S}");

    my $dateFromISO = $from;
    $dateFromISO .= 'T00:00:00Z';
    $self->app->log->debug("From: $dateFromISO");
    $tm = Time::Moment->from_string($dateFromISO);
    $head_time .= '-' . $tm->strftime("[%Y%m%d");

    my $dateToISO = $to;
    $dateToISO =~ s/ /T/;
    $dateToISO .= 'Z';
    $tm = Time::Moment->from_string($dateToISO);
    $head_time .= '-' . $tm->strftime("%Y%m%d]");

    # build filename
    # my $csv_filename = '/Dati_'.$stid.'-'.$prid.'.csv';
    my $csv_filename = '/Analisi_validazione_'.$head_time.'.csv';
    $csv_filename = encode_utf8( $csv_filename );
    my $full_csv_filename = $app_path.'/'.$csv_filename;
    $self->app->log->debug("File csv : $full_csv_filename");

    # write header
    my $eco_file_header;
    $eco_file_header .= "Parametri;";
    $eco_file_header .= "Dati attesi;";
    $eco_file_header .= "Dati mancanti;";
    $eco_file_header .= "[-1024] - Non valido per cause esterne;";
    $eco_file_header .= "[-512] - OPAS-DL - Valore inferiore al min impostato;";
    $eco_file_header .= "[-256] - Non valido ticket;";
    $eco_file_header .= "[-128] - Non valido operatore/non valido generico;";
    $eco_file_header .= "[-64] - Non valido manutentore;";
    $eco_file_header .= "[-32] - OPAS-DL - Errore strumentale;";
    $eco_file_header .= "[-16] - OPAS-DL - Zero/Span High/Low;";
    $eco_file_header .= "[-8] - OPAS-DL - Minore -DL;";
    $eco_file_header .= "[-4] - OPAS-DL - Numero letture insufficiente;";
    $eco_file_header .= "[-2] - Non valido per validazione automatica;";
    $eco_file_header .= "[-1] - Sospetto per validazione automatica;";
    $eco_file_header .= "TOTALE INVALIDI;";
    $eco_file_header .= "[0] - Valido;";
    $eco_file_header .= "[1] - Ricostruito;";
    $eco_file_header .= "[2] - OPAS-DL - Taratura;";
    $eco_file_header .= "[4] - OPAS-DL - Compreso tra -DL e DL, sostituito con DL/2;";
    $eco_file_header .= "[8] - Dato invalido per sistema e valido da operatore;";
    $eco_file_header .= "[16] - Dato invalidato precedentemente, rivalidato;";
    $eco_file_header .= "[32] - Dato importato da campo;";
    $eco_file_header .= "TOTALE VALIDI";

    my $data_rows = $self->dbstatistiche->get_user_validation_analysis($user_id, $from, $to, $stid);

    my $csv_rows = '';
    foreach my $row (@{$data_rows}) {
        if (defined $row->{'stats_obj'}) {
            my $csv_row = '';
            $csv_row .= $row->{'param_name'} .';';

            my $row_obj = decode_json(encode_utf8($row->{'stats_obj'}));

            $csv_row .= $row_obj->{'expected_data'} .';';
            $csv_row .= $row_obj->{'count_missing'} .';';
            $csv_row .= join(";", @{$row_obj->{'count_notvalid_codes'}} ) .';';
            $csv_row .= $row_obj->{'count_not_valid'} .';';
            $csv_row .= join(";", @{$row_obj->{'count_valid_codes'}} ) .';';
            $csv_row .= $row_obj->{'count_valid'};
            $csv_rows .= $csv_row ."\n";
        }

    } # foreach my $row (@{$data_rows})

    # open single data file
    $self->app->log->debug("Open CSV data file");
    open(FH, '>', $full_csv_filename) or die $!;
    # print header & pubs
    print FH $eco_file_header ."\n";

    # print rows with values
    $self->app->log->debug("Print rows with values...");
    print FH $csv_rows ."\n";

    # close data file
    $self->app->log->debug("Close CSV data file");
    close(FH);

    # last check
    $self->app->log->debug("Check zip file exists");
    if (-e $full_csv_filename) {
        # Open file in browser(do not show save dialog)
        $self->app->log->debug("Render file back to browser");

        $self->render_file(
            'filepath' => $full_csv_filename,
            'format' => 'csv', # will change Content-Type "application/x-download" to "application/pdf"
            'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
            'cleanup' => 0, # delete file after completed
        );

    }
    else {
        $self->app->log->error("Error. Zip file DOES NOT exists!");

        my $json = {
            res => 'ERROR',
            desc => "Errore durante lo scarico dei dati."
        };

        # final render
        $self->render(json => $json);
    }
};

sub create_csv_file {
    my ($cmd, $jobid) = @_;

    # log
    say 'create_csv_file';

    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script creazione CSV";
             # run script via ssh
            say "[SSH] Lancio script creazione CSV via ssh";

            # percorso script
            my $format_cmd = $cmd.' '.$jobid;
            # execute
            say "Running system: $format_cmd";

            # sleep(30); # sleep for 120 seconds
            return system($format_cmd);
        },
        sub { # second callback resolves promise with subprocess result
            my ($self, $err, $result) = @_;
            say "Fine creazione CSV";
            say $result;
            return $promise->reject($err) if $err;
            $promise->resolve($result);
        }
    );

    # return
    return $promise;
};

async get_network_csv_data => sub {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Statistiche sub get_network_csv_data");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $net = $self->param('net'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Network: $net");

    $self->app->log->debug("Inizio recupero dati");

    my $obj = {
        start_d => $from,
        end_d => $to,
        net => $net
    };

    # if (1) {
    if ($self->dbutilities->get_pending_jobs_by_params(9, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        my $cmd = $self->dbutilities->get_job_command(9);
        my $jobid = $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), 9, $obj);
        my $promise = create_csv_file($cmd, $jobid);

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

sub get_downloads {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Statistiche sub get_downloads");

    my $user_id = $self->session('it.ecometer.bobo');
    my $download = $self->dbstatistiche->get_last_download($user_id);

    my $json = {
        res => "OK",
        download => $download
    };

    # render
    $self->render(json => $json);
}

# !! COPERTURA
sub copertura {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Copertura");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # Render template "statistiche/copertura.html.ep" with message
    $self->render('statistiche/copertura');
}

sub get_data_coverage {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Copertura sub get_data_coverage");

    my $user_id = $self->session('it.ecometer.bobo');

    my $year = $self->param('year'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("Stazione: $stid");

    # get stations from province
    my $params = $self->dbstatistiche->get_active_parameters_by_stid($stid);

    my $data = [];
    my $valid = [];
    my $charts;

    if (scalar @{$params} > 0) {
        $data = $self->dbstatistiche->get_data_coverage_by_stid($year, $stid, $params);
        $valid = $self->dbstatistiche->get_valid_data_coverage_by_stid($year, $stid, $params);
        $charts = $self->dbstatistiche->get_chart_data_coverage_by_stid($year, $stid);
    }

    my $json = {
        res => "OK",
        params => $params,
        data => $data,
        valid => $valid,
        charts => $charts
    };

    # render
    $self->render(json => $json);
}

# redirect to page
sub annuali{
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

    # render page
    $self->render(template => 'statistiche/annuali');
}

1;

=head1 info

Render della pagina di visualizzazione dell'informativa relativa ai limiti di riferimento.

Argomenti:  /

Return:     /

=cut

=head1 ana_validazione

Render della pagina di analisi delle validazioni effettuate dagli utenti.

Argomenti:  /

Return:     /

=cut

=head1 get_user_validation_analysis

Funzione per recuperare le statistiche relative ai codici di validazione/invalidazione
per stazione in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id dell'utente ('user_id');

Return:     json contenente il messaggio "OK" e le statistiche, oppure il messaggio ERR".

=cut

=head1 get_csv_data

Funzione per effettuare il download, in formato .csv, delle statistiche relative ai codici
di validazione/invalidazione per stazione in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id dell'utente ('user_id');

Return:     download del file generato.

=cut

=head1 create_csv_file

Funzione per generare il file csv menzionato nella funzione precedente.

Argomenti:  * comando bash per l'esecuzione dello script ('cmd');

           * id del job ('jobid');

Return:     Risultato del comando lanciato.

=cut

=head1 get_network_csv_data

Funzione per generare il file, in formato .csv, delle statistiche relative ai codici
di validazione/invalidazione per rete in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('net');

           * id dell'utente ('user_id');

Return:     json contenente 1 o -1:

            - 1: OK;

            - -1: ERROR;

=cut

=head1 get_downloads

Funzione per recuperare l'elenco dei files csv generati.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente il messaggio "OK" e i files.

=cut

=head1 copertura

Render della pagina di analisi copertura.

Argomenti:  /

Return:     /

=cut

=head1 get_data_coverage

Funzione per recuperare le informazioni necessarie all'analisi della copertura
e della validita' dei dati per ogni stazione in un determinato periodo.

Argomenti:  * id dell'utente ('user_id');

           * anno ('year');

           * id della stazione ('stid');

Return:     json contenente il messaggio "OK" e le varie informazioni recuperate.

=cut