package Bobo::Model::DbcnfBombole;
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

sub get_cylinders_by_date {
    my ( $self, $user_id, $from, $to, $net ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfBombole sub get_cylinders_by_date");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                vc.cy_id,
                COALESCE(vc.cylinder_arpa_id, '--') AS cylinder_arpa_id,
                COALESCE(vc.cylinder_name   , '--') AS cylinder_name   ,
                vc.cylinder_mixture     ,
                vc.cylinder_is_zero     ,
                vc.cylinder_built_date  ,
                vc.cylinder_expiry_date ,
                vc.cylinder_ch_values   ,
                vc.cylinder_all_stations,
                vc.cylinder_active      ,
                vc.cylinder_is_exhausted,
                vc.cylinder_is_returned ,
                vsc.stcy_id AS location_id,
                CASE
                    WHEN vsc.station_name NOTNULL THEN vsc.station_name
                    WHEN vc.cylinder_all_stations IS TRUE THEN 'Tutte le stazioni'
                    ELSE '<i class="icon-close text-danger"></i>'
                END AS location,
                station_cy_startup_date AS location_start,
                CASE
                    WHEN station_cy_dismiss_date = 'infinity' THEN 'infinito'
                    WHEN station_cy_dismiss_date IS NULL THEN '--'
                    ELSE TO_CHAR(station_cy_dismiss_date, 'DD/MM/YYYY HH24:MI')
                END AS location_end
            FROM equipments.view_cylinders vc
            LEFT JOIN metadata.view_stations_cylinders vsc ON ( vc.cy_id = vsc.cy_id AND tsrange(vsc.station_cy_startup_date, vsc.station_cy_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
            WHERE vc.network_types && ARRAY(
                    SELECT st_network_id
                    FROM bobo.view_user_networks
                    WHERE user_id = ?
                )
            AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(vc.cylinder_built_date, vc.cylinder_expiry_date, '[]')
    };

    if ($net != -1) {
        $sql .= qq{ AND $net = ANY(vc.network_types) };
    }

    $sql .= qq{
        )
        SELECT *
        FROM t
        ORDER BY cylinder_built_date DESC;
    };

    # $self->app->log->debug($sql, $user_id, $from, $to);

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_cylinders_by_date_station {
    my ( $self, $user_id, $from, $to, $net, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfBombole sub get_cylinders_by_date_station");

    # query
    my $sql = qq{
        SELECT
            cy_id,
            COALESCE(cylinder_arpa_id, '--') AS cylinder_arpa_id,
            COALESCE(cylinder_name   , '--') AS cylinder_name   ,
            cylinder_mixture     ,
            cylinder_is_zero     ,
            cylinder_built_date  ,
            cylinder_expiry_date ,
            cylinder_ch_values   ,
            cylinder_all_stations,
            cylinder_active      ,
            cylinder_is_exhausted,
            cylinder_is_returned ,
            stcy_id AS location_id,
            CASE
                WHEN station_name NOTNULL THEN station_name
                ELSE '<i class="icon-close text-danger"></i>'
            END AS location,
            station_cy_startup_date AS location_start,
            CASE
                WHEN station_cy_dismiss_date = 'infinity' THEN 'infinito'
                WHEN station_cy_dismiss_date IS NULL THEN '--'
                ELSE TO_CHAR(station_cy_dismiss_date, 'DD/MM/YYYY HH24:MI')
            END AS location_end
        FROM metadata.view_stations_cylinders
        WHERE station_id IN (
                SELECT station_id
                FROM bobo.view_user_stations
                WHERE user_id = ?
            )
        AND tsrange(?::timestamp, ?::timestamp, '[]') && tsrange(station_cy_startup_date, station_cy_dismiss_date, '[]')
    };

    if ($net != -1) {
        $sql .= qq{ AND $net = ANY(network_types) };
    }

    if ($stid != -1) {
        $sql .= qq{ AND station_id = $stid };
    }

    $sql .= qq{
        ORDER BY station_cy_startup_date DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_cylinders_for_location {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfBombole sub get_cylinders_for_location");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                vc.cy_id,
                vc.cylinder_mixture ||
                COALESCE(' - '||vc.cylinder_name, '') ||
                COALESCE(' ['||vc.cylinder_arpa_id||']', '') AS cylinder_name,
                cylinder_expiry_date,
                vc.network_types,
                CASE
                    WHEN
                        (
                            SELECT TRUE
                            FROM metadata.stations_cylinders sc
                            WHERE vc.cy_id = sc.cy_id
                            AND tsrange(sc.stcy_startup_date, sc.stcy_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                        ) THEN 'hidden'
                    ELSE ''
                END AS cylinder_class

            FROM equipments.view_cylinders vc
            WHERE vc.network_types && ARRAY(
                    SELECT st_network_id
                    FROM bobo.view_user_networks
                    WHERE user_id = ?
                )
            -- AND tsrange(vc.cylinder_built_date, vc.cylinder_expiry_date, '[)')  @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')::timestamp
            AND vc.cylinder_built_date <= (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')::timestamp
            AND vc.cylinder_all_stations IS FALSE
            AND vc.cylinder_active IS TRUE
            AND vc.cylinder_is_exhausted IS FALSE
            AND vc.cylinder_is_returned IS FALSE
        )
        SELECT *
        FROM t
        ORDER BY 1;
    };

    # $self->app->log->debug($sql, $user_id, $from, $to);

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_cylinder_by_id {
    my ( $self, $cyid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfBombole sub get_cylinders_by_date");

    # query
    my $sql = qq{
        SELECT
            *,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        att_id          AS file_id,
                        file_original   AS file_name,
                        '/uploads/impostazioni/bombole/'||LPAD(cy_id::text, 9, '0')||'/'||file_archive AS file_path,
                        file_image
                    FROM
                        equipments.cylinder_attachments ca
                    WHERE ca.cy_id = vc.cy_id
                ) j
            ) AS cylinder_attachments,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(l)))
                FROM (
                    SELECT
                        stcy_id                     AS id,
                        station_id                  AS location_id,
                        vsi.station_name            AS location_name,
                        vsm.province_name           AS location_prov,
                        vsi.station_lat_wgs84       AS location_lat,
                        vsi.station_lon_wgs84       AS location_lon,
                        stcy_startup_date           AS location_start,
                        CASE
                            WHEN stcy_dismiss_date = 'infinity' THEN 'infinito'
                            ELSE TO_CHAR(stcy_dismiss_date, 'DD/MM/YYYY HH24:MI')
                        END                         AS location_end,
                        stcy_dismiss_date,
                        COALESCE(stcy_note, '--')   AS location_note
                    FROM
                        metadata.stations_cylinders sc
                        LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                        LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
                    WHERE sc.cy_id = vc.cy_id
                    ORDER BY stcy_startup_date DESC
                ) l
            ) AS cylinder_locations
        FROM equipments.view_cylinders vc
        WHERE cy_id = ?
    };

    # return
    return $self->pg->db->query($sql, $cyid)->hash();
}

sub get_location_by_id {
    my ( $self, $stcyid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbcnfBombole sub get_location_by_id");

    # query
    my $sql = qq{
        SELECT *
        FROM metadata.stations_cylinders
        WHERE stcy_id = ?
    };

    # return
    return $self->pg->db->query($sql, $stcyid)->hash();
}

sub insert_new_cylinder {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole insert_new_cylinder");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        # {
        #   "add-location" => "on",
        #   "loc-end-date" => "06/09/2021 09:31",
        #   "loc-notes" => "TEST NOTA LOCATION",
        #   "loc-prov" => 1,
        #   "loc-start-date" => "06/09/2021 09:31",
        #   "loc-stat" => 1004,
        #   "tank-active" => "on",
        #   "tank-arpa-id" => "OPAS0001",
        #   "tank-category" => 2,
        #   "tank-cy-id" => "",
        #   "tank-date-built" => "01/09/2021",
        #   "tank-date-expiry" => "30/09/2021",
        #   "tank-description" => "Test Miscela",
        #   "tank-exhausted" => "on",
        #   "tank-iszero" => "on",
        #   "tank-name" => "Test Nome",
        #   "tank-networks" => [
        #                        6,
        #                        1
        #                      ],
        #   "tank-not-compliant" => "on",
        #   "tank-note" => "TEST NOTA BOMBOLA",
        #   "tank-returned" => "on",
        #   "val-first" => "9.26",
        #   "val-second" => "",
        #   "val-third" => ""
        # }

        # ARRAY networks
        my @networks;
        if (ref($params->{'tank-networks'}) eq 'ARRAY') {
            @networks = @{$params->{'tank-networks'}};
        }
        else {
            push @networks, $params->{'tank-networks'};
        }

        # ARRAY value
        my @values;
        push @values, $params->{'val-first'};

        if (defined $params->{'val-second'} && $params->{'val-second'} ne '') {
            push @values, $params->{'val-second'};
        }

        if (defined $params->{'val-third'} && $params->{'val-third'} ne '') {
            push @values, $params->{'val-third'};
        }

        # INSERT INTO equipments.cylinders
        #     (cy_id, cy_arpa_id, cy_name, cy_mixture, category_id, cy_built_date, cy_expiry_date, cy_ch_values, cy_all_stations, cy_is_zero, cy_is_exhausted, cy_is_returned, cy_not_compliant, cy_active, cy_note, network_types )
        # VALUES
        #     (DEFAULT, 'OPAS00001', 'Pluto', 'NO 79,80 ppm', 2, '2020-02-07'::date, '2021-08-07'::date, '{80.01, 79.8, 0.3}'::real[],  TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Nota di esempio', '{1}'::integer[]   ), -- 1
        #     (DEFAULT, 'OPAS46657', NULL   , 'CO'          , 3, '2020-01-09'::date, '2022-01-09'::date, '{10.35}'::real[]           , FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, NULL             , '{2,3}'::integer[] )  -- 2

        # RETURNING cy_id;

        $id = $self->pg->db->insert('equipments.cylinders', {
            #id                     => # id progressivo
            cy_arpa_id          => $self->app->helperEscapeParam($params->{'tank-arpa-id'}),
            cy_name             => $self->app->helperEscapeParam($params->{'tank-name'}),
            cy_mixture          => $self->app->helperEscapeParam($params->{'tank-description'}),
            category_id         => $params->{'tank-category'},
            cy_built_date       => $self->app->helperGetFormattedFulldate($params->{'tank-date-built'}),
            cy_expiry_date      => $self->app->helperGetFormattedFulldate($params->{'tank-date-expiry'}),
            cy_ch_values        => \@values,
            cy_all_stations     => $self->app->helperGetBoolean($params, 'tank-all-stations'),
            cy_is_zero          => $self->app->helperGetBoolean($params, 'tank-iszero'),
            cy_is_exhausted     => $self->app->helperGetBoolean($params, 'tank-exhausted'),
            cy_is_returned      => $self->app->helperGetBoolean($params, 'tank-returned'),
            cy_not_compliant    => $self->app->helperGetBoolean($params, 'tank-not-compliant'),
            cy_active           => $self->app->helperGetBoolean($params, 'tank-active'),
            cy_note             => $self->app->helperEscapeParam($params->{'tank-note'}),

            network_types       => \@networks,
            insert_user         => $userid

        }, {returning => 'cy_id'})->hash->{'cy_id'};

        if (defined $params->{'add-location'} && $params->{'add-location'} ne '') {
            $self->pg->db->insert('metadata.stations_cylinders', {
                # id                => # id progressivo
                station_id        => $params->{'loc-stat'},
                cy_id             => $id,
                stcy_startup_date => $self->app->helperGetFormattedFulldate($params->{'loc-start-date'}),
                stcy_dismiss_date => $params->{'loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'loc-end-date'}) : 'infinity',
                stcy_note         => $self->app->helperEscapeParam($params->{'loc-notes'})
            });
        }
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
       $tx->commit;
       return $id;
    }
}

sub insert_new_attachment {
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    # query
    my $res = $self->pg->db->insert('equipments.cylinder_attachments', {
        cy_id         => $id,
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
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole insert_new_location");

    # {
    #   "modal-loc-end-date" => "16/09/2021 10:59",
    #   "modal-loc-id" => 1,
    #   "modal-loc-notes" => "prova location Modifica",
    #   "modal-loc-prov" => -1,
    #   "modal-loc-start-date" => "01/09/2021 09:11",
    #   "modal-loc-stat" => 1004,
    #   "modal-networks" => "[1]",
    #   "modal-loc-tank" => 2
    # }

    my $id;

    eval{
        $id = $self->pg->db->insert('metadata.stations_cylinders', {
            # id                => # id progressivo
            station_id        => $params->{'modal-loc-stat'},
            cy_id             => $params->{'modal-loc-tank'},
            stcy_startup_date => $self->app->helperGetFormattedFulldate($params->{'modal-loc-start-date'}),
            stcy_dismiss_date => $params->{'modal-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'modal-loc-end-date'}) : 'infinity',
            stcy_note         => $self->app->helperEscapeParam($params->{'modal-loc-notes'})
        }, {returning => 'stcy_id'})->hash->{'stcy_id'};
    };

    if (defined $id) {
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_cylinders_check') != -1) {
            return -1;
        }
        else {
            return undef;
        }
    }
}

sub update_cylinder_by_id {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole update_cylinder_by_id");

    # {
    #   "add-location" => "on",
    #   "loc-end-date" => "06/09/2021 09:31",
    #   "loc-notes" => "TEST NOTA LOCATION",
    #   "loc-prov" => 1,
    #   "loc-start-date" => "06/09/2021 09:31",
    #   "loc-stat" => 1004,
    #   "tank-active" => "on",
    #   "tank-arpa-id" => "OPAS0001",
    #   "tank-category" => 2,
    #   "tank-cy-id" => "",
    #   "tank-date-built" => "01/09/2021",
    #   "tank-date-expiry" => "30/09/2021",
    #   "tank-description" => "Test Miscela",
    #   "tank-exhausted" => "on",
    #   "tank-iszero" => "on",
    #   "tank-name" => "Test Nome",
    #   "tank-networks" => [
    #                        6,
    #                        1
    #                      ],
    #   "tank-not-compliant" => "on",
    #   "tank-note" => "TEST NOTA BOMBOLA",
    #   "tank-returned" => "on",
    #   "val-first" => "9.26",
    #   "val-second" => "",
    #   "val-third" => ""
    # }

    # ARRAY networks
    my @networks;
    if (ref($params->{'tank-networks'}) eq 'ARRAY'){
        @networks = @{$params->{'tank-networks'}};
    }
    else {
        push @networks, $params->{'tank-networks'};
    }

    # ARRAY value
    my @values;
    push @values, $params->{'val-first'};

    if (defined $params->{'val-second'} && $params->{'val-second'} ne '') {
        push @values, $params->{'val-second'};
    }

    if (defined $params->{'val-third'} && $params->{'val-third'} ne '') {
        push @values, $params->{'val-third'};
    }

    # INSERT INTO equipments.cylinders
    #     (cy_id, cy_arpa_id, cy_name, cy_mixture, category_id, cy_built_date, cy_expiry_date, cy_ch_values, cy_all_stations, cy_is_zero, cy_is_exhausted, cy_is_returned, cy_not_compliant, cy_active, cy_note, network_types )
    # VALUES
    #     (DEFAULT, 'OPAS00001', 'Pluto', 'NO 79,80 ppm', 2, '2020-02-07'::date, '2021-08-07'::date, '{80.01, 79.8, 0.3}'::real[],  TRUE, FALSE, FALSE, FALSE, FALSE, TRUE, 'Nota di esempio', '{1}'::integer[]   ), -- 1
    #     (DEFAULT, 'OPAS46657', NULL   , 'CO'          , 3, '2020-01-09'::date, '2022-01-09'::date, '{10.35}'::real[]           , FALSE, FALSE, FALSE, FALSE, FALSE, TRUE, NULL             , '{2,3}'::integer[] )  -- 2

    # RETURNING cy_id;

    my $res = $self->pg->db->update('equipments.cylinders', {
        # id               => # id progressivo
        cy_arpa_id       => $self->app->helperEscapeParam($params->{'tank-arpa-id'}),
        cy_name          => $self->app->helperEscapeParam($params->{'tank-name'}),
        cy_mixture       => $self->app->helperEscapeParam($params->{'tank-description'}),
        category_id      => $params->{'tank-category'},
        cy_built_date    => $self->app->helperGetFormattedFulldate($params->{'tank-date-built'}),
        cy_expiry_date   => $self->app->helperGetFormattedFulldate($params->{'tank-date-expiry'}),
        cy_ch_values     => \@values,
        cy_all_stations  => $self->app->helperGetBoolean($params, 'tank-all-stations'),
        cy_is_zero       => $self->app->helperGetBoolean($params, 'tank-iszero'),
        cy_is_exhausted  => $self->app->helperGetBoolean($params, 'tank-exhausted'),
        cy_is_returned   => $self->app->helperGetBoolean($params, 'tank-returned'),
        cy_not_compliant => $self->app->helperGetBoolean($params, 'tank-not-compliant'),
        cy_active        => $self->app->helperGetBoolean($params, 'tank-active'),
        cy_note          => $self->app->helperEscapeParam($params->{'tank-note'}),

        network_types    => \@networks
    }, {cy_id => $params->{'tank-cy-id'}});

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
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole update_location_by_id");

    # {
    #   "modal-loc-end-date" => "16/09/2021 10:59",
    #   "modal-loc-id" => 1,
    #   "modal-loc-notes" => "prova location Modifica",
    #   "modal-loc-prov" => -1,
    #   "modal-loc-start-date" => "01/09/2021 09:11",
    #   "modal-loc-stat" => 1004,
    #   "modal-networks" => "[1]",
    #   "modal-loc-tank" => 2
    # }

    my $res;

    eval {
        if (defined $params->{'modal-loc-stat'}) {
            $res = $self->pg->db->update('metadata.stations_cylinders', {
                station_id        => $params->{'modal-loc-stat'},
                stcy_startup_date => $self->app->helperGetFormattedFulldate($params->{'modal-loc-start-date'}),
                stcy_dismiss_date => $params->{'modal-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'modal-loc-end-date'}) : 'infinity',
                stcy_note         => $self->app->helperEscapeParam($params->{'modal-loc-notes'})
            }, {stcy_id => $params->{'modal-loc-id'}});
        }
        else {
            $res = $self->pg->db->update('metadata.stations_cylinders', {
                stcy_dismiss_date => $params->{'modal-loc-end-date'} ne '' ? $self->app->helperGetFormattedFulldate($params->{'modal-loc-end-date'}) : 'infinity',
                stcy_note         => $self->app->helperEscapeParam($params->{'modal-loc-notes'})
            }, {stcy_id => $params->{'modal-loc-id'}});
        }
    };

    if (defined $res) {
        return 1;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        if (index($@->{'message'}, 'metadata_stations_cylinders_check') != -1) {
            return -1;
        }
        else {
            return 0;
        }
    }
}

sub delete_cylinder_by_id {
    my ( $self, $cyid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole delete_cylinder_by_id");
    $self->app->log->debug("cyid: $cyid");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # query
        my $sql = qq{
            DELETE FROM metadata.stations_cylinders
            WHERE cy_id = ?;
        };

        $self->pg->db->query($sql, $cyid);

        $sql = qq{
            DELETE FROM equipments.cylinder_attachments
            WHERE cy_id = ?;
        };

        $self->pg->db->query($sql, $cyid);

        $sql = qq{
            DELETE FROM equipments.cylinders
            WHERE cy_id = ?;
        };

        $self->pg->db->query($sql, $cyid);
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
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM equipments.cylinder_attachments
        WHERE att_id = ?;
    };

    # return
    my $res = $self->pg->db->query($sql, $att_id);
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub close_location_by_id {
    my( $self, $stcyid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole close_location_by_id");

    # my $sql = qq{
    #     UPDATE metadata.stations_cylinders
    #     SET stcy_dismiss_date = ( DATE_TRUNC('hour', ?::timestamp ) )::timestamp
    #     WHERE stcy_id = ?;
    # };

    my $res = $self->pg->db->update('metadata.stations_cylinders', {
        stcy_dismiss_date => $self->app->helperGetLocaleFullDate()
    }, {stcy_id => $stcyid });

    # error check
    # my $res = $self->pg->db->query($sql, $self->app->helperGetLocaleFullDate(), $stcyid);
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub check_cylinder {
    my ( $self, $cyid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole check_cylinder");
    $self->app->log->debug("cyid: $cyid");

    # per controllo associazione con report tarature e planning query:
    # query
    my $sql = qq{
        WITH t1 AS (
            SELECT COUNT(*) AS s
            FROM reports.calibrations c,
                jsonb_each_text(c.calib_values)
            WHERE key ~ 'tank'
            AND value::integer = ?
        ),
        t2 AS (
            SELECT COUNT(*) AS s
            FROM reports.tickets
            WHERE cy_id::integer = ?
        )
        SELECT
            CASE WHEN t1.s + t2.s > 0 THEN TRUE
            ELSE FALSE
            END AS result
        FROM t1, t2;
    };

    my $flag = $self->pg->db->query($sql, $cyid, $cyid)->hash->{'result'};

    # return
    return $flag;
}

sub check_location {
    my ( $self, $stcyid ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbcnfBombole check_location");
    $self->app->log->debug("stcyid: $stcyid");

    # per controllo associazione con report tarature e planning query:

    # station_id
    # cy_id
    # stcy_startup_date
    # stcy_dismiss_date

    # query
    my $sql = qq{
        WITH t1 AS (
            SELECT *
            FROM metadata.stations_cylinders
            WHERE stcy_id = ?
        ),
        t2 AS (
            SELECT COUNT(*) AS s
            FROM t1
            LEFT JOIN reports.calibrations c ON (t1.station_id = c.station_id AND tsrange(t1.stcy_startup_date, t1.stcy_dismiss_date, '[)') @> c.calib_fulldate ),
                jsonb_each_text(c.calib_values)
            WHERE key ~ 'tank'
            AND value::integer = t1.cy_id
        ),
        t3 AS (
            SELECT COUNT(*) AS s
            FROM t1
            LEFT JOIN reports.tickets t ON (t1.station_id = t.station_id AND tsrange(t1.stcy_startup_date, t1.stcy_dismiss_date, '[)') @> t.tk_opening_date )
            WHERE t.cy_id::integer = t1.cy_id
        )
        SELECT
            CASE
                WHEN t2.s + t3.s > 0 THEN TRUE
                ELSE FALSE
            END AS result
        FROM t2, t3;
    };

    my $flag = $self->pg->db->query($sql, $stcyid)->hash->{'result'};

    # return
    return $flag;
}

1;

=head1 get_cylinders_by_date

Funzione che, dato un certo periodo temporale, recupera tutte le bombole disponibili dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

Return:     Risultato della query.

=cut

=head1 get_cylinders_by_date_station

Funzione che, dato un certo periodo temporale e l'id di una stazione, recupera tutte le bombole dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della stazione, se presente ('stid');

Return:     Risultato della query.

=cut

=head1 get_cylinders_for_location

Funzione che recupera le bombole non ancora stanziate dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_cylinder_by_id

Funzione che, dato l'id, recupera le informazioni di una determinata bombola dal database.

Argomenti:  * id della bombola ('cyid');

Return:     Risultato della query.

=cut

=head1 get_location_by_id

Funzione che, dato l'id, recupera le informazioni di una determinata location dal database.

Argomenti:  * id della location ('stcyid');

Return:     Risultato della query.

=cut

=head1 insert_new_cylinder

Funzione che inserisce una nuova bombola nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni della bombola da inserire ('params');

Return:     Se tutto OK, restituisce l'id della bombola appena inserita;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_new_attachment

Funzione che inserisce nel database gli allegati di una determinata bombola.

Argomenti:  * id della bombola ('id');

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

=head1 update_cylinder_by_id

Funzione che, dato l'id, modifica una determinata bombola nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni della bombola da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_location_by_id

Funzione che, dato l'id, modifica una determinata location nel database.

Argomenti:  * oggetto contenente le informazioni della location da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0, oppure -1 qualora sia presente un messaggio d'errore.

=cut

=head1 delete_cylinder_by_id

Funzione che, dato l'id, elimina una determinata bombola dal database.

Argomenti:  * id della bombola ('cyid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_attachment_by_id

Funzione che, dato l'id, elimina un determinato allegato dal database.

Argomenti:  * id dell'allegato ('att_id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 close_location_by_id

Funzione che, dato l'id, effettua la chiusura di una determinata location nel database.

Argomenti:  * id della location ('stcyid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.


=cut

=head1 check_cylinder

Funzione che verifica se una determinata bombola e' associata a qualche report taratura, oppure a qualche ticket.

Argomenti:  * id della bombola ('cyid');

Return:     Valore booleano TRUE/FALSE.

=cut

=head1 check_location

Funzione che verifica se la bombola durante una determinata location e' associata a qualche report taratura, oppure a qualche ticket.

Argomenti:  * id della location ('stcyid');

Return:     Valore booleano TRUE/FALSE.

=cut