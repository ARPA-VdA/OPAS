package Bobo::Model::Dbfaq;
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
# FAQ functions
# -----------------------------------------------------------------------------

## FAQ REGION

# Getters
# -----------------------------------------------------------------------------

# get all selectable faq arguments
sub faq_get_search_arguments {
    my ( $self, $flag_tech ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_search_arguments");

    # query
    my $sql = qq{
        SELECT
            faq_page_id,
            faq_page_name,
            faq_arg_id,
            faq_arg_title COLLATE "POSIX"
        FROM bobo.view_faq_page_arguments
    };

    if ($flag_tech == 0) {
        $sql .= qq{ WHERE faq_arg_technical IS FALSE };
    }

    $sql .= qq{ ORDER BY faq_page_id, faq_arg_title; };

    # return
    $self->pg->db->query($sql)->hashes;
}

# get first argument to visualize when user enter in the faq page
sub faq_get_first_page_arguments {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_first_page_arguments");

    # query first Help
    # SELECT * FROM bobo.view_faq_page_arguments WHERE faq_page_id = (SELECT min(faq_page_id) FROM bobo.faq_pages);
    my $sql = qq{
        SELECT * FROM bobo.view_faq_page_arguments WHERE faq_page_id = 1;
    };

    # return
    # $self->pg->db->query($sql)->hashes;
    $self->pg->db->query($sql)->hash;
}

# get all pages
sub faq_get_pages {
    my ( $self ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_pages");

    # query
    my $sql = qq{
        SELECT * FROM bobo.faq_pages ORDER BY faq_page_id;
    };

    # return
    $self->pg->db->query($sql)->hashes;
}

# get data about selected option and all related arguments
sub faq_get_selected_page_arguments {
    my( $self, $arg_id, $flag_tech) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_selected_page_arguments");

    # query
    my $sql = qq{
        SELECT
            faq_page_id,
            faq_page_name,
            faq_arg_id,
            faq_arg_title COLLATE "POSIX",
            faq_arg_desc
        FROM bobo.view_faq_page_arguments
        WHERE faq_page_id = (
            SELECT faq_page_id
            FROM bobo.view_faq_page_arguments
            WHERE faq_arg_id = ?
        )
    };

    if ($flag_tech == 0) {
        $sql .= qq{ AND faq_arg_technical IS FALSE };
    }

    $sql .= qq{ ORDER BY faq_arg_title; };

    # return
    $self->pg->db->query($sql, $arg_id)->hashes;
}

# get articles that contain keywords searched by the user
sub faq_get_arguments_by_keywords {
    my( $self, $keywords, $flag_tech) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_arguments_by_keywords");

    # query
    my $sql = qq{
        WITH temp AS (
            SELECT *
            FROM bobo.view_faq_page_arguments
            WHERE faq_arg_desc_fts @@ to_tsquery('italian', ?) IS TRUE
    };

    if ($flag_tech == 0) {
        $sql .= qq{ AND faq_arg_technical IS FALSE };
    }

    $sql .= qq{
        )
        SELECT
            faq_arg_id,
            faq_page_id,
            faq_arg_title COLLATE "POSIX",
            ts_headline( faq_arg_desc, to_tsquery('italian', ?), 'StartSel = ''<strong class="highlight">'', StopSel = </strong>, HighlightAll=TRUE') AS faq_arg_desc
        FROM temp
        ORDER BY faq_page_id, faq_arg_title;
    };

    # return
    $self->pg->db->query($sql, $keywords, $keywords)->hashes;
}

sub faq_get_number_args {
    my( $self, $page_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_get_number_args");

    # query
    my $sql = qq{
        SELECT COUNT(*) AS n_args FROM bobo.view_faq_page_arguments WHERE faq_page_id = ?;
    };

    # return
    return $self->pg->db->query($sql, $page_id)->hash->{n_args};
}

# Insert
# -----------------------------------------------------------------------------

# add a new page and a new related argument with a default description
sub faq_new_page {
    my ($self, $new_page_name, $flag_tech ) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_new_page");

    # query
    my $sql = qq{
       INSERT INTO bobo.faq_pages (faq_page_name) VALUES (?) RETURNING faq_page_id;
    };

    my $new_page_id = $self->pg->db->query($sql, $new_page_name)->hash->{faq_page_id};

    if (!$new_page_id) {
        $self->app->log->debug("FAQ: Errore durante l'inserimento della nuova pagina!");
        return 0;
    }

    $self->app->log->debug("FAQ: Aggiunta di un articolo standard alla nuova pagina");

    $sql = qq{
        INSERT INTO bobo.faq_arguments
            (faq_page_id, faq_arg_title, faq_arg_desc, faq_arg_technical)
        VALUES
            (?, 'Titolo di default da modificare!', 'Qui puoi inserire il testo di descrizione del nuovo argomento', ?);
    };

    # return
    return $self->pg->db->query($sql, $new_page_id, $flag_tech);
}

# add a new argument
sub faq_new_argument {
    my ($self, $page_id, $new_arg_title, $new_arg_desc, $new_arg_tech) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_new_argument");

    # query
    my $sql = qq{
        INSERT INTO bobo.faq_arguments
            (faq_page_id, faq_arg_title, faq_arg_desc, faq_arg_technical)
        VALUES
        (?, ?, ?, ?) RETURNING faq_arg_id;
    };

    my $arg_id = $self->pg->db->query($sql, $page_id, $new_arg_title, $new_arg_desc, $new_arg_tech)->hash->{faq_arg_id};

    if (!$arg_id) {
        $self->app->log->debug("FAQ: Errore durante l'inserimento del nuovo articolo!");
        return 0;
    }

    $sql = qq{
        UPDATE bobo.faq_arguments
        SET faq_arg_desc_fts = to_tsvector('italian', faq_arg_desc)
        WHERE faq_arg_id = ?;
    };

    # return
    $self->pg->db->query($sql, $arg_id);
}

# Edit
# -----------------------------------------------------------------------------

# edit the argument's title & description and automatically update the fts column for search aim
sub faq_edit_argument {
    my ($self, $arg_id, $new_arg_title, $new_arg_desc) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_edit_argument");

    # query
    my $sql = qq{
        UPDATE bobo.faq_arguments
        SET faq_arg_title = ?,
            faq_arg_desc = ?
        WHERE faq_arg_id = ?;
    };

    if (!$self->pg->db->query($sql, $new_arg_title, $new_arg_desc, $arg_id)) {
        $self->app->log->debug("FAQ: Errore durante la modifica dell'articolo!");
        return 0;
    }

    $sql = qq{
        UPDATE bobo.faq_arguments
        SET faq_arg_desc_fts = to_tsvector('italian', faq_arg_desc)
        WHERE faq_arg_id = ?;
    };

    # return
    $self->pg->db->query($sql, $arg_id);
}

# Delete
# -----------------------------------------------------------------------------

sub faq_delete_argument {
    my ($self, $arg_id) = @_;

    # log
    $self->app->log->debug("Bobo::Model::Dbfaq sub faq_delete_argument");

    # query
    my $sql = qq{
        DELETE FROM bobo.faq_arguments WHERE faq_arg_id = ?;
    };

    # return
    $self->pg->db->query($sql, $arg_id);
}

1;

=head1 faq_get_search_arguments

Funzione che recupera tutti gli argomenti selezionabili dal database.

Argomenti:  * flag che indica se le FAQ sono tecniche o no ('flag_tech');

Return:     Risultato della query.

=cut

=head1 faq_get_first_page_arguments

Funzione che recupera il primo argomento da visualizzare quando si accede alla pagina del portale.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 faq_get_pages

Funzione che recupera tutte le pagine di FAQ disponibili dal database.

Argomenti:  /

Return:     Risultato della query.

=cut

=head1 faq_get_selected_page_arguments

Funzione che recupera le FAQ relative ad un determinato argomento dal database.

Argomenti:  * id dell'argomento ('arg_id');

           * flag che indica se le FAQ sono tecniche o no ('flag_tech');

Return:     Risultato della query.

=cut

=head1 faq_get_arguments_by_keywords

Funzione che recupera gli argomenti dal database, in base a determinate parole chiave inserite dall'utente.

Argomenti:  * parole chiave ('keywords');

           * flag che indica se le FAQ sono tecniche o no ('flag_tech');

Return:     Risultato della query.

=cut

=head1 faq_get_number_args

Funzione che recupera il numero di argomenti di una determinata pagina dal database.

Argomenti:  * id della pagina ('page_id');

Return:     Risultato della query.

=cut

=head1 faq_new_page

Funzione che inserisce una nuova pagina nel database.

Argomenti:  * nome della nuova pagina ('new_page_name');

           * flag che indica se le FAQ sono tecniche o no ('flag_tech');

Return:     Risultato della query.

=cut

=head1 faq_new_argument

Funzione che inserisce una nuova pagina nel database.

Argomenti:  * id della pagina a cui associare il nuovo argomento ('page_id');

           * titolo del nuovo argomento ('new_arg_title');

           * descrizione del nuovo argomento ('new_arg_desc');

           * flag che indica se le FAQ sono tecniche o no ('new_arg_tech');

Return:     Risultato della query.

=cut

=head1 faq_edit_argument

Funzione che modifica un determinato argomento.

Argomenti:  * id dell'argomento da modificare ('arg_id');

           * nuovo titolo dell'argomento, se presente ('new_arg_title');

           * nuova descrizione dell'argomento, se presente ('new_arg_desc');

Return:     Risultato della query.

=cut

=head1 faq_delete_argument

Funzione che elimina un determinato argomento.

Argomenti:  * id dell'argomento da eliminare ('arg_id');

Return:     Risultato della query.

=cut