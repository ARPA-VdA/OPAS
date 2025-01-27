package Bobo::Model::Dbtelegram;
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

# -----------------------------------------------------------------------------
# TELEGRAM MESSAGES functions
# -----------------------------------------------------------------------------

# Getters
# -----------------------------------------------------------------------------
sub get_channels {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbtelegram sub get_channels");

    # query
    my $sql = qq{
        SELECT
            channel_id, chat, channel_name,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'100')) AS t (bit)) AS temp)::boolean AS channel_insert
        FROM
            bobo.view_user_channels
        WHERE
            user_id = ?
        ORDER BY
            channel_name
    };

    # return
    return $self->pg->db->query($sql, $user_id)->hashes();
}

# get messages list
sub get_messages_by_dates {
    my ( $self, $user_id, $from, $to, $ch ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbtelegram sub get_messages_by_dates");

    # check channel
    $ch = ($ch != -1 ? "^$ch\$": ".*");

    # query
    my $sql = qq{
        SELECT
            t.id               ,
            COALESCE(t.tag, '') AS tag,
            t.chat             ,
            tc.tc_color        ,
            t.telegram_type    ,
            t.message          ,
            CASE
                WHEN CHAR_LENGTH(t.message) > 200 THEN CONCAT(SUBSTRING(message FROM 1 FOR 200), ' [...]')
                ELSE COALESCE(t.message,'-')
            END AS message_short,
            t.photo            ,
            t.photo_caption    ,
            t.document         ,
            t.document_caption ,
            t.status           ,
            CASE
                WHEN t.status IS TRUE THEN '<i class="icon-check text-success"></i> Si'
                ELSE '<i class="icon-close text-danger"></i> No'
            END AS icon_status,
            TO_CHAR(sent_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'YYYY-MM-DD HH24:MI')    AS sent_time_format,
            TO_CHAR(insert_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'YYYY-MM-DD HH24:MI')  AS insert_time_format,

            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'001')) AS t (bit)) AS temp)::boolean AS channel_delete
        FROM
            gateways.telegrams t
            LEFT JOIN gateways.telegram_channels tc USING (chat)
            LEFT JOIN bobo.view_user_channels vuc USING (chat)
        WHERE
            insert_time BETWEEN ? AND ?
            AND chat ~ ?
            AND user_id = ?
            AND deleted IS NOT TRUE
        ORDER BY
            insert_time DESC;
    };

    # return
    return $self->pg->db->query($sql, $from, $to, $ch, $user_id)->hashes();
}

sub get_message_by_id {
    my ( $self, $msgid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbtelegram sub get_message_by_id");
    $self->app->log->debug("msgid: $msgid");

    # query
    my $sql = qq{
        SELECT
            id, app, chat, tag, telegram_type, parse_mode, message, photo, photo_caption,
            document, document_caption, status, sent_time,
            tc.tc_color        ,
            CASE
                WHEN status IS TRUE THEN '<i class="icon-check text-success"></i> Si'
                ELSE '<i class="icon-close text-danger"></i> No'
            END AS icon,
            CASE
                WHEN telegram_type = 'Photo'    THEN photo_caption
                WHEN telegram_type = 'Document' THEN document_caption
                ELSE NULL
            END AS caption,
            to_char(insert_time, 'DD.MM.YY')                          AS insert_date,
            to_char(insert_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD-MM-YYYY HH24:MI')                AS insert_time_format,
            COALESCE(to_char(sent_time AT TIME ZONE 'UTC' AT TIME ZONE 'Europe/Rome', 'DD-MM-YYYY HH24:MI'), '')    AS sent_time_format,
            COALESCE(to_char(sent_time, 'DD-MM-YYYY'), '')            AS sent_date
        FROM
            gateways.telegrams t
            LEFT JOIN gateways.telegram_channels tc USING (chat)
        WHERE
            id = ? ;
    };

    # return
    return $self->pg->db->query($sql, $msgid)->hash();
}

sub insert_new_message {
    my( $self, $user_id, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbtelegram sub insert_new_message");

    my $msg = $params->{'msg'};
    my $channel = $params->{'ch'};

    $self->app->log->debug("Channel: $channel, message: $msg");

    # inserisco il messaggio nel db per invio al canale
    my $id = $self->pg->db->insert('gateways.telegrams', {
        app        => 'bobo.telegram',
        chat       => $channel,
        message    => $self->app->helperEscapeParam($params->{'msg'}),
        parse_mode => 'Markdown',
        us_id      => $user_id
    }, { returning => 'id' })->hash->{'id'};

    # check result and return
    if (defined $id) {
        return 1;
    }
    else {
        return 0;
    }
}

sub delete_message_by_id {
    my ( $self, $blid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbtelegram sub delete_message_by_id");

    # query
    my $sql = qq{
        UPDATE gateways.telegrams SET tobe_deleted = true WHERE id = ?;
    };

    # return
    return $self->pg->db->query($sql, $blid);
}

1;

=head1 get_channels

Funzione che recupera i canali Telegram visibili dall'utente dal database.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query.

=cut

=head1 get_messages_by_dates

Funzione che recupera, dato un certo periodo temporale, ed eventualmente l'id di un determinato canale,
tutti i relativi messaggi dal database.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id del canale (opzionale) ('ch');

Return:     Risultato della query.

=cut

=head1 get_message_by_id

Funzione che recupera, dato l'id, le informazioni di un determinato messaggio dal database.

Argomenti:  * id del messaggio ('msgid');

Return:     Risultato della query.

=cut

=head1 insert_new_message

Funzione che inserisce un nuovo messaggio nel database.

Argomenti:  * oggetto contenente le informazioni relative al messaggio da inserire ('params');

Return:     Se tutto OK, restituisce 1;

        Se KO, restituisce 0.

=cut

=head1 delete_message_by_id

Funzione che elimina, dato l'id, un determinato messaggio dal database.

Argomenti:  * id dell'messaggio ('blid');

Return:     Risultato della query.

=cut
