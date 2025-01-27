package Bobo::Plugin::Menus;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(decode_json);
use Encode qw(encode_utf8);
use Time::Moment;
use Data::Dumper;

sub register {
    my ( $self, $app ) = @_;

    # log debug message
    $app->log->debug('Bobo::Plugin::Menus sub register()');

    # -----------------------------------------------------------------------------
    # -- helperGetHomepageStash
    # -----------------------------------------------------------------------------
    $app->helper(helperGetMenusStash => sub {
        my $self = shift;
        my $active_page = $self->req->url->to_abs->path;
        my $user_id = $self->session('it.ecometer.bobo');

        # $active_page =~ s/\/[0-9]+//s;
        $active_page =~ /(\/\w*)(\/.+)?/;
        $active_page = "$1";
        # log debug message
        $app->log->debug('Bobo::Plugin::Menus :: helperGetHomepageStash()');
        $app->log->debug('Active page: '.$active_page);

        # -------------------------------------------------------
        # user session
        # -------------------------------------------------------
        my $user = $self->dbmain->get_user_byid( $user_id );
        my $portal_favicon = '/bobo-icons';

        if (defined $user->{'portal_basepath'}){
            my $path = $self->app->home->rel_file("/public/".$user->{'portal_basepath'}."/favicon/");

            # check if exist specific portal favicons else default favicons
            my @img_files = File::Find::Rule->file()
                ->name( '*.png', '*.jpeg', '*.jpg' )
                ->in( $path );

            if (scalar @img_files > 0) {
                $portal_favicon = $img_files[0];
                $self->app->log->debug("$portal_favicon");
                if ($portal_favicon =~ /.*(favicon.*\.(jpg|png|jpeg))/) {
                    $portal_favicon = $user->{'portal_basepath'}."/favicon";
                }
            }
        }


        $self->stash( user => $user );
        $self->stash( portal_favicon => $portal_favicon );

        # -------------------------------------------------------
        # get main menu
        # -------------------------------------------------------
        my $sidebar_usermenu = $self->dbmain->get_sidebar_usermenu( $user_id, $active_page );
        # $self->app->log->debug(Dumper($sidebar_usermenu));
        $self->stash(sidebar_usermenu => $sidebar_usermenu);

        # -------------------------------------------------------
        # get shortcut menu html
        # -------------------------------------------------------
        my $sidebar_secondmenu = $self->dbmain->get_sidebar_secondmenu( $user_id );
        # $self->app->log->debug(Dumper($sidebar_secondmenu));
        $self->stash(sidebar_secondmenu => $sidebar_secondmenu);

        # -------------------------------------------------------
        # get user nav menu html
        # -------------------------------------------------------
        my $usernav = $self->dbmain->get_usernav( $user_id );
        # $self->app->log->debug(Dumper($usernav));
        $self->stash( usernav => $usernav );

        # -------------------------------------------------------
        # get notification nav
        # -------------------------------------------------------
        my $notesnav = $self->dbmain->get_notesnav( $user_id );
        # $self->app->log->debug(Dumper($notesnav));
        $self->stash(notesnav => $notesnav);

        if ($active_page eq '/') {
            $self->stash(breadcrumb => undef);
        }
        else {
            my $breadcrumb = $self->dbmain->get_breadcrumb( $user_id, $active_page );
            # $self->app->log->debug(Dumper($breadcrumb));
            $self->stash( breadcrumb => $breadcrumb );
        }

        # -------------------------------------------------------
        # get shortcuts icons
        # -------------------------------------------------------
        my $shortcuts = $self->dbmain->get_shortcuts( $user_id );
        # $self->app->log->debug(Dumper($notesnav));
        $self->stash( shortcuts => $shortcuts );

        return 1;
    });

    # -----------------------------------------------------------------------------
    # -- helperGetPortalPageOptions
    # -----------------------------------------------------------------------------
    $app->helper(helperGetPortalPageOptions => sub {
        my $self = shift;

        # log debug message
        $app->log->debug('Bobo::Plugin::Menus :: helperGetPortalPageOptions()');

        my $active_page = $self->req->url->to_abs->path;
        $active_page =~ /(\/\w*)(\/.+)?/;
        $active_page = "$1";

        my $user = $self->stash('user');
        $self->app->log->debug("$user");

        # -------------------------------------------------------
        # get page options based on the portal
        # -------------------------------------------------------
        my $page_options = $self->dbmain->get_portal_page_options( $user->{'portal_id'}, $active_page );
        # $self->app->log->debug(Dumper($sidebar_usermenu));
        $self->stash( page_options => decode_json(encode_utf8($page_options)) );

        return 1;
    });
}

1;

=head1 helperGetMenusStash

Funzione che renderizza loghi e menu del portale, in base
all'utente.

Argomenti:  * pagina visualizzata ('active_page');

           * id dell'utente ('user_id');

Return:     valore 1

=cut

=head1 helperGetPortalPageOptions

Funzione che recupera le opzioni della pagina attualmente attiva, in base al portale.

Argomenti:  * pagina visualizzata ('active_page');

           * oggetto contenente le informazioni relative all'utente ('user');

Return:     valore 1

=cut