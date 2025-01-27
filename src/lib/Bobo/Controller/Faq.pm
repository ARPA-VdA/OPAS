package Bobo::Controller::Faq;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

sub faq {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub faq");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # get search arguments
    my $search_arguments = $self->dbfaq->faq_get_search_arguments(0);
    $self->stash(search_arguments => $search_arguments);

    # get help argument
    my $first_page_arguments = $self->dbfaq->faq_get_first_page_arguments();
    $self->stash(first_page_arguments => $first_page_arguments);

    # get pages selections
    my $faq_pages = $self->dbfaq->faq_get_pages();
    $self->stash(faq_pages => $faq_pages);

    $self->stash(faq_tech => 0);

    # Render template "utilities/faq.html.ep" with message
    $self->render('utilities/faq');
}

sub faq_tech {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub faq_tech");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # get search arguments
    my $search_arguments = $self->dbfaq->faq_get_search_arguments(1);
    $self->stash(search_arguments => $search_arguments);

    # get help argument
    my $first_page_arguments = $self->dbfaq->faq_get_first_page_arguments();
    $self->stash(first_page_arguments => $first_page_arguments);

    # get pages selections
    my $faq_pages = $self->dbfaq->faq_get_pages();
    $self->stash(faq_pages => $faq_pages);

    $self->stash(faq_tech => 1);

    # Render template "utilities/faq.html.ep" with message
    $self->render("utilities/faq");
}

sub get_page_arguments {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub get_selected_argument");

    # get the report id
    my $arg_id = $self->param('id');
    my $arg_tech = $self->param('tech'); # get
    $self->app->log->debug("arg_id: $arg_id");

    # get data about selected option and all related arguments
    my $selected_page_arguments = $self->dbfaq->faq_get_selected_page_arguments($arg_id, $arg_tech);

    # check result
    my $json;
    if ($selected_page_arguments) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            selected_page_args => $selected_page_arguments
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dell\'argomento selezionato'
        };
    }

    # render
    $self->render(json => $json)
}

sub search_key {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub search_key");

    # get the report by keyword
    my $keywords = $self->param('key'); # get
    my $arg_tech = $self->param('tech');
    $self->app->log->debug("key: $keywords");

    # get data about selected option and all related arguments
    my $search_results = $self->dbfaq->faq_get_arguments_by_keywords($keywords, $arg_tech);

    # check result
    my $json;
    if ($search_results) {
        $self->app->log->debug('Result: OK');
        $json = {
            res => 'OK',
            search_results => $search_results
        };
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $json = {
            res => 'Error',
            message => 'Errore nel recupero dell\'argomento selezionato'
        };
    }

    # render
    $self->render(json => $json)
}

sub put_page {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub put_page");

    my $res;
    # get params from ajax
    my $page_title= $self->param('title');
    my $flag_tech = $self->param('tech');

    $self->app->log->debug("Bobo::Controller::Faq insert of new FAQ page");
    $res = $self->dbfaq->faq_new_page($page_title, $flag_tech);

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub put_argument {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub put_argument");

    my $res;

    # get params from ajax
    my $arg_title = $self->param('title');
    my $arg_text = $self->param('text');
    my $arg_tech = $self->param('tech');

    my $arg_id = $self->param('id');

    # if arg_id defined -> edit FAQ argument
    if (defined $arg_id) {
        $self->app->log->debug("Bobo::Controller::Faq edit of FAQ argument");
        $res = $self->dbfaq->faq_edit_argument($arg_id, $arg_title, $arg_text);
    }
    else { # else -> insert FAQ argument
        my $page_id = $self->param('page_id');

        $self->app->log->debug("Bobo::Controller::Faq insert of new FAQ argument");
        $res = $self->dbfaq->faq_new_argument($page_id, $arg_title, $arg_text, $arg_tech);
    }

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_argument {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Faq sub del_argument");

    my $res;

    # get params from ajax
    my $arg_id = $self->param('id');

    # if arg_id defined -> edit FAQ argument
    if (defined $arg_id) {
        $res = $self->dbfaq->faq_delete_argument($arg_id);
    }

    # check result
    if ($res) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

1;

=head1 faq

Render della pagina relativa alle Frequently Asked Questions (FAQ).

Argomenti:  /

Return:     /

=cut

=head1 faq_tech

Render della pagina relativa alle FAQs tecniche.

Argomenti:  /

Return:     /

=cut

=head1 get_page_arguments

Funzione per recuperare, dato l'id, le pagine relative ad un determinato argomento.

Argomenti:  * id dell'argomento selezionato ('id');

           * flag che indica se le FAQ sono tecniche o no ('tech');

Return:     json contenente la risposta "OK" e le pagine, oppure "Error" e un messaggio d'errore.

=cut

=head1 search_key

Funzione per recuperare, date le parole chiave, gli argomenti corrispondenti.

Argomenti:  * parole chiave ('key');

           * flag che indica se le FAQ sono tecniche o no ('tech');

Return:     json contenente la risposta "OK" e i risultati, oppure "Error" e un messaggio d'errore.

=cut

=head1 put_page

Funzione per inserire una nuova pagina di FAQ.

Argomenti:  * titolo della pagina ('title');

           * flag che indica se le FAQ sono tecniche o no ('tech');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 put_argument

Funzione per inserire/modificare un argomento.

Argomenti:  * titolo dell'argomento ('title');

           * testo della FAQ ('text');

           * flag che indica se le FAQ sono tecniche o no ('tech');

           * id dell'argomento: se presente, l'argomento esiste gia' e quindi l'operazione sara' di modifica ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_argument

Funzione per eliminare, dato l'id, un determinato argomento.

Argomenti:  * id dell'argomento da eliminare ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut