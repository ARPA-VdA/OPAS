package Bobo::Controller::Common;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub get_provinces {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_provinces");

    my $region = $self->param('region'); # post
    $self->app->log->debug("ID regione: $region");

    # get stations from province
    my $provinces = $self->dbcommon->get_all_provinces_by_region($region);

    my $json = {
        res => "OK",
        provinces => $provinces
    };

    # render
    $self->render(json => $json);
}

sub get_municipalities {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_municipalities");

    my $province = $self->param('province'); # post
    $self->app->log->debug("ID provincia: $province");

    # get stations from province
    my $municipalities = $self->dbcommon->get_all_municipalities_by_province($province);

    my $json = {
        res => "OK",
        municipalities => $municipalities
    };

    # render
    $self->render(json => $json);
}

sub get_municipality_by_coords {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_municipality_by_coords");

    my $lon = $self->param('lon'); # post
    my $lat = $self->param('lat'); # post

    # get stations from province
    my $municipality = $self->dbcommon->get_municipality_by_coordinates($lon, $lat);

    my $json = {
        res => "OK",
        municipality => $municipality
    };

    # render
    $self->render(json => $json);
}

sub get_stations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_stations");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    $self->app->log->debug("ID provincia: $prid");

    # get stations from province
    my $stations = $self->dbcommon->get_stations_by_province($user_id, $prid);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_stations_by_net_province {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_stations_by_nets");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    my $net = $self->param('net');

    # get stations from province
    my $stations = $self->dbcommon->get_stations_by_net_province($user_id, $net, $prid);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_stations_by_nets {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_stations_by_nets");

    my $user_id = $self->session('it.ecometer.bobo');

    my $prid = $self->param('prid'); # post
    my $nets = decode_json($self->param('nets'));

    $self->app->log->debug("ID provincia: $prid");
    $self->app->log->debug("Networks:". \@{$nets});

    # get stations from province
    my $stations = $self->dbcommon->get_stations_by_nets($user_id, $prid, $nets);

    my $json = {
        res => "OK",
        stations => $stations
    };

    # render
    $self->render(json => $json);
}

sub get_parameters {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_parameters");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    # get stations from province
    my $params = $self->dbcommon->get_all_parameters_by_station($stid);

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_codes {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_codes");

    my $user_id = $self->session('it.ecometer.bobo');

    # get periphery validation codes sent by an ajax call
    my $periphery = $self->dbcommon->get_periphery();

    # get auto validation codes sent by an ajax call
    my $autoval = $self->dbcommon->get_autoval();

    # get user validation codes sent by an ajax call
    my $userval = $self->dbcommon->get_validation_codes();

    # get final validation codes sent by an ajax call
    my $finalval = $self->dbcommon->get_final_validation_codes($user_id);

    my $json = {
        res => "OK",
        periphery => $periphery,
        autoval   => $autoval,
        userval   => $userval,
        finalval  => $finalval
    };

    # render
    $self->render(json => $json);
}

sub get_station_data {
    my $self = shift;

    # render
    $self->app->log->debug("Bobo::Controller::Common sub get_station_data");

    my $station_id = $self->param('stid'); # post
    my $pr_id = $self->param('prid'); # post
    my $date_from = $self->param('dateFrom'); # post
    my $date_to = $self->param('dateTo'); # post

    my $data = $self->dbdatamanager->get_data_by_param($station_id, $pr_id, $date_from, $date_to);

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
            res => 'Error',
            message => 'Errore nel recupero dei dati'
        };
    }

    # render
    $self->render(json => $json)
}

sub get_station_data_by_stprid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_station_data_by_stprid");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $params = $self->param('params');
    $params = decode_json(encode_utf8($params)); # post

    $self->app->log->debug("Data inizio: $from, data fine: $to");
    $self->app->log->debug("ST PR ID: $from, data fine: $to");

    # get data from dateFrom to dateTo
    my $json;
    my $data = $self->dbdatamanager->get_data_by_stprid($from, $to, $params);

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

    # render
    $self->render(json => $json);
}

sub get_instruments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Common sub get_instruments");

    my $stid = $self->param('stid'); # post
    $self->app->log->debug("ID stazione: $stid");

    my $dt = $self->param('dt'); # post
    $self->app->log->debug("data e ora: $dt");

    # get instruments from station
    my $instruments = $self->dbcommon->get_instruments_by_station_date($stid, $dt);

    my $json = {
        res => "OK",
        instruments => $instruments
    };

    # render
    $self->render(json => $json);
}

1;

=head1 get_provinces

Funzione per recuperare le province di una determinata regione.

Argomenti:  * id della regione ('region');

Return:     json contenente le province e il messaggio "OK";

=cut

=head1 get_municipalities

Funzione per recuperare i comuni di una determinata provincia.

Argomenti:  * id della provincia ('province');

Return:     json contenente i comuni e il messaggio "OK";

=cut

=head1 get_municipality_by_coords

Funzione per recuperare, date le coordinate, un determinato comune.

Argomenti:  * longitudine ('lon');

           * latitudine ('lat');

Return:     json contenente il comune e il messaggio "OK";

=cut

=head1 get_stations

Funzione per recuperare le stazioni di una determinata provincia.

Argomenti:  * id della provincia ('prid');

Return:     json contenente le stazioni e il messaggio "OK";

=cut

=head1 get_stations_by_net_province

Funzione per recuperare le stazioni di una determinata provincia in una determinata rete.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia ('prid');

           * id della rete ('net');

Return:     json contenente le stazioni e il messaggio "OK";

=cut

=head1 get_stations_by_nets

Funzione per recuperare le stazioni di una determinata provincia in una o piu' reti.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia ('prid');

           * array delle reti ('nets');

Return:     json contenente le stazioni e il messaggio "OK";

=cut

=head1 get_parameters

Funzione per recuperare tutti i parametri di una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente i parametri e il messaggio "OK";

=cut

=head1 get_codes

Funzione per recuperare i vari codici di validazione.

Argomenti:  /

Return:     json contenente i codici e il messaggio "OK";

=cut

=head1 get_station_data

Funzione per recuperare i dati di una determinata stazione di un determinato parametro
in un determinato periodo temporale.

Argomenti:  * id della stazione ('stid');

           * id del parametro ('prid');

           * data d'inizio ('dateFrom');

           * data di fine ('dateTo');

Return:     se presenti: json contenente i dati e il messaggio "OK"

           altrimenti: json di errore;

=cut

=head1 get_station_data_by_stprid

Funzione per recuperare i dati di determinati parametri associati ad una stazione
in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * array dei parametri ('params');

Return:     se presenti: json contenente i dati e il messaggio "OK"

           altrimenti: json di errore;

=cut

=head1 get_instruments

Funzione per recuperare gli strumenti presenti in una determinata stazione in un determinata data.

Argomenti:  * id della stazione ('stid');

           * data e ora ('dt');

Return:     json contenente gli strumenti e il messaggio "OK";

=cut