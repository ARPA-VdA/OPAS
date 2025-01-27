package Bobo::Model::Dbqatarature;
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

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

sub get_cylinder_by_id {
    my ( $self, $cyid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_cylinder_by_id");

    # query
    my $sql = qq{
        SELECT
            COALESCE(cylinder_arpa_id, '--') AS cylinder_arpa_id,
            cylinder_name,
            cylinder_mixture,
            cylinder_mixture
            || COALESCE(' - '||cylinder_name, '')
            || COALESCE(' ['||cylinder_arpa_id||']', '') AS cylinder_fullname,
            cylinder_ch_values

        FROM equipments.view_cylinders vc
        WHERE cy_id = ?
    };

    # return
    return $self->pg->db->query($sql, $cyid)->hash();
}

sub get_cylinders_by_category {
    my ( $self, $user_id, $stid, $cat, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_cylinders_by_category");

    # query
    my $sql = qq{
        WITH t AS (
                SELECT
                    vc.cy_id,
                    vc.cylinder_arpa_id     ,
                    vc.cylinder_name        ,
                    vc.cylinder_mixture     ,
                    cylinder_mixture
                    || COALESCE(' - '||cylinder_name, '')
                    || COALESCE(' ['||cylinder_arpa_id||']', '') AS cylinder_fullname,
                    vc.cylinder_is_zero     ,
                    vc.cylinder_expiry_date ,
                    vc.cylinder_ch_values   ,
                    vc.cylinder_all_stations,
                    vc.cylinder_active      ,
                    vc.category_id
                FROM
                    equipments.view_cylinders vc
                WHERE vc.network_types && ARRAY(
                        SELECT st_network_id
                        FROM bobo.view_user_networks
                        WHERE user_id = ? -- user_id
                    )
                AND vc.cylinder_all_stations IS TRUE
                -- AND tsrange(vc.cylinder_built_date, vc.cylinder_expiry_date, '[]') @> ?::timestamp
                AND vc.cylinder_built_date <= ?::timestamp
                AND vc.cylinder_is_exhausted IS FALSE
                AND vc.cylinder_is_returned IS FALSE
            UNION
                SELECT
                    cy_id,
                    cylinder_arpa_id     ,
                    cylinder_name        ,
                    cylinder_mixture     ,
                    cylinder_mixture
                    || COALESCE(' - '||cylinder_name, '')
                    || COALESCE(' ['||cylinder_arpa_id||']', '') AS cylinder_fullname,
                    cylinder_is_zero     ,
                    cylinder_expiry_date ,
                    cylinder_ch_values   ,
                    cylinder_all_stations,
                    cylinder_active      ,
                    category_id
                FROM
                    metadata.view_stations_cylinders
                WHERE station_id = ? -- station_id
                AND tsrange(station_cy_startup_date, station_cy_dismiss_date, '[]') @> ?::timestamp
        )
        SELECT *
        FROM t
        WHERE cylinder_active IS TRUE
        AND category_id = ? -- category id dello strumento
        ORDER BY cylinder_fullname;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $dt, $stid, $dt, $cat)->hashes();
}

sub get_method_by_id {
    my ( $self, $meid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_method_by_id");

    # query
    my $sql = qq{
        SELECT
            calib_me_id     AS method_id,
            calib_me_name   AS method_name
        FROM reports.calibration_methods
        WHERE calib_me_id = ?;
    };

    # TODO da aggiungere filtro per categoria
    # $cat

    # return
    return $self->pg->db->query($sql, $meid)->hash();
}

sub get_methods_by_category {
    my ( $self, $cat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_methods_by_category");

    # query
    my $sql = qq{
        SELECT
            calib_me_id     AS method_id,
            calib_me_name   AS method_name
        FROM reports.calibration_methods
        ORDER BY calib_me_name;
    };

    # TODO da aggiungere filtro per categoria
    # $cat

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_reasons {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_reasons");

    # query
    my $sql = qq{
        SELECT
            calib_re_id AS reason_id,
            calib_re_name AS reason_name
        FROM
            reports.calibration_reasons
        ORDER BY
            calib_re_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_calibrators {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_calibrators");

    # query
    my $sql = qq{
        SELECT
            instr_id,
            instr_type_fullname || COALESCE(' - '||instrument_name, '') AS instr_fullname
        FROM equipments.view_instruments vi
        WHERE category_id = 19
        AND vi.network_types && ARRAY(
            SELECT st_network_id
            FROM bobo.view_user_networks
            WHERE user_id = ?
        )
        ORDER BY instr_type_fullname;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_calibrator_by_id {
     my ( $self, $instr_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_calibrator_by_id");

    # query
    my $sql = qq{
        SELECT
            instr_type_fullname || COALESCE(' - '||instrument_name, '') AS instr_fullname,
            COALESCE(instrument_arpa_id, '-') AS instrument_arpa_id
        FROM equipments.view_instruments
        WHERE instr_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $instr_id)->hash();
}

sub get_reports_by_date_province {
    my ( $self, $user_id, $from, $to, $net, $prid, $catid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_reports_by_date_province");

    # query
    my $sql = qq{
        WITH t AS(
            -- NOT USED
            -- SELECT
            --     CASE
            --         WHEN um.comp_id = pp.admin_comp_id THEN linked_comp_id
            --         ELSE ARRAY[um.comp_id]
            --     END AS comps
            -- FROM bobo.users_metadata um
            -- LEFT JOIN bobo.portal_properties pp USING (portal_id)
            -- WHERE us_id = ?

            SELECT
                um.comp_id AS user_comp
            FROM bobo.users_metadata um
            WHERE us_id = ?
        )
        SELECT
            vc.calib_id        ,
            vc.us_id           ,
            vc.user_fullname   ,
            vc.user_avatar_thumb,
            vc.station_id      ,
            vc.station_name    ,
            snt.st_network_name AS network_name,
            vc.instr_id        ,
            vc.instr_type_id   ,
            vit.instr_type_fullname,
            vit.instr_type_fullname || COALESCE(' - ' || vc.instr_name, '') AS instr_fullname,
            vit.category_id     ,
            vit.category_name   ,
            vc.instr_name       ,
            vc.calib_fulldate   ,
            vc.calib_multipoint ,
            vc.calib_values     ,

            CASE vit.category_id
                WHEN  1 THEN COALESCE( calib_values ->> 'mod-zero-so2', 'off' )::boolean
                WHEN  2 THEN COALESCE( calib_values ->> 'mod-zero-noxnono2', 'off' )::boolean
                WHEN  3 THEN COALESCE( calib_values ->> 'mod-zero-co', 'off' )::boolean
                WHEN  4 THEN COALESCE( calib_values ->> 'mod-zero-o3', 'off' )::boolean
                WHEN  5 THEN COALESCE( calib_values ->> 'mod-zero-btx', 'off' )::boolean
                WHEN  7 THEN COALESCE( calib_values ->> 'mod-zero-ch4', 'off' )::boolean
                WHEN 25 THEN COALESCE( calib_values ->> 'mod-zero-biogas', 'off' )::boolean
                ELSE NULL
            END AS zero_mod,
            CASE vit.category_id
                WHEN  1 THEN COALESCE( calib_values ->> 'mod-span-so2', 'off' )::boolean
                WHEN  2 THEN COALESCE( calib_values ->> 'mod-span-noxnono2', 'off' )::boolean
                WHEN  3 THEN COALESCE( calib_values ->> 'mod-span-co', 'off' )::boolean
                WHEN  4 THEN COALESCE( calib_values ->> 'mod-span-o3', 'off' )::boolean
                WHEN  5 THEN COALESCE( calib_values ->> 'mod-span-btx', 'off' )::boolean
                WHEN  7 THEN COALESCE( calib_values ->> 'mod-span-ch4', 'off' )::boolean
                WHEN 25 THEN COALESCE( calib_values ->> 'mod-span-biogas', 'off' )::boolean
                ELSE NULL
            END AS span_mod,
            CASE vit.category_id
                WHEN 1 THEN calib_values ->> 'read-span-so2'
                WHEN 2 THEN COALESCE( NULLIF( (calib_values ->> 'read-nox-span-noxnono2'), '') ||', '||(calib_values ->> 'read-no-span-noxnono2')||', '||(calib_values ->> 'read-no2-span-noxnono2'), '')
                WHEN 3 THEN calib_values ->> 'read-span-co'
                WHEN 4 THEN calib_values ->> 'read-span-o3'
                WHEN 5 THEN COALESCE( NULLIF( (calib_values ->> 'read-ben-span-btx'), '') ||', '||(calib_values ->> 'read-tol-span-btx')||', '||(calib_values ->> 'read-xil-span-btx'), '' )
                WHEN 7 THEN COALESCE( NULLIF( (calib_values ->> 'read-span-ch4'), '') ||', '||(calib_values ->> 'read-span-tnmhc'), '' )
                ELSE ''
            END AS span_found,
            CASE vit.category_id

                WHEN 1 THEN calib_values ->> 'find-zero-so2'
                WHEN 2 THEN COALESCE( NULLIF( (calib_values ->> 'nox-zero-noxnono2'), '') ||', '||(calib_values ->> 'no-zero-noxnono2')||', '||(calib_values ->> 'no2-zero-noxnono2'), '' )
                WHEN 3 THEN calib_values ->> 'find-zero-co'
                WHEN 4 THEN calib_values ->> 'find-zero-o3'
                WHEN 5 THEN COALESCE( NULLIF( (calib_values ->> 'find-ben-zero-btx'), '') ||', '||(calib_values ->> 'find-tol-zero-btx')||', '||(calib_values ->> 'find-xil-zero-btx'), '' )
                WHEN 7 THEN COALESCE( NULLIF( (calib_values ->> 'find-zero-ch4'), '') ||', '||(calib_values ->> 'find-zero-tnmhc'), '' )
                ELSE ''

            END AS zero_found,

            vc.calib_note       ,
            CASE
                WHEN um.comp_id = (SELECT user_comp FROM t) THEN TRUE
                ELSE FALSE
            END  AS user_has_grants

        FROM
            reports.view_calibrations vc
            LEFT JOIN bobo.users_metadata um                    ON um.us_id = vc.us_id
            LEFT JOIN equipments.view_instruments_type vit      USING (instr_type_id)
            LEFT JOIN metadata.stations_info sm                 USING (station_id)
            LEFT JOIN metadata.stations_network_type snt        ON snt.st_network_id = sm.st_info_network_type_fk
            LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
            LEFT JOIN bobo.view_user_stations vus USING (station_id)

        WHERE
            vus.user_id = ?

        -- solo report degli utenti delle aziende che puoi visualizzare
        -- NOT USED
        -- AND um.comp_id IN (SELECT UNNEST(comps) FROM t)

        AND vc.calib_fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($net != -1) {
        $sql .= qq{ AND sm.st_info_network_type_fk = $net }
    }

    if ($prid != -1) {
        $sql .= qq{ AND vsm.province_id = $prid }
    }

    if ($catid != -1) {
        $sql .= qq{ AND vit.category_id = $catid }
    }

    $sql .= qq{
        ORDER BY vc.calib_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $from, $to)->hashes();
}

sub get_reports_by_date_station {
    my ( $self, $user_id, $from, $to, $stid, $catid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_reports_by_date_station");

    # query
    my $sql = qq{
         WITH t AS(
            SELECT
                um.comp_id AS user_comp
            FROM bobo.users_metadata um
            WHERE us_id = ?
        )
        SELECT
            vc.calib_id        ,
            vc.us_id           ,
            vc.user_fullname   ,
            vc.user_avatar_thumb,
            vc.station_id      ,
            vc.station_name    ,
            snt.st_network_name AS network_name,
            vc.instr_id        ,
            vc.instr_type_id   ,
            vit.instr_type_fullname,
            vit.instr_type_fullname || COALESCE(' - ' || vc.instr_name, '') AS instr_fullname,
            vit.category_id     ,
            vit.category_name   ,
            vc.instr_name       ,
            vc.calib_fulldate   ,
            vc.calib_multipoint ,
            vc.calib_values     ,
            CASE vit.category_id
                WHEN  1 THEN COALESCE( calib_values ->> 'mod-zero-so2', 'off' )::boolean
                WHEN  2 THEN COALESCE( calib_values ->> 'mod-zero-noxnono2', 'off' )::boolean
                WHEN  3 THEN COALESCE( calib_values ->> 'mod-zero-co', 'off' )::boolean
                WHEN  4 THEN COALESCE( calib_values ->> 'mod-zero-o3', 'off' )::boolean
                WHEN  5 THEN COALESCE( calib_values ->> 'mod-zero-btx', 'off' )::boolean
                WHEN  7 THEN COALESCE( calib_values ->> 'mod-zero-ch4', 'off' )::boolean
                WHEN 25 THEN COALESCE( calib_values ->> 'mod-zero-biogas', 'off' )::boolean
                ELSE NULL
            END AS zero_mod,
            CASE vit.category_id
                WHEN  1 THEN COALESCE( calib_values ->> 'mod-span-so2', 'off' )::boolean
                WHEN  2 THEN COALESCE( calib_values ->> 'mod-span-noxnono2', 'off' )::boolean
                WHEN  3 THEN COALESCE( calib_values ->> 'mod-span-co', 'off' )::boolean
                WHEN  4 THEN COALESCE( calib_values ->> 'mod-span-o3', 'off' )::boolean
                WHEN  5 THEN COALESCE( calib_values ->> 'mod-span-btx', 'off' )::boolean
                WHEN  7 THEN COALESCE( calib_values ->> 'mod-span-ch4', 'off' )::boolean
                WHEN 25 THEN COALESCE( calib_values ->> 'mod-span-biogas', 'off' )::boolean
                ELSE NULL
            END AS span_mod,
            CASE vit.category_id
                WHEN 1 THEN calib_values ->> 'read-span-so2'
                WHEN 2 THEN COALESCE( NULLIF( (calib_values ->> 'read-nox-span-noxnono2'), '') ||', '||(calib_values ->> 'read-no-span-noxnono2')||', '||(calib_values ->> 'read-no2-span-noxnono2'), '')
                WHEN 3 THEN calib_values ->> 'read-span-co'
                WHEN 4 THEN calib_values ->> 'read-span-o3'
                WHEN 5 THEN COALESCE( NULLIF( (calib_values ->> 'read-ben-span-btx'), '') ||', '||(calib_values ->> 'read-tol-span-btx')||', '||(calib_values ->> 'read-xil-span-btx'), '' )
                WHEN 7 THEN COALESCE( NULLIF( (calib_values ->> 'read-span-ch4'), '') ||', '||(calib_values ->> 'read-span-tnmhc'), '' )
                ELSE ''
            END AS span_found,
            CASE vit.category_id

                WHEN 1 THEN calib_values ->> 'find-zero-so2'
                WHEN 2 THEN COALESCE( NULLIF( (calib_values ->> 'nox-zero-noxnono2'), '') ||', '||(calib_values ->> 'no-zero-noxnono2')||', '||(calib_values ->> 'no2-zero-noxnono2'), '' )
                WHEN 3 THEN calib_values ->> 'find-zero-co'
                WHEN 4 THEN calib_values ->> 'find-zero-o3'
                WHEN 5 THEN COALESCE( NULLIF( (calib_values ->> 'find-ben-zero-btx'), '') ||', '||(calib_values ->> 'find-tol-zero-btx')||', '||(calib_values ->> 'find-xil-zero-btx'), '' )
                WHEN 7 THEN COALESCE( NULLIF( (calib_values ->> 'find-zero-ch4'), '') ||', '||(calib_values ->> 'find-zero-tnmhc'), '' )
                ELSE ''

            END AS zero_found,
            vc.calib_note       ,
            CASE
                WHEN um.comp_id = (SELECT user_comp FROM t) THEN TRUE
                ELSE FALSE
            END  AS user_has_grants

        FROM
            reports.view_calibrations vc
            LEFT JOIN bobo.users_metadata um                    ON um.us_id = vc.us_id
            LEFT JOIN metadata.stations_info sm                 USING (station_id)
            LEFT JOIN metadata.stations_network_type snt        ON snt.st_network_id = sm.st_info_network_type_fk
            LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        WHERE
            vc.calib_fulldate BETWEEN ?::timestamp AND ?::timestamp

        AND vc.station_id = ?
    };

    if ($catid != -1) {
        $sql .= qq{ AND vit.category_id = $catid }
    }

    $sql .= qq{
        ORDER BY vc.calib_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $stid)->hashes();
}

sub get_reports_events_by_dates {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_reports_events_by_date");

    # query
    my $sql = qq{
        SELECT
            vc.calib_id        ,
            vc.us_id           ,
            vc.user_fullname   ,
            c.comp_name AS company_name,
            vc.station_id      ,
            vc.station_name    ,
            snt.st_network_name AS network_name,
            vit.instr_type_fullname,
            vit.category_name   ,
            vc.instr_name       ,
            vc.calib_fulldate::date  AS calib_fulldate,
            TO_CHAR(vc.calib_fulldate, 'HH24:MI')  AS calib_hour,
            vc.calib_multipoint ,
            vc.calib_values
        FROM
            reports.view_calibrations vc
            LEFT JOIN bobo.users_metadata um                    ON um.us_id = vc.us_id
            LEFT JOIN bobo.companies c                          USING (comp_id)
            LEFT JOIN equipments.view_instruments_type vit      USING (instr_type_id)
            LEFT JOIN metadata.stations_info sm                 USING (station_id)
            LEFT JOIN metadata.stations_network_type snt        ON snt.st_network_id = sm.st_info_network_type_fk
            LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
            LEFT JOIN bobo.view_user_stations vus               USING (station_id)
        WHERE
            vus.user_id = ?
        AND vc.calib_fulldate BETWEEN ?::timestamp AND ?::timestamp
        ORDER BY vc.calib_fulldate ASC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub get_methods_by_category");

    # query
    my $sql = qq{
        SELECT
            vc.calib_id        ,
            vc.us_id           ,
            vc.user_fullname   ,
            vc.station_id      ,
            vc.station_name    ,
            vsm.province_id,
            vsm.province_name,
            vc.instr_id        ,
            vc.instr_type_id   ,
            vit.instr_type_fullname,
            vit.category_id     ,
            vit.category_name   ,
            COALESCE(vc.instr_arpa_id   , '--') AS instr_arpa_id,
            COALESCE(vc.instr_serial_num, '--') AS instr_serial_num,
            COALESCE(vc.instr_name      , '--') AS instr_name      ,
            vit.instr_type_fullname || COALESCE(' - '|| vc.instr_name, '') AS instr_fullname,
            COALESCE(vit.instr_type_unit, '')   AS instr_unit,
            vc.calib_fulldate  ,
            vc.calib_fulldate_formatted,
            vc.calib_re_id           ,
            vc.calib_reason          ,
            vc.calib_multipoint      ,
            vc.calib_values          ,
            vc.calib_note            ,
            -- Allegati
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        ca.att_id,
                        lpad(ca.calib_id::text , 9, '0')||'/'||ca.file_archive AS file_archive,
                        ca.file_image,
                        ca.file_original
                    FROM
                        reports.calibration_attachments ca
                    WHERE ca.calib_id = vc.calib_id
                ) j
            ) AS attachments
        FROM reports.view_calibrations vc
        LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
        WHERE calib_id = ?
    };

    # TODO da aggiungere filtro per categoria
    # $cat

    # return
    return $self->pg->db->query($sql, $rpid)->hash();
}

sub insert_report {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub insert_report");

    return  $self->pg->db->insert('reports.calibrations', {
        us_id            => $user_id,
        station_id       => $params->{'station-calib'},
        instr_id         => $params->{'instrument-calib'},
        calib_fulldate   => $self->app->helperGetFormattedFulldate($params->{'datetime-calib'}),
        calib_re_id      => $params->{'reason-calib'},
        calib_multipoint => $self->app->helperGetBoolean($params, 'flag-multi'),
        calib_values     => $params->{'obj-calib'},
        calib_note       => $self->app->helperEscapeParam($params->{'notes-calib'}),
    }, { returning => 'calib_id' })->hash->{'calib_id'};
}

sub insert_new_attachment {
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::Dbqatarature insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    return $self->pg->db->insert('reports.calibration_attachments', {
        # att_id        => # id progressivo
        calib_id      => $id,
        file_original => $original_name,
        file_archive  => $new_name,
        file_image    => $is_image
        # att_fulldate  => # default data attuale
    });
}

sub update_report {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub update_report");

    return  $self->pg->db->update('reports.calibrations', {
        station_id       => $params->{'station-calib'},
        instr_id         => $params->{'instrument-calib'},
        calib_fulldate   => $self->app->helperGetFormattedFulldate($params->{'datetime-calib'}),
        calib_re_id      => $params->{'reason-calib'},
        calib_multipoint => $self->app->helperGetBoolean($params, 'flag-multi'),
        calib_values     => $params->{'obj-calib'},
        calib_note       => $self->app->helperEscapeParam($params->{'notes-calib'}),
    }, { calib_id =>  $params->{'report-caid'} });
}

sub check_if_associated {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub check_if_associated");

    # query
    my $sql = qq{
        SELECT COUNT(*) AS num FROM reports.maintenances_operations
        WHERE calib_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash->{'num'};
}

sub delete_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqatarature sub delete_report_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;
        # ##################################################################
        # 1- eliminazione degli allegati del report
        # ##################################################################
        # query
        my $sql = qq{
            DELETE FROM reports.calibration_attachments
            WHERE calib_id = ?;
        };

        $self->pg->db->query($sql, $rpid);

        # ##################################################################
        # 2- eliminazione del report
        # ##################################################################
        # query
        $sql = qq{
            DELETE FROM reports.calibrations
            WHERE calib_id = ?;
        };

        # return
        $self->pg->db->query($sql, $rpid);
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
    my ( $self, $attach_id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::Dbqatarature delete_attachment_by_id");
    $self->app->log->debug("attach_id: $attach_id");

    # query
    my $sql = qq{
        DELETE FROM reports.calibration_attachments
        WHERE att_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $attach_id);
}

1;

=head1 get_cylinder_by_id

Funzione che recupera, dato l'id, le informazioni di una determinata bombola dal database.

Argomenti:  * id della bombola ('cyid');

Return:     Risultato della query.

=cut

=head1 get_cylinders_by_category

Funzione che recupera, dato l'id della categoria di strumento, le relative bombole dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('stid');

           * id della categoria di strumento ('cat');

           * data e ora della taratura ('dt');

Return:     Risultato della query.

=cut

=head1 get_method_by_id

Funzione che recupera, dato l'id, le informazioni di un determinato metodo dal database.

Argomenti:  * id del metodo ('meid');

Return:     Risultato della query.

=cut

=head1 get_methods_by_category

Funzione che recupera, dato l'id della categoria di strumento, i relativi metodi dal database.

Argomenti:  * id della categoria di strumento ('cat');

Return:     Risultato della query.

=cut

=head1 get_reasons

Funzione che recupera i possibili motivi per la taratura dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_calibrators

Funzione che recupera i calibratori per le tarature dell'O3 dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_calibrator_by_id

Funzione che recupera, dato l'id di uno strumento, le informazioni di un determinato calibratore dal database.

Argomenti:  * id dello strumento ('instr_id');

Return:     Risultato della query.

=cut

=head1 get_reports_by_date_province

Funzione che recupera, dato un certo periodo temporale e l'id di una provincia,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prid');

           * id della categoria di strumento, se presente ('catid');

Return:     Risultato della query.

=cut

=head1 get_reports_by_date_station

Funzione che recupera, dato un certo periodo temporale e l'id di una stazione,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

           * id della categoria di strumento, se presente ('catid');

Return:     Risultato della query.

=cut

=head1 get_reports_events_by_dates

Funzione che recupera, dato un certo periodo temporale,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_report_by_id

Funzione che recupera, dato l'id, le informazioni di una determinata taratura dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 insert_report

Funzione che inserisce una nuova taratura nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id della taratura appena inserita;

=cut

=head1 insert_new_attachment

Funzione che inserisce gli allegati di un determinato report nel database.

Argomenti:  * id della taratura ('id');

           * nome originale dell'allegato ('original_name');

           * nuovo nome dell'allegato per l'archiviazione ('new_name');

           * valore booleano che indica se l'allegato e' un'immagine ('is_image');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_report

Funzione che modifica, dato l'id, un determinato report nel database.

Argomenti:  * oggetto contenente le informazioni della taratura da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 check_if_associated

Funzione che verifica se una determinata taratura è associata ad un report manutenzione nel database.

Argomenti:  * id del report ('rpid');

Return:     Conteggio delle manutenzioni a cui e' associata la taratura.

=cut

=head1 delete_report_by_id

Funzione che elimina, dato l'id, un determinato report dal database.

Argomenti:  * id del report ('rpid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_attachment_by_id

Funzione che elimina, dato l'id, un determinato allegato dal database.

Argomenti:  * id dell'allegato ('attach_id');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut