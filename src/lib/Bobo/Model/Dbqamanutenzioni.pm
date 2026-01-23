package Bobo::Model::Dbqamanutenzioni;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

sub get_miscellanies_operations {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_miscellanies_operations");

    # query
    my $sql = qq{
        SELECT
            mi_op_id,
            mi_op_desc
        FROM
            equipments.miscellanies_operations
        ORDER BY
            mi_op_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_reports_by_date_net_province {
    my ( $self, $user_id, $from, $to, $net, $prid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_reports_by_date_net_province");

    # query
    my $sql = qq{
        WITH t AS(
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
            m.ma_id                             AS ma_id,
            m.station_id                        AS station_id,
            s.station_name                      AS station_name,
            snt.st_network_name                 AS network_name,
            m.us_id                             AS us_id,
            u.us_name||
            COALESCE(' '||u.us_2nd_name, ' ')
            ||u.us_surname                      AS user_fullname,
            u.us_avatar                         AS user_avatar,
            u.us_avatar_thumb                   AS user_avatar_thumb,
            m.ma_fulldate                       AS maintenance_fulldate,
            COALESCE(m.ma_note, '--')           AS maintenance_note,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo
                WHERE mo.ma_id = m.ma_id
            ) AS maintenance_operation_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo2
                WHERE mo2.ma_id = m.ma_id
                AND calib_id IS NOT NULL
            ) AS maintenance_calib_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_miscellanies_operations mmo
                WHERE mmo.ma_id = m.ma_id
            ) AS miscellanies_operation_flag,
            CASE
                WHEN um.comp_id = (SELECT user_comp FROM t) THEN TRUE
                ELSE FALSE
            END  AS user_has_grants

        FROM reports.maintenances m
        LEFT JOIN metadata.stations s                       USING (station_id)
        LEFT JOIN metadata.stations_info sm                 USING (station_id)
        LEFT JOIN metadata.stations_network_type snt        ON snt.st_network_id = sm.st_info_network_type_fk
        LEFT JOIN bobo.users u                              USING (us_id)
        LEFT JOIN bobo.users_metadata um                    ON um.us_id = u.us_id
        LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
        LEFT JOIN bobo.view_user_stations vus               USING (station_id)
        WHERE
            vus.user_id = ?

        -- solo report degli utenti delle aziende che puoi visualizzare
        -- AND um.comp_id IN (SELECT UNNEST(comps) FROM t)

        AND m.ma_fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    my @binds;
    push @binds, $user_id, $user_id, $from, $to;

    if ($net != -1) {
        $sql .= qq{ AND sm.st_info_network_type_fk = ? };
        push @binds, $net;
    }

    if ($prid != -1) {
        $sql .= qq{ AND vsm.province_id = ? };
        push @binds, $prid;
    }

    $sql .= qq{
        ORDER BY m.ma_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, @binds)->hashes();
}

sub get_reports_by_date_station {
    my ( $self, $user_id, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_reports_by_date_station");

    # query
    my $sql = qq{
         WITH t AS(
            SELECT
                um.comp_id AS user_comp
            FROM bobo.users_metadata um
            WHERE us_id = ?
        )
        SELECT
            m.ma_id                             AS ma_id,
            m.station_id                        AS station_id,
            s.station_name                      AS station_name,
            snt.st_network_name                 AS network_name,
            m.us_id                             AS us_id,
            u.us_name||
            COALESCE(' '||u.us_2nd_name, ' ')
            ||u.us_surname                      AS user_fullname,
            u.us_avatar                         AS user_avatar,
            u.us_avatar_thumb                   AS user_avatar_thumb,
            m.ma_fulldate                       AS maintenance_fulldate,
            COALESCE(m.ma_note, '--')           AS maintenance_note,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo
                WHERE mo.ma_id = m.ma_id
            ) AS maintenance_operation_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo2
                WHERE mo2.ma_id = m.ma_id
                AND calib_id IS NOT NULL
            ) AS maintenance_calib_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_miscellanies_operations mmo
                WHERE mmo.ma_id = m.ma_id
            ) AS miscellanies_operation_flag,
            CASE
                WHEN um.comp_id = (SELECT user_comp FROM t) THEN TRUE
                ELSE FALSE
            END  AS user_has_grants

        FROM reports.maintenances m
        LEFT JOIN metadata.stations s                       USING (station_id)
        LEFT JOIN metadata.stations_info sm                 USING (station_id)
        LEFT JOIN metadata.stations_network_type snt        ON snt.st_network_id = sm.st_info_network_type_fk
        LEFT JOIN bobo.users u                              USING (us_id)
        LEFT JOIN bobo.users_metadata um                    ON um.us_id = u.us_id
        WHERE
            m.ma_fulldate BETWEEN ?::timestamp AND ?::timestamp
        AND
            m.station_id = ?
        ORDER BY
            m.ma_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $stid)->hashes();
}

sub get_reports_events_by_dates {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_reports_events_by_dates");

    # query
    my $sql = qq{
        SELECT
            m.ma_id                             AS ma_id,
            m.station_id                        AS station_id,
            s.station_name                      AS station_name,
            m.us_id                             AS us_id,
            u.us_name||
            COALESCE(' '||u.us_2nd_name, ' ')
            ||u.us_surname                      AS user_fullname,
            c.comp_name                         AS company_name,
            m.ma_fulldate::date                 AS maintenance_fulldate,
            TO_CHAR(m.ma_fulldate, 'HH24:MI')   AS maintenance_hour,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo
                WHERE mo.ma_id = m.ma_id
            ) AS maintenance_operation_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_operations mo2
                WHERE mo2.ma_id = m.ma_id
                AND calib_id IS NOT NULL
            ) AS maintenance_calib_flag,
            EXISTS(
                SELECT *
                FROM reports.maintenances_miscellanies_operations mmo
                WHERE mmo.ma_id = m.ma_id
            ) AS miscellanies_operation_flag

        FROM reports.maintenances m
        LEFT JOIN metadata.stations s         USING (station_id)
        LEFT JOIN metadata.stations_info sm   USING (station_id)
        LEFT JOIN bobo.users u                USING (us_id)
        LEFT JOIN bobo.users_metadata um      ON um.us_id = u.us_id
        LEFT JOIN bobo.companies c            USING (comp_id)
        LEFT JOIN bobo.view_user_stations vus USING (station_id)
        WHERE
            vus.user_id = ?

        AND m.ma_fulldate BETWEEN ?::timestamp AND ?::timestamp
        ORDER BY m.ma_fulldate ASC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_report_by_id");

    # query
    my $sql = qq{
        SELECT
            vm.ma_id,
            vm.station_id,
            vm.station_name,
            vsm.province_id,
            vsm.province_name,
            vm.us_id,
            vm.user_fullname,
            vm.user_avatar,
            vm.user_avatar_thumb,
            vm.maintenance_fulldate,
            TO_CHAR(vm.maintenance_fulldate, 'DD-MM-YYYY HH24:MI') AS maintenance_fulldate_formatted,
            COALESCE(vm.maintenance_note, '') AS maintenance_note
        FROM reports.view_maintenances vm
        LEFT JOIN metadata.view_stations_municipality vsm   USING (station_id)
        WHERE ma_id = ?
        LIMIT 1;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash();
}

sub get_operations_by_report {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_operations_by_report");

    # query
    my $sql = qq{
        SELECT
            vm2.ma_op_id,
            vm2.instr_id,
            vm2.instr_type_id,
            COALESCE(vit.instr_type_fullname, '')   AS instr_type_fullname,
            COALESCE(vm2.instr_arpa_id, '')         AS instr_arpa_id,
            COALESCE(vm2.instr_serial_num, '')      AS instr_serial_num,
            COALESCE(vm2.instr_name, '')            AS instr_name,
            vit.category_id,
            vit.category_name,
            vm2.in_op_id,
            vm2.op_id,
            vio.operation_description,
            vm2.op_ca_id,
            vio.operation_category_desc,
            vm2.freq_id ,
            vio.frequency_desc ,
            vio.frequency_label,
            vio.frequency_db,
            COALESCE( TO_CHAR(vm2.main_operation_filters_exp, 'DD/MM/YYYY' ), '') AS main_operation_filters_exp,
            COALESCE( vm2.main_operation_note, '' )                         AS main_operation_note,
            vm2.calib_id,
            COALESCE( vc.user_fullname    , '' )                            AS calib_user_fullname,
            COALESCE( vc.user_avatar_thumb, '' )                            AS calib_user_avatar_thumb,
            COALESCE(TO_CHAR(vc.calib_fulldate, 'DD/MM/YYYY HH24:MI'), '' ) AS calib_fulldate,
            vc.calib_multipoint ,
            vc.calib_values     ,
            COALESCE( vc.calib_note, '' )  AS calib_note
        FROM reports.view_maintenances vm2
        LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        LEFT JOIN equipments.view_instruments_operations vio USING (in_op_id)
        LEFT JOIN reports.view_calibrations vc USING (calib_id)
        WHERE vm2.ma_id = ?
        AND vm2.ma_op_id NOTNULL
        ORDER BY vm2.ma_op_id;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hashes();
}

sub get_miscellanies_operations_by_report {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_miscellanies_operations_by_report");

    # query
    my $sql = qq{
        SELECT
            mmo.mi_id,
            m.mi_arpa_id,
            m.mi_name,
            m.mi_name|| COALESCE(' ['||mi_arpa_id||']', '') AS miscellany_fullname,
            m.mi_dismiss_date,
            TO_CHAR( m.mi_dismiss_date, 'DD/MM/YYYY' ) AS miscellany_dismiss_date_format,
            mmo.mi_op_id,
            mo.mi_op_desc,
            COALESCE(mmo.mami_op_note, '') AS mami_op_note
        FROM
            reports.maintenances_miscellanies_operations mmo
            LEFT JOIN equipments.miscellanies_operations mo USING (mi_op_id)
            LEFT JOIN equipments.miscellanies m USING (mi_id)
        WHERE
            mmo.ma_id = ?
        ORDER BY
            mmo.mami_op_id;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hashes();
}

sub get_instruments_by_station {
    my ( $self, $stid, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_instruments_by_station");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                instr_id,
                instr_type_fullname AS instrument_type_fullname,
                COALESCE(instrument_arpa_id, '') AS instrument_arpa_id,
                COALESCE(instrument_name, '') AS instrument_name,
                category_id
            FROM equipments.view_instruments
            WHERE instr_id = 0
            UNION
            SELECT
                instr_id,
                instrument_type_fullname||' - '||category_name AS instrument_type_fullname,
                COALESCE(instrument_arpa_id, '') AS instrument_arpa_id,
                COALESCE(instrument_name, '') AS instrument_name,
                category_id
            FROM metadata.view_stations_instruments
            WHERE station_id = ?
            AND tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> ?::timestamp
        )
        SELECT * FROM t
        ORDER BY (
            CASE
                WHEN instr_id = 0 THEN 0
                ELSE 1
            END
        ) ASC, instrument_type_fullname;

    };

    # return
    return $self->pg->db->query($sql, $stid, $dt)->hashes();
}

sub get_operations_by_instrument {
    my ( $self, $instrid, $catid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_operations_by_instrument");

    # query
    my $sql = qq{
        SELECT
            in_op_id,
            vio.category_id,
            vio.category_name,
            instr_type_id,
            instr_type_fullname,
            op_id,
            operation_description,
            operation_category_desc,
            freq_id,
            frequency_desc,
            frequency_label,
            frequency_db
        FROM equipments.view_instruments_operations vio
        LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        WHERE (vio.category_id = ? AND instr_type_id IS NULL)
        OR (vio.category_id = ? AND instr_type_id = (
            SELECT instr_type_id
            FROM equipments.instruments
            WHERE instr_id = ?
        ))
        ORDER BY operation_description;

    };

    # return
    return $self->pg->db->query($sql, $catid, $catid, $instrid)->hashes();
}

sub get_calibrations_by_station_instr {
    my ( $self, $stid, $instr, $dt ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub get_calibrations_by_station_instr");

    # query
    my $sql = qq{
        SELECT
            vc.calib_id        ,
            vc.us_id           ,
            vc.user_fullname   ,
            vc.user_avatar_thumb,
            vc.station_id      ,
            vc.station_name    ,
            vc.instr_id        ,
            vc.instr_type_id   ,
            vit.instr_type_fullname,
            vit.category_id     ,
            vit.category_name   ,
            vc.instr_name       ,
            TO_CHAR(vc.calib_fulldate, 'DD-MM-YYYY HH24:MI') AS calib_fulldate,
            vc.calib_multipoint ,
            vc.calib_values     ,
            vc.calib_note
        FROM reports.view_calibrations vc
        LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
        WHERE
            vc.calib_fulldate <= ?::timestamp
            AND vc.station_id = ?
            AND vc.instr_id = ?
        ORDER BY vc.calib_fulldate DESC
        LIMIT 15;
    };

    # return
    return $self->pg->db->query($sql, $dt, $stid, $instr)->hashes();
}

sub insert_report {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub insert_report");

    my $tx;
    my $new_rpid;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo report manutenzione e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 1");

        $new_rpid = $self->pg->db->insert('reports.maintenances', {
            us_id       => $user_id,
            station_id  => $params->{'maintenance-stat'},
            ma_fulldate => $self->app->helperGetFormattedFulldate($params->{'maintenance-datetime'}),
            ma_note     => $self->app->helperEscapeParam($params->{'maintenance-note'}),
        }, { returning => 'ma_id' })->hash->{'ma_id'};

        # ##################################################################
        # 2- aggiunta delle operazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 2");

        my @operations = decode_json(encode_utf8($params->{'maintenance-operations'}));

        # $self->app->log->debug("Print ARRAY");
        # $self->app->helperDumper($operations[0]);

        for my $operation (@{$operations[0]}) {

            # $self->app->helperDumper( $operation );
            # {
            #   "calibid" => 2,
            #   "expdate" => "",
            #   "instrid" => 4,
            #   "note" => "",
            #   "opid" => 42
            # }

            $self->pg->db->insert('reports.maintenances_operations', {
                ma_id             => $new_rpid,
                instr_id          => $operation->{'instrid'} == -1 ? undef : $operation->{'instrid'},
                in_op_id          => $operation->{'opid'},
                calib_id          => $operation->{'calibid'} == -1 ? undef : $operation->{'calibid'},
                ma_op_filters_exp => $self->app->helperGetFormattedFulldate($operation->{'expdate'}),
                ma_op_note        => $self->app->helperEscapeParam($operation->{'note'})
            });
        };

        # ##################################################################
        # 3- aggiunta delle operazioni sulle dotazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 2");

        @operations = decode_json(encode_utf8($params->{'miscellanies-operations'}));

        # $self->app->log->debug("Print ARRAY");
        # $self->app->helperDumper($operations[0]);

        for my $operation (@{$operations[0]}) {
            $self->pg->db->insert('reports.maintenances_miscellanies_operations', {
                ma_id        => $new_rpid,
                mi_id        => $operation->{'miid'} == -1 ? undef : $operation->{'miid'},
                mi_op_id     => $operation->{'opid'},
                mami_op_note => $self->app->helperEscapeParam($operation->{'note'})
            });
        };
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return undef;
    }
    else {
       $tx->commit;
       return $new_rpid;
    }
}

sub update_report {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub update_report");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- modifica report manutenzione
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 1");

        $self->pg->db->update('reports.maintenances', {
            station_id      => $params->{'maintenance-stat'},
            ma_fulldate     => $self->app->helperGetFormattedFulldate($params->{'maintenance-datetime'}),
            ma_note         => $self->app->helperEscapeParam($params->{'maintenance-note'}),
        }, { ma_id => $params->{'maintenance-id'} });

        # ##################################################################
        # 2- eliminazione delle operazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 2");

        # query
        my $sql = qq{
            DELETE FROM reports.maintenances_operations
            WHERE ma_id = ?;
        };

        $self->pg->db->query($sql, $params->{'maintenance-id'});

        # ##################################################################
        # 3- aggiunta delle operazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 3");

        my @operations = decode_json(encode_utf8($params->{'maintenance-operations'}));

        # $self->app->log->debug("Print ARRAY");
        # $self->app->helperDumper($operations[0]);

        for my $operation (@{$operations[0]}) {
            # $self->app->helperDumper( $operation );
            # {
            #   "calibid" => 2,
            #   "expdate" => "",
            #   "instrid" => 4,
            #   "note" => "",
            #   "opid" => 42
            # }

            $self->pg->db->insert('reports.maintenances_operations', {
                ma_id             => $params->{'maintenance-id'},
                instr_id          => $operation->{'instrid'} == -1 ? undef : $operation->{'instrid'},
                in_op_id          => $operation->{'opid'},
                calib_id          => $operation->{'calibid'} == -1 ? undef : $operation->{'calibid'},
                ma_op_filters_exp => $self->app->helperGetFormattedFulldate($operation->{'expdate'}),
                ma_op_note        => $self->app->helperEscapeParam($operation->{'note'})
            });
        };

        # ##################################################################
        # 4- eliminazione delle operazioni sulle dotazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 4");

        # query
        $sql = qq{
            DELETE FROM reports.maintenances_miscellanies_operations
            WHERE ma_id = ?;
        };

        $self->pg->db->query($sql, $params->{'maintenance-id'});

        # ##################################################################
        # 5- aggiunta delle operazioni sulle dotazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 5");

        @operations = decode_json(encode_utf8($params->{'miscellanies-operations'}));

        # $self->app->log->debug("Print ARRAY");
        # $self->app->helperDumper($operations[0]);

        for my $operation (@{$operations[0]}) {
            $self->pg->db->insert('reports.maintenances_miscellanies_operations', {
                ma_id        => $params->{'maintenance-id'},
                mi_id        => $operation->{'miid'} == -1 ? undef : $operation->{'miid'},
                mi_op_id     => $operation->{'opid'},
                mami_op_note => $self->app->helperEscapeParam($operation->{'note'})
            });
        };
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

sub delete_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqamanutenzioni sub delete_report_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- eliminazione delle operazioni associate al report
        # ##################################################################
        my $sql = qq{
            DELETE FROM reports.maintenances_operations
            WHERE ma_id = ?;
        };

        $self->pg->db->query($sql, $rpid);

        # ##################################################################
        # 2- eliminazione delle operazioni sulle dotazioni associate al report
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbqamanutenzioni STEP 4");

        # query
        $sql = qq{
            DELETE FROM reports.maintenances_miscellanies_operations
            WHERE ma_id = ?;
        };

        $self->pg->db->query($sql, $rpid);

        # ##################################################################
        # 3- eliminazione del report
        # ##################################################################

        # query
        $sql = qq{
            DELETE FROM reports.maintenances
            WHERE ma_id = ?;
        };

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

1;

=head1 get_miscellanies_operations

Funzione che recupera dal database le operazioni associate alle varie dotazioni.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_reports_by_date_net_province

Funzione che recupera, dato un certo periodo temporale e l'id di una provincia,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prid');

Return:     Risultato della query.

=cut

=head1 get_reports_by_date_station

Funzione che recupera, dato un certo periodo temporale e l'id di una stazione,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

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

Funzione che recupera, dato l'id, le informazioni di una determinata manutenzione dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_operations_by_report

Funzione che recupera, dato l'id di una manutenzione, le relative operazioni dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_miscellanies_operations_by_report

Funzione che recupera, dato l'id di una manutenzione, le relative operazioni effettuate sulle dotazioni dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 get_instruments_by_station

Funzione che recupera, dato l'id della stazione, i relativi strumenti dal database.

Argomenti:  * id della stazione ('stid');

           * data della manutenzione ('dt');

Return:     Risultato della query.

=cut

=head1 get_operations_by_instrument

Funzione che recupera, dato l'id dello strumento, le relative operazioni dal database.

Argomenti:  * id dello strumento ('instrid');

           * id della categoria di strumento ('catid');

Return:     Risultato della query.

=cut

=head1 get_calibrations_by_station_instr

Funzione che recupera, dati gli id di una stazione e di uno strumento, le relative tarature dal database.

Argomenti:  * id della stazione ('stid');

           * id dello strumento ('instr');

           * data della taratura ('dt');

Return:     Risultato della query.

=cut

=head1 insert_report

Funzione che inserisce una nuova manutenzione nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id della manutenzione appena inserita;

        Se KO, restituisce undef.

=cut

=head1 update_report

Funzione che modifica, dato l'id, un determinato report nel database.

Argomenti:  * oggetto contenente le informazioni della manutenzione da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_report_by_id

Funzione che elimina, dato l'id, un determinato report dal database.

Argomenti:  * id del report ('rpid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut