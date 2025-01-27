package Bobo::Model::DbcnfParametri;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

use Data::Dumper;

use utf8;

has 'pg';
has 'app';

sub get_parameters_by_stid {
    my ( $self, $stid, $type ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub get_parameters_by_stid");

    $type = ($type != -1 ? "^$type\$": ".*");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_table_id,
            sp.stpr_id      ,
            p.param_id      ,
            sp.stpr_group_id,
            p.param_name,
            sp.stpr_note,
            p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS parameter_name,
            p.param_unit                  ,
            sp.stpr_active                ,
            p.param_conv                  ,
            p.param_unit_conv             ,
            p.param_offset                ,
            CASE
                WHEN p.param_conv = 0 THEN 'y='||COALESCE(p.param_offset::text, '0')
                WHEN p.param_conv = 1 THEN 'y=x'||COALESCE('+'||p.param_offset::text, '')
                ELSE 'y='||p.param_conv||'*x'||COALESCE('+'||p.param_offset::text, '')
            END                             AS parameter_formule,
            pm.pm_info_type_fk              AS parameter_type_id,
            pt.pm_type_desc                 AS parameter_type_desc,
            pt.pm_type_icon                 AS parameter_type_icon,
            pt.pm_type_colour               AS parameter_type_colour,
            spi.stpr_info_cadence_fk,
            mc.measure_cadence_desc,
            sps.stpr_custom_export_publish  AS stpr_export_publish,
            spi.stpr_export_id1             AS stpr_export_id_1,
            spi.stpr_export_id2             AS stpr_export_id_2,
            ARRAY_REMOVE(ARRAY[spi.stpr_export_id1, spi.stpr_export_id2], NULL)
                                            AS stpr_export_ids

        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.stations_params_status sps USING (stpr_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pm USING (param_id)
            LEFT JOIN metadata.parameters_type pt ON pm.pm_info_type_fk = pt.pm_type_id
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.measures_cadence mc ON COALESCE(spi.stpr_info_cadence_fk, si.st_info_cadence_fk) = mc.measure_cadence_id

        WHERE
            station_id = ?
            AND pm.pm_info_type_fk::text ~ ?
        ORDER BY
            sp.stpr_table_id;
    };

    # return
    return $self->pg->db->query($sql, $stid, $type)->hashes();
}

sub get_parameters_from_config {
    my ( $self, $file ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub get_parameters_from_config");

    # query
    my $sql = qq{
        SELECT metadata.f_get_parameters_from_station_config_v2( ( ? ):: jsonb ) AS params_obj;
    };

    # return
    return $self->pg->db->query($sql,decode_utf8(encode_json(decode_json($file))))->hash->{'params_obj'};
}

sub get_parameter {
    my ( $self, $stprid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub get_parameter");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id,
            sp.station_id,
            p.param_id,
            sp.stpr_table_id,
            p.param_name,
            p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text) AS parameter_fullname,
            sp.stpr_active,
            sps.stpr_suspended,
            sps.stpr_ws_publish,
            sps.stpr_dataview_publish,
            sps.stpr_custom_export_publish,
            sp.stpr_ext_id,
            TO_CHAR(sp.stpr_startup_date, 'DD/MM/YYYY') AS stpr_startup_date,
            TO_CHAR(sp.stpr_dismiss_date, 'DD/MM/YYYY') AS stpr_dismiss_date,
            spi.stpr_info_cadence_fk,
            mc.measure_cadence_desc,
            p.param_unit                    AS parameter_unit,
            p.param_conv,
            p.param_unit_conv               AS parameter_unit_conv,
            p.param_offset                  AS parameter_offset,
            CASE
                WHEN p.param_conv = 0 THEN 'y='||COALESCE(p.param_offset::text, '0')
                WHEN p.param_conv = 1 THEN 'y=x'||COALESCE('+'||p.param_offset::text, '')
                ELSE 'y='||p.param_conv||'*x'||COALESCE('+'||p.param_offset::text, '')
            END                             AS parameter_formule,
            p.param_decimals                AS parameter_decimals,
            p.param_active                  AS parameter_active,
            NULL::integer                   AS pollutant_id,
            pm.pm_info_shortname            AS parameter_shortname,
            pm.pm_info_extra_shortname      AS parameter_extra_shortname,
            pm.pm_info_type_fk              AS parameter_type_id,
            pt.pm_type_desc                 AS parameter_type_desc,
            pm.pm_info_obj                  AS parameter_object,
            sp.stpr_note,
            p.param_note                    AS parameter_note,
            pm.pm_info_note                 AS parameter_meta_note,
            spi.stpr_export_id1,
            spi.stpr_export_id2,
            spi.stpr_info_ws_id,
            spi.stpr_import_ws_id,
            sp.stpr_group_id

        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
            LEFT JOIN metadata.stations_params_status sps USING (stpr_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pm USING (param_id)
            LEFT JOIN metadata.parameters_type pt ON pm.pm_info_type_fk = pt.pm_type_id
            LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = spi.stpr_info_cadence_fk

        WHERE
            sp.stpr_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $stprid)->hash;
}

sub insert_station_parameters {
    my( $self, $stid, $new ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub insert_station_parameters");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        my $module;
        my $group_id;
        my $sql;

        for my $param (@{$new}) {
            # {
            #     "id":4028,
            #     "name":"[CC] Ben Zero",
            #     "prid":524,
            #     "unit":"ppb",
            #     "daily":false,
            #     "module":3,
            #     "need-group":true,
            #     "groupid":354
            # }

            $self->app->log->debug(Dumper($param));

            # check if parameter need a stpr_group_id
            if ($param->{'need-group'}) {
                $self->app->log->debug("Parameter need group ID!");

                # parameter acquired from a different module than the previous parameter
                if($module != $param->{'module'}){
                    $self->app->log->debug("Parameter acquired from a different module than the previous parameter");

                    # check if there is another parameter of the same module
                    # that has already obtained a group id
                    if (defined $param->{'groupid'} && $param->{'groupid'} ne '') {
                        $self->app->log->debug("There is another parameter of the same module that has already obtained a group id");

                        $group_id = $param->{'groupid'};
                    }
                    else {
                        $self->app->log->debug("Get NEXT id from group ID sequence");

                        # get NEXT id from group ID sequence
                        $sql = qq{ SELECT nextval('metadata.stations_parameters_stpr_group_id_seq') AS group_id; };
                        $group_id = $self->pg->db->query($sql)->hash->{group_id};
                    }
                }
                # else do nothing
                # parameter acquired from the same module of previous parameter
                # no need to update group id
            }
            else {
                $group_id = undef;
            }

            $self->app->log->debug("GROUP ID: ".$param->{'groupid'});

            # ##################################################################
            # 1- inserimento stazione parametro
            # ##################################################################
            $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 1: insert into stations_parameters and return stpr_id...");

            my $stprid = $self->pg->db->insert('metadata.stations_parameters', {
                station_id        => $stid,
                stpr_table_id     => $param->{'id'},
                param_id          => $param->{'prid'},
                stpr_group_id     => $group_id,
                stpr_active       => 1,
                stpr_note         => $self->app->helperEscapeParam($param->{'note'}),
                stpr_startup_date => $self->app->helperGetLocaleFullDate()
            }, { returning => 'stpr_id' })->hash->{stpr_id};

            $self->app->log->debug("STPR ID: $stprid");

            # ##################################################################
            # 2- modifica stazione parametro info
            # ##################################################################
            $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 2: take care of daily cadence and do insert into stations_params_info");

            # if it is a daily parameter then add row in the stations_params_info table
            if ($param->{'daily'}) {
                $self->pg->db->insert('metadata.stations_params_info', {
                    stpr_id              => $stprid,
                    stpr_info_cadence_fk => 8 # daily
                });
            }

            # update module with the current one
            $module = $param->{'module'};
        };

        # ##################################################################
        # 3 - creazione vista CC
        # ##################################################################
        $sql = qq{ SELECT template.f_create_cc_view(?::integer); };
        $self->pg->db->query($sql, $stid);

    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return 0;
    }
    else {
       $tx->commit;
       return 1;
    }
}

sub update_station_parameter {
    my( $self, $param ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub update_station_parameter");

    # {
    #   'param-ws-active' => 'on',
    #   'param-active' => 'on',
    #   'param-prid' => '47',
    #   'param-export-active' => 'on',
    #   'param-tableid' => '39',
    #   'param-exportid-1' => '321',
    #   'param-cadence' => '5',
    #   'param-stprid' => '93',
    #   'param-exportid-2' => '123',
    #   'param-importid' => 'WS123',
    #   'param-note' => 'Fidas test',
    #   'param-external-id' => '123XX',
    #   'param-startup-date' => '01/01/2019',
    #   'param-ws-id' => '456'
    # };

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- modifica stazione parametro
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 1");

        $self->pg->db->update('metadata.stations_parameters', {
            stpr_table_id     => $param->{'param-tableid'},
            param_id          => $param->{'param-prid'},
            stpr_active       => $self->app->helperGetBoolean($param, 'param-active'),
            stpr_note         => $self->app->helperEscapeParam($param->{'param-note'}),
            stpr_startup_date => $self->app->helperGetFormattedFulldate($param->{'param-startup-date'}),
            stpr_dismiss_date => $self->app->helperGetFormattedFulldate($param->{'param-dismiss-date'}),
            stpr_ext_id       => $self->app->helperEscapeParam($param->{'param-external-id'})
        }, { stpr_id => $param->{'param-stprid'} });

        # ##################################################################
        # 2- modifica stazione parametro info
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 2");

        my $sql = qq{
            INSERT INTO metadata.stations_params_info
                (stpr_id, stpr_info_cadence_fk, stpr_export_id1, stpr_export_id2, stpr_info_ws_id, stpr_import_ws_id)
            VALUES
                (?, ?, ?, ?, ?, ?)
            ON CONFLICT ON CONSTRAINT metadata_stations_params_info_pkey
            DO UPDATE SET
                stpr_info_cadence_fk = EXCLUDED.stpr_info_cadence_fk,
                stpr_export_id1   = EXCLUDED.stpr_export_id1,
                stpr_export_id2   = EXCLUDED.stpr_export_id2,
                stpr_info_ws_id   = EXCLUDED.stpr_info_ws_id,
                stpr_import_ws_id = EXCLUDED.stpr_import_ws_id
        };

        # query
        $self->pg->db->query(
            $sql,
            $param->{'param-stprid'},
            $param->{'param-cadence'} != -1 ? $param->{'param-cadence'} : undef,
            $self->app->helperEscapeParam($param->{'param-exportid-1'}),
            $self->app->helperEscapeParam($param->{'param-exportid-2'}),
            $self->app->helperEscapeParam($param->{'param-ws-id'}),
            $self->app->helperEscapeParam($param->{'param-importid'})
        );

        # ##################################################################
        # 3- modifica stazione parametro status
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 3");

        $sql = qq{
            INSERT INTO metadata.stations_params_status
                (stpr_id, stpr_custom_export_publish, stpr_ws_publish)
            VALUES
                (?, ?, ?)
            ON CONFLICT ON CONSTRAINT metadata_stations_params_status_pkey
            DO UPDATE SET
                stpr_custom_export_publish = EXCLUDED.stpr_custom_export_publish,
                stpr_ws_publish = EXCLUDED.stpr_ws_publish;
        };

        # query
        $self->pg->db->query(
            $sql,
            $param->{'param-stprid'},
            $self->app->helperGetBoolean($param, 'param-export-active'),
            $self->app->helperGetBoolean($param, 'param-ws-active')
        );
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);

        if (index($@->{'message'}, 'metadata_stations_parameters_ukey') != -1) {
            # rollback
            return -1;
        }
        else {
            # rollback
            return 0;
        }
    }
    else {
       $tx->commit;
       return 1;
    }
}

sub update_station_parameters_status {
    my( $self, $disabled ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub update_station_parameters_status");
    my $tx;

    eval {
        $tx = $self->pg->db->begin;
        my $sql;

        # ##################################################################
        # 1- modifica stato stazione parametro
        # ##################################################################
        $sql = qq{
            UPDATE metadata.stations_parameters
            SET stpr_active = FALSE
            WHERE
                stpr_id = ANY( ? );
        };

        $self->pg->db->query($sql, \@{$disabled});
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);

        # rollback
        return 0;
    }
    else {
        $tx->commit;
        return 1;
    }

}

sub delete_param_by_stprid {
    my( $self, $stprid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub delete_param_by_stprid");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = "DELETE FROM metadata.stations_params_status WHERE stpr_id = ?";

        $self->pg->db->query($sql, $stprid);

        $sql = "DELETE FROM metadata.stations_params_info WHERE stpr_id = ?";

        $self->pg->db->query($sql, $stprid);

        $sql = "DELETE FROM metadata.stations_parameters WHERE stpr_id = ?";

        $self->pg->db->query($sql, $stprid);
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);

       # rollback
       return 0;
    }
    else {
       $tx->commit;
       return 1;
    }
}

1;

=head1 get_parameters_by_stid

Dato l'id di una stazione, funzione che recupera dal database i parametri associati ad essa.

Argomenti:  * id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 get_parameters_from_config

Funzione che recupera dal database le informazioni relative ai parametri di una stazione dopo aver caricato sul portale
il relativo file di configurazione presente in periferia.

Argomenti:  * contenuto del file di configurazione caricato dall'utente ('file');

Return:     Risultato della query.

=cut

=head1 get_parameter

Funzione che recupera, dato l'id dell'associazione stazione-parametro, le informazioni relative ad un determinato
parametro di una determinata stazione dal database.

Argomenti:  * id dell'associazione stazione-parametro ('stprid');

Return:     Risultato della query;

=cut

=head1 insert_station_parameters

Funzione che effettua l'inserimento dei parametri associati ad una determinata stazione nel database.

Argomenti:  * id della stazione ('stid');

           * oggetto contenente le informazioni necessarie all'inserimento dei parametri ('new');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_station_parameter

Funzione che effettua la modifica delle informazioni relative ad un determinato parametro di una determinata stazione nel database.

Argomenti:  * oggetto contenente le informazioni del parametro ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_station_parameters_status

Funzione che effettua la modifica dello status dei parametri di una determinata stazione nel database.

Argomenti:  * oggetto contenente gli id delle associazioni stazione-parametro dei parametri dei quali si intente modificare lo status ('disabled');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_param_by_stprid

Funzione che effettua l'eliminazione di un determinato parametro di una determinata stazione dal database.

Argomenti:  * id associazione stazione-parametro ('stprid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut