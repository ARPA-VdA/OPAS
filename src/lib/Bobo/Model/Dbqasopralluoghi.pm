package Bobo::Model::Dbqasopralluoghi;
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

# Getters
# -----------------------------------------------------------------------------
sub get_reports_by_dates {
    my ( $self, $user_id, $from, $to, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqasopralluoghi sub get_reports_by_dates");

    $prov = ($prov != -1 ? "^$prov\$": ".*");

    # query
    my $sql = qq{
        SELECT
            i.insp_id       ,
            i.mu_id         ,
            mu.mu_name      ,
            p.province_id   ,
            p.province_code ,
            mu.mu_name||' ('||p.province_code||')' AS municipality_format,
            i.insp_locality ,
            i.insp_fulldate ,
            i.insp_operators,
            ARRAY(
                SELECT
                    us_name || ' ' || COALESCE(us_2nd_name||' ', '') || us_surname AS us_fullname
                FROM
                    bobo.users
                WHERE
                    us_id = ANY(i.insp_operators)
            ) AS operators_name,
            i.us_id         ,
            u.us_name || ' ' || COALESCE(u.us_2nd_name||' ', '') || u.us_surname AS us_fullname,
            u.us_avatar_thumb,
            -- Allegati
            ARRAY(
                SELECT
                    lpad(ia.insp_id::text , 9, '0')||'/'||ia.file_archive
                FROM
                    reports.inspection_attachments ia
                WHERE
                    ia.insp_id = i.insp_id
                    AND ia.file_image IS TRUE
                LIMIT 3
            )   AS attachments

        FROM
            reports.inspections i
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN main.municipalities mu USING (mu_id)
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            LEFT JOIN bobo.users u USING (us_id)
        WHERE
            um.portal_id = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
            AND i.insp_fulldate BETWEEN ?::timestamp AND ?::timestamp
            AND p.province_id::text ~ ?
        ORDER BY
            i.insp_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to, $prov)->hashes;
}

sub get_reports_events_by_dates {
    my ( $self, $user_id, $from, $to ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqasopralluoghi sub get_reports_events_by_dates");

    # query
    my $sql = qq{
        SELECT
            i.insp_id,
            mu.mu_name      ,
            p.province_code ,
            p.province_name ,
            mu.mu_name||' ('||p.province_code||')' AS municipality_format,
            i.insp_locality ,
            i.insp_fulldate ,
            TO_CHAR(i.insp_fulldate, '<strong>DD/MM/YYYY</strong> alle <strong>HH24:MI</strong>') AS insp_fulldate_format,
            ARRAY(
                SELECT
                    us_name || ' ' || COALESCE(us_2nd_name||' ', '') || us_surname AS us_fullname
                FROM
                    bobo.users
                WHERE
                    us_id = ANY(i.insp_operators)
            ) AS operators_name,
            i.insp_note     ,
            i.us_id         ,
            u.us_name || ' ' || COALESCE(u.us_2nd_name||' ', '') || u.us_surname AS us_fullname

        FROM
            reports.inspections i
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN main.municipalities mu USING (mu_id)
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            LEFT JOIN bobo.users u USING (us_id)
        WHERE
            um.portal_id = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
            AND i.insp_fulldate BETWEEN ?::timestamp AND ?::timestamp
        ORDER BY
            i.insp_fulldate ASC;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $from, $to)->hashes();
}

sub get_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqasopralluoghi sub get_report_by_id");

    # query
    my $sql = qq{
        SELECT
            i.insp_id,
            i.mu_id         ,
            mu.mu_name      ,
            p.province_id   ,
            p.province_code ,
            p.province_name ,
            mu.mu_name||' ('||p.province_code||')' AS municipality_format,
            i.insp_locality ,
            i.insp_fulldate ,
            TO_CHAR(i.insp_fulldate, '<strong>DD/MM/YYYY</strong> alle <strong>HH24:MI</strong>') AS insp_fulldate_format,
            i.insp_operators,
            ARRAY(
                SELECT
                    us_name || ' ' || COALESCE(us_2nd_name||' ', '') || us_surname AS us_fullname
                FROM
                    bobo.users
                WHERE
                    us_id = ANY(i.insp_operators)
            ) AS operators_name,
            i.insp_note     ,
            i.us_id         ,
            u.us_name || ' ' || COALESCE(u.us_2nd_name||' ', '') || u.us_surname AS us_fullname,
            u.us_avatar_thumb,
            i.insp_insert_ts,
            -- Allegati
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        ia.att_id AS file_id,
                        lpad(ia.insp_id::text , 9, '0')||'/'||ia.file_archive AS file_archive,
                        ia.file_image,
                        ia.file_original
                    FROM
                        reports.inspection_attachments ia
                    WHERE ia.insp_id = i.insp_id
                ) j
            ) AS attachments
        FROM
            reports.inspections i
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN main.municipalities mu USING (mu_id)
            LEFT JOIN main.province_municipalities pm USING (mu_id)
            LEFT JOIN main.provinces p USING (province_id)
            LEFT JOIN bobo.users u USING (us_id)

        WHERE
            i.insp_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash;
}
# END GETTERS

# INSERT
sub insert_report {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::Dbqasopralluoghi insert_report");

    my $tx;
    my $id;

    eval {
        $tx = $self->pg->db->begin;

        # {
        #   "survey-datetime" => "01/05/2023 08:33",
        #   "survey-district" => 4790,
        #   "survey-id" => "",
        #   "survey-operators" => [
        #                           3,
        #                           4,
        #                           5
        #                         ],
        #   "survey-place" => "localit\x{e0} test",
        #   "survey-prov" => 72,
        #   "survey-text" => "..."
        # }

        # ARRAY utenti
        my @operators;
        if (ref($params->{'survey-operators'}) eq 'ARRAY') {
            @operators = @{$params->{'survey-operators'}};
        }
        else {
            push @operators, $params->{'survey-operators'};
        }

        $id = $self->pg->db->insert('reports.inspections', {
            # insp_id        => # id progressivo
            mu_id          => $params->{'survey-district'}, # integer NOT NULL
            insp_locality  => $params->{'survey-place'}, # text NOT NULL
            insp_fulldate  => $self->app->helperGetFormattedFulldate($params->{'survey-datetime'}), # timestamp NOT NULL,
            insp_operators => \@operators, # integer[]
            insp_note      => $params->{'survey-text'}, # text NOT NULL
            us_id          => $userid # integer NOT NULL

        }, { returning => 'insp_id' })->hash->{'insp_id'};
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
    $self->app->log->debug("sub Bobo::Model::Dbqasopralluoghi insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    my $res = $self->pg->db->insert('reports.inspection_attachments', {
        # att_id        => # id progressivo
        insp_id       => $id,
        file_original => $original_name,
        file_archive  => $new_name,
        file_image    => $is_image
        # att_fulldate  => # default data attuale
    });

    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}
# END INSERT

# UPDATE
sub update_report {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::Dbqasopralluoghi update_report");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # {
        #   "survey-datetime" => "01/05/2023 08:33",
        #   "survey-district" => 4790,
        #   "survey-id" => 1,
        #   "survey-operators" => [
        #                           3,
        #                           4,
        #                           5
        #                         ],
        #   "survey-place" => "localit\x{e0} test",
        #   "survey-prov" => 72,
        #   "survey-text" => "..."
        # }

        # ARRAY utenti
        my @operators;
        if (ref($params->{'survey-operators'}) eq 'ARRAY') {
            @operators = @{$params->{'survey-operators'}};
        }
        else {
            push @operators, $params->{'survey-operators'};
        }

        $self->pg->db->update('reports.inspections', {
            mu_id          => $params->{'survey-district'}, # integer NOT NULL
            insp_locality  => $params->{'survey-place'}, # text NOT NULL
            insp_fulldate  => $self->app->helperGetFormattedFulldate($params->{'survey-datetime'}), # timestamp NOT NULL,
            insp_operators => \@operators, # integer[]
            insp_note      => $params->{'survey-text'} # text NOT NULL
        }, { insp_id => $params->{'survey-id'} });
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
# END UPDATE

# DELETE
sub delete_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbqasopralluoghi sub delete_report_by_id");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- eliminazione degli allegati associati al report
        # ##################################################################
        my $sql = qq{
            DELETE FROM reports.inspection_attachments
            WHERE insp_id = ?;
        };

        $self->pg->db->query($sql, $rpid);

        # ##################################################################
        # 2- eliminazione del report
        # ##################################################################
        $sql = qq{
            DELETE FROM reports.inspections
            WHERE insp_id = ?;
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

sub delete_attachment_by_id {
    my ( $self, $att_id ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::Dbqasopralluoghi delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM reports.inspection_attachments
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
# END DELETE

1;

=head1 get_reports_by_dates

Funzione che recupera, dato un certo periodo temporale e l'id di una provincia,
tutti i relativi report dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia ('prov');

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

Funzione che recupera, dato l'id, le informazioni di un determinato sopralluogo dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 insert_report

Funzione che inserisce un nuovo sopralluogo nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id del sopralluogo appena inserito;

=cut

=head1 insert_new_attachment

Funzione che inserisce gli allegati di un determinato report nel database.

Argomenti:  * id del sopralluogo ('id');

           * nome originale dell'allegato ('original_name');

           * nuovo nome dell'allegato per l'archiviazione ('new_name');

           * valore booleano che indica se l'allegato e' un'immagine ('is_image');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_report

Funzione che modifica, dato l'id, un determinato report nel database.

Argomenti:  * oggetto contenente le informazioni del sopralluogo da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

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