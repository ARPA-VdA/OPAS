package Bobo::Controller::Openair;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use File::Find::Rule;
use File::Path;
use File::Temp qw/ tempfile tempdir /;

use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;

use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;

sub openair {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Openair openair");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get equipments categories
    my $categories = $self->dbutilities->get_openair_equipments_categories();
    $self->stash(categories => $categories);

    # Render template "strumenti/openair.html.ep" with message
    $self->render('strumenti/openair');
}

sub get_runs {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Openair sub get_runs");

    my $user_id = $self->session('it.ecometer.bobo');

    # get openair runs
    my $runs = $self->dbutilities->get_openair_runs($user_id);

    my $json = {
        res => "OK",
        runs => $runs
    };

    # render
    $self->render(json => $json);
}

sub get_images {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Openair sub get_images");

    my $id = $self->param('id'); # post
    $self->app->log->debug("ID Job: $id");

    my $job = $self->dbutilities->get_job_by_id($id);
    my $result_obj = $job->{'jq_result_obj'};

    $self->helperDumper($result_obj);

    my $json;
    if (defined $result_obj) {
        $result_obj = decode_json($job->{'jq_result_obj'});

        if ($result_obj->{'type'} eq 'succ') {
            my $dir = $result_obj->{'dir'};

            # get times
            my $tm = Time::Moment->now;
            my $head_time = $tm->strftime("%Y%m%d");
            my $path = $self->app->home->rel_file("public/downloads/openair/$head_time/$dir");

            $self->app->log->debug("$path");

            # creazione dell'array contenente i file delle immagini
            my @img_files = File::Find::Rule->file()->name( '*.png')->in($path);

            if (scalar @img_files > 0) {
                my @obj_files;

                # ciclo per ogni immagine...
                for my $file (@img_files){
                    my $path = $file =~ s/^.*public\///r; # formatto il file path
                    my $name = $file =~ s/^.*\d\///r; # isolo il nome del file
                    my $formatted_name = ""; # nome formattato per l'anteprima dei grafici sul portale

                    $path .= '?v='.time();
                    $name = $name =~ s/[.]png//r;

                    # controlli sui nomi delle immagini per creare il nome formattato
                    if ($name =~ /\bwind\b/) {
                        $formatted_name = "Direzione e velocità del vento";
                    }
                    elsif ($name =~ /\bwindrose\b/) {
                        $formatted_name = "Rosa dei venti";
                    }
                    elsif ($name =~ /\bwindrose_season\b/) {
                        $formatted_name = "Rosa dei venti stagionale";
                    }
                    elsif ($name =~ /\bpollutionrose_so2\b/) {
                        $formatted_name = "Pollution Rose - SO2";
                    }
                    elsif ($name =~ /\bpollutionrose_nox\b/) {
                        $formatted_name = "Pollution Rose - NOX";
                    }
                    elsif ($name =~ /\bpollutionrose_no2\b/) {
                        $formatted_name = "Pollution Rose - NO2";
                    }
                    elsif ($name =~ /\bpollutionrose_no\b/) {
                        $formatted_name = "Pollution Rose - NO";
                    }
                    elsif ($name =~ /\bpollutionrose_co\b/) {
                        $formatted_name = "Pollution Rose - CO";
                    }
                    elsif ($name =~ /\bpollutionrose_o3\b/) {
                        $formatted_name = "Pollution Rose - O3";
                    }
                    elsif ($name =~ /\bpollutionrose_pm10\b/) {
                        $formatted_name = "Pollution Rose - PM10";
                    }
                    elsif ($name =~ /\bpollutionrose_pm25\b/) {
                        $formatted_name = "Pollution Rose - PM2.5";
                    }
                    elsif ($name =~ /\bpollutionrose_ben\b/) {
                        $formatted_name = "Pollution Rose - Benzene";
                    }
                    elsif ($name =~ /\bpollutionrose_tol\b/) {
                        $formatted_name = "Pollution Rose - Toluene";
                    }
                    elsif ($name =~ /\bpollutionrose_etil\b/) {
                        $formatted_name = "Pollution Rose - Etilbenzene";
                    }
                    elsif ($name =~ /\bpolarplot_so2\b/) {
                        $formatted_name = "Polar Plot - SO2";
                    }
                    elsif ($name =~ /\bpolarplot_nox\b/) {
                        $formatted_name = "Polar Plot - NOX";
                    }
                    elsif ($name =~ /\bpolarplot_no2\b/) {
                        $formatted_name = "Polar Plot - NO2";
                    }
                    elsif ($name =~ /\bpolarplot_no\b/) {
                        $formatted_name = "Polar Plot - NO";
                    }
                    elsif ($name =~ /\bpolarplot_co\b/) {
                        $formatted_name = "Polar Plot - CO";
                    }
                    elsif ($name =~ /\bpolarplot_o3\b/) {
                        $formatted_name = "Polar Plot - O3";
                    }
                    elsif ($name =~ /\bpolarplot_pm10\b/) {
                        $formatted_name = "Polar Plot - PM10";
                    }
                    elsif ($name =~ /\bpolarplot_pm25\b/) {
                        $formatted_name = "Polar Plot - PM2.5";
                    }
                    elsif ($name =~ /\bpolarplot_ben\b/) {
                        $formatted_name = "Polar Plot - Benzene";
                    }
                    elsif ($name =~ /\bpolarplot_tol\b/) {
                        $formatted_name = "Polar Plot - Toluene";
                    }
                    elsif ($name =~ /\bpolarplot_etil\b/) {
                        $formatted_name = "Polar Plot - Etilbenzene";
                    }
                    elsif ($name =~ /\bpolarplot_season_so2\b/) {
                        $formatted_name = "Polar Plot Season - SO2";
                    }
                    elsif ($name =~ /\bpolarplot_season_nox\b/) {
                        $formatted_name = "Polar Plot Season - NOX";
                    }
                    elsif ($name =~ /\bpolarplot_season_no2\b/) {
                        $formatted_name = "Polar Plot Season - NO2";
                    }
                    elsif ($name =~ /\bpolarplot_season_no\b/) {
                        $formatted_name = "Polar Plot Season - NO";
                    }
                    elsif ($name =~ /\bpolarplot_season_co\b/) {
                        $formatted_name = "Polar Plot Season - CO";
                    }
                    elsif ($name =~ /\bpolarplot_season_o3\b/) {
                        $formatted_name = "Polar Plot Season - O3";
                    }
                    elsif ($name =~ /\bpolarplot_season_pm10\b/) {
                        $formatted_name = "Polar Plot Season - PM10";
                    }
                    elsif ($name =~ /\bpolarplot_season_pm25\b/) {
                        $formatted_name = "Polar Plot Season - PM2.5";
                    }
                    elsif ($name =~ /\bpolarplot_season_ben\b/) {
                        $formatted_name = "Polar Plot Season - Benzene";
                    }
                    elsif ($name =~ /\bpolarplot_season_tol\b/) {
                        $formatted_name = "Polar Plot Season - Toluene";
                    }
                    elsif ($name =~ /\bpolarplot_season_etil\b/) {
                        $formatted_name = "Polar Plot Season - Etilbenzene";
                    }
                    elsif ($name =~ /\bpolarannulus_so2\b/) {
                        $formatted_name = "Polar Annulus - SO2";
                    }
                    elsif ($name =~ /\bpolarannulus_nox\b/) {
                        $formatted_name = "Polar Annulus - NOX";
                    }
                    elsif ($name =~ /\bpolarannulus_no2\b/) {
                        $formatted_name = "Polar Annulus - NO2";
                    }
                    elsif ($name =~ /\bpolarannulus_no\b/) {
                        $formatted_name = "Polar Annulus - NO";
                    }
                    elsif ($name =~ /\bpolarannulus_co\b/) {
                        $formatted_name = "Polar Annulus - CO";
                    }
                    elsif ($name =~ /\bpolarannulus_o3\b/) {
                        $formatted_name = "Polar Annulus - O3";
                    }
                    elsif ($name =~ /\bpolarannulus_pm10\b/) {
                        $formatted_name = "Polar Annulus - PM10";
                    }
                    elsif ($name =~ /\bpolarannulus_pm25\b/) {
                        $formatted_name = "Polar Annulus - PM2.5";
                    }
                    elsif ($name =~ /\bpolarannulus_ben\b/) {
                        $formatted_name = "Polar Annulus - Benzene";
                    }
                    elsif ($name =~ /\bpolarannulus_tol\b/) {
                        $formatted_name = "Polar Annulus - Toluene";
                    }
                    elsif ($name =~ /\bpolarannulus_etil\b/) {
                        $formatted_name = "Polar Annulus - Etilbenzene";
                    }
                    elsif ($name =~ /\bpolarannulus_season_so2\b/) {
                        $formatted_name = "Polar Annulus Season - SO2";
                    }
                    elsif ($name =~ /\bpolarannulus_season_nox\b/) {
                        $formatted_name = "Polar Annulus Season - NOX";
                    }
                    elsif ($name =~ /\bpolarannulus_season_no2\b/) {
                        $formatted_name = "Polar Annulus Season - NO2";
                    }
                    elsif ($name =~ /\bpolarannulus_season_no\b/) {
                        $formatted_name = "Polar Annulus Season - NO";
                    }
                    elsif ($name =~ /\bpolarannulus_season_co\b/) {
                        $formatted_name = "Polar Annulus Season - CO";
                    }
                    elsif ($name =~ /\bpolarannulus_season_o3\b/) {
                        $formatted_name = "Polar Annulus Season - O3";
                    }
                    elsif ($name =~ /\bpolarannulus_season_pm10\b/) {
                        $formatted_name = "Polar Annulus Season - PM10";
                    }
                    elsif ($name =~ /\bpolarannulus_season_pm25\b/) {
                        $formatted_name = "Polar Annulus Season - PM2.5";
                    }
                    elsif ($name =~ /\bpolarannulus_season_ben\b/) {
                        $formatted_name = "Polar Annulus Season - Benzene";
                    }
                    elsif ($name =~ /\bpolarannulus_season_tol\b/) {
                        $formatted_name = "Polar Annulus Season - Toluene";
                    }
                    elsif ($name =~ /\bpolarannulus_season_etil\b/) {
                        $formatted_name = "Polar Annulus Season - Etilbenzene";
                    }

                    my $obj = {
                        path => $path,
                        name => $name,
                        formatted_name => $formatted_name
                    };

                    push @obj_files, $obj;
                }

                # return ok
                $json = {
                    res => 'OK',
                    img_files => [@obj_files]
                };
            }
        }
        elsif ($result_obj->{'type'} eq 'warn' && $result_obj->{'dir'} eq 'NA') {
            # return error
            $json = {
                res => 'EMPTY'
            };
        }
        else {
            # return error
            $json = {
                res => 'ERR'
            };
        }
    }
    else {
        $self->app->log->debug('Job not finished yet');
        $json = {
            res => 'WAIT'
        };
    }

    # render
    $self->render(json => $json);
}

sub create_images {
    my ($cmd, $jobid) = @_;

    say 'create_images';

    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script creazioni immagini openair";

            # run script via ssh
            say "[SSH] Lancio script creazione pdf via ssh";

            # percorso script
            # r script
            my $format_cmd = $cmd.' '.$jobid;
            # run local script
            #my $cmd = '/usr/bin/Rscript /data/bin/arpa_lig/stats/stats.R \''.$dt.'\' '.$prov;

            # execute
            say "Running system: $format_cmd";
            # sleep(30);  # sleep for 120 seconds
            # return 1;
            return system($format_cmd);
        },
        sub { # second callback resolves promise with subprocess result
            my ($self, $err, $result) = @_;
            say "Fine script creazioni immagini OPENAIR";
            say $result;
            return $promise->reject($err) if $err;
            $promise->resolve($result);
        }
    );

    # return
    return $promise;
}

async put_images_creation => sub {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Openair sub put_images_creation");

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper( $params );

    # $self->app->log->debug("Temp path: $temp_path");
    my $options = '';
    if ($params->{'openair-scale'} == 1) {
        $options = $params->{'openair-insert-num'};
    }
    elsif ($params->{'openair-scale'} == 2) {
        $options = $params->{'openair-insert-step'};
    }

    $self->app->log->debug("Creating images...");

    my $obj = {
        start_d => $params->{'from'},
        end_d => $params->{'to'},
        stid_p => $params->{'openair-stat-poll'},
        stid_w => $params->{'openair-stat-wea'},
        inst_cat => $params->{'openair-equip-cat'},
        w_calm => $params->{'openair-wind-calm'},
        l_lim => $params->{'openair-limit-low'},
        u_lim => $params->{'openair-limit-high'},
        scale_type => $params->{'openair-scale'},
        scale_opt => $options
    };

    # if (1) {
    if ($self->dbutilities->get_pending_jobs_by_params(2, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        # get times
        my $tm = Time::Moment->now;
        my $head_time = $tm->strftime("%Y%m%d");
        my $path = $self->app->home->rel_file("public/downloads/openair/$head_time");
        $self->app->log->debug("Application path: $path");
        $self->helperCreatePath($path);

        my $cmd = $self->dbutilities->get_job_command(2);
        my $jobid =  $self->dbutilities->insert_new_job($self->session('it.ecometer.bobo'), 2, $obj);
        my $promise = create_images($cmd, $jobid);

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

1;

=head1 openair

Render della pagina di visualizzazione dei grafici OpenAir.

Argomenti:  /

Return:     /

=cut

=head1 get_runs

Funzione per recuperare tutte le esecuzioni dello script di generazione dei grafici OpenAir richieste dall'utente nel giorno corrente.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le esecuzioni.

=cut

=head1 get_images

Funzione per recuperare le immagini dei grafici di una determinata richiesta.

Argomenti:  * id della richiesta ('id');

Return:     json contenente la risposta "OK" e le immagini, se presenti (sennò il messaggio "EMPTY"), oppure un messaggio di attesa ("WAIT") qualora l'esecuzione dello script non sia ancora terminato.

=cut

=head1 create_images

Funzione che effettua il lancio dello script di creazione delle immagini di OpenAir.

Argomenti:  * id della richiesta nella coda di job ('jobid');

Return:     oggetto Promise che determina la riuscita dell'operazione.

=cut

=head1 put_images_creation

Funzione asincrona che processa le richieste inviate dall'utente per la generazione delle immagini di Openair

Argomenti:  /

Return:     json contenente 1 o -1:

            - 1: OK, script lanciato;

            - -1: processo già in esecuzione con i parametri selezionati;

=cut