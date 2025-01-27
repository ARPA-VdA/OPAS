package Bobo::Controller::Profile;
use Mojo::Base 'Mojolicious::Controller';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::File 'path';

# This action will render a template
sub profile {
    my $self = shift;

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    # render
    $self->render('utente/profile');
}

sub get_user_byid {
    my $self = shift;

    # render
    $self->app->log->debug("Bobo::Controller::Profile sub get_user_byid");

    my $userid = $self->session('it.ecometer.bobo');
    # $self->app->log->debug("User id: $userid");

    # get users associated with the portal
    my $user = $self->dbcommon->get_user_byid($userid);
    my $company = $self->dbcommon->get_comp_detail_byid($user->{'company_id'});

    my $json = {
        res => "OK",
        user => $user,
        comp => $company
    };

    # render
    $self->render(json => $json);
}

sub put_user {
    my $self = shift;

    # render
    $self->app->log->debug("Bobo::Controller::Profile  sub put_user");
    $self->helperDumperPostData('Admin', 'put_user', $self->req->body_params);

    my $res;
    my $params = $self->req->body_params->to_hash;
    my $user_id = $self->session('it.ecometer.bobo');

    # get params from ajax
    $self->app->log->debug("Bobo::Controller::Profile edit of user");
    $res = $self->dbprofile->update_user($params);

    # Caricamento FILE per UPDATE
    my $file = $self->req->upload('file');

    if ($res == 1) {
        if (defined $file) {
            my $basepath;
            my $user = $self->dbmain->get_user_byid($user_id); # with information about basepath and portal

            if (defined $user->{'portal_basepath'}) {
                $basepath = $user->{'portal_basepath'};
            }
            else {
                $basepath = '/bobo-img/default';
            }

            my $user_file = sprintf("%06d", $user_id);
            $self->app->log->debug("user_file: $user_file");
            my $file_base_dir = $basepath .'/avatar/'.$user_file;
            my $file_dir = $self->app->static->paths->[0] . $file_base_dir;
            $self->helperCreatePath($file_dir);

            my $file_name = $self->helperFileUploadGetFileId() . ".jpg";
            my $full_file_name = $file_dir."/".$file_name;

            $file->move_to($full_file_name);
            $self->helperImageCreateThumbanail($file_name, $file_dir);

            $res = $self->dbadmin->update_avatar($user_id, $file_base_dir.'/'.$file_name);
        } # END defined file
    } # END defined rpid & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Profile ERROR in update user");
        $res = 0;
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

sub put_password {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Profile sub put_password");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $params = $self->req->body_params->to_hash; # post
    my $user_id = $self->req->body_params->param('mod-pwd-id'); # post
    my $new_password = $self->req->body_params->param('mod-password'); # post

    my $res = $self->dbmain->edit_password($user_id, $new_password);

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

=head1 profile

Render della pagina di gestione del profilo.

Argomenti:  /

Return:     /

=cut

=head1 get_user_byid

Recupero dei dati di un determinato utente.

Argomenti:  * id dell'utente ('user_id') dalla SESSION;

Return:     json contenente i dati dell'utente.

=cut

=head1 put_user

Modifica delle informazioni relative all'utente.

Argomenti:  * dati dell'utente da modificare da AJAX;

           * id dell'utente ('user_id') dalla SESSION;

                - se definito: UPDATE;

                - se non definito: ERROR;

Return:     json contenente 1 o 0:

                - 1: OK;

                - 0: ERROR;

=cut

=head1 put_password

Modifica della password di un determinato utente.

Argomenti:  * id dell'utente ('user_id') dalla SESSION

           * nuova password scelta ('new_password') da AJAX;

Return:     json contenente 1 o 0:

                - 1: OK;

                - 0: ERROR;

=cut