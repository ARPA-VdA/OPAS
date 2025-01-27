package Bobo::Model::Dboptions;
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
# USER SETTINGS
# -----------------------------------------------------------------------------
sub get_widgets {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub get_widgets");

    # query
    my $sql = qq{
        SELECT
            wdg_id,
            wdg_name,
            wdg_description,
            wdg_image_url
        FROM
            bobo.view_user_widgets
        WHERE
            user_id = ?
        ORDER BY wdg_name;
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

sub get_user_options {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub get_user_options");

    # query
    my $sql = qq{
        SELECT
            option_object
        FROM bobo.user_options
        WHERE
            option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $userid)->hash;
}

sub get_pages_icon {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub get_pages_icon");

    # query
    my $sql = qq{
        SELECT page_id, page_href, mp_name, page_shortcut_icon, menu_type, nlevel(mp.mp_path)
        FROM bobo.menu_pages mp
            LEFT JOIN bobo.menus m USING (menu_id)
            LEFT JOIN bobo.pages p USING (page_id)
        WHERE (
            SELECT COUNT(*) AS children
            FROM bobo.view_menu_pages
            WHERE mp.mp_path @> page_path
            AND page_href IS NOT NULL
            AND page_id IN (
                SELECT DISTINCT(page_id)
                FROM bobo.group_pages
                WHERE gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
            )
        ) > 0
        AND menu_id IN (1, 3) -- menu principale e menu utente
        AND nlevel(mp.mp_path) > 1
        AND (page_id ISNULL OR page_href !~ 'logout')
        ORDER BY menu_id DESC, mp_order;
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

sub insert_options {
    my( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub insert_options");

    # query
    my $sql = qq{
        INSERT INTO bobo.user_options
            (option_user, option_object, option_last_update)
        VALUES
            (?, '{}'::jsonb, CURRENT_TIMESTAMP);
    };

    # return
    return $self->pg->db->query($sql, $userid);
}

sub insert_new_link {
    my( $self, $userid, $params ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub insert_new_link");

    # query and return
    return $self->pg->db->insert('bobo_tools.homepage_links', {
        link_name    => $self->app->helperEscapeParam($params->{'name'}),
        link_url     => $self->app->helperEscapeParam($params->{'url'}),
        link_default => 0,
        us_id        => $userid
    }, { returning => 'link_id' })->hash->{'link_id'};
}

sub update_widgets {
    my( $self, $userid, $widgets ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub update_widgets");

    # query
    my $sql = qq{
        UPDATE bobo.user_options
            SET option_object = jsonb_set(option_object, '{widgets}', ?::jsonb, true),
            option_last_update = CURRENT_TIMESTAMP
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $widgets, $userid);
}

sub update_links {
    my( $self, $userid, $links ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub update_links");

    # query
    my $sql = qq{
        UPDATE bobo.user_options
            SET option_object = jsonb_set(option_object, '{links}', ?::jsonb, true),
            option_last_update = CURRENT_TIMESTAMP
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $links, $userid);
}

sub update_shortcuts {
    my( $self, $userid, $shortcuts ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dboptions sub update_shortcuts");

    # query
    my $sql = qq{
        UPDATE bobo.user_options
            SET option_object = jsonb_set(option_object, '{shortcuts}', ?::jsonb, true),
            option_last_update = CURRENT_TIMESTAMP
        WHERE option_user = ?;
    };

    # return
    return $self->pg->db->query($sql, $shortcuts, $userid);
}

1;

=head1 get_widgets

Funzione che recupera i widgets associati ad un determinato utente dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_user_options

Funzione che recupera le impostazioni del portale di un determinato utente dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 get_pages_icon

Funzione che recupera le icone relative alle pagine in visualizzazione di un determinato utente dal database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.

=cut

=head1 insert_options

Funzione che inserisce le impostazioni di un determinato utente nel database.

Argomenti:  * id dell'utente ('userid');

Return:     Risultato della query.
=cut

=head1 insert_new_link

Funzione che inserisce un nuovo link impostato da un determinato utente nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni del link da inserire ('params');

Return:     id del nuovo link appena inserito.

=cut

=head1 update_widgets

Funzione che modifica le impostazioni dei widgets di un determinato utente nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni dei widgets da modificare ('widgets');

Return:     Risultato della query.

=cut

=head1 update_links

Funzione che modifica le impostazioni dei links di un determinato utente nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni dei links da modificare ('links');

Return:     Risultato della query.

=cut

=head1 update_shortcuts

Funzione che modifica le impostazioni delle shortcuts di un determinato utente nel database.

Argomenti:  * id dell'utente ('userid');

           * oggetto contenente le informazioni delle shortcuts da modificare ('shortcuts');

Return:     Risultato della query.

=cut