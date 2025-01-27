#!/usr/bin/perl
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------
#
#   Script Name : report-taratura-date.pl
#        Author : Ecometer s.n.c.
#          Date : 2024-09-30
#
#   REPORT TARATURA CUMULATIVO
#       Perl script to generate report PDF
#
#   RUN EXAMPLE:
#       ($date_start)
#       ($date_end)
#       (station_network_type_id)
#       (station_id) -- eventuale
#       (user_id)
#
#       $ perl /var/www/bobo/public/report-taratura-date.pl 2022-01-01 2022-12-31 1 1000 16
#
#------------------------------------------------------------------------------
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# USE LIBS
#------------------------------------------------------------------------------
# enables the strict and warnings pragmas
# use Modern::Perl '2018';
use File::Spec::Functions qw(rel2abs);
use File::Basename;
use Getopt::Std;
use Fcntl qw(:flock);
use Log::Log4perl::Level;
use LaTeX::Encode 'latex_encode';
use experimental qw( switch );
use JSON;
use LWP::Simple;
use List::MoreUtils qw(firstidx);
use Encode qw( encode_utf8 );

#------------------------------------------------------------------------------
# NON-BLOCKING FLOCK
#------------------------------------------------------------------------------
open our $file, '<', $0 or die $!;
flock $file, LOCK_EX|LOCK_NB or die "Unable to lock file $!";

#------------------------------------------------------------------------------
# ARGUMENTS
#------------------------------------------------------------------------------
my $num_args = $#ARGV + 1;

#------------------------------------------------------------------------------
# SCRIPT SETTINGS
#------------------------------------------------------------------------------
my $title    = 'Reports';
my $location = 'Opas';
my $logfile  = 'report-taratura-date.log';
my $version  = '1.0';
my $script   = basename($0);
# absolute path
my $abs_path = dirname(rel2abs($0));

#------------------------------------------------------------------------------
# LOG HANDLER
#------------------------------------------------------------------------------
our $log;

#--------------------------------------------------------
# DATE TIME VARIABLES
#--------------------------------------------------------
our ($year,$month,$day,$hour,$min,$sec);

#------------------------------------------------------------------------------
# DATE TIME VARIABLES
#------------------------------------------------------------------------------
require "$abs_path/inc/library-v2.pl";
require "$abs_path/inc/library-dbh-v3.pl";
require "$abs_path/settings.pl";

#------------------------------------------------------------------------------
# START UP
#------------------------------------------------------------------------------
$log = set_logfile("$abs_path/log", $logfile);
$log->level($DEBUG); # one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL
# $log->trace("...");  # Log a trace message
# $log->debug("...");  # Log a debug message
# $log->info("...");   # Log a info message
# $log->warn("...");   # Log a warn message
# $log->error("...");  # Log a error message
# $log->fatal("...");  # Log a fatal message
startup($title, $location, $version);

#------------------------------------------------------------------------------
# CHECKING ARGUMENTS
#------------------------------------------------------------------------------
my $date_start;
my $date_end;
my $net;
my $station;
my $user_id;
if ($num_args == 5) {
    $date_start = $ARGV[0];
    $date_end = $ARGV[1];
    $net = $ARGV[2];
    $station = $ARGV[3];
    $user_id = $ARGV[4];
    # sanity check
    if($net == -1){
        $log->warn("No Network provided!");
        end();
        exit(1);
    }
} else {
    $log->warn("Wrong arguments provided {date1, date2, net, st, user}, sample: report-taratura-date.pl '2022-01-01 00:00:00' '2022-01-31 23:59:59' -1 -1 1");
    end();
    exit(1);
}
# log
$log->info("Data iniziale: $date_start");
$log->info("Data finale: $date_end");
$log->info("Rete: $net");
$log->info("Stazione: $station");
$log->info("User: $user_id");

#------------------------------------------------------------------------------
# TEX DIRECTORY
#------------------------------------------------------------------------------
my $working_path = $abs_path.'/tex_tmp';
createpath($working_path);

#------------------------------------------------------------------------------
# RANDOM STRING
#------------------------------------------------------------------------------
my $random_str = sprintf("%05X", rand(0xFFFFFFFF));

#------------------------------------------------------------------------------
# MAIN PATHS
#------------------------------------------------------------------------------
# my $pdf_export_path in settings.pl
my $tex_file_wrapper = $working_path.'/report_taratura_date_'.$random_str.'.tex';
my $tex_file_body = $working_path.'/taratura_date_'.$random_str.'.tex';
my $tex_file_headfoot = $working_path.'/header_footer_taratura_date_'.$random_str.'.tex';

#------------------------------------------------------------------------------
# CONNECT TO DATABASE
#------------------------------------------------------------------------------
dbh_connect($db_settings) or bail_out("Cannot connect to database !");

#------------------------------------------------------------------------------
# QUERY
#------------------------------------------------------------------------------
my $sql_cal = qq{
    SELECT
        vc.calib_id,
        vc.us_id,
        vc.user_fullname,
        vu.company_name,
        vc.station_id,
        vc.station_name,
        vsi.station_network_type_id,
        vsi.station_network_type_desc,
        vsi.station_network_type_logo,
        vsm.province_id,
        vsm.province_name,
        vc.instr_id,
        vc.instr_type_id,
        vit.instr_type_fullname,
        vit.category_id,
        vit.category_name,
        vit.instr_type_unit,
        vc.instr_arpa_id,
        COALESCE(vc.instr_serial_num, '--') AS instr_serial_num,
        vc.instr_name,
        vc.calib_fulldate,
        TO_CHAR(vc.calib_fulldate::date, 'DD/MM/YYYY') AS date,
        TO_CHAR(vc.calib_fulldate::time, 'HH24:MI') AS time_format,
        vc.calib_fulldate_formatted,
        vc.calib_re_id,
        vc.calib_reason,
        vc.calib_multipoint,
        CASE WHEN vc.calib_multipoint IS true THEN 'Si' ELSE 'No' END AS multi_si_no,
        vc.calib_values,
        vc.calib_note,
        COALESCE(vc.calib_note, 'Nessuna nota') AS cal_note,
        -- Allegati
        (
            SELECT to_json(ARRAY_AGG(row_to_json(j)))
            FROM (
                SELECT
                    ca.att_id AS file_id,
                    lpad(ca.calib_id::text , 9, '0')||'/'||ca.file_archive AS file_archive,
                    ca.file_image,
                    ca.file_original
                FROM
                    reports.calibration_attachments ca
                WHERE ca.calib_id = vc.calib_id
            ) j
        ) AS attachments
    FROM reports.view_calibrations vc
    LEFT JOIN metadata.view_stations_info vsi USING (station_id)
    LEFT JOIN equipments.view_instruments_type vit USING (instr_type_id)
    LEFT JOIN metadata.view_stations_municipality vsm USING (station_id)
    LEFT JOIN bobo.view_users vu ON (vc.us_id = vu.user_id)
    WHERE
        vc.calib_fulldate::date BETWEEN '$date_start'::timestamp AND '$date_end'::timestamp
        AND vsi.station_network_type_id = $net
};

# controllo della stazione selezionata
if($station != -1){
    $sql_cal .= qq{
        AND vc.station_id = $station
    };
}

# query end
$sql_cal .= qq {
    ORDER BY calib_id, calib_fulldate
    -- LIMIT 5 -- only test
};

#------------------------------------------------------------------------------
# GET RECORD
#------------------------------------------------------------------------------
my $calibrations = dbh_get_rows_arrayref( $sql_cal );
$log->info(Dumper($calibrations));

# controllo se il risultato della query è vuoto
my $rows = scalar @{$calibrations};
if ($rows == 0){
    $log->info("Empty query!");
    end();
    exit(1);
}

# variabili contenuto
my $headfoot;
my $body;

# get number of calibrations
my $num_tarature =  scalar @{$calibrations};
$log->info("LUNGHEZZA ARRAY TARATURE: $num_tarature");

# flag per identificare il primo valore dell'array delle tarature (utile per creare una sola volta il file header_footer)
my $first = 0;

# loop dei report tarature
foreach my $calibration ( @{$calibrations} )
{
    # controllo se l'header_footer è già stato creato
    if ($first == 0) {
        #------------------------------------------------------------------------------
        # HEADER/FOOTER
        #------------------------------------------------------------------------------
        $log->debug('header-footer tarature cumulativo...');

        # togliere il commento se si vuole prendere l'immagine del logo dalla directory "/inc" (caricare l'immagine in quella cartella)
        # my $logo_name = basename($calibration->{station_network_type_logo});

        # costruzione del file .tex
        $headfoot .= '%%----------------- DEFINIZIONE HEADER E FOOTER -----------------'."\n";
        $headfoot .= '\pagestyle{fancy}'."\n";
        $headfoot .= '\setlength{\headheight}{50pt} % distanza dell\'header dalla cima del foglio'."\n";
        $headfoot .= '\setlength{\footskip}{80pt} % distanza del footer dall\'ultima linea della pagina'."\n";
        $headfoot .= '\fancyhf{} % cancella tutti i campi di intestazione e pie pagina'."\n";
        $headfoot .= "\n";
        $headfoot .= '%% MODIFICA COLORE DELLE LINEE DELL\'HEADER E DEL FOOTER'."\n";
        $headfoot .= '\let\oldheadrule\headrule % Copy \headrule into \oldheadrule'."\n";
        $headfoot .= '\renewcommand{\headrule}{\color{greyHEADFOOT}\oldheadrule} % Add colour to \headrule'."\n";
        $headfoot .= '\let\oldfootrule\footrule % Copy \footrule into \oldfootrule'."\n";
        $headfoot .= '\renewcommand{\footrule}{\color{greyHEADFOOT}\oldfootrule} % Add colour to \footrule'."\n";
        $headfoot .= "\n";
        $headfoot .= '%%----------------- HEADER -----------------'."\n";
        $headfoot .= '\fancyhead[L]{'."\n";
        # $body .= '\hypertarget{HOME}{}'."\n";
        $headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$main_logo.'}}'."\n";
        $headfoot .= '    \quad % aggiunge una tabulazione per distanziare le immagini'."\n";
        $headfoot .= '    \quad'."\n";
        $headfoot .= '    \raisebox{2ex}{\includegraphics[height=1cm, keepaspectratio]{'.$logo_path.''.$calibration->{station_network_type_logo}.'}}'."\n";
        $headfoot .= '}'."\n";
        $headfoot .= "\n";
        $headfoot .= '\fancyhead[R]{'."\n";
        $headfoot .= '    \raisebox{1.5ex}{\textcolor{greyHEADFOOT}{\bfseries{\LARGE '.latex_encode($calibration->{station_network_type_desc}).'}}} \\\\'."\n";
        $headfoot .= '}'."\n";
        $headfoot .= '%%----------------- FOOTER -----------------'."\n";
        $headfoot .= '\fancyfoot[L]{'."\n";
        $headfoot .= '    \textcolor{greyHEADFOOT}{\bfseries{'.$foot_desc.' - '.latex_encode($calibration->{station_network_type_desc}).'}} \\\\'."\n";
        $headfoot .= '    \textcolor{greyHEADFOOT}{\mdseries{Report generato il \today}}'."\n";
        $headfoot .= '}'."\n";
        $headfoot .= "\n";
        $headfoot .= '\fancyfoot[R]{'."\n";
        $headfoot .= '    \bfseries{Mod. 07\\_D3 Rev. 02} \\\\'."\n";
        $headfoot .= '    \mdseries{Pagina \thepage $ $ di \pageref{LastPage}}'."\n";
        $headfoot .= '}'."\n";
        $headfoot .= "\n";
        $headfoot .= '\renewcommand{\footrulewidth}{0.2mm}'."\n";

        # variabile impostata ad 1 per skippare la creazione dal secondo elemento dell'array
        $first = 1;
    }

    # campi del json estratto dalla query (campo 'calib_values')
    my $calib_json = decode_json($calibration->{calib_values});
    $log->info(Dumper($calib_json));

    #------------------------------------------------------------------------------
    # CORPO CENTRALE
    #------------------------------------------------------------------------------
    $log->debug('corpo centrale tarature cumulativo ...');

    # costruzione del nome completo dello strumento
    my $instrument_fullname = $calibration->{instr_type_fullname};
    if (defined $calibration->{instr_name} && $calibration->{instr_name} ne ''){
        $instrument_fullname .= ' ('.$calibration->{instr_name}.')';
    }

    # # insert interruzione di pagina
    # $body .= '\pagebreak[4] '."\n";
    # $body .= "\n";

    # costruzione del file .tex
    # titolo
    $body .= '\begin{center}'."\n";
    $body .= '    \hypertarget{TARATURA_'.$calibration->{calib_id}.'}{}'."\n";
    $body .= '    \textcolor{BOBOblue}{\Large{Report Taratura n. \textbf{'.$calibration->{calib_id}.'} del \textbf{'.$calibration->{date}.'} alle \textbf{'.$calibration->{time_format}.'}}} % TITOLO'."\n";
    $body .= '\end{center}'."\n";

    # dati operatore
    $body .= '%%----------------- tabella -----------------'."\n";
    $body .= '\begin{center}'."\n";
    $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
    $body .= '    \begin{tabularx}{1.0\textwidth}{'."\n";
    $body .= '        >{\raggedleft\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedleft\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '    }'."\n";
    $body .= '        \bfseries{Operatore:} & \multicolumn{2}{p{5cm}}{\mdseries{'.controlnull(latex_encode($calibration->{user_fullname})).'}} & \bfseries{Azienda:} & \mdseries{'.controlnull(latex_encode($calibration->{company_name})).'} & \\\\'."\n";
    $body .= '        \bfseries{Provincia:} & \multicolumn{2}{p{5cm}}{\mdseries{'.controlnull(latex_encode($calibration->{province_name})).'}} & \bfseries{Stazione:} & \multicolumn{2}{p{5cm}}{\mdseries{'.controlnull(latex_encode($calibration->{station_name})).'}} \\\\'."\n";
    $body .= '    \end{tabularx}'."\n";
    $body .= '\end{center}'."\n";
    $body .= '\\\\'."\n";
    $body .= '\begin{center}'."\n";
    $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
    $body .= '    \begin{tabularx}{1.0\textwidth}{'."\n";
    $body .= '        >{\raggedleft\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedleft\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '        >{\raggedright\arraybackslash}X'."\n";
    $body .= '    }'."\n";
    $body .= '        \bfseries{Strumento:} & \multicolumn{5}{p{40em}}{\mdseries{'.controlnull(latex_encode($instrument_fullname)).' (cat. \itshape{'.controlnull(latex_encode($calibration->{category_name})).'}})} \\\\'."\n";
    $body .= '        \bfseries{ID:} & \multicolumn{2}{p{5cm}}{\mdseries{'.controlnull(latex_encode($calibration->{instr_arpa_id})).'}} & \bfseries{N\degree  Seriale:} & \mdseries{'.controlnull(latex_encode($calibration->{instr_serial_num})).'} & \\\\'."\n";
    $body .= '        \bfseries{Tarat. multi:} & \multicolumn{2}{p{5cm}}{\mdseries{'.$calibration->{multi_si_no}.'}} & \bfseries{Motivo:} & \multicolumn{2}{p{6cm}}{\mdseries{'.controlnull(latex_encode($calibration->{calib_reason})).'}} \\\\'."\n";
    $body .= '        \bfseries{Note:} & \multicolumn{5}{p{40em}}{\mdseries{'.controlnull(latex_encode($calibration->{cal_note})).'}} \\\\'."\n";
    $body .= '    \end{tabularx}'."\n";
    $body .= '\end{center}'."\n";
    $body .= "\n";
    $body .= '\vspace{0.5cm}'."\n";
    $body .= "\n";

    # corpo tabelle

    # category_id degli strumenti
    # 1	"Analizzatore SO2"
    # 2	"Analizzatore NOx"
    # 3	"Analizzatore CO"
    # 4	"Analizzatore O3"
    # ...

    my ($tank_zero, $tank_span);
    my ($method_zero, $method_span);
    my ($mod_zero, $mod_span, $mod_probe);

    $log->debug("CATEGORY_ID --> $calibration->{category_id}");

    given ($calibration->{category_id}) {
        when (1) {
            # S02
            $tank_zero = get_cylinder_by_id($calib_json->{'tank-zero-so2'});
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-so2'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-so2'});
            $method_span = get_method_by_id($calib_json->{'method-span-so2'});

            if ($calib_json->{'mod-zero-so2'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-so2'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_zero->{cylinder_fullname})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-zero-so2'}), controlnull($calibration->{instr_type_unit})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            if ($calibration->{calib_multipoint}) {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         &  & \bfseries{Span letto} & \bfseries{Span teorico} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                # $body .= '        \multicolumn{2}{l}{\multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L1}}}} & \mdseries{'.controlnull($calib_json->{'l1-read-span-so2'}).'} & \mdseries{'.controlnull($calib_json->{'l1-theory-span-so2'}).'} \\\\'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L1}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L2}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L3}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L4}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L5}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            } else {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-so2'}), controlnull($calibration->{instr_type_unit})).'} & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-so2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            }
        }
        when (2) {
            # NOx, NO, NO2
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-noxnono2'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-noxnono2'});
            $method_span = get_method_by_id($calib_json->{'method-span-noxnono2'});

            if ($calib_json->{'mod-zero-noxnono2'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-noxnono2'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{NOX} & \bfseries{NO} & \bfseries{NO2} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'nox-zero-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'no-zero-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'no2-zero-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            if ($calibration->{calib_multipoint}) {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         &  & \bfseries{NOX} & \bfseries{NO} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L1}}} & \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '         & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L2}}} & \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '         & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L3}}} & \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '         & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L4}}} & \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '         & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            } else {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         & \bfseries{NOX} & \bfseries{NO} & \bfseries{NO2} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-no2-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-nox-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-no-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-no2-span-noxnono2'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            }
        }
        when (3) {
            # CO
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-co'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-co'});
            $method_span = get_method_by_id($calib_json->{'method-span-co'});

            if ($calib_json->{'mod-zero-co'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-co'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            # $body .= '        \bfseries{Bombola:} & \mdseries{'.latex_encode($tank_zero->{cylinder_fullname}).'} &  &  \\\\'."\n";
            # $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \multicolumn{3}{l}{\mdseries{'.check_data_unit(controlnull($calib_json->{'find-zero-co'}), controlnull($calibration->{instr_type_unit})).'}} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            if ($calibration->{calib_multipoint}) {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         &  & \bfseries{Span letto} & \bfseries{Span teorico} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                # $body .= '        \multicolumn{2}{l}{\multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L1}}}} & \mdseries{'.controlnull($calib_json->{'l1-read-span-co'}).'} & \mdseries{'.controlnull($calib_json->{'l1-theory-span-co'}).'} \\\\'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L1}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L2}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L3}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L4}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L5}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            } else {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            }

        }
        when (4) {
            # O3
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-o3'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-o3'});
            $method_span = get_method_by_id($calib_json->{'method-span-o3'});
            $calibrator_span = get_calibrator_by_id($calib_json->{'calib-span-o3'});

            if ($calib_json->{'mod-zero-o3'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-o3'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            # $body .= '        \bfseries{Bombola:} & \mdseries{'.latex_encode($tank_zero->{cylinder_fullname}).'} &  &  \\\\'."\n";
            # $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \multicolumn{3}{l}{\mdseries{'.check_data_unit(controlnull($calib_json->{'find-zero-o3'}), controlnull($calibration->{instr_type_unit})).'}} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            if ($calibration->{calib_multipoint}) {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Calibratore:} & \mdseries{'.controlnull(latex_encode($calibrator_span->{instr_fullname})).'} & \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         &  & \bfseries{Span letto} & \bfseries{Span teorico} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                # $body .= '        \multicolumn{2}{l}{\multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large 100}}}} & \mdseries{'.controlnull($calib_json->{'l1-read-span-o3'}).'} & \mdseries{'.controlnull($calib_json->{'l1-theory-span-o3'}).'} \\\\'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large 100}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-span-o3'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-span-o3'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large 200}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-span-o3'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-span-o3'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large 300}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-span-o3'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-span-o3'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large 400}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-span-o3'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-span-o3'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large 500}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-read-span-o3'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-theory-span-o3'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            } else {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Calibratore:} & \mdseries{'.controlnull(latex_encode($calibrator_span->{instr_fullname})).'} & \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            }
        }
        when (5) {
            # GC955 (BTX)
            $tank_zero = get_cylinder_by_id($calib_json->{'tank-zero-btx'});
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-btx'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-btx'});
            $method_span = get_method_by_id($calib_json->{'method-span-btx'});

            if ($calib_json->{'mod-zero-btx'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-btx'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_zero->{cylinder_fullname})).'} &  &  \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{Benzene} & \bfseries{Toluene} & \bfseries{Xilene} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-ben-zero-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-tol-zero-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-xil-zero-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            if ($calibration->{calib_multipoint}) {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         &  & \bfseries{Span letto} & \bfseries{Span teorico} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                # $body .= '        \multicolumn{2}{l}{\multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large 100}}}} & \mdseries{'.controlnull($calib_json->{'l1-read-span-btx'}).'} & \mdseries{'.controlnull($calib_json->{'l1-theory-span-btx'}).'} \\\\'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large L1}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-read-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l1-theory-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large L2}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-read-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l2-theory-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large L3}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-read-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l3-theory-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large L4}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-read-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l4-theory-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \multicolumn{2}{c}{\textcolor{BOBOblue}{\bfseries{\large L5}}} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-read-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'l5-theory-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            } else {
                $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
                $body .= '\begin{center}'."\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\raggedright\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= "\n";
                $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
                $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
                $body .= '        >{\raggedleft\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '        >{\centering\arraybackslash}X'."\n";
                $body .= '    }'."\n";
                $body .= '         & \bfseries{Benzene} & \bfseries{Toluene} & \bfseries{Xilene} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-ben-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-tol-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-xil-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '        \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-ben-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-tol-span-btx'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-xil-span-btx'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
                $body .= '        \arrayrulecolor{lines}\hline'."\n";
                $body .= '    \end{tabularx}'."\n";
                $body .= '\end{center}'."\n";
            }
        }
        when (7) {
            # CH4
            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-ch4'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-ch4'});
            $method_span = get_method_by_id($calib_json->{'method-span-ch4'});

            if ($calib_json->{'mod-zero-ch4'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-ch4'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{CH4} & \bfseries{TNMHC} & \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-zero-ch4'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'find-zero-tnmhc'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            # MULTIPUNTO
            # if ($calibration->{calib_multipoint}) {
            #     $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN MULTIPUNTO}}'."\n";
            #     $body .= '\begin{center}'."\n";
            #     $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            #     $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            #     $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            #     $body .= '        >{\raggedright\arraybackslash}X'."\n";
            #     $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            #     $body .= '        >{\raggedright\arraybackslash}X'."\n";
            #     $body .= '    }'."\n";
            #     $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  )&  \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '    \end{tabularx}'."\n";
            #     $body .= "\n";
            #     $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            #     $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            #     $body .= '        >{\raggedright\arraybackslash}X'."\n";
            #     $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            #     $body .= '        >{\centering\arraybackslash}X'."\n";
            #     $body .= '        >{\centering\arraybackslash}X'."\n";
            #     $body .= '    }'."\n";
            #     $body .= '         &  & \bfseries{Span letto} & \bfseries{Span teorico} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     # $body .= '        \multicolumn{2}{l}{\multirow{2}*{\textcolor{BOBOblue}{\bfseries{\large L1}}}} & \mdseries{'.controlnull($calib_json->{'l1-read-span-co'}).'} & \mdseries{'.controlnull($calib_json->{'l1-theory-span-co'}).'} \\\\'."\n";
            #     $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L1}}} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l1-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l1-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L2}}} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l2-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l2-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L3}}} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l3-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l3-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L4}}} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l4-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l4-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \multicolumn{2}{l}{\textcolor{BOBOblue}{\bfseries{\large L5}}} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l5-read-span-co'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit( controlnull($calib_json->{'l5-theory-span-co'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '    \end{tabularx}'."\n";
            #     $body .= '\end{center}'."\n";
            # } else {
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{CH4} & \bfseries{TNMHC} & \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-ch4'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-tnmhc'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-ch4'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-tnmhc'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
        }
        when ([8, 9, 10, 11, 12, 13]) {
            # MCZ

            if ($calib_json->{'mod-flow-sampler'}) {
                $mod_flow = "Si";
            } else {
                $mod_flow = "No";
            }

            ##### TABELLA FLUSSI
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dei FLUSSI}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.80\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        r'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Flusso letto:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'read-flow-sampler'})), "l/min").'} & \bfseries{Flusso riferimento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'reference-flow-sampler'})), "l/min").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Temp. Ambiente:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'temp-flow-sampler'})), "\\degree C").'} & \bfseries{Pressione:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'press-flow-sampler'})), "hPa").'} \\\\'."\n";
            # $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_zero->{cylinder_fullname})).'} &  &  \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Temp. Strumento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'temp-instr-flow-sampler'})), "\\degree C").'} & \bfseries{Press. Strumento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'press-instr-flow-sampler'})), "hPa").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Flusso calibrato:} & \multicolumn{3}{l}{\mdseries{'.$mod_flow.'}} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";

            # # if ($calibration->{'station_network_type_id'} == 1 && $calibration->{'instr_id'} == 10) { # strettamente palas di arpavda
            # if ($calibration->{'instr_id'} == 10) {
            #     $body .= '        \bfseries{Riferimento:} & \mdseries{'.controlnull($calib_json->{'palas-reference'}).'} & \bfseries{Metodo:} & \mdseries{'.controlnull($calib_json->{'palas-method'}).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            #     $body .= '        \bfseries{Canale misurato:} & \mdseries{'.controlnull($calib_json->{'palas-measure-channel'}).'} & \bfseries{Canale riferimento:} & \mdseries{'.controlnull($calib_json->{'palas-reference-channel'}).'} \\\\'."\n";
            #     $body .= '        \arrayrulecolor{lines}\hline'."\n";
            # }

            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
        }
        when ([14, 15, 18]) {
            # CAMP. POLVERI OTTICO - AEROSOL

            # +------------------------------------------------------+
            # | "CANALE"                                             |
            # | tank-span-aerosol           method-span-aerosol      |
            # | read-spa-aerosol            theory-span-aerosol      |
            # |                                                      |
            # | "FLUSSI"                                             |
            # | read-flow-aerosol           reference-flow-aerosol   |
            # | temp-instr-flow-aerosol     press-instr-flow-aerosol |
            # | temp-flow-aerosol           press-flow-aerosol       |
            # | mod-flow-aerosol                                     |
            # +------------------------------------------------------+

            $ref_channel = get_cylinder_by_id($calib_json->{'tank-span-aerosol'});
            $method_channel = get_method_by_id($calib_json->{'method-span-aerosol'});

            if ($calib_json->{'mod-span-aerosol'}) {
                $ch_cal = "Si";
            } else {
                $ch_cal = "No";
            }

            if ($calib_json->{'mod-flow-aerosol'}) {
                $mod_flow = "Si";
            } else {
                $mod_flow = "No";
            }

            ##### TABELLA CANALE
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura del CANALE}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.80\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        r'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Riferimento:} & \mdseries{'.controlnull(latex_encode($ref_channel->{cylinder_fullname})).'} & \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_channel->{method_name})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Canale misurato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-span-aerosol'}), controlnull($calibration->{instr_type_unit})).'} & \bfseries{Canale riferimento:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-span-aerosol'}), controlnull($calibration->{instr_type_unit})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Canale calibrato:} & \multicolumn{3}{l}{\mdseries{'.$ch_cal.'}} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA FLUSSI
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dei FLUSSI}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.80\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        r'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Flusso letto:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'read-flow-aerosol'})), "l/min").'} & \bfseries{Flusso riferimento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'reference-flow-aerosol'})), "l/min").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Temp. Strumento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'temp-instr-flow-aerosol'})), "\\degree C").'} & \bfseries{Press. Strumento:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'press-instr-flow-aerosol'})), "hPa").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Temp. Ambiente:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'temp-flow-aerosol'})), "\\degree C").'} & \bfseries{Pressione:} & \mdseries{'.check_data_unit(controlnull(latex_encode($calib_json->{'press-flow-aerosol'})), "hPa").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Flusso calibrato:} & \multicolumn{3}{l}{\mdseries{'.$mod_flow.'}} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";
        }
        when (25) {
            # BIOGAS

            # "o2-zero-biogas": "1",
            # "ch4-zero-biogas": "2",
            # "co2-zero-biogas": "3",
            # "mod-zero-biogas": "on",
            # "method-zero-biogas": "4",
            # "tank-span-biogas": "-1",
            # "method-span-biogas": "1",
            # "read-o2-span-biogas": "11",
            # "read-ch4-span-biogas": "22",
            # "read-co2-span-biogas": "33",
            # "theory-o2-span-biogas": "111",
            # "theory-ch4-span-biogas": "222",
            # "theory-co2-span-biogas": "333",
            # "mod-span-biogas": "on",


            $tank_span = get_cylinder_by_id($calib_json->{'tank-span-biogas'});
            $method_zero = get_method_by_id($calib_json->{'method-zero-biogas'});
            $method_span = get_method_by_id($calib_json->{'method-span-biogas'});

            if ($calib_json->{'mod-zero-biogas'}) {
                $mod_zero = "Si";
            } else {
                $mod_zero = "No";
            }

            if ($calib_json->{'mod-span-biogas'}) {
                $mod_span = "Si";
            } else {
                $mod_span = "No";
            }

            ##### TABELLA ZERO
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello ZERO}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_zero->{method_name})).'} & \bfseries{Zero modificato:} & \mdseries{'.$mod_zero.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{O2} & \bfseries{CH4} & \bfseries{CO2} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Zero trovato:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'o2-zero-biogas'}), latex_encode("%")).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'ch4-zero-biogas'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'co2-zero-biogas'}), latex_encode("%")).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
            $body .= "\n";
            $body .= '\vspace{0.5cm}'."\n";
            $body .= "\n";

            ##### TABELLA SPAN
            $body .= '\textcolor{BOBOblue}{\bfseries{\large Taratura dello SPAN}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_span->{method_name})).'} & \bfseries{Span modificato:} & \mdseries{'.$mod_span.'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Bombola:} & \mdseries{'.controlnull(latex_encode($tank_span->{cylinder_fullname})).'} &  &  \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.75\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{O2} & \bfseries{CH4} & \bfseries{CO2} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Span letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-o2-span-biogas'}), latex_encode("%")).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-ch4-span-biogas'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-co2-span-biogas'}), latex_encode("%")).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Span teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-o2-span-biogas'}), latex_encode("%")).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-ch4-span-biogas'}), controlnull($calibration->{instr_type_unit})).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-co2-span-biogas'}), latex_encode("%")).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
        }
        when (26) {
            # SONDE MULTIPARAMETRICHE

            # "solution-probe": "",
            # "method-probe": "",
            # "read-temp-probe": "",
            # "read-cond-probe": "",
            # "read-ph-probe": "",
            # "read-redox-probe": "",
            # "theory-temp-probe": "",
            # "theory-cond-probe": "",
            # "theory-ph-probe": "",
            # "theory-redox-probe": "",
            # "mod-probe": "",
            # "notes-calib": "",


            $solution_probe = get_cylinder_by_id($calib_json->{'solution-probe'});
            $method_probe = get_method_by_id($calib_json->{'method-probe'});

            if ($calib_json->{'mod-probe'}) {
                $mod_probe = "Si";
            } else {
                $mod_probe = "No";
            }

            ##### TABELLA SONDA
            $body .= '\textcolor{BOBOblue}{\bfseries{\large SONDA}}'."\n";
            $body .= '\begin{center}'."\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.80\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\raggedright\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '        \bfseries{Soluzione:} & \mdseries{'.controlnull(latex_encode($solution_probe->{cylinder_fullname})).'} & \bfseries{Metodo:} & \mdseries{'.controlnull(latex_encode($method_probe->{method_name})).'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '         &  &  &  &'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= "\n";
            $body .= '    \renewcommand{\arraystretch}{1.75}'."\n";
            $body .= '    \begin{tabularx}{0.80\textwidth}{'."\n";
            $body .= '        >{\raggedleft\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '        >{\centering\arraybackslash}X'."\n";
            $body .= '    }'."\n";
            $body .= '         & \bfseries{Temperatura} & \bfseries{Conducibilit\`a} & \bfseries{Ph} & \bfseries{Redox} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Valore letto:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-temp-probe'}), "\\degree C").'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-cond-probe'}), "{\\micro}S/cm").'} & \mdseries{'.controlnull($calib_json->{'read-ph-probe'}).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'read-redox-probe'}), "mV").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Valore teorico:} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-temp-probe'}), "\\degree C").'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-cond-probe'}), "{\\micro}S/cm").'} & \mdseries{'.controlnull($calib_json->{'theory-ph-probe'}).'} & \mdseries{'.check_data_unit(controlnull($calib_json->{'theory-redox-probe'}), "mV").'} \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '         &  &  &  &  \\\\'."\n";
            # $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '        \bfseries{Taratura:} & \mdseries{'.$mod_probe.'} &  &  &  \\\\'."\n";
            $body .= '        \arrayrulecolor{lines}\hline'."\n";
            $body .= '    \end{tabularx}'."\n";
            $body .= '\end{center}'."\n";
        }
        default {
            $body .= 'ID STRUMENTO NON TROVATO: '.$calibration->{category_id}.' \\\\'."\n";
        }
    }

    # allegati
    # $calibration->{attachments} --> array degli allegati
    my $arr_allegati = $calibration->{attachments};

    # check se ci sono allegati o no
    if (!$arr_allegati) {
        $log->info("NO ATTACHMENTS");
        $body .= '    \section*{\textcolor{BOBOblue}{\bfseries{Allegati}}}'."\n";
        $body .= '    \mdseries{Nessun allegato}'."\n";
    } else {
        $arr_allegati = decode_json(encode_utf8($calibration->{attachments}));
        $log->info("ATTACHMENTS: IMAGES");
        $body .= '\newpage'."\n";
        $body .= "\n";
        $body .= '%%%%%%%%%%%%%%%%%%%%%%%% - Allegati (immagini) - %%%%%%%%%%%%%%%%%%%%%%%%'."\n";
        $body .= '\subsection*{\textcolor{BOBOblue}{\mdseries{Immagini}}}'."\n";
        $body .= '\begin{figure}[!h]'."\n";
        $body .= '    \begin{minipage}{0.75\linewidth}'."\n";

        # contatore immagini per latex
        my $image_counter = 1;

        # flag presenza immagini
        my $images = 0;

        # gestione array degli allegati PER LE IMMAGINI
        foreach my $allegato ( @{$arr_allegati} ){
            # controllo se l'allegato è un'immagine
            if (!$allegato->{file_image}){
                $log->info("NOT IMAGE: NEXT ATTACHMENT...");
                next;
            }

            $log->info("EXIST IMAGE: ADDING IT...");
            $body .= '        \subfigure[Foto '.$image_counter.']{%'."\n";
            $body .= '            \setlength{\tabcolsep}{10mm}'."\n";
            $body .= '            \begin{tabular}{c}'."\n";
            $body .= '                \includegraphics*[width=0.50\textwidth,height=0.50\textheight,keepaspectratio]{'.check_fix_imgs($allegato->{file_archive}).'}'."\n";
            $body .= '            \end{tabular}'."\n";
            # if ($image_counter % 3 == 0) {
            #     $body .= '        } \\\\'."\n";
            # } else {
            #     $body .= '        }'."\n";
            # }

            $body .= '        }'."\n";

            $image_counter = $image_counter + 1;
            $images = 1;
        }

        if (!$images){
            $body .= '        \mdseries{Nessuna immagine}'."\n";
        }

        $body .= '    \end{minipage}'."\n";
        $body .= '\end{figure}'."\n";
        $body .= ''."\n";

        # flag presenza altri allegati (no immagini)
        my $others = 0;

        $log->info("ATTACHMENTS: OTHERS");
        $body .= '%%%%%%%%%%%%%%%%%%%%%%%% - Allegati (files) - %%%%%%%%%%%%%%%%%%%%%%%%'."\n";
        $body .= '\subsection*{\textcolor{BOBOblue}{\mdseries{Altri allegati}}}'."\n";

        $body .= '\begin{itemize}'."\n";

        # gestione array degli allegati PER GLI ALTRI ALLEGATI
        foreach my $allegato ( @{$arr_allegati} ){
            # controllo se l'allegato è un'immagine
            if ($allegato->{file_image}){
                $log->info("IS IMAGE: NEXT ATTACHMENT...");
                next;
            }

            # se non è un'immagine: inserire il nome originale nell'elenco puntato
            $body .= '    \item '.latex_encode($allegato->{file_original}).''."\n";
            $others = 1;
        }

        $body .= '\end{itemize}'."\n";

        if (!$others){
            $body .= '\mdseries{Nessun altro allegato}'."\n";
        }
    }

    # get element postion
    my $idx = firstidx { $_ eq $calibration } @{$calibrations};
    $idx++; # 0 excluded
    $log->info("POSIZIONE: $idx");
    $body .= '\newpage'."\n";
}

# date formattate per nome file
$date_start =~m/^(\d+)-(\d+)-(\d+)/;
my $format_from = "$1$2$3";
# $date_end =~m/^(\d+)-(\d+)-(\d+)\s\d+:\d+:\d+/;
$date_end =~m/^(\d+)-(\d+)-(\d+)(\s|T)\d+:\d+:\d+/;
my $format_to = "$1$2$3";
$log->info("Data DA formattata: $format_from");
$log->info("Data  A formattata: $format_to");

#------------------------------------------------------------------------------
# WRAPPER
#------------------------------------------------------------------------------
$log->debug('wrapper tarature cumulativo ...');

# variabile contenuto
my $wrap;

# costruzione del file .tex
$wrap .= '%% -------------------- PREAMBOLO --------------------'."\n";
$wrap .= '\input{'.$abs_path.'/inc/preamble.tex}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- DEFINIZIONE HEADER E FOOTER --------------------'."\n";
$wrap .= '\input{'.$tex_file_headfoot.'}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- DEFINITIONS --------------------'."\n";
$wrap .= '\input{'.$abs_path.'/inc/define.tex}'."\n";
$wrap .= ''."\n";
$wrap .= '%% -------------------- INIZIO DOCUMENTO --------------------'."\n";
$wrap .= '\begin{document}'."\n";
$wrap .= ''."\n";
$wrap .= '    \input{'.$tex_file_body.'}'."\n";
$wrap .= ''."\n";
$wrap .= '\end{document}'."\n";
$wrap .= '%% -------------------- FINE DOCUMENTO --------------------'."\n";

#------------------------------------------------------------------------------
# WRITE TO FILES
#------------------------------------------------------------------------------
# FILE WRAPPER
$log->info("Writing to file $tex_file_wrapper ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_wrapper) or die $!;
print FILE $wrap;
close FILE;

# FILE HEADER-FOOTER
$log->info("Writing to file $tex_file_headfoot ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_headfoot) or die $!;
print FILE $headfoot;
close FILE;

# FILE BODY
$log->info("Writing to file $tex_file_body ...");
$log->info("");
open(FILE ,">:encoding(UTF-8)", $tex_file_body) or die $!;
print FILE $body;
close FILE;

#------------------------------------------------------------------------------
# PDF FILENAME
#------------------------------------------------------------------------------
my $job_name = 'report-taratura-{'.$user_id.$net.'}-'.$format_from.'-'.$format_to;
my $pdf_filename = $job_name.'.pdf';
my $pdf_fullname = $pdf_export_path.$pdf_filename;

#------------------------------------------------------------------------------
# CHANGE WORKING PATH
#------------------------------------------------------------------------------
$log->debug("Changing working path ...");
chdir($abs_path) or log_msg("Cannot chdir to $abs_path $!", 1);

#------------------------------------------------------------------------------
# CREATE PDF
#------------------------------------------------------------------------------
my $res = latex2pdf ( $pdf_export_path, $job_name, $tex_file_wrapper, $pdf_fullname, $working_path, $random_str );

#------------------------------------------------------------------------------
# DISCONNECT FROM DB
#------------------------------------------------------------------------------
dbh_disconnect();

#------------------------------------------------------------------------------
# THE END
#------------------------------------------------------------------------------
end();
exit(0);





#------------------------------------------------------------------------------
# SUBS
#------------------------------------------------------------------------------
# funzione per recuperare i metodi relativi ad una determinata taratura
sub get_method_by_id {
    my $me_id = shift;

    # metodi
    my $sql = qq{
        SELECT
            calib_me_id     AS method_id,
            calib_me_name   AS method_name
        FROM reports.calibration_methods
        WHERE calib_me_id = $me_id;
    };

    # esecuzione query
    my $method = dbh_get_row_hashref( $sql );
    $log->info(Dumper($method));

    return defined $method ? $method : '-';
    # return defined $method ? $method->{'method_name'} : '-';
}

# funzione per recuperare le informazioni relative ad una determinata bombola
sub get_cylinder_by_id {
    my $cy_id = shift;

    # bombole
    my $sql = qq{
        SELECT
            COALESCE(cylinder_arpa_id, '--') AS cylinder_arpa_id,
            cylinder_name,
            cylinder_mixture,
            cylinder_mixture
            || COALESCE(' - '||cylinder_name, '')
            || COALESCE(' ['||cylinder_arpa_id||']', '') AS cylinder_fullname,
            cylinder_ch_values

        FROM equipments.view_cylinders vc
        WHERE cy_id = $cy_id
    };

    # esecuzione query
    my $cylinder = dbh_get_row_hashref( $sql );
    $log->info(Dumper($cylinder));

    my $default_tank = {
        cylinder_arpa_id   => '-',
        cylinder_name      => '-',
        cylinder_mixture   => '-',
        cylinder_fullname  => '-',
        cylinder_ch_values => []
    };

    return defined $cylinder ? $cylinder : $default_tank;
}

# funzione per recuperare i calibratori dal database
sub get_calibrator_by_id {
    my $cr_id = shift;

    # calibratori
    my $sql = qq{
        SELECT
            instr_type_fullname || COALESCE(' - '||instrument_name, '') AS instr_fullname,
            COALESCE(instrument_arpa_id, '-') AS instrument_arpa_id
        FROM equipments.view_instruments
        WHERE instr_id = $cr_id;
    };

    # esecuzione query
    my $calibrator = dbh_get_row_hashref( $sql );
    $log->info(Dumper($calibrator));

    return defined $calibrator ? $calibrator : '-';
    # return defined $calibrator ? $calibrator->{'method_name'} : '-';
}

# funzione per gestire i null: se presente un null, oppure una stringa vuota, lo sostituisce con la stringa '--'
sub controlnull {
    my $dato = shift;

    if (!defined $dato) {
        return "--";
    } elsif ($dato eq '') {
        return "--";
    } else {
        return $dato;
    }
}

# funzione per verificare i dati di calibrazione
sub check_data_unit {
    my ( $data, $unit ) = @_;

    # if calib data is empty: THEN print "--" ELSE print "value + unit"
    if($data eq "--") {
        return "--";
    } else {
        return "$data $unit";
    }
}

# funzione di lancio del comando di generazione del PDF partendo dai files .tex generati
sub latex2pdf {
    my $exppath  = shift;
    my $jobname  = shift;
    my $texfile  = shift;
    my $pdffile  = shift;
    my $workpath = shift;
    my $randstr  = shift;

    # log
    $log->info("");
    $log->debug("Generating pdf file $pdffile ...");

    # delete the pdf file if exists
    if (-e $pdffile) { unlink $pdffile; }

    # default to wrong result
    my $res = 0;

    # -------------------------------------------------------
    # generate pdf
    # http://www.perlhowto.com/executing_external_commands
    # cat test.tex | pdflatex &>/dev/null && rm texput.log texput.aux
    # -interaction=STRING  set interaction mode (STRING=batchmode/nonstopmode/scrollmode/errorstopmode)
    # -------------------------------------------------------
    if ( $^O eq 'linux' ) {
        $log->debug("Calling system() ...");
        $log->debug("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");
        system("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");
        system("pdflatex -interaction=nonstopmode --shell-escape -output-directory=$exppath --jobname=$jobname $texfile");

        if ( $? == -1 ) {
            $log->debug("Command failed: $!");
        } else {
            $log->debug( (printf "Command exited with value %d", $? >> 8));
            $res = 1;
        }

        $log->debug("Calling chmod ...");
        if (-e $pdffile) {
            chmod 0744, $pdffile or $log->debug( "Couldn't chmod $pdffile: $!" );
        }
    }

    # if all went ok delete support files
    if ( $res ) {
        # clear all -- http://www.perlhowto.com/working_with_files
        $log->debug("Unlinking support files ...");
        #if ( ! $DEBUG ) { unlink <$exppath/report*.tex>; }
        unlink <$exppath/report*.tex>;
        unlink <$exppath/*.tex>;
        unlink <$exppath/*.aux>;
        unlink <$exppath/*.log>;
        unlink <$exppath/*.out>;
        # del *.dvi
        # del *.aux
        # del *.bbl
        # del *.blg
        # del *.brf
        # del *.out

        # remove ".tex" files once finished
        $log->debug("Unlinking tex files ...");
        unlink <$workpath/*$randstr.tex>;
    }

    # return
    return $res;
}

# funzione di download delle immagini attraverso https
sub getImage {
    my $img_url = shift;
    my $img_name = shift;
    my $img_save_path = "$abs_path/inc/tmp/$img_name.jpg";
    $log->debug("Downloading ... ");

    # displaying a user friendly message
    $log->debug("FROM...");
    $log->debug($img_url);
    $log->debug("TO...");
    $log->debug($img_save_path);

    # first parameter is the URL of the image
    # second parameter is the location of the downloaded image

    getstore($img_url, $img_save_path);

    # checking for successful
    if (-e $img_save_path) {
        $log->debug("Image successfully downloaded.");
        return 1;
    }
    else {
        $log->debug("Image download failed.");
        return 0;
    }
}

# funzione che converte le immagini per visualizzarle correttamente all'interno del PDF
sub check_fix_imgs {
    my $img = shift;

    # regex per estrarre il nome dell'immagine senza estensione
    my $name_to_convert = $1 if $img =~ /(\d+\/file-\d+-\d+)/; # solo per le immagini

    # regex per estrarre il nome della directory in cui sono salvate le immagini
    $imgs_dir = $1 if $img =~ /(\d+\/)/;
    make_path($url_taratura.$imgs_dir);
    $log->info($imgs_dir);

    my $conv_imgs_path = "$url_taratura"."$name_to_convert".".png";

    $imgs_path = $url_taratura.$img;

    $log->info("PATH: $imgs_path");
    $log->info("CONV PATH: $conv_imgs_path");

    # conversione immagini in PNG per visualizzarle sul PDF
    system("convert $imgs_path $conv_imgs_path");

    # verifica esistenza file convertito
    if (-e $conv_imgs_path) {
        # utilizzo di 'pngquant' per il resize dell'immagine convertita
        system("pngquant $conv_imgs_path --output $conv_imgs_path --force");

        return $conv_imgs_path;
    } else {
        return "$abs_path/inc/facsimile.jpg";
    }
}
