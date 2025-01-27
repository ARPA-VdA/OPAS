package Bobo::Controller::Demo;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Scalar::Util qw(looks_like_number);

# This action will render a template
sub demo {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Demo");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $userid = $self->session('it.ecometer.bobo');

    # Render template with message
    $self->render('demo');
}

1;

=head1 demo

Render della pagina "Demo".

Argomenti:  /

Return:     /

=cut
