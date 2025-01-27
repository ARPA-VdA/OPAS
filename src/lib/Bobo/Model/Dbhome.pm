package Bobo::Model::Dbhome;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Date::Calc qw(Today);
use Encode qw(encode_utf8);
use utf8;

has 'pg';
has 'app';

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

# -----------------------------------------------------------------------------
# Main function
# -----------------------------------------------------------------------------
sub welcome {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub welcome");

    # query
    my $sql = qq{
        SELECT CURRENT_TIMESTAMP AS timestamp;
    };

    # return
    $self->pg->db->query($sql)->hash->{timestamp};
}

sub get_widget_by_id {
    my ( $self, $user_id, $wdgid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbcommon sub get_widget_by_id");
    $self->app->log->debug("WIDGET $wdgid");
    $self->app->log->debug("USER $user_id");

    # query
    my $sql = qq{
        SELECT DISTINCT ON (u.us_id, w.wdg_name)
            w.wdg_id,
            w.wdg_name,
            w.wdg_description,
            w.wdg_image_url,
            w.wdg_page_html,
            FIRST_VALUE(wg.gw_dest) OVER( ORDER BY wg.gw_dest ->> 'type' DESC) gw_dest
        FROM bobo.users u
            LEFT JOIN bobo.user_groups ug USING (us_id)
            LEFT JOIN bobo.groups g USING (gr_id)
            LEFT JOIN bobo.group_widgets wg USING (gr_id)
            LEFT JOIN bobo_tools.homepage_widgets w USING (wdg_id)
        WHERE w.wdg_id = ?
        AND u.us_id = ?
    };

    # return
    return $self->pg->db->query($sql, $wdgid, $user_id)->hash;
}

sub get_delays {
    my ( $self, $user_id, $range ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_delays");

    my $filter = '';
    if($range != -1){
        $filter = qq{ AND slu.station_last_update::date > CURRENT_DATE - interval '1 week' };
    }

    # query
    my $sql = qq{
        WITH t AS(
            SELECT
                slu.station_id,
                slu.station_name,
                slu.network_name,
                slu.province_code,
                slu.station_last_update,
                slu.station_last_update_formatted,
                slu.station_minutes_gap,
                slu.station_last_update_class,
                CASE
                    WHEN station_last_update_class LIKE 'late' THEN 'Ritardo'
                    WHEN station_last_update_class LIKE 'almost-late' THEN 'Lieve ritardo' -- station_minutes_gap||' min rit.'
                    ELSE 'Ok'
                END AS station_last_update_text
            FROM clients.view_stations_last_update slu
            LEFT JOIN bobo.view_user_stations us USING(station_id)
            WHERE
               us.user_id = ?
               $filter
            ORDER BY (station_minutes_gap/station_accepted_delay) DESC, station_minutes_gap DESC
        )
        SELECT
            *,
            CASE
                WHEN ( SELECT COUNT(*) FROM (SELECT DISTINCT(network_name) FROM t ) AS t2) > 1 THEN TRUE
                ELSE FALSE
            END AS network_visible
        FROM t
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_instr_delays {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_instr_delays");

    # query
    my $sql = qq{
        SELECT
            ilu.station_id,
            vus.station_name,
            snt.st_network_name,
            ilu.instr_last_update
        FROM
            clients.instruments_last_update ilu
            LEFT JOIN metadata.stations_info si USING (station_id)
            LEFT JOIN metadata.stations_network_type snt ON (si.st_info_network_type_fk = snt.st_network_id)
            LEFT JOIN bobo.view_user_stations vus USING (station_id)
        WHERE
           vus.user_id = ?
        ORDER BY
            vus.station_name
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_station_params_delays{
    my ( $self, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_station_params_delays");

    # query
    my $sql = qq{
        SELECT clients.f_get_station_gaps(?, CURRENT_TIMESTAMP::timestamp without time zone) AS res;
    };

    # return
    return $self->pg->db->query($sql, $stid)->hash->{res};
}

sub get_last_alarms {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_alarms");

    # query
    my $sql = qq{
        SELECT
            sa.station_id,
            st.station_name,
            sa.param_id,
            CONCAT_WS(' - ', a.alarm_label, sp.stpr_note) AS alarm_label,
            a.alarm_color,
            a.alarm_icon,
            sa.sa_fulldate AS station_alarm_fulldate,
            to_char(sa.sa_fulldate, 'DD.MM h HH24'::text) AS station_alarm_fulldate_formatted,
            CASE
                WHEN sa.sa_fulldate = date_trunc('hour'::text, CURRENT_TIMESTAMP) THEN false
                ELSE (( SELECT count(*) AS count
                   FROM clients.stations_alarms t
                  WHERE t.station_id = sa.station_id AND t.param_id = sa.param_id AND t.sa_fulldate = (sa.sa_fulldate + '01:00:00'::interval))) = 0
            END AS station_alarm_off

        FROM
            clients.stations_alarms sa
            LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            LEFT JOIN clients.alarms a ON sa.param_id = a.param_id
            LEFT JOIN metadata.stations st ON sa.station_id = st.station_id
            LEFT JOIN bobo.view_user_stations us ON sa.station_id = us.station_id
        WHERE
           us.user_id = ?
           AND sa.sa_fulldate >= (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome' - interval '3 days')::timestamp
        AND alarm_label != 'Porta'
        ORDER BY sa.sa_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_last_reports {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_reports");

    # query
    my $sql = qq{
        WITH t AS (
            (
                SELECT
                    'Taratura' AS report_type,
                    c.calib_id AS id,
                    ((u.us_name || ' '::text) || COALESCE(u.us_2nd_name, ''::text)) || u.us_surname AS user_fullname,
                    u.us_avatar_thumb AS user_avatar_thumb,
                    s.station_name,
                    c.calib_fulldate AS report_fulldate,
                    '<strong>Strumento '||vit.instr_type_fullname || COALESCE(' - '|| i.instr_name, '')||'</strong> (cat. '||vit.category_name||')<br>
                    <strong>Motivo:</strong> '||cr.calib_re_name||'<br>
                    <strong>Nota:</strong> '||COALESCE(c.calib_note, '--'::text) AS report_desc
                FROM reports.calibrations c
                    LEFT JOIN bobo.users u USING (us_id)
                    LEFT JOIN metadata.stations s USING (station_id)
                    LEFT JOIN reports.calibration_reasons cr USING (calib_re_id)
                    LEFT JOIN equipments.instruments i USING (instr_id)
                    LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
                    LEFT JOIN bobo.view_user_stations vus               USING (station_id)
                WHERE
                    vus.user_id = ?
                ORDER BY c.calib_id
            )
            UNION ALL
            (
                SELECT
                    'Manutenzione' AS report_type,
                    m.ma_id AS id,
                    MAX((u.us_name || COALESCE(' '::text || u.us_2nd_name, ' '::text)) || u.us_surname) AS user_fullname,
                    MAX(u.us_avatar_thumb) AS user_avatar_thumb,
                    MAX(s.station_name) AS station_name,
                    MAX(m.ma_fulldate) AS report_fulldate,
                    COALESCE(STRING_AGG('<strong>'||COALESCE(i.instr_arpa_id||' - ', ''::text) ||vit.instr_type_fullname || COALESCE(' - '|| i.instr_name, '')||':</strong> '||vio.operation_description||'<br>', ''), 'Nessuna operazione<br>')||
                    '<strong>Note:</strong> '||COALESCE(MAX(m.ma_note), '--'::text) AS report_desc
                FROM reports.maintenances m
                    LEFT JOIN reports.maintenances_operations mo USING (ma_id)
                    LEFT JOIN metadata.stations s USING (station_id)
                    LEFT JOIN bobo.users u USING (us_id)
                    LEFT JOIN equipments.instruments i USING (instr_id)
                    LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
                    LEFT JOIN equipments.view_instruments_operations vio USING (in_op_id)
                    LEFT JOIN bobo.view_user_stations vus               USING (station_id)
                WHERE
                    vus.user_id = ?
                GROUP BY m.ma_id
                ORDER BY m.ma_id
            )
        )
        SELECT
            *,
            TO_CHAR(report_fulldate, 'DD.MM.YY hHH24') AS  report_ts_formatted
        FROM t
        ORDER BY report_fulldate DESC
        LIMIT 4;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id)->hashes();
}

sub get_open_doors_bydates {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_open_doors_bydates");

    # query
    my $sql = qq{
        WITH t AS(
            SELECT DISTINCT ON (station_id)
                station_id AS main_station_id,
                metadata.f_get_stationid_by_date(station_id, station_alarm_fulldate) AS station_id,
                station_alarm_fulldate,
                station_alarm_fulldate_formatted,
                CASE
                    WHEN station_alarm_off IS TRUE THEN '<span class="text-info">SI</span>'
                    ELSE '<span class="text-danger">NO</span>'
                END AS station_alarm_off_formatted,
                CASE
                    WHEN station_alarm_off IS TRUE THEN 'Allarmi rientrati'
                    ELSE 'Allarmi non rientrati'
                END AS station_alarm_layer,
                CASE
                    WHEN station_alarm_off IS TRUE THEN 7
                    ELSE 4
                END AS station_alarm_layer_id,
                CASE
                    WHEN station_alarm_off IS TRUE THEN 'f08b' --'f343'
                    ELSE 'f090' --'f342'
                END AS station_alarm_icon
            FROM clients.view_stations_alarms
            WHERE station_alarm_fulldate BETWEEN ?::timestamp AND ?::timestamp
            AND alarm_label = 'Porta'
            ORDER BY station_id, station_alarm_fulldate DESC
        )
        SELECT
            'station'                   AS marker_type,
            TRUE                        AS marker_flag_popup,
            t.station_alarm_layer_id    AS marker_layer_id,
            t.station_alarm_layer       AS marker_layer,
            sm.station_id               AS marker_id,
            sm.station_name             AS marker_name,
            sm.station_lat_wgs84        AS marker_lat,
            sm.station_lon_wgs84        AS marker_lon,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Ultimo allarme del : </strong>'|| t.station_alarm_fulldate_formatted ||'<br>
                <strong>Rientrato : </strong>'|| t.station_alarm_off_formatted||'<br>
            </div>'                     AS marker_hover,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Ultimo allarme del : </strong>'|| t.station_alarm_fulldate_formatted ||'<br>
                <strong>Rientrato : </strong>'|| t.station_alarm_off_formatted||'<br>'||
                COALESCE(
                '<br><table class="table popup-table">
                    <thead>
                        <tr>
                            <th>Data ora</th>
                            <th>Rientrato</th>
                        </tr>
                    </thead>
                    <tbody>'||
                (
                    SELECT STRING_AGG(s.table_row, '') FROM (
                        SELECT
                            '<tr>
                                <td>'||vsa.station_alarm_fulldate_formatted||'</td>'
                                ||( CASE
                                    WHEN vsa.station_alarm_off IS TRUE THEN '<td><i class="icon-check text-info" data-toggle="tooltip" data-original-title="allarme rientrato"></i></td>'
                                    ELSE '<td><i class="icon-close text-danger" data-toggle="tooltip" data-original-title="allarme NON rientrato"></i></td>'
                                END )||
                            '</tr>' AS table_row
                        FROM clients.view_stations_alarms vsa
                        WHERE  vsa.station_id = t.main_station_id
                        AND vsa.alarm_label = 'Porta'
                        AND vsa.station_alarm_fulldate != t.station_alarm_fulldate
                        AND vsa.station_alarm_fulldate BETWEEN ?::timestamp AND ?::timestamp
                        ORDER BY vsa.station_alarm_fulldate DESC
                        LIMIT 5
                    ) s
                )||'
                    </tbody>
                </table>', '') ||'
            </div>' AS marker_desc,
            t.station_alarm_icon AS marker_icon
        FROM
            t
            LEFT JOIN metadata.view_stations_info sm USING (station_id)
            LEFT JOIN bobo.view_user_stations us ON (us.station_id = t.main_station_id)

        WHERE
           us.user_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $from, $to, $user_id)->hashes();
}

sub get_alarms_bydate {
    my ( $self, $user_id, $from, $to, $net, $prov, $stat, $flag ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_alarms_bydate");

    # query
    my $sql = qq{
        SELECT
            sa.station_id,
            st.station_name,
            sa.param_id,
            CONCAT_WS(' - ', a.alarm_label, sp.stpr_note) AS alarm_label,
            a.alarm_color,
            a.alarm_icon,
            sa.sa_fulldate AS station_alarm_fulldate,
            to_char(sa.sa_fulldate, 'DD.MM h HH24'::text) AS station_alarm_fulldate_formatted,
            CASE
                WHEN sa.sa_fulldate = date_trunc('hour'::text, CURRENT_TIMESTAMP) THEN false
                ELSE (( SELECT count(*) AS count
                   FROM clients.stations_alarms t
                  WHERE t.station_id = sa.station_id AND t.param_id = sa.param_id AND t.sa_fulldate = (sa.sa_fulldate + '01:00:00'::interval))) = 0
            END AS station_alarm_off
        FROM
            clients.stations_alarms sa
            LEFT JOIN metadata.stations_parameters sp USING (stpr_id)
            LEFT JOIN clients.alarms a ON sa.param_id = a.param_id
            LEFT JOIN metadata.stations st ON sa.station_id = st.station_id
            LEFT JOIN bobo.view_user_stations us ON sa.station_id = us.station_id
    };

    if ($net != -1) {
        $sql .= qq{ LEFT JOIN metadata.view_stations_info sm ON sa.station_id = sm.station_id };
    }

    if ($prov != -1) {
        $sql .= qq{ LEFT JOIN metadata.view_stations_municipality smu ON sa.station_id = smu.station_id };
    }

    $sql .= qq{
        WHERE
            us.user_id = ?
    };

    if ($flag eq 'true') {
        $sql .= qq{ AND a.alarm_label != 'Porta' };
    };

    $sql .= qq{
        AND sa.sa_fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($net != -1) {
        $sql .= qq{ AND sm.station_network_type_id = $net };
    }

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND sa.station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            sa.sa_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_swam_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_swam_messages");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                MIN(sw_fulldate) AS sw_fulldate,
                station_id,
                sw_id,
                sw_bit_mask
            FROM clients.swam_warnings
            GROUP BY sw_fulldate::date, station_id, sw_id, sw_bit_mask
        )
        SELECT
            TO_CHAR(sw_fulldate, 'DD.MM h HH24') AS sw_fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            CASE
                WHEN sw_id = 5040 THEN ''
                WHEN sw_id = 5026 THEN 'A'
                WHEN sw_id = 5076 THEN 'B'
                WHEN sw_id = 5126 THEN 'C'
                ELSE 'n.d.'
            END AS sw_line,
            CASE
                WHEN sw_id = 5040 THEN 'class="late"'
                ELSE ''
            END AS sw_class,
            sw_id,
            jsonb_array_length(
                CASE
                    WHEN sw_id = 5040 THEN '[]'::jsonb || jsonb_build_object('code', 'Status Alarm', 'desc', 'Malfunzionamento SWAM')
                    ELSE clients.f_get_messages_swam(sw_bit_mask)
                END
            ) AS sw_num
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND sw_fulldate::date >= ( CURRENT_TIMESTAMP - interval '1 days')::date
        ORDER BY
             sw_fulldate DESC, (
                CASE
                    WHEN sw_id = 5040 THEN 0
                    ELSE 1
                END
            ) ASC, station_name;

    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_swam_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_swam_messages_bydate");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                MIN(sw_fulldate) AS sw_fulldate,
                station_id,
                sw_id,
                sw_bit_mask
            FROM clients.swam_warnings
            GROUP BY sw_fulldate::date, station_id, sw_id, sw_bit_mask
        )
        SELECT
            sw_fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            sw_id,
            CASE
                WHEN sw_id = 5040 THEN ''
                WHEN sw_id = 5026 THEN 'A'
                WHEN sw_id = 5076 THEN 'B'
                WHEN sw_id = 5126 THEN 'C'
                ELSE 'n.d.'
            END AS sw_line,
            CASE
                WHEN sw_id = 5040 THEN 'class="late"'
                ELSE ''
            END AS sw_class,
            sw_bit_mask,
            CASE
                WHEN sw_id = 5040 THEN '[]'::jsonb || jsonb_build_object('code', 'Status Alarm', 'desc', 'Malfunzionamento SWAM')
                ELSE clients.f_get_messages_swam(sw_bit_mask)
            END AS messages
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND sw_fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            sw_fulldate DESC, (
                CASE
                    WHEN sw_id = 5040 THEN 0
                    ELSE 1
                END
            ) ASC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_tecora_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_tecora_messages");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                MIN(fulldate) AS fulldate,
                station_id,
                COUNT(*) AS num
            FROM clients.tecora_warnings
            GROUP BY fulldate::date, station_id, warning_id
        )
        SELECT
            TO_CHAR(fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            num
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY
            fulldate DESC, station_name
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_tecora_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_tecora_messages_bydate");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                DATE_TRUNC('hour', fulldate) AS fulldate,
                station_id,
                MIN( tm.message ) AS message,
                COUNT(*) AS num
            FROM clients.tecora_warnings tw
            LEFT JOIN clients.tecora_messages tm ON (tm.id = tw.warning_id)
            GROUP BY DATE_TRUNC('hour', fulldate), station_id, warning_id
        )
        SELECT
            fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            message,
            num
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_derenda_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_derenda_messages");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                MIN(fulldate) AS fulldate,
                station_id,
                COUNT(*) AS num
            FROM clients.derenda_warnings
            GROUP BY fulldate::date, station_id, warning_id
        )
        SELECT
            TO_CHAR(fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            num
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY
            fulldate DESC, station_name
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_derenda_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_derenda_messages_bydate");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                DATE_TRUNC('hour', fulldate) AS fulldate,
                station_id,
                MIN( tm.message ) AS message,
                COUNT(*) AS num
            FROM clients.derenda_warnings tw
            LEFT JOIN clients.derenda_messages tm ON (tm.id = tw.warning_id)
            GROUP BY DATE_TRUNC('hour', fulldate), station_id, warning_id
        )
        SELECT
            fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            message,
            num
        FROM t
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_envea_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_envea_messages");

    # query
    my $sql = qq{
        SELECT
            TO_CHAR(fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            jsonb_array_length(clients.f_get_messages_envea(warning_id::integer::bit(11))) AS num

        FROM clients.envea_warnings
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY
            fulldate DESC, station_name
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_envea_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_envea_messages_bydate");

    # query
    my $sql = qq{
        SELECT
            fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            warning_id,
            clients.f_get_messages_envea(warning_id::integer::bit(11)) AS message
        FROM clients.envea_warnings
        LEFT JOIN bobo.view_user_stations us USING (station_id)
        LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_metone_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_metone_messages");

    # query
    my $sql = qq{
        SELECT
            TO_CHAR(fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            jsonb_array_length(clients.f_get_messages_metone(warning_id::integer)) AS num
        FROM
            clients.metone_warnings
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY
            fulldate DESC, station_name
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_metone_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_metone_messages_bydate");

    # query
    my $sql = qq{
        SELECT
            fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            warning_id,
            clients.f_get_messages_metone(warning_id::integer) AS message
        FROM
            clients.metone_warnings
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_fidas_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_fidas_messages");

    # query
    my $sql = qq{
        SELECT
            TO_CHAR(fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            station_id,
            smu.station_name,
            smu.province_code,
            jsonb_array_length(clients.f_get_messages_fidas(bit_mask)) AS num
        FROM
            clients.fidas_warnings
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        ORDER BY
            fulldate DESC, station_name
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_fidas_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_fidas_messages_bydate");

    # query
    my $sql = qq{
        SELECT
            fulldate,
            station_id,
            smu.station_name,
            smu.province_code,
            bit_mask,
            clients.f_get_messages_fidas(bit_mask) AS messages
        FROM
            clients.fidas_warnings
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
        AND fulldate BETWEEN ?::timestamp AND ?::timestamp
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_last_teledyne_messages {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_last_teledyne_messages");

    # query
    my $sql = qq{
        SELECT
            TO_CHAR(w.fulldate, 'DD.MM h HH24') AS fulldate_formatted,
            w.station_id,
            CONCAT_WS(' - ', smu.station_name, vsi.instrument_type_fullname) AS station_name,
            smu.province_code,
            jsonb_array_length(clients.f_get_messages_teledyne(w.warning_id::bigint)) AS num
        FROM
            clients.teledyne_warnings w
            LEFT JOIN metadata.view_stations_instruments vsi USING (station_id, stpr_group_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> (w.fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome')
        ORDER BY
            w.fulldate DESC, smu.station_name, w.stpr_group_id
        LIMIT 10;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

sub get_teledyne_messages_bydate {
    my ( $self, $user_id, $from, $to, $prov, $stat ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_teledyne_messages_bydate");

    # query
    my $sql = qq{
        SELECT
            w.fulldate,
            w.station_id,
            smu.station_name,
            vsi.instrument_type_fullname,
            smu.province_code,
            w.warning_id,
            clients.f_get_messages_teledyne(w.warning_id::bigint) AS message
        FROM
            clients.teledyne_warnings w
            LEFT JOIN metadata.view_stations_instruments vsi USING (station_id, stpr_group_id)
            LEFT JOIN bobo.view_user_stations us USING (station_id)
            LEFT JOIN metadata.view_stations_municipality smu USING (station_id)
        WHERE
            us.user_id = ?
            AND w.fulldate BETWEEN ?::timestamp AND ?::timestamp
            AND tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> (w.fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome')
    };

    if ($prov != -1) {
        $sql .= qq{ AND smu.province_id = $prov };
    }

    if ($stat != -1) {
        $sql .= qq{ AND station_id = $stat };
    }

    $sql .= qq{
        ORDER BY
            fulldate DESC
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_links {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_links");

    # query
    my $sql = qq{
        SELECT
            link_id,
            link_name,
            link_url
        FROM
            bobo_tools.homepage_links
        WHERE
            link_default IS FALSE
            AND portal_id = (SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?)
            AND link_image_url IS NULL
        ORDER BY link_name;
    };

    # return
    return $self->pg->db->query($sql, $userid)->hashes();
}

sub get_user_links {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbhome sub get_user_links");

    # query
    my $sql = qq{
        WITH l AS(
            SELECT option_object->'links' AS links
            FROM bobo.user_options
            WHERE
                option_user = ?
        ),
        u AS (
            SELECT
                link_id,
                link_name,
                link_url,
                link_image_url,
                CASE
                    WHEN link_image_url NOTNULL THEN 1
                    ELSE 0
                END AS link_is_image,
                link_default,
                pos AS link_pos
            FROM jsonb_to_recordset( (SELECT links FROM l)::jsonb ) AS t(link_id int, pos int)
            LEFT JOIN bobo_tools.homepage_links USING (link_id)
        ),
        d AS (
            SELECT
                link_id,
                link_name,
                link_url,
                link_image_url,
                CASE
                    WHEN link_image_url NOTNULL THEN 1
                    ELSE 0
                END AS link_is_image,
                link_default,
                1000 AS link_pos
            FROM
                bobo_tools.homepage_links
            WHERE
                link_default IS TRUE
                AND portal_id = (SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?)
                AND link_id NOT IN (SELECT link_id FROM u)

        )
        SELECT * FROM u
        UNION
        SELECT * FROM d
        ORDER BY link_is_image, link_pos, link_id
    };

    # return
    return $self->pg->db->query($sql, $userid, $userid)->hashes();
}

1;

=head1 welcome

Funzione che recupera la data e ora corrente.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_widget_by_id

Funzione che recupera, dato l'id, le informazioni relative ad un determinato widget
dal database.

Argomenti:  * id dell'utente ('user_id');

           * id del widget ('wdgid');

Return:     Risultato della query;

=cut

=head1 get_delays

Funzione che recupera le informazioni relative allo stato delle stazioni per il widget
presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_instr_delays

Funzione che recupera le informazioni relative allo stato degli strumenti presenti sulle stazioni
per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_last_alarms

Funzione che recupera le informazioni relative agli allarmi scattati nelle stazioni
negli ultimi 10 minuti per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_last_reports

Funzione che recupera le informazioni relative agli ultimi report tarature/manutenzioni
per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_open_doors_bydates

Funzione che recupera le informazioni relative agli allarmi di tipo 'Porta aperta' scattati in
un determinato periodo temporale per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query;

=cut

=head1 get_alarms_bydate

Funzione che recupera le informazioni relative agli allarmi scattati in
un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per rete, provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della rete ('net');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

           * valore booleano che indica se nascondere o meno gli allarmi di tipo 'Porta aperta' ('flag');

Return:     Risultato della query;

=cut

=head1 get_last_swam_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento SWAM per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_swam_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento SWAM in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_tecora_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento TECORA per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_tecora_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento TECORA in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_derenda_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento DERENDA per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_derenda_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento DERENDA in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_envea_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento ENVEA per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_envea_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento ENVEA in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_metone_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento METONE per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_metone_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento METONE in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_fidas_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento FIDAS per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_fidas_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning dello
strumento FIDAS in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_last_teledyne_messages

Funzione che recupera le informazioni relative agli ultimi messaggi di warning degli
strumenti TELEDYNE per il widget presente in homepage dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_teledyne_messages_bydate

Funzione che recupera le informazioni relative agli ultimi messaggi di warning degli
strumenti TELEDYNE in un determinato periodo temporale con la possibilita' di filtrare i dati estratti
per provincia e stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * eventuale id della provincia ('prov');

           * eventuale id della stazione ('stat');

Return:     Risultato della query;

=cut

=head1 get_links

Funzione che recupera le informazioni relative ai link utili all'interno del
widget presente in homepage dal database.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_user_links

Funzione che recupera le informazioni relative ai link utili inseriti dall'utente
all'interno del widget presente in homepage dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query;

=cut
