package Bobo::Controller::Anagrafica;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Net::FTP;
use Mojo::JSON qw(decode_json encode_json);
# use Mojo::File qw(path);

sub strumenti {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Anagrafica sub strumenti");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    my $infos = $self->dbanagrafica->get_instruments_types_info();
    $self->stash(infos => $infos);

    my $types = $self->dbcnfstrumenti->get_instruments_types();
    $self->stash(types => $types);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($userid);
    $self->stash(provinces => $provinces);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # render
    $self->render('anagrafica/strumenti');
}

sub stazioni {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Anagrafica sub stazioni");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    my $instrs = $self->dbcnfstrumenti->get_instruments_types();
    $self->stash(instrs => $instrs);

    my $params = $self->dbadmin->get_all_parameters();
    $self->stash(params => $params);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($userid);
    $self->stash(provinces => $provinces);

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # render
    $self->render('anagrafica/stazioni');
}

sub get_parameters {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Anagrafica sub get_parameters");

    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post
    my $params = decode_json($self->param('params')); # post

    my $user_id = $self->session('it.ecometer.bobo');

    # get parameters
    my $parameters = $self->dbanagrafica->get_parameters_by_id($user_id, $net, $prov, $params);

    my $json;

    # check result
    if (defined $parameters) {
        $json = {
            res => "OK",
            parameters => $parameters
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

sub get_operations {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Anagrafica sub get_operations");

    my $instr = $self->param('instr'); # post
    # log
    $self->app->log->debug($instr);

    # get operations
    my $operations = $self->dbanagrafica->get_operations_by_id($instr);
    # my $operations = 1;

    my $json;

    # check result
    if (defined $operations) {
        $json = {
            res => "OK",
            operations => $operations
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
    $self->app->log->debug("Bobo::Controller::Anagrafica sub get_instruments");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $types = decode_json($self->param('types')); # post
    my $net = $self->param('net'); # post
    my $prov = $self->param('prov'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID strumenti: ". \@{$types});

    my $user_id = $self->session('it.ecometer.bobo');
    my $instruments;

    # get instruments
    $instruments = $self->dbanagrafica->get_instruments_by_types($user_id, $from, $to, $net, $prov, $types);

    my $json;

    # check result
    if (defined $instruments) {
        $json = {
            res => "OK",
            instruments => $instruments
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

sub get_station_equipments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Anagrafica sub get_station_equipments");

    my $stid = $self->param('stid'); # post
    my $flag = $self->param('flag'); # post

    $self->app->log->debug("Stazione: $stid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $from;
    my $to;
    if($flag eq 'true'){
        $from = $self->helperGetLocaleFullDate();
        $to = $self->helperGetLocaleFullDate();
    }
    else{
        $from = '-infinity';
        $to = 'infinity';
    }

    # get equipments
    my $instruments = $self->dbcnfstrumenti->get_instruments_by_date_station($user_id, $from, $to, -1, $stid, -1);
    my $cylinders = $self->dbcnfbombole->get_cylinders_by_date_station($user_id, $from, $to, -1, $stid);
    my $miscellanies = $self->dbcnfdotazioni->get_miscellanies_by_date_station($user_id, $from, $to, $stid);

    my $json;

    # check result
    if (
        defined $instruments &&
        defined $cylinders   &&
        defined $miscellanies
    ) {
        $json = {
            res => "OK",
            instruments  => $instruments,
            cylinders    => $cylinders,
            miscellanies => $miscellanies
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

1;

=head1 strumenti

Render della pagina di anagrafica degli strumenti.

Argomenti:  /

Return:     /

=cut

=head1 stazioni

Render della pagina di anagrafica delle stazioni.

Argomenti:  /

Return:     /

=cut

=head1 get_parameters

Funzione per recuperare tutti i parametri disponibili sul portale, eventualmente
filtrati per tipologia, rete e provincia.

Argomenti:  * id della rete ('net');

           * id della provincia ('prov');

           * oggetto contenente le tipologie di parametro ('params');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i parametri, oppure la risposta "ERR".

=cut

=head1 get_instruments

Funzione per recuperare tutti gli strumenti disponibili sul portale, eventualmente
filtrati per tipologia, rete e provincia.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente le tipologie di strumento ('types');

           * id della rete ('net');

           * id della provincia ('prov');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e gli strumenti, oppure la risposta "ERR".

=cut

=head1 get_station_equipments

Funzione per recuperare le informazioni relative agli strumenti, alle bombole e alle dotazioni presenti in
una determinata stazione.

Argomenti:  * id della stazione ('stid');

Return:     json contenente le informazioni relative agli strumenti, le bombole e le dotazioni presenti in stazione.

=cut