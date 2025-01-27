package Bobo::Controller::Verbali;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use Unicode::UTF8 qw[decode_utf8 encode_utf8];

sub verbali {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get compilers
    my $compilers = $self->dbverbali->get_compilers($user_id);
    $self->stash(compilers => $compilers);

    # Render template "report/verbali.html.ep" with message
    $self->render('report/verbali');
}

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali sub get_reports");

    my $userid = $self->session('it.ecometer.bobo');
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $prov = $self->param('prov'); # post
    $self->app->log->debug("Data inizio: $from, data fine: $to");

    # get reports from dateFrom to dateTo
    my $reports = $self->dbverbali->get_reports_by_dates($userid, $from, $to, $prov);

    my $json = {
        res => "OK",
        reports => $reports
    };

    # render
    $self->render(json => $json);
}

sub get_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali sub get_selected_report");

    my $rpid = $self->param('id'); # post
    $self->app->log->debug("ID report: $rpid");

    # get report
    my $report = $self->dbverbali->get_report_by_id($rpid);

    my $json;
    if (defined $report) {
        $json = {
            res => "OK",
            report => $report
        };
    }
    else {
        $json = {
            res => "ERR"
        };
    }

    # render
    $self->render(json => $json);
}

sub get_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali sub get_pdf");

    my $params  = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    # get dates
    my $rpid = $params->{'rpid'}; # post

    $self->app->log->debug("PDF del report: $rpid");

    if ($^O eq 'linux') {
        eval {
            # create remote report
            $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
            my $cmd = 'ls';
            $self->app->log->debug($cmd);
            system($cmd) or $self->app->log->warn("Ssh failed: $!");
            $self->app->log->debug("Fine script creazione pdf");

            # get remote report
            $self->app->log->debug("[SCP] Copia file remoto in locale");
            my $rpid_file = sprintf("%06d", $rpid);
            my $filename = "verbale-".$rpid_file.".pdf";
            my $remotefile = 'PATH/'.$filename;
            my $dest_path = 'PATH';
            system("ls") or $self->app->log->warn("Scp failed: $!");
            $self->app->log->debug("Fine copia");
        };
    }

    $self->app->log->debug("check system result");
    $self->app->log->debug($?);
    my $json;

    if ($? == -1) { # errore if ($? == -1) {
        $self->app->log->debug("command failed: $!");

        $json = {
            res  => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id   => 0
        };

        # final render
        $self->render(json => $json);

    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/report/verbali';
        $self->app->log->debug("Download path: $download_path");

        my $rpid_file = sprintf("%06d", $rpid);

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "verbale-".$rpid_file.".pdf";

        # get full zip filename
        my $full_pdf_filename = $download_path.'/'.$pdf_filename;
        # log
        $self->app->log->debug("PDF filename: $full_pdf_filename");

        # last check
        if (-e $full_pdf_filename) {
            # encode filename to support "à"
            $pdf_filename = encode_utf8($pdf_filename);

            # downloadPdfFile | render_file
            $self->render_file(
                'filepath' => $full_pdf_filename,
                'filename' => $pdf_filename,
                'format'   => 'pdf',                   # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0                         # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );
        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            $json = {
                res  => 'ERROR',
                desc => "Errore durante lo scarico del bollettino."
            };

            # final render
            $self->render(json => $json);
        }
    }
}

sub put_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali sub put_report");

    # dump post data (with user infos)
    $self->helperDumperPostData('Verbali', 'put_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $userid = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $res = 1;
    my $rpid = $params->{'report-id'};

    # if rpid defined -> edit report
    if (defined $rpid && $rpid ne "") {

        $self->app->log->debug("Bobo::Controller::Verbali edit of report");

        $res = $self->dbverbali->update_report($params);
    }
    else { # else -> insert new report

        $self->app->log->debug("Bobo::Controller::Verbali insert of new report");

        $rpid = $self->dbverbali->insert_report($userid, $params);
    }

    if (defined $rpid && $res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1)
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0)
    }
}

sub del_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Verbali sub del_selected_report");

    my $rpid = $self->param('id'); # post

    my $res = $self->dbverbali->delete_report($rpid);

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

1;

=head1 verbali

Render della pagina di visualizzazione dei verbali.

Argomenti:  /

Return:     /

=cut

=head1 get_reports

Funzione per recuperare tutti i report verbali disponibili in un determinato periodo temporale.

Argomenti:  * id dell'utente ('userid');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia, se presente ('prov');

Return:     json contenente la risposta "OK" e i report.

=cut

=head1 get_selected_report

Funzione per recuperare, dato l'id, le informazioni di un determinato verbale.

Argomenti:  * id del report ('id');

Return:     json contenente, se presenti, la risposta "OK" e il report, oppure solamente la risposta "ERR".

=cut

=head1 get_pdf

Funzione che effettua, dato l'id, il download del pdf di un determinato verbale.

Argomenti:  * id del report ('rpid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut

=head1 put_report

Funzione per inserire/modificare un determinato report.

Argomenti:  * oggetto contenente le informazioni del verbale da inserire/modificare ('params');

           * id del report; se presente: UPDATE ('report-id');

           * id dell'utente ('userid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_report

Funzione per eliminare, dato l'id, un determinato verbale.

Argomenti:  * id del report ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut