package Bobo::Model::Dbmain;
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
# login user
# -----------------------------------------------------------------------------
sub user_login {
    my ( $self, $usermail, $userpass ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub user_login");

    # query
    my $sql = qq{
        SELECT
            user_id,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            user_sys_admin
        FROM
            bobo.view_user_authentication
        WHERE
            user_email = ?
            AND user_password = crypt(?, user_password);
    };

    # return
    $self->pg->db->query($sql, $usermail, $userpass)->hash;
}

sub user_authorization {
    my ( $self, $user_id, $priv ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub user_authorization");
    $self->app->log->debug($priv);

    # query
    my $sql = qq{
        SELECT
            user_first_log,
            user_pwd_expired,
            total_user_grants,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'100')) AS t (bit)) AS temp)::boolean AS user_insert,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'010')) AS t (bit)) AS temp)::boolean AS user_update,
            (SELECT bit_and(temp.bit)::integer FROM ( SELECT * FROM (VALUES (total_user_grants), (b'001')) AS t (bit)) AS temp)::boolean AS user_delete
        FROM
            bobo.view_user_grants_pages
        WHERE
            user_id = ?
            AND page_href = ?;
    };

    # return
    $self->pg->db->query($sql, $user_id, $priv)->hash;
}

sub get_user_byid {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_user_byid");

    # query
    my $sql = qq{
        SELECT
            user_name,
            user_second_name,
            user_surname,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            user_avatar,
            user_avatar_thumb,
            user_pwd_expired,
            user_expiration_time,
            user_sys_admin,
            user_first_log,
            groups_id,
            groups_name,
            company_id,
            company_name,
            company_desc ,
            company_web,
            portal_id,
            portal_name,
            portal_desc,
            portal_extra_desc,
            portal_logo,
            portal_thumb_logo,
            portal_footer_text,
            portal_style,
            portal_carousel,
            portal_basepath,
            portal_link,
            portal_region
        FROM
            bobo.view_user_authentication
        WHERE
            user_id = ?;
    };

    # return
    $self->pg->db->query($sql, $user_id)->hash;
}

sub get_user_bymail {
    my ( $self, $mail ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_user_bymail");

    # query
    my $sql = qq{
        SELECT
            --user_id,
            --user_email,
            user_name,
            user_second_name,
            user_surname,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            user_avatar,
            user_avatar_thumb,
            user_expiration_time,
            user_first_log,
            groups_id,
            groups_name,
            company_id,
            company_name,
            company_desc ,
            -- company_title,
            -- company_logo ,
            -- company_thumb_logo,
            -- company_address,
            -- company_phone,
            company_web,
            -- company_email,
            portal_id,
            portal_name,
            portal_desc,
            portal_extra_desc,
            portal_logo,
            portal_thumb_logo,
            portal_footer_text,
            portal_style,
            portal_carousel,
            portal_basepath
        FROM
            bobo.view_user_authentication
        WHERE
            user_email = ?;
    };

    # return
    $self->pg->db->query($sql, $mail)->hash;
}

sub get_user_page_grants {
    my ( $self, $user_id, $page_href ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_user_page_grants");

    # query
    my $sql = qq{
        SELECT
            user_id,
            user_name,
            user_second_name,
            user_surname,
            user_name || ' ' || COALESCE(user_second_name, '') || ' ' || user_surname AS user_fullname,
            page_name,
            page_href,
            total_user_grants,
            bobo.f_convert_grants_to_string(total_user_grants) AS string_user_grants
        FROM
            bobo.view_user_grants_pages
        WHERE
            user_id = ?
            AND page_href = ?;
    };

    # return
    $self->pg->db->query($sql, $user_id, $page_href)->hash;
}

sub recover_password {
    my ( $self, $user_email ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub recover_password");

    # query
    my $sql = qq{ SELECT bobo.f_recover_user_password(?) AS new_pwd; };

    my $new_pwd = $self->pg->db->query($sql, $user_email)->hash->{new_pwd};

    # return
    return $new_pwd;
}

sub check_password {
    my ($self, $user_id, $password ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub check_password");

    # query
    my $sql = qq{
        SELECT
            CASE
                WHEN us_pwd LIKE crypt(?, us_pwd) THEN TRUE
                ELSE FALSE
            END AS result
        FROM
            bobo.users
        WHERE us_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $password, $user_id)->hash->{'result'};
}

sub edit_password {
    my ( $self, $user_id, $password ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub edit_password");

    # query
    my $sql = qq{
        UPDATE bobo.users
        SET us_pwd = crypt(?, gen_salt('bf')),
        us_first_log = FALSE
        WHERE us_id = ?;
    };

    eval {
        $self->pg->db->query($sql, $password, $user_id);
    };

    # error check
    if ($@) {
       $self->app->log->warn("Error: ".$@);
       return 0;
    }
    else {
       return 1;
    }
}

# -----------------------------------------------------------------------------
# MENU
# -----------------------------------------------------------------------------
sub get_sidebar_usermenu {
    my ( $self, $user_id, $active_page ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_sidebar_usermenu");
    $self->app->log->debug("$active_page");

    # query
    my $sql = qq{
        SELECT *,
        (
            SELECT bit_or(tbit.gp_iud_grants) FROM
            (
                SELECT gp_iud_grants
                FROM bobo.group_pages
                WHERE page_id = vmp.page_id
                AND gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
            ) AS tbit
        ) AS total_user_grants,
        CASE
            WHEN page_href = ? THEN 'active'
            WHEN (SELECT COUNT(*)
                  FROM bobo.view_menu_pages
                  WHERE page_path <@ vmp.page_path
                  AND page_href = ?
                 ) > 0 THEN 'active'
            ELSE null
        END AS menu_page_active
        FROM bobo.view_menu_pages vmp
        WHERE (
            SELECT COUNT(*) AS children
            FROM bobo.view_menu_pages
            WHERE vmp.page_path @> page_path
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
        AND menu_id = 1
        AND menu_page_level > 1
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $user_id, $active_page, $active_page, $user_id)->hashes;
}

sub get_sidebar_secondmenu {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_sidebar_secondmenu");

    # query
    my $sql = qq{
        SELECT *
        FROM bobo.view_menu_pages
        WHERE menu_id = 2
        AND menu_page_level > 1
        AND page_id IN (
            SELECT DISTINCT(page_id)
            FROM bobo.group_pages
            WHERE gr_id IN (
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
        )
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_usernav {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_usernav");

    # query
    my $sql = qq{
        SELECT *
        FROM bobo.view_menu_pages
        WHERE menu_id = 3
        AND menu_page_level > 1
        AND page_id IN (
            SELECT DISTINCT(page_id)
            FROM bobo.group_pages
            WHERE gr_id IN (
                SELECT gr_id
                FROM bobo.user_groups
                WHERE us_id = ?
            )
        )
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $user_id)->hashes;
}

sub get_notesnav {
    my ( $self, $user_id ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_notesnav");

    # query
    my $sql = qq{
        SELECT *,
        (
            SELECT bit_or(tbit.gp_iud_grants) FROM
            (
                SELECT gp_iud_grants
                FROM bobo.group_pages
                WHERE page_id = vmp.page_id
                AND gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
            ) AS tbit
        ) AS total_user_grants
        FROM bobo.view_menu_pages vmp
        WHERE (
            SELECT COUNT(*) AS children
            FROM bobo.view_menu_pages
            WHERE vmp.page_path @> page_path
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
        AND menu_id = 4
        AND menu_page_level > 1
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $user_id, $user_id)->hashes;
}

sub get_breadcrumb {
    my ( $self, $user_id, $active_page ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_breadcrumb");

    # query
    my $sql = qq{
        SELECT *,
        CASE
            WHEN page_href = ? THEN 'active'
            ELSE ''
        END AS menu_page_active
        FROM bobo.view_menu_pages
        WHERE page_path @> (
            SELECT page_path
            FROM bobo.view_menu_pages
            WHERE page_href = ?
            AND page_id IN (
                SELECT DISTINCT(page_id)
                FROM bobo.group_pages
                WHERE gr_id IN (
                    SELECT gr_id
                    FROM bobo.user_groups
                    WHERE us_id = ?
                )
            )
        )
        AND menu_page_level >= 2
        ORDER BY menu_page_order;
    };

    # return
    $self->pg->db->query($sql, $active_page, $active_page, $user_id)->hashes;
}

sub get_shortcuts {
    my ( $self, $userid ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_shortcuts");

    # query
    my $sql = qq{
        SELECT
            *,
            row_number() OVER ()-1 AS key
        FROM (
                SELECT jsonb_array_elements_text( (option_object->'shortcuts')::jsonb)::integer AS page_id
                FROM bobo.user_options
                WHERE option_user = ?
            ) t
        LEFT JOIN bobo.pages USING (page_id)
        ORDER BY key
    };

    # return
    $self->pg->db->query($sql, $userid)->hashes;
}

# -----------------------------------------------------------------------------
# PAGE
# -----------------------------------------------------------------------------
sub get_sys_admin_options{
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_sys_admin_options");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                go_obj
            FROM
                bobo_tools.general_options
            WHERE
                go_tool = 'sysadmin'
        )
        SELECT t.go_obj
        FROM t
        UNION ALL
        SELECT '{}'::jsonb
        WHERE NOT EXISTS (SELECT 1 FROM t);
    };

    # return
    $self->pg->db->query($sql)->hash->{'go_obj'};
}

sub get_portal_page_options {
    my ( $self, $portal_id, $active_page ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub get_portal_page_options");
    $self->app->log->debug("$portal_id");
    $self->app->log->debug("$active_page");

    # query
    my $sql = qq{
        WITH t AS (
            SELECT
                po_obj
            FROM
                bobo_tools.portal_options
            WHERE
                portal_id = ?
                AND page_id = (
                    SELECT page_id
                    FROM bobo.pages
                    WHERE page_href = ?
                )
        )
        SELECT t.po_obj
        FROM t
        UNION ALL
        SELECT '{}'::jsonb
        WHERE NOT EXISTS (SELECT 1 FROM t);
    };

    # return
    $self->pg->db->query($sql, $portal_id, $active_page)->hash->{'po_obj'};
}

sub insert_sys_admin_options{
    my( $self, $obj ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbmain sub insert_sys_admin_options");

    # query
    my $sql = qq{
        INSERT INTO bobo_tools.general_options 
            (go_tool, go_obj)
        VALUES
            ( 'sysadmin', ?::jsonb )
        ON CONFLICT ON CONSTRAINT bobo_tools_general_options_ukey
        DO UPDATE
            SET go_obj = EXCLUDED.go_obj;
    };

    # check result and return
    if ($self->pg->db->query($sql, $obj))
    {
        return 1;
    }
    else {
        return 0;
    }
}



1;

=head1 user_login

Funzione che effettua il login.

Argomenti:  * mail dell'utente ('usermail');

           * password dell'utente ('userpass');

Return:     Risultato della query;

=cut

=head1 user_authorization

Funzione che recupera le autorizzazioni che l'utente possiede
su una determinata pagina.

Argomenti:  * id dell'utente ('user_id');

           * url della pagina di cui verificare l'autorizzazione ('priv');

Return:     Risultato della query;

=cut

=head1 get_user_byid

Funzione che recupera, dato l'id, un determinato utente.

Argomenti:  * id dell'utente ($user_id);

Return:     Risultato della query;

=cut

=head1 get_user_bymail

Funzione che recupera, data la mail, un determinato utente.

Argomenti:  * mail dell'utente ($mail);

Return:     Risultato della query;

=cut

=head1 get_user_page_grants

Funzione che recupera i vari permessi che l'utente possiede
su una determinata pagina.

Argomenti:  * id dell'utente ('user_id');

           * url della pagina di cui verificare i permessi ('page_href');

Return:     Risultato della query;

=cut

=head1 recover_password

Funzione di recupero della password.

Argomenti:  * mail dell'utente ($user_mail);

Return:     Nuova password generata automaticamente.

=cut

=head1 check_password

Funzione di verifica della password.

Argomenti:  * id dell'utente ('user_id');

           * password dell'utente ('password');

Return:     Valore booleano TRUE/FALSE.

=cut

=head1 edit_password

Funzione di modifica della password.

Argomenti:  * id dell'utente ('user_id');

           * password dell'utente ('password');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut

=head1 get_sidebar_usermenu

Funzione che genera il menu laterale delle pagine del portale in
base ai permessi dell'utente.

Argomenti:  * id dell'utente ('user_id');

           * url della pagina attualmente visualizzata ('active_page');

Return:     Risultato della query;

=cut

=head1 get_sidebar_secondmenu

Funzione che genera il menu laterale presente per ogni utente.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_usernav

Funzione che genera il menu a comparsa che si visualizza cliccando
sul nome dell'utente del portale.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_notesnav

Funzione che genera il menu a comparsa che si visualizza cliccando il
pulsante posto in alto a destra sul portale, relativo alle notifiche ricevute
dall'utente.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_breadcrumb

Funzione che genera il percorso della pagina corrente che si visualizza
in alto a destra sul portale.

Argomenti:  * id dell'utente ('user_id');

           * url della pagina attualmente visualizzata ('active_page');

Return:     Risultato della query;

=cut

=head1 get_shortcuts

Funzione che genera il menu delle scorciatoie per le pagine che si visualizza,
quando attivo, in basso a sinistra sul portale.

Argomenti:  * id dell'utente ('user_id');

Return:     Risultato della query;

=cut

=head1 get_sys_admin_options

Funzione che recupera le opzioni di sistema settate dal System Admin.

Argomenti:  /

Return:     Risultato della query;

=cut

=head1 get_portal_page_options

Funzione che recupera le opzioni relative alla pagina attualmente visualizzata
in base al portale di appartenenza dell'utente loggato.

Argomenti:  * id del portale ('portal_id');

           * url della pagina attualmente visualizzata ('active_page');

Return:     Risultato della query;

=cut

=head1 insert_sys_admin_options

Funzione che inserisce nel db le impostazioni settate dal System Admin sottoforma di jsonb

Argomenti:  * oggetto contenente le modifiche relative alle impostazioni ('obj');

Return:     valore 1/0:

                - 1: OK

                - 0: ERRORE

=cut