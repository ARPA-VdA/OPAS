package Bobo::Model::DbplanPeriferia;
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

# -----------------------------------------------------------------------------
# Getters function
# -----------------------------------------------------------------------------
sub get_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_types");

    # query
    my $sql = qq{
        SELECT
            tt_id,
            tt_desc
        FROM reports.ticket_types
        ORDER BY tt_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_categories {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_categories");

    # query
    my $sql = qq{
        SELECT
            tc_id,
            tc_desc
        FROM reports.ticket_categories
        ORDER BY tc_desc;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_urgencies {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_urgencies");

    # query
    my $sql = qq{
        SELECT
            tu_id,
            tu_desc
        FROM reports.ticket_urgencies
        ORDER BY tu_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_frequencies {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_frequencies");

    # query
    my $sql = qq{
        SELECT
            tf_id,
            tf_desc
        FROM reports.ticket_frequencies
        ORDER BY tf_order;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_maintenances {
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_maintenances");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                station_id,
                tk_opening_date,
                tk_recipient_comp_fk
            FROM reports.tickets
            WHERE tk_id = ?
        )
        SELECT
            m.ma_id                             AS ma_id,
            m.station_id                        AS station_id,
            m.us_id                             AS us_id,
            u.us_name||
            COALESCE(' '||u.us_2nd_name, ' ')
            ||u.us_surname                      AS user_fullname,
            u.us_avatar                         AS user_avatar,
            u.us_avatar_thumb                   AS user_avatar_thumb,
            TO_CHAR(m.ma_fulldate, 'DD/MM/YYYY HH24:MI')
                                                AS maintenance_fulldate,
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
            ) AS maintenance_calib_flag

        FROM reports.maintenances m
        LEFT JOIN bobo.users u           USING (us_id)
        LEFT JOIN bobo.users_metadata um USING (us_id)

        WHERE m.station_id = ( SELECT station_id FROM t )
        AND um.comp_id = ( SELECT tk_recipient_comp_fk FROM t )
        AND m.ma_fulldate > ( SELECT tk_opening_date FROM t )

        ORDER BY m.ma_fulldate ASC
        LIMIT 5;
    };

    # return
    return $self->pg->db->query($sql, $tkid)->hashes();
}

sub get_tickets {
    my ( $self, $user_id, $from, $to, $comp, $prov, $stid, $hide ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_tickets");

    $prov = ($prov != -1 ? "^$prov\$": ".*");
    $stid = ($stid  != -1 ? "^$stid\$" : ".*");

    # query
    my $sql = qq{
        WITH s AS (
            SELECT
                tk_id,
                ts_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS tk_status_date,
                ts_status::text AS tk_status
            FROM (
                SELECT
                    tk_id,
                    ts_fulldate,
                    ts_status::text,
                    row_number() OVER (PARTITION BY tk_id ORDER BY ts_fulldate DESC) AS rownum
                FROM reports.tickets_status
            ) AS x
            WHERE x.rownum = 1
        ),
        t AS (
            SELECT
                tk_id,
                tk_opening_date,
                tk_expiry_date,
                tk_opening_user_fk,
                u.us_name||
                COALESCE(' '||u.us_2nd_name, ' ')
                ||' '||u.us_surname                 AS us_fullname,
                u.us_avatar                         AS us_avatar,
                u.us_avatar_thumb                   AS us_avatar_thumb,
                um.comp_id                          AS tk_opening_comp_fk,
                tk_recipient_comp_fk ,
                station_id           ,
                instr_id,
                cy_id,
                mi_id,
                tt_id                ,
                tc_id                ,
                tu_id                ,
                tf_id                ,
                tk_title          AS tk_title       ,
                tk_opening_note   AS tk_opening_note,
                s.tk_status,
                s.tk_status_date
            FROM
                reports.tickets t
                LEFT JOIN s USING (tk_id)
                LEFT JOIN bobo.users u ON (t.tk_opening_user_fk = u.us_id)
                LEFT JOIN bobo.users_metadata um USING (us_id)
            WHERE (
                ( tk_expiry_date BETWEEN ?::timestamp AND ?::timestamp )
                OR ( ( s.tk_status IS NULL OR s.tk_status != 'closed' ) AND ( tk_expiry_date < CURRENT_TIMESTAMP OR tk_expiry_date = 'infinity') )
                OR ( tt_id = 4 AND s.tk_status = 'closed' AND s.tk_status_date BETWEEN ?::timestamp AND ?::timestamp )
            )
            AND t.station_id IN (
                SELECT DISTINCT(station_id)
                FROM
                    bobo.users us
                    LEFT JOIN bobo.user_groups ug USING (us_id)
                    LEFT JOIN bobo.groups g USING (gr_id)
                    LEFT JOIN bobo.group_stations gs USING (gr_id)
                WHERE us.us_id = ?
            )
    };

    if ($hide eq 'true') {
        $sql .= qq{ AND ( s.tk_status IS NULL OR s.tk_status != 'closed' ) };
    };

    $sql .= qq{
        )
        SELECT
            tk_id,
            tk_opening_date,
            tk_expiry_date,
            tk_opening_user_fk,
            us_fullname,
            us_avatar,
            us_avatar_thumb,
            tk_opening_comp_fk,
            c2.comp_name AS opening_comp_name,
            tk_recipient_comp_fk ,
            c.comp_name          ,
            station_id           ,
            st.station_name      ,
            CASE
                WHEN instr_id IS NOT NULL THEN (SELECT
                                                    instr_type_fullname
                                                    || COALESCE(' - '||instrument_name, '')
                                                    || COALESCE(' ['||instrument_arpa_id||'] ', '')
                                                FROM equipments.view_instruments vi
                                                WHERE vi.instr_id = t.instr_id )
                WHEN cy_id IS NOT NULL THEN (SELECT
                                                cy_mixture
                                                || COALESCE(' - '||cy_name, '')
                                                || COALESCE(' ['||cy_arpa_id||']', '')
                                            FROM equipments.cylinders c
                                            WHERE cy_id = t.cy_id )
                WHEN mi_id IS NOT NULL THEN (SELECT
                                                mi_name
                                                || COALESCE(' ['||mi_arpa_id||']', '')
                                            FROM equipments.miscellanies m
                                            WHERE mi_id = t.mi_id )
                ELSE ''
            END AS equipment_name,
            tt_id                ,
            tt_desc              ,
            tc_id                ,
            tc_desc              ,
            CASE tc_id
                WHEN 1 THEN 'icon-tag text-success'
                WHEN 2 THEN 'ti-import text-danger'
                WHEN 3 THEN 'ti-settings text-info'
                WHEN 4 THEN 'icon-magic-wand text-muted'
                ELSE 'ti-location-pin text-warning'
            END AS tc_class      ,
            tu_id                ,
            tu_desc              ,
            tf_id                ,
            tf_desc              ,
            tk_title          AS tk_title       ,
            tk_opening_note   AS tk_opening_note,
            tk_status,
            tk_status_date

        FROM
            t
            LEFT JOIN bobo.companies c ON c.comp_id = t.tk_recipient_comp_fk
            LEFT JOIN metadata.stations st USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
            LEFT JOIN reports.ticket_types tt USING (tt_id)
            LEFT JOIN reports.ticket_categories tc USING (tc_id)
            LEFT JOIN reports.ticket_urgencies tu USING (tu_id)
            LEFT JOIN reports.ticket_frequencies tf USING (tf_id)
            LEFT JOIN bobo.companies c2 ON (t.tk_opening_comp_fk = c2.comp_id)
        WHERE
            smu.province_id::text ~ ?
            AND t.station_id::text ~ ?
    };

    if ($comp != -1) {
        $sql .= qq{ AND ( tk_opening_comp_fk = $comp OR tk_recipient_comp_fk = $comp ) };
    }

    # forzo ordinamento, tipologia 4 expiry date a infinity quindi sempre in fondo
    $sql .= qq{
        ORDER BY
            ( CASE
                WHEN (tt_id = 4) THEN 0
                ELSE 1
            END ) ASC, tk_expiry_date, tu_id DESC;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $from, $to, $user_id, $prov, $stid)->hashes;
}

sub get_calendar_tickets {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_calendar_tickets");

    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                CASE
                    WHEN um.comp_id = pp.admin_comp_id THEN linked_comp_id
                    ELSE ARRAY[um.comp_id]
                END AS comps
            FROM bobo.users_metadata um
            LEFT JOIN bobo.portal_properties pp USING (portal_id)
            WHERE us_id = ?
        ),
        s AS (
            SELECT
                tk_id,
                ts_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS tk_status_date,
                ts_status::text AS tk_status
            FROM (
                SELECT
                    tk_id,
                    ts_fulldate,
                    ts_status::text,
                    row_number() OVER (PARTITION BY tk_id ORDER BY ts_fulldate DESC) AS rownum
                FROM reports.tickets_status
            ) AS x
            WHERE x.rownum = 1
        )
        SELECT
            tk_id                ,
            TO_CHAR(tk_opening_date, 'DD-MM-YYYY') AS tk_opening_date,
            tk_expiry_date::date,
            u.us_name||
            COALESCE(' '||u.us_2nd_name, ' ')
            ||' '||u.us_surname                 AS us_fullname,
            um.comp_id      AS tk_opening_comp_fk,
            c.comp_name     AS opening_comp_name,
            tk_recipient_comp_fk ,
            vt.comp_name     AS recipient_comp_name,
            station_id           ,
            station_name         ,
            CASE
                WHEN instr_id IS NOT NULL THEN (SELECT
                                                    instr_type_fullname
                                                    || COALESCE(' - '||instrument_name, '')
                                                    || COALESCE(' ['||instrument_arpa_id||'] ', '')
                                                FROM equipments.view_instruments vi
                                                WHERE vi.instr_id = vt.instr_id )
                WHEN cy_id IS NOT NULL THEN (SELECT
                                                cy_mixture
                                                || COALESCE(' - '||cy_name, '')
                                                || COALESCE(' ['||cy_arpa_id||']', '')
                                            FROM equipments.cylinders c
                                            WHERE cy_id = vt.cy_id )
                WHEN mi_id IS NOT NULL THEN (SELECT
                                                mi_name
                                                || COALESCE(' ['||mi_arpa_id||']', '')
                                            FROM equipments.miscellanies m
                                            WHERE mi_id = vt.mi_id )
                ELSE '--'
            END AS equipment_name,
            tt_id                ,
            tt_desc              ,
            tc_id                ,
            tc_desc              ,
            CASE tc_id
                WHEN 1 THEN 'icon-tag'
                WHEN 2 THEN 'ti-import'
                WHEN 3 THEN 'ti-settings'
                WHEN 4 THEN 'icon-magic-wand'
                ELSE 'ti-location-pin'
            END AS tc_class      ,
            tu_id                ,
            tu_desc              ,
            tf_id                ,
            tf_desc              ,
            tk_title          AS tk_title       ,
            COALESCE(tk_opening_note, '--')   AS tk_opening_note,
            s.tk_status,
            s.tk_status_date
        FROM
            reports.view_tickets vt
            LEFT JOIN s USING (tk_id)
            LEFT JOIN bobo.users u ON (vt.tk_opening_user_fk = u.us_id)
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN bobo.companies c USING (comp_id)
        WHERE (
            um.comp_id IN (SELECT UNNEST(comps) FROM t)
            OR tk_recipient_comp_fk IN (SELECT UNNEST(comps) FROM t)
        )
        AND tk_expiry_date BETWEEN ?::timestamp AND (?||' 23:59:59')::timestamp
        AND vt.station_id IN (
            SELECT DISTINCT(station_id)
            FROM
                bobo.users us
                LEFT JOIN bobo.user_groups ug USING (us_id)
                LEFT JOIN bobo.groups g USING (gr_id)
                LEFT JOIN bobo.group_stations gs USING (gr_id)
            WHERE us.us_id = ?
        )
        ORDER BY tk_expiry_date;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $user_id)->hashes();
}

sub get_ticket_by_id {
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub get_ticket_by_id");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                tk_id                ,
                tk_opening_date      ,
                tk_expiry_date       ,
                TO_CHAR( tk_opening_date, 'DD/MM/YYYY HH24:MI') AS  tk_opening_date_formatted,
                CASE
                    WHEN isFinite(tk_expiry_date) THEN TO_CHAR( tk_expiry_date , 'DD/MM/YYYY HH24:MI')
                    ELSE 'Assente'
                END                 AS  tk_expiry_date_formatted ,
                tk_opening_user_fk   ,
                u.us_name || COALESCE(' '||u.us_2nd_name, ''::text) ||' '|| u.us_surname
                                    AS user_fullname,
                u.us_avatar         AS user_avatar,
                u.us_avatar_thumb   AS user_avatar_thumb,
                tk_recipient_comp_fk ,
                c.comp_name          ,
                vsm.province_id      ,
                vsm.province_name    ,
                station_id           ,
                s.station_name       ,
                CASE
                    WHEN instr_id IS NOT NULL THEN (SELECT
                                                        instr_type_fullname
                                                        || COALESCE(' - '||instrument_name, '')
                                                        || COALESCE(' ['||instrument_arpa_id||'] ', '')
                                                    FROM equipments.view_instruments vi
                                                    WHERE vi.instr_id = t.instr_id )
                    WHEN cy_id IS NOT NULL THEN (SELECT
                                                    cy_mixture
                                                    || COALESCE(' - '||cy_name, '')
                                                    || COALESCE(' ['||cy_arpa_id||']', '')
                                                FROM equipments.cylinders c
                                                WHERE cy_id = t.cy_id )
                    WHEN mi_id IS NOT NULL THEN (SELECT
                                                    mi_name
                                                    || COALESCE(' ['||mi_arpa_id||']', '')
                                                FROM equipments.miscellanies m
                                                WHERE mi_id = t.mi_id )
                    ELSE ''
                END AS equipment_name,
                COALESCE( 'instr-'||instr_id, 'tank-'||cy_id, 'misc-'||mi_id ) AS equipment_id,
                tt_id                ,
                tt.tt_desc           ,
                tu_id                ,
                tu.tu_desc           ,
                tc_id                ,
                tc.tc_desc           ,
                CASE tc_id
                    WHEN 1 THEN 'icon-tag text-success'
                    WHEN 2 THEN 'ti-import text-danger'
                    WHEN 3 THEN 'ti-settings text-info'
                    WHEN 4 THEN 'icon-magic-wand text-muted'
                    ELSE 'ti-location-pin text-warning'
                END AS tc_class      ,
                tf_id                ,
                tf.tf_desc           ,
                tk_title          AS tk_title       ,
                tk_opening_note   AS tk_opening_note,
                ARRAY(
                    SELECT ml_id
                    FROM reports.tickets_mlists tm
                    WHERE tm.tk_id = t.tk_id
                ) AS ml_ids,
                ARRAY(
                    SELECT ml_name
                    FROM reports.tickets_mlists tm
                    LEFT JOIN gateways.mailing_list ml USING (ml_id)
                    WHERE tm.tk_id = t.tk_id
                ) AS mailing_lists
            FROM
                reports.tickets t
                LEFT JOIN bobo.companies c ON (c.comp_id = t.tk_recipient_comp_fk)
                LEFT JOIN bobo.users u ON ( u.us_id = t.tk_opening_user_fk )
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
                LEFT JOIN reports.ticket_types tt USING (tt_id)
                LEFT JOIN reports.ticket_categories tc USING (tc_id)
                LEFT JOIN reports.ticket_urgencies tu USING (tu_id)
                LEFT JOIN reports.ticket_frequencies tf USING (tf_id)
             WHERE tk_id = ?
        ),
        s AS (
            SELECT
                u2.us_id,
                u2.us_name || COALESCE(' '||u2.us_2nd_name, ''::text) ||' '|| u2.us_surname AS user_fullname,
                u2.us_avatar AS user_avatar,
                u2.us_avatar_thumb AS user_avatar_thumb,
                ts_fulldate,
                TO_CHAR(ts_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD/MM/YYYY HH24:MI') AS ts_fulldate_formatted,
                COALESCE(ts_note, '--' ) AS ts_note,
                ts_status,
                ma_id,
                COALESCE(
                    '['|| TO_CHAR(m.ma_fulldate, 'DD/MM/YYYY HH24:MI')||'] Operatore: '
                    || u3.us_name|| COALESCE(' '||u3.us_2nd_name, ' ') ||u3.us_surname,
                    '--' )                      AS maintenance
            FROM reports.tickets_status ts
            LEFT JOIN bobo.users u2 ON ( ts.us_id = u2.us_id )
            LEFT JOIN reports.maintenances m USING (ma_id)
            LEFT JOIN bobo.users u3 ON ( m.us_id = u3.us_id )
            WHERE tk_id = ?
            ORDER BY ts_fulldate
        )
        SELECT
            *,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        *
                   FROM s
                ) j
            ) AS ticket_status
        FROM t
    };

    # return
    return $self->pg->db->query($sql, $tkid, $tkid)->hash();
}

sub check_active_tickets {
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub check_active_tickets");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT tk_id
            FROM reports.tickets
            WHERE tk_parent_id_fk = (
                SELECT tk_parent_id_fk
                FROM reports.tickets
                WHERE tk_id = ?
            )
            AND tk_expiry_date < (
                SELECT tk_expiry_date
                FROM reports.tickets
                WHERE tk_id = ?
            )
            UNION
            SELECT tk_parent_id_fk AS tk_id
            FROM reports.tickets
            WHERE tk_id = ?
        )
        SELECT COUNT(*) AS num
        FROM t
        WHERE tk_id NOT IN (
            SELECT tk_id
            FROM reports.tickets_status
        )
        AND tk_id NOTNULL;
    };

    # return
    return $self->pg->db->query($sql, $tkid, $tkid, $tkid)->hash()->{'num'};
}

# -----------------------------------------------------------------------------
# Write functions
# -----------------------------------------------------------------------------
sub insert_ticket {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub insert_ticket");

    my $tx;
    my $new_tkid;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo ticket e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 1");

        # {
        #   "newtic-assigned" => 7,
        #   "newtic-body" => "Prova prova prova",
        #   "newtic-category" => 3,
        #   "newtic-expdate" => "04/06/2021 15:21",
        #   "newtic-id" => "",
        #   "newtic-insdate" => "04/06/2021 15:21",
        #   "newtic-equipment" => -1,
        #   "newtic-objtype" => "",
        #   "newtic-prov" => 33,
        #   "newtic-repeat" => 0,
        #   "newtic-station" => 1136,
        #   "newtic-title" => "Titolo",
        #   "newtic-type" => 3
        # }

        my $instr_id = undef;
        my $cy_id = undef;
        my $mi_id = undef;

        # my $old = 'cat';
        # my $new = $old =~ s/cat/dog/r;

        if ($params->{'newtic-objtype'} eq 'instr') {
            $instr_id = $params->{'newtic-equipment'} =~ s/instr-//r;
        } elsif ($params->{'newtic-objtype'} eq 'tank') {
            $cy_id = $params->{'newtic-equipment'} =~ s/tank-//r;
        } elsif ($params->{'newtic-objtype'} eq 'misc') {
            $mi_id = $params->{'newtic-equipment'} =~ s/misc-//r;
        }

        my $exp_date;
        if ($params->{'newtic-type'} == 4) { # Generale
            $exp_date = 'infinity';
        }
        else {
            $exp_date = $self->app->helperGetFormattedFulldate($params->{'newtic-expdate'});
        }

        $new_tkid = $self->pg->db->insert('reports.tickets', {
            tk_opening_date      => defined $params->{'newtic-insdate'} ? $self->app->helperGetFormattedFulldate($params->{'newtic-insdate'}) : $self->app->helperGetLocaleFullDate(),
            tk_expiry_date       => $exp_date,
            tk_opening_user_fk   => $user_id,
            tk_recipient_comp_fk => $params->{'newtic-assigned'},
            station_id           => $params->{'newtic-station'},
            instr_id             => $instr_id,
            cy_id                => $cy_id,
            mi_id                => $mi_id,
            tt_id                => $params->{'newtic-type'},
            tc_id                => $params->{'newtic-category'},
            tu_id                => $params->{'newtic-urgency'},
            tf_id                => $params->{'newtic-repeat'},
            tk_title             => $self->app->helperEscapeParam($params->{'newtic-title'}),
            tk_opening_note      => $self->app->helperEscapeParam($params->{'newtic-body'})
        }, { returning => 'tk_id' })->hash->{'tk_id'};

        # ##################################################################
        # 2- aggiunta delle mailing list a cui mandare le notifiche del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 2");

        # ARRAY networks
        my @mlists;

        if (defined $params->{'newtic-email'}) {
            if (ref($params->{'newtic-email'}) eq 'ARRAY') {
                @mlists = @{$params->{'newtic-email'}};
            }
            else {
                push @mlists, $params->{'newtic-email'};
            }

            for my $list (@mlists) {
                $self->pg->db->insert('reports.tickets_mlists', {
                    tk_id => $new_tkid,
                    ml_id => $list
                });
            }
        }

        # ##################################################################
        # 3- aggiunta delle eventuali ripetizioni del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 3");

        if ($params->{'newtic-repeat'} > 0) {
            my $sql = qq{
                SELECT reports.f_insert_periodic_tickets(?, ?, ?::timestamp, ?);
            };

            $self->pg->db->query($sql, $new_tkid, $exp_date, $self->app->helperGetFormattedFulldate($params->{'newtic-repeat-dateto'}), $params->{'newtic-repeat'});

            for my $list (@mlists) {
                $sql = qq{
                    INSERT INTO reports.tickets_mlists (tk_id, ml_id)
                        SELECT
                            tk_id,
                            ? ::integer
                        FROM
                            reports.tickets
                        WHERE
                            tk_parent_id_fk = ?

                    ON CONFLICT ON CONSTRAINT reports_tickets_mlists_pkey
                        DO NOTHING;
                };

                $self->pg->db->query($sql, $list, $new_tkid);
            }
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
       return $new_tkid;
    }
}

sub insert_ticket_status {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub insert_ticket_status");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- aggiunta cambiamento di stato del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 1");

        $self->pg->db->insert('reports.tickets_status', {
            tk_id       => $params->{'changestatus-id'},
            us_id       => $user_id,
            ts_fulldate => $self->app->helperGetFullDate(),
            ts_note     => $self->app->helperEscapeParam($params->{'changestatus-note'}),
            ts_status   => $params->{'changestatus-status'},
            ma_id       => $params->{'changestatus-maintenance'} != -1 ? $params->{'changestatus-maintenance'} : undef
        });

        # ##################################################################
        # 2- se presa in carico di ticket correttivo, aggiorno data di scadenza
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 2");

        if (defined $params->{'changestatus-expdate'}) {
            $self->pg->db->update('reports.tickets', {
                tk_expiry_date => $self->app->helperGetFormattedFulldate($params->{'changestatus-expdate'})
            }, { tk_id => $params->{'changestatus-id'}} );
        }
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

sub update_ticket {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub update_ticket");

    # {
    #   "newtic-body" => "Prova prova prova",
    #   "newtic-category" => 3,
    #   "newtic-expdate" => "04/06/2021 15:21",
    #   "newtic-id" => "",
    #   "newtic-title" => "Titolo",
    #   "newtic-type" => 3
    # }

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- update delle informazioni del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 2");

        my $exp_date;
        if ($params->{'newtic-type'} == 4) { # Generale
            $exp_date = 'infinity';
        }
        else {
            $exp_date = $self->app->helperGetFormattedFulldate($params->{'newtic-expdate'});
        }

        $self->pg->db->update('reports.tickets', {
            tk_expiry_date  => $exp_date,
            tt_id           => $params->{'newtic-type'},
            tc_id           => $params->{'newtic-category'},
            tu_id           => $params->{'newtic-urgency'},

            tk_title        => $self->app->helperEscapeParam($params->{'newtic-title'}),
            tk_opening_note => $self->app->helperEscapeParam($params->{'newtic-body'})
        }, { tk_id => $params->{'newtic-id'} });


        # ##################################################################
        # 2- eliminazione associazioni ticket-mailing list e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanPeriferia STEP 2");

        my $sql = qq{
            DELETE FROM reports.tickets_mlists WHERE tk_id = ?
        };

        $self->pg->db->query($sql, $params->{'newtic-id'});

        # ARRAY networks
        my @mlists;
        if (defined $params->{'newtic-email'}) {
            if (ref($params->{'newtic-email'}) eq 'ARRAY') {
                @mlists = @{$params->{'newtic-email'}};
            }
            else {
                push @mlists, $params->{'newtic-email'};
            }

            for my $list (@mlists) {
                $self->pg->db->insert('reports.tickets_mlists', {
                    tk_id => $params->{'newtic-id'},
                    ml_id => $list
                });
            }
        }

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

sub delete_ticket {
    my ( $self, $tkid, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanPeriferia sub delete_ticket");

    # query
    my $sql = qq{
        SELECT reports.f_delete_tickets(?::integer, ?::boolean) AS result;
    };

    # return
    return $self->pg->db->query($sql, $tkid, $flag)->hash()->{'result'};
}

1;

=head1 get_types

Funzione che recupera le tipologie di ticket dal database.

Argomenti:  /

Return:     Array di tipologie;

=cut

=head1 get_categories

Funzione che recupera le categorie di ticket dal database.

Argomenti:  /

Return:     Array di categorie;

=cut

=head1 get_urgencies

Funzione che recupera le tipologie di urgenza dei ticket dal database.

Argomenti:  /

Return:     Array di tipologie di urgenza;

=cut

=head1 get_frequencies

Funzione che recupera le tipologie di frequenza dei ticket dal database.

Argomenti:  /

Return:     Array di tipologie di frequenza;

=cut

=head1 get_maintenances

Funzione che recupera le manutenzioni associabili ad un ticket per la chiusura dello stesso, sulla base della
data di scadenza, dell'azienda destinataria e della stazione

Argomenti:  * id del ticket ('tkid');

Return:     Array con le manutenzioni associabili al ticket

=cut

=head1 get_tickets

Funzione che recupera i ticket visibili ad un determinato utente di una determinata
azienda in un determinato periodo temporale dal database.

Argomenti:  * data d'inizio periodo ('from');

           * data di fine periodo ('to');

           * id dell'azienda, se presente ('comp');

           * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_calendar_tickets

Funzione che recupera per la pagina del calendario i ticket visibili dall'utente .

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio periodo ('from');

           * data di fine periodo ('to');

Return:     Risultato della query;

=cut

=head1 get_ticket_by_id

Funzione che recupera tramite id le informazioni di un determinato ticket dal database.

Argomenti:  * id del ticket ('tkid');

Return:     Risultato della query;

=cut

=head1 check_active_tickets

Funzione che controlla se, in una serie di ticket programmati, esistono dei ticket precedenti
a quello selezionato ancora da chiudere

Argomenti:  * id del ticket ('tkid');

Return:     Numero di ticket precedenti e ancora aperti;

=cut

=head1 insert_ticket

Funzione che effettua l'inserimento di un nuovo ticket nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni del ticket ('params');

Return:     Se tutto OK, restituisce l'id del nuovo ticket;

        Se KO, restituisce 'undef'.

=cut

=head1 insert_ticket_status

Funzione che effettua l'inserimento dello stato di un determinato ticket nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni del ticket ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_ticket

Funzione che effettua la modifica di un ticket nel database.

Argomenti:  * oggetto contenente le informazioni del ticket ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_ticket

Funzione che effettua, dato l'id, l'eliminazione di un determinato ticket dal database.

Argomenti:  * id del ticket ('tkid');

           * valore booleano ('flag') per scegliere in caso di ticket programmati, se eliminare i ticket

             successivi rispetto a quello indicato

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut