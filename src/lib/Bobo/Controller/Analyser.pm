package Bobo::Controller::Analyser;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

use Mojo::File 'path';
use File::Path qw(rmtree);
use File::Temp qw/ tempfile tempdir /;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use Scalar::Util qw(looks_like_number);
use Time::Moment;

sub analyser {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub analyser");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    my $portal_groups_list = $self->dbcommon->get_portal_groups_by_user($user_id);
    $self->stash(portal_groups_list => $portal_groups_list);

    my $val_codes = $self->dbcommon->get_validation_codes();
    $self->stash(val_codes => $val_codes);

    my $aggregations = $self->dbcommon->get_aggregations($user_id);
    $self->stash(aggregations => $aggregations);

    my $treatments = $self->dbcommon->get_treatments();
    $self->stash(treatments => $treatments);

    my $scales = $self->dbanalyser->get_wind_scales();
    $self->stash(scales => $scales);

    # Render template "strumenti/analyser.html.ep" with message
    $self->render('strumenti/analyser');
}

sub get_analyser_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_analyser_options");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $gen_opt = $self->dbanalyser->get_analyser_general_options();
    my $user_opt = $self->dbanalyser->get_analyser_user_options($user_id);
    my $json;

    if (defined $user_opt) {
        $json = {
            res => "OK",
            gen_opt => decode_json(encode_utf8($gen_opt->{'option_object'})),
            user_opt => decode_json(encode_utf8($user_opt->{'option_object'}))
        };
    }
    else {
        $json = {
            res => "OK",
            gen_opt => decode_json(encode_utf8($gen_opt->{'option_object'})),
            user_opt => undef
        };
    }

    # render
    $self->render(json => $json);
}

sub get_categories {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_categories");

    my $user_id = $self->session('it.ecometer.bobo');

    my $categories_list = $self->dbanalyser->get_categories_list($user_id);
    my $json;

    if (defined $categories_list) {
        $json = {
            res => "OK",
            categories_list => $categories_list
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

sub get_category_byid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_category_byid");

    my $cat_id = $self->param('id'); # post

    $self->app->log->debug("cat_id: $cat_id");

    my $category = $self->dbanalyser->get_category_byid($cat_id);
    my $json;

    if (defined $category) {
        $json = {
            res => "OK",
            category => $category
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

sub get_analyser_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_analyser_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get groups for the construction of the jstree
    my $groups = $self->dbanalyser->get_analyser_groups($user_id);

    if (defined $groups) {
        # $self->helperDumper( decode_json(encode_utf8($groups)) );
        $self->render(json => decode_json(encode_utf8($groups)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-package' ,
            'text'=> 'Nessun sottogruppo'
        });
    }
}

sub get_group_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_group_stations");

    # dump
    $self->helperDumper($self->req->query_params->to_hash);

    my $user_id = $self->session('it.ecometer.bobo');

    # get group id
    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));

    $self->app->log->debug("Got grid: $grid");

    # get stations by group id for the construction of the jstree
    my $stations = $self->dbanalyser->get_group_stations($nodeid, $grid, $options, $user_id);

    if (defined $stations) {
        # $self->helperDumper( decode_json(encode_utf8($stations)));
        $self->render(json => decode_json(encode_utf8($stations)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-home' ,
            'text'=> 'Nessuna stazione presente'
        });
    }
}

sub get_station_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_station_params");

    $self->helperDumper($self->req->query_params->to_hash);

    my $stid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));

    $self->app->log->debug("Got stid: $stid");

    # get params by station id for the construction of the jstree
    my $params = $self->dbanalyser->get_station_params($nodeid, $stid, $options);

    if (defined $params) {
        # $self->helperDumper( decode_json(encode_utf8($params)) );
        $self->render(json => decode_json(encode_utf8($params)));
    }
    else {
        $self->render(json => []);
    }
}

sub get_params_type {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_params_type");

    $self->helperDumper( $self->req->query_params->to_hash);

    my $stid = $self->req->query_params->to_hash->{id};
    my $type = $self->req->query_params->to_hash->{type};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));

    $self->app->log->debug("Got stid: $stid");

    # get params by station id for the construction of the jstree
    my $params = $self->dbanalyser->get_params_type($nodeid, $stid, $type, $options);

    if (defined $params) {
        # $self->helperDumper( decode_json(encode_utf8($params)) );
        $self->render(json => decode_json(encode_utf8($params)));
    }
    else {
        $self->render(json => []);
    }
}

sub get_groups {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_groups");

    my $user_id = $self->session('it.ecometer.bobo');

    # get macro groups for the construction of the jstree
    my $macro_groups = $self->dbanalyser->get_groups($user_id);
    $self->helperDumper($macro_groups);

    if (defined $macro_groups) {
        # $self->helperDumper( decode_json(encode_utf8($macro_groups)) );
        $self->render(json => decode_json(encode_utf8($macro_groups)));
    }
    else {
        $self->render(json => {
            'icon'=> 'ti-package' ,
            'text'=> 'Nessuna categoria presente'
        });
    }
}

sub get_group_macros {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_station_params");

    $self->helperDumper( $self->req->query_params->to_hash);

    my $grid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    my $options = decode_json(encode_utf8($self->req->query_params->to_hash->{options}));
    $self->app->log->debug("Got grid: $grid");

    # get macros by category id for the construction of the jstree
    my $macros = $self->dbanalyser->get_group_macros($nodeid, $grid, $options);

    if (defined $macros) {
        # $self->helperDumper( decode_json(encode_utf8($macros)) );
        $self->render(json => decode_json(encode_utf8($macros)));
    }
    else {
        $self->render(json => []);
    }
}

sub get_macro_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_macro_params");

    $self->helperDumper($self->req->query_params->to_hash);

    my $macroid = $self->req->query_params->to_hash->{id};
    my $nodeid = $self->req->query_params->to_hash->{nodeid};
    $self->app->log->debug("Got macroid: $macroid");

    # get macros by category id for the construction of the jstree
    my $params = $self->dbanalyser->get_macro_params($nodeid, $macroid);

    if (defined $params) {
        # $self->helperDumper( decode_json(encode_utf8($params)) );
        $self->render(json => decode_json(encode_utf8($params)));
    }
    else {
        $self->render(json => []);
    }
}

sub get_macro_metadata {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_macro_metadata");

    my $mcid = $self->param('id'); # post

    $self->app->log->debug("Macro id: $mcid");

    my $json;
    my $macro = $self->dbanalyser->get_macro_byid($mcid);

    if (defined $macro) {
        $json = {
            res => "OK",
            category => $macro->{'macro_category'},
            macro => decode_json(encode_utf8($macro->{'macro_object'}))
        };
    }
    else {
        $json = {
            res => "ERR"
        }
    }

    # render
    $self->render(json => $json);
}

sub get_param_info {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_param_info");

    my $stprid = $self->param('stprid'); # post
    my $conv = $self->param('conv'); # post

    $self->app->log->debug("St_pr_id: $stprid");

    my $json;

    my $param = $self->dbanalyser->get_info_param($stprid, $conv);

    $json = {
        res => "OK",
        param => $param
    };

    # render
    $self->render(json => $json);
}

sub get_limit_info {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_limit_info");

    my $lm_id = $self->param('lmid'); # post

    $self->app->log->debug("Limit ID: $lm_id");

    my $json;

    my $limit = $self->dbanalyser->get_info_limit($lm_id);

    $json = {
        res => "OK",
        limit => $limit
    };

    # render
    $self->render(json => $json);
}

sub get_wind_scale {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_wind_scale");

    my $scaleid = $self->param('scaleid'); # post

    my $scaleobj  = $self->dbanalyser->get_wind_scale_byid($scaleid);

    my $json = {
        res => "OK",
        scale => $scaleobj
    };

    # render
    $self->render(json => $json);
}

sub get_highcharts_data_bydate {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_data_bydate");

    my $macro = $self->param('macro');
    $macro = decode_json(encode_utf8($macro));
    # $self->helperDumper($macro);

    # post
    my $hide_nulls = $self->param('hideNulls'); # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $flag_notes = $self->param('notes'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("Recupero notes: ". $flag_notes);

    # get data from dateFrom to dateTo
    my $json;

    my $data;
    my $query;

    if ($macro->{macro}{aggregation} =~ /rep\_/) {
        $data  = $self->dbdatamanager->get_highcharts_representative_data_by_dates($from, $to, $macro);
        $query = '';
    }
    else {
        $data  = $self->dbdatamanager->get_highcharts_data_by_dates($from, $to, $hide_nulls, $macro);
        $query = $self->dbdatamanager->get_highcharts_query($from, $to, $hide_nulls, $macro);
    }

    if (defined $data) {
        $json = {
            res => "OK",
            data => $data,
            query => $query,
            notes => undef
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

sub get_highcharts_data_per_year {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_highcharts_data_by_year");

    my $macro = $self->param('macro');
    $macro = decode_json(encode_utf8($macro));

    # post
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");

    # get data from dateFrom to dateTo
    my $json;
    my $data;
    my $query = '';

    $data = $self->dbdatamanager->get_highcharts_data_per_year($from, $to, $macro);

    if (defined $data) {
        $json = {
            res => "OK",
            data => $data,
            query => $query
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

sub get_windrose_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_windrose_data");

    my $params   = $self->req->body_params->to_hash;
    my $stid     = $params->{'stid'}; # post
    my $dateFrom = $params->{'from'}; # post
    my $dateTo   = $params->{'to'}; # post
    my $validity = $params->{'valcode'}; # post
    my $scaleid  = $params->{'scale'}; # post

    $self->app->log->debug("Data inizio: $dateFrom, data fine: $dateTo, validità: $validity ");

    my $scaleobj = $self->dbanalyser->get_wind_scale_byid($scaleid);
    my $scale    = decode_json(encode_utf8($scaleobj->{'ws_obj'}));

    # get data from dateFrom to dateTo
    my $rs    = $self->dbdatamanager->get_windrose_data_bydates($stid, $dateFrom, $dateTo, $validity, $scale);
    my $query = $self->dbdatamanager->get_windrose_query($stid, $dateFrom, $dateTo, $validity, $scale);

    if (defined $rs) {
        my @json_classes;
        # my @json_debole;
        # my @json_moderata;
        # my @json_forte;
        # my @json_molto_forte;
        # my @json_totale;
        my $tot = 0;
        my $tot_calma = 0;

        foreach my $rec (@{$rs}) {
            $tot = $tot + $rec->{'totale'};
            $tot_calma = $tot_calma + $rec->{'class0'};
        }

        my $first_loop = 1;
        foreach my $rec (@{$rs}) {
            if (!defined $tot || $tot == 0) {
                $tot = 1;
            }

            my $cnt = 0;
            foreach my $class (@{$scale}) {
                if ($cnt == 0) { #se calma allora la salto
                    # $self->app->log->debug("Next!");
                    $cnt++;
                    next;
                }

                # $self->app->log->debug("Classe $cnt");
                if ($first_loop) {
                    $json_classes[$cnt] = [];
                }

                if (defined $rec->{'class'.$cnt}) {
                    my $value = $rec->{'class'.$cnt}+0 ;
                    my $result = ($value / $tot) * 100;

                    push @{$json_classes[$cnt]}, sprintf("%.3f", $result) + 0; # force to number
                }
                else {
                    push @{$json_classes[$cnt]}, undef;
                }

                $cnt++;
            }

            $first_loop = 0; # almeno un giro è stato compiuto, metto a false il flag
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
            query            => $query,
            perc_calma       => $perc_calma,
            scale            => $scale,
            classes          => \@json_classes
        });
    }
    else {
        my $json = {
            res => "ERR"
        };

        $self->render(json => $json);
    }
}

sub get_tabulator_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_tabulator_data");

    my $macro = decode_json(encode_utf8($self->param('macro')));
    my $hide_nulls = $self->param('hideNulls'); # post
    my $from = $self->param('from');
    my $to = $self->param('to');

    my $data;
    my $query;

    if ($macro->{macro}{aggregation} =~ /rep\_/) {
        $data  = $self->dbdatamanager->get_datatable_representative_data_by_dates($from, $to, $macro);
        $query = '';
    }
    else {
        $data = $self->dbdatamanager->get_datatable_data_by_dates($from, $to, $hide_nulls, $macro);
        $query = $self->dbdatamanager->get_datatable_query($from, $to, $hide_nulls, $macro);
    }

    # $self->helperDumper( $data );
    my $json = {
        res => "OK",
        data => $data,
        query => $query,
        # last_page => $last_page
        # info =>
    };

    # render
    $self->render(json => $json);
}

sub get_csv_data {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub get_csv_data");

    my $macro = decode_json(encode_utf8($self->param('macro')));
    my @params_array = @{$macro->{'params'}};
    my $hide_nulls = $self->param('hideNulls'); # post
    my $date_from = $self->param('from');
    my $date_to = $self->param('to');

    # get application path .../public/ path
    my $app_path = $self->app->home->rel_file('public/downloads/analyser');
    $self->app->log->debug("Application path: $app_path");

    # create a temp dir to store data files
    my $temp_path = tempdir('temp_XXXXX', DIR => $app_path);
    $self->app->log->debug("Temp path: $temp_path");

    # get times
    $self->app->log->debug("Formattazione date");
    my $tm = Time::Moment->now;
    my $head_time = $tm->strftime("{%Y%m%d_%H%M%S}");

    my $dateFromISO = $date_from;
    $dateFromISO =~ s/ /T/;
    $dateFromISO .= 'Z';
    $tm = Time::Moment->from_string($dateFromISO);
    $head_time .= '-' . $tm->strftime("[%Y%m%d");
    my $dateToISO = $date_to;
    $dateToISO =~ s/ /T/;
    $dateToISO .= 'Z';
    $tm = Time::Moment->from_string($dateToISO);
    $head_time .= '-' . $tm->strftime("%Y%m%d]");

    # build filename
    # my $csv_filename = '/Dati_'.$stid.'-'.$prid.'.csv';
    my $csv_filename = '/Dati_analyser_'.$head_time.'.csv';
    $csv_filename = encode_utf8( $csv_filename );
    my $full_csv_filename = $temp_path.'/'.$csv_filename;
    $self->app->log->debug("File csv : $full_csv_filename");

    my $header_rows = $self->dbdatamanager->get_csv_header($macro);

    # write header
    my $eco_file_header = '';

    # header
    my $file_header_station .= "Stazione: ";
    my $file_header_stid    .= "StId: ";
    my $file_header_quote   .= "Quota m s.l.m.: ";
    my $file_header_lat     .= "WGS84 lat: ";
    my $file_header_lon     .= "WGS84 lon: ";
    my $file_header_zone    .= "Zona: ";
    my $file_header_param   .= "Parametro: ";
    my $file_header_unit    .= "Unità misura: ";

    my $idx = 0;
    # loop through parameters
    $self->app->log->debug("Loop through stprid...");
    foreach my $row (@{$header_rows}) {

        my $station_name = $row->{'station_name'};
        $self->app->log->debug("Stazione: $station_name");

        my $parameter_name = $row->{'parameter_name'};
        my $parameter_unit = $row->{'parameter_unit'};
        $self->app->log->debug("Parametro: $parameter_name");

        my $lat = $row->{'station_lat_wgs84'};
        my $lon = $row->{'station_lon_wgs84'};

        $lat =~ s/\./,/g if looks_like_number($lat);
        $lon =~ s/\./,/g if looks_like_number($lon);

        # write header
        $file_header_station .= ";" . $station_name;
        $file_header_stid    .= ";" . $row->{'station_id'};
        $file_header_quote   .= ";" . $row->{'station_altitude'};
        $file_header_lat     .= ";" . $lat;
        $file_header_lon     .= ";" . $lon;
        $file_header_zone    .= ";" . $row->{'station_zone'};
        $file_header_param   .= ";" . $parameter_name;
        $file_header_unit    .= ";" . $params_array[$idx]->{'unit'};

        # index increment for parameter units array
        $idx++;
    } # foreach my $row (@{$data_rows})

    $eco_file_header .= $file_header_station . "\n";
    $eco_file_header .= $file_header_stid    . "\n";
    $eco_file_header .= $file_header_quote   . "\n";
    $eco_file_header .= $file_header_lat     . "\n";
    $eco_file_header .= $file_header_lon     . "\n";
    $eco_file_header .= $file_header_zone    . "\n";
    $eco_file_header .= $file_header_param   . "\n";
    $eco_file_header .= $file_header_unit    . "\n";

    my $data_rows = $self->dbdatamanager->get_csv_data_by_dates($date_from, $date_to, $hide_nulls, $macro);

    my $csv_rows = '';
    foreach my $row ( @{$data_rows} ) {

        my $csv_row = join(";", @{$row} );

        $csv_rows .= $csv_row ."\n";

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

    # create zip file to be downloaded
    # get zip filename
    $self->app->log->debug("File zip");
    my $zip_filename = "Dati_analyser_".$head_time.".zip";

    # get full zip filename
    my $full_zip_filename = $app_path.'/'.$zip_filename;
    $self->app->log->debug("Zip file: $full_zip_filename");

    # get new zip file object
    my $zip = Archive::Zip->new();

    # read temp dir
    opendir(DIR, $temp_path);
    #my @zipfiles = readdir(DIR);
    my @zipfiles = grep( !/^\./, readdir(DIR) );
    closedir(DIR);

    # add files to zip object
    foreach (@zipfiles) {
        $self->app->log->debug("Adding file [$_] ...");
        $zip->addFile( "$temp_path/$_", $_ ); # add files
    }

    # save zip object to file
    $self->app->log->debug("Save zip file to disk");
    if ($zip->writeToFileNamed($full_zip_filename) != AZ_OK) {
        $self->app->log->warning("Error in archive creation!");
    }
    else {
        $self->app->log->debug("Archive created successfully");
    }

    # delete temporary directory
    $self->app->log->debug("Delete temporary directory: $temp_path");
    rmtree($temp_path, {error => \my $err});
    if ($err && @$err) {
        for my $diag (@$err) {
            my ($file, $message) = %$diag;
            if ($file eq '') {
              $self->app->log->warning("General error: $message");
            }
            else {
              $self->app->log->warning("Problem unlinking $file: $message");
            }
        }
    }
    else {
        $self->app->log->debug("No error encountered");
    }

    # last check
    $self->app->log->debug("Check zip file exists");
    if (-e $full_zip_filename) {
        # Open file in browser(do not show save dialog)
        $self->app->log->debug("Render file back to browser");

        $self->render_file(
            'filepath' => $full_zip_filename,
            'format'   => 'zip',                   # will change Content-Type "application/x-download" to "application/pdf"
            'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
            'cleanup' => 0,                        # delete file after completed
        );

    }
    else {
        $self->app->log->error("Error. Zip file DOES NOT exists!");

        my $json = {
            res  => 'ERROR',
            desc => "Errore durante lo scarico dei dati."
        };
        # final render
        $self->render(json => $json);
    }
}

sub put_analyser_user_options {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub put_analyser_user_options");

    $self->helperDumperPostData('Analyser', 'put_analyser_user_options', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;
    my $options = $params->{'options'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    if (defined $self->dbanalyser->get_analyser_user_options($user_id)) {
        $res = $self->dbanalyser->update_options($user_id, $options);
    }
    else {
        $res = $self->dbanalyser->insert_options($user_id, $options);
    }

    # $self->helperDumper( $data );
    my $json;

    if (defined $res) {
        $json = 1;
    }
    else {
        $json = 0;
    }

    # render
    $self->render(json => $json);
}

sub put_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub put_categories");

    $self->helperDumperPostData('Analyser', 'put_category', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;
    $self->helperDumper( $params );

    my $cat_id = $params->{'new-cat-id'};
    my $user_id = $self->session('it.ecometer.bobo');

    my $res = 1;

    # store action to audit table
    my $table = 'analyser';

    if (defined $cat_id && $cat_id ne "") {
        $self->helperInsertUserLog( 'EDIT CAT', $table, encode_json($params));
        $res = $self->dbanalyser->update_category($params);
    }
    else {
        $self->helperInsertUserLog( 'INSERT CAT', $table, encode_json($params));
        $cat_id = $self->dbanalyser->insert_category($user_id, $params);
    }

    # $self->helperDumper( $data );
    my $json;

    $self->app->log->debug("$res");
    # $self->app->log->debug("$cat_id");

    if (defined $res && defined $cat_id) {
        $json = {
            res => "OK",
            cat_id => $cat_id
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

sub put_macro {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub put_macro");
    $self->helperDumperPostData('Analyser', 'put_macro', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;

    my $macro_id = $params->{'mcid'};
    my $macro = $params->{'macro'};
    my $macro_cat = $params->{'mccat'};
    my $res = 1;

    # store action to audit table
    my $table = 'analyser';

    if (defined $macro_id && $macro_id ne "") {
        $self->helperInsertUserLog( 'EDIT MACRO', $table, encode_json($params));
        $res = $self->dbanalyser->update_macro($macro_id, $macro_cat, $macro);
    }
    else {
        $self->helperInsertUserLog( 'INSERT MACRO', $table, encode_json($params));
        # associates the new macro with the default category
        $macro_id = $self->dbanalyser->insert_macro($macro_cat, $macro);
    }

    # $self->helperDumper( $data );
    my $json;
    $self->app->log->debug("$res");
    $self->app->log->debug("$macro_id");

    if (defined $res && defined $macro_id) {
        $json = {
            res => "OK",
            macro_id => $macro_id
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

sub put_macro_duplication {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub put_macro_duplication");
    $self->helperDumperPostData('Analyser', 'put_macro_duplication', $self->req->body_params);

    my $macro_id = $self->param('id'); # post

    $self->app->log->debug("Macro id: $macro_id");

    my $res = $self->dbanalyser->insert_macro_duplication($macro_id);

    # render
    $self->render(json => $res);
}

sub del_category {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub del_category");
    $self->helperDumperPostData('Analyser', 'del_category', $self->req->body_params);

    my $params  = $self->req->body_params->to_hash;

    my $cat_id = $self->param('id');
    my $res = 1;

    # store action to audit table
    my $table = 'analyser';
    $self->helperInsertUserLog('DELETE CAT', $table, encode_json($params));

    # delete macro
    $res = $self->dbanalyser->delete_category($cat_id);

    my $json;
    $self->app->log->debug("$res");

    if ($res == 1) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

sub del_macro {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Analyser sub del_macro");
    $self->helperDumperPostData('Analyser', 'del_macro', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $macro_id = $self->param('mcid');
    my $res = 1;

    # store action to audit table
    my $table = 'analyser';
    $self->helperInsertUserLog('DELETE MACRO', $table, encode_json($params));

    # delete macro
    $res = $self->dbanalyser->delete_macro_byid($macro_id);

    my $json;
    $self->app->log->debug("$res");
    $self->app->log->debug("$macro_id");

    if (defined $res) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 analyser

Render della pagina dell'applicativo Analyser.

Argomenti:  /

Return:     /

=cut

=head1 get_analyser_options

Funzione per recuperare le impostazioni, generiche e personalizzate di un determinato utente,
dello strumento Analyser.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli oggetti delle relative impostazioni, generiche e dell'utente loggato.

=cut

=head1 get_categories

Funzione per recuperare le categorie di macro visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e le categorie, oppure la risposta "ERR".

=cut

=head1 get_category_byid

Funzione per recuperare una determinata categoria.

Argomenti:  * id della categoria ('cat_id');

Return:     json contenente la risposta "OK" e le categorie, oppure la risposta "ERR".

=cut

=head1 get_analyser_groups

Funzione per recuperare i gruppi di macro visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente i gruppi, oppure un oggetto indicante 'Nessun sottogruppo'.

=cut

=head1 get_group_stations

Funzione per recuperare le stazioni appartenenti ad un determinato gruppo visibile dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

           * id del gruppo ('grid');

           * id del nodo ('nodeid');

           * oggetto contenente le impostazioni dell'albero delle stazioni ('options');

Return:     json contenente le stazioni, oppure un oggetto indicante 'Nessuna stazione presente'.

=cut

=head1 get_station_params

Funzione per recuperare i parametri associati ad una determinata stazione.

Argomenti:  * id della stazione ('stid');

           * id del nodo ('nodeid');

           * oggetto contenente le impostazioni dell'albero delle stazioni ('options');

Return:     json contenente i parametri, oppure un oggetto vuoto.

=cut

=head1 get_params_type

Funzione per recuperare i parametri associati ad una determinata stazione raggruppati
in una determinata tipologia.

Argomenti:  * id della stazione ('stid');

           * tipologia di parametro ('type');

           * id del nodo ('nodeid');

           * oggetto contenente le impostazioni dell'albero delle stazioni ('options');

Return:     json contenente i parametri raggruppati per tipologia, oppure un oggetto vuoto.

=cut

=head1 get_groups

Funzione per recuperare i gruppi di macro visibili dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i gruppi, oppure un oggetto indicante 'Nessuna categoria presente'.

=cut

=head1 get_group_macros

Funzione per recuperare le macro appartenenti ad un determinato gruppo visibile dall'utente loggato.

Argomenti:  * id del gruppo ('grid');

           * id del nodo ('nodeid');

           * oggetto contenente le impostazioni dell'albero delle macro ('options');

Return:     json contenente le macro, oppure un oggetto vuoto.

=cut

=head1 get_macro_params

Funzione per recuperare i parametri associati ad una determinata macro.

Argomenti:  * id della macro ('macroid');

           * id del nodo ('nodeid');

Return:     json contenente i parametri, oppure un oggetto vuoto.

=cut

=head1 get_macro_metadata

Funzione per recuperare i metadati relativi ad una determinata macro.

Argomenti:  * id della macro ('mcid');

Return:     json contenente la risposta "OK", i metadati e la macro, oppure la risposta "ERR".

=cut

=head1 get_param_info

Funzione per recuperare le informazioni relative ad un determinato
parametro associato ad una determinata stazione.

Argomenti:  * id della associazione stazione-parametro ('stprid');

           * valore booleano per la conversione del parametro ('conv');

Return:     json contenente la risposta OK e le informazioni relative al parametro.

=cut

=head1 get_limit_info

Funzione per recuperare le informazioni relative ad un determinato limite.

Argomenti:  * id del limite ('lmid');

Return:     json contenente la risposta OK e le informazioni relative al limite.

=cut

=head1 get_wind_scale

Funzione per recuperare una determinata scala di vento.

Argomenti:  * id della scala di vento ('scaleid');

Return:     json contenente la risposta OK e le informazioni relative alla scala di vento.

=cut

=head1 get_highcharts_data_bydate

Funzione per recuperare i dati necessari alla generazione del grafico Highcharts
di una determinata macro relativi ad un determinato periodo temporale.

Argomenti:  * oggetto macro ('macro');

           * valore booleano che indica se nascondere o meno i valori nulli ('hide_nulls');

           * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano che indica se sono presenti o meno delle note ('flag_notes');

Return:     json contenente la risposta "OK", i dati, la query Highcharts e le eventuali note, oppure la risposta "ERR".

=cut

=head1 get_highcharts_data_per_year

Funzione per recuperare i dati necessari alla generazione del grafico Highcharts
di una determinata macro relativi ad un determinato periodo temporale, visualizzato per anno.

Argomenti:  * oggetto macro ('macro');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     json contenente la risposta "OK", i dati e la query Highcharts, oppure la risposta "ERR".

=cut

=head1 get_windrose_data

Funzione per recuperare i dati necessari alla generazione della rosa dei venti
di una determinata stazione relativa ad un determinato periodo temporale.

Argomenti:  * oggetto contenente le informazioni necessarie alla generazione del grafico ('params');

Return:     json contenente la query, la percentuale di calma di vento, la scala e i dati, oppure la risposta "ERR".

=cut

=head1 get_tabulator_data

Funzione per recuperare i dati necessari alla generazione della tabella dei dati
di una determinata macro relativi ad un determinato periodo temporale.

Argomenti:  * oggetto macro ('macro');

           * valore booleano che indica se nascondere o meno i valori nulli ('hide_nulls');

           * data d'inizio ('dateFrom');

           * data di fine ('dateTo');

Return:     json contenente la risposta "OK", i dati e la query, oppure la risposta "ERR".

=cut

=head1 get_csv_data

Funzione per recuperare i dati necessari alla generazione del file in formato '.csv' dei dati
di una determinata macro relativi ad un determinato periodo temporale.

Argomenti:  * oggetto macro ('macro');

           * array dei parametri della macro ('params_array');

           * valore booleano che indica se nascondere o meno i valori nulli ('hide_nulls');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

Return:     download del file dati in formato '.csv', oppure json contenente la risposta "ERR" e ul messaggio "Errore durante lo scarico dei dati.".

=cut

=head1 put_analyser_user_options

Funzione per salvare le impostazioni utente personalizzate all'interno del database.

Argomenti:  * oggetto contenente le impostazioni utente ('params');

           * id dell'utente ('user_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_category

Funzione per modificare/inserire una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da modificare/inserire ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e l'id della categoria modificata/inserita,
            oppure la risposta "ERR".

=cut

=head1 put_macro

Funzione per modificare/inserire una macro.

Argomenti:  * oggetto contenente le informazioni relative alla macro
              da modificare/inserire ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e l'id della macro modificata/inserita,
            oppure la risposta "ERR".

=cut

=head1 put_macro_duplication

Funzione per duplicare una macro.

Argomenti:  * id della macro ('macro_id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_category

Funzione per eliminare una categoria.

Argomenti:  * oggetto contenente le informazioni relative alla categoria
              da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_macro

Funzione per eliminare una macro.

Argomenti:  * oggetto contenente le informazioni relative alla macro
              da eliminare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut