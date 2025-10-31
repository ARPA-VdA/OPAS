package Bobo::Controller::Dataview;
use Mojo::Base 'Mojolicious::Controller';

use Mojolicious::Validator;
use Mojolicious::Validator::Validation;
use Scalar::Util qw(looks_like_number);

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[encode_utf8];
use Mojo::AsyncAwait;
use Mojo::Promise;
use Mojo::IOLoop;


# This action will render a template
sub dataview {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub dataview");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $option = $self->dbdataview->get_dataview_options();
    $self->stash(option => decode_json(encode_utf8($option->{'option_object'})));

    my $description = $self->dbdataview->get_dataview_descriptions();
    $self->stash(description => $description);

    my $provinces;
    my $stations;

    if ($user_id) {
        $provinces = $self->dbdataview->get_dataview_all_provinces($user_id);
        $stations = $self->dbdataview->get_dataview_all_stations($user_id, -1, -1);
        $self->stash(logged => 1);
    }
    else {
        $provinces = $self->dbdataview->get_dataview_provinces();
        $stations = $self->dbdataview->get_dataview_stations(-1, -1);
        $self->stash(logged => 0);
    }

    $self->stash(provinces => $provinces);
    $self->stash(stations => $stations);

    my $params = $self->dbdataview->get_dataview_params();

    my $params_live = $self->dbdataview->get_dataview_params_live();

    # HACK to filter out the "Gamma" from the list of parameters
    # check if the region is not defined or it is not Valle d'Aosta
    if(!defined $self->stash('reg') || $self->stash('reg') != 2){
        # all except the gamma
        @{$params} = grep { $_->{'parameter_id'} != 151 } @{$params};
        @{$params_live} = grep { $_->{'parameter_id'} != 151 } @{$params_live};
    }

    $self->stash(params => $params);
    $self->stash(params_live => $params_live);

    my $params_ind = $self->dbdataview->get_dataview_params_indicator();
    $self->stash(params_ind => $params_ind);

    # render
    $self->render('strumenti/dataview_index');
}

# This action will render a template
sub station {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub station");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $option = $self->dbdataview->get_dataview_options();
    $self->stash(option => decode_json(encode_utf8($option->{'option_object'})));

    my $description = $self->dbdataview->get_dataview_descriptions();
    $self->stash(description => $description);

    # value of "/:stid" param
    my $station_id = $self->stash->{'stid'};
    $self->app->log->debug("Station: $station_id");

    my $stations;
    if ($user_id) {
        $stations = $self->dbdataview->get_dataview_all_stations($user_id, -1, -1);
        $self->stash(logged => 1);
    }
    else {
        $stations = $self->dbdataview->get_dataview_stations(-1, -1);
        $self->stash(logged => 0);
    }

    $self->stash(stations => $stations);

    if (!defined $user_id) {
        return $self->redirect_to('/str_dataview')
            unless $self->dbdataview->check_permission_station($station_id);
    }

    my $station = $self->dbcommon->get_station_by_id($station_id);

    my $files = $self->helperGetStationFiles($station->{'station_media_path'});

    my @matches = grep {/.*(media.*\/\d+\.(jpg|png|jpeg))/} @{$files->{'img_files'}};
    my $image;

    if (scalar @matches > 0) {
        $image = $matches[0];
        $image =~ /.*(media.*\.(jpg|png|jpeg))/;
        $image = "/$1";
    }
    else {
        $image= "/media/no-photo-dataview.png";
    }

    $self->stash(station => $station);
    $self->stash(image => $image);

    my $param_values = $self->dbdatamanager->get_public_last_data_bystation($station_id);
    $self->helperDumper(@{$param_values});
    if (@{$param_values}) {
        $self->stash(param_values => $param_values);
    }
    else {
        $self->stash(param_values => []);
    }

    # Render template "strumenti/dataview_station.html.ep" with message
    $self->render('strumenti/dataview_station');
}

# This action will render a template
sub download {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub download");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $option = $self->dbdataview->get_dataview_options();
    $self->stash(option => decode_json(encode_utf8($option->{'option_object'})));

    my $user_id = $self->session('it.ecometer.bobo');
    if ($user_id) {
        my $user = $self->dbcommon->get_user_byid($user_id);
        $self->stash(user => $user);
    }

    my $files = $self->dbdataview->get_dataview_files();
    $self->stash(files => $files);

    # Render template "strumenti/dataview_index.html.ep" with message
    $self->render('strumenti/dataview_download');
}

# start DATAVIEW INDEX section

sub get_stations_list {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_stations_list");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $regid = -1;
    my $provid = -1;

    if (defined $self->param('regid')) {
        $regid = $self->param('regid'); # post
    }

    if (defined $self->param('provid')) {
        $provid = $self->param('provid'); # post
    }

    return $self->render(json => {res => "ERR"})
        unless looks_like_number($regid) && looks_like_number($provid);

    my $user_id = $self->session('it.ecometer.bobo');
    my $stations;
    if ($user_id) {
        $stations = $self->dbdataview->get_dataview_all_stations($user_id, $regid, $provid);
    }
    else {
        $stations = $self->dbdataview->get_dataview_stations($regid, $provid);
    }

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_map_last_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_map_last_data");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    # my $station_id = $self->param('stid'); # post
    my $param_id = $self->param('prid');
    my $param_aggr = $self->param('aggr'); # post

    $self->app->log->debug("Parametro: $param_id");
    my $user_id = $self->session('it.ecometer.bobo');

    # sanity check
    return $self->render(json => { res => "ERR" })
        unless looks_like_number($param_id);

    my $stations;

    # get params from dateFrom to dateTo
    if (defined $user_id) {
        $stations = $self->dbdatamanager->get_dataview_map_all_last_station_data($user_id, $param_id, $param_aggr);
    }
    else {
        $stations = $self->dbdatamanager->get_dataview_map_last_station_data($param_id, $param_aggr);
    }

    # check result
    my $json;
    if (defined $stations) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            stations => $stations
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dei dati'
        };
    }

    $self->app->log->debug('Result: OK');

    # render
    $self->render(json => $json);
}

sub get_map_indicators {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_map_indicators");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    # my $station_id = $self->param('stid'); # post
    my $param_id = $self->param('prid');
    my $stat_id = $self->param('stat');
    # my $param_aggr = $self->param('aggr'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    my $stations;
    my $legend;

    $self->app->log->debug("Parametro: $param_id");

    # sanity check
    return $self->render(json => { res => "ERR" })
        unless looks_like_number($param_id) && looks_like_number($stat_id);
    # $self->helperDumper

    # get params from dateFrom to dateTo
    $legend = $self->dbdatamanager->get_dataview_indicators_color($param_id, $stat_id);

    if (defined $user_id) {
        $stations = $self->dbdatamanager->get_dataview_map_all_indicators($user_id, $param_id, $stat_id);
    }
    else {
        $stations = $self->dbdatamanager->get_dataview_map_indicators($param_id, $stat_id);
    }

    # check result
    my $json;
    if (defined $stations) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            legend => $legend,
            stations => $stations
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero degli indicatori'
        };
    }

    $self->app->log->debug('Result: OK');

    # log
    $self->render(json => $json)
}

sub get_map_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_map_stations");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $stations;
    my $params;
    my $user_id = $self->session('it.ecometer.bobo');

    if (defined $self->param('params')) {
        $params = decode_json($self->param('params'));
        $self->helperDumper($params);
    }

    if (!defined $user_id) {
        # get stations
        $stations = $self->dbdataview->get_map_stations($params);
    }
    else {
        $stations = $self->dbdataview->get_map_all_stations($user_id, $params);
    }

    # check result
    my $json;
    if (defined $stations) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            stations => $stations
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero delle stazioni'
        };
    }

    # render
    $self->render(json => $json)
}

# end DATAVIEW INDEX section

# start STATION section

sub get_all_params_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_all_params_data");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $station_id = $self->param('id'); # post
    my $aggregation = $self->param('aggr'); # post
    my $date_from = $self->param('from'); # post
    my $date_to = $self->param('to'); # post

    # sanity check
    return $self->render(json => { res => "ERR" })
        unless looks_like_number($station_id) &&
            ($aggregation eq 'hh' || $aggregation eq 'dd') &&
            $date_from =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/ &&
            $date_to =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/;

    my $data = $self->dbdatamanager->get_public_data_station($station_id, $aggregation, $date_from, $date_to);

    # check result
    my $json;
    if ($data) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            data => $data
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'ERR',
            message => 'Errore nel recupero dei dati'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_all_params_data_table {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_all_params_data_table");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $station_id = $self->param('id'); # post
    my $aggregation = $self->param('aggr'); # post
    my $date_from = $self->param('from'); # post
    my $date_to = $self->param('to'); # post

    return $self->render(json => { res => "ERR" })
        unless looks_like_number($station_id) &&
            ($aggregation eq 'hh' || $aggregation eq 'dd') &&
            $date_from =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/ &&
            $date_to =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/;

    my $json;
    my $params = $self->dbdatamanager->get_ordered_params_by_station($station_id);
    if (@{$params}) {
        my $data = $self->dbdatamanager->get_public_data_station_table($aggregation, $date_from, $date_to, $params);

        # check result
        if ($data) {
            $self->app->log->debug('Result: OK');
            $json = {
                res => 'OK',
                params => $params,
                data => $data
            };
        }
        else {
            $self->app->log->debug('Result: ERROR');
            $json = {
                res => 'ERR',
                message => 'Errore nel recupero dei dati'
            };
        }
    }
    else {
        $json = {
            res => 'ERR',
            message => 'Nessun parametro disponibile'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_windrose_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_windrose_data");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $params = $self->req->body_params->to_hash;
    my $station_id = $params->{'id'}; # post
    my $date_from = $params->{'from'}; # post
    my $date_to = $params->{'to'}; # post

    return $self->render(json => { res => "ERR" })
        unless looks_like_number($station_id);

    my $aggr = $self->dbcommon->get_min_aggregation();
    my $rs = $self->dbdatamanager->get_station_wind_rose_data($station_id, $date_from, $date_to, $aggr->{'app_aggregation_label'});

    my @json_calma;
    my @json_debole;
    my @json_moderata;
    my @json_forte;
    my @json_molto_forte;
    my @json_totale;
    my $tot = 0;
    my $tot_calma = 0;

    foreach my $rec (@{$rs}) {
        $tot = $tot + $rec->{'totale'};
        $tot_calma = $tot_calma + $rec->{'calma'};
    }

    foreach my $rec (@{$rs}) {
        if (!defined $tot || $tot == 0) {
            $tot = 1;
        }

        # if (defined $rec->{'calma'}) {
        #     my $value = $rec->{'calma'}+0 ;
        #     my $result = ($value / $tot) * 100;
        #     $self->app->log->debug("Risultato: $result ");
        #     push @json_calma, sprintf("%.3f", $result) + 0; # force to number
        # }
        # else {
        #     push @json_calma, undef;
        # }
        if (defined $rec->{'debole'}) {
            my $value = $rec->{'debole'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_debole, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_debole, undef;
        }
        if (defined $rec->{'moderata'}) {
            my $value = $rec->{'moderata'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_moderata, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_moderata, undef;
        }
        if (defined $rec->{'forte'}) {
            my $value = $rec->{'forte'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_forte, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_forte, undef;
        }
        if (defined $rec->{'molto_forte'}) {
            my $value = $rec->{'molto_forte'} + 0;
            my $result = ($value / $tot) * 100;
            push @json_molto_forte, sprintf("%.3f", $result) + 0; # force to number
        }
        else {
            push @json_molto_forte, undef;
        }
        if (defined $rec->{'totale'}) {
            push @json_totale, $rec->{'totale'} + 0; # force to number
        }
        else {
            push @json_totale, undef;
        }
    }

    # calma
    # debole
    # moderata
    # forte
    # molto_forte
    # totale

    # -------------------------------------------------------
    # RETURN
    # -------------------------------------------------------
    my $perc_calma = ($tot_calma / $tot) * 100;
    $perc_calma = sprintf("%.3f", $perc_calma) + 0;

    # json back
    $self->render(json => {
        perc_calma       => $perc_calma,
        json_debole      => \@json_debole,
        json_moderata    => \@json_moderata,
        json_forte       => \@json_forte,
        json_molto_forte => \@json_molto_forte,
        json_totale      => \@json_totale
    });
}

sub get_near_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_near_stations");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $station_id = $self->param('stid'); # post

    # sanity check
    return $self->render(json => { res => "ERR" })
        unless looks_like_number($station_id);

    # get stations
    my $user_id = $self->session('it.ecometer.bobo');

    my $stations;
    if ($user_id) {
        $stations = $self->dbdataview->get_all_near_stations($user_id, $station_id);
    }
    else {
        $stations = $self->dbdataview->get_near_stations($station_id);
    }

    # check result
    my $json;
    if ($stations) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            stations => $stations
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dei dati delle stazioni'
        };
    }

    # render
    $self->render(json => $json);
}

# end STATION section

# start DOWNLOAD section

sub get_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_stations");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $date_from = $self->param('from'); # post
    my $date_to = $self->param('to'); # post
    my $params;

    $self->app->log->debug("Data inizio: $date_from, data fine: $date_to");

    # return $self->render(json => {res => "ERR"})
    #     unless
    #         $date_from =~ /(\d{4})\-(\d\d)\-(\d\d)/ &&
    #         $date_to =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/;

    if (defined $self->param('params')) {
        $params = decode_json($self->param('params'));
        $self->helperDumper($params);
    }

    # get stations from dateFrom to dateTo
    my $stations = $self->dbdataview->get_stations_by_dates_params($date_from, $date_to, $params);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_params");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $date_from = $self->param('from'); # post
    my $date_to = $self->param('to'); # post
    my $aggr = $self->param('aggr'); # post
    my $stations;

    # return $self->render(json => {res => "ERR"})
    #     unless
    #         $date_from =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/ &&
    #         $date_to =~ /(\d{4})\-(\d\d)\-(\d\d)\s(\d\d):(\d\d):(\d\d)/;

    $self->app->log->debug("Data inizio: $date_from, data fine: $date_to, aggregazione: $aggr");
    # $self->helperDumper

    if (defined $self->param('stations')) {
        $stations = decode_json($self->param('stations'));
        $self->helperDumper($stations);
    }

    #get params from dateFrom to dateTo
    my $params = $self->dbdataview->get_params_by_dates_stations($date_from, $date_to, $aggr, $stations);

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_station_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_station_params");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $station_id = $self->param('stid'); # post

    # sanity check
    return $self->render(json => { res => "ERR" })
        unless looks_like_number($station_id);

    # get params from dateFrom to dateTo
    my $params = $self->dbdataview->get_params_by_station($station_id);

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_downloads {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_downloads");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $uuid = $self->param('uuid'); # post
    my $downloads = $self->dbdataview->get_all_jobs($uuid);

    my $json = {
        res => "OK",
        downloads => $downloads
    };

    # render
    $self->render(json => $json);
}

sub create_zip_files {
    my ($cmd, $jobid) = @_;

    say 'create_zip_files';

    my $promise = Mojo::Promise->new;
    Mojo::IOLoop->subprocess(
        sub { # first callback is executed in subprocess
            say "Lancio script creazioni ZIP";

            # run script via ssh
            say "[SSH] Lancio script creazione ZIP via ssh";

            # percorso script
            my $format_cmd = $cmd.' '.$jobid;

            # execute
            say "Running system: $format_cmd";

            # sleep(30); # sleep for 120 seconds
            # return 1;
            return system($format_cmd);
        },
        sub { # second callback resolves promise with subprocess result
            my ($self, $err, $result) = @_;
            say "Fine creazioni zip CSV";
            say $result;
            return $promise->reject($err) if $err;
            $promise->resolve($result);
        }
    );

    # return
    return $promise;
}

async get_data => sub {
    my $self = shift;

    # # Increase inactivity timeout for connection a bit
    # $self->inactivity_timeout(300);

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_data");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    # dump post data (with user infos)
    $self->helperDumperPostData('Dataview', 'get_data', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    $v->required('from');
    $v->required('to');
    $v->required('uuid');
    $v->required('dw-temp');
    $v->required('duallistbox_stat[]');
    $v->required('duallistbox_param[]');
    $v->required('ck-data-licenses');
    $v->required('ck-data-system');
    $v->required('ck-privacy-legacy');
    $v->required('ck-major-age');

    # Check for mandatory fields
    return $self->render(json => { res  => 'ERROR missing mandatory fields' }) if $v->has_error;

    # get dates
    my $date_from = $params->{'from'}; # post
    my $date_to = $params->{'to'}; # post
    my $aggr = $params->{'dw-temp'}; # post

    $self->app->log->debug("Data inizio: $date_from, data fine: $date_to");
    $self->app->log->debug("Aggregazione: $aggr");

    # eval text array
    my @stidArr;

    if (ref($params->{'duallistbox_stat[]'}) eq 'ARRAY') {
        @stidArr = @{$params->{'duallistbox_stat[]'}};
    }
    else {
        push @stidArr, $params->{'duallistbox_stat[]'};
    }

    my @pridArr;
    if (ref($params->{'duallistbox_param[]'}) eq 'ARRAY') {
        @pridArr = @{$params->{'duallistbox_param[]'}};
    }
    else {
        push @pridArr, $params->{'duallistbox_param[]'};
    }

    $self->app->log->debug("Stazioni:");
    $self->helperDumper(@stidArr);
    $self->app->log->debug("Parametri:");
    $self->helperDumper(@pridArr);

    $self->app->log->debug("Inizio recupero dati");
    my $obj = {
        start_d  =>  $date_from,
        end_d    =>  $date_to,
        aggr     =>  $aggr,
        st_ids   =>  \@stidArr,
        pr_ids   =>  \@pridArr
    };

    # if (1){
    if ($self->dbdataview->get_pending_jobs_by_params($params->{'uuid'}, $obj) >= 1) {
        $self->app->log->debug("Process already running");
        $self->render(json => -1);
    }
    else {
        # store request to audit table
        my $table = 'dataview';
        $self->helperInsertLog($table, encode_json($params));

        my $cmd = $self->dbutilities->get_job_command(5);
        my $jobid = $self->dbdataview->insert_new_job($params->{'uuid'}, $obj);
        my $promise = create_zip_files($cmd, $jobid);

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

# end DOWNLOAD section

# start JOBS ROUTINE section

sub get_notifications {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Dataview sub get_notifications");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $uuid = $self->param('uuid'); # post
    my $pending = $self->dbdataview->get_pending_jobs($uuid);
    my $notifications = $self->dbdataview->get_finished_jobs($uuid);

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
    $self->app->log->debug("Bobo::Controller::Dataview sub get_notifications");

    # first validation
    # only request from site
    my $v = $self->validation;

    # Check CSRF token
    return $self->render(json => { res => 'ERROR csrf check failed', status => 403 }) if $v->csrf_protect->has_error('csrf_token');

    my $id = $self->param('id'); # post
    $self->dbdataview->update_job_ack($id);

    # render
    $self->render(json => 1);
}

# end JOBS ROUTINE section

1;

=head1 dataview

Render della pagina dello strumento "Dataview".

Argomenti:  /

Return:     /

=cut

=head1 station

Render della pagina di dettaglio della stazione dello strumento "Dataview".

Argomenti:  * id dell'utente ('user_id');

Return:     /

=cut

=head1 download

Render della pagina dello scarico dati da Dataview.

Argomenti:  /

Return:     /

=cut

=head1 get_stations_list

Funzione che recupera la lista delle stazioni pubbliche attive in un determinato periodo temporale
e che acquisiscono i parametri selezionati dall'utente.

Argomenti:  * id della regione, se disponibile ('regid');

           * id della provincia, se disponibile ('provid');

Return:     json contenente il messaggio "OK" e le stazioni.

=cut

=head1 get_map_last_data

Funzione per recuperare gli ultimi dati disponibili delle stazioni presenti sul portale, visualizzabili
sulla mappa principale dello strumento "Dataview".

Argomenti:  /

Return:     json contenente il messaggio "OK" e i dati, oppure il messaggio "Errore nel recupero dei dati"

=cut

=head1 get_map_indicators

Funzione per recuperare gli indicatori disponibili relativi agli inquinanti delle stazioni presenti
sul portale, visualizzabili sulla mappa principale dello strumento "Dataview".

Argomenti:  /

Return:     json contenente il messaggio "OK" e i dati, oppure il messaggio "Errore nel recupero dei dati"

=cut

=head1 get_map_stations

Funzione per recuperare i pin relativi alle stazioni presenti sul portale,
visualizzabili sulla mappa principale dello strumento "Dataview".

Argomenti:  /

Return:     json contenente il messaggio "OK" e i dati, oppure il messaggio "Errore nel recupero dei dati"

=cut

=head1 get_all_params_data

Funzione per recuperare i dati di tutti i parametri associati ad una determinata stazione
per un determinato periodo temporale (formato grafico).

Argomenti:  * id della stazione ('id');

           * aggregazione dei dati ('aggr');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri, oppure la risposta "ERR".

=cut

=head1 get_all_params_data_table

Funzione per recuperare i dati di tutti i parametri associati ad una determinata stazione
per un determinato periodo temporale (formato tabella).

Argomenti:  * id della stazione ('id');

           * aggregazione dei dati ('aggr');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK" e le informazioni relative ai parametri, oppure la risposta "ERR".

=cut

=head1 get_windrose_data

Funzione per recuperare i dati necessari alla generazione della rosa dei venti
di una determinata stazione relativa ad un determinato periodo temporale.

Argomenti:  * oggetto contenente le informazioni necessarie alla generazione del grafico ('params');

           * id della stazione ('id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la query, la percentuale di calma di vento, la scala e i dati, oppure la risposta "ERR".

=cut

=head1 get_near_stations

Funzione per recuperare, dato l'id, le stazioni nelle vicinanze di una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente il messaggio "OK" e le stazioni, oppure il messaggio "Errore nel recupero dei dati delle stazioni".

=cut

=head1 get_stations

Funzione che recupera le stazioni pubbliche attive in un determinato periodo temporale e che acquisiscono i parametri selezionati dall'utente.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id del/dei parametro/i, se presente/i ('params');

Return:     json contenente il messaggio "OK" e le stazioni.

=cut

=head1 get_params

Funzione che recupera i parametri acquisiti in un determinato periodo temporale nelle stazioni pubbliche selezionate dall'utente.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * aggregazione temporale ('aggr');

           * id della/e stazione/e, se presente/i ('stations');

Return:     json contenente il messaggio "OK" e i parametri.

=cut

=head1 get_station_params

Funzione che recupera tutte le informazioni relative ai parametri acquisiti da una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente il messaggio "OK" e i parametri.

=cut

=head1 get_downloads

Funzione che recupera tutte le richieste di download lanciati da un determinato utente nel giorno corrente.

Argomenti:  * id univoco dell'utente che ha richiesto i dati ('uuid');

Return:     json contenente il messaggio "OK" e i downloads.

=cut

=head1 get_official_data

Funzione che invia un'email all'apposito ufficio con i parametri selezionati dall'utente per ottenere i dati ufficiali (mandati in secondo momento via PEC o posta).

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * aggregazione temporale ('dw-temp');

           * motivazione della richiesta ('dw-reason');

Return:     json contenente il messaggio "OK" e i jobs.

=cut

=head1 create_zip_files

Funzione che attraverso uno script crea il file zip contenente i dati richiesti.

Argomenti:  * id della richiesta ('jobid');

Return:     oggetto Promise che determina la riuscita dell'operazione.

=cut

=head1 get_data

Funzione asincrona che recupera i dati richiesti dall'utente.

Argomenti:  * oggetto contenente le informazioni inserite dall'utente ('params');

Return:     json contenente 1 o -1:

            - 1: OK, script lanciato;

            - -1: processo già in esecuzione con i parametri selezionati;

=cut

=head1 get_notifications

Funzione che recupera le richieste nella coda di job di Dataview visibili all'utente, sia quelle completate sia quelle ancora in pending.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente il messaggio "OK", le richieste ancora in pending e quelle completate.

=cut

=head1 put_notification_ack

Funzione che effettua l'update di una determinata richiesta nella coda di job di Dataview inserendone l'acknowledge.

Argomenti:  * id della richiesta ('id');

Return:     json contenente il valore 1.

=cut