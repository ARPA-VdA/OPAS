package Bobo::Controller::Cnfparametri;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use File::Basename;

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

use Mojo::File 'path';

use utf8;

sub parametri {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($userid);
    $self->stash(networks => $networks);

    # get all parameters
    my $params = $self->dbadmin->get_all_parameters();
    $self->stash(params => $params);

    # get station measures cadence
    my $measures_cadences = $self->dbcnfstazioni->get_measures_cadences();
    $self->stash(measures_cadences => $measures_cadences);

    # get parameters type
    my $types = $self->dbangparametri->get_parameters_types();
    $self->stash(types => $types);

    # Render template "utilities/faq.html.ep" with message
    $self->render('impostazioni/parametri');
    # @ALE
    # $self->render('impostazioni/stazioni_v2');
}

sub get_parameters_by_stid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub get_parameters_by_stid");

    my $stid = $self->param('stid'); # post
    my $type = $self->param('type'); # post
    $self->app->log->debug("ID stazione: $stid");
    $self->app->log->debug("Tipo parametro: $type");

    my $params = $self->dbcnfparametri->get_parameters_by_stid($stid, $type);

    my $json = {
        res => "OK",
        params => $params
    };

    # render
    $self->render(json => $json);
}

sub get_parameter_by_stprid {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub get_parameter_by_stprid");

    my $stprid = $self->param('stprid'); # post
    $self->app->log->debug("STPRID: $stprid");

    my $parameter = $self->dbcnfparametri->get_parameter($stprid);

    my $json = {
        res => "OK",
        parameter => $parameter
    };

    # render
    $self->render(json => $json);
}

sub put_station_param {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub put_station_param");
    $self->helperDumperPostData('Parametri', 'put_station_param', $self->req->body_params);

    my $param = $self->req->body_params->to_hash;
    $self->app->log->debug(Dumper($param));

    my $res = $self->dbcnfparametri->update_station_parameter($param);

    # check result
    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => $res);
    }
}

sub put_config_file {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub put_config_file");

    my $params = $self->req->body_params->to_hash;
    my $stid = $params->{'station-id'};

    my $file_base_dir = 'uploads/impostazioni/stazioni/'.$stid;
    my $file_dir = $self->app->static->paths->[0].'/'.$file_base_dir;
    $self->helperCreatePath($file_dir);

    my $files = $self->req->uploads('files');

    my $file_content;
    my $params_array;
    my $json;

    eval {
        if (scalar @{$files} > 0) {
            # my $rpid_file = sprintf("%09d", $rpid);
            # $self->app->log->debug( "rpid_file: $rpid_file" );
            # my $file_base_dir = 'uploads/report/rendiconto/'.$rpid_file;
            # my $file_dir = $self->app->static->paths->[0].'/'.$file_base_dir;
            # $self->helperCreatePath( $file_dir );

            my $file = @{$files}[0];

            my $original_name = $file->filename;
            $self->app->log->debug("original_name: $original_name");
            my $field_name = $file->name;
            $self->app->log->debug("field name: $field_name");

            my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

            my $file_name = $self->helperFileUploadGetFileId() . $p_ext;
            my $full_file_name = $file_dir."/".$file_name;

            $file->move_to($full_file_name);

            open(FH, '<:encoding(UTF-8)', $full_file_name) or die $!;

            # Chomp removes the current "input record separator", which can be changed by editing one of the built-in perl variables
            $/ = "\r\n";

            # remove \r\n
            chomp(my @lines = <FH>);
            $file_content = join('', @lines);

            $params_array = $self->dbcnfparametri->get_parameters_from_config($file_content);

            close(FH);
        }
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);

        $json = {
            res => 'ERR'
        };
    }
    else {
       $json = {
           res => 'OK',
           config => decode_json(encode_utf8($file_content)),
           params => $params_array
       };
    }

    # render
    $self->render(json => $json);
}

sub put_config_params {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub put_config_params");
    $self->helperDumperPostData('Parametri', 'put_config_params', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    my $stid = $params->{'stid'};

    my $new = decode_json(encode_utf8($params->{'new'}));
    my $disabled = decode_json($params->{'disabled'});

    my $res = -1;

    if (scalar @{$new} > 0) {
        $self->app->log->debug("Add new parameters to station $stid");

        $res += $self->dbcnfparametri->insert_station_parameters($stid, $new);
        # $res += 1;
    }
    else {
        $res++;
    }

    if (scalar @{$disabled} > 0) {
        $self->app->log->debug("Disable parameters from station $stid");

        $res += $self->dbcnfparametri->update_station_parameters_status($disabled);
    }
    else {
        $res++;
    }

    # render
    $self->render(json => $res);
}

sub del_station_param {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Cnfparametri sub del_station_param");
    $self->helperDumperPostData('Parametri', 'del_station_param', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $stprid = $self->param('id'); # post

    $self->app->log->debug("Param ID: $stprid");

    # store action to audit table
    # my $table = 'rep_qamaintenances';
    # $self->helperInsertUserLog('DELETE', $table, encode_json($params));

    my $res = $self->dbcnfparametri->delete_param_by_stprid($stprid);
    # my $res = 1;

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

1;

=head1 parametri

Render della pagina di anagrafica dei parametri.

Argomenti:  /

Return:     /

=cut

=head1 get_parameters_by_stid

Funzione per recuperare, dato l'id di una stazione e quello della tipologia richiesta,
i relativi parametri associati.

Argomenti:  * id della stazione ('stid');

           * id della tipologia di parametro ('type');

Return:     json contenente la risposta "OK", e i vari parametri.

=cut

=head1 get_parameter_by_stprid

Funzione per recuperare, dato l'id dell'associazione stazione-parametro, le informazioni relative
al parametro.

Argomenti:  * id dell'associazione stazione-parametro ('stprid');

Return:     json contenente la risposta "OK" e i vari parametri.

=cut

=head1 put_station_param

Funzione per modificare le informazioni di una determinata stazione.

Argomenti:  * oggetto contenente le informazioni del parametro ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_config_file

Funzione per recuperare le informazioni relative ai parametri di una stazione caricando sul portale
il relativo file di configurazione presente in periferia.

Argomenti:  * oggetto contenente le informazioni relative alla stazione ed al file di configurazione associato ('params');

Return:     json contenente la risposta "OK", la configurazione di stazione e l'array dei parametri, oppure la risposta "ERR".

=cut

=head1 put_config_params

Funzione per inserire/modificare le informazioni relative ai parametri di una stazione, partendo dal relativo file di configurazione presente in periferia.

Argomenti:  * oggetto contenente le informazioni relative alla stazione ed ai parametri da inserire/modificare ('params');

Return:     json contenente la risposta dell'inserimento/della modifica.

=cut

=head1 del_station_param

Funzione per eliminare un determinato parametro da una determinata stazione.

Argomenti:  * oggetto contenente le informazioni del parametro (per tabella di audit) ('params');

           * id dell'associazione stazione-parametro ('stprid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut