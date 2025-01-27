package Bobo::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Mojo::JSON qw(decode_json encode_json);

# redirect to login page
sub login {
    my $self = shift;

    # if access denied or first log
    # after login, if defined redirect to login_redirect_path else to root
    my $login_redirect_path = $self->flash('login_redirect_path') || '/';
    $self->flash(login_redirect_path => $login_redirect_path);
    # -------------------------------------------------------
    # render login form
    # -------------------------------------------------------
    my $template = 'auth/'.$self->config->{login_page};
    $self->render(template => $template);
}

# post login stuff
sub get_login {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub get_login");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $params = $self->req->body_params->to_hash; # POST
    my $usermail = $self->req->body_params->param('login_mail');     # post
    my $password = $self->req->body_params->param('login_password'); # post

    my $headers = $self->req->headers->to_hash;
    delete(%{$headers}{'Cookie'});

    # -------------------------------------------------------
    # authenticate
    # -------------------------------------------------------
    # call functions "load_user" and "validate_user" (plugin Authentication) declared in Bobo.pm
    my $authenticate = $self->authenticate($usermail, $password);
    my $user = $self->dbmain->get_user_byid( $self->session('it.ecometer.bobo') );
    # https://docs.mojolicious.org/Mojolicious/Controller#session
    $self->session(expiration => $user->{'user_expiration_time'});

    my $login_redirect_path;

    #redirect to primo_login in order to change the password
    if ($user->{'user_first_log'}) {
        $login_redirect_path = 'primo_login';
    }
    # if password expired redirect to password.html in order to change the password
    elsif ($user->{'user_pwd_expired'}) {
        $login_redirect_path = 'password';
    }
    else {
        # after login, if defined redirect to login_redirect_path else to root
        $login_redirect_path = $self->flash('login_redirect_path') || '/';
    }

    # if not authenticated we must redefine the flash "login_redirect_path" variable for the next login
    # redirect to login form
    unless ($authenticate) {
        # log
        $self->helperInsertAccessLog( encode_json($headers), $usermail, 'error');
        $self->flash(login_redirect_path =>  $login_redirect_path);
        $self->flash(error_msg => "Errore: email e/o password errati.");
        $self->redirect_to( '/login' ) and return 0;
    }

    # log
    $self->helperInsertAccessLog(encode_json($headers), $usermail, 'success');

    # -------------------------------------------------------
    # redirect
    # -------------------------------------------------------
    # redirect to "login_redirect_path"
    $self->redirect_to($login_redirect_path) and return 1;
}

sub password {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub password");

    my $user = $self->dbmain->get_user_byid( $self->session('it.ecometer.bobo') );
    $self->stash(user => $user);

    # -------------------------------------------------------
    # render primo login form
    # -------------------------------------------------------
    $self->render(template => 'auth/password');
}

sub primo_login {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub primo_login");

    my $user = $self->dbmain->get_user_byid( $self->session('it.ecometer.bobo') );
    $self->stash(user => $user);

    # -------------------------------------------------------
    # render primo login form
    # -------------------------------------------------------
    $self->render(template => 'auth/primo_login');
}

sub recover_password {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub get_password");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $params = $self->req->body_params->to_hash; # post
    my $recover_email = $self->req->body_params->param('recover_email'); # post

    my $user = $self->dbmain->get_user_bymail($recover_email);

    #redirect to login if user never logged before
    if ($user->{'user_first_log'}) {
        # in case of any error, return 0 and error_msg
        $self->flash(error_msg => "Per recuperare la password devi aver eseguito almeno una volta con successo il login al portale");
        $self->redirect_to('/login') and return 0;
    }

    # update returning new password
    my $new_pwd = $self->dbmain->recover_password($recover_email);

    # insert into db to sending email with new password
    if (defined $new_pwd) {
        $self->app->log->debug("Password changed: insert into db to sending email");

        my @email_recipients;
        push @email_recipients, $recover_email;

        my $email_title = $user->{'portal_footer_text'};
        my $email_subject = '[NO REPLY] Nuove credenziali di accesso';
        my $email_body ='<p>Gentile Utente,<br>';
        $email_body .= 'A seguito della richiesta da Lei inoltrata, Le abbiamo inviato le nuove credenziali di accesso.</p>';
        $email_body .= '<p>Al primo login Le verr&agrave; richiesto di modificare la password.</p>';
        $email_body .= '<p>Nuova password: <strong>'.$new_pwd. '</strong></p>';
        $email_body .= '<p>Cordiali saluti</p>';

        my $email_logo = $self->config->{logo_mail};

        # sending email with the new password
        if ($self->helperSendEmailHTML($email_title, $email_subject , $email_body, $email_logo, @email_recipients)) {
            $self->flash(recover_msg => "A breve riceverai una mail con la nuova password. Se non dovessi riceverla, contatta software\@ecometer.it");
            $self->redirect_to( '/login' ) and return 1;
        }

    }

    # in case of any error, return 0 and error_msg
    $self->flash(error_msg => "Si è verificato un errore durante l'inoltro della richiesta.");
    $self->redirect_to('/login') and return 0;
}

sub edit_password {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub edit_password");

    # -------------------------------------------------------
    # get post data
    # -------------------------------------------------------
    my $params = $self->req->body_params->to_hash; # post
    my $new_password = $self->req->body_params->param('new_password'); # post

    my $user_id = $self->session('it.ecometer.bobo');

    # check if new password is equal to old one
    my $check = $self->dbmain->check_password($user_id, $new_password);
    # if true then return warning else update it
    # it can be true only in case of password expired, otherwise (recover password) is always false
    if ($check == 1) {
        $self->app->log->debug("Nuova password uguale alla vecchia");
        # -------------------------------------------------------
        # redirect
        # -------------------------------------------------------
        $self->flash(pwd_warn => "La nuova password non può essere uguale a quella corrente: modificarla");
        # redirect to "password"
        $self->redirect_to( '/password' ) and return 0;
    }
    else {
        # if success, redirect to home
        if ($self->dbmain->edit_password($user_id, $new_password)) {
            $self->app->log->debug("Password cambiata con successo");
            # -------------------------------------------------------
            # redirect
            # -------------------------------------------------------
            # redirect to /
            $self->redirect_to( '/' ) and return 1;
        }
        else { # redirect to primo_login
            $self->app->log->debug("Errore nel cambio password");
            # -------------------------------------------------------
            # redirect
            # -------------------------------------------------------
            $self->flash(pwd_error => "Errore: la password non è stata cambiata.");
            # redirect to "primo_login"
            $self->redirect_to( '/primo_login' ) and return 0;
        }
    }
}

# logout
sub delete {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub delete");

    # -------------------------------------------------------
    # log
    # -------------------------------------------------------
    # $self->dbmain->log_authentications( 0, $self->session('it.ecometer.bobo') );

    # -------------------------------------------------------
    # logout
    # -------------------------------------------------------
    # plugin Authentication function
    $self->logout();

    # -------------------------------------------------------
    # redirect
    # -------------------------------------------------------
    $self->redirect_to('/login') and return 0;
}

# every routes has to be checked
sub check {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub check");

    # is_user_authenticated() returns true
    # if current_user() returns some valid object, false otherwise.
    # current_user() returns the user object
    # as it was returned from the supplied load_user subroutine ref.

    # -------------------------------------------------------
    # $self->redirect_to('/login') and return 0 unless($self->is_user_authenticated);
    # -------------------------------------------------------
    # unless ($self->is_user_authenticated) {
    unless ($self->session('it.ecometer.bobo')) {
        $self->flash(error_msg => "Errore: utente e/o password errati.");
        $self->redirect_to('/login') and return 0;
    }
    else {
        return 1;
    }
};

sub wrong_request {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Auth sub wrong_request");

    # render json
    $self->render(text => 'Route non trovata'); # 400 Bad Request
};

1;

=head1 login

Redirect alla pagina di login.

Argomenti:  /

Return:     /

=cut

=head1 get_login

Funzione che effettua il login nel portale.

Argomenti:  * usermail ('login_mail') da AJAX;

           * password ('login_password') da AJAX;

Return:     Redirect alla homepage o, se primo login, alla pagina di cambio password.

=cut

=head1 password

Render della pagina html di modifica della password scaduta.

Argomenti:  /

Return:     /

=cut

=head1 primo_login

Render della pagina html del primo login.

Argomenti:  /

Return:     /

=cut

=head1 recover_password

Funzione per recupero della password. Verra' generata una nuova password

e inviata per email all'utente.

Argomenti:  * recover_email ('recover_email')  da AJAX;

Return:     Se OK, invio della mail con la nuova password e redirect alla

        pagina di login.

=cut

=head1 edit_password

Funzione per modifica della password.

Argomenti:  * new_password ('new_password')  da AJAX;

Return:     Se OK, password modificata e redirect alla homepage.

        Se KO, password non modificata e redirect alla pagina di primo login.

=cut

=head1 delete

Funzione per il logout.

Argomenti:  /

Return:     /

=cut

=head1 check

Funzione di verifica dell'autenticazione per ogni route.

Argomenti:  /

Return:     Se OK, autenticazione confermata.

        Se KO, redirect alla pagina di login.

=cut

=head1 wrong_request

Funzione che identifica una richiesta errata.

Argomenti:  /

Return:     Testo "Route non trovata" (400 Bad Request)

=cut