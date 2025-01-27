package Bobo::Model::Dbverbali;
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

# Getters
# -----------------------------------------------------------------------------
sub get_compilers {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub get_compilers");

    # query
    my $sql = qq{
        SELECT
            user_id,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname
        FROM
            bobo.view_users vu
        WHERE
            user_active IS TRUE
            AND portal_id = (
                SELECT
                    portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        ORDER BY user_surname;
    };

    # $self->app->log->debug($sql);

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_reports_by_dates {
    my ( $self, $userid, $from, $to, $prov ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub get_reports_by_dates");

    # query
    my $sql = qq{
        SELECT
            meet_id,
            meet_date,
            meet_start_time,
            meet_end_time,
            province_code,
            meet_locality,
            meet_title,
            user_fullname,
            user_avatar_thumb
        FROM
            reports.view_meetings
        WHERE
            meet_date BETWEEN ? AND ?
            AND portal_id = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
    };

    if ($prov != -1) {
        $sql .= qq{
            AND province_id = $prov
        };
    }

    $sql .= qq{
        ORDER BY meet_date;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $userid)->hashes;
}

sub get_report_by_id {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub get_report_by_id");

    # query
    my $sql = qq{
        SELECT
            meet_id,
            meet_date,
            meet_date_format,
            meet_start_time,
            meet_end_time,
            province_id,
            province_name,
            province_code,
            meet_locality,
            meet_participants,
            ARRAY(
                SELECT

                    u.us_name||' '
                    ||COALESCE(u.us_2nd_name, '')
                    ||u.us_surname              AS user_fullname
                FROM
                    bobo.users u
                WHERE u.us_id = ANY (vm.meet_participants)

            ) AS participants,
            meet_title,
            meet_desc,
            us_id,
            user_fullname,
            user_avatar,
            user_avatar_thumb,
            portal_id,
            meet_insert_time,
            meet_pdf_time,
            meet_pdf_created,
            meet_mail_sent

        FROM
            reports.view_meetings vm
        WHERE
            meet_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $rpid)->hash;
}

sub insert_report {
    my ( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub insert_report");

    my $tx;
    my $new_rpid;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo report verbale CIL e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbverbali STEP 1");
        # "array-participants" => [
        #                          4,
        #                          2,
        #                          5
        #                        ],
        # "report-date" => "30/05/2022",
        # "report-id" => "",
        # "report-locality" => "via garin",
        # "report-participants" => [
        #                          4,
        #                          2,
        #                          5
        #                        ],
        # "report-prov" => 1,
        # "report-text" => "<p>Prova testo verbale&nbsp;</p>",
        # "report-time-end" => "11:20",
        # "report-time-start" => "09:20",
        # "report-title" => "Test",
        # "report-verbalizer" => 4

        # ARRAY networks
        my @participants;
        if (ref($params->{'report-participants'}) eq 'ARRAY') {
            @participants = @{$params->{'report-participants'}};
        }
        else {
            push @participants, $params->{'report-participants'};
        }

        $new_rpid = $self->pg->db->insert('reports.meetings', {
            meet_date         => $self->app->helperGetFormattedFulldate($params->{'report-date'}), # NOT NULL
            meet_start_time   => $params->{'report-time-start'}, # NOT NULL
            meet_end_time     => $params->{'report-time-end'}, # NOT NULL
            province_id       => $params->{'report-prov'}, # NOT NULL
            meet_locality     => $params->{'report-locality'}, # NOT NULL
            meet_participants => (scalar \@participants  != 0) ? \@participants : undef,
            meet_title        => $params->{'report-title'}, # NOT NULL
            meet_desc         => $params->{'report-text'}, # NOT NULL
            us_id             => $params->{'report-verbalizer'} # NOT NULL
        }, { returning => 'meet_id' })->hash->{'meet_id'};
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
    $self->app->log->debug("Bobo::Model::Dbverbali sub update_report");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- modifica report verbale
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbverbali STEP 1");
        # "array-participants" => [
        #                          4,
        #                          2,
        #                          5
        #                        ],
        # "report-date" => "30/05/2022",
        # "report-id" => "",
        # "report-locality" => "via garin",
        # "report-participants" => [
        #                          4,
        #                          2,
        #                          5
        #                        ],
        # "report-prov" => 1,
        # "report-text" => "<p>Prova testo verbale&nbsp;</p>",
        # "report-time-end" => "11:20",
        # "report-time-start" => "09:20",
        # "report-title" => "Test",
        # "report-verbalizer" => 4

        # ARRAY networks
        my @participants;
        if (ref($params->{'report-participants'}) eq 'ARRAY') {
            @participants = @{$params->{'report-participants'}};
        }
        else {
            push @participants, $params->{'report-participants'};
        }

        $self->pg->db->update('reports.meetings', {
            meet_date         => $self->app->helperGetFormattedFulldate($params->{'report-date'}), # NOT NULL
            meet_start_time   => $params->{'report-time-start'}, # NOT NULL
            meet_end_time     => $params->{'report-time-end'}, # NOT NULL
            province_id       => $params->{'report-prov'}, # NOT NULL
            meet_locality     => $params->{'report-locality'}, # NOT NULL
            meet_participants => (scalar \@participants  != 0) ? \@participants : undef,
            meet_title        => $params->{'report-title'}, # NOT NULL
            meet_desc         => $params->{'report-text'}, # NOT NULL
            us_id             => $params->{'report-verbalizer'} # NOT NULL
        }, { meet_id => $params->{'report-id'} });
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

sub update_report_pdf_creation {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub update_report_pdf_creation");

    # query and return
    return $self->pg->db->update('reports.meetings', {
        meet_pdf_time => $self->app->helperGetFullDate()
    }, { meet_id => $rpid });
}

sub delete_report {
    my ( $self, $rpid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbverbali sub delete_report");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- eliminazione del verbale
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbverbali STEP 1");

        # query
        my $sql = qq{
            DELETE FROM reports.meetings
            WHERE meet_id = ?;
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

=head1 get_compilers

Funzione che recupera i verbalizzanti dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_reports_by_dates

Funzione che recupera, dati un certo periodo temporale e l'id di una provincia,
tutti i relativi verbali dal database.

Argomenti:  * id dell'utente ('userid');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prov');

Return:     Risultato della query.

=cut

=head1 get_report_by_id

Funzione che recupera, dato l'id, le informazioni di un determinato verbale dal database.

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 insert_report

Funzione che inserisce un nuovo verbale nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni del report da inserire ('params');

Return:     Se tutto OK, restituisce l'id del verbale appena inserito;

        Se KO, restituisce 'undef'.

=cut

=head1 update_report

Funzione che modifica un determinato verbale.

Argomenti:  * oggetto contenente le informazioni del report da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_report_pdf_creation

Funzione che modifica la data di creazione del PDF

Argomenti:  * id del report ('rpid');

Return:     Risultato della query.

=cut

=head1 delete_report

Funzione che elimina un determinato verbale dal database.

Argomenti:  * id del report ('rpid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut