package Bobo::Controller::Infoaria;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw(decode_utf8 encode_utf8);

use File::Basename;
use File::Find::Rule;
use File::Path;
use File::Temp qw/ tempfile tempdir /;

use Date::Calc qw(This_Year);

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

sub dataset_e2a {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria dataset_e2a");

    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($userid);
    $self->stash(provinces => $provinces);

    my $pollutants = $self->dbinfoaria->get_pollutants();
    $self->stash(pollutants => $pollutants);

    # render
    $self->render('infoaria/dataset_e2a');
};

sub dataset_e1a {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria dataset_e1a");

    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($userid);
    $self->stash(provinces => $provinces);

    # get pollutants
    my $pollutants = $self->dbinfoaria->get_pollutants();
    $self->stash(pollutants => $pollutants);

    # render
    $self->render('infoaria/dataset_e1a');
};

# This action will render a template
sub get_stations_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria sub get_stations_params");

    my $user_id = $self->session('it.ecometer.bobo');
    my $year = $self->param('year'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $stid = $self->param('stid'); # post
    my $prid = $self->param('prid'); # post

    $self->app->log->debug("Year: ".$year);

    if (!defined $year) {
        my $this_year = This_Year();

        $year = $this_year - 1;
    }

    my $params;
    if ($stid == -1) {
        $params = $self->dbinfoaria->get_all_stations_params_by_province($user_id, $net, $prov, $prid, $year);
    }
    else {
        $params = $self->dbinfoaria->get_all_station_params($stid, $prid, $year);
    }

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

sub get_stations_params_e2a_recap {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria sub get_stations_params_e2a_recap");

    my $user_id = $self->session('it.ecometer.bobo');
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $stid = $self->param('stid'); # post

    my $params = $self->dbinfoaria->get_stations_params_e2a_recap($user_id, $net, $prov, $stid);

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

sub get_e1a_files {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria sub get_e1a_files");

    my $reg = $self->param('reg'); # post
    my $year = $self->param('year'); # post

    # get times
    my $reg_path = sprintf("%02d", $reg);

    # ricerca tutti .csv file nella directory
    my $path = $self->app->home->rel_file("public/downloads/infoaria/$reg_path/e1a");
    $self->app->log->debug("Application path: $path");

    my @files_csv = File::Find::Rule->file->name('E1a_'.$reg_path.'\_'.$year.'*.csv')->in($path);
    my $length = scalar @files_csv;
    $self->app->log->debug("Files csv: $length");

    my @files_html = File::Find::Rule->file->name('E1a_'.$reg_path.'\_'.$year.'*.html')->in($path);
    $length = scalar @files_html;
    $self->app->log->debug("Files html: $length");

    my @files = (@files_csv, @files_html);
    $length = scalar @files;
    $self->app->log->debug("Files: $length");

    # $self->helperDumper(@files);
    $self->app->log->debug("@files\n");

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

sub get_stations_params_e1a_recap {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria sub get_stations_params_e1a_recap");

    my $user_id = $self->session('it.ecometer.bobo');
    my $year = $self->param('year'); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $stid = $self->param('stid'); # post

    $self->app->log->debug("YEAR $year");

    my $params = $self->dbinfoaria->get_stations_params_e1a_recap($user_id, $year, $net, $prov, $stid);

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

sub put_status {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Infoaria sub put_status");
    $self->helperDumperPostData('Infoaria', 'put_status', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $status = decode_json(encode_utf8($params->{'status'}));

    my $res = 1;

    if ($self->dbinfoaria->update_stations_params_status($status)) {
        $self->app->log->debug("Success");
    }
    else { # elimino la pagina dal gruppo
        $self->app->log->debug("Error");
        $res = 0;
    }

    # render
    $self->render(json => $res);
}

sub create_csv {
    my ($cmd, $jobid, $regid) = @_;

    say 'create_csv';

    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script creazione file CSV E1A";

            # run script via ssh
            say "[SSH] Lancio script creazione CSV via ssh";

            # percorso script
            # r script
            my $format_cmd = $cmd.' '.$jobid.' '.$regid;

            # execute
            say "Running system: $format_cmd";
            # sleep(30);  # sleep for 120 seconds
            # return 1;
            return system($format_cmd);
        },
        sub { # second callback resolves promise with subprocess result
            my ($self, $err, $result) = @_;
            say "Fine script creazione file CSV E1A";
            say $result;
            return $promise->reject($err) if $err;
            $promise->resolve($result);
        }
    );

    # return
    return $promise;
}

async put_e1a_creation => sub {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Openair sub put_e1a_creation");

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    # log
    $self->app->log->debug("Creating CSV...");

    my $obj = {
        year => $params->{'year'},
        region => $params->{'reg'},
        ftp => $params->{'ftp'}
    };

    # if (1) {
    if ($self->dbutilities->get_pending_jobs_by_params(4, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        # get times
        my $reg_path = sprintf("%02d", $params->{'reg'});
        my $path = $self->app->home->rel_file("public/downloads/infoaria/$reg_path/e1a");
        $self->app->log->debug("Application path: $path");
        $self->helperCreatePath($path);

        my $cmd = $self->dbutilities->get_job_command(4);
        my $jobid = $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), 4, $obj);
        my $promise = create_csv($cmd, $jobid, $params->{'reg'});

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

1;

=head1 dataset_e2a

Render della pagina di visualizzazione dei contenuti relativi al Dataset E2a.

Argomenti:  /

Return:     /

=cut

=head1 dataset_e1a

Render della pagina di visualizzazione dei contenuti relativi al Dataset E1a.

Argomenti:  /

Return:     /

=cut

=head1 get_stations_params

Funzione per recuperare, dati l'anno e i vari id di rete, provincia, stazione e parametro, lo
stato delle associazioni stazione/parametro per il dataset e1a/e2a

Argomenti:  * id dell'utente ('user_id');

           * anno, se presente ('year');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stid');

           * id del parametro, se presente ('prid');

Return:     json contenente la risposta "OK" e le associazioni, oppure la risposta "ERR".

=cut

=head1 get_stations_params_e2a_recap

Funzione per recuperare, dati i vari id di rete, provincia e stazione, lo
stato delle associazioni stazione/parametro per il dataset e2a.

Argomenti:  * id dell'utente ('user_id');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stid');

Return:     json contenente la risposta "OK" e le associazioni, oppure la risposta "ERR".

=cut

=head1 get_e1a_files

Funzione per recuperare, dati regione ed anno, i file csv relativi al Dataset E1a.

Argomenti:  * regione ('reg');

           * anno ('year');

Return:     json contenente la risposta "OK" e l'oggetto relativo ai files, oppure un oggetto vuoto.

=cut

=head1 get_stations_params_e1a_recap

Funzione per recuperare, dati l'anno e i vari id di rete, provincia, stazione e parametro, lo
stato delle associazioni stazione/parametro per il dataset e1a.

Argomenti:  * id dell'utente ('user_id');

           * anno, se presente ('year');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prov');

           * id della stazione, se presente ('stid');

Return:     json contenente la risposta "OK" e le associazioni, oppure la risposta "ERR".

=cut

=head1 put_status

Funzione per modificare lo stato d'invio di un'associazione stazione/parametro.

Argomenti:  * oggetto contenente le informazioni dell'associazione ('params');

           * status da modificare ('status');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 create_csv

Funzione che effettua il lancio dello script di creazione del csv per il dataset E1a.

Argomenti:  * id della richiesta nella coda di job ('jobid');

Return:     oggetto Promise che determina la riuscita dell'operazione.

=cut

=head1 put_e1a_creation

Funzione asincrona che processa le richieste inviate dall'utente per la generazione dei csv per il dataset E1a

Argomenti:  /

Return:     json contenente 1 o -1:

            - 1: OK, script lanciato;

            - -1: processo già in esecuzione con i parametri selezionati;

=cut