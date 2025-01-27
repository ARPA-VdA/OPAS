package Bobo::Controller::Qasopralluoghi;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;

use File::Basename;
use Mojo::File 'path';
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Sys::Hostname;

sub qa_sopralluoghi {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get provinces
    my $provinces = $self->dbcommon->get_italy_provinces();
    $self->stash(provinces => $provinces);

    # get users
    my $users = $self->dbcommon->get_portal_users_by_user($user_id);
    $self->stash(users => $users);

    # Render template "report/qa_sopralluoghi.html.ep" with message
    $self->render('report/qa_sopralluoghi');
}

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub get_reports");

    my $userid = $self->session('it.ecometer.bobo');
    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $prov = $self->param('prov'); # post
    $self->app->log->debug("Data inizio: $from, data fine: $to");

    # get reports from dateFrom to dateTo
    my $reports = $self->dbqasopralluoghi->get_reports_by_dates($userid, $from, $to, $prov);

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
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub get_selected_report");

    my $rpid = $self->param('id'); # post

    $self->app->log->debug("ID report: $rpid");

    # get report
    my $report = $self->dbqasopralluoghi->get_report_by_id($rpid);

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
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub get_pdf");

    my $params = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    # get dates
    my $rpid = $params->{'rpid'}; # post

    $self->app->log->debug("PDF del report: $rpid");

    if ($^O eq 'linux') {
        # choose by host
        my $host = hostname;
        if ($host eq 'opas-http') {
            # system
            eval{
                # create remote report
                $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
                my $cmd = 'ls';
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Ssh failed: $!");
                $self->app->log->debug("Fine script creazione pdf");

                # get remote report
                $self->app->log->debug("[SCP] Copia file remoto in locale");
                my $rpid_file = sprintf("%06d", $rpid);
                my $filename = "report-sopralluoghi-".$rpid_file.".pdf";
                my $remotefile = 'PATH/'.$filename;
                my $dest_path = 'PATH';
                system("ls") or $self->app->log->warn("Scp failed: $!");
                $self->app->log->debug("Fine copia");
            };

            #     $self->app->log->debug("Check system result: $res");
            #     if ($@ || $res != 0) {
            #         $self->app->log->error("Errore esecuzione script ssh");
            #         $json = {
            #             res  => 'ERROR',
            #             desc => 'Errore durante la creazione del report pdf.'
            #         };
            #     }
            #     else {
            #         $self->app->log->debug("updating db ...");
            #         $self->dbbolmonthly->insert_publish_bull_byid( $userid, $rpid );
            #         $json = {
            #             res  => 'OK',
            #             desc => 'Report creato correttamente.'
            #         };
            #     }

        }
        else {
            $self->app->log->debug("Lancio script creazione pdf");
            system('ls');
            $self->app->log->debug("Fine script creazione pdf");
        }
    }

    my $json;

    $self->app->log->debug("check system result");
    $self->app->log->debug($?);
    if ($? == -1) { # errore if ($? == -1) {
        $self->app->log->debug("command failed: $!");

        $json = {
            res => 'ERROR',
            desc => 'Errore durante la creazione del pdf',
            id => 0
        };

        # final render
        $self->render(json => $json);

    }
    else { # comando andato a buon fine
        $self->app->log->debug('Pdf creato correttamente');
        $self->app->log->debug("Inizio recupero dati");

        # get application download path .../public/ path
        my $download_path = $self->app->static->paths->[0].'/downloads/report/qa_sopralluoghi';
        $self->app->log->debug("Download path: $download_path");

        my $rpid_file = sprintf("%06d", $rpid);

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "report-sopralluoghi-".$rpid_file.".pdf";

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
                'format' => 'pdf', # will change Content-Type "application/x-download" to "application/pdf"
                'content_disposition' => 'attachment', # will change Content-Disposition from "attachment" to "inline"
                'cleanup' => 0 # delete file after completed

                # inline               - is for showing file inline
                # attachment (default) - is for downloading
            );
        }
        else {
            $self->app->log->error("Error. PDF file DOES NOT exists!");

            $json = {
                res => 'ERROR',
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
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub put_report");

    # dump post data (with user infos)
    $self->helperDumperPostData('Qasopralluoghi', 'put_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $userid = $self->session('it.ecometer.bobo');

    # get params from ajax
    my $res = 1;
    my $rpid = $params->{'survey-id'};

    # if rpid defined -> edit report
    if (defined $rpid && $rpid ne "") {
        $self->app->log->debug("Bobo::Controller::Qasopralluoghi edit of report");

        $res = $self->dbqasopralluoghi->update_report($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Qasopralluoghi insert of new report");

        $rpid = $self->dbqasopralluoghi->insert_report($userid, $params);
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    if (defined $rpid && $res) {
        if (scalar @{$files} > 0) {
            my $rpid_file = sprintf("%09d", $rpid);
            $self->app->log->debug("rpid_file: $rpid_file");
            my $file_base_dir = 'uploads/report/qa_sopralluoghi/'.$rpid_file;
            my $file_dir = $self->app->static->paths->[0].'/'.$file_base_dir;
            $self->helperCreatePath($file_dir);

            for my $file (@{$files}) {
                # $self->helperDumper($file);
                $self->app->log->debug($file->headers->content_type);
                my $content_type = $file->headers->content_type;
                my $is_image = 0;
                if ($content_type =~ m/image\//) {
                    $self->app->log->debug("Is image");
                    $is_image = 1;
                }

                my $original_name = $file->filename;
                $self->app->log->debug("original_name: $original_name");
                my ($fp_name,$p_path,$p_ext) = fileparse($original_name, qr"\..[^.]*$");

                my $file_name = $self->helperFileUploadGetFileId() . $p_ext;
                my $full_file_name = $file_dir."/".$file_name;

                $file->move_to($full_file_name);

                $res = $self->dbqasopralluoghi->insert_new_attachment($rpid, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    } # END defined rpid & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Qasopralluoghi ERROR in insert or update report");
        $res = 0;
    }

    if ($res == 1) {
        $self->app->log->debug('Result: OK');
        $self->render(json => 1);
    }
    else {
        $self->app->log->debug('Result: ERROR');
        $self->render(json => 0);
    }
}

sub del_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub del_selected_report");

    my $rpid = $self->param('id'); # post

    my $res = $self->dbqasopralluoghi->delete_report_by_id($rpid);

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

sub del_selected_attachment {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qasopralluoghi sub del_selected_attachment");
    $self->helperDumperPostData('Qasopralluoghi', 'del_selected_attachment', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $attach_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $attach_id");

    # store action to audit table
    # my $table = 'inspections';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbqasopralluoghi->delete_attachment_by_id($attach_id)) {
        $self->render(json => 1);
    }
    else {
        $self->render(json => 0);
    }
}

1;

=head1 qa_sopralluoghi

Render della pagina di visualizzazione dei report sopralluoghi.

Argomenti:  /

Return:     /

=cut

=head1 get_reports

Funzione per recuperare tutti i report sopralluoghi disponibili in un determinato periodo temporale.

Argomenti:  * id dell'utente ('userid');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della provincia ('prov');

Return:     json contenente la risposta "OK" e i report, oppure solamente la risposta "ERR".

=cut

=head1 get_selected_report

Funzione per recuperare, dato l'id, le informazioni di un determinato sopralluogo.

Argomenti:  * id del report ('id');

Return:     json contenente, se presenti, la risposta "OK" e i vari campi del report selezionato,
oppure solamente la risposta "ERR".

=cut

=head1 get_pdf

Funzione che effettua, dato l'id, il download del pdf di un determinato sopralluogo.

Argomenti:  * id del report ('rpid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut

=head1 put_report

Funzione per inserire/modificare un determinato report.

Argomenti:  * oggetto contenente le informazioni del sopralluogo da inserire/modificare ('params');

           * id dell'utente ('userid');

           * id del report; se presente: UPDATE ('rpid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_report

Funzione per eliminare, dato l'id, un determinato report.

Argomenti:  * id del report ('id');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_selected_attachment

Funzione per eliminare, dato l'id, un determinato allegato.

Argomenti:  * id dell'allegato ('id');

Return:     json contenente la risposta "OK" e un messaggio di avvenuta eliminazione,
oppure la risposta "ERR" e un messaggio di errore.

=cut