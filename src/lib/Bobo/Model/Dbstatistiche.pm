package Bobo::Model::Dbstatistiche;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

# use Mojo::JSON qw(decode_json encode_json);
# use Encode qw/encode_utf8 decode_utf8/;
use utf8;

has 'pg';
has 'app';

# -----------------------------------------------------------------------------
# Analisi validazione dati
# -----------------------------------------------------------------------------
sub get_user_validation_analysis {
    my ( $self, $user_id, $from, $to, $stid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbstatistiche sub get_user_validation_analysis");

    # query
    my $sql = qq{
        SELECT
            sp.stpr_id,
            p.param_name || COALESCE(' - ' || sp.stpr_note, '') AS param_name,
            clients_stats.f_user_validity_analysis(
                sp.stpr_id,
                ?::timestamp,
                ?::timestamp
            ) AS stats_obj
        FROM
            metadata.stations_parameters sp
            LEFT JOIN metadata.stations s USING (station_id)
            LEFT JOIN metadata.parameters p USING (param_id)

        WHERE
            station_id = ?
            AND param_id IN (
                SELECT
                    value AS param_id
                FROM
                    jsonb_to_recordset(
                        bobo.f_get_user_portal_options( ?, '/dat_validaz_finale' )-> 'params'
                    ) AS x(value integer, label text)
             )
        ORDER BY
            station_name, param_name;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $stid, $user_id)->hashes;
}

sub get_last_download {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_last_download");

    # query
    my $sql = qq{
        SELECT
            jq_id        ,
            TO_CHAR((jq_args_obj->>'start_d' )::timestamp, 'DD/MM/YYYY') AS start_date,
            TO_CHAR((jq_args_obj->>'end_d' )::timestamp, 'DD/MM/YYYY') AS end_date,
            (
                SELECT
                    st_network_name
                FROM
                    metadata.stations_network_type
                WHERE st_network_id::text = jq_args_obj->>'net'
            ) AS network,
            jq_result_obj->>'link' AS download_link
        FROM
            clients.jobs_queue
        WHERE
            us_id = ?
            AND job_id = 9
            AND jq_end_ts::date = CURRENT_DATE
        ORDER BY jq_id DESC
        LIMIT 1
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash;
}

# -----------------------------------------------------------------------------
# Analisi copertura dati
# -----------------------------------------------------------------------------
sub get_active_parameters_by_stid {
    my ( $self, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbstatistiche sub get_active_parameters_by_stid");

    # query
    my $sql = qq{
        SELECT
            parameter_id,
            station_param_table_id,
            parameter_name
        FROM
            metadata.view_stations_parameters
        WHERE
            station_id = ?
        AND station_param_active IS TRUE
        AND parameter_type_id IN (1, 2, 3)
        ORDER BY station_param_table_id;
    };

    # return
    return $self->pg->db->query($sql, $station_id)->hashes();
}

sub get_chart_data_coverage_by_stid {
    my ( $self, $year, $station_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbstatistiche sub get_chart_data_coverage_by_stid");

    # query
    my $sql = qq{
        SELECT
            measure_year,
            measure_id,
            ARRAY_AGG(ARRAY[measure_month-1, measure_perc] ORDER BY measure_month ASC) AS measure_perc,
            ARRAY_AGG(ARRAY[measure_month-1, measure_validity_perc] ORDER BY measure_month ASC) AS measure_validity_perc
        FROM
            clients.data_coverage tbl
        WHERE
            measure_year = to_char( '$year'::timestamp, 'YYYY')::smallint
            AND station_id = ?
            AND measure_id IN (
                SELECT
                    station_param_table_id
                FROM
                    metadata.view_stations_parameters
                WHERE
                    station_id = ?
                AND station_param_active IS TRUE
                AND parameter_type_id IN (1, 2, 3)
            )
        GROUP BY 1,2
        ORDER BY 1,2;
    };

    # return
    return $self->pg->db->query($sql, $station_id, $station_id)->hashes();
}

sub get_data_coverage_by_stid {
    my ( $self, $year, $station_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbstatistiche sub get_data_coverage_by_stid");

    my $ext_fields = 'fulldate::timestamp';
    my $ext_conditions = '';
    my $inner_fields = 'fulldate text';
    my $inner_query = '';
    my $count = 0;

    # query
    for my $param (@{$params}) {
        my $measure_id = $param->{'station_param_table_id'};
        # station_id integer NOT NULL,
        # measure_year smallint NOT NULL,
        # measure_month smallint NOT NULL,
        # measure_id smallint NOT NULL,
        # measure_perc smallint NOT NULL,

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        $ext_fields .= ", field".$count." AS field_".$count;
        $inner_fields .= qq{, field$count text};
        $inner_query .= qq{
            SELECT
                s.field_date::date::text,
                ''field$count''::text AS field_name,
                COALESCE(measure_perc::text, ''nd'') AS perc
            FROM
                generate_series(''$year''::date, LEAST(CURRENT_DATE, (extract(''year'' from ''$year''::date)||''-12-31'')::date), ''1 month'') AS s(field_date)
                LEFT JOIN clients.data_coverage tbl ON ( s.field_date = (tbl.measure_year||''-''||tbl.measure_month||''-01'')::date AND tbl.station_id = $station_id AND tbl.measure_id = $measure_id)
        };

        $count++;
    }

    # query
    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
            $inner_query
            ) t ORDER BY field_date, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        ORDER BY 1;
    };

    # $self->app->log->debug($final_query);

    # return
    return $self->pg->db->query($final_query)->hashes();
}

sub get_valid_data_coverage_by_stid {
    my ( $self, $year, $station_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbstatistiche sub get_valid_data_coverage_by_stid");

    my $ext_fields = 'fulldate::timestamp';
    my $ext_conditions = '';
    my $inner_fields = 'fulldate text';
    my $inner_query = '';
    my $count = 0;

    # query
    for my $param (@{$params}) {
        my $measure_id = $param->{'station_param_table_id'};

        # station_id integer NOT NULL,
        # measure_year smallint NOT NULL,
        # measure_month smallint NOT NULL,
        # measure_id smallint NOT NULL,
        # measure_perc smallint NOT NULL,

        if ($count != 0) {
            $inner_query .= 'UNION ALL ';
        }

        $ext_fields .= ", field".$count." AS field_".$count;
        $inner_fields .= qq{, field$count text};
        $inner_query .= qq{
            SELECT
                s.field_date::date::text,
                ''field$count''::text AS field_name,
                COALESCE(measure_validity_perc::text, ''nd'') AS perc
            FROM
                generate_series(''$year''::date, LEAST(CURRENT_DATE, (extract(''year'' from ''$year''::date)||''-12-31'')::date), ''1 month'') AS s(field_date)
                LEFT JOIN clients.data_coverage tbl ON ( s.field_date = (tbl.measure_year||''-''||tbl.measure_month||''-01'')::date AND tbl.station_id = $station_id AND tbl.measure_id = $measure_id)
        };

        $count++;
    }

    # query
    my $final_query = qq{
        SELECT
            $ext_fields
        FROM crosstab('
            SELECT * FROM (
            $inner_query
            ) t ORDER BY field_date, SUBSTRING(field_name FROM ''([0-9]+)'')::integer ASC
        ') AS horiz_table( $inner_fields )
        ORDER BY 1;
    };

    # return
    return $self->pg->db->query($final_query)->hashes();
}

1;

=head1 get_user_validation_analysis

Funzione che effettua il recupero delle statistiche relative ai codici di validazione/invalidazione
per stazione in un determinato periodo temporale dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della stazione ('stid');

Return:     Risultato della query;

=cut

=head1 get_last_download

Funzione che effettua il recupero dei files csv generati in precedenza dall'utente loggato.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_active_parameters_by_stid

Funzione che effettua il recupero, dato l'id, delle informazioni relative ai parametri attivi
associati ad una determinata stazione.

Argomenti:  * id della stazione ('station_id');

Return:     Risultato della query;

=cut

=head1 get_chart_data_coverage_by_stid

Funzione che effettua il recupero, dato l'id, dei grafici di copertura dati di una determinata stazione
per un determinato anno richiesto dall'utente.

Argomenti:  * anno ('year');

           * id della stazione ('station_id');

Return:     Risultato della query;

=cut

=head1 get_data_coverage_by_stid

Funzione che effettua il recupero, dato l'id, della tabella di copertura dati di una determinata stazione
per un determinato anno richiesto dall'utente.

Argomenti:  * anno ('year');

           * id della stazione ('station_id');

           * oggetto contenente le informazioni relative ai parametri della stazione ('params');

Return:     Risultato della query;

=cut

=head1 get_valid_data_coverage_by_stid

Funzione che effettua il recupero, dato l'id, della tabella di copertura dei dati validi di una determinata stazione
per un determinato anno richiesto dall'utente.

Argomenti:  * anno ('year');

           * id della stazione ('station_id');

           * oggetto contenente le informazioni relative ai parametri della stazione ('params');

Return:     Risultato della query;

=cut