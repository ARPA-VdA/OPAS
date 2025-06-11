package Bobo::Model::Dbdatamanager;
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

# !! MAPPER
sub get_data_station {
    my ( $self, $stid, $from, $to, $conv, $all ) = @_;

    # get stations
    # my $station = $self->app->dbcommon->get_station_by_id($station_id);
    # my $station_data_tbl = $station->{'station_fulltable'};
    # $self->app->log->debug($station_data_tbl);


    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_data_station");
    $self->app->log->debug("Date FROM $from");
    $self->app->log->debug("Date TO $to");
    $self->app->log->debug("Conversione $conv");

    my $operation = '';
    if ($conv eq 'true') {
        # UPDATE 19/06/2024 10:56
        # $operation = '* parameter_conv';
        $operation = '* metadata.f_get_conversion_by_date_prid( parameter_id, tbl.measure_date_time ) ';
    }

    my $validity_code = '';
    if ($all eq 'true') {
        $validity_code = ", '< 2147483647'::text";
    }

    my $sql = qq{
        SELECT
            station_name,
            station_fulltable,
            station_param_id,
            parameter_id,
            station_param_table_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_decimals,
            parameter_active,
            parameter_type_id,
            measure_cadence_min AS station_param_cadence_min,
            station_param_measure_type_id,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            COALESCE(parameter_object->'general'->>'windroseV', 'false')::boolean AS parameter_windv,
            COALESCE(parameter_object->'general'->>'windroseD', 'false')::boolean AS parameter_windd,
            (
                SELECT row_to_json(row) FROM (
                    SELECT
                        ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_value $operation)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS meanvalue,
                        ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_min   $operation)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS minvalue,
                        ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_max   $operation)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS maxvalue
                    FROM
                        clients.f_data_extraction(station_param_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, COALESCE(parameter_object->'general'->>'treatment', 'avg')::metadata.e_treatments $validity_code) tbl
                    GROUP BY tbl.measure_id
                ) row
            ) AS station_data,
            CASE
                WHEN (parameter_object->'general'->>'treatment' = 'sum') THEN
                    ARRAY(
                            SELECT
                                ARRAY[EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND( (SUM((tbl.measure_value $operation)) OVER (ORDER BY tbl.measure_date_time) )::numeric, parameter_decimals)]
                            FROM
                                clients.f_data_extraction(station_param_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, (parameter_object-> 'general'->>'treatment')::metadata.e_treatments $validity_code) tbl
                            ORDER BY tbl.measure_date_time
                        )
                ELSE NULL
            END AS station_data_cum
        FROM
            metadata.view_stations_parameters vsp
            LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = vsp.station_param_cadence_type_id
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
        WHERE station_id = ?
        AND station_param_active IS TRUE
        AND ( parameter_type_id < 4 OR parameter_type_id > 13 OR param_id IN (163,164))
        ORDER BY
            (
                CASE
                    WHEN parameter_type_id IN (2,3) THEN 1
                    WHEN parameter_type_id = 1 THEN 2
                    WHEN parameter_type_id IS NULL THEN 1000
                    WHEN parameter_type_id = 14 THEN parameter_type_id + 1000
                    ELSE parameter_type_id
                END
            ) ASC, param_order ASC, parameter_name
    };

    # return
    # return $self->pg->db->query($sql, $date_from, $date_to, $station_id)->hashes();
    return $self->pg->db->query($sql, $from, $to, $from, $to, $stid)->hashes();
}

sub get_data_by_stprid {
    my ( $self, $from, $to, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_data_by_stprid");

    my $sql;
    #  !! LOOP THROUGH ID AND PUSH RESULT IN ARRAY
    my @data;

    for my $param ( @{$params} ){
        my $sql = qq{
            SELECT
                station_name,
                station_fulltable,
                station_param_id,
                parameter_id,
                station_param_table_id,
                parameter_name,
                parameter_unit,
                parameter_conv,
                parameter_unit_conv,
                parameter_decimals,
                parameter_active,
                parameter_type_id,
                measure_cadence_min AS station_param_cadence_min,
                station_param_measure_type_id,
                COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
                COALESCE(parameter_object->'general'->>'windroseV', 'false')::boolean AS parameter_windv,
                COALESCE(parameter_object->'general'->>'windroseD', 'false')::boolean AS parameter_windd,
                (
                    SELECT row_to_json(row) FROM (
                        SELECT
                            ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_value)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS meanvalue,
                            ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_min  )::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS minvalue,
                            ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint , ROUND((tbl.measure_max  )::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS maxvalue
                        FROM
                            clients.f_data_extraction(station_param_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, COALESCE(parameter_object->'general'->>'treatment', 'avg')::metadata.e_treatments) tbl
                        GROUP BY tbl.measure_id
                    ) row
                ) AS station_data,
                CASE
                    WHEN (parameter_object->'general'->>'treatment' = 'sum') THEN
                        ARRAY(
                                SELECT
                                    ARRAY[EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND((SUM(tbl.measure_value) OVER (ORDER BY tbl.measure_date_time))::numeric, parameter_decimals)]
                                FROM
                                    clients.f_data_extraction(station_param_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, (parameter_object-> 'general'->>'treatment')::metadata.e_treatments) tbl
                                ORDER BY tbl.measure_date_time
                            )
                    ELSE NULL
                END AS station_data_cum
            FROM
                metadata.view_stations_parameters vsp
                LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = vsp.station_param_cadence_type_id
                LEFT JOIN bobo_tools.parameters_options po USING (param_id)
            WHERE
                station_param_id = ?
        };

        my $res = $self->pg->db->query($sql, $from, $to, $from, $to, $param )->hash;

        if (defined $res){
            push @data, $res;
        }
    }

    # return
    return \@data;
}

sub get_data_per_validation_by_stprid {
    my ( $self, $from, $to, $stprid, $conv ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_data_per_validation_by_stprid");

    my $operation = '';
    if ($conv eq 'true') {
        # UPDATE 19/06/2024 10:56
        # $operation = '* parameter_conv';
        $operation = '* metadata.f_get_conversion_by_date_prid( parameter_id, tbl.measure_date_time ) ';
    }

    # query
    my $sql = qq{
        SELECT
            station_name,
            station_fulltable,
            station_param_id,
            parameter_id,
            station_param_table_id,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_decimals,
            parameter_active,
            parameter_type_id,
            station_param_cadence_type_id,
            measure_cadence_min AS station_param_cadence_min,
            station_param_measure_type_id,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            COALESCE(parameter_object->'general'->>'windroseV', 'false')::boolean AS parameter_windv,
            COALESCE(parameter_object->'general'->>'windroseD', 'false')::boolean AS parameter_windd,
            (
                SELECT row_to_json(row) FROM (
                    SELECT
                        ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint, CASE WHEN tbl.post_validity_code >= 0 THEN ROUND((tbl.measure_value $operation)::numeric, parameter_decimals) ELSE NULL::numeric END] ORDER BY  tbl.measure_date_time) AS meanvalue_valid,
                        ARRAY_AGG(ARRAY[ ( EXTRACT(EPOCH FROM tbl.measure_date_time)*1000 )::bigint, CASE WHEN tbl.post_validity_code < 0 THEN ROUND((tbl.measure_value   $operation)::numeric, parameter_decimals) ELSE NULL::numeric END] ORDER BY  tbl.measure_date_time) AS meanvalue_not_valid
                    FROM
                        clients.f_data_extraction(station_param_id, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, COALESCE(parameter_object->'general'->>'treatment', 'avg')::metadata.e_treatments, '< 2147483647'::text ) tbl
                    GROUP BY tbl.measure_id
                ) row
            ) AS station_data
        FROM
            metadata.view_stations_parameters vsp
            LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = vsp.station_param_cadence_type_id
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
        WHERE
            station_param_id = ?
    };

    my $data = $self->pg->db->query($sql, $from, $to, $stprid )->hash;

    # return
    return $data;
}

sub get_inst_data_station {
    my ( $self, $station_id, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_inst_data_station");

    my $sql = qq{
        SELECT
            vsp.station_name,
            station_param_id,
            parameter_id,
            station_param_table_id,
            stpr_group_id,
            parameter_name,
            parameter_shortname,
            instrument_type_fullname
            || COALESCE(' - '||instrument_name, '')
            || COALESCE(' ['||instrument_arpa_id||'] ', '')     AS instrument_name,
            parameter_unit,
            (
                SELECT row_to_json(row) FROM (
                    SELECT
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time AT TIME ZONE 'Europe/Rome' AT TIME ZONE 'Europe/Rome')*1000, ROUND(tbl.measure_value::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS meanvalue,
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time AT TIME ZONE 'Europe/Rome' AT TIME ZONE 'Europe/Rome')*1000, tbl.station_code] ORDER BY  tbl.measure_date_time) AS station_alarms,
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time AT TIME ZONE 'Europe/Rome' AT TIME ZONE 'Europe/Rome')*1000, tbl.measure_code] ORDER BY  tbl.measure_date_time) AS measure_alarms
                    FROM
                        clients.f_inst_data_extraction(station_param_id,  (?::timestamp - interval '1 hour')::timestamp, ?::timestamp) tbl
                    GROUP BY tbl.measure_id
                ) row
            ) AS station_data
        FROM
            metadata.view_stations_parameters vsp
            LEFT JOIN metadata.view_stations_instruments vsi USING (stpr_group_id)
        WHERE
            vsp.station_id = ?
            AND instr_id IS NOT NULL
            AND tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
            AND station_param_active IS TRUE
            AND ( parameter_type_id < 4 OR parameter_type_id > 13 )
        ORDER BY
            stpr_group_id ASC,
            (
                CASE
                    WHEN parameter_type_id IN (2,3) THEN 1
                    WHEN parameter_type_id = 1 THEN 2
                    WHEN parameter_type_id IS NULL THEN 1000
                    WHEN parameter_type_id = 14 THEN parameter_type_id + 1000
                    ELSE parameter_type_id
                END
            ) ASC, station_param_id ASC
    };

    # return
    return $self->pg->db->query($sql, $to, $to, $station_id)->hashes();
}

sub get_inst_data_table {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_inst_data_table");
    $self->app->log->debug($station_id);

    # query
    my $sql = qq{
        SELECT
            (
                SELECT COUNT(*)
                FROM information_schema.tables
                WHERE table_schema = st.station_schema
                AND table_name = COALESCE(st.station_prefix, '') || st.station_table || '_inst'
            ) AS table_exists,
            st.station_schema || '.' || COALESCE(st.station_prefix, '') || st.station_table || '_inst' AS station_fulltable
        FROM
            metadata.stations st
        WHERE
            station_id = ?;
    };

    my $result = $self->pg->db->query($sql, $station_id)->hash;
    if ($result->{'table_exists'} == 0) {
        return -1;
    }
    else {
        my $table = $result->{'station_fulltable'};

        # query
        $sql = qq{
            WITH t AS(
                SELECT MAX(measure_date_time) AS max_date
                FROM $table
            )
            SELECT
                vsp.station_name,
                parameter_name,
                parameter_shortname,
                CASE
                    WHEN parameter_type_id IN (1, 2, 3) THEN '<i class="far fa-home text-info ico-main-type" data-original-title="Principale" data-toggle="tooltip"></i>'
                    WHEN parameter_type_id IN (13) THEN '<i class="far fa-search text-success ico-main-type" data-original-title="Diagnostico" data-toggle="tooltip"></i>'
                    ELSE '<i class="far fa-bell-on text-danger ico-main-type" data-original-title="Allarme" data-toggle="tooltip"></i>'
                END AS parameter_icon,
                CASE
                    WHEN instr_id NOTNULL THEN instrument_type_fullname
                        || COALESCE(' - '||instrument_name, '')
                        || COALESCE(' ['||instrument_arpa_id||'] ', '')
                    WHEN parameter_type_id = 1 THEN 'Sensore meteo'
                    ELSE 'Stazione'
                END AS instrument_name,
                parameter_unit,
                measure_date_time,
                measure_value,
                station_code,
                measure_code
            FROM
                $table tbl
                LEFT JOIN metadata.view_stations_parameters vsp ON ( vsp.station_id = ? AND tbl.measure_id = vsp.stpr_table_id)
                LEFT JOIN metadata.view_stations_instruments vsi USING (stpr_group_id), t
            WHERE
                measure_date_time = t.max_date
                AND ( tsrange(station_instr_startup_date, station_instr_dismiss_date, '[]') @> (t.max_date::timestamp AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome') OR instr_id ISNULL )
                AND station_param_active IS TRUE
            ORDER BY
            (
                CASE
                    WHEN parameter_type_id IN (2, 3) THEN 1
                    WHEN parameter_type_id = 1 THEN 2
                    WHEN parameter_type_id IS NULL THEN 1000
                    WHEN parameter_type_id = 14 THEN parameter_type_id + 1000
                    ELSE parameter_type_id
                END
            ) ASC, station_param_id ASC
        };

        # return
        return $self->pg->db->query($sql, $station_id)->hashes();
    }
}

# !! ANALYSER & VISUALIZER
sub get_highcharts_data_by_dates {
    my ( $self, $from, $to, $hide_nulls, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_highcharts_data_by_dates");

    my $sql;
    my $params_array = $macro->{'params'};
    my $aggregation  = $macro->{macro}{aggregation};
    my $percent  = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    if (!defined $validity_code) {
        $validity_code = '< 2147483647';
    }

    # !! LOOP THROUGH ID AND PUSH RESULT IN ARRAY
    my @data;

    for my $param (@{$params_array}) {
        my $res;
        my $treatment = $param->{'treatment'};

        if ($treatment eq 'sldavg') {
            $res = $self->get_highcharts_moving_average( $from, $to, $hide_nulls, $macro, $param );
        }
        else {
            my $decimals = $param->{'decimals'};
            my $formule  = $param->{'formule'};
            my $stprid   = $param->{'st_pr_id'};
            my $prid     = $param->{'param_id'};
            my $table;

            # check if stprid greater than 0
            # if true then it's a normal station-parameter
            # otherwise it is a parameter linked to an allocated MM
            if( $stprid > 0){
                $table = 'metadata.stations_parameters';
            }
            else{
                $table = 'metadata.f_get_view_sites_parameters('.$stprid.'::bigint)';
            }

            $formule =~ s/y=//;
            # $formule =~ s/x/tbl.measure_value/;
            my $mean = $formule;
            my $min  = $formule;
            my $max  = $formule;

            if ($param->{'converted'}) {
                $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
                $min  =~ s/x/( tbl.measure_min * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
                $max  =~ s/x/( tbl.measure_max * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            }
            else {
                $mean =~ s/x/tbl.measure_value/g;
                $min  =~ s/x/tbl.measure_min/g;
                $max  =~ s/x/tbl.measure_max/g;
            }

            if ($treatment eq 'cum') {
                $mean = qq{SUM( $mean ) OVER (ORDER BY tbl.measure_date_time)};
                $min  = qq{SUM( $min  ) OVER (ORDER BY tbl.measure_date_time)};
                $max  = qq{SUM( $max  ) OVER (ORDER BY tbl.measure_date_time)};
                $treatment = 'sum';
            }

            # $self->app->log->debug("$mean");

            my $sql = qq{
                WITH d AS (
                    SELECT
                        ARRAY[
                            EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                            CASE
                                WHEN tbl.measure_perc >= ? THEN ROUND( $mean, $decimals )
                                ELSE NULL
                            END
                        ] AS measure_value,
                        ARRAY[
                            EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                            CASE
                                WHEN tbl.measure_perc >= ? THEN ROUND( $min, $decimals )
                                ELSE NULL
                            END
                        ] AS measure_min,
                        ARRAY[
                            EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                            CASE
                                WHEN tbl.measure_perc >= ? THEN ROUND( $max, $decimals )
                                ELSE NULL
                            END
                        ] AS measure_max
                    FROM clients.f_data_extraction(?, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, '$treatment'::metadata.e_treatments, ?::text) tbl
            };

            if ($hide_nulls eq 'true') {
                $sql.= qq{            WHERE tbl.measure_value IS NOT NULL};
            }

            $sql .=qq { ORDER BY tbl.measure_date_time
                ),
                a AS (
                    SELECT
                        ?::bigint AS stpr_id,
                        ARRAY(SELECT measure_value FROM d) AS station_param_values,
                        ARRAY(SELECT measure_min FROM d)   AS station_min_values,
                        ARRAY(SELECT measure_max FROM d)   AS station_max_values
                )
                SELECT
                    sp.stpr_id AS station_param_id,
                    sp.station_id,
                    sp.param_id,
                    sp.stpr_table_id,
                    s.station_name,
                    s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
                    p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
                    p.param_unit        AS parameter_unit,
                    p.param_conv        AS parameter_conv,
                    p.param_unit_conv   AS parameter_unit_conv,
                    p.param_decimals    AS parameter_decimals,
                    CASE
                        WHEN TRUE = ALL (select unnest(a.station_param_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                        ELSE a.station_param_values
                    END AS station_param_values,
                    CASE
                        WHEN TRUE = ALL (select unnest(a.station_min_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                        ELSE a.station_min_values
                    END AS station_min_values,
                    CASE
                        WHEN TRUE = ALL (select unnest(a.station_max_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                        ELSE a.station_max_values
                    END AS station_max_values
                FROM
                    a
                    LEFT JOIN $table sp USING (stpr_id)
                    LEFT JOIN metadata.parameters p USING (param_id)
                    LEFT JOIN metadata.stations s USING (station_id)
            };

            # $self->app->log->debug($sql, $percent, $from, $to, $aggregation, $validity_code, $param->{'st_pr_id'});

            $res = $self->pg->db->query($sql, $percent, $percent, $percent, $stprid, $from, $to, $aggregation, $validity_code, $stprid )->hash();
            # my $res = $self->pg->db->query($sql, $from, $to, $percent, $param->{'st_pr_id'})->hash();
        }

        if (defined $res){
            push @data, $res;
        }
    }
    return \@data;
}

sub get_highcharts_moving_average {
    my ( $self, $from, $to, $hide_nulls, $macro, $param ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_highcharts_moving_average");

    my $sql;
    my $aggregation  = $macro->{macro}{aggregation};
    my $percent  = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    my $window = 8;
    if (defined $param->{'window'} && $param->{'window'} ne '') {
        $window = $param->{'window'};
    }

    if (!defined $validity_code) {
        $validity_code = '< 2147483647';
    }

    my $decimals = $param->{'decimals'};
    my $formule = $param->{'formule'};
    my $stprid  = $param->{'st_pr_id'};
    my $prid    = $param->{'param_id'};
    my $table;

    # check if stprid greater than 0
    # if true then it's a normal station-parameter
    # otherwise it is a parameter linked to an allocated MM
    if( $stprid > 0){
        $table = 'metadata.stations_parameters';
    }
    else{
        $table = 'metadata.f_get_view_sites_parameters('.$stprid.'::bigint)';
    }

    $formule =~ s/y=//;
    # $formule =~ s/x/tbl.measure_value/;

    my $mean = $formule;
    my $min  = $formule;
    my $max  = $formule;

    if ($param->{'converted'}) {
        $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        $min  =~ s/x/( tbl.measure_min * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        $max  =~ s/x/( tbl.measure_max * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
    }
    else {
        $mean =~ s/x/tbl.measure_value/g;
        $min  =~ s/x/tbl.measure_min/g;
        $max  =~ s/x/tbl.measure_max/g;
    }

    $self->app->log->debug("$mean");

    $sql = qq{
        WITH d AS (
            SELECT
                ARRAY[
                    EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                    CASE
                        WHEN tbl.measure_perc >= ? THEN ROUND( $mean , $decimals )
                        ELSE NULL
                    END
                ] AS measure_value,
                ARRAY[
                    EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                    CASE
                        WHEN tbl.measure_perc >= ? THEN ROUND( $min , $decimals )
                        ELSE NULL
                    END
                ] AS measure_min,
                ARRAY[
                    EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                    CASE
                        WHEN tbl.measure_perc >= ? THEN ROUND( $max , $decimals )
                        ELSE NULL
                    END
                ] AS measure_max
            FROM clients.f_sldavg_data_extraction(?::bigint, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, ?::text, $window ::integer) tbl
    };

    if ($hide_nulls eq 'true') {
        $sql.= qq{            WHERE tbl.measure_value IS NOT NULL};
    }

    $sql .=qq { ORDER BY tbl.measure_date_time
        ),
        a AS (
            SELECT
                ?::bigint AS stpr_id,
                ARRAY(SELECT measure_value FROM d) AS station_param_values,
                ARRAY(SELECT measure_min FROM d)   AS station_min_values,
                ARRAY(SELECT measure_max FROM d)   AS station_max_values
        )
        SELECT
            sp.stpr_id AS station_param_id,
            sp.station_id,
            sp.param_id,
            sp.stpr_table_id,
            s.station_name,
            s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
            p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
            p.param_unit        AS parameter_unit,
            p.param_conv        AS parameter_conv,
            p.param_unit_conv   AS parameter_unit_conv,
            p.param_decimals    AS parameter_decimals,
            CASE
                WHEN TRUE = ALL (select unnest(a.station_param_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                ELSE a.station_param_values
            END AS station_param_values,
            CASE
                WHEN TRUE = ALL (select unnest(a.station_min_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                ELSE a.station_min_values
            END AS station_min_values,
            CASE
                WHEN TRUE = ALL (select unnest(a.station_max_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                ELSE a.station_max_values
            END AS station_max_values
        FROM
            a
            LEFT JOIN $table sp USING (stpr_id)
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN metadata.stations s USING (station_id)
    };

    # $self->app->log->debug($sql, $percent, $from, $to, $aggregation, $validity_code, $param->{'st_pr_id'});

    # return
    return $self->pg->db->query($sql, $percent, $percent, $percent, $param->{'st_pr_id'}, $from, $to, $aggregation, $validity_code, $param->{'st_pr_id'} )->hash();
}

sub get_highcharts_representative_data_by_dates {
    my ( $self, $from, $to, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_highcharts_representative_data_by_dates");

    my $sql;
    my $params_array = $macro->{'params'};
    my $aggregation  = $macro->{macro}{aggregation};
    my $percent  = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    if (!defined $validity_code) {
        $validity_code = '< 2147483647';
    }

    my $extract;
    my $format;

    if ($aggregation =~ /rep\_day/) {
        $extract = 'hour';
        $format = 'HH24';
    }
    elsif ($aggregation =~ /rep\_week/) {
        $extract = 'isodow';
        $format = 'TMDay';
    }
    elsif ($aggregation =~ /rep\_year/) {
        $extract = 'month';
        $format = 'TMMonth';
    }

    # !! LOOP THROUGH ID AND PUSH RESULT IN ARRAY
    my @data;

    for my $param (@{$params_array}) {
        my $res;
        my $treatment = $param->{'treatment'};

        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $stprid  = $param->{'st_pr_id'};
        my $prid    = $param->{'param_id'};
        my $table;

        # check if stprid greater than 0
        # if true then it's a normal station-parameter
        # otherwise it is a parameter linked to an allocated MM
        if( $stprid > 0){
            $table = 'metadata.stations_parameters';
        }
        else{
            $table = 'metadata.f_get_view_sites_parameters('.$stprid.'::bigint)';
        }

        $formule =~ s/y=//;
        # $formule =~ s/x/tbl.measure_value/;
        my $mean = $formule;
        # $mean =~ s/x/tbl.measure_value/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
        }

        $self->app->log->debug("$mean");

        my $sql = qq{
            WITH t AS(
                SELECT
                    EXTRACT('$extract' from tbl.measure_date_time) as measure_group,
                    TO_CHAR(tbl.measure_date_time, '$format') as measure_category,
                    $mean AS measure_value
                FROM clients.f_data_extraction(?::bigint, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, ?::text) tbl
                ORDER BY tbl.measure_date_time
            ),
            d AS (
                SELECT
                    ARRAY[
                        measure_category,
                        ROUND( AVG(measure_value) , $decimals )::text
                    ] AS measure_value
                FROM t
                GROUP BY measure_group, measure_category
                ORDER BY measure_group, measure_category
            ),
            a AS (
                SELECT
                    ?::bigint AS stpr_id,
                    ARRAY(SELECT measure_value FROM d) AS station_param_values
            )
            SELECT
                sp.stpr_id AS station_param_id,
                sp.station_id,
                sp.param_id,
                sp.stpr_table_id,
                s.station_name,
                s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
                p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
                p.param_unit        AS parameter_unit,
                p.param_conv        AS parameter_conv,
                p.param_unit_conv   AS parameter_unit_conv,
                p.param_decimals    AS parameter_decimals,
                CASE
                    WHEN TRUE = ALL (select unnest(a.station_param_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::text[]
                    ELSE a.station_param_values
                END AS station_param_values
            FROM
                a
                LEFT JOIN $table sp USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.stations s USING (station_id)
        };

        # $self->app->log->debug($sql, $param->{'st_pr_id'}, $from, $to, $validity_code);

        $res = $self->pg->db->query($sql, $param->{'st_pr_id'}, $from, $to, $validity_code, $param->{'st_pr_id'} )->hash();
        # my $res = $self->pg->db->query($sql, $from, $to, $percent, $param->{'st_pr_id'})->hash();


        if (defined $res){
            push @data, $res;
        }
    }
    return \@data;
}

sub get_highcharts_data_per_year {
    my ( $self, $from, $to, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_highcharts_data_per_year");

    my $sql;
    my @params_array = @{$macro->{'params'}};
    my $param = $params_array[0];
    my $aggregation  = $macro->{macro}{aggregation};
    my $percent  = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    if (!defined $validity_code) {
        $validity_code = '< 2147483647';
    }

    # !! LOOP THROUGH YEARS AND PUSH RESULT IN ARRAY
    my @data;
    my $trunc;
    if ($aggregation =~ /hh/) {
        $trunc = 'hour';
    }
    elsif ($aggregation =~ /dd/) {
        $trunc = 'day';
    }
    elsif ($aggregation =~ /mm/) {
        $trunc = 'month';
    }
    elsif ($aggregation =~ /yy/) {
        $trunc = 'year';
    }

    my $tm_from = Time::Moment->from_string($from.'z', lenient => 1);
    my $year_from = $tm_from->year;

    my $tm_to = Time::Moment->from_string($to.'z', lenient => 1);
    my $year_to = $tm_to->year;

    my @years = ($year_from..$year_to);
    for my $year (@years){

        my $res;
        my $treatment = $param->{'treatment'};
        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $stprid  = $param->{'st_pr_id'};
        my $prid    = $param->{'param_id'};
        my $table;

        # check if stprid greater than 0
        # if true then it's a normal station-parameter
        # otherwise it is a parameter linked to an allocated MM
        if( $stprid > 0){
            $table = 'metadata.stations_parameters';
        }
        else{
            $table = 'metadata.f_get_view_sites_parameters('.$stprid.'::bigint)';
        }

        $formule =~ s/y=//;
        # $formule =~ s/x/tbl.measure_value/;
        my $mean = $formule;
        # $mean =~ s/x/tbl.measure_value/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
        }

        if ($treatment eq 'cum') {
            $mean = qq{SUM( $mean ) OVER (ORDER BY tbl.measure_date_time)};
            $treatment = 'sum';
        }

        my $sql = qq{
            WITH m AS (
                SELECT
                    DATE_TRUNC('$trunc', ('2000-01-01 00:00'::timestamp + interval '60 minute' * s.a)::timestamp) AS measure_date_time
                FROM
                    generate_series(0,(EXTRACT(EPOCH FROM '2000-12-31 23:00'::timestamp
                    - '2000-01-01 00:00'::timestamp)/3600)::integer) AS s(a)
                GROUP BY 1
                ORDER BY 1
            ),
            d AS (
                SELECT
                    ARRAY[
                        EXTRACT(EPOCH FROM m.measure_date_time)*1000,
                        CASE
                            WHEN tbl.measure_perc >= ? THEN ROUND( $mean , $decimals )
                            ELSE NULL
                        END
                    ] AS measure_value

                FROM
                    m
                    LEFT JOIN clients.f_data_extraction(?::bigint, '$year-01-01 00:00:00'::timestamp, '$year-12-31 23:59:59'::timestamp, ?::metadata.e_aggregations, '$treatment'::metadata.e_treatments, ?::text) tbl ON( TO_CHAR(m.measure_date_time, 'DD-MM HH24:MI') = TO_CHAR(tbl.measure_date_time, 'DD-MM HH24:MI') )
                ORDER BY m.measure_date_time
            ),
            a AS (
                SELECT
                    ?::bigint AS stpr_id,
                    ARRAY(SELECT measure_value FROM d) AS station_param_values
            )
            SELECT
                ($year)::text AS year,
                sp.stpr_id AS station_param_id,
                sp.station_id,
                sp.param_id,
                sp.stpr_table_id,
                s.station_name,
                s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
                p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
                p.param_unit        AS parameter_unit,
                p.param_conv        AS parameter_conv,
                p.param_unit_conv   AS parameter_unit_conv,
                p.param_decimals    AS parameter_decimals,
                CASE
                    WHEN TRUE = ALL (select unnest(a.station_param_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                    ELSE a.station_param_values
                END AS station_param_values
            FROM
                a
                LEFT JOIN $table sp USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.stations s USING (station_id)
        };

        # $self->app->log->debug($sql, $percent, $from, $to, $aggregation, $validity_code, $param->{'st_pr_id'});

        $res = $self->pg->db->query($sql, $percent, $param->{'st_pr_id'}, $aggregation, $validity_code, $param->{'st_pr_id'} )->hash();
        # my $res = $self->pg->db->query($sql, $from, $to, $percent, $param->{'st_pr_id'})->hash();

        if (defined $res){
            push @data, $res;
        }
    }
    return \@data;
}

sub get_highcharts_query {
    my ( $self, $from, $to, $hide_nulls, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_highcharts_query");

    my $sql = '';
    my $params_array = $macro->{'params'};
    my $aggregation  = $macro->{macro}{aggregation};
    my $percent  = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    if (!defined $validity_code) {
        $validity_code = '< 2147483647';
    }

    #  !! LOOP THROUGH ID AND PUSH RESULT IN ARRAY
    my @data;

    for my $param (@{$params_array}) {
        my $treatment = $param->{'treatment'};
        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $stprid  = $param->{'st_pr_id'};
        my $pr_name = $param->{'legend'};
        my $prid    = $param->{'param_id'};
        my $table;

        # check if stprid greater than 0
        # if true then it's a normal station-parameter
        # otherwise it is a parameter linked to an allocated MM
        if( $stprid > 0){
            $table = 'metadata.stations_parameters';
        }
        else{
            $table = 'metadata.f_get_view_sites_parameters('.$stprid.'::bigint)';
        }

        $formule =~ s/y=//;
        # $formule =~ s/x/tbl.measure_value/;
        my $mean = $formule;
        my $min  = $formule;
        my $max  = $formule;
        # $mean =~ s/x/tbl.measure_value/g;
        # $min  =~ s/x/tbl.measure_min/g;
        # $max  =~ s/x/tbl.measure_max/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $min  =~ s/x/( tbl.measure_min * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $max  =~ s/x/( tbl.measure_max * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
            $min  =~ s/x/tbl.measure_min/g;
            $max  =~ s/x/tbl.measure_max/g;
        }

        if ($treatment eq 'cum') {
            $mean = qq{SUM( $mean ) OVER (ORDER BY tbl.measure_date_time)};
            $min  = qq{SUM( $min  ) OVER (ORDER BY tbl.measure_date_time)};
            $max  = qq{SUM( $max  ) OVER (ORDER BY tbl.measure_date_time)};
            $treatment = 'sum';
        }

        $sql .= qq{
            -- RECUPERO DATI PARAMETRO: $pr_name
            WITH d AS (
                SELECT
                    ARRAY[
                        EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                        CASE
                            WHEN tbl.measure_perc >= $percent THEN ROUND( $mean , $decimals )
                            ELSE NULL
                        END
                    ] AS measure_value,
                    ARRAY[
                        EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                        CASE
                            WHEN tbl.measure_perc >= $percent THEN ROUND( $min , $decimals )
                            ELSE NULL
                        END
                    ] AS measure_min,
                    ARRAY[
                        EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                        CASE
                            WHEN tbl.measure_perc >= $percent THEN ROUND( $max , $decimals )
                            ELSE NULL
                        END
                    ] AS measure_max
                FROM clients.f_data_extraction( ($stprid)::bigint , '$from'::timestamp, '$to'::timestamp, '$aggregation'::metadata.e_aggregations, '$treatment'::metadata.e_treatments, '$validity_code'::text) tbl
        };

        if ($hide_nulls eq 'true') {
            $sql.= qq{            WHERE tbl.measure_value IS NOT NULL};
        }

        $sql .=qq { ORDER BY tbl.measure_date_time
            ),
            a AS (
                SELECT
                    ($stprid)::bigint AS stpr_id,
                    ARRAY(SELECT measure_value FROM d) AS station_param_values,
                    ARRAY(SELECT measure_min FROM d)   AS station_min_values,
                    ARRAY(SELECT measure_max FROM d)   AS station_max_values
            )
            SELECT
                sp.stpr_id AS station_param_id,
                sp.station_id,
                sp.param_id,
                sp.stpr_table_id,
                s.station_name,
                s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
                p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
                p.param_unit        AS parameter_unit,
                p.param_conv        AS parameter_conv,
                p.param_unit_conv   AS parameter_unit_conv,
                p.param_decimals    AS parameter_decimals,
                CASE
                    WHEN TRUE = ALL (select unnest(a.station_param_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                    ELSE a.station_param_values
                END AS station_param_values,
                CASE
                    WHEN TRUE = ALL (select unnest(a.station_min_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                    ELSE a.station_min_values
                END AS station_min_values,
                CASE
                    WHEN TRUE = ALL (select unnest(a.station_max_values) is null) THEN ARRAY[ ARRAY[ NULL, NULL ] ]::numeric[]
                    ELSE a.station_max_values
                END AS station_max_values
            FROM
                a
                LEFT JOIN $table sp USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.stations s USING (station_id);
        };
    }

    # return
    return $sql;
}

sub get_windrose_data_bydates {
    my ( $self, $station_id, $from, $to, $validity, $scale ) = @_;

    # log
    $self->app->log->debug("sub get_windrose_data_bydates - stid: $station_id");

    my $sql_id1 = qq{
        SELECT stpr_id AS stprid
        FROM metadata.stations_parameters
        WHERE station_id = ?
        AND param_id = (
            SELECT param_id
            FROM metadata.parameters_info
            WHERE (pm_info_obj->'general'->>'windroseV')::boolean IS TRUE
        );
    };

    my $sql_id2 = qq{
        SELECT stpr_id AS stprid
        FROM metadata.stations_parameters
        WHERE station_id = ?
        AND param_id = (
            SELECT param_id
            FROM metadata.parameters_info
            WHERE (pm_info_obj->'general'->>'windroseD')::boolean IS TRUE
        );
    };

    my $stprid1 = $self->pg->db->query($sql_id1, $station_id)->hash->{'stprid'}; # velocità vento
    if ( ! $stprid1 ) { return undef; }
    my $stprid2 =  $self->pg->db->query($sql_id2, $station_id)->hash->{'stprid'}; # direzione vento
    if ( ! $stprid2 ) { return undef; }

    my $validity_code = $validity;

    if (!defined $validity_code || $validity_code eq '') {
        $validity_code = '< 2147483647';
    }

    my $sql = qq{
        WITH tmp_first AS (
            SELECT measure_date_time as fulldate,
                round(cast( t1.measure_value  as numeric), 1) as wind_vel,
                CASE
                    WHEN t1.measure_value NOTNULL AND t2.measure_value IS NULL THEN 0.0::numeric
                    ELSE round(cast( t2.measure_value  as numeric), 1)
                END AS wind_dir
            FROM clients.f_data_extraction( ($stprid1)::bigint, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '$validity_code'::text) t1
            LEFT JOIN clients.f_data_extraction( ($stprid2)::bigint, ?::timestamp, ?::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '$validity_code'::text) t2 USING (measure_date_time)
            ORDER BY measure_date_time
        )
    };

    my @sectors = (
        {from => 337.5, to => 22.5  },
        {from => 22.5 , to => 67.5  },
        {from => 67.5 , to => 112.5 },
        {from => 112.5, to => 157.5 },
        {from => 157.5, to => 202.5 },
        {from => 202.5, to => 247.5 },
        {from => 247.5, to => 292.5 },
        {from => 292.5, to => 337.5 }
    );

    my $flag = 1;
    my $cond;
    foreach my $sector (@sectors){

        if ($flag) {
            $sql .= qq{SELECT};
            $cond = qq{OR}; # per wind_dir prima select con OR perché a cavallo di 0 gradi
            $flag = 0;
        }
        else {
            $sql .= qq{UNION ALL
            SELECT };
            $cond = qq{AND}; # per wind_dir
        }

        my $dir_from = $sector->{'from'};
        my $dir_to = $sector->{'to'};

        my $cnt = 0;
        foreach my $class (@{$scale}) {
            my $name = 'class'.$cnt;
            my $vel_from = $class->{'from'};
            my $vel_to = $class->{'to'};

            if ($cnt == 0) {
                $sql .= qq{
                    COUNT(CASE WHEN wind_vel >= $vel_from and wind_vel <= $vel_to
                    AND (wind_dir >= $dir_from $cond wind_dir < $dir_to) THEN 1 END) AS $name ,};
                }
            else {
                $sql .= qq{
                    COUNT(CASE WHEN wind_vel > $vel_from and wind_vel <= $vel_to
                    AND (wind_dir >= $dir_from $cond wind_dir < $dir_to) THEN 1 END) AS $name ,};
            }

            $cnt++;
        }

        $sql .= qq{
            COUNT(CASE WHEN (wind_dir >= $dir_from $cond wind_dir < $dir_to) AND wind_vel >= 0 THEN 1 END) AS totale
            FROM tmp_first
        };
    }

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $from, $to, $from, $to)->hashes();
}

sub get_windrose_query {
    my ( $self, $station_id, $from, $to, $validity, $scale ) = @_;

    # log
    $self->app->log->debug("sub get_windrose_query");

    my $sql_id1 = qq{
        SELECT stpr_id AS stprid
        FROM metadata.stations_parameters
        WHERE station_id = ?
        AND param_id = (
            SELECT param_id
            FROM metadata.parameters_info
            WHERE (pm_info_obj->'general'->>'windroseV')::boolean IS TRUE
        );
    };

    my $sql_id2 = qq{
        SELECT stpr_id AS stprid
        FROM metadata.stations_parameters
        WHERE station_id = ?
        AND param_id = (
            SELECT param_id
            FROM metadata.parameters_info
            WHERE (pm_info_obj->'general'->>'windroseD')::boolean IS TRUE
        );
    };

    my $stprid1 = $self->pg->db->query($sql_id1, $station_id)->hash->{'stprid'}; # velocità vento
    if ( ! $stprid1 ) { return undef; }
    my $stprid2 =  $self->pg->db->query($sql_id2, $station_id)->hash->{'stprid'}; # direzione vento
    if ( ! $stprid2 ) { return undef; }

    my $validity_code = $validity;

    if (!defined $validity_code || $validity_code eq '') {
        $validity_code = '< 2147483647';
    }

    my $sql = qq{
        WITH tmp_first AS (
            SELECT measure_date_time as fulldate,
                round(cast( t1.measure_value  as numeric), 1) as wind_vel,
                CASE
                    WHEN t1.measure_value NOTNULL AND t2.measure_value IS NULL THEN 0.0::numeric
                    ELSE round(cast( t2.measure_value  as numeric), 1)
                END AS wind_dir
            FROM clients.f_data_extraction( ($stprid1)::bigint, '$from'::timestamp, '$to'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '$validity_code'::text) t1
            LEFT JOIN clients.f_data_extraction( ($stprid2)::bigint, '$from'::timestamp, '$to'::timestamp, 'hh'::metadata.e_aggregations, 'avg'::metadata.e_treatments, '$validity_code'::text) t2 USING (measure_date_time)
            ORDER BY measure_date_time
        )
    };

    # sql
    my @sectors = (
        {from => 337.5, to => 22.5 },
        {from => 22.5 , to => 67.5 },
        {from => 67.5 , to => 112.5 },
        {from => 112.5, to => 157.5 },
        {from => 157.5, to => 202.5 },
        {from => 202.5, to => 247.5 },
        {from => 247.5, to => 292.5 },
        {from => 292.5, to => 337.5 }
    );

    my $flag = 1;
    my $cond;

    foreach my $sector (@sectors) {
        if ($flag) {
            $sql .= qq{SELECT};
            $cond = qq{OR}; # per wind_dir prima select con OR perché a cavallo di 0 gradi
            $flag = 0;
        }
        else {
            $sql .= qq{UNION ALL
            SELECT };
            $cond = qq{AND};
        }

        my $dir_from = $sector->{'from'};
        my $dir_to = $sector->{'to'};

        my $cnt = 0;
        foreach my $class (@{$scale}) {
            my $name = 'class'.$cnt;
            my $vel_from = $class->{'from'};
            my $vel_to = $class->{'to'};

            if ($cnt == 0) {
                $sql .= qq{
                    COUNT(CASE WHEN wind_vel >= $vel_from and wind_vel <= $vel_to
                    AND (wind_dir >= $dir_from $cond wind_dir < $dir_to) THEN 1 END) AS $name ,};
            }
            else {
                $sql .= qq{
                    COUNT(CASE WHEN wind_vel > $vel_from and wind_vel <= $vel_to
                    AND (wind_dir >= $dir_from $cond wind_dir < $dir_to) THEN 1 END) AS $name ,};
            }

            $cnt++;
        }

        $sql .= qq{
            COUNT(CASE WHEN (wind_dir  >= $dir_from $cond wind_dir < $dir_to) AND wind_vel >= 0 THEN 1 END) AS totale
            FROM tmp_first
        };
    }

    # $self->app->log->debug($sql);

    # return
    return $sql;
}

sub get_datatable_data_by_dates {
    # my ( $self, $from, $to, $hide_nulls, $macro, $page, $size ) = @_;
    my ( $self, $from, $to, $hide_nulls, $macro) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_datatable_data_by_dates");

    my $aggregation  = $macro->{macro}{aggregation};
    my $percent_data = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    my $min_agg;
    my $sql = qq{
        SELECT DISTINCT ON(app_aggregation_cadence_id)
            app_aggregation_label
        FROM metadata.view_app_aggregations
        ORDER BY app_aggregation_cadence_id
        LIMIT 1;
    };

    # return
    $min_agg = $self->pg->db->query($sql)->hash->{'app_aggregation_label'};

    my $ext_fields   = 'fulldate::timestamp';
    my $ext_conditions = '';
    my $inner_fields = 'fulldate text';
    my $inner_query  = '';
    my $count = 0;

    for my $param (@{$macro->{params}}){
        my $stprid = $param->{'st_pr_id'};
        my $treatment = $param->{'treatment'};
        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $is_limit = $param->{'is_limit'};
        my $prid    = $param->{'param_id'};

        my $window = 8;

        my $validity = qq{''< 2147483647''::text};
        if (defined $validity_code) {
            $validity = qq{ ''$validity_code''::text};
        }

        $formule =~ s/y=//;
        my $mean = $formule;
        my $min  = $formule;
        my $max  = $formule;
        # $mean =~ s/x/tbl.measure_value/g;
        # $min  =~ s/x/tbl.measure_min/g;
        # $max  =~ s/x/tbl.measure_max/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $min  =~ s/x/( tbl.measure_min * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $max  =~ s/x/( tbl.measure_max * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
            $min  =~ s/x/tbl.measure_min/g;
            $max  =~ s/x/tbl.measure_max/g;
        }

        if ($treatment eq 'cum') {
            $mean = qq{SUM( $mean ) OVER (ORDER BY tbl.measure_date_time)};
            $min  = qq{SUM( $min  ) OVER (ORDER BY tbl.measure_date_time)};
            $max  = qq{SUM( $max  ) OVER (ORDER BY tbl.measure_date_time)};
            $treatment = 'sum';
        }

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        if ($aggregation eq $min_agg) { # recupero anche il codice di validazione
            $ext_fields .= ", field".$count."[1] AS field_".$count.", field".$count."[2] AS min_".$count.", field".$count."[3] AS max_".$count.", field".$count."[4] AS code_".$count.", field".$count."[5] AS perc_".$count;
            $inner_fields .= qq{, field$count text[]};

            $inner_query .= qq{
                SELECT
                    measure_date_time::text,
                    ''field$count''::text AS field_name,
                    ARRAY[
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $mean , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $min , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $max , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(post_validity_code::text, ''--'')
                            ELSE ''--''
                        END,
                        COALESCE(measure_perc||''%'', ''--'')
                    ] AS values
            };
        }
        else { # recupero solo i valori
            $ext_fields .= ", field".$count."[1] AS field_".$count.", field".$count."[2] AS min_".$count.", field".$count."[3] AS max_".$count.", field".$count."[4] AS perc_".$count;
            $inner_fields .= qq{, field$count text[]};

            $inner_query .= qq{
                SELECT
                    measure_date_time::text,
                    ''field$count''::text AS field_name,
                    ARRAY[
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $mean , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $min , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $max , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        COALESCE(measure_perc||''%'', ''--'')
                    ]
            };
        }

        if ($treatment eq 'sldavg') {
            if (defined $param->{'window'} && $param->{'window'} ne '') {
                $window = $param->{'window'};
            }

            $inner_query .= qq{
                FROM clients.f_sldavg_data_extraction( ($stprid)::bigint, ''$from''::timestamp, ''$to''::timestamp, ''$aggregation''::metadata.e_aggregations, $validity, $window ::integer) tbl
            };
        }
        else {
            $inner_query .= qq{
                FROM clients.f_data_extraction( ($stprid)::bigint, ''$from''::timestamp, ''$to''::timestamp, ''$aggregation''::metadata.e_aggregations, ''$treatment''::metadata.e_treatments, $validity) tbl
            };
        }

        if ($hide_nulls eq 'true' && $is_limit == 0) {
            if ($ext_conditions eq '') {
                $ext_conditions .= "WHERE field".$count."[1] NOT LIKE '--' ";
            }
            else {
                $ext_conditions .= "OR field".$count."[1] NOT LIKE '--' ";
            }
        }

        $count++;
    }

    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
                $inner_query
            ) t ORDER BY measure_date_time, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        $ext_conditions ;
    };
    # --LIMIT ? OFFSET ?;

    # $self->app->log->debug("$final_query");
    # return data
    # return $self->pg->db->query($final_query, $size, ($page-1)*$size)->hashes();
    return $self->pg->db->query($final_query)->hashes();
}

sub get_datatable_representative_data_by_dates {

    # my ( $self, $from, $to, $hide_nulls, $macro, $page, $size ) = @_;
    my ( $self, $from, $to, $macro) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_datatable_representative_data_by_dates");

    my $aggregation  = $macro->{macro}{aggregation};
    my $percent_data = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    my $ext_fields   = 'category::text';
    my $ext_conditions = '';
    my $inner_fields = 'category text';
    my $inner_query  = '';
    my $count = 0;

    my $extract;
    my $format;

    if ($aggregation =~ /rep\_day/) {
        $extract = 'hour';
        $format = 'HH24';
    }
    elsif ($aggregation =~ /rep\_week/) {
        $extract = 'isodow';
        $format = 'TMDay';
    }
    elsif ($aggregation =~ /rep\_year/) {
        $extract = 'month';
        $format = 'TMMonth';
    }

    for my $param (@{$macro->{params}}) {
        my $stprid = $param->{'st_pr_id'};
        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $is_limit = $param->{'is_limit'};
        my $prid    = $param->{'param_id'};

        my $window = 8;

        my $validity = qq{''< 2147483647''::text};
        if (defined $validity_code) {
            $validity = qq{ ''$validity_code''::text};
        }

        $formule =~ s/y=//;
        my $mean = $formule;
        # $mean =~ s/x/tbl.measure_value/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
        }

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

         # recupero solo i valori
        $ext_fields .= ", field".$count." AS field_".$count;
        $inner_fields .= qq{, field$count text};

        $inner_query .= qq{
            SELECT
                measure_group,
                measure_category,
                ''field$count''::text AS field_name,
                COALESCE(( ROUND( AVG( measure_value ), $decimals ) )::text, ''--'') AS values
            FROM (
                SELECT
                    EXTRACT(''$extract'' FROM tbl.measure_date_time) as measure_group,
                    TO_CHAR(tbl.measure_date_time, ''$format'') as measure_category,
                    $mean AS measure_value
                FROM clients.f_data_extraction( ($stprid)::bigint, ''$from''::timestamp, ''$to''::timestamp, ''hh''::metadata.e_aggregations, ''avg''::metadata.e_treatments, $validity) tbl
                ORDER BY tbl.measure_date_time
            )
            GROUP BY measure_group, measure_category
        };

        $count++;
    }

    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT measure_category, field_name, values
            FROM (
                $inner_query
            ) t ORDER BY measure_group, measure_category, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        $ext_conditions ;
    };
    # --LIMIT ? OFFSET ?;

    # $self->app->log->debug("$final_query");
    # return data
    # return $self->pg->db->query($final_query, $size, ($page-1)*$size)->hashes();
    return $self->pg->db->query($final_query)->hashes();
}

sub get_datatable_query {
    # my ( $self, $from, $to, $hide_nulls, $macro, $page, $size ) = @_;
    my ( $self, $from, $to, $hide_nulls, $macro) = @_;

    my $aggregation  = $macro->{macro}{aggregation};
    my $percent_data = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    my $ext_fields   = 'fulldate::timestamp';
    my $ext_conditions = '';
    my $inner_fields = 'fulldate text';
    my $inner_query  = '';
    my $count = 0;

    for my $param (@{$macro->{params}}) {
        my $stprid = $param->{'st_pr_id'};
        my $treatment = $param->{'treatment'};
        my $decimals = $param->{'decimals'};
        my $formule = $param->{'formule'};
        my $is_limit = $param->{'is_limit'};
        my $pr_name = $param->{'legend'};
        my $prid    = $param->{'param_id'};

        # my $validity = '';
        # if (defined $validity_code) {
        #     $validity = 'AND measure_code '.$validity_code;
        # }

        my $validity = qq{''< 2147483647''::text};
        if (defined $validity_code) {
            $validity = qq{ ''$validity_code''::text};
        }

        $formule =~ s/y=//;
        my $mean = $formule;
        my $min  = $formule;
        my $max  = $formule;
        # $mean =~ s/x/tbl.measure_value/g;
        # $min  =~ s/x/tbl.measure_min/g;
        # $max  =~ s/x/tbl.measure_max/g;

        if ($param->{'converted'}) {
            $mean =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $min  =~ s/x/( tbl.measure_min * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            $max  =~ s/x/( tbl.measure_max * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
        }
        else {
            $mean =~ s/x/tbl.measure_value/g;
            $min  =~ s/x/tbl.measure_min/g;
            $max  =~ s/x/tbl.measure_max/g;
        }

        if ($treatment eq 'cum') {
            $mean = qq{SUM( $mean ) OVER (ORDER BY tbl.measure_date_time)};
            $min  = qq{SUM( $min  ) OVER (ORDER BY tbl.measure_date_time)};
            $max  = qq{SUM( $max  ) OVER (ORDER BY tbl.measure_date_time)};
            $treatment = 'sum';
        }

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        if ($aggregation eq 'hh') { # recupero anche il codice di validazione
            $ext_fields .= ", field".$count."[1] AS field_".$count.", field".$count."[2] AS min_".$count.", field".$count."[3] AS max_".$count.", field".$count."[4] AS code_".$count.", field".$count."[5] AS perc_".$count;
            $inner_fields .= qq{, field$count text[]};
            $inner_query .= qq{
                SELECT
                    measure_date_time::text,
                    ''field$count''::text AS field_name,
                    ARRAY[
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $mean , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $min , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $max , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(post_validity_code::text, ''--'')
                            ELSE ''--''
                        END,
                        COALESCE(measure_perc||''%'', ''--'')
                    ] AS values
                FROM clients.f_data_extraction( ($stprid)::bigint, ''$from''::timestamp, ''$to''::timestamp, ''$aggregation''::metadata.e_aggregations, ''$treatment''::metadata.e_treatments, $validity) tbl
            };
        }
        else { # recupero solo i valori
            $ext_fields .= ", field".$count."[1] AS field_".$count.", field".$count."[2] AS min_".$count.", field".$count."[3] AS max_".$count.", field".$count."[4] AS perc_".$count;
            $inner_fields .= qq{, field$count text[]};

            $inner_query .= qq{
                SELECT
                    measure_date_time::text,
                    ''field$count''::text AS field_name,
                    ARRAY[
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $formule , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $min , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE(( ROUND( $max , $decimals ) )::text, ''--'')
                            ELSE ''--''
                        END,
                        COALESCE(measure_perc||''%'', ''--'')
                    ]
                FROM clients.f_data_extraction( ($stprid)::bigint, ''$from''::timestamp, ''$to''::timestamp, ''$aggregation''::metadata.e_aggregations, ''$treatment''::metadata.e_treatments, $validity) tbl
            };
        }

        if ($hide_nulls eq 'true' && $is_limit == 0) {
            if ($ext_conditions eq '') {
                $ext_conditions .= "WHERE field".$count."[1] NOT LIKE '--' ";
            }
            else {
                $ext_conditions .= "OR field".$count."[1] NOT LIKE '--' ";
            }
        }

        $count++;
    }

    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
                $inner_query
            ) t ORDER BY measure_date_time, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        $ext_conditions;
    };

    # return data
    return $final_query;
}

sub get_csv_header {
    my ( $self, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_csv_header");

    my $sql;
    my $params_array = $macro->{'params'};

    #  !! LOOP THROUGH ID AND PUSH RESULT IN ARRAY
    my @data;

    for my $param ( @{$params_array} ){
        my $table;

        # check if stprid greater than 0
        # if true then it's a normal station-parameter
        # otherwise it is a parameter linked to an allocated MM
        if( $param->{'st_pr_id'} > 0){
            $table = 'metadata.stations_parameters';
        }
        else{
            $table = 'metadata.f_get_view_sites_parameters('. $param->{'st_pr_id'} .'::bigint)';
        }

        my $sql = qq {
            SELECT
                sp.stpr_id AS station_param_id,
                sp.station_id,
                sp.param_id,
                sp.stpr_table_id,
                s.station_name,
                s.station_schema||'.'||COALESCE(s.station_prefix, '')|| s.station_table AS station_fulltable,
                p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS parameter_name,
                p.param_unit        AS parameter_unit,
                p.param_conv        AS parameter_conv,
                p.param_unit_conv   AS parameter_unit_conv,
                p.param_decimals    AS parameter_decimals,
                COALESCE( si.st_info_zone     , '--' ) AS station_zone     ,
                COALESCE( si.st_info_lat_wgs84::text, '--' ) AS station_lat_wgs84,
                COALESCE( si.st_info_lon_wgs84::text, '--' ) AS station_lon_wgs84,
                COALESCE( si.st_info_altitude ::text, '--' ) AS station_altitude
            FROM
                $table sp
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.stations s USING (station_id)
                LEFT JOIN metadata.stations_info si USING (station_id)
            WHERE
                sp.stpr_id = ?
        };

        my $res = $self->pg->db->query($sql, $param->{'st_pr_id'} )->hash();

        if (defined $res){
            push @data, $res;
        }
    }

    # return
    return \@data;
}

sub get_csv_data_by_dates {
    # my ( $self, $from, $to, $hide_nulls, $macro, $page, $size ) = @_;
    my ( $self, $from, $to, $hide_nulls, $macro ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_csv_data_by_dates");

    my $aggregation  = $macro->{macro}{aggregation};
    my $percent_data = $macro->{macro}{percent_data};
    my $validity_code = $macro->{macro}{validity_code};

    my $fields = '';
    my $joins = '';
    my $temp_table = '';
    my $count = 0;

    my $tx;
    my $data;

    eval {
        $tx =  $self->pg->db->begin;

        for my $param (@{$macro->{params}}) {
            my $stprid = $param->{'st_pr_id'};
            my $treatment = $param->{'treatment'};
            my $decimals = $param->{'decimals'};
            my $formule = $param->{'formule'};
            my $is_limit = $param->{'is_limit'};
            my $prid    = $param->{'param_id'};

            my $validity = qq{'< 2147483647'::text};
            if (defined $validity_code) {
                $validity = qq{ '$validity_code'::text};
            }

            $formule =~ s/y=//;
            # $formule =~ s/x/tbl.measure_value/g;

            if ($param->{'converted'}) {
                $formule =~ s/x/( tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) )::numeric/g;
            }
            else {
                $formule =~ s/x/tbl.measure_value/g;
            }

            if ($treatment eq 'cum') {
                $formule = qq{SUM( $formule ) OVER (ORDER BY tbl.measure_date_time)};
                $treatment = 'sum';
            }

            if ($count == 0) {
                $fields .= qq{
                    t0.measure_date_time,
                    t0.measure_value AS field_0};

                $joins = 't0';
            }
            else {
                $fields .= qq{,
                    t$count.measure_value AS field_$count};

                $joins .= qq{
                LEFT JOIN t$count USING (measure_date_time) };
            }

            $temp_table = qq{
                CREATE TEMP TABLE t$count ON COMMIT DROP AS (
                    SELECT
                        TO_CHAR(measure_date_time, 'YYYY-MM-DD HH24.MI.SS') AS measure_date_time,
                        CASE
                            WHEN measure_perc >= $percent_data THEN COALESCE( REPLACE (( ROUND( $formule , $decimals ) )::text, '.', ','), '')
                            ELSE ''
                        END AS measure_value
                    FROM
                        clients.f_data_extraction( ($stprid)::bigint, '$from'::timestamp, '$to'::timestamp, '$aggregation'::metadata.e_aggregations, '$treatment'::metadata.e_treatments, $validity) tbl
                    ORDER BY
                        tbl.measure_date_time
                );
            };

            $self->pg->db->query($temp_table);

            $count++;
        }

        # select
        # t1.measure_date_time,
        # t1.measure_value,
        # t2.measure_value
        # from t1 left join t2 using(measure_date_time)
        my $final_query = qq{
            SELECT
                $fields
            FROM
                $joins
            ORDER BY
                measure_date_time;
        };

        $data = $self->pg->db->query($final_query)->arrays;
    };

    # error check
    if ($@) {
        $self->app->helperDumper($@->{'message'});
        return undef;

    }
    else {
        $tx->commit;
        # return 1;
        return $data;
    }
}

# !! VALIDAZIONE
sub get_data_station_table {
    my ( $self, $aggregation, $date_from, $date_to, $converted, $hide_nulls, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_data_station_table");
    $self->app->log->debug("Date FROM $date_from");
    $self->app->log->debug("Date TO $date_to");

    my $ext_fields   = 'fulldate::timestamp';
    my $inner_fields = 'fulldate text';
    my $inner_query  = '';
    my $ext_conditions = '';
    my $count = 0;

    for my $param (@{$params}) {
        my $stprid = $param->{'station_param_id'};
        my $decimals = $param->{'parameter_decimals'};
        my $treatment = $param->{'parameter_treatment'};
        my $conv = $param->{'parameter_conv'};
        my $prid = $param->{'parameter_id'};

        my $formule = 'tbl.measure_value';

        if ( $converted ) {
            # UPDATE 19/06/2024 10:56
            # $formule = qq{ tbl.measure_value* $conv };
            $formule = qq{ tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) };
        }

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        $ext_fields .= ", field".$count."[1] AS field_".$count.", field".$count."[2] AS code_".$count.", field".$count."[3] AS class_".$count;
        $inner_fields .= qq{, field$count text[]};

        $inner_query .= qq{
            SELECT
                measure_date_time::text,
                ''field$count''::text AS field_name,
                ARRAY[
                    COALESCE(( ROUND( ( $formule )::numeric, $decimals ) )::text, ''--''),
                    post_validity_code::text,
                    CASE
                        WHEN final_validity_code > 0 THEN
                            CASE
                                WHEN post_validity_code > 0 THEN ''cell-valid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                                WHEN post_validity_code = -1 THEN ''cell-auto cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                                WHEN post_validity_code IN (-2, -3) THEN ''cell-auto-invalid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                                WHEN post_validity_code < -3 THEN ''cell-invalid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                                ELSE ''cell-default cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                            END
                        ELSE
                            CASE
                                WHEN post_validity_code > 0 THEN ''cell-valid''
                                WHEN post_validity_code = -1 THEN ''cell-auto''
                                WHEN post_validity_code IN (-2, -3) THEN ''cell-auto-invalid''
                                WHEN post_validity_code < -3 THEN ''cell-invalid''
                                ELSE ''cell-default''
                            END
                    END
                ]
            FROM clients.f_data_extraction( $stprid, ''$date_from''::timestamp, ''$date_to''::timestamp, ''$aggregation''::metadata.e_aggregations, ''$treatment''::metadata.e_treatments, ''< 2147483647''::text) tbl
        };

        if ($hide_nulls eq 'true') {
            if ($ext_conditions eq '') {
                $ext_conditions .= "WHERE field".$count."[1] NOT LIKE '--' ";
            }
            else {
                $ext_conditions .= "OR field".$count."[1] NOT LIKE '--' ";
            }
        }

        $count++;
    }

    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
                $inner_query
            ) t ORDER BY measure_date_time, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        $ext_conditions;
    };

    # # log
    # $self->app->log->debug($final_query);

    # return data
    return $self->pg->db->query($final_query)->hashes();
    # return 1;
}

sub get_station_alarms {
    my ( $self, $station_id, $date_from, $date_to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_station_alarms");

    # query
    my $sql = qq{
        SELECT sa_fulldate, array_agg(alarm_label) AS sa_labels
        FROM clients.stations_alarms sa
        LEFT JOIN clients.alarms a USING (param_id)
        WHERE station_id = ?
        AND sa_fulldate BETWEEN ?::timestamp AND ?::timestamp
        GROUP BY sa_fulldate
        ORDER BY sa_fulldate;
    };

    # return
    return $self->pg->db->query($sql, $station_id, $date_from, $date_to)->hashes();
}

sub get_val_codes_by_date_id {
    my ( $self, $user_id, $table, $date, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_val_codes_by_date_id");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                fvc_code_id,
                COALESCE(t2.label, t1.fvc_code_desc) AS fvc_code_desc
            FROM
                metadata.final_validation_codes t1
                LEFT JOIN jsonb_to_recordset(
                    bobo.f_get_user_portal_options( ?, '/dat_validaz_finale' )-> 'codes'
                ) AS t2(value integer, label text) ON (t1.fvc_code_id = t2.value)
            ORDER BY
                fvc_code_id
        )
        SELECT
            --ARRAY[]::text[] AS periphery_codes,
            ARRAY(
                SELECT ARRAY[
                    pvc_code_desc,
                    CASE
                        WHEN pvc_code_valid IS TRUE THEN 'mdi mdi-checkbox-marked-circle'
                        ELSE 'mdi mdi-checkbox-blank-circle'
                    END,
                    CASE
                        WHEN pvc_code_valid IS TRUE THEN 'text-success'
                        ELSE 'text-danger'
                    END
                ]
                FROM metadata.periphery_validation_codes
                WHERE pvc_code_id IN (
                    SELECT UNNEST( main.signed_bitmask_toarray( tbl.measure_code::integer, 30))
                )
                ORDER BY pvc_code_id
            ) AS periphery_codes,
            ARRAY(
                SELECT ARRAY[
                    avc_code_desc,
                    CASE
                        WHEN avc_code_id = 0 THEN 'mdi mdi-checkbox-marked-circle'
                        ELSE 'mdi mdi-checkbox-blank-circle'
                    END,
                    CASE
                        WHEN avc_code_id = 0 THEN 'text-success'
                        ELSE 'text-danger'
                    END
                ]
                FROM metadata.auto_validation_codes
                WHERE avc_code_id IN (
                    SELECT UNNEST( main.signed_bitmask_toarray( tbl.auto_validity_code::integer, 30))
                )
                ORDER BY avc_code_id
            ) AS auto_codes,
            ARRAY(
                SELECT ARRAY[
                        uvc_code_desc,
                        CASE
                            WHEN uvc_code_id > 0 THEN 'cell-valid'
                            WHEN uvc_code_id = -1 THEN 'cell-auto'
                            WHEN uvc_code_id = -2 THEN 'cell-auto-invalid'
                            WHEN uvc_code_id < -2 THEN 'cell-invalid'
                            ELSE 'cell-default'
                        END
                    ]
                FROM metadata.user_validation_codes
                WHERE uvc_code_id IN (
                    SELECT UNNEST( main.signed_bitmask_toarray( tbl.post_validity_code::integer, 30))
                )
                ORDER BY uvc_code_id
            ) AS user_codes,
            ARRAY(
                SELECT ARRAY[
                        fvc_code_desc,
                        CASE
                            WHEN fvc_code_id = 0 THEN 'mdi mdi-checkbox-blank-circle'
                            ELSE 'mdi mdi-checkbox-marked-circle'
                        END,
                        CASE
                            WHEN fvc_code_id = 0 THEN 'text-danger'
                            ELSE 'text-success'
                        END
                    ]
                FROM t
                WHERE fvc_code_id IN (
                    SELECT UNNEST( main.signed_bitmask_toarray( tbl.final_validity_code::integer, 30))
                )
                ORDER BY fvc_code_id
            ) AS final_codes
        FROM $table tbl
        WHERE measure_date_time = ?::timestamp
        AND measure_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $date, $id)->hash;
}

sub get_history_by_date_id {
    my ( $self, $table, $date, $id, $stprid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_history_by_date_id");

    # query
    my $sql = qq{
        SELECT
            (item_object->>'d')::timestamp  AS update_fulldate,
            TO_CHAR((item_object->>'d')::timestamp at time zone 'UTC' at time zone 'Europe/Rome', 'DD/MM/YYYY HH24:MI:SS')
                                            AS update_fulldate_formatted,
            (item_object->>'u')::integer    AS update_user,
            CONCAT_WS(
                ' ',
                u.us_name,
                u.us_2nd_name,
                u.us_surname
            )                               AS user_fullname,
            (item_object->>'a')::integer    AS update_note,
            (item_object->'old')::jsonb     AS update_old,
            (item_object->'new')::jsonb     AS update_new,

            metadata.f_get_conversion_by_date_stprid( ?, ? ) AS param_conv
        FROM $table tbl,
            jsonb_array_elements(measure_update_obj) WITH ordinality t(item_object, position)
        LEFT JOIN bobo.users u ON (u.us_id = (item_object->>'u')::integer )

        WHERE measure_date_time = ?::timestamp
        AND measure_id = ?
        ORDER BY (item_object->>'d')::timestamp DESC;
    };

    # return
    return $self->pg->db->query($sql, $stprid, $date, $date, $id)->hashes;
}

sub get_chart_data_neighborhood {
    my ( $self, $aggr, $stprid, $date, $converted ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_data_neighborhood");

    my $fullname;
    my $formule;
    my $formule_min;
    my $formule_max;

    if ($converted eq 'true') {
        $fullname = "parameter_name||' ['|| parameter_unit_conv ||']'";

        # UPDATE 19/06/2024 10:56
        # $formule = qq{tbl.measure_value*parameter_conv};
        # $formule_min = qq{tbl.measure_min*parameter_conv};
        # $formule_max = qq{tbl.measure_max*parameter_conv};
        $formule = qq{ tbl.measure_value * metadata.f_get_conversion_by_date_prid( param_id, tbl.measure_date_time ) };
        $formule_min = qq{tbl.measure_min* metadata.f_get_conversion_by_date_prid( param_id, tbl.measure_date_time ) };
        $formule_max = qq{tbl.measure_max* metadata.f_get_conversion_by_date_prid( param_id, tbl.measure_date_time ) };
    }
    else {
        $fullname = "parameter_name||' ['|| parameter_unit ||']'";
        $formule = qq{tbl.measure_value};
        $formule_min = qq{tbl.measure_min};
        $formule_max = qq{tbl.measure_max};
    }

    # select
    my $sql = qq{
        SELECT
            stpr_id         AS station_param_id,
            param_id        AS parameter_id,
            stpr_table_id   AS station_param_table_id,
            $fullname AS parameter_fullname,
            station_name,
            parameter_name,
            parameter_unit,
            parameter_conv,
            parameter_unit_conv,
            parameter_decimals,
            parameter_active,
            measure_cadence_min AS station_param_cadence_min,
            COALESCE(parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
            (
                SELECT row_to_json(row) FROM (
                    SELECT
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND(( $formule )::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS meanvalue,
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND(( $formule_min)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS minvalue,
                        ARRAY_AGG(ARRAY[ EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND(( $formule_max)::numeric, parameter_decimals)] ORDER BY  tbl.measure_date_time) AS maxvalue
                    FROM
                        clients.f_data_extraction(stpr_id, '$date'::timestamp - interval '1 day', '$date'::timestamp + interval '1 day', '$aggr'::metadata.e_aggregations, COALESCE(parameter_object->'general'->>'treatment', 'avg')::metadata.e_treatments, '< 2147483647'::text) tbl
                    GROUP BY tbl.measure_id
                ) row
            ) AS station_data
        FROM
            metadata.view_stations_parameters vsp
        LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = vsp.station_param_cadence_type_id
        WHERE stpr_id = ?;
    };

    # return
    # return $self->pg->db->query($sql, $date_from, $date_to, $station_id)->hashes();
    return $self->pg->db->query($sql, $stprid)->hash();
}

sub get_table_data_neighborhood {
    my ( $self, $aggr, $stprid, $date, $converted, $param ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_table_data_neighborhood");

    my $decimals = $param->{'parameter_decimals'};
    my $treatment = $param->{'parameter_treatment'};
    my $conv = $param->{'parameter_conv'};
    my $prid = $param->{'parameter_id'};

    my $formule;
    my $formule_min;
    my $formule_max;

    if ($converted eq 'true') {
        # UPDATE 19/06/2024 10:56
        # $formule = qq{tbl.measure_value* $conv};
        # $formule_min = qq{tbl.measure_min* $conv};
        # $formule_max = qq{tbl.measure_max* $conv};
        $formule = qq{tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) };
        $formule_min = qq{tbl.measure_min* metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) };
        $formule_max = qq{tbl.measure_max* metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) };
    }
    else {
        $formule = qq{tbl.measure_value};
        $formule_min = qq{tbl.measure_min};
        $formule_max = qq{tbl.measure_max};
    }

    my $ext_fields   = "fulldate::timestamp";
    my $inner_fields = "fulldate text";
    my $inner_query  = "";

    $ext_fields .= ", field0[1] AS min, field0[2] AS value, field0[3] AS max, field0[4] AS code, field0[5] AS class";
    $inner_fields .= qq{, field0 text[]};

    $inner_query .= qq{
        SELECT
            measure_date_time::text,
            ''field0''::text AS field_name,
            ARRAY[
                COALESCE(( ROUND( ( $formule_min )::numeric, $decimals ) )::text, ''--''),
                COALESCE(( ROUND( ( $formule )::numeric, $decimals ) )::text, ''--''),
                COALESCE(( ROUND( ( $formule_max )::numeric, $decimals ) )::text, ''--''),
                post_validity_code::text,
                CASE
                    WHEN final_validity_code > 0 THEN
                        CASE
                            WHEN post_validity_code > 0 THEN ''cell-valid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                            WHEN post_validity_code = -1 THEN ''cell-auto cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                            WHEN post_validity_code IN (-2, -3) THEN ''cell-auto-invalid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                            WHEN post_validity_code < -3 THEN ''cell-invalid cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                            ELSE ''cell-default cell-checked-''||main.bitmask_greater(final_validity_code, 8)
                        END
                    ELSE
                        CASE
                            WHEN post_validity_code > 0 THEN ''cell-valid''
                            WHEN post_validity_code = -1 THEN ''cell-auto''
                            WHEN post_validity_code IN (-2, -3) THEN ''cell-auto-invalid''
                            WHEN post_validity_code < -3 THEN ''cell-invalid''
                            ELSE ''cell-default''
                        END
                END
            ]
        FROM clients.f_data_extraction( $stprid, ''$date''::timestamp - interval ''1 day'', ''$date''::timestamp + interval ''1 day'', ''$aggr''::metadata.e_aggregations, ''min''::metadata.e_treatments, ''< 2147483647''::text) tbl
    };

    # query
    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            $inner_query
            ORDER BY measure_date_time,field_name
        ') AS horiz_table( $inner_fields );
    };

    # return
    # return $self->pg->db->query($sql, $date_from, $date_to, $station_id)->hashes();
    return $self->pg->db->query($final_query)->hashes();
}

sub update_data_validation_by_calendar {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub update_data_validation_by_calendar");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        my $record;

        $sql = qq{
            SELECT
                stpr_table_id AS id,
                station_fulltable AS table
            FROM
                metadata.view_stations_parameters vsp
            WHERE stpr_id = ?;
        };

        $record = $self->pg->db->query($sql, $params->{'stprid'})->hash();
        my $id = $record->{'id'};
        my $table = $record->{'table'};

        $sql = qq{ SELECT bobo.f_get_user_portal_options( ?, '/dat_validazione' ) AS options_obj };
        my $options = $self->pg->db->query($sql, $user_id)->hash->{'options_obj'};

        # inserimento nota se presente @TODO
        my $ann_id = undef;

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id   => $user_id,
            ann_id  => $ann_id,
            options => $options
        });

        my $filter = $params->{'filter'};
        if ($filter ne '') {
            $filter = 'AND measure_value '.$filter;
        }

        my $filter_code = $params->{'filter_code'};
        if ($filter_code ne '') {
            if ($filter_code =~ m/⊃/) {
                $self->app->log->debug('CONTIENE');
                $filter_code =~ s/⊃ //;
                $filter_code = 'AND '.$filter_code.' = ANY( main.signed_bitmask_toarray(post_validity_code, 10 ))';
            }
            else {
                $filter_code = 'AND post_validity_code '. $filter_code;
            }
        }

        $sql = qq{
            UPDATE $table
            SET post_validity_code = post_validity_code::integer ||| ( ? )::integer
            WHERE measure_date_time BETWEEN ? AND ?
            $filter
            $filter_code
            AND measure_id = ?;
        };

        # $self->app->log->debug($sql, $params->{'code'}, $params->{'from'}, $params->{'to'}, $id);
        $self->pg->db->query($sql, $params->{'code'}, $params->{'from'}, $params->{'to'}, $id);

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };
        $self->pg->db->query($sql);
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

sub update_data_value_by_calendar {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub update_data_value_by_calendar");

    my $tx;
    my $sql;

    # OPERAZIONE MATEMATICA CON FILTRO
    # {
    #   "action" => "false",
    #   "code" => "",
    #   "filter" => ">9.54",
    #   "from" => "2021-08-26 00:00",
    #   "operation" => "+6.7",
    #   "stprid" => 2,
    #   "to" => "2021-08-27 14:00"
    # }

    # OPERAZIONE SOSTITUISCI SENZA FILTRO
    # {
    #   "action" => "false",
    #   "code" => "",
    #   "filter" => "",
    #   "from" => "2021-08-26 00:00",
    #   "operation" => "=57.953",
    #   "stprid" => 2,
    #   "to" => "2021-08-27 14:00"
    # }

    eval {
        $tx =  $self->pg->db->begin;

        my $record;

        $sql = qq{
            SELECT
                stpr_table_id AS id,
                station_fulltable AS table
            FROM
                metadata.view_stations_parameters vsp
            WHERE stpr_id = ?;
        };

        $record = $self->pg->db->query($sql, $params->{'stprid'})->hash();
        my $id = $record->{'id'};
        my $table = $record->{'table'};

        $sql = qq{ SELECT bobo.f_get_user_portal_options( ?, '/dat_validazione' ) AS options_obj };
        my $options = $self->pg->db->query($sql, $user_id)->hash->{'options_obj'};

        # inserimento nota se presente @TODO
        my $ann_id = undef;

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id   => $user_id,
            ann_id  => $ann_id,
            options => $options
        });

        my $filter = $params->{'filter'};
        if ($filter ne '') {
            $filter = 'AND measure_value '.$filter;
        }

        my $filter_code = $params->{'filter_code'};
        if ($filter_code ne '') {
            if ($filter_code =~ m/⊃/) {

                $self->app->log->debug('CONTIENE');
                $filter_code =~ s/⊃ //;
                $filter_code = 'AND '.$filter_code.' = ANY( main.signed_bitmask_toarray(post_validity_code, 10 ))';
            }
            else {
                $filter_code = 'AND post_validity_code '. $filter_code;
            }
        }

        my $operation = $params->{'operation'};
        if ($operation =~ m/=/) {
            $self->app->log->debug('SOSTITUZIONE');

            $operation =~ s/=//;
        }
        else {
            $operation = 'measure_value '. $operation
        }

        $sql = qq{
            UPDATE $table
            SET measure_value = $operation,
            post_validity_code = post_validity_code::integer ||| ( 1 )::integer
            WHERE measure_date_time BETWEEN ? AND ?
            $filter
            $filter_code
            AND measure_id = ?;
        };

        # $self->app->log->debug($sql, $params->{'from'}, $params->{'to'}, $id);
        $self->pg->db->query($sql, $params->{'from'}, $params->{'to'}, $id);

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };
        $self->pg->db->query($sql);
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

sub update_data {
    my ( $self, $user_id, $converted, $cells ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub update_data");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        # inserimento nota se presente @TODO
        my $ann_id = undef;

        $sql = qq{ SELECT bobo.f_get_user_portal_options( ?, '/dat_validazione' ) AS options_obj };
        my $options = $self->pg->db->query($sql, $user_id)->hash->{'options_obj'};

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id   => $user_id,
            ann_id  => $ann_id,
            options => $options
        });

        for my $cell (@{$cells}){
            my $grant  = $cell->{'grant'};

            if ($grant == 1 && $cell->{'value' } ne '--') { #insert/update solo se ho il permesso e il valore non è nullo
                my $table  = $cell->{'table'};
                my $date   = $cell->{'date'  };
                my $stprid = $cell->{'stprid'};
                my $id     = $cell->{'tableid'};
                my $value  = $cell->{'value' };
                my $code   = $cell->{'code'  };

                my $dirty  = $cell->{'dirty'};
                # my $conv   = $cell->{'conv'};

                # dirty a TRUE solo se modificato il valore della cella
                if ($dirty == 1) {
                    # $code =~ s/post_validity_code/EXCLUDED.post_validity_code/;
                    my $decimals = $cell->{'decimals'};

                    if ($converted) {
                        $value = qq{ROUND( ($value / metadata.f_get_conversion_by_date_stprid( $stprid, ('$date')::timestamp ) )::numeric, $decimals )};
                    }


                    $sql = qq{
                        INSERT INTO $table AS t
                            (measure_date_time, measure_id, measure_value, post_validity_code)
                        VALUES
                            (?, ?, $value, 1)
                        ON CONFLICT (measure_date_time, measure_id)
                        DO UPDATE SET
                            measure_value = EXCLUDED.measure_value,
                            post_validity_code = ( t.post_validity_code ||| 1::integer );
                    };
                }
                else {

                    # if (defined $code && $code ne '') {
                    $code= qq{(post_validity_code::integer ||| ($code)::integer)};
                    # }
                    # else {
                    #     $code= qq{post_validity_code};
                    # }

                    $sql = qq{
                        UPDATE $table
                        SET post_validity_code = $code
                        WHERE measure_date_time = ?
                        AND measure_id = ?;
                    };
                }

                $self->app->log->debug("$sql");
                $self->pg->db->query($sql, $date, $id);
            }
        }

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };
        $self->pg->db->query($sql);

    }; # end eval

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

sub update_check_data {
    my ( $self, $user_id, $from, $to, $cells ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub update_check_data");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        $sql = qq{ SELECT bobo.f_get_user_portal_options( ?, '/dat_validazione' ) AS options_obj };
        my $options = $self->pg->db->query($sql, $user_id)->hash->{'options_obj'};

        # inserimento nota se presente @TODO
        my $ann_id = undef;

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id   => $user_id,
            ann_id  => $ann_id,
            options => $options
        });

        for my $cell (@{$cells}) {
            # STEP 1: CONTROLLO GRANTS
            my $grant = $cell->{'grant'};

            if ($grant == 1) { #update solo se ho il permesso
                $self->app->log->debug("update_check_data");

                # STEP 2: UPDATE CODICE VALIDITà FINALE
                my $table= $cell->{'table'};

                my $stprid = $cell->{'stprid'};
                my $id = $cell->{'tableid'};
                my $code = $cell->{'final_code'};

                # final_validity_code must be equal to 0 OR to 1
                # otherwise don't update it
                $sql = qq{
                    UPDATE $table
                    SET final_validity_code = final_validity_code | ?::smallint
                    WHERE measure_date_time BETWEEN ?::timestamp AND ?::timestamp
                    AND final_validity_code IN (0,1)
                    AND measure_id = ?;
                };

                # $self->app->log->debug("$sql");
                # $self->app->log->debug("{ $code, $from, $to, $id }");
                $self->pg->db->query($sql, $code, $from, $to, $id);

                # STEP 3: ELIMINA RISULTATI VALIDAZIONE AUTOMATICA
                $sql = qq{
                    DELETE FROM clients.auto_validation_results
                    WHERE measure_date_time BETWEEN ?::timestamp AND ?::timestamp
                    AND stpr_id = ?;
                };

                # $self->app->log->debug("$sql");
                # $self->app->log->debug("{ $from, $to, $stprid }");
                $self->pg->db->query($sql, $from, $to, $stprid);
            }
        }

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };
        $self->pg->db->query($sql);
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

sub reset_cells_code {
    my ( $self, $user_id, $cells ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub reset_cells_code");

    my $tx;
    my $sql;

    eval {
        $tx =  $self->pg->db->begin;

        $sql = qq{ SELECT bobo.f_get_user_portal_options( ?, '/dat_validazione' ) AS options_obj };
        my $options = $self->pg->db->query($sql, $user_id)->hash->{'options_obj'};

        # inserimento metadata da recuperare nel trigger f_save_history che scatta before update
        # !attenzione! riga visibile solo dai trigger che scattano durante questa transazione
        # INSERT INTO clients.trigger_history (us_id, ann_id) VALUES (4, NULL);
        $self->pg->db->insert('clients.trigger_history' , {
            us_id   => $user_id,
            options => $options
        });

        for my $cell (@{$cells}) {
            my $grant = $cell->{'grant'};

            if ($grant == 1) { # update solo se ho il permesso
                $self->app->log->debug("reset_cells_code");

                my $table = $cell->{'table'};

                my $date = $cell->{'date'};
                my $id = $cell->{'tableid'};

                $sql = qq{
                    UPDATE $table
                    SET post_validity_code = 0
                    WHERE measure_date_time = ?
                    AND measure_id = ?;
                };

                # $self->app->log->debug("$sql");
                # $self->app->log->debug("{ $date, $id }");
                $self->pg->db->query($sql, $date, $id);
            }
        }

        # elimino metadata salvati precedentemente
        # !attenzione! elimina unicamente la riga inserita in questa transazione
        $sql = qq{
            DELETE FROM clients.trigger_history;
        };

        $self->pg->db->query($sql);
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

# !! DATAVIEW
sub get_dataview_indicators_color {
    my ( $self, $param_id, $stat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_dataview_params_indicator");

    # query
    my $sql = qq{
        WITH range AS (
            SELECT
                jsonb_array_elements(range_limits) AS rows
            FROM metadata.parameters p
            LEFT JOIN infoaria.params_pollutant pp USING (param_id)
            LEFT JOIN bobo_tools.dataview_indicators_range dir USING (pollutant_id)
            WHERE p.param_id = ?::integer
            AND dir.stat_id = ?::integer
        )
        SELECT
            TRIM(COALESCE(rows->>'desc', dil.legend_desc)) AS legend_desc,
            dil.legend_color,
            rows->>'lower' AS legend_lower,
            rows->>'upper' AS legend_upper
        FROM range r
        LEFT JOIN bobo_tools.dataview_indicators_legend dil ON (dil.legend_id = (r.rows->>'legend_id')::integer)
        ORDER BY (
            CASE
                WHEN (rows->>'order')::integer NOTNULL THEN (rows->>'order')::integer
                ELSE dil.legend_order
            END
        ) ASC;
    };

    # return
    return $self->pg->db->query($sql, $param_id, $stat_id)->hashes();
}

sub get_dataview_map_all_last_station_data {
    my ( $self, $user_id, $param_id, $param_aggr ) = @_;

    # sanify
    $param_aggr ||= '';

    # log
    $self->app->log->debug("Bobo::Model::DbdatamanagerCF sub get_dataview_map_all_last_station_data");
    $self->app->log->debug("Parameter ID: $param_id");
    # $self->app->log->debug("Parameter AGGR: $param_aggr");

    # select the column to be used to collect data
    # from table clients.dataview_lastdata
    # if marker_value, gets last data, while marker_sum gets rain sum

    # select, take care og variable $data_field
    my $sql = qq{
        WITH p AS (
            SELECT
                DISTINCT      station_id,
                sp.param_id::integer   AS param_id,
                p.param_unit_conv      AS parameter_unit_conv,
                p.param_conv           AS parameter_conv,
                COALESCE(pp.pp_decimals, p.param_decimals)         AS parameter_decimals,
                COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg')::metadata.e_treatments AS param_treatment,
                sp.stpr_group_id
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
            WHERE
                param_id = ?::integer
                AND stpr_active IS TRUE
        ),
        t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'::text                 AS marker_type,
            FALSE                           AS marker_flag_popup,
            sm.station_network_type_desc    AS marker_layer,
            sm.station_network_type_logo    AS marker_logo,
            p.station_id                    AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            p.parameter_unit_conv           AS marker_unit,
            COALESCE(
                (
                    SELECT
                        -- ROUND(marker_value::numeric, p.parameter_decimals)::real
                        CASE
                            WHEN marker_value > 0 AND marker_value < 1 THEN ROUND(marker_value::numeric, FLOOR(LOG10(marker_value))::integer * -1)::real
                            ELSE ROUND(marker_value::numeric, p.parameter_decimals)::real
                        END
                    FROM clients.dataview_lastdata dl
                    WHERE dl.station_id = p.station_id AND dl.param_id = p.param_id
                )::text, 'n.d.'
            )
            AS marker_value,
            CASE TRUE
                WHEN p.param_id = 10 THEN
                    COALESCE(
                    (
                        SELECT marker_value FROM clients.dataview_lastdata dl
                        WHERE dl.station_id = p.station_id AND dl.param_id = 11
                    )::text, 'n.d.')
                ELSE NULL
            END AS marker_dir,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||p.station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc,
            metadata.f_get_icon_by_station_id( t.station_id ) AS marker_icon
        FROM
            p
            LEFT JOIN t ON (p.station_id = t.main_station_id)
            LEFT JOIN metadata.view_stations_info sm ON (sm.station_id = t.station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status ss
                    WHERE
                        ss.ss_dataview_publish      IS TRUE
                        AND ss.ss_suspended         IS FALSE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
            )
            AND sm.station_active           IS TRUE
            AND sm.station_lat_wgs84    IS NOT NULL
            AND sm.station_lon_wgs84    IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = p.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
        ORDER BY
            sm.station_name;
    };

    # log
    # $self->app->log->debug("Query\n".$sql);
    $self->app->log->debug("Parameters: $param_id, $user_id");

    # return
    return $self->pg->db->query($sql, $param_id, $user_id)->hashes();
}

sub get_dataview_map_last_station_data {
    my ( $self, $param_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_dataview_map_last_station_data");
    $self->app->log->debug("Parameter ID: $param_id");

    # select
    my $sql = qq{
        WITH p AS (
            SELECT
                DISTINCT      station_id,
                sp.param_id::integer   AS param_id,
                p.param_unit_conv      AS parameter_unit_conv,
                p.param_conv           AS parameter_conv,
                COALESCE(pp.pp_decimals, p.param_decimals)         AS parameter_decimals,
                COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg')::metadata.e_treatments AS param_treatment,
                stpr_group_id
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
            WHERE
                param_id = ?::integer
                AND stpr_active IS TRUE
        ),
        t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'::text                 AS marker_type,
            FALSE                           AS marker_flag_popup,
            sm.station_network_type_desc    AS marker_layer,
            sm.station_network_type_logo    AS marker_logo,
            p.station_id                    AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            p.parameter_unit_conv           AS marker_unit,
            COALESCE(
                (
                    SELECT
                        -- ROUND(marker_value::numeric, parameter_decimals)::real
                        CASE
                            WHEN marker_value > 0 AND marker_value < 1 THEN ROUND(marker_value::numeric, FLOOR(LOG10(marker_value))::integer * -1)::real
                            ELSE ROUND(marker_value::numeric, p.parameter_decimals)::real
                        END
                    FROM clients.dataview_lastdata dl
                    WHERE dl.station_id = p.station_id
                    AND dl.param_id = p.param_id
                )::text, 'n.d.') AS marker_value,
            CASE TRUE
                WHEN p.param_id = 10 THEN
                    COALESCE((select marker_value FROM clients.dataview_lastdata dl WHERE dl.station_id = p.station_id AND dl.param_id = 11)::text, 'n.d.')
                ELSE NULL
            END AS marker_dir,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||p.station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc,
            metadata.f_get_icon_by_station_id( t.station_id ) AS marker_icon
        FROM
            p
            LEFT JOIN t ON (p.station_id = t.main_station_id)
            LEFT JOIN metadata.view_stations_info sm ON (sm.station_id = t.station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status
                    WHERE
                        ss_dataview_publish      IS TRUE
                        AND ss_suspended         IS FALSE
            )
            AND sm.station_active           IS TRUE
            AND sm.station_lat_wgs84    IS NOT NULL
            AND sm.station_lon_wgs84    IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = p.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
        ORDER BY
            sm.station_name;
    };

    # log
    # $self->app->log->debug("Query\n".$sql);
    $self->app->log->debug("Parameters: $param_id");

    # return
    return $self->pg->db->query($sql, $param_id)->hashes();
}

sub get_dataview_map_all_indicators {
    my ( $self, $user_id, $param_id, $stat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_dataview_map_all_indicators");
    $self->app->log->debug("Parameter ID: $param_id");

    # select
    my $sql = qq{
        WITH p AS (
            SELECT DISTINCT station_id,
                sp.stpr_id,
                sp.stpr_group_id,
                p.param_id,
                pp.pollutant_id,
                COALESCE(pp.pp_decimals, p.param_decimals) AS parameter_decimals,
                p.param_unit_conv
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
            WHERE
                param_id = ?::integer
                AND stpr_active IS TRUE
        ),
        t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'::text                 AS marker_type,
            FALSE                           AS marker_flag_popup,
            sm.station_network_type_desc    AS marker_layer,
            sm.station_network_type_logo    AS marker_logo,
            p.station_id                    AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            p.param_unit_conv               AS marker_unit,
            pollutant_id,
            COALESCE(
            (
                SELECT ROUND(res_value::numeric, parameter_decimals)::real
                FROM
                    clients_stats.results dl
                    LEFT JOIN clients_stats.limits l USING (limit_id)
                WHERE
                    l.stat_id = ?
                    AND dl.stpr_id = p.stpr_id
                    AND res_date >= CURRENT_DATE - interval '3 days'
                ORDER BY res_date
                DESC LIMIT 1
            )::text, 'n.d.') AS marker_value,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||p.station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc
        FROM
            p
            LEFT JOIN t ON (p.station_id = t.main_station_id)
            LEFT JOIN metadata.view_stations_info sm ON (sm.station_id = t.station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status
                    WHERE
                        ss_dataview_publish      IS TRUE
                        AND ss_suspended         IS FALSE
                UNION
                    SELECT
                        station_id
                    FROM
                        bobo.view_user_stations vus
                    LEFT JOIN metadata.stations_status ss2 USING (station_id)
                    WHERE
                        user_id = ?
                        AND ss2.ss_suspended IS FALSE
            )
            AND sm.station_active       IS TRUE
            AND sm.station_lat_wgs84    IS NOT NULL
            AND sm.station_lon_wgs84    IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = p.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
        ORDER BY
            sm.station_name;
    };

    # log
    # $self->app->log->debug("Query\n".$sql);
    $self->app->log->debug("Parameters: $param_id, Stat: $stat_id");

    # return
    return $self->pg->db->query($sql, $param_id, $stat_id, $user_id)->hashes();
}

sub get_dataview_map_indicators {
    my ( $self, $param_id, $stat_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_dataview_map_indicators");
    $self->app->log->debug("Parameter ID: $param_id");

    # select
    my $sql = qq{
        WITH p AS (
            SELECT DISTINCT station_id,
                stpr_id,
                stpr_group_id,
                param_id,
                pollutant_id,
                COALESCE(pp.pp_decimals, p.param_decimals) AS parameter_decimals,
                param_unit_conv
            FROM
                metadata.stations_parameters
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
            WHERE
                param_id = ?::integer
                AND stpr_active IS TRUE
        ),
        t AS (
            SELECT
                s.station_id AS main_station_id,
                COALESCE(  ss.station_override_id, s.station_id ) AS station_id,
                CASE
                    WHEN ss.station_override_id NOTNULL THEN (
                        SELECT mu_id
                        FROM metadata.sites
                        WHERE site_id = ss.site_id
                    )
                    ELSE (
                        SELECT mu_id
                        FROM metadata.stations_municipality
                        WHERE station_id = s.station_id
                    )
                END     AS mu_id
            FROM
                metadata.stations s
                LEFT JOIN metadata.stations_sites ss ON (s.station_id = ss.station_id AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome'))
        )
        SELECT
            'station'::text                 AS marker_type,
            FALSE                           AS marker_flag_popup,
            sm.station_network_type_desc    AS marker_layer,
            sm.station_network_type_logo    AS marker_logo,
            p.station_id                    AS marker_id,
            sm.station_name                 AS marker_name,
            sm.station_lat_wgs84            AS marker_lat,
            sm.station_lon_wgs84            AS marker_lon,
            p.param_unit_conv               AS marker_unit,
            pollutant_id,
            COALESCE(
            (
                SELECT ROUND(res_value::numeric, parameter_decimals)::real
                FROM
                    clients_stats.results dl
                    LEFT JOIN clients_stats.limits l USING (limit_id)
                WHERE
                    l.stat_id = ?
                    AND dl.stpr_id = p.stpr_id
                    AND res_date >= CURRENT_DATE - interval '3 days'
                ORDER BY res_date
                DESC LIMIT 1
            )::text, 'n.d.') AS marker_value,
            '<div>
                <h4>'|| sm.station_name ||'</h4>
                <strong>Comune : </strong>'|| COALESCE(m.mu_name, '-') ||'<br>
                <strong>Località : </strong>'|| COALESCE(sm.station_locality, '-') ||'<br>
                <strong>Quota : </strong>'|| COALESCE(sm.station_altitude::text, '-') ||'<br>
                <strong>Rete : </strong>'|| sm.station_network_type_desc||'
                <p style="margin: 0;">
                    <strong>Links : </strong><a href="/str_dataview_station/'||p.station_id||'">dati e anagrafica</a>
                </p>
            </div>'                         AS marker_desc
        FROM
            p
            LEFT JOIN t ON (p.station_id = t.main_station_id)
            LEFT JOIN metadata.view_stations_info sm ON (sm.station_id = t.station_id)
            LEFT JOIN main.municipalities m USING (mu_id)
        WHERE
            t.main_station_id IN (
                    SELECT
                        station_id
                    FROM
                        metadata.stations_status
                    WHERE
                        ss_dataview_publish      IS TRUE
                        AND ss_suspended         IS FALSE
            )
            AND sm.station_active       IS TRUE
            AND sm.station_lat_wgs84    IS NOT NULL
            AND sm.station_lon_wgs84    IS NOT NULL
            AND station_roaming_type_id IN (1,2,4) -- stazioni fisse, mobili, siti con stanziamento
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = p.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
        ORDER BY
            sm.station_name;
    };

    # log
    # $self->app->log->debug("Query\n".$sql);
    $self->app->log->debug("Parameters: $param_id, Stat: $stat_id");

    # return
    return $self->pg->db->query($sql, $param_id, $stat_id)->hashes();
}

sub get_public_data_station {
    my ( $self, $station_id, $aggregation, $date_from, $date_to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_public_data_station");
    $self->app->log->debug("Date FROM $date_from");
    $self->app->log->debug("Date TO $date_to");

    # check if it is a mobile station located in a specific site
    my $sql = qq{
        SELECT
            ss.station_override_id
        FROM metadata.stations_sites ss
        WHERE
            ss.station_id = ?
            AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
    };

    my $res = $self->pg->db->query($sql, $station_id)->hash;

    if (defined $res) { # mm located in a site
        my $station_override = $res->{'station_override_id'};
        my $converted = 1;

        my $inner_sql = '';
        my $formule = 'tbl.measure_value';

        if ($converted) {
            # UPDATE 19/06/2024 10:56
            # $formule = 'tbl.measure_value*p.param_conv';
            $formule = 'tbl.measure_value * metadata.f_get_conversion_by_date_prid( sp.param_id, tbl.measure_date_time ) ';

            $inner_sql .= ",";
            $inner_sql .= "(SELECT limit_value FROM clients_stats.limits l WHERE l.pollutant_id = pp.pollutant_id AND limit_aggr = '".$aggregation."'::metadata.e_aggregations AND objective_type_id IN ('TV', 'LV') LIMIT 1) AS limit_value,";
            $inner_sql .= "(SELECT limit_note FROM clients_stats.limits l WHERE l.pollutant_id = pp.pollutant_id AND limit_aggr = '".$aggregation."'::metadata.e_aggregations AND objective_type_id IN ('TV', 'LV') LIMIT 1) AS limit_note";
        }

        # select
        $sql = qq{
            SELECT
                sp.stpr_id              AS station_param_id,
                sp.param_id             AS parameter_id,
                sp.stpr_table_id        AS station_param_table_id,
                COALESCE(vsi.station_network_type_logo, '/bobo-img/default/dataview.png') AS station_logo,
                parameter_name,
                parameter_unit,
                parameter_conv,
                parameter_unit_conv,
                parameter_decimals,
                parameter_active,
                mc.measure_cadence_min  AS station_param_cadence_min,
                COALESCE(sp.parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
                ARRAY(
                    SELECT
                        ARRAY[
                            EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                            CASE
                                WHEN tbl.measure_perc >= 75 THEN ROUND(( $formule )::numeric, parameter_decimals)
                                ELSE NULL::numeric
                            END
                        ]
                    FROM
                         clients.f_data_extraction(sp.stpr_id, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, COALESCE(sp.parameter_object->'general'->>'treatment', 'avg')::metadata.e_treatments) tbl
                    ORDER BY tbl.measure_date_time
                ) AS station_param_values,
                CASE
                    WHEN (sp.parameter_object->'general'->>'treatment' = 'sum') THEN
                        ARRAY(
                                SELECT
                                    ARRAY[EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND( (SUM( $formule ) OVER (ORDER BY tbl.measure_date_time))::numeric, parameter_decimals)]
                                FROM
                                    clients.f_data_extraction(sp.stpr_id, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, (sp.parameter_object-> 'general'->>'treatment')::metadata.e_treatments) tbl
                                ORDER BY tbl.measure_date_time
                            )
                    ELSE NULL
                END AS station_param_values_cum $inner_sql
            FROM
                metadata.view_sites_parameters sp
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
                LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = sp.station_param_cadence
            WHERE
                station_id = ?
                AND station_param_active IS TRUE
                AND param_id IN (
                    SELECT parameter_id
                    FROM metadata.view_parameters_info
                    WHERE parameter_dataview_flag IS TRUE
                )
                AND EXISTS (
                    SELECT 1
                    FROM
                        metadata.stations_instruments si
                    WHERE
                        si.stpr_group_id = sp.stpr_group_id
                        AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                        AND si.stin_master IS TRUE
                )
            ORDER BY
                param_id;
        };

        $station_id = $station_override;
    }
    else {
        my $converted = 1;

        my $inner_sql = '';
        my $formule = 'tbl.measure_value';

        if ($converted) {
            # UPDATE 19/06/2024 10:56
            # $formule = 'tbl.measure_value*p.param_conv';
            $formule = 'tbl.measure_value * metadata.f_get_conversion_by_date_prid( sp.param_id, tbl.measure_date_time ) ';

            $inner_sql .= ",";
            $inner_sql .= "(SELECT limit_value FROM clients_stats.limits l WHERE l.pollutant_id = pp.pollutant_id AND limit_aggr = '".$aggregation."'::metadata.e_aggregations AND objective_type_id IN ('TV', 'LV') LIMIT 1) AS limit_value,";
            $inner_sql .= "(SELECT limit_note FROM clients_stats.limits l WHERE l.pollutant_id = pp.pollutant_id AND limit_aggr = '".$aggregation."'::metadata.e_aggregations AND objective_type_id IN ('TV', 'LV') LIMIT 1) AS limit_note";
        }

        # select
        $sql = qq{
            SELECT
                sp.stpr_id              AS station_param_id,
                sp.param_id             AS parameter_id,
                sp.stpr_table_id        AS station_param_table_id,
                COALESCE(vsi.station_network_type_logo, '/bobo-img/default/dataview.png') AS station_logo,
                p.param_name|| COALESCE(' - '|| sp.stpr_note, '')
                                        AS parameter_name,
                p.param_unit            AS parameter_unit,
                p.param_conv            AS parameter_conv,
                p.param_unit_conv       AS parameter_unit_conv,
                p.param_decimals        AS parameter_decimals,
                p.param_active          AS parameter_active,
                mc.measure_cadence_min  AS station_param_cadence_min,
                COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg') AS parameter_treatment,
                ARRAY(
                    SELECT
                        ARRAY[
                            EXTRACT(EPOCH FROM tbl.measure_date_time)*1000,
                            CASE
                                WHEN tbl.measure_perc >= 75 THEN ROUND(( $formule )::numeric, p.param_decimals)
                                ELSE NULL::numeric
                            END
                        ]
                    FROM
                         clients.f_data_extraction(sp.stpr_id, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg')::metadata.e_treatments) tbl
                    ORDER BY tbl.measure_date_time
                ) AS station_param_values,
                CASE
                    WHEN (pi.pm_info_obj->'general'->>'treatment' = 'sum') THEN
                        ARRAY(
                                SELECT
                                    ARRAY[EXTRACT(EPOCH FROM tbl.measure_date_time)*1000, ROUND( (SUM( $formule ) OVER (ORDER BY tbl.measure_date_time))::numeric, p.param_decimals)]
                                FROM
                                    clients.f_data_extraction(sp.stpr_id, ?::timestamp, ?::timestamp, ?::metadata.e_aggregations, (pi.pm_info_obj-> 'general'->>'treatment')::metadata.e_treatments) tbl
                                ORDER BY tbl.measure_date_time
                            )
                    ELSE NULL
                END AS station_param_values_cum $inner_sql
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.stations_params_info spi USING (stpr_id)
                LEFT JOIN metadata.parameters p USING (param_id)
                LEFT JOIN bobo_tools.parameters_options po USING (param_id)
                LEFT JOIN metadata.parameters_info pi USING (param_id)
                LEFT JOIN infoaria.params_pollutant pp USING (param_id)
                LEFT JOIN metadata.view_stations_info vsi USING (station_id)
                LEFT JOIN metadata.measures_cadence mc ON mc.measure_cadence_id = spi.stpr_info_cadence_fk
            WHERE
                station_id = ?
                AND stpr_active IS TRUE
                AND param_id IN (
                    SELECT parameter_id
                    FROM metadata.view_parameters_info
                    WHERE parameter_dataview_flag IS TRUE
                )
                AND EXISTS (
                    SELECT 1
                    FROM
                        metadata.stations_instruments si
                    WHERE
                        si.stpr_group_id = sp.stpr_group_id
                        AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                        AND si.stin_master IS TRUE
                )
            ORDER BY
                param_order;
        };
    }

    # log
    # $self->app->log->debug("$sql");

    # return
    return $self->pg->db->query($sql, $date_from, $date_to, $aggregation, $date_from, $date_to, $aggregation, $station_id)->hashes();
}

sub get_ordered_params_by_station {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdataview sub get_ordered_params_by_station");

    # check if it is a mobile station located in a specific site
    my $sql = qq{
        SELECT
            ss.station_override_id
        FROM metadata.stations_sites ss
        WHERE
            ss.station_id = ?
            AND tsrange(ss.stsi_startup_date, ss.stsi_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
    };

    my $res = $self->pg->db->query($sql, $station_id)->hash;

    if (defined $res) { # mm located in a site
        my $station_override = $res->{'station_override_id'};
        my $converted = 1;
        my $fullname;

        if ($converted) {
            $fullname = "parameter_name||' ['|| parameter_unit_conv ||']'";
        }
        else {
            $fullname = "parameter_name||' ['|| parameter_conv ||']'";
        }

        $sql = qq{
            SELECT
                stpr_id         AS station_param_id,
                param_id        AS parameter_id,
                stpr_table_id   AS station_param_table_id,
                $fullname AS parameter_fullname,
                parameter_decimals,
                parameter_active,
                parameter_conv,
                COALESCE(sp.parameter_object->'general'->>'treatment', 'avg') AS parameter_treatment,
                COALESCE(sp.parameter_object->'general'->>'windroseV', 'false')::boolean AS parameter_windv,
                COALESCE(sp.parameter_object->'general'->>'windroseD', 'false')::boolean AS parameter_windd
            FROM
                metadata.view_sites_parameters sp
            WHERE station_id = ?
            AND station_param_active IS TRUE
            AND param_id IN (
                SELECT parameter_id
                FROM metadata.view_parameters_info
                WHERE parameter_dataview_flag IS TRUE
            )
            -- SOLO PER OPAS
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = sp.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
            ORDER BY stpr_table_id;
        };

        $station_id = $station_override;
    }
    else {
        my $converted = 1;
        my $fullname;

        if ($converted) {
            $fullname = "param_name|| COALESCE(' - '|| sp.stpr_note, '')||' ['|| param_unit_conv ||']'";
        }
        else {
            $fullname = "param_name|| COALESCE(' - '|| sp.stpr_note, '')||' ['|| param_unit ||']'";
        }

        $sql = qq{
            SELECT
                stpr_id         AS station_param_id,
                param_id        AS parameter_id,
                stpr_table_id   AS station_param_table_id,
                $fullname AS parameter_fullname,
                param_decimals  AS parameter_decimals,
                param_active    AS parameter_active,
                param_conv      AS parameter_conv,
                COALESCE(pi.pm_info_obj->'general'->>'treatment', 'avg') AS parameter_treatment,
                COALESCE(pi.pm_info_obj->'general'->>'windroseV', 'false')::boolean AS parameter_windv,
                COALESCE(pi.pm_info_obj->'general'->>'windroseD', 'false')::boolean AS parameter_windd
            FROM
                metadata.stations_parameters sp
                LEFT JOIN metadata.parameters p         USING (param_id)
                LEFT JOIN metadata.parameters_info pi   USING (param_id)
                LEFT JOIN bobo_tools.parameters_options po USING (param_id)

            WHERE station_id = ?
            AND stpr_active IS TRUE
            AND param_id IN (
                SELECT parameter_id
                FROM metadata.view_parameters_info
                WHERE parameter_dataview_flag IS TRUE
            )
            -- SOLO PER OPAS
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = sp.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
            ORDER BY param_order;
        };
    }

    # log
    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $station_id)->hashes();
}

sub get_public_data_station_table {
    my ( $self, $aggregation, $date_from, $date_to, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_public_data_station_table");
    $self->app->log->debug("Date FROM $date_from");
    $self->app->log->debug("Date TO $date_to");

    my $ext_fields   = 'fulldate::timestamp';
    my $inner_fields = 'fulldate text';
    my $inner_query  = '';
    my $count = 0;

    for my $param (@{$params}) {
        my $stprid = $param->{'station_param_id'};
        my $decimals = $param->{'parameter_decimals'};
        my $treatment = $param->{'parameter_treatment'};
        my $conv = $param->{'parameter_conv'};
        my $prid = $param->{'parameter_id'};

        my $converted = 1;
        my $formule = 'tbl.measure_value';

        if ($converted) {
            # UPDATE 19/06/2024 11:45
            # $formule = qq{ tbl.measure_value* $conv };
            $formule = qq{ tbl.measure_value * metadata.f_get_conversion_by_date_prid( $prid, tbl.measure_date_time ) };
        }

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        $ext_fields .= qq{, col$count };
        $inner_fields .= qq{, col$count text};

        $inner_query .= qq{
            SELECT
                measure_date_time::text,
                ''field$count''::text AS field_name,
                CASE
                    WHEN tbl.measure_perc >= 75 THEN COALESCE(( ROUND( ( $formule )::numeric , $decimals ) )::text, ''--'')
                    ELSE ''--''
                END
            FROM clients.f_data_extraction( $stprid, ''$date_from''::timestamp, ''$date_to''::timestamp, ''$aggregation''::metadata.e_aggregations, ''$treatment''::metadata.e_treatments) tbl
        };

        $count++;
    }

    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
                $inner_query
            ) t ORDER BY measure_date_time, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields );
    };

    # log
    # $self->app->log->debug($final_query);

    # return data
    return $self->pg->db->query($final_query)->hashes();
    # return 1;
}

sub get_public_last_data_bystation {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbdatamanager sub get_public_last_data_bystation");
    $self->app->log->debug("Station ID: $station_id");
    # $self->app->log->debug("Parameter AGGR: $param_aggr");

    # select
    my $sql = qq{
        SELECT
            sp.station_id,
            TO_CHAR(CURRENT_TIMESTAMP, 'DD-MM-YYYY HH24:00:00 UTC') AS fulldate,
            sp.param_id    AS parameter_id,
            p.param_name|| COALESCE(' - '|| sp.stpr_note, '')   AS parameter_name,
            p.param_unit_conv AS parameter_unit_conv,
            COALESCE((select marker_value FROM clients.dataview_lastdata dl WHERE dl.station_id = sp.station_id AND dl.param_id = sp.param_id)::text, 'n.d.')||' '||p.param_unit_conv AS value
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.parameters p USING (param_id)
            LEFT JOIN bobo_tools.parameters_options po USING (param_id)
        WHERE
            station_id = ?
            AND param_id IN (
                SELECT parameter_id
                FROM metadata.view_parameters_info
                WHERE parameter_dataview_flag IS TRUE
            )
            AND stpr_active IS TRUE
            AND EXISTS (
                SELECT 1
                FROM
                    metadata.stations_instruments si
                WHERE
                    si.stpr_group_id = sp.stpr_group_id
                    AND tsrange(si.stin_startup_date, si.stin_dismiss_date, '[)') @> (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Rome')
                    AND si.stin_master IS TRUE
            )
        ORDER BY
            param_order;
    };

    # return
    return $self->pg->db->query($sql, $station_id)->hashes();
}

sub get_station_wind_rose_data {
    my ( $self, $station_id, $from, $to, $aggr ) = @_;

    # log
    $self->app->log->debug("sub get_station_wind_rose_data - stid: $station_id");

    my $sql_id = qq{
        SELECT stpr_id AS stprid
        FROM metadata.stations_parameters
        WHERE station_id = ?
        AND param_id = ?
        AND stpr_active IS TRUE
    };

    my $stprid1 = $self->pg->db->query($sql_id, $station_id, 19)->hash->{'stprid'}; # velocità vento
    if ( ! $stprid1 ) { return undef; }
    my $stprid2 =  $self->pg->db->query($sql_id, $station_id, 22)->hash->{'stprid'}; # direzione vento
    if ( ! $stprid2 ) { return undef; }


    my $sql = qq{
        WITH tmp_first AS (
            SELECT measure_date_time as fulldate,
                round(cast( t1.measure_value  as numeric), 1) as wind_vel,
                CASE
                    WHEN t1.measure_value NOTNULL AND t2.measure_value IS NULL THEN 0.0::numeric
                    ELSE round(cast( t2.measure_value  as numeric), 1)
                END AS wind_dir
            FROM clients.f_data_extraction( $stprid1, ?::timestamp, ?::timestamp, '$aggr'::metadata.e_aggregations, 'avg'::metadata.e_treatments) t1
            LEFT JOIN clients.f_data_extraction( $stprid2, ?::timestamp, ?::timestamp, '$aggr'::metadata.e_aggregations, 'avg'::metadata.e_treatments) t2 USING (measure_date_time)
            ORDER BY measure_date_time
        )
    };

    # sql
    $sql .= qq{
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 337.5 OR wind_dir < 22.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 337.5 OR wind_dir < 22.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 337.5 OR wind_dir < 22.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 337.5 OR wind_dir < 22.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 337.5 OR wind_dir < 22.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 337.5 OR wind_dir < 22.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 22.5 AND wind_dir < 67.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 22.5 AND wind_dir < 67.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 22.5 AND wind_dir < 67.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 22.5 AND wind_dir < 67.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 22.5 AND wind_dir < 67.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 22.5 AND wind_dir < 67.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 67.5 AND wind_dir < 112.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 67.5 AND wind_dir < 112.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 67.5 AND wind_dir < 112.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 67.5 AND wind_dir < 112.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 67.5 AND wind_dir < 112.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 67.5 AND wind_dir < 112.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 112.5 AND wind_dir < 157.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 112.5 AND wind_dir < 157.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 112.5 AND wind_dir < 157.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 112.5 AND wind_dir < 157.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 112.5 AND wind_dir < 157.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 112.5 AND wind_dir < 157.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 157.5 AND wind_dir < 202.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 157.5 AND wind_dir < 202.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 157.5 AND wind_dir < 202.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 157.5 AND wind_dir < 202.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 157.5 AND wind_dir < 202.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 157.5 AND wind_dir < 202.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 202.5 AND wind_dir < 247.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 202.5 AND wind_dir < 247.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 202.5 AND wind_dir < 247.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 202.5 AND wind_dir < 247.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 202.5 AND wind_dir < 247.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 202.5 AND wind_dir < 247.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 247.5 AND wind_dir < 292.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 247.5 AND wind_dir < 292.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 247.5 AND wind_dir < 292.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 247.5 AND wind_dir < 292.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 247.5 AND wind_dir < 292.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 247.5 AND wind_dir < 292.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
        UNION ALL
        SELECT
            COUNT(CASE WHEN wind_vel >= 0 and wind_vel <= 0.5
            AND (wind_dir  >= 292.5 AND wind_dir < 337.5) THEN 1 END) AS calma
            ,COUNT(CASE WHEN wind_vel > 0.5 and wind_vel <= 3
            AND (wind_dir  >= 292.5 AND wind_dir < 337.5) THEN 1 END) AS debole
            ,COUNT(CASE WHEN wind_vel > 3 and wind_vel <= 5
            AND (wind_dir  >= 292.5 AND wind_dir < 337.5) THEN 1 END) AS moderata
            ,COUNT(CASE WHEN wind_vel > 5 and wind_vel <= 10
            AND (wind_dir  >= 292.5 AND wind_dir < 337.5) THEN 1 END) AS forte
            ,COUNT(CASE WHEN wind_vel > 10 and wind_vel <= 9999
            AND (wind_dir  >= 292.5 AND wind_dir < 337.5) THEN 1 END) AS molto_forte
            ,COUNT(CASE WHEN (wind_dir >= 292.5 AND wind_dir < 337.5) AND wind_vel >= 0 THEN 1 END) AS totale
        FROM tmp_first
    };

    # $self->app->log->debug($sql);
    # return
    return $self->pg->db->query($sql, $from, $to, $from, $to)->hashes();
}

1;


=head1 get_data_station

Funzione che recupera dal database i dati di una determinata stazione
di un determinato periodo temporale.

Argomenti:  * id della stazione ('stid');

           * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano che indica la conversione dei dati della stazione ('conv');

Return:     Risultato della query.

=cut

=head1 get_data_by_stprid

Funzione che recupera i dati relativi ad un parametro di una determinata stazione
di un determinato periodo temporale dal database.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente gli id delle associazioni stazione-parametro ('params');

Return:     Risultato della query.

=cut

=head1 get_data_per_validation_by_stprid

Funzione che recupera i dati validi e non validi relativi ad un determinato parametro
di una determinata stazione di un determinato periodo temporale dal database.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id dell'associazione stazione-parametro ('stprid');

           * valore booleano che indica la conversione dei dati della stazione ('conv');

Return:     Risultato della query.

=cut

=head1 get_inst_data_station

Funzione che recupera i dati istantanei di una determinata stazione dal database
per la visualizzazione in tempo reale.

Argomenti:  * id della stazione ('station_id');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_inst_data_table

Funzione che recupera i dati istantanei di una determinata stazione dal database
per la visualizzazione in tempo reale, verificando l'esistenza della relativa tabella prima
di effettuare l'estrazione dei dati.

Argomenti:  * id della stazione ('station_id');

Return:     Se la tabella non esiste: -1;

            se la tabella esiste: risultato della query.

=cut

=head1 get_highcharts_data_by_dates

Funzione che recupera i dati necessari alla creazione dei grafici Highcharts di un
determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati.

=cut

=head1 get_highcharts_moving_average

Funzione che recupera i dati di media mobile di un determinato parametro
necessari alla creazione dei grafici Highcharts di un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

           * oggetto contenente le informazioni relative al parametro ('param');

Return:     Oggetto contenente i dati.

=cut

=head1 get_highcharts_representative_data_by_dates

Funzione che recupera i dati piu' rappresentativi necessari alla creazione dei grafici
Highcharts di un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati.

=cut

=head1 get_highcharts_data_per_year

Funzione che recupera i dati necessari alla creazione dei grafici Highcharts di un
determinato anno.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati.

=cut

=head1 get_highcharts_query

Funzione che recupera la query necessaria alla creazione dei grafici Highcharts di un
determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Query SQL per l'estrazione dei dati.

=cut

=head1 get_windrose_data_bydates

Funzione per recuperare i dati necessari alla generazione della rosa dei venti
di una determinata stazione relativa ad un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id);

           * data d'inizio ('from');

           * data di fine ('to');

           * codice di validita' ('validity');

           * oggetto contenente le informazioni relative alla scala di vento ('scale');

Return:     Oggetto contenente i dati.

=cut

=head1 get_windrose_query

Funzione che recupera la query necessaria alla creazione della rosa dei venti di
una determinata stazione relativa ad un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * codice di validita' ('validity');

           * oggetto contenente le informazioni relative alla scala di vento ('scale');

Return:     Query SQL per l'estrazione dei dati.

=cut

=head1 get_datatable_data_by_dates

Funzione che recupera i dati necessari alla generazione della tabella dei dati
di una determinata macro relativi ad un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati.

=cut

=head1 get_datatable_representative_data_by_dates

Funzione che recupera i dati piu' rappresentativi necessari alla generazione della
tabella dei dati di un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati.

=cut

=head1 get_datatable_query

Funzione che recupera la query necessaria alla creazione della tabella dei dati di
una determinata stazione relativa ad un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Query SQL per l'estrazione dei dati.

=cut

=head1 get_csv_header

Funzione che recupera le informazioni necessarie alla generazione dell' header del file di
estrazione dati dello strumento 'Analyser' in formato .csv.

Argomenti:  * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Array contenente le informazioni.

=cut

=head1 get_csv_data_by_dates

Funzione che recupera i dati necessari alla generazione del file in formato .csv
di una determinata macro relativi ad un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative alla macro ('macro');

Return:     Oggetto contenente i dati, oppure il valore 'undef'.

=cut

=head1 get_data_station_table

Funzione che recupera dal database la tabella dei dati di una determinata stazione
di un determinato periodo temporale.

Argomenti:  * tipologia di aggregazione dei dati ('aggregation');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

           * valore booleano che indica la conversione dei dati della stazione ('converted');

           * valore booleano per la visualizzazione dei valori nulli ('hide_nulls');

           * oggetto contenente le informazioni relative ai parametri ('params');

Return:     Risultato della query.

=cut

=head1 get_station_alarms

Funzione che recupera dal database gli allarmi di una determinata stazione
di un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

Return:     Risultato della query.

=cut

=head1 get_val_codes_by_date_id

Funzione che recupera dal database i codici di validita' dei dati di un determinato parametro
di una determinata stazione per una determinata data.

Argomenti:  * id dell'utente ('user_id');

           * tabella dei dati ('table');

           * data ('date');

           * id del parametro ('id');

Return:     Risultato della query.

=cut

=head1 get_history_by_date_id

Funzione che recupera dal database lo storico dei dati di validazione di un
determinato parametro di una determinata stazione per una determinata data.

Argomenti:  * tabella dei dati ('table');

           * data ('date');

           * id del parametro ('id');

Return:     Risultato della query.

=cut

=head1 get_chart_data_neighborhood

Funzione che recupera dal database i dati di una determinata stazione
di un determinato periodo temporale per la generazione di un grafico relativo
ai dintorni della stazione.

Argomenti:  * tipologia di aggregazione dei dati ('aggr');

           * id dell'associazione stazione-parametro ('stprid');

           * data ('date');

           * valore booleano che indica la conversione dei dati della stazione ('converted');

Return:     Risultato della query.

=cut

=head1 get_table_data_neighborhood

Funzione che recupera dal database i dati di una determinata stazione
di un determinato periodo temporale per la generazione di una tabella relativa
ai dintorni della stazione.

Argomenti:  * tipologia di aggregazione dei dati ('aggr');

           * id dell'associazione stazione-parametro ('stprid');

           * data ('date');

           * valore booleano che indica la conversione dei dati della stazione ('converted');

           * oggetto contenente le informazioni relative ai parametri ('param');

Return:     Risultato della query.

=cut

=head1 update_data_validation_by_calendar

Funzione che gestisce la validazione da calendario presente all'interno
dell'applicativo 'Validazione' che consente la validazione di moli di dati piu' grandi.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative ai parametri ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_data_value_by_calendar

Funzione che gestisce la modifica da calendario presente all'interno
dell'applicativo 'Validazione' che consente la modifica dei valori di moli di dati piu' grandi.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative ai parametri ('params');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_data

Funzione che gestisce la validazione e modifica dei dati all'interno
dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * valore booleano che indica la conversione dei dati della stazione ('converted');

           * oggetto contenente le informazioni relative alle celle dei dati da validare/modificare ('cells');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 update_check_data

Funzione che gestisce la validazione finale dei dati all'interno
dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * oggetto contenente le informazioni relative alle celle dei dati da verificare ('cells');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 reset_cells_code

Funzione che gestisce il reset dei codici di validazione applicati ad una o piu' celle
selezionate dall'utente loggato all'interno dell'applicativo 'Validazione'.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni relative alle celle dei dati da modificare ('cells');

Return:     valore 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 get_dataview_indicators_color

Funzione che gestisce la creazione della legenda relativa agli indicatori delle statistiche
di un determinato parametro all'interno dell'applicativo 'Dataview'.

Argomenti:  * id del parametro ('param_id');

           * id della statistica ('stat_id');

Return:     Risultato della query.

=cut

=head1 get_dataview_map_all_last_station_data

Funzione che recupera dal database gli ultimi dati disponibili di un determinato
parametro per le stazioni visibili dall'utente loggato all'interno dell'applicativo 'Dataview'.

Argomenti:  * id dell'utente ('user_id');

           * id del parametro ('param_id');

           * aggregazione del parametro ('param_aggr');

Return:     Risultato della query.

=cut

=head1 get_dataview_map_last_station_data

Funzione che recupera dal database gli ultimi dati disponibili di un determinato
parametro per le stazioni presenti all'interno dell'applicativo 'Dataview'.

Argomenti:  * id del parametro ('param_id');

Return:     Risultato della query.

=cut

=head1 get_dataview_map_all_indicators

Funzione che recupera dal database gli indicatori di una determinata statistica
relativa ad un determinato parametro per le stazioni visibili dall'utente loggato
all'interno dell'applicativo 'Dataview'.

Argomenti:  * id dell'utente ('user_id');

           * id del parametro ('param_id');

           * id della statistica ('stat_id');

Return:     Risultato della query.

=cut

=head1 get_dataview_map_indicators

Funzione che recupera dal database gli indicatori di una determinata statistica
relativa ad un determinato parametro per le stazioni presenti all'interno
dell'applicativo 'Dataview'.

Argomenti:  * id del parametro ('param_id');

           * id della statistica ('stat_id');

Return:     Risultato della query.

=cut

=head1 get_public_data_station

Funzione che recupera dal database i dati visibili dal pubblico di una determinata
stazione all'interno dell'applicativo 'Dataview' per un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id');

           * aggregazione dei dati ('aggregation');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

Return:     Risultato della query.

=cut

=head1 get_ordered_params_by_station

Funzione che recupera, ordinati per id, i parametri di una determinata
stazione all'interno dell'applicativo 'Dataview'.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query.

=cut

=head1 get_public_data_station_table

Funzione che recupera dal database i dati visibili dal pubblico di una determinata
stazione all'interno dell'applicativo 'Dataview' per un determinato periodo temporale.

Argomenti:  * aggregazione dei dati ('aggregation');

           * data d'inizio ('date_from');

           * data di fine ('date_to');

           * oggetto contenente le informazioni relative ai parametri ('params');

Return:     Risultato della query.

=cut

=head1 get_public_last_data_bystation

Funzione che recupera dal database gli ultimi dati aggiornati visibili
dal pubblico di una determinata stazione all'interno dell'applicativo
'Dataview' per un determinato periodo temporale.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query.

=cut

=head1 get_station_wind_rose_data

Funzione che recupera dal database i dati relativi ai parametri del vento di una determinata stazione
in un determinato periodo temporale e con una determinata aggregazione.

Argomenti:  * id della stazione ('station_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * aggregazione temporale ('aggr');

Return:     Risultato della query.

=cut