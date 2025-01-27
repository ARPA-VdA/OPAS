package Bobo::Model::Dbemailgest;
use Mojo::Base -base;

# latest version can always be found in the examples directory.
# https://github.com/kraih/mojo-pg/tree/master/examples/blog
# http://mojo.readthedocs.io/en/latest/docs/models.html#using-models
# https://metacpan.org/pod/Mojo::Pg
# http://mojolicio.us/perldoc/Mojo/Pg/Results
use Mojo::JSON qw(decode_json encode_json);
use Encode qw(encode_utf8);
use utf8;

# https://irclog.perlgeek.de/mojo/2015-12-12/text
has 'pg';
has 'app';

sub get_mailing_lists {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest sub get_external_mails");

    # query
    my $sql = qq{
        SELECT
            ml_id,
            ml_name,
            COALESCE(ml_description, '') AS ml_description,
            comp_id,
            COALESCE(comp_name, '') AS comp_name,
            ARRAY(
                SELECT us_email
                FROM bobo.users
                WHERE us_id IN (
                    SELECT us_id
                    FROM gateways.mlist_users mu
                    WHERE mu.ml_id = m.ml_id
                )
            )::text[] ||
            ARRAY(
                SELECT ee_mail
                FROM gateways.external_emails
                WHERE ee_id IN (
                    SELECT ee_id
                    FROM gateways.mlist_external_mails mem
                    WHERE mem.ml_id = m.ml_id
                )
            )::text[] AS total_mails
        FROM gateways.mailing_list m
        LEFT JOIN bobo.companies USING (comp_id)
        WHERE
            portal_id = (
                SELECT
                    portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            )
        ORDER BY
            ml_name;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_mailing_list_byid {
    my ( $self, $id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest sub get_mailing_list_byid");

    # query
    my $sql = qq{
        SELECT
            ml_id,
            ml_name,
            COALESCE(ml_description, '') AS ml_description,
            comp_id,
            COALESCE(comp_name, '') AS comp_name,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(u)))
                FROM (
                    SELECT
                        us_name     AS name,
                        us_surname  AS surname,
                        us_email    AS email,
                        COALESCE(c2.comp_name, '') AS comp_name
                    FROM bobo.users
                    LEFT JOIN bobo.users_metadata USING (us_id)
                    LEFT JOIN bobo.companies c2 USING (comp_id)
                    WHERE us_id IN (
                        SELECT us_id
                        FROM gateways.mlist_users mu
                        WHERE mu.ml_id = m.ml_id
                    )

                ) u
            ) AS portal_mails,
            (
                SELECT to_json(ARRAY_AGG(row_to_json(e)))
                FROM (
                    SELECT
                        COALESCE(ee_name, '')       AS name,
                        COALESCE(ee_surname, '')    AS surname,
                        ee_mail                     AS email,
                        COALESCE(c3.comp_name, '')  AS comp_name
                    FROM gateways.external_emails
                    LEFT JOIN bobo.companies c3 USING (comp_id)

                    WHERE ee_id IN (
                        SELECT ee_id
                        FROM gateways.mlist_external_mails mem
                        WHERE mem.ml_id = m.ml_id
                    )
                ) e
            ) AS external_mails,
            ARRAY(
                SELECT 'port-'||us_id
                FROM gateways.mlist_users mu
                WHERE mu.ml_id = m.ml_id
            )::text[] ||
            ARRAY(
                SELECT 'ext-'||ee_id
                FROM gateways.mlist_external_mails mem
                WHERE mem.ml_id = m.ml_id
            )::text[] AS total_mails
        FROM gateways.mailing_list m
        LEFT JOIN bobo.companies USING (comp_id)
        WHERE
            ml_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $id)->hash;
}

sub get_external_mails {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest sub get_external_mails");

    # query
    my $sql = qq{
        SELECT
            ee_id,
            COALESCE(ee_name, '') AS ee_name,
            COALESCE(ee_surname, '') AS ee_surname,
            COALESCE(ee_name, '')||COALESCE(' '||ee_surname, '') AS ee_fullname,
            ee_mail,
            comp_id,
            COALESCE(comp_name, '') AS comp_name
        FROM gateways.external_emails
        LEFT JOIN bobo.companies USING (comp_id)
        WHERE
            (
                SELECT
                    portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            ) = ANY(portal_ids)
        ORDER BY
            ee_mail;
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes;
}

sub insert_new_mailing_list {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest insert_new_mailing_list");
    my $sql;
    my $portal;
    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        $sql = qq{ SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?; };
        $portal = $self->pg->db->query($sql, $user_id)->hash->{'portal_id'};

        my $mlid = $self->pg->db->insert('gateways.mailing_list', {
            # id             => # id progressivo
            ml_name        => $self->app->helperEscapeParam($params->{'mlist-name'}),
            ml_description => $self->app->helperEscapeParam($params->{'mlist-desc'}),
            comp_id        => $params->{'mlist-company'} == -1 ? undef : $params->{'mlist-company'},
            portal_id      => $portal
        }, { returning => 'ml_id' })->hash->{'ml_id'};

        my @users = decode_json($params->{'portal-users'});

        $self->app->log->debug("Print ARRAY");
        $self->app->helperDumper(@users);

        for my $user (@{$users[0]}){
            $self->pg->db->insert('gateways.mlist_users', {
                ml_id => $mlid,
                us_id => $user
            });
        }

        my @externals = decode_json( $params->{'external-emails'});

        $self->app->log->debug("Print ARRAY");
        $self->app->helperDumper(@externals);

        for my $external (@{$externals[0]}){
            $self->pg->db->insert('gateways.mlist_external_mails', {
                ml_id => $mlid,
                ee_id => $external
            });
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

sub insert_new_external_mail {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest insert_new_external_mail");

    my $res;
    my $sql;
    my $portal;

    eval {
        $sql = qq{
            SELECT COUNT(*) AS num
            FROM bobo.users
            LEFT JOIN bobo.users_metadata USING (us_id)
            WHERE us_email = ?
            AND portal_id = (
                SELECT portal_id
                FROM bobo.users_metadata
                WHERE us_id = ?
            );
        };

        if ($self->pg->db->query($sql, $params->{'email-mail'}, $user_id)->hash->{'num'} == 0) {
            $sql = qq{ SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?; };
            $portal = $self->pg->db->query($sql, $user_id)->hash->{'portal_id'};

            $res = $self->pg->db->insert('gateways.external_emails', {
                # id         => # id progressivo
                ee_name    => $self->app->helperEscapeParam($params->{'email-name'}),
                ee_surname => $self->app->helperEscapeParam($params->{'email-surname'}),
                ee_mail    => $params->{'email-mail'},
                comp_id    => $params->{'email-company'} == -1 ? undef : $params->{'email-company'},
                portal_ids => [ $portal ]
            }, { returning => 'ee_id' })->hash->{'ee_id'};
        }
        else {
            $res = -2; # email gia esistente negli utenti
        }
    };

    if (defined $res) {
        return $res;
    }
    else {
        $self->app->helperDumper($@->{'message'});
        # ON CONFLICT ON CONSTRAINT gateways_external_emails_ukey
        if (index($@->{'message'}, 'gateways_external_emails_ukey') != -1) {
            $sql = qq{
                UPDATE gateways.external_emails
                SET
                    portal_ids = portal_ids || ?::integer
                WHERE
                    ee_mail = ?
                    AND NOT (?::integer = ANY(portal_ids));
            };

            $self->pg->db->query($sql, $portal, $params->{'email-mail'}, $portal);
            return -1;
        }
        else {
            return undef;
        }
    }
}

sub update_mailing_list {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest update_mailing_list");

    my $sql;
    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- update campi mailing list
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 1");

        $self->pg->db->update('gateways.mailing_list', {
            # id             => # id progressivo
            ml_name        => $self->app->helperEscapeParam($params->{'mlist-name'}),
            ml_description => $self->app->helperEscapeParam($params->{'mlist-desc'}),
            comp_id        => $params->{'mlist-company'} == -1 ? undef : $params->{'mlist-company'}
        }, { ml_id => $params->{'mlist-id'} });

        # ##################################################################
        # 2- rimozione associazioni mailing list - utenti e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 2");

        $sql = qq{
            DELETE FROM gateways.mlist_users
            WHERE
                ml_id = ?
        };

        $self->pg->db->query($sql, $params->{'mlist-id'});

        my @users = decode_json($params->{'portal-users'});
        for my $user (@{$users[0]}){
            $self->pg->db->insert('gateways.mlist_users', {
                ml_id => $params->{'mlist-id'},
                us_id => $user
            });
        }

        # ##################################################################
        # 3- rimozione associazioni mailing list - email esterne e inserimento nuove associazioni
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 3");

        $sql = qq{
            DELETE FROM gateways.mlist_external_mails
            WHERE
                ml_id = ?;
        };

        $self->pg->db->query($sql, $params->{'mlist-id'});

        my @externals = decode_json( $params->{'external-emails'});
        for my $external (@{$externals[0]}){
            $self->pg->db->insert('gateways.mlist_external_mails', {
                ml_id => $params->{'mlist-id'},
                ee_id => $external
            });
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

sub update_external_mail {
    my( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest update_external_mail");

    my $res;

    $res = $self->pg->db->update('gateways.external_emails', {
        # id         => # id progressivo
        ee_name    => $self->app->helperEscapeParam($params->{'email-name'}),
        ee_surname => $self->app->helperEscapeParam($params->{'email-surname'}),
        comp_id    => $params->{'email-company'} == -1 ? undef : $params->{'email-company'}
    }, { ee_id => $params->{'email-id'} });

    # error check
    if (defined $res) {
        return 1;
    }
    else {
        $self->app->log->warn("Error: ".$@);
        return 0;
    }
}

sub delete_mailing_list_by_id {
    my( $self, $mlid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest delete_mailing_list_by_id");

    my $tx;
    my $sql;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- rimozione associazioni mailing list - utenti
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 1");

        $sql = qq{
            DELETE FROM gateways.mlist_users
            WHERE
                ml_id = ?
        };

        $self->pg->db->query($sql, $mlid);

        # ##################################################################
        # 2- rimozione associazioni mailing list - email esterne
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 2");

        $sql = qq{
            DELETE FROM gateways.mlist_external_mails
            WHERE
                ml_id = ?;
        };

        $self->pg->db->query($sql, $mlid);

        # ##################################################################
        # 3- rimozione mailing list
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 3");

        # ATTENZIONE! eliminazione in CASCADE anche nella tabella reports.tickets_mlist
        $sql = qq{
            DELETE FROM gateways.mailing_list
            WHERE
                ml_id = ?;
        };

        $self->pg->db->query($sql, $mlid);
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

sub delete_email_by_id {
    my( $self, $user_id, $eeid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbemailgest delete_email_by_id");

    my $tx;
    my $sql;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- recupero portal_id dell'utente e rimozione email dalle mailing list
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 1");

        $sql = qq{ SELECT portal_id FROM bobo.users_metadata WHERE us_id = ?; };
        my $portal = $self->pg->db->query($sql, $user_id)->hash->{'portal_id'};

        $sql = qq{
            DELETE FROM gateways.mlist_external_mails
            WHERE
                ee_id = ?
                AND ml_id IN (
                    SELECT ml_id
                    FROM gateways.mailing_list
                    WHERE portal_id = ?
                );
        };

        $self->pg->db->query($sql, $eeid, $portal);

        # ##################################################################
        # 2- rimozione email dal portale dell'utente
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 2");

        $sql = qq{
            UPDATE gateways.external_emails
            SET
                portal_ids = array_remove(portal_ids, ?)
            WHERE
                ee_id = ?
        };

        $self->pg->db->query($sql, $portal, $eeid);
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return 0;
    }
    else {
        $tx->commit;

        # ##################################################################
        # 3- controllo dimensione array portal_ids > se vuoto elimino direttamente la riga
        # ##################################################################
        $self->app->log->debug("Bobo::Model::Dbemailgest STEP 3");

        $sql = qq{ SELECT array_length(portal_ids, 1) AS num FROM gateways.external_emails WHERE ee_id = ?; };

        if (!defined $self->pg->db->query($sql, $eeid)->hash->{'num'}) {
            $sql = qq{
                DELETE FROM gateways.external_emails WHERE ee_id = ?;
            };

            $self->pg->db->query($sql, $eeid);
        }

        return 1;
    }
}

1;

=head1 get_mailing_lists

Funzione che recupera le mailing list dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Array di mailing list.

=cut

=head1 get_mailing_list_byid

Funzione che recupera, dato l'id, uan determinata mailing list dal database.

Argomenti:  * id della mailing list ('id');

Return:     Risultato della query.

=cut

=head1 get_external_mails

Funzione che recupera le mail esterne dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Array di mail.

=cut

=head1 insert_new_mailing_list

Funzione che inserisce una nuova mailing list nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni della nuova mailing list ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 insert_new_external_mail

Funzione che inserisce una nuova mail esterna nel database.

Argomenti:  * id dell'utente ('user_id');

           * oggetto contenente le informazioni della nuova mail esterna ('params');

Return:     Se tutto OK, restituisce l'id della nuova mail esterna generato dal database;

        Se la mail è già esistente come indirizzo di uno degli utenti del portale, restituisce -2.

        Se KO, restituisce undef.

=cut

=head1 update_mailing_list

Funzione che modifica una mailing list nel database.

Argomenti:  * oggetto contenente le informazioni della mailing list da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 update_external_mail

Funzione che modifica una mail esterna nel database.

Argomenti:  * oggetto contenente le informazioni della mail esterna da modificare ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_mailing_list_by_id

Funzione che elimina, dato l'id, una determinata mailing list dal database.

Argomenti:  * id della mailing list ('mlid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_email_by_id

Funzione che elimina, dato l'id, una determinata mail esterna dal database.

Argomenti:  * id dell'utente ('user_id');

           * id della mailing list ('eeid');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut
