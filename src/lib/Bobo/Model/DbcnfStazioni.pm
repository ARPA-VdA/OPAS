package Bobo::Model::DbcnfStazioni;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

sub get_schemas {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStazioni get_schemas");

    # query
    my $sql = qq{
        SELECT
            UNNEST(db_schema_names) AS schema_name
        FROM
            bobo.portal_properties pp
            LEFT JOIN bobo.users_metadata USING (portal_id)
        WHERE
            us_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $userid)->hashes();
}

sub get_typologies {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStazioni get_typologies");

    # query
    my $sql = qq{
        SELECT
            st_typology_id,
            st_typology_desc,
            STRING_AGG(st_typology_desc, ', ') OVER () AS total
        FROM metadata.stations_typology
        ORDER BY st_typology_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_roaming_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStazioni get_roaming_types");

    # query
    my $sql = qq{
        SELECT
            st_roaming_id,
            st_roaming_desc,
            STRING_AGG(st_roaming_desc, ', ') OVER () AS total
        FROM metadata.stations_roaming_type
        WHERE
            st_roaming_id IN (1,2,3)
        ORDER BY st_roaming_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_measures_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStazioni get_measures_types");

    # query
    my $sql = qq{
        SELECT
            measure_type_id,
            measure_type_desc,
            STRING_AGG(measure_type_desc, ', ') OVER () AS total
        FROM metadata.measures_type
        ORDER BY measure_type_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_measures_cadences {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStazioni get_measures_cadences");

    # query
    my $sql = qq{
        SELECT
            measure_cadence_id,
            measure_cadence_desc,
            STRING_AGG(measure_cadence_desc, ', ' ) OVER (ORDER BY measure_cadence_db) AS total
        FROM metadata.measures_cadence
        ORDER BY measure_cadence_db;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_stations_by_province_net {
    my ( $self, $user_id, $net, $prov, $status ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStazioni sub get_stations_by_province_net");

    $net = ($net != -1 ? "^$net\$": ".*");
    $prov = ($prov != -1 ? "^$prov\$": ".*");

    ## query
    my $sql = qq{
        SELECT
            sm.station_id,
            sm.station_name,
            '/downloads/anagrafica/stazioni/report-anagrafica-'||sm.station_id||'.pdf' AS station_pdf_path,
            sm.station_active,
            ss.ss_suspended AS station_suspended,
            ss.ss_dataview_publish AS station_published,
            sm.station_startup_date,
            -- sm.station_shortname,
            -- sm.station_longname,
            -- sm.station_north_utm,
            -- sm.station_east_utm,
            -- sm.station_altitude,
            -- COALESCE(sm.station_lat_wgs84::text, '--') AS station_lat_wgs84,
            -- COALESCE(sm.station_lon_wgs84::text, '--') AS station_lon_wgs84,
            -- COALESCE(sm.station_note, '--') AS station_note,
            smu.mu_name,
            smu.province_code,
            COALESCE(sm.station_locality, '--') AS station_locality,
            sm.station_fulltable,
            sm.station_network_type_id,
            sm.station_network_type_desc,
            sm.station_network_type_name,
            -- FOR PROVINCE FILTER
            smu.province_id,
            smu.province_name,
            smu.region_id,
            smu.region_name
        FROM
            metadata.view_stations_info sm
            LEFT JOIN metadata.stations_status ss USING (station_id)
            LEFT JOIN bobo.view_user_stations us USING(station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND sm.station_network_type_id::text ~ ?
            AND smu.province_id::text ~ ?
    };

    # filtro dello stato della stazione
    if ($status != -1) { # nessuna selezione
        if ($status == 0) { # stazione attiva
            $sql .= qq{
                AND sm.station_active IS TRUE
                AND ss.ss_suspended IS FALSE
            };
        }
        elsif ($status == 1) { # stazione non attiva
            $sql .= qq{
                AND sm.station_active IS FALSE
            };
        }
        else { # stazione sospesa (attiva/non attiva)
            $sql .= qq{
                AND ss.ss_suspended IS TRUE
            };
        }
    }

    $sql .= qq {
            AND sm.station_network_type_id IS NOT NULL
        ORDER BY
            sm.station_network_type_id, sm.station_name;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id, $net, $prov)->hashes();
}

sub get_station_by_id {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStazioni sub get_station_by_id");

    # query
    my $sql = qq{
        SELECT
            vsi.station_id,
            vsi.station_name,
            vsi.station_schema,
            vsi.station_table,
            vsi.station_prefix,
            vsi.station_fulltable,
            vsi.station_active,
            vsi.station_base_path,
            vsi.station_base_path || '/' || vsi.station_id AS station_media_path,
            '/downloads/anagrafica/stazioni/report-anagrafica-'||vsi.station_id||'.pdf' AS station_pdf_path,
            vsi.station_external_id                                 AS station_external_id,
            vsi.station_file_header                                 AS station_file_header,
            station_remote_ctrl,
            vsi.station_note                                        AS station_note,
            vsi.station_shortname                                   AS station_shortname,
            vsi.station_longname                                    AS station_longname,
            TO_CHAR(vsi.station_startup_date, 'DD-MM-YYYY HH24:MI') AS station_startup_date,
            TO_CHAR(vsi.station_dismiss_date, 'DD-MM-YYYY HH24:MI') AS station_dismiss_date,
            vsi.station_locality                                    AS station_locality,
            vsi.station_zone                                        AS station_zone,
            vsi.station_basin                                       AS station_basin,
            vsi.station_community                                   AS station_community,
            vsi.station_north_utm                                   AS station_north_utm,
            vsi.station_east_utm                                    AS station_east_utm,
            vsi.station_altitude                                    AS station_altitude,
            vsi.station_lat_wgs84                                   AS station_lat_wgs84,
            vsi.station_lon_wgs84                                   AS station_lon_wgs84,
            vsi.station_national_code                               AS station_national_code,
            vsi.station_export_id                                   AS station_export_id,
            vsi.station_ws_name                                     AS station_ws_name,
            vsi.station_import_ws_id,
            vsi.station_network_type_id,
            vsi.station_network_type_name,
            vsi.station_network_type_desc,
            vsi.station_network_type_logo,
            vsi.station_roaming_type_id,
            vsi.station_roaming_type_desc,
            vsi.station_typology_id,
            vsi.station_typology_desc,
            vsi.station_measure_type_id,
            vsi.station_measure_type_desc                           AS station_measure_type_desc,
            vsi.station_cadence_type_id,
            vsi.station_cadence_type_desc                           AS station_cadence_type_desc,
            vsi.station_metadata_note                               AS station_metadata_note,
            vm.mu_id,
            vm.mu_name                                              AS mu_name,
            vm.mu_istat_code,
            vm.mu_catasto_code,
            vm.mu_cap,
            vm.mu_note,
            vm.province_id,
            vm.province_name                                        AS province_name,
            vm.province_istat_code,
            vm.province_code,
            vm.province_note,
            vm.region_id,
            vm.region_name                                          AS region_name,
            vm.region_istat_code,
            vm.region_note,
            ss.ss_custom_export_publish                             AS station_export_active,
            ss.ss_suspended                                         AS station_suspended,
            ss.ss_dataview_publish                                  AS station_published,
            ss.ss_real_time                                         AS station_real_time,
            ss.ss_ws_publish                                        AS station_ws_active
        FROM
            metadata.view_stations_info vsi
            LEFT JOIN metadata.stations_status ss USING (station_id)
            LEFT JOIN metadata.stations_municipality sm USING (station_id)
            LEFT JOIN main.view_municipalities vm USING (mu_id)
        WHERE
            vsi.station_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $station_id)->hash();
}

sub get_parameters_metadata_by_stid {
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStazioni sub get_parameters_metadata_by_stid");

    # query
    my $sql = qq{
        SELECT
            COUNT(*)            AS station_parameters_number,
            MAX(stpr_table_id)  AS station_parameter_table_id
            --numero parametri attivi
            --numero parametri pubblici
        FROM
            metadata.view_stations_parameters vsp
        WHERE
            station_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $stid)->hashes();
}

sub insert_station {
    my( $self, $userid, $params ) = @_;

    $self->app->log->debug("Bobo::Model::DbcnfStazioni sub insert_station");

    # {
    #   "station-active" => "on",
    #   "station-altitude" => 580,
    #   "station-headerfile" => "ao_plouves",
    #   "station-id" => ,
    #   "station-locality" => "Piazza Plouves",
    #   "station-municipality" => 3,
    #   "station-name" => "Aosta - Plouves",
    #   "station-network" => 1,
    #   "station-province" => 1,
    #   "station-region" => 2,
    #   "station-wgs84-lat" => "45.7369",
    #   "station-wgs84-lon" => "7.32372",
    #   "station-zone" => "A"
    # }
    # log

    my $tx;
    my $sql;

    my $stid;
    my $basepath;

    eval {
        $tx = $self->pg->db->begin;

        # /!\ PARTE 1: DML - Data Manipulation Language /!\

        # ##################################################################
        # 1- inserimento stazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 1");

        $stid = $self->pg->db->insert('metadata.stations', {
            station_name         => $self->app->helperEscapeParam($params->{'station-name'}),
            station_active       => 0,
            station_schema       => $params->{'station-schemadb'},
            station_table        => $params->{'station-tabledb'},
            station_file_header  => $self->app->helperEscapeParam($params->{'station-headerfile'}),

            station_insert_us_id => $userid
        }, { returning => 'station_id' })->hash->{'station_id'};

        # ##################################################################
        # 2- inserimento comune
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 2");

        my $sql = qq{
            INSERT INTO metadata.stations_municipality
                (station_id, mu_id)
            VALUES
                (?, ?);
        };

        $self->pg->db->query(
            $sql,
            $stid,
            $params->{'station-municipality'}
        );

        # ##################################################################
        # 3- inserimento riga stazione info
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 3");

        $sql = qq{
            SELECT st_network_basepath FROM metadata.stations_network_type WHERE st_network_id = ?;
        };

        $basepath = $self->pg->db->query(
                        $sql,
                        $params->{'station-network'}
                    )->hash->{'st_network_basepath'};

        $self->pg->db->insert('metadata.stations_info', {
            station_id              => $stid,

            st_info_startup_date    => $self->app->helperGetLocaleFullDate(),
            st_info_locality        => $self->app->helperEscapeParam($params->{'station-locality'}),
            st_info_zone            => $self->app->helperEscapeParam($params->{'station-zone'}),
            st_info_altitude        => $self->app->helperEscapeParam($params->{'station-altitude'}),
            st_info_lat_wgs84       => $self->app->helperEscapeParam($params->{'station-wgs84-lat'}),
            st_info_lon_wgs84       => $self->app->helperEscapeParam($params->{'station-wgs84-lon'}),
            st_info_network_type_fk => $params->{'station-network'},
            st_info_basepath        => $basepath,
            # al primo inserimento lo impongo uguale al nome inserito
            st_info_shortname       => $self->app->helperEscapeParam($params->{'station-name'}),  # NOT NULL
            st_info_roaming_type_fk => $params->{'station-roaming'} # NOT NULL
            ## DEFAULTs ##
            # st_info_typology_fk     DEFAULT 2 (tipo stazione: chimica)
            # st_info_measure_fk      DEFAULT 1 (tipo misurazione: continua)
            # st_info_cadence_fk      DEFAULT 5 (tipo cadenza: oraria)
        });

        # ##################################################################
        # 4- inserimento riga status stazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 4");

        $self->pg->db->insert('metadata.stations_status', {
            station_id             => $stid
            ## DEFAULTs ##
            # ss_suspended             DEFAULT FALSE
            # ss_ws_publish            DEFAULT FALSE
            # ss_dataview_publish      DEFAULT FALSE
            # ss_custom_export_publish DEFAULT FALSE
            # ss_real_time             DEFAULT FALSE
        });

        # ##################################################################
        # 5- inserimento permessi
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 5");

        $self->pg->db->insert('bobo.group_stations', {
            station_id    => $stid,
            gr_id         => 3, # Ecometer
            gs_iud_grants => '111'
        }, { on_conflict => undef }); # ON CONFLICT DO NOTHING

        $sql = qq{
            WITH t AS (
                SELECT
                    gp.gr_id,
                    (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (gp.gp_iud_grants), (b'100')) AS t (bit)) AS temp)::boolean AS has_grant,
                    EXISTS( SELECT 1 FROM bobo.portal_properties WHERE admin_gr_id = gp.gr_id   ) AS is_admin
                FROM bobo.group_pages gp
                LEFT JOIN bobo.pages p USING (page_id)
                WHERE
                    p.page_href = '/cnf_stazioni'
            )
            SELECT
                gr_id
            FROM
                t
            WHERE
                (has_grant OR is_admin) IS TRUE
                AND gr_id IN (
                    SELECT
                        UNNEST(pp.linked_gr_id)
                    FROM bobo.users_metadata
                    LEFT JOIN bobo.portal_properties pp USING (portal_id)
                    WHERE us_id = ?
                )
            ORDER BY gr_id;
        };

        my $groups = $self->pg->db->query($sql, $userid)->hashes;
        for my $group (@{$groups}) {
            $self->pg->db->insert('bobo.group_stations', {
                station_id    => $stid,
                gr_id         => $group->{'gr_id'},
                gs_iud_grants => '111'
            }, { on_conflict => undef }); # ON CONFLICT DO NOTHING
        }
    };

    # error check
    if ($@) {
        $self->app->log->warn("Error: ".$@);
        if (index($@->{'message'}, 'metadata_stations_ukey') != -1) {
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

       eval {

            # create directory for station's attachments
            my $station_dir = $self->app->static->paths->[0].'/'.$basepath.'/'.$stid;
            $self->app->helperCreatePath($station_dir);

            # /!\ PARTE 2:  DDL - Data Definition Language /!\

            # ##################################################################
            # 6- creazione tabelle e trigger
            # ##################################################################
            $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 6");

            $sql = qq{ SELECT template.f_create_opas_tables(?) AS res; };

            die "Something went wrong during function template.f_create_opas_tables execution!"
                unless $self->pg->db->query($sql, $stid)->hash->{'res'};
        };

        if($@){
           $self->app->log->warn("Error: ".$@);
           return -2;
        }
        else {
            return $stid;
        }
    }
}

sub update_station {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStazioni sub update_station");

    # {
    #   "station-active" => "on",
    #   "station-altitude" => 580,
    #   "station-cadence" => 5,
    #   "station-control-id" => "",
    #   "station-export-id" => "",
    #   "station-extra-id" => 4000,
    #   "station-headerfile" => "ao_plouves",
    #   "station-id" => 1000,
    #   "station-import-id" => "",
    #   "station-locality" => "Piazza Plouves",
    #   "station-longname" => "",
    #   "station-measure" => 1,
    #   "station-municipality" => 3,
    #   "station-name" => "Aosta - Plouves",
    #   "station-network" => 1,
    #   "station-note" => "",
    #   "station-province" => 1,
    #   "station-published" => "on",
    #   "station-realtime" => "on",
    #   "station-region" => 2,
    #   "station-roaming" => 1,
    #   "station-shortname" => "Aosta - Plouves",
    #   "station-startup-date" => "01/01/2000",
    #   "station-typology" => 2,
    #   "station-wgs84-lat" => "45.7369",
    #   "station-wgs84-lon" => "7.32372",
    #   "station-ws-name" => "",
    #   "station-zone" => "A"
    # }
    # log

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- modifica stazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 1");

        $self->pg->db->update('metadata.stations', {
            station_name         => $self->app->helperEscapeParam($params->{'station-name'}),
            station_active       => $self->app->helperGetBoolean($params, 'station-active'),
            station_note         => $self->app->helperEscapeParam($params->{'station-note'}),
            station_ext_id       => $self->app->helperEscapeParam($params->{'station-extra-id'}),
            station_file_header  => $self->app->helperEscapeParam($params->{'station-headerfile'}),
            station_remote_ctrl  => $self->app->helperEscapeParam($params->{'station-control-id'}),

            station_update_ts    => $self->app->helperGetFullDate(),
            station_update_us_id => $userid

        }, { station_id => $params->{'station-id'} });

        # ##################################################################
        # 2- insert/modifica comune
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 2");

        my $sql = qq{
            INSERT INTO metadata.stations_municipality
                (station_id, mu_id)
            VALUES
                (?, ?)
            ON CONFLICT ON CONSTRAINT metadata_stations_municipality_ukey
            DO UPDATE SET
                mu_id = EXCLUDED.mu_id;
        };

        $self->pg->db->query(
            $sql,
            $params->{'station-id'},
            $params->{'station-municipality'}
        );

        # ##################################################################
        # 3- modifica stazione info
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 3");


        $self->pg->db->update('metadata.stations_info', {
            st_info_startup_date    => $self->app->helperGetFormattedFulldate($params->{'station-startup-date'}),
            st_info_dismiss_date    => $self->app->helperGetFormattedFulldate($params->{'station-dismiss-date'}),
            st_info_locality        => $self->app->helperEscapeParam($params->{'station-locality'}),
            st_info_zone            => $self->app->helperEscapeParam($params->{'station-zone'}),
            st_info_altitude        => $self->app->helperEscapeParam($params->{'station-altitude'}),
            st_info_lat_wgs84       => $self->app->helperEscapeParam($params->{'station-wgs84-lat'}),
            st_info_lon_wgs84       => $self->app->helperEscapeParam($params->{'station-wgs84-lon'}),
            st_info_network_type_fk => $params->{'station-network'},

            st_info_shortname       => $self->app->helperEscapeParam($params->{'station-shortname'}), # NOT NULL
            st_info_longname        => $self->app->helperEscapeParam($params->{'station-longname'}),
            st_info_typology_fk     => $params->{'station-typology'}, # NOT NULL
            st_info_roaming_type_fk => $params->{'station-roaming'}, # NOT NULL
            st_info_measure_fk      => $params->{'station-measure'} ne '' ? $params->{'station-measure'} : undef,
            st_info_cadence_fk      => $params->{'station-cadence'} ne '' ? $params->{'station-cadence'} : undef,
            st_info_export_id       => $self->app->helperEscapeParam($params->{'station-export-id'}),
            st_info_ws_name         => $self->app->helperEscapeParam($params->{'station-ws-name'}),
            st_info_import_ws_id    => $self->app->helperEscapeParam($params->{'station-import-id'})

        }, { station_id => $params->{'station-id'} });

        # set refresh_dependents to true in order to run specific scripts to update all products linked to the station
        # like map screenshot, pdf ecc ecc
        $sql = qq{
            UPDATE metadata.stations_info
            SET st_info_obj= jsonb_set(st_info_obj, '{refresh_dependents}', 'true'::jsonb, true)
            WHERE station_id = ?;
        };

        $self->pg->db->query(
            $sql,
            $params->{'station-id'}
        );

        # ##################################################################
        # 4- modifica status stazione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbcnfStazioni STEP 4");

        $self->pg->db->update('metadata.stations_status', {
            ss_suspended             => $self->app->helperGetBoolean($params, 'station-suspended'),
            ss_real_time             => $self->app->helperGetBoolean($params, 'station-realtime'),
            ss_dataview_publish      => $self->app->helperGetBoolean($params, 'station-published'),
            ss_ws_publish            => $self->app->helperGetBoolean($params, 'station-ws-active'),
            ss_custom_export_publish => $self->app->helperGetBoolean($params, 'station-export-active'),
            ss_suspended             => $self->app->helperGetBoolean($params, 'station-suspended')
        }, { station_id => $params->{'station-id'} });
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

sub delete_station_by_id {
    my( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfParametri sub delete_param_by_stprid");

    my $tx;
    my $res;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = "SELECT metadata.f_delete_station( ?::integer ) AS res";

        $res = $self->pg->db->query($sql, $stid)->hash->{res};
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return 0;
    }
    else {
       $tx->commit;
       return $res;
    }
}

1;


=head1 get_schemas

Funzione che recupera gli schemi dei vari clients del database visibile dall'utente loggato.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query;

=cut

=head1 get_typologies

Funzione che recupera le tipologie di stazione dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_roaming_types

Funzione che recupera le tipologie di giacenza sul territorio delle stazioni dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_measures_types

Funzione che recupera le tipologie di misurazione delle stazioni dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_measures_cadences

Funzione che recupera le varie cadenze di misurazione delle stazioni dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_stations_by_province_net

Funzione che recupera, dati gli id di una provincia e di una rete (non obbligatori), le informazioni di determinate stazioni dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della provincia, se presente ('province_id');

           * id della rete, se presente ('network_id');

Return:     Risultato della query;

=cut

=head1 get_station_by_id

Funzione che recupera, dato l'id, le informazioni di una determinata stazione dal database.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query;

=cut


=head1 get_parameters_metadata_by_stid

Funzione che recupera, dato l'id di una stazione, i metadati dei associati ad essa dal database.

Argomenti:  * id della stazione ('stid');

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 insert_station

Funzione che effettua l'inserimento di una stazione nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni della stazione ('params');

Return:     Se tutto OK, restituisce il nuovo id della stazione;

        Se KO, restituisce -1/ 0 (inserimento della stazione e assegnazione dei permessi) oppure -2 (errori nella creazione di tabelle e trigger).

=cut

=head1 update_station

Funzione che effettua la modifica di una stazione nel database.

Argomenti:  * oggetto contenente le informazioni della stazione ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_station_by_id

Funzione che l'eliminazione di una determinata stazione dal database.

Argomenti:  * id della stazione ('stid');

Return:     Se tutto OK, restituisce il risultato della query;

        Se KO, restituisce 0.

=cut