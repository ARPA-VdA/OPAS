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

    # Render template "statistiche/indicatori.html.ep" with message
    $self->render('statistiche/indicatori');
}

sub get_pdf_files {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Indicatori sub get_pdf_files");

    # ricerca tutti .pdf file nella directory
    my $path = $self->app->home->rel_file("public/downloads/statistiche/indicatori"); # /var/www/bobo/public/downloads/statistiche/indicatori
    $self->app->log->debug("Application path: $path");

    my @files = File::Find::Rule->file->name('*.pdf')->in($path);
    # $self->helperDumper(@files);

    my $json;

    if (@files) {
        # result
        my @filestats;

        foreach my $file (@files) {
            my $mtime = (stat($file))[9];
            my $obj = {
                name => $file,
                mtime => $mtime
            };

            push @filestats, $obj;
        }

        $json = {
            res => 'OK',
            files => [@filestats]
        };
    }
    else {
        $json = {
            res => 'OK',
            files => []
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
    $self->app->log->debug("Bobo::Controller::Indicatori sub put_stats_calculation");

    my $dt = $self->param('dt'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $json;

    $self->app->log->debug("Date: ". $dt);
    $self->app->log->debug("Prov: ". $prov);

    my $obj = {
        dt => $dt,
        prov => $prov
    };

    if ($self->dbutilities->get_pending_jobs_by_params(1, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        my $cmd = $self->dbutilities->get_job_command(1);
        my $jobid = $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), 1, $obj);
        my $promise = calc_stats($cmd, $jobid);

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
    $self->app->log->debug("Bobo::Controller::Indicatori sub put_pdf");

    my $dt = $self->param('dt'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post

    my $json;

    $self->app->log->debug("PDF della rete: $net");

    # system
    eval{
        # $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");

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

            # https://github.com/koorchik/Mojolicious-Plugin-RenderFile
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

=head1 get_pdf_files

Funzione per recuperare tutti i files pdf disponibili sul portale.

Argomenti:  /

Return:     json contenente la risposta "OK" e, se presenti, i files pdf, altrimenti un array vuoto.

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