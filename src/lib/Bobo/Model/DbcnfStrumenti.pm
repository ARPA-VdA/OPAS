package Bobo::Model::DbcnfStrumenti;
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

sub get_instruments_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instruments_types");

    # query
    my $sql = qq{
        SELECT
            instr_type_id,
            instr_type_fullname,
            CASE
                WHEN category_id = 0 THEN 'N.d.'
                ELSE category_name
            END AS category_name
        FROM
            equipments.view_instruments_type vit
        ORDER BY instr_type_fullname;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_instruments_by_date {
    my ( $self, $user_id, $from, $to, $net, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instruments_by_date");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                vi.instr_id,
                vi.instr_type_fullname                   AS instrument_type_fullname,
                COALESCE(vi.instrument_arpa_id   , '--') AS instrument_arpa_id   ,
                COALESCE(vi.instrument_serial_num, '--') AS instrument_serial_num,
                COALESCE(vi.instrument_name      , '--') AS instrument_name      ,
                vi.instr_type_fullname || COALESCE(' - '|| vi.instrument_name, '') || COALESCE(' ['|| vi.instrument_serial_num||']', '') AS instrument_fullname,
                vi.instrument_active        ,
                vi.instrument_note          ,
                vi.instrument_delivery_date ,
                vi.instrument_dismiss_date  ,
                vi.category_id              ,
                vi.category_name            ,
                vi.network_names            ,
                vsi.stin_id AS location_id  ,
                CASE
                    WHEN vsi.station_name NOTNULL THEN vsi.station_name
                    ELSE '<i class="icon-close text-danger"></i>'
                END AS location,
                station_instr_startup_date AS location_start,
                CASE
                    WHEN station_instr_dismiss_date = 'infinity' THEN 'infinito'
                    WHEN station_instr_dismiss_date IS NULL THEN '--'
                    ELSE TO_CHAR(station_instr_dismiss_date, 'DD/MM/YYYY HH24:MI')
                END AS location_end

            FROM equipments.view_instruments vi
            LEFT JOIN metadata.view_stations_instruments vsi ON ( vi.instr_id = vsi.instr_id AND tsrange(vsi.station_instr_startup_date, vsi.station_instr_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
            WHERE vi.network_types && ARRAY(
                    SELECT st_network_id
                    FROM bobo.view_user_networks
                    WHERE user_id = ?
                )
            AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(vi.instrument_delivery_date, vi.instrument_dismiss_date, '[]')
    };

    my @binds = ($user_id, $from, $to);

    if ($net != -1) {
        $sql .= qq{ AND ? = ANY(vi.network_types) };
        push @binds, $net;
    }

    if ($cat != -1) {
        $sql .= qq{ AND vi.category_id = ? };
        push @binds, $cat;
    }

    $sql .= qq{
        )
        SELECT *
        FROM t
        ORDER BY instrument_delivery_date DESC;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_instruments_by_date_station {
    my ( $self, $user_id, $from, $to, $net, $stid, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instruments_by_date_station");

    # query
    my $sql = qq{
        SELECT
            instr_id,
            instrument_type_fullname      ,
            COALESCE(instrument_arpa_id   , '--') AS instrument_arpa_id   ,
            COALESCE(instrument_serial_num, '--') AS instrument_serial_num,
            COALESCE(instrument_name      , '--') AS instrument_name      ,
            instrument_type_fullname || COALESCE(' - '|| instrument_name, '') || COALESCE(' ['|| instrument_serial_num||']', '') AS instrument_fullname,
            instrument_note          ,
            instrument_delivery_date ,
            instrument_dismiss_date  ,
            instrument_active        ,
            category_id              ,
            category_name            ,
            network_names            ,
            stin_id AS location_id   ,
            CASE
                WHEN station_name NOTNULL THEN station_name
                ELSE '<i class="icon-close text-danger"></i>'
            END AS location,
            station_instr_startup_date AS location_start,
            CASE
                WHEN station_instr_dismiss_date = 'infinity' THEN 'infinito'
                WHEN station_instr_dismiss_date IS NULL THEN '--'
                ELSE TO_CHAR(station_instr_dismiss_date, 'DD/MM/YYYY HH24:MI')
            END AS location_end,

            station_instr_master,
            ( stpr_group_id > 0 ) AS has_linked_parameters

        FROM metadata.view_stations_instruments
        WHERE station_id IN (
                SELECT station_id
                FROM bobo.view_user_stations
                WHERE user_id = ?
            )
        AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]')
    };

    my @binds = ($user_id, $from, $to);

    if ($net != -1) {
        $sql .= qq{ AND ? = ANY(network_types) };
        push @binds, $net;
    }

    if ($stid != -1) {
        $sql .= qq{ AND station_id = ? };
        push @binds, $stid;
    }

    if ($cat != -1) {
        $sql .= qq{ AND category_id = ? };
        push @binds, $cat;
    }

    $sql .= qq{
        ORDER BY station_instr_startup_date DESC;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_params_by_instr_type {
    my ( $self, $stid, $intyid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_params_by_instr_type");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT param_id
            FROM metadata.parameters_info
            WHERE ? = ANY(instr_type_ids)
            AND (
		        pm_info_type_fk BETWEEN 1 AND 5
		        OR pm_info_type_fk = 19
	        )
        )
        SELECT
            stpr_group_id,
            STRING_AGG( p.param_name || COALESCE(' - '::text || sp.stpr_note, ''::text), ', ' ) AS parameters
        FROM
            metadata.stations_parameters sp
            LEFT JOIN  metadata.parameters p USING (param_id)
            LEFT JOIN metadata.parameters_info pi USING (param_id)
        WHERE
            station_id = ?
            AND param_id IN (SELECT * FROM t)
            AND stpr_group_id NOTNULL
        GROUP BY sp.stpr_group_id
        ORDER BY sp.stpr_group_id;
    };

    # return
    return $self->pg->db->query($sql, $intyid, $stid)->hashes();
}

sub get_instruments_for_location {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instruments_for_location");

    # query
    my $sql = qq{
        SELECT
            vi.instr_id,
            vi.instr_type_id,
            vi.instr_type_fullname ||
            COALESCE(' - '|| vi.instrument_name, '') ||
            COALESCE(' ['|| vi.instrument_arpa_id||']', '') AS instrument_fullname,
            vi.network_types,
            CASE
                WHEN
                    (
                        SELECT TRUE
                        FROM metadata.stations_instruments si
                        WHERE vi.instr_id = si.instr_id
                        AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    ) THEN 'disabled'
                ELSE ''
            END AS instrument_class

        FROM equipments.view_instruments vi
        WHERE vi.network_types && ARRAY(
                SELECT st_network_id
                FROM bobo.view_user_networks
                WHERE user_id = ?
            )
        AND tsrange(vi.instrument_delivery_date, vi.instrument_dismiss_date, '[)')  @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')::timestamp
        -- AND vi.instr_delivery_date <= (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')::timestamp
        AND vi.instrument_active IS TRUE
        ORDER BY 1;
    };

    # return
    # $self->app->log->debug($sql, $user_id, $from, $to);
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_instrument_by_id {
    my ( $self, $inid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instrument_by_id");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                stin_id,
                station_id AS main_station_id,
                CASE
                    WHEN stin_dismiss_date = 'infinity' THEN metadata.f_get_stationid_by_date(station_id, CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    ELSE metadata.f_get_stationid_by_date(station_id, stin_dismiss_date)
                END AS station_id,
                stin_startup_date,
                stin_dismiss_date,
                stin_note,
                stpr_group_id,
                stin_master
            FROM
                metadata.stations_instruments
            WHERE
                instr_id = ?
        )
        SELECT
            *,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        att_id          AS file_id,
                        file_original   AS file_name,
                        '/uploads/impostazioni/strumenti/'||LPAD(instr_id::text, 9, '0')||'/'||file_archive AS file_path,
                        file_image
                    FROM
                        equipments.instrument_attachments ia
                    WHERE ia.instr_id = vi.instr_id
                ) j
            ) AS instrument_attachments,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(l)))
                FROM (
                    SELECT
                        t.stin_id                   AS id,
                        t.station_id                AS location_id,
                        vsi.station_name            AS location_name,
                        vsm.province_name           AS location_prov,
                        vsi.station_lat_wgs84       AS location_lat,
                        vsi.station_lon_wgs84       AS location_lon,
                        t.stin_startup_date         AS location_start,
                        CASE
                            WHEN t.stin_dismiss_date = 'infinity' THEN 'infinito'
                            ELSE TO_CHAR(t.stin_dismiss_date, 'DD/MM/YYYY HH24:MI')
                        END                         AS location_end,
                        t.stin_dismiss_date,
                        COALESCE(t.stin_note, '--') AS location_note,
                        ARRAY(
                            SELECT
                                parameter_name || COALESCE(' ('|| sp.stpr_note||')', ''::text)
                            FROM
                                metadata.stations_parameters sp
                                LEFT JOIN metadata.view_parameters_info vpi ON (sp.param_id = vpi.parameter_id)
                            WHERE
                                sp.stpr_group_id = t.stpr_group_id
                            AND vpi.parameter_type_id BETWEEN 1 AND 5
                        )                           AS location_params,
                        t.stin_master               AS location_master
                    FROM
                        t
                        LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                        LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
                    ORDER BY
                        t.stin_startup_date DESC
                ) l
            ) AS instrument_locations
        FROM equipments.view_instruments vi
        WHERE instr_id = ?
    };

    # return
    return $self->pg->db->query($sql, $inid, $inid)->hash();
}

sub get_location_by_id {
    my ( $self, $stinid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_location_by_id");

    # query
    my $sql = qq{
        SELECT *
        FROM metadata.stations_instruments
        WHERE stin_id = ?
    };

    # return
    return $self->pg->db->query($sql, $stinid)->hash;
}

sub get_instrument_locations_history{
    my ( $self, $inid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfStrumenti sub get_instrument_locations_history");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                row_number() OVER (PARTITION BY instr_id ORDER BY stin_startup_date ASC) AS rownum,
                stin_id,
                station_id AS main_station_id,
                CASE
                    WHEN stin_dismiss_date = 'infinity' THEN metadata.f_get_stationid_by_date(station_id, CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    ELSE metadata.f_get_stationid_by_date(station_id, stin_dismiss_date)
                END AS station_id,
                stin_startup_date,
                CASE
                    WHEN stin_dismiss_date = 'infinity' THEN CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'
                    ELSE stin_dismiss_date
                END AS stin_dismiss_date,
                stin_note,
                stpr_group_id,
                stin_master
            FROM
                metadata.stations_instruments
            WHERE
                instr_id = ?
            ORDER BY 
                stin_startup_date ASC
        )
        SELECT 
            vi.instr_type_fullname || COALESCE(' - '|| vi.instrument_name, '') || COALESCE(' ['|| vi.instrument_serial_num||']', '') AS instrument_fullname,
            (
            SELECT 
                to_json(ARRAY_AGG(json_strip_nulls(row_to_json(l))))
                FROM (
                    SELECT 
                        t.rownum::text AS id,
                        vsi.station_name AS name,
                        t.stin_startup_date AS start,
                        t.stin_dismiss_date AS end,
                        CASE
                            WHEN t.rownum = 1 THEN NULL
                            ELSE (t.rownum-1)::text 
                        END 				AS dependency
                    FROM
                        t
                        LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                    ORDER BY
                        rownum
                ) l 
            ) AS instrument_locations	
        FROM equipments.view_instruments vi
        WHERE instr_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $inid, $inid)->hash();
}

sub insert_new_instrument {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti insert_new_instrument");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        # ARRAY networks
        my @networks;
        if (ref($params->{'instr-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'instr-networks'}};
        }
        else {
            push @networks, $params->{'instr-networks'};
        }

        $id = $self->pg->db->insert('equipments.instruments', {
            # id                  => # id progressivo
            instr_type_id       => $params->{'instr-type'}, # NOT NULL
            instr_arpa_id       => $self->app->helperEscapeParam($params->{'instr-arpa-id'}),
            instr_owner         => $self->app->helperEscapeParam($params->{'instr-owner'}),
            instr_serial_num    => $self->app->helperEscapeParam($params->{'instr-serial-num'}),
            instr_name          => $self->app->helperEscapeParam($params->{'instr-name'}),
            instr_active        => $self->app->helperGetBoolean($params, 'instr-active'),
            instr_note          => $self->app->helperEscapeParam($params->{'instr-note'}),
            instr_delivery_date => $self->app->helperGetFormattedFulldate($params->{'instr-date-delivery'}), # NOT NULL
            instr_dismiss_date  => $params->{'instr-date-disuse'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'instr-date-disuse'}) : undef,

            network_types       => \@networks, # NOT NULL
            insert_user         => $userid
        }, { returning => 'instr_id' })->hash->{'instr_id'};

        if (defined $params->{'add-location'} && $params->{'add-location'} ne '') {
            $self->pg->db->insert('metadata.stations_instruments', {
                # id                => # id progressivo
                station_id        => $params->{'loc-stat'},
                instr_id          => $id,
                stpr_group_id     => $params->{'loc-params'},
                stin_startup_date => $self->app->helperGetFormattedFulldate($params->{'loc-start-date'}),,
                stin_dismiss_date => $params->{'loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'loc-end-date'}) : 'infinity',
                stin_note         => $self->app->helperEscapeParam($params->{'loc-notes'}),
                stin_master       => $self->app->helperGetBoolean($params, 'loc-first'),
            });
        }
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_instruments_check') != -1) {
            $self->app->log->debug("RETURN -1");
            return -1;
        }
        else {
            return undef;
        }
    }
    else {
        $tx->commit;
        return $id;
    }
}

sub insert_new_attachment {
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    # query
    my $res = $self->pg->db->insert('equipments.instrument_attachments', {
        instr_id      => $id,
        file_original => $original_name,
        file_archive  => $new_name,
        file_image    => $is_image
    });

    # check result and return
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub insert_new_location {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti insert_new_location");

    my $id;

    eval{
        $id = $self->pg->db->insert('metadata.stations_instruments', {
            # id                => # id progressivo
            station_id        => $params->{'place-instr-stat'},
            instr_id          => $params->{'place-instr-id'},
            stpr_group_id     => $params->{'place-instr-params'},
            stin_startup_date => $self->app->helperGetFormattedFulldate($params->{'place-instr-start-date'}),
            stin_dismiss_date => $params->{'place-instr-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-instr-end-date'}) : 'infinity',
            stin_note         => $self->app->helperEscapeParam($params->{'place-instr-notes'}),
            stin_master       => $self->app->helperGetBoolean($params, 'place-instr-first'),
        }, { returning => 'stin_id' })->hash->{'stin_id'};
    };

    # check result and return
    if (defined $id) {
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_instruments_check') != -1) {
            return -1;
        }
        elsif (index($@->{'message'}, 'metadata_stations_instruments_check2') != -1) {
            return -2;
        }
        else {
            return undef;
        }
    }
}

sub update_instrument_by_id {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti update_instrument_by_id");

    # ARRAY networks
    my @networks;
    if (ref($params->{'instr-networks'}) eq 'ARRAY') {
        @networks = @{$params->{'instr-networks'}};
    }
    else {
        push @networks, $params->{'instr-networks'};
    }


    my $res = $self->pg->db->update('equipments.instruments', {
        # id                  => # id progressivo
        instr_type_id       => $params->{'instr-type'}, # NOT NULL
        instr_arpa_id       => $self->app->helperEscapeParam($params->{'instr-arpa-id'}),
        instr_owner         => $self->app->helperEscapeParam($params->{'instr-owner'}),
        instr_serial_num    => $self->app->helperEscapeParam($params->{'instr-serial-num'}),
        instr_name          => $self->app->helperEscapeParam($params->{'instr-name'}),
        instr_active        => $self->app->helperGetBoolean($params, 'instr-active'),
        instr_note          => $self->app->helperEscapeParam($params->{'instr-note'}),
        instr_delivery_date => $self->app->helperGetFormattedFulldate($params->{'instr-date-delivery'}), # NOT NULL
        instr_dismiss_date  => $params->{'instr-date-disuse'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'instr-date-disuse'}) : undef,

        network_types       => \@networks # NOT NULL
    }, {instr_id => $params->{'instr-id'}} );

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub update_location_by_id {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti update_location_by_id");

    my $res;

    eval{
        if (defined $params->{'place-instr-stat'}) {
            $res = $self->pg->db->update('metadata.stations_instruments', {
                station_id        => $params->{'place-instr-stat'},
                stpr_group_id     => $params->{'place-instr-params'},
                stin_startup_date => $self->app->helperGetFormattedFulldate($params->{'place-instr-start-date'}),,
                stin_dismiss_date => $params->{'place-instr-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-instr-end-date'}) : 'infinity',
                stin_note         => $self->app->helperEscapeParam($params->{'place-instr-notes'}),
                stin_master       => $self->app->helperGetBoolean($params, 'place-instr-first'),
            }, { stin_id => $params->{'place-id'} });
        }
        else {
            $res = $self->pg->db->update('metadata.stations_instruments', {
                stpr_group_id     => $params->{'place-instr-params'},
                stin_dismiss_date => $params->{'place-instr-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'place-instr-end-date'}) : 'infinity',
                stin_note         => $self->app->helperEscapeParam($params->{'place-instr-notes'}),
                stin_master       => $self->app->helperGetBoolean($params, 'place-instr-first'),
            }, { stin_id => $params->{'place-id'} });
        }
    };

    # check result and return
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_instruments_check') != -1) {
            return -1;
        }
        elsif (index($@->{'message'}, 'metadata_stations_instruments_check2') != -1) {
            return -2;
        }
        else {
            return undef;
        }
    }
}

sub delete_instrument_by_id {
    my ( $self, $inid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti delete_instrument_by_id");
    $self->app->log->debug("inid: $inid");

    my $tx;

    eval {
        $tx =  $self->pg->db->begin;

        # query
        my $sql = qq{
            DELETE FROM metadata.stations_instruments
            WHERE instr_id = ?;
        };

        $self->pg->db->query($sql, $inid);

        $sql = qq{
            DELETE FROM equipments.instrument_attachments
            WHERE instr_id = ?;
        };

        $self->pg->db->query($sql, $inid);

        $sql = qq{
            DELETE FROM equipments.instruments
            WHERE instr_id = ?;
        };

        $self->pg->db->query($sql, $inid);
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

sub delete_attachment_by_id {
    my ( $self, $att_id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM equipments.instrument_attachments
        WHERE att_id = ?;
    };

    my $res = $self->pg->db->query($sql, $att_id);

    # check result and return
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub close_location_by_id {
    my( $self, $stinid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti close_location_by_id");

    my $res = $self->pg->db->update('metadata.stations_instruments', {
        stin_dismiss_date => $self->app->helperGetLocaleFullDate()
    }, { stin_id => $stinid });

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub check_instrument {
    my ( $self, $inid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti check_instrument");
    $self->app->log->debug("inid: $inid");

    # per controllo associazione con report tarature e planning query:
    my $sql = qq{
        SELECT check_flag AS result FROM equipments.f_check_instrument(?::integer);
    };

    my $flag = $self->pg->db->query($sql, $inid)->hash->{'result'};

    # return
    return $flag;
}

sub check_location {
    my ( $self, $stinid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfStrumenti check_location");
    $self->app->log->debug("stinid: $stinid");

    # per controllo associazione con report tarature, report manutenzioni, report alims e planning query:
    my $sql = qq{
        SELECT * FROM equipments.f_check_instrument_location(?::integer)
    };

    # return
    return $self->pg->db->query($sql, $stinid)->hash;
}

1;

=head1 get_instruments_types

Funzione che recupera tutte le tipologie di strumento disponibili dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_instruments_by_date

Funzione che recupera, dato un certo periodo temporale,
tutti gli strumenti disponibili dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della categoria di strumento, se presente ('cat');

Return:     Risultato della query.

=cut

=head1 get_instruments_by_date_station

Funzione che recupera, dato un certo periodo temporale e l'id di una stazione,
tutti gli strumenti dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della stazione, se presente ('stid');

           * id della categoria di strumento, se presente ('cat');

Return:     Risultato della query.

=cut

=head1 get_params_by_instr_type

Funzione che recupera i parametri associabili ad una determinata tipologia di strumento dal database.

Argomenti:  * id della stazione ('stid');

           * id della tipologia di strumento ('intyid');

Return:     Risultato della query.

=cut

=head1 get_instruments_for_location

Funzione che recupera gli strumenti non ancora stanziati dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_instrument_by_id

Funzione che recupera, dato l'id, le informazioni di un determinato strumento dal database.

Argomenti:  * id dello strumento ('inid');

Return:     Risultato della query.

=cut

=head1 get_location_by_id

Funzione che recupera, dato l'id, le informazioni di una determinata location dal database.

Argomenti:  * id della location ('stinid');

Return:     Risultato della query.

=cut

=head1 get_instrument_locations_history

Funzione che dato l'id dello strumento ne recupera lo storico degli stanziamenti, organizzandoli in un unico jsonb.
L'oggetto viene utilizzato per la costruzione di un GANTT

Argomenti:  * id dello strumento ('inid');

Return:     Risultato della query.

=cut

=head1 insert_new_instrument

Funzione che inserisce un nuovo strumento nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni dello strumento da inserire ('params');

Return:     Se tutto OK, restituisce l'id dello strumento appena inserito;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_attachment

Funzione che inserisce gli allegati di un determinato strumento nel database.

Argomenti:  * id dello strumento ('id');

           * nome originale dell'allegato ('original_name');

           * nuovo nome dell'allegato per l'archiviazione ('new_name');

           * valore booleano che indica se l'allegato e' un'immagine ('is_image');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 insert_new_location

Funzione che inserisce una nuova location nel database.

Argomenti:  * oggetto contenente le informazioni della location da inserire ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 'undef', oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 update_instrument_by_id

Funzione che modifica, dato l'id, un determinato strumento nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni dello strumento da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_location_by_id

Funzione che modifica, dato l'id, una determinata location nel database.

Argomenti:  * oggetto contenente le informazioni della location da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0, oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 delete_instrument_by_id

Funzione che elimina, dato l'id, un determinato strumento dal database.

Argomenti:  * id dello strumento ('inid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_attachment_by_id

Funzione che elimina, dato l'id, un determinato allegato dal database.

Argomenti:  * id dell'allegato ('att_id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 close_location_by_id

Funzione che effettua, dato l'id, la chiusura di una determinata location nel database.

Argomenti:  * id della location ('stinid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.


=cut

=head1 check_instrument

Funzione che verifica se un determinato strumento e' associato a qualche report taratura, oppure a qualche ticket.

Argomenti:  * id dello strumento ('inid');

Return:     Valore booleano TRUE/FALSE.

=cut

=head1 check_location

Funzione che verifica se una determinata location e' associata a qualche report taratura, oppure a qualche ticket.

Argomenti:  * id della location ('stinid');

Return:     Valore booleano TRUE/FALSE.

=cut