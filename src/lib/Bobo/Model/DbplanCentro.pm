package Bobo::Model::DbplanCentro;
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
sub get_user_role{
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_user_role");

    # query
    my $sql = qq{
        SELECT
            ? AS us_id,
            EXISTS (SELECT 1 FROM bobo.user_groups WHERE us_id = ? AND gr_id = 125) AS is_ctp,
            EXISTS (SELECT 1 FROM bobo.user_groups WHERE us_id = ? AND gr_id = 126) AS is_maintainer;
    };

    # return
    return $self->pg->db->query($sql, $user_id, $user_id, $user_id)->hash;
}

sub get_status {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_status");

    # query
    my $sql = qq{
        SELECT
            status_label,
            status_desc,
            status_action
        FROM reports.view_ced_ticket_status;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_types {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_types");

    # query
    my $sql = qq{
        SELECT
            ctt_id,
            ctt_name,
            ctt_desc
        FROM reports.ced_ticket_types
        ORDER BY ctt_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_urgencies {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_urgencies");

    # query
    my $sql = qq{
        SELECT
            ctu_id,
            ctu_name,
            ctu_desc
        FROM reports.ced_ticket_urgencies
        ORDER BY ctu_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_groups{
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_groups");

    # query
    my $sql = qq{
        SELECT
            gr_id,
            gr_name
        FROM bobo.groups
        WHERE
            gr_id IN (125, 126)
        ORDER BY gr_id;
    };

    # return
    return $self->pg->db->query($sql)->hashes();
}

sub get_tickets {
    my ( $self, $from, $to, $status, $urgency, $type, $useful ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_tickets");

    $status  = ($status  ne '' ? "^$status\$": ".*");
    $urgency = ($urgency != -1 ? "^$urgency\$" : ".*");
    $type    = ($type != -1 ? "^$type\$" : ".*");

    # query
    my $sql = qq{
        WITH s AS (
            SELECT
                ct_id,
                cts_fulldate     AS last_status_date,
                cts_status::text AS last_status,
                ctt_id           AS last_ctt_id,
                ctu_id           AS last_ctu_id,
                gr_id            AS last_gr_id
            FROM (
                SELECT
                    ct_id,
                    cts_fulldate,
                    cts_status::text,
                    ctt_id,
                    ctu_id,
                    gr_id,
                    row_number() OVER (PARTITION BY ct_id ORDER BY cts_fulldate DESC) AS rownum
                FROM reports.ced_tickets_status
            ) AS x
            WHERE x.rownum = 1
        )
        SELECT
            ct.ct_id,
            ct.ct_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS ct_fulldate,
            s.last_ctt_id,
            ctt.ctt_name,
            ctt.ctt_desc,
            ctt.ctt_icon,
            ctt.ctt_colour,
            ct.ct_title,

            ct.us_id,
            CONCAT_WS(' ',
                u.us_name,
                u.us_2nd_name,
                u.us_surname
            )                                   AS user_fullname,
            u.us_avatar_thumb                   AS user_avatar_thumb,
            um.comp_id,
            c.comp_name,

            s.last_status_date AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS last_status_date,
            s.last_status,
            sd.status_desc,
            s.last_ctu_id,
            ctu.ctu_name,
            ctu.ctu_desc,
            ctu.ctu_colour,
            s.last_gr_id,
            g.gr_name AS last_group_name,
            ct.ct_useful
        FROM
            reports.ced_tickets ct
            -- opening metadata
            LEFT JOIN bobo.users u USING (us_id)
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN bobo.companies c USING (comp_id)
            -- last status metadata
            LEFT JOIN s USING (ct_id)
            LEFT JOIN reports.view_ced_ticket_status sd ON (sd.status_label = s.last_status)
            LEFT JOIN reports.ced_ticket_types ctt ON (ctt.ctt_id = s.last_ctt_id)
            LEFT JOIN reports.ced_ticket_urgencies ctu ON (ctu.ctu_id = s.last_ctu_id)
            LEFT JOIN bobo.groups g ON (g.gr_id = s.last_gr_id)

        WHERE
            ( ct.ct_fulldate BETWEEN ?::timestamp AND ?::timestamp OR s.last_status != 'closed')
            AND s.last_status::text ~ ?
            AND s.last_ctu_id::text ~ ?
            AND s.last_ctt_id::text ~ ?
    };

    if($useful eq 'true'){
        $sql .= qq{    
            AND ct.ct_useful IS TRUE
        };
    }

    $sql .= qq{
        ORDER BY
            ct.ct_fulldate DESC;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $status, $urgency, $type)->hashes;
}

sub get_ticket_by_id {
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_ticket_by_id");

    # query
    my $sql = qq{
        SELECT
            ct.ct_id,
            ct.ct_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS ct_fulldate,
            ct.ct_title,
            ct.ct_description,
            ct.us_id,
            CONCAT_WS(' ',
                us_name,
                us_2nd_name,
                us_surname,
                ( CASE WHEN comp_id NOTNULL AND comp_id > 1 THEN '('||comp_name||')' ELSE NULL END )
            )                                   AS user_fullname,
            u.us_avatar_thumb                   AS user_avatar_thumb,
            u.us_email                          As user_email,
            um.comp_id,
            c.comp_name
        FROM
            reports.ced_tickets ct
            -- opening metadata
            LEFT JOIN bobo.users u USING (us_id)
            LEFT JOIN bobo.users_metadata um USING (us_id)
            LEFT JOIN bobo.companies c USING (comp_id)

        WHERE
            ct_id = ?
    };

    # return
    return $self->pg->db->query($sql, $tkid)->hash;
}

sub get_ticket_status_list {
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_ticket_status_list");

    # query
    my $sql = qq{
        SELECT
            s.cts_id         ,
            s.ct_id          ,
            s.us_id          ,
            CONCAT_WS(' ',
                u.us_name,
                u.us_2nd_name,
                u.us_surname
            )                   AS user_fullname,
            u.us_avatar_thumb   AS user_avatar_thumb,
            s.cts_fulldate AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome' AS cts_fulldate,
            s.cts_status     ,
            sd.status_desc   ,
            sd.status_action ,
            s.ctt_id         ,
            ctt.ctt_name     ,
            ctt.ctt_desc     ,
            ctt.ctt_icon     ,
            ctt.ctt_colour   ,
            s.gr_id          ,
            g.gr_name        ,
            s.ctu_id         ,
            ctu.ctu_name     ,
            ctu.ctu_desc     ,
            ctu.ctu_colour   ,
            s.cts_description,
            -- Allegati
            (
                SELECT to_json(ARRAY_AGG(row_to_json(j)))
                FROM (
                    SELECT
                        a.att_id AS file_id,
                        lpad(a.cts_id::text , 9, '0')||'/'||a.file_archive AS file_archive,
                        a.file_image,
                        a.file_original
                    FROM
                        reports.ced_tickets_status_attachments a
                    WHERE a.cts_id = s.cts_id
                ) j
            ) AS attachments

        FROM
            reports.ced_tickets_status s
            LEFT JOIN bobo.users u USING (us_id)
            LEFT JOIN reports.view_ced_ticket_status sd ON (sd.status_label::text = s.cts_status::text)
            LEFT JOIN reports.ced_ticket_types ctt USING (ctt_id)
            LEFT JOIN reports.ced_ticket_urgencies ctu USING (ctu_id)
            LEFT JOIN bobo.groups g USING (gr_id)

        WHERE
            s.ct_id = ?
        ORDER BY
            s.cts_fulldate ASC;
    };

    # return
    return $self->pg->db->query($sql, $tkid)->hashes();
}

sub get_ticket_last_status{
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub get_ticket_last_status");

    # query
    my $sql = qq{
        SELECT
            cts_id,
            ct_id,
            cts_fulldate     AS last_status_date,
            cts_status::text AS last_status,
            ctt_id           AS last_ctt_id,
            ctu_id           AS last_ctu_id,
            gr_id            AS last_gr_id
        FROM
            reports.ced_tickets_status
        WHERE
            ct_id = ?
        ORDER BY
            cts_fulldate DESC
        LIMIT 1;
    };

    # return
    return $self->pg->db->query($sql, $tkid)->hash;
}

# -----------------------------------------------------------------------------
# Write functions
# -----------------------------------------------------------------------------
sub insert_ticket {
    my ( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub insert_ticket");

    my $tx;
    my $new_tkid;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- creazione nuovo ticket e recupero id
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 1");

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

        $new_tkid = $self->pg->db->insert('reports.ced_tickets', {
            # ct_id                 SERIAL
            ct_fulldate          => $self->app->helperGetFullDate(),
            ct_title             => $self->app->helperEscapeParam($params->{'newtic-title'}),
            ct_description       => $self->app->helperEscapeParam($params->{'newtic-body'}),

            us_id                => $user_id
        }, { returning => 'ct_id' })->hash->{'ct_id'};

        # ##################################################################
        # 2- aggiunta status open del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 2");

        $self->pg->db->insert('reports.ced_tickets_status', {
            ct_id        => $new_tkid,
            us_id        => $user_id,
            cts_fulldate => $self->app->helperGetFullDate(),
            cts_status   => 'open',
            gr_id        => $params->{'newtic-assigned'},
            ctt_id       => $params->{'newtic-type'},
            ctu_id       => $params->{'newtic-urgency'}
        });
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
    $self->app->log->debug("Bobo::Model::DbplanCentro sub insert_ticket_status");

    my $tx;
    my $cts_id;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- aggiunta cambiamento di stato del ticket
        # ##################################################################

        # {
        #   "uptic-action" => "reassign",
        #   "uptic-assigned" => 126,
        #   "uptic-body" => "<p>...</p>",
        #   "uptic-id" => 1,
        #   "uptic-urgency" => 1
        # }

        $cts_id = $self->pg->db->insert('reports.ced_tickets_status', {
            ct_id        => $params->{'uptic-id'},
            us_id        => $user_id,
            cts_fulldate => $self->app->helperGetFullDate(),
            cts_status   => $params->{'uptic-action'},
            gr_id        => $params->{'uptic-assigned'},
            ctt_id       => $params->{'uptic-type'},
            ctu_id       => $params->{'uptic-urgency'},
            cts_description => $params->{'uptic-body'}

        }, { returning => 'cts_id' })->hash->{'cts_id'};
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       # rollback
       return 0;
    }
    else {
       $tx->commit;
       return $cts_id;
    }
}

sub insert_new_attachment{
    my( $self, $id, $original_name, $new_name, $is_image ) = @_;

    # log
    $self->app->log->debug("sub Bobo::Model::DbplanCentro insert_new_attachment");
    $self->app->log->debug("File: $original_name to $new_name");

    my $res = $self->pg->db->insert('reports.ced_tickets_status_attachments', {
        # att_id        => # id progressivo
        cts_id        => $id,
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

sub update_ticket {
    my ( $self, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub update_ticket");

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
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 1");

        $self->pg->db->update('reports.ced_tickets', {
            ct_title             => $self->app->helperEscapeParam($params->{'newtic-title'}),
            ct_description       => $self->app->helperEscapeParam($params->{'newtic-body'}),

            ct_update_ts         => $self->app->helperGetFullDate(),
        }, { ct_id => $params->{'newtic-id'} });


         ##################################################################
        # 2- aggiunta status open del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 2");

        $self->pg->db->update('reports.ced_tickets_status', {
            ctt_id      => $params->{'newtic-type'},
            ctu_id      => $params->{'newtic-urgency'}

        }, { ct_id => $params->{'newtic-id'}, cts_status => 'open' });

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

sub update_ticket_usefulness {
    my ( $self, $id, $useful ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub update_ticket_usefulness");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- update delle informazioni del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 1");

        $self->pg->db->update('reports.ced_tickets', {
            ct_useful       => $useful,

            ct_update_ts    => $self->app->helperGetFullDate(),
        }, { ct_id => $id });
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
    my ( $self, $tkid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::DbplanCentro sub delete_ticket");

    my $tx;

    eval {
        $tx = $self->pg->db->begin;

        # ##################################################################
        # 1- delete allegati associati ai cambiamenti di stato del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 1");

        # query
        my $sql = qq{
            DELETE FROM reports.ced_tickets_status_attachments
            WHERE cts_id IN (
                SELECT cts_id
                FROM reports.ced_tickets_status
                WHERE ct_id = ?
            );
        };

        $self->pg->db->query($sql, $tkid);

        # ##################################################################
        # 1- delete cambiamenti di stato del ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 2");

        # query
        $sql = qq{
            DELETE FROM reports.ced_tickets_status
            WHERE ct_id = ?;
        };

        $self->pg->db->query($sql, $tkid);

        # ##################################################################
        # 1- delete ticket
        # ##################################################################
        $self->app->log->debug("Bobo::Model::DbplanCentro STEP 3");

        # query
        $sql = qq{
            DELETE FROM reports.ced_tickets
            WHERE ct_id = ?;
        };

        $self->pg->db->query($sql, $tkid);

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
    $self->app->log->debug("sub Bobo::Model::DbplanCentro delete_attachment_by_id");
    $self->app->log->debug("att_id: $att_id");

    # query
    my $sql = qq{
        DELETE FROM reports.ced_tickets_status_attachments
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

1;

=head1 get_user_role

Restituisce il ruolo dell'utente (es. se è CTP o manutentore).

Argomenti:  
* user_id: identificativo utente

Return:    
* Hash con i ruoli dell'utente

=cut

=head1 get_status

Restituisce la lista degli stati possibili dei ticket.

Argomenti:  /
Return:     Array di hash con gli stati

=cut

=head1 get_types

Restituisce la lista dei tipi di ticket.

Argomenti:  /
Return:     Array di hash con i tipi

=cut

=head1 get_urgencies

Restituisce la lista delle urgenze dei ticket.

Argomenti:  /
Return:     Array di hash con le urgenze

=cut

=head1 get_groups

Restituisce la lista dei gruppi abilitati alla gestione dei ticket.

Argomenti:  /
Return:     Array di hash con i gruppi

=cut

=head1 get_tickets

Restituisce la lista dei ticket filtrati per data, stato, urgenza, tipo e utilità.

Argomenti:  
* from: data inizio
* to: data fine
* status: stato
* urgency: urgenza
* type: tipo
* useful: utilità

Return:    
* Array di hash con i ticket

=cut

=head1 get_ticket_by_id

Restituisce i dettagli di un ticket dato il suo id.

Argomenti:  
* tkid: identificativo del ticket

Return:    
* Hash con i dettagli del ticket

=cut

=head1 get_ticket_status_list

Restituisce la lista degli stati associati a un ticket.

Argomenti:  
* tkid: identificativo del ticket

Return:    
* Array di hash con gli stati del ticket

=cut

=head1 get_ticket_last_status

Restituisce l'ultimo stato di un ticket.

Argomenti:  
* tkid: identificativo del ticket

Return:    
* Hash con i dati dell'ultimo stato

=cut

=head1 insert_ticket

Crea un nuovo ticket e aggiunge lo stato iniziale "Open".

Argomenti:  
* user_id: identificativo utente
* params: parametri del ticket

Return:    
* Id del nuovo ticket o undef in caso di errore

=cut

=head1 insert_ticket_status

Aggiunge un nuovo stato a un ticket.

Argomenti:  
* user_id: identificativo utente
* params: parametri dello stato

Return:    
* Id del nuovo stato o 0 in caso di errore

=cut

=head1 insert_new_attachment

Aggiunge un nuovo allegato a uno stato di ticket.

Argomenti:  
* id: id dello stato
* original_name: nome originale file
* new_name: nome file archiviato
* is_image: flag se immagine

Return:    
* 1 se ok, 0 se errore

=cut

=head1 update_ticket

Aggiorna le informazioni di un ticket esistente.

Argomenti:  
* params: parametri aggiornati del ticket

Return:    
* 1 se ok, 0 se errore

=cut

=head1 update_ticket_usefulness

Aggiorna il campo "utilità" di un ticket.

Argomenti:  
* id: identificativo del ticket
* useful: valore utilità

Return:    
* 1 se ok, 0 se errore

=cut

=head1 delete_ticket

Elimina un ticket e tutte le sue dipendenze (stati e allegati).

Argomenti:  
* tkid: identificativo del ticket

Return:    
* 1 se ok, 0 se errore

=cut

=head1 delete_attachment_by_id

Elimina un allegato dato il suo id.

Argomenti:  
* att_id: identificativo dell'allegato

Return:    
* 1 se ok, 0 se errore

=cut

