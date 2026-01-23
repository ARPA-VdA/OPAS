package Bobo::Controller::Indicatori;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use File::Find::Rule;
use Mojo::File 'path';

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;

use DateTime;

use Data::Dumper;

sub indicatori {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces( $user_id );
    $self->stash(provinces => $provinces);

    $self->helperGetPortalPageOptions();

    # Render template "statistiche/indicatori.html.ep" with message
    $self->render('statistiche/indicatori');
}

sub get_runs {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub get_runs");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $prov = $self->param('prov'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $runs = $self->dbindicatori->get_runs($user_id, $from, $to, $prov );

    my $json;
    if (defined $runs) {
        $json = {
            res => "OK",
            runs => $runs
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

sub get_table_by_date {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub get_table_by_date");

    my $dt = $self->param('dt'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $header = $self->dbindicatori->get_header_by_date($user_id, $dt, $net, $prov);
    my $data = $self->dbindicatori->get_data_by_date($user_id, $dt, $net, $prov);

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
}

sub get_table_by_station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub get_table_by_station");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $stid = $self->param('stid'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $header = $self->dbindicatori->get_header_by_station($from, $to, $stid);
    my $data = $self->dbindicatori->get_data_by_station($from, $to, $stid);

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
}

sub calc_stats {
    my ($cmd, $jobid) = @_;

    say 'calc_stats';
    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script calcolo statistiche";

            # run script via ssh
            say "[SSH] Lancio script creazione pdf via ssh";

            # percorso script
            my $format_cmd = $cmd.' '.$jobid;

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

sub put_stats_calculation {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub put_stats_calculation");

    my $type = $self->param('type'); # post
    my $from = $self->param('from'); # post
    my $to   = $self->param('to'); # post
    my $prov = $self->param('prov'); # post
    my $json;

    $self->app->log->debug("Type: ". $type);
    $self->app->log->debug("From: ". $from);
    if($type eq 'range'){
        $self->app->log->debug("To: ". $to);
    }
    $self->app->log->debug("Prov: ". $prov);

    my @dates;
    if($type eq 'daily'){
        @dates = ($from);
    }
    else{
        my $dt_from = DateTime->new(
            year   => substr($from, 0, 4),
            month  => substr($from, 5, 2),
            day    => substr($from, 8, 2)
        );

        my $dt_to = DateTime->new(
            year   => substr($to, 0, 4),
            month  => substr($to, 5, 2),
            day    => substr($to, 8, 2)
        );

        while ($dt_from <= $dt_to) {
            push @dates, $dt_from->strftime('%Y-%m-%d');
            $dt_from->add(days => 1);
        }
    }

    my @promises; 

    for my $dt (@dates) {

        my $obj = {
            dt => $dt,
            prov => $prov
        };

        if ($self->dbutilities->get_pending_jobs_by_params(1, $obj) >= 1) {
            $self->app->log->debug("Process already running");
        }
        else {
            my $cmd = $self->dbutilities->get_job_command(1);
            my $jobid = $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), 1, $obj);
            $self->dbindicatori->insert_run($self->session('it.ecometer.bobo'), $dt, $prov);
            my $promise = calc_stats($cmd, $jobid);

            $promise->then(sub {
                my @results = @_;
                $self->app->log->debug('Into single resolved promise! Date: '. $dt);

            })->catch(sub {
                my $err = @_;
                $self->app->log->debug('Into single rejected promise!');
            });

            push @promises, $promise;
        }
    }

    $self->app->log->debug("Waiting for promises end...");

    # Continua l'esecuzione in background SENZA aspettare
    unless (@promises) {
        $self->app->log->debug("Nessuna operazione avviata");
        return;
    }

    # Esegui le promise in background (non aspettare)
    Mojo::Promise->all(@promises)->then(sub {
        $self->app->log->debug("Tutte le promise risolte in background");
    })->catch(sub {
        $self->app->log->warning("Alcune promise hanno fallito in background");
    });

    $self->render(json => 1);
};

sub put_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub put_pdf");

    my $dt = $self->param('dt'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $json;

    $self->app->log->debug("PDF della rete: $net");

    # system
    eval{
        $self->app->log->debug("Lancio script creazione pdf");

        # percorso script
        my $cmd = 'ls';

        $self->app->log->debug("Running system: $cmd");
        # execute
        system($cmd);
        $self->app->log->debug("Fine script creazione pdf");
    };

    if ($@) {
        $self->app->log->warning("command failed: $@");

        $json = {
            res => 'ERR',
            desc => 'Errore durante la creazione del pdf'
        };
    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        my $province = $self->dbcommon->get_province_by_id($prov);

        # get application download path .../public/ path
        $dt =~ /(\d\d\d\d)-(\d\d)/;
        my $download_path = $self->app->static->paths->[0].'/downloads/statistiche/indicatori'."/$1/$2";
        $self->app->log->debug("Download path: $download_path");

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "report_giornaliero_".$province->{'province_code'}."-".$dt.".pdf";

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;
        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        $self->app->log->debug("Checking file $full_pdf_filename exists...");
        if (-e $full_pdf_filename) {
            $self->app->log->debug("Pdf file FOUND!");

            $self->dbindicatori->update_run($user_id, $dt, $prov);

            # Provide any file name
            $json = {
                res => 'OK'
            };
        }
        else {
            $self->app->log->debug("Pdf file NOT found!");
            # redirect to report list
            $json = {
                res => 'ERR',
                desc => 'Errore, file pdf non trovato!'
            };
        }
    }

    # final render
    $self->render(json => $json);
}

1;

=head1 indicatori

Render della pagina di visualizzazione degli indicatori giornalieri.

Argomenti:  /

Return:     /

=cut

=head1 get_runs

Funzione per recuperare le esecuzioni disponibili degli indicatori per un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

            * data fine ('to');

            * id della provincia, se presente ('prov');

Return:     json contenente la risposta "OK" e le esecuzioni disponibili, oppure il messaggio "ERR".

=cut

=head1 get_table_by_date

Funzione per recuperare la relativa tabella degli indicatori per una data specifica.

Argomenti:  * data e ora ('dt');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli indicatori, oppure il messaggio "ERR".

=cut

=head1 get_table_by_station

Funzione per recuperare, data una stazione, la relativa tabella degli indicatori.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli indicatori, oppure il messaggio "ERR".

=cut

=head1 calc_stats

Funzione che effettua il lancio dello script per effettuare il calcolo delle statistiche.

Argomenti:  * id della richiesta nella coda di job ('job_id');

Return:     oggetto Promise che determina la riuscita dell'operazione.

=cut

=head1 put_stats_calculation

Funzione asincrona per accodare varie richieste di calcolo delle statistiche.

Argomenti:  * data e ora ('dt');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

Return:     json contenente 1 o -1:

            - 1: OK, script lanciato;

            - -1: processo già in esecuzione con i parametri selezionati;

=cut

=head1 put_pdf

Funzione di creazione del pdf riassuntivo del calcolo delle statistiche.

Argomenti:  * data e ora ('dt');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

Return:     json contenente la risposta "OK" se trovato il file pdf, oppure la risposta "ERR" se
non e' stato trovato.

=cut