package Bobo::Model::Dbutilities;
use Mojo::Base -base;
# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results

# https://irclog.perlgeek.de/mojo/2015-12-12/text

use Mojo::JSON qw(decode_json encode_json);
use Encode qw/encode_utf8 decode_utf8/;
use utf8;

has 'pg';
has 'app';

# http://mojolicious.org/perldoc/Mojo/Pg
# http://mojolicious.org/perldoc/Mojo/Pg/Results
# http://mojolicious.org/perldoc/Mojo/Collection

# -----------------------------------------------------------------------------
# REPORT AUTOMATICI
# -----------------------------------------------------------------------------
sub get_siral_status_bydate {
    my ( $self, $from ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_siral_status_bydate");

    # query
    my $sql = qq{
        SELECT
            counter,
            TO_CHAR(wso.execution_ts, 'H HH24:MI DD/MM/YYYY') AS execution_ts_format,
            wso.command,
            COALESCE(
                CASE
                    WHEN wso.result = 200 THEN '<td class="text-success bobo-nowrap">200 <i class="fa-solid fa-circle-check"></i></td>'
                    ELSE '<td class="text-danger font-bold bobo-nowrap">'||wso.result||' <i class="fa-solid fa-circle-x"></i></td>'
                END, '<td></td>'
            ) AS formatted_result,
            CASE
                WHEN wso.mode = 'N' THEN 'Grezzo'
                ELSE 'Valido'
            END AS mode,
            wso.sending_res,
            /*CASE
                WHEN char_length(wso.sending_res::text) > 160 THEN concat(substring(wso.sending_res::text FROM 1 FOR 100), ' <a href="" class="text-info view-result ellipsis-modal" data-toggle="modal" data-target=".modal-result" data-toggle-second="tooltip" data-original-title="Clicca qui per vedere il log completo">&nbsp;<i class="fa-solid fa-square-ellipsis"></i></a>')
                WHEN wso.sending_res::text = 'null' THEN '--'
                ELSE coalesce(wso.sending_res::text,'--')
            END AS formatted_sending_res,*/
            'Richiesta: '::text || (wso.sending_res->>'idRichiesta')::text AS formatted_sending_res,

            wso.process_res,
            CASE
                WHEN char_length(wso.process_res::text) > 160 THEN
                    concat(
                        'Esito: '::text || (wso.process_res->>'idEsito')::text,
                        ' RecInseriti: '::text || (wso.process_res->>'numRecInseriti')::text,
                        ' <a href="" class="text-info view-result ellipsis-modal" data-toggle="modal" data-target=".modal-result" data-toggle-second="tooltip" data-original-title="Clicca qui per vedere il log completo">&nbsp;<i class="fa-solid fa-square-ellipsis"></i></a>'
                    )
                WHEN wso.process_res::text = 'null' THEN '--'
                ELSE coalesce(wso.process_res::text,'--')
            END AS formatted_process_res
        FROM
            client_lig.ws_opas2siral wso
        WHERE
            execution_ts::date = ?::date
        ORDER BY execution_ts DESC
    };

    # return
    return $self->pg->db->query($sql, $from)->hashes();
}

sub get_aernostrum_status_bydate {
    my ( $self, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_aernostrum_status_bydate");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT fulldate_series, fulldate_series::date AS date_series FROM generate_series
            ( ?::timestamp
            , ?::timestamp
            , '1 hour'::interval) s(fulldate_series)
        ),
        a AS (
            SELECT
                DATE_TRUNC('hour', execution_ts) AS execution_ts,
                BOOL_AND(result) AS result
            FROM client_lig.ws_opas2aernostrum
            WHERE execution_ts BETWEEN ?::timestamp AND ?::timestamp
            GROUP BY DATE_TRUNC('hour', execution_ts)
            ORDER BY DATE_TRUNC('hour', execution_ts)
        )
        SELECT
            TO_CHAR(t.date_series, 'DD/MM/YYYY') AS date_result,
            (
                SELECT jsonb_agg(obj) FROM (
                    SELECT
                        jsonb_build_object(
                            'hour_result'     , EXTRACT('hour' FROM inner_t.fulldate_series),
                            'formatted_result', CASE
                                                    WHEN a.result IS TRUE THEN '<td class="text-center bg-green"><i class="fa-solid fa-check"></i></td>'
                                                    WHEN a.result IS FALSE THEN '<td class="text-center bg-red"><i class="fa-solid fa-xmark-large"></i></td>'
                                                    ELSE '<td class="text-center"></td>'
                                                END
                        )::jsonb AS obj
                    FROM
                        t inner_t
                        LEFT JOIN a ON (a.execution_ts = inner_t.fulldate_series)
                    WHERE t.date_series = inner_t.fulldate_series::date
                    ORDER BY inner_t.fulldate_series
                ) AS temp
            ) AS obj_results
        FROM t
        GROUP BY t.date_series
        ORDER BY t.date_series DESC
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $from, $to)->hashes();
}

# -----------------------------------------------------------------------------
# OPENAIR
# -----------------------------------------------------------------------------
sub get_openair_equipments_categories {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_openair_equipments_categories");

    # query
    my $sql = qq{
        SELECT
            category_id,
            category_name
        FROM equipments.categories
        WHERE category_id IN (1, 2, 3, 4, 5, 16)
        ORDER BY category_name;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_openair_runs {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_openair_runs");

    # query
    my $sql = qq{
        SELECT
            j.jq_id,
            j.jq_start_ts,
            TO_CHAR(start_d, 'DD/MM/YYYY') AS start_d,
            TO_CHAR(end_d, 'DD/MM/YYYY') AS end_d,
            stid_p,
            s1.station_name AS station_pollutant,
            stid_w,
            s2.station_name AS station_weather,
            w_calm,
            inst_cat,
            COALESCE(category_name, '--') AS category_name,
            COALESCE(l_lim, '--') AS l_limit,
            COALESCE(u_lim, '--') AS u_limit,
            CASE scale_type
                WHEN 0 THEN 'Default'
                WHEN 1 THEN 'N° fasce della scala'
                WHEN 2 THEN 'Ripartizione step della scala'
                ELSE 'Default'
            END AS scale_type_text,
            COALESCE(scale_opt, '--') AS scale_opt_formatted
        FROM
            clients.jobs_queue j,
            jsonb_to_record(
                ( SELECT jq_args_obj FROM clients.jobs_queue j2 WHERE j.jq_id = j2.jq_id )
            ) AS x(
                start_d     date,
                end_d       date,
                stid_p      integer,
                stid_w      integer,
                w_calm      numeric,
                inst_cat    integer,
                l_lim       text,
                u_lim       text,
                scale_type  integer,
                scale_opt   text
            )
            LEFT JOIN metadata.stations s1 ON s1.station_id = x.stid_p
            LEFT JOIN metadata.stations s2 ON s2.station_id = x.stid_w
            LEFT JOIN equipments.categories c ON c.category_id = x.inst_cat
        WHERE
            j.job_id = 2
            AND j.jq_start_ts::date = CURRENT_DATE
            AND stid_p IN (
                SELECT DISTINCT(station_id)
                FROM
                    bobo.users us
                    LEFT JOIN bobo.user_groups ug USING (us_id)
                    LEFT JOIN bobo.groups g USING (gr_id)
                    LEFT JOIN bobo.group_stations gs USING (gr_id)
                WHERE us.us_id = ?
            )
        ORDER BY
            j.jq_start_ts DESC;

    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

# -----------------------------------------------------------------------------
# JOBS
# -----------------------------------------------------------------------------
sub get_job_command {
    my ( $self, $job ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_job_command");

    # query
    my $sql = qq{
        SELECT
            job_command
        FROM
            clients.jobs
        WHERE
            job_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $job)->hash->{'job_command'};
}

sub get_pending_jobs {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_pending_jobs");

    # query
    my $sql = qq{
        SELECT COUNT(*) AS num
        FROM
            clients.jobs_queue
        WHERE
            us_id = ?
            AND ( jq_end_ts IS NULL OR jq_ack IS FALSE );
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hash->{'num'};
}

sub get_pending_jobs_by_params {
    my ( $self, $job, $args ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_pending_jobs_by_params");

    $self->app->log->debug("JOB: ". $job);
    $self->app->helperDumper($args);

    $args = decode_utf8(encode_json($args));

    # query
    my $sql = qq{
        SELECT COUNT(*) AS num
        FROM
            clients.jobs_queue
        WHERE
            job_id = ?
            -- A @> B AND A <@ B
            AND ( jq_args_obj @> ?::jsonb AND jq_args_obj <@ ?::jsonb )
            AND jq_end_ts IS NULL;
    };

    # return
    return $self->pg->db->query($sql, $job, $args, $args)->hash->{'num'};
}

sub get_finished_jobs {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_finished_jobs");

    # query
    my $sql = qq{
        SELECT
            jq_id        ,
            jq_result_obj
        FROM
            clients.jobs_queue
        WHERE
            us_id = ?
            AND jq_end_ts IS NOT NULL
            AND jq_ack IS FALSE;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_job_by_id {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub get_job_by_id");

    # query
    my $sql = qq{
        SELECT
            jq_id        ,
            job_id       ,
            us_id        ,
            jq_args_obj  ,
            jq_start_ts  ,
            jq_end_ts    ,
            jq_result_obj,
            jq_ack
        FROM
            clients.jobs_queue
        WHERE
            jq_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $id)->hash;
}

sub insert_new_job {
    my ( $self, $user_id, $job, $args ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub insert_new_job");

    # query and return
    return $self->pg->db->insert('clients.jobs_queue', {
        us_id       => $user_id,
        job_id      => $job,
        jq_args_obj => decode_utf8(encode_json($args))
    }, { returning => 'jq_id' })->hash->{'jq_id'};
}

sub update_job_result {
    my ( $self, $id, $result ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub update_job_result");

    # query and return
    return $self->pg->db->update('clients.jobs_queue', {
        jq_result_obj => decode_utf8(encode_json($result)),
        jq_end_ts     => $self->app->helperGetFullDate()
    }, { jq_id => $id });
}

sub update_job_ack {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbutilities sub update_notification_ack");

    # query and return
    return $self->pg->db->update('clients.jobs_queue', {
        jq_ack => 1
    }, { jq_id  => $id });
}



1;

=head1 get_siral_status_bydate

Funzione che effettua il recupero dello status del webservice Siral in un determinato
periodo temporale.

Argomenti:  * data d'inizio ('from');

Return:     Risultato della query.

=cut

=head1 get_aernostrum_status_bydate

Funzione che effettua il recupero dello status del webservice AerNostrum in un determinato
periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

Return:     Risultato della query.

=cut

=head1 get_openair_equipments_categories

Funzione che recupera le categorie di strumenti dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 get_openair_runs

Funzione che recupera le informazioni delle richieste inviate dall'utente per la creazione delle immagini dei grafici OpenAir dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_job_command

Funzione che recupera il comando da lanciare di un determinato job.

Argomenti:  * id del tipo di job ('job');

Return:     Risultato della query.

=cut

=head1 get_pending_jobs

Funzione che recupera dal database il numero di richieste nella coda di job ancora in attesa di essere eseguite.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_pending_jobs_by_params

Funzione che recupera dal database il numero di richieste nella coda di job con determinati parametri e ancora in attesa di essere eseguite.

Argomenti:  * id del tipo di job ('job');

           * oggetto contenente i parametri della richiesta inseriti dall'utente ('args');

Return:     Risultato della query.

=cut

=head1 get_finished_jobs

Funzione che recupera dal database il numero di richieste completate.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_job_by_id

Funzione che recupera una determinata richiesta dalla coda di job.

Argomenti:  * id della richiesta ('id');

Return:     Risultato della query.

=cut

=head1 insert_new_job

Funzione che inserisce una nuova richiesta nella coda di job.

Argomenti:  * id dell'utente ('user_id');

           * id del tipo di job ('id');

           * oggetto contenente i parametri della richiesta inseriti dall'utente ('args');

Return:     Risultato della query.

=cut

=head1 update_job_result

Funzione che aggiorna il risultato e, di conseguenza, la data di fine di una determinata richiesta nella coda di job.

Argomenti:  * id della richiesta ('id');

           * oggetto json contenente il risultato della richiesta ('result');

Return:     Risultato della query.

=cut

=head1 update_job_ack

Funzione che aggiorna il campo di acknowledge di una determinata richiesta nella coda di job.

Argomenti:  * id della richiesta ('id');

Return:     Risultato della query.

=cut