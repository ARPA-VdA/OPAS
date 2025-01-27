package Bobo::Controller::Telegram;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

# This action will render a template
sub telegram {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Telegram sub telegram");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get channels
    my $channels = $self->dbtelegram->get_channels($user_id);
    $self->stash(channels => $channels);

    # render
    $self->render('divulgazione/telegram');
}

sub get_messages {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Telegram sub get_messages");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $ch = $self->param('ch'); # post
    $self->app->log->debug("Date from: $from, date to: $to, channel: $ch");

    my $user_id = $self->session('it.ecometer.bobo');

    my $messages = $self->dbtelegram->get_messages_by_dates($user_id, $from, $to, $ch);

    my $json = {
        res => "OK",
        messages => $messages
    };

    # render
    $self->render(json => $json);
}

sub get_selected_message {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Telegram sub get_selected_message");

    my $msgid = $self->param('id'); # post

    $self->app->log->debug("Message id: $msgid");

    # get reports from dateFrom to dateTo
    my $msg = $self->dbtelegram->get_message_by_id($msgid);

    my $json = {
        res => "OK",
        msg => $msg
    };

    # render
    $self->render(json => $json);
}

sub put_message {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Telegram sub put_message");
    $self->helperDumperPostData('Telegram', 'put_message', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;

    my $user_id = $self->session('it.ecometer.bobo');

    # if arg_id defined -> edit report
    $self->app->log->debug("Bobo::Controller::Telegram insert new Message");
    my $res = $self->dbtelegram->insert_new_message($user_id, $params);

    # check result
    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_selected_message {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Telegram sub del_selected_message");
    $self->helperDumperPostData('Telegram', 'del_selected_message', $self->req->body_params);

    my $msg = $self->param('id'); # post

    $self->app->log->debug("Message id: $msg");

    my $json;

    my $res = $self->dbtelegram->delete_message_by_id($msg);

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

=head1 telegram

Render della pagina di gestione della messaggistica tramite Telegram.

Argomenti:  /

Return:     /

=cut

=head1 get_messages

Funzione per recuperare i messaggi inviati sui canali Telegram di cui l'utente ha la visibilità
in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id del canale ('ch');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i messaggi.

=cut

=head1 get_selected_message

Funzione per recuperare, dato l'id, un determinato messaggio.

Argomenti:  * id del messaggio ('id');

Return:     json contenente la risposta "OK" e il messaggio.

=cut

=head1 put_message

Funzione per inviare un nuovo messaggio.

Argomenti:  * oggetto contenente le informazioni del messaggio da inviare ('params');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_message

Funzione per eliminare, dato l'id, un determinato messaggio.

Argomenti:  * id del messaggio ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut
