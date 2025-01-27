package Bobo::Controller::Qatarature;
use Mojo::Base 'Mojolicious::Controller';

use File::Basename;
use Data::Dumper;
use Mojo::File 'path';
use Mojo::JSON qw(decode_json encode_json);
use Unicode::UTF8 qw[decode_utf8 encode_utf8];
use Sys::Hostname;

sub qa_tarature {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature");

    # get the menu with active element based on the current route
    $self->helperGetMenusStash();

    my $user_id = $self->session('it.ecometer.bobo');

    # get networks
    my $networks = $self->dbcommon->get_all_networks($user_id);
    $self->stash(networks => $networks);

    # get provinces
    my $provinces = $self->dbcommon->get_provinces($user_id);
    $self->stash(provinces => $provinces);

    # get categories
    my $categories = $self->dbcommon->get_equipments_categories();
    $self->stash(categories => $categories);

    # get reasons
    my $reasons = $self->dbqatarature->get_reasons();
    $self->stash(reasons => $reasons);

    # get calibrators O3
    my $calibrators = $self->dbqatarature->get_calibrators($user_id);
    $self->stash(calibrators => $calibrators);

    # Render template "report/qa_tarature.html.ep" with message
    $self->render('report/qa_tarature');
}

sub get_metadata {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_metadata");

    my $user_id = $self->session('it.ecometer.bobo');

    my $stid = $self->param('stid'); # post
    my $cat = $self->param('cat'); # post
    my $dt = $self->param('dt'); # post

    $self->app->log->debug("ID stazione: $stid");
    $self->app->log->debug("ID categoria: $cat");
    $self->app->log->debug("Data e ora: $dt");

    # get stations from province
    my $cylinders = $self->dbqatarature->get_cylinders_by_category($user_id, $stid, $cat, $dt);
    my $methods = $self->dbqatarature->get_methods_by_category($cat);

    my $json;
    if (defined $cylinders && defined $methods) {
        $json = {
            res => "OK",
            cylinders => $cylinders,
            methods => $methods
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

sub get_reports {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_reports");

    my $from = $self->param('from'); # post
    my $to = $self->param('to'); # post
    my $net = $self->param('net'); # post
    my $prid = $self->param('prid'); # post
    my $stid = $self->param('stid'); # post
    my $catid = $self->param('catid'); # post

    $self->app->log->debug("From: $from - To: $to");
    $self->app->log->debug("ID province: $prid");
    $self->app->log->debug("ID station: $stid");
    $self->app->log->debug("ID category: $catid");

    my $user_id = $self->session('it.ecometer.bobo');
    my $reports;

    if ($stid == -1) {
        # get report
        $reports = $self->dbqatarature->get_reports_by_date_province($user_id, $from, $to, $net, $prid, $catid);
    }
    else {
        $reports = $self->dbqatarature->get_reports_by_date_station($user_id, $from, $to, $stid, $catid);
    }

    my $json;
    if (defined $reports) {
        $json = {
            res => "OK",
            reports => $reports
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

sub get_selected_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_selected_report");

    my $rpid = $self->param('id'); # post

    $self->app->log->debug("ID report: $rpid");

    # get report
    my $report = $self->dbqatarature->get_report_by_id($rpid);

    # 'Analizzatore SO2' -> 1
    # 'Analizzatore NOx' -> 2
    # 'Analizzatore CO'  -> 3
    # 'Analizzatore O3'  -> 4
    # 'Analizzatore BTX' -> 5
    # 'Analizzatore IPA' -> 6
    # 'Analizzatore CH4' -> 7
    my $json;
    if (defined $report) {
        my $rep_obj = decode_json($report->{'calib_values'});
        my ($tank_zero, $tank_span);
        my ($method_zero, $method_span);
        my $calibrator;

        my $default_tank = {
            cylinder_arpa_id => '--',
            cylinder_fullname => '--',
            cylinder_ch_values => []
        };

        if ($report->{'category_id'} == 1) {
            $tank_zero = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-zero-so2'});
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-so2'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-so2'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-so2'});
        }
        elsif ($report->{'category_id'} == 2) {
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-noxnono2'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-noxnono2'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-noxnono2'});
        }
        elsif ($report->{'category_id'} == 3) {
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-co'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-co'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-co'});
        }
        elsif ($report->{'category_id'} == 4) {
            # $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-o3'});
            $calibrator = $self->dbqatarature->get_calibrator_by_id($rep_obj->{'calib-span-o3'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-o3'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-o3'});
        }
        elsif ($report->{'category_id'} == 5) {
            $tank_zero = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-zero-btx'});
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-btx'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-btx'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-btx'});
        }
        elsif ($report->{'category_id'} == 7 || $report->{'category_id'} == 25) {
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-ch4'});
            $method_zero = $self->dbqatarature->get_method_by_id($rep_obj->{'method-zero-ch4'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-ch4'});
        }
        elsif ($report->{'category_id'} == 14 || $report->{'category_id'} == 15 || $report->{'category_id'} == 18) {
            $tank_span = $self->dbqatarature->get_cylinder_by_id($rep_obj->{'tank-span-aerosol'});
            $method_span = $self->dbqatarature->get_method_by_id($rep_obj->{'method-span-aerosol'});
        }

        $json = {
            res => "OK",
            report => $report,
            tank_zero => defined $tank_zero ? $tank_zero : $default_tank,
            tank_span => defined $tank_span ? $tank_span : $default_tank,
            method_zero => defined $method_zero ? $method_zero->{'method_name'} : '--',
            method_span => defined $method_span ? $method_span->{'method_name'} : '--',
            calibrator => $calibrator
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
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_pdf");

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
                my $filename = "report-taratura-".$rpid_file.".pdf";
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
        my $download_path = $self->app->static->paths->[0].'/downloads/report/qa_tarature';
        $self->app->log->debug("Download path: $download_path");

        my $rpid_file = sprintf("%06d", $rpid);

        # get PDF filename
        $self->app->log->debug("File PDF");
        my $pdf_filename = "report-taratura-".$rpid_file.".pdf";

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

sub get_total_pdf {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub get_total_pdf");

    my $params = $self->req->query_params->to_hash;
    $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # get dates
    my $from = $params->{'from'}; # post
    my $to = $params->{'to'}; # post
    my $net = $params->{'net'}; # post
    my $stid = $params->{'stid'}; # post

    if ($^O eq 'linux') {
        # choose by host
        my $host = hostname;
        if ($host eq 'opas-http') {
            # system
            eval {
                # create remote report
                $self->app->log->debug("[SSH] Lancio script creazione pdf via ssh");
                my $tof = $to;
                $tof =~ tr/ /T/;
                my $cmd = 'ls';
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Ssh failed: $!");
                $self->app->log->debug("Fine script creazione pdf");

                # get remote report
                $self->app->log->debug("[SCP] Copia file remoto in locale");

                $from =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
                my $from_format = "$1$2$3";
                $to =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)$/;
                my $to_format = "$1$2$3";
                my $filename = "report-taratura-{".$user_id.$net."}-".$from_format."-".$to_format.".pdf";
                my $remotefile = 'PATH/'.$filename;
                my $dest_path = 'PATH';
                $cmd = "ls";
                $self->app->log->debug($cmd);
                system($cmd) or $self->app->log->warn("Scp failed: $!");
                $self->app->log->debug("Fine copia");
            };
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
        my $download_path = $self->app->static->paths->[0].'/downloads/report/qa_tarature';
        $self->app->log->debug("Download path: $download_path");

        $from =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
        my $from_format = "$1$2$3";

        $to =~ m/^(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)$/;
        my $to_format = "$1$2$3";

        # get PDF filename
        $self->app->log->debug("File PDF");
        # report-taratura-4-1-YYYYMMDD-YYYYMMDD.pdf;
        my $pdf_filename = "report-taratura-{".$user_id.$net."}-".$from_format."-".$to_format.".pdf";

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
    $self->app->log->debug("Bobo::Controller::Qatarature sub put_report");

    # dump post data (with user infos)
    $self->helperDumperPostData('Tarature', 'put_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash;
    $self->helperDumper($params);

    my $user_id = $self->session('it.ecometer.bobo');

    # store request to audit table
    my $table = 'rep_qacalibrations';

    # get params from ajax
    my $res = 1;
    my $rpid = $params->{'report-caid'};

    # if rpid defined -> edit report
    if (defined $rpid && $rpid ne "") {
        $self->app->log->debug("Bobo::Controller::Qatarature edit of report");
        $self->helperInsertUserLog('UPDATE', $table, encode_json($params));

        $res = $self->dbqatarature->update_report($params);
    }
    else { # else -> insert new report
        $self->app->log->debug("Bobo::Controller::Qatarature insert of new report");
        $self->helperInsertUserLog('INSERT', $table, encode_json($params));

        $rpid = $self->dbqatarature->insert_report($user_id, $params);
    }

    # Caricamento FILES sia per INSERT che per UPDATE
    my $files = $self->req->uploads('files');

    $self->app->log->debug("RES = $res");

    if (defined $rpid && $res) {
        if (scalar @{$files} > 0) {
            my $rpid_file = sprintf("%09d", $rpid);
            $self->app->log->debug("rpid_file: $rpid_file");
            my $file_base_dir = 'uploads/report/qa_tarature/'.$rpid_file;
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

                my $file_name = $self->helperFileUploadGetFileId().$p_ext;
                my $full_file_name = $file_dir."/".$file_name;

                $file->move_to($full_file_name);

                $res = $self->dbqatarature->insert_new_attachment($rpid, $original_name, $file_name, $is_image);
            }
        } # END array files > 0
    } # END defined rpid & res = TRUE
    else {
        $self->app->log->debug("Bobo::Controller::Qatarature ERROR in insert or update report");
        $res = 0;
    }

    $self->app->log->debug("RES = $res");

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

sub del_report {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub del_report");
    $self->helperDumperPostData('Tarature', 'del_report', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $report_id = $self->param('id'); # post

    $self->app->log->debug("Report id: $report_id");

    # store action to audit table
    my $table = 'rep_qacalibrations';
    $self->helperInsertUserLog('DELETE', $table, encode_json($params));

    # check if already associated to report manutenzione
    if ($self->dbqatarature->check_if_associated($report_id) > 0) {
        $self->render(json => -1);
    }
    else {
        my $res = $self->dbqatarature->delete_report_by_id($report_id);

        if ($res == 1) {
            $self->render(json => 1);
        }
        else {
            $self->render(json => 0);
        }
    }
}

sub del_selected_attachment {
    my $self = shift;

    # log
    $self->app->log->debug("Bobo::Controller::Qatarature sub del_selected_attachment");
    $self->helperDumperPostData('Qatarature', 'del_selected_attachment', $self->req->body_params);

    my $params = $self->req->body_params->to_hash; # for audit
    my $attach_id = $self->param('id'); # post

    $self->app->log->debug("Attachment id: $attach_id");

    my $json;

    # store action to audit table
    my $table = 'rep_damages';
    # $self->helperInsertUserLog('DELETE ATT.', $table, encode_json($params));

    if ($self->dbqatarature->delete_attachment_by_id($attach_id)) {
        $json = {
            res => "OK",
            message => "Attachment successfully removed!",
        };
    }
    else {
        $json = {
            res => "ERR",
            message => "An error has occurred; retry later!",
        };
    }

    # render
    $self->render(json => $json);
}

1;

=head1 qa_tarature

Render della pagina di visualizzazione dei report taratura.

Argomenti:  /

Return:     /

=cut

=head1 get_metadata

Funzione per recuperare i metadati (bombole e metodi).

Argomenti:  * id dell'utente ('user_id');

           * id della stazione ('stid');

           * id della categoria di strumento ('cat');

           * data e ora della taratura ('dt');

Return:     json contenente la risposta "OK" e i metadati (bombole e metodi), oppure solamente la risposta "ERR".

=cut

=head1 get_reports

Funzione per recuperare tutti i report taratura disponibili in un determinato periodo temporale.

Argomenti:  * data d'inizio ('from');

           * data di fine ('to');

           * id della rete, se presente ('net');

           * id della provincia, se presente ('prid');

           * id della stazione, se presente ('stid');

           * id della categoria di strumento, se presente ('catid');

           * id dell'utente ('user_id');

Return:     json contenente la risposta "OK" e i report, oppure solamente la risposta "ERR".

=cut

=head1 get_selected_report

Funzione per recuperare, dato l'id, le informazioni di una determinata taratura.

Argomenti:  * id del report ('id');

Return:     json contenente, se presenti, la risposta "OK" e i vari campi del report selezionato,
oppure solamente la risposta "ERR".

=cut

=head1 get_pdf

Funzione che effettua, dato l'id, il download del pdf di una determinata taratura.

Argomenti:  * id del report ('rpid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut

=head1 get_total_pdf

Funzione che effettua il download del pdf totale di tutte le tarature di una determinata rete
in un determinato periodo temporale ed, eventualmente, di una determinata stazione.

Argomenti:  * id dell'utente ('user_id');

           * data d'inizio ('from');

           * data di fine ('to');

           * id della rete ('net');

           * id della stazione, se presente ('stid');

Return:     download del pdf, oppure json contenente la risposta "ERR" e un messaggio di errore.

=cut


=head1 put_report

Funzione per inserire/modificare un determinato report.

Argomenti:  * oggetto contenente le informazioni della taratura da inserire/modificare ('params');

           * id dell'utente ('user_id');

           * id del report; se presente: UPDATE ('report-caid');

Return:     json contenente 1 o 0:

            - 1: OK;

            - 0: ERROR;

=cut

=head1 del_report

Funzione per eliminare, dato l'id, una determinata taratura.

Argomenti:  * id del report ('id');

Return:     json contenente 1 o 0 o -1 (se associato ad un report manutenzione):

            - 1: OK;

            - 0: ERROR;

            - -1: Gia' associato ad un report manutenzione;

=cut

=head1 del_selected_attachment

Funzione per eliminare, dato l'id, un determinato allegato.

Argomenti:  * id dell'allegato ('id');

Return:     json contenente la risposta "OK" e un messaggio di avvenuta eliminazione,
oppure la risposta "ERR" e un messaggio di errore.

=cut