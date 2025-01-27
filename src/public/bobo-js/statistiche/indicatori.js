/**
 * Document ready.
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var tblPdf;

    // @TODO da togliere in futuro
    $('#networks, #networks2, #networks3').val(-1);

    $('#networks, #networks2, #networks3').select2();
    $('#provinces, #provinces2, #provinces3').select2();

    // FIRST TAB
    /////////////////////////////////////////////////////////////////////////
{
    // Daterange pickers initialization
    $('#pdf-daily-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(-1, 'day').format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });
    // set default date
    $('#pdf-daily-date').bootstrapMaterialDatePicker('setDate', moment().add(-1, 'day').format("DD/MM/YYYY"));

    // datatable initialization
    tblPdf = $('#pdf-download-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
        ],
        "order": [[ 0, "desc" ]]
    });

    /**
     * Action for the statistic calculation button
     */
    $('#stats-calc').on('click', function(e){
        e.preventDefault();

        // get selected date
        var dt   = $('#pdf-daily-date').val();
        // get selected network
        var net  = $('#networks3').val();
        // check network and return if equal to -1
        if(net == -1){
            swal("Attenzione!", "Selezionare una rete di appartenenza", "error");
            return false;
        }
        // get selected province
        var prov = $('#provinces3').val();
        // check province and return if equal to -1
        if(prov == -1){
            swal("Attenzione!", "Selezionare una provincia di appartenenza", "error");
            return false;
        }

        // send calculation request to server via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_indicatori_put_stats_calculation',
            type: "post",
            dataType: "json",
            data: {
                dt  : moment(dt, 'DD-MM-YYYY').format('YYYY-MM-DD'),
                net : net,
                prov: prov
            },
        })
        .done(function(result) {

            // check result
            // if 1 then show success message, start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result == 1){
                swal("Richiesta inoltrata", "Al termine del processo riceverai una notifica", "info");
                startNotifier();
            }
            else if(result == -1)
                swal({
                    title: "Attenzione",
                    text: "Il processo è <strong>già in esecuzione con i parametri selezionati</strong>: attenderne la conclusione per rilanciarlo!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il calcolo delle statistiche", "error");
        });

    });

    /**
     *  Action for the pdf creation button
     */
    $('#stats-pdf').on('click', function(e){
        e.preventDefault();

        // get selected date
        var dt   = $('#pdf-daily-date').val();
        // get selected network
        var net  = $('#networks3').val();
        // check network and return if equal to -1
        if(net == -1){
            swal("Attenzione!", "Selezionare una rete di appartenenza", "error");
            return false;
        }
        // get selected province
        var prov = $('#provinces3').val();
        // check province and return if equal to -1
        if(prov == -1){
            swal("Attenzione!", "Selezionare una provincia di appartenenza", "error");
            return false;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // send pdf creation request via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_indicatori_put_pdf_by_date_net',
            type: "post",
            dataType: "json",
            data: {
                dt  : moment(dt, 'DD-MM-YYYY').format('YYYY-MM-DD'),
                net : net,
                prov: prov
            },
        })
        .done(function(result) {

            // check result
            // if OK then show suces message and refresh pdf list
            // else error
            if(result.res == 'OK'){
                swal("Successo!", "Il PDF è stato creato correttamente", "success");
                loadPdfList();
            }
            else{
                // error message
                swal("Errore!", result.desc, "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante la creazione del PDF", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

    // first load of pdf list
    loadPdfList();
}
    // SECOND TAB
    /////////////////////////////////////////////////////////////////////////
{
    $('#tab-period-data').hide();

    // Daterange pickers initialization
    $('#report-daily-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(-1, 'day').format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });
    // set default date
    $('#report-daily-date').bootstrapMaterialDatePicker('setDate', moment().add(-1, 'day').format("DD/MM/YYYY"));

    /**
     * filters change event
     */
    $('#report-daily-date, #networks, #provinces').on('change', function(){
        // refresh list of data
        loadDataByDate();
        // based on user selection, create content body title
        var net = ( $('#networks').val() == -1 ? 'tutte le reti' : $('#networks option:selected').text() );
        var prov = ( $('#provinces').val() == -1 ? 'tutte le province' : $('#provinces option:selected').text() );

        $('#tab-prov .subtitle-tabbing strong').text(net+' - '+prov);
    });
}
    // THIRD TAB
    /////////////////////////////////////////////////////////////////////////
{
    $('#tab-staz-data').hide();
    // variable for loadDataByStation function
    var dateTo = moment().add(-1, 'day').format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(6, 'days').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().add(-1, 'day').subtract(6, 'days'), moment().add(-1, 'day')],
            'Ultimo mese': [moment().add(-1, 'day').subtract(1, 'month'), moment().add(-1, 'day')],
            'Ultimo 2 mesi': [moment().add(-1, 'day').subtract(2, 'months'), moment().add(-1, 'day')],
            'Ultimo 6 mesi': [moment().add(-1, 'day').subtract(6, 'months'), moment().add(-1, 'day')],
            'Ultimo anno': [moment().add(-1, 'day').subtract(1, 'year'), moment().add(-1, 'day')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');
        // get selected station
        var stid = $('#stations').val();
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);

    });

    $("#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    /**
     * Network/Province filters change event
     */
    $( "#networks2, #provinces2" ).on( "change", function() {
        var net = $('#networks2').val();
        var prid = $('#provinces2').val();
        var dest = $('#provinces2').data('change');

        // refresh list of stations based on user selection
        loadStations(net, prid);
    });

    /**
     * Station filter change event
     */
    $( "#stations" ).on( "change", function() {

        var stid = $(this).val();
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);
        // update content body title with the name of selected station
        var stat = $( "#stations option:selected" ).text();

        $('#tab-staz .subtitle-tabbing strong').text(stat);
    });

    // trigger change event in order to fill station filter for the first time
    $('#provinces2').trigger('change');
}

    // UTILITIES

    /**
     * Function to get the correct class for the table header.
     *
     * @param {integer} index Position of the table's line.
     *
     * @returns If even, "";
     *          If odd, the HTML class "tbl-bg-head";
     */
    function getHeaderClass(index){
        if(index % 2 != 0)
            return 'tbl-bg-head';
        else
            return '';
    }

    /**
     * Function to get the correct class for exceeded values (red and bold).
     *
     * @param {boolean} exceedFlag Boolean value for exceedences.
     *
     * @returns If true, the HTML classes "text-danger" and "font-weight-bold";
     *          If false, "";
     */
    function getClass(exceedFlag){
        if(exceedFlag == true)
            return 'text-danger font-weight-bold';
        else
            return '';
    }

    // LOADS

    /**
     * Function that retrieves the stations of a given network and of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     */
    function loadStations(net, prid){

        var jqxhr = $.ajax({
            url: '/stat_indicatori_get_stations',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
            },
        })
        .done(function(result) {
            // check if result is OK
            if(result.res == 'OK'){
                $('#stations').empty();
                var stations = result.stations;

                // variable for dinamically building the html
                var opts = '';
                var net;

                // loop through all elements
                // for each station, build a html option to be added to the optgroup
                $.each(stations, function(index, station){
                    // check if the current looped station is associated to a different network then the previous one
                    //  - if true then set a new optgroup for the new network
                    if(net != station.station_network_type_id){
                        if(index != 0)
                            opts += '</optgroup>';

                        net = station.station_network_type_id;
                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                    }

                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });
                // append options
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    };

    /**
     * Function that retrieves the pdf list of the calculated statistics.
     * No args needed
     */
    function loadPdfList(){

        // if defined clear table
        if(tblPdf)
            tblPdf.clear();
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        var jqxhr = $.ajax({
            url: '/stat_indicatori_get_pdf_files',
            type: "post",
            dataType: "json",
        })
        .done(function(result) {
            var files = result.files;
            console.dir(result);
            // variable for dinamically building the html
            var html= '';
            // check if at least one element exists
            if( files.length > 0 ){
                // loop through all elements
                // for each file, build a html row to be added to the datable
                $.each(files, function(index, file) {
                    var filename = file.name;
                    // .*\/\d{4}\/\d{2}\/(.*\.pdf)
                    // .*\/\d{4}\/\d{2}\/.*(\d{4}-\d{2}-\d{2})\.pdf
                    var fileUrl  = filename.match(/(downloads.*\.pdf)/)[1];
                    var fileName = filename.match(/.*\/\d{4}\/\d{2}\/(.*\.pdf)/)[1];
                    var fileDate = filename.match(/.*\/\d{4}\/\d{2}\/.*(\d{4}-\d{2}-\d{2})\.pdf/)[1];
                    var fileVersion = Math.random().toString(36).replace('0.', '');

                    var lastModified = moment.unix(file.mtime).format('DD-MM-YYYY HH:mm');

                    html += '<tr>';
                    html += '   <td>'+getFormattedDateDT(fileDate, 'basic')+'</td>';
                    html += '   <td>'+lastModified+'</td>';
                    html += '   <td>'+fileName+'</td>';
                    html += '   <td><a href="/'+fileUrl+'?v='+fileVersion+'" target="_blank" class="text-danger"><strong><i class="fa fa-file-pdf-o" aria-hidden="true"></i> PDF</strong></a></td>';
                    html += '   <td></td>';
                    html += '</tr>';
                });
                // add rows to datatable by using html object
                tblPdf.rows.add($( html ));
                // redraw it
                tblPdf.draw();
                // adjust columns size
                tblPdf.columns.adjust();

                // initializes the tooltips of all lines
                // loop through each table row contained in all pages (not only the visible one )
                tblPdf.rows({page: 'all'}).every(function() {
                    var row = this;
                    // get all tr node and transform it into a jquery items
                    // in order to find all tooltip elements
                    $(row.node())
                        .find('[data-toggle="tooltip"]')
                        .tooltip();
                });

            } else {
                tblPdf.draw();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei PDF", "error");
            tblPdf.draw();
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    };

    /**
     * Function that retrieves the data of the calculated statistics of a given date.
     * No args needed
     */
    function loadDataByDate(){
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // reset all table elements (header, body and footer)
        $('#tab-period-data').hide();
        $('#dynamic-daily-table thead').empty();
        $('#dynamic-daily-table tbody').empty();
        $('#dynamic-daily-table tfoot').empty();

        // get data selected by the user
        var dt   = $('#report-daily-date').val();
        var net  = $('#networks').val();
        var prov = $('#provinces').val();

        // get statistics via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_indicatori_get_table_by_date',
            type: "post",
            dataType: "json",
            data:{
                dt: moment(dt, 'DD-MM-YYYY').format('YYYY-MM-DD'),
                net: net,
                prov: prov
            }
        })
        .done(function(result) {

            console.dir(result);
            // variables for dinamically building the html
            var htmlHead    = '';
            var htmlBody    = '';
            var htmlFooter  = '';

            // check result
            // if OK build all table components and append them
            // else error
            if(result.res == 'OK'){

                var header = result.header;

                // labels_obj: "[{\"statistic\" : \"media oraria\", \"metrics\" : [\"conc max (µg/m³)\",\"n° sup da inizio anno\",\"n° sup allarme\"]}, {\"statistic\" : \"media 24 ore\", \"metrics\" : [\"conc (µg/m³)\",\"n° sup da inizio anno\"]}, {\"statistic\" : \"media annuale\", \"metrics\" : [\"conc (µg/m³)\"]}, {\"statistic\" : \"\", \"metrics\" : [\"conc (µg/m³)\"]}]"
                // pollutant_id: 1
                // pollutant_notation: "SO2"

                // check header lenth
                // if equal to 0 then no statistics found -> warning message
                if(header.length != 0){

                    // ATTENZIONE HEADER CONSTRUCTION
                    // to even pollutants add class .tbl-bg-head in header and footer
                    htmlHead += '<tr class="text-center">';
                    htmlHead += '<th></th>;';

                    // polluntants row
                    $.each(header, function(idx, el){
                        // parse object
                        var labels = JSON.parse(el.labels_obj);
                        var cnt = 0;
                        // colspan equal to the number of metrics of all pollutant statistics
                        $.each(labels, function(idx2, el2){
                            cnt += el2.metrics.length;
                        });

                        htmlHead += '    <th class="'+getHeaderClass(idx)+'" colspan="'+cnt+'">'+el.pollutant_notation+'</th>';

                    });

                    // close header row
                    htmlHead += '</tr>';
                    // open statistics row
                    htmlHead += '<tr class="text-center">';
                    htmlHead += '    <th></th>';

                    // statistics row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){

                            htmlHead += '    <th class="'+getHeaderClass(idx)+'" colspan="'+el2.metrics.length+'">'+el2.statistic+'</th>';
                        });
                    });

                    htmlHead += '</tr>';
                    htmlHead += '<tr class="text-vertical">';
                    htmlHead += '    <th>STAZIONI</th>';

                    // row of metrics for each statistics
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){
                            $.each(el2.metrics, function(idx3, metric){
                                htmlHead += '    <th class="'+getHeaderClass(idx)+'">'+metric+'</th>';
                            });
                        });
                    });
                    htmlHead += '</tr>';
                    // ATTENZIONE END HEADER CONSTRUCTION

                    // ATTENZIONE BODY CONSTRUCTION
                    // object in order to save last loop data
                    var old = {
                        station: null,
                        pollutant: null,
                        stat: null
                    };
                    var data = result.data;
                    // for each data build an html row
                    $.each(data, function(idx, el){

                        // if previous station not equal to current one and it isn't the first loop
                        // then close current row, open a new one and add station name row header
                        if(old.station != el.station_id){
                            if(idx != 0)
                                htmlBody += '</tr>';

                            htmlBody += '<tr>';
                            htmlBody += '<th>'+el.station_name+'</th>';

                            old.station = el.station_id;
                            old.pollutant = null;
                        }
                        // if previous pollutant not equal to the current one
                        // then update old object variables
                        if(old.pollutant != el.pollutant_id){
                            old.pollutant = el.pollutant_id;
                            old.stat = null;
                        }
                        // build a different td element based on statistic type and data value
                        if(old.stat != el.stat_id && el.stat_id <= 3 && el.type_num_sup == true ){
                            if(el.stpr_id == null)
                                htmlBody += '<td class="text-muted font-italic">nr</td>';
                            else if(el.res_value == null || el.res_aggrules == false)
                                htmlBody += '<td class="text-muted font-italic">nd</td>';
                            else{
                                htmlBody += '<td class="'+getClass(el.res_exceed_value)+'">'+el.res_value+'</td>';
                            }
                        }

                        var value;
                        var flag;
                        if(el.type_num_sup == true){
                            value = el.res_num_sup;
                            flag  = el.res_exceed_num_sup;
                        }
                        else{
                            value = el.res_value;
                            flag  = el.res_exceed_value;
                        }
                        // build a different td element based on data value and exceeded flag value
                        if(el.stpr_id == null)
                            htmlBody += '<td class="text-muted font-italic">nr</td>';
                        else if(value == null || el.res_aggrules == false)
                            htmlBody += '<td class="text-muted font-italic">nd</td>';
                        else
                            htmlBody += '<td class="'+getClass(flag)+'">'+value+'</td>';

                        old.stat = el.stat_id;
                    });

                    htmlBody += '</tr>';
                    // ATTENZIONE END BODY CONSTRUCTION

                    // ATTENZIONE FOOTER CONSTRUCTION
                    htmlFooter += '<tr class="text-vertical">';
                    htmlFooter += '    <th>STAZIONI</th>';

                    // row of metrics for each statistic
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){
                            $.each(el2.metrics, function(idx3, metric){
                                htmlFooter += '    <th class="'+getHeaderClass(idx)+'">'+metric+'</th>';
                            });
                        });
                    });
                    htmlFooter += '</tr>';
                    htmlFooter += '<tr class="text-center">';
                    htmlFooter += '    <th></th>';

                    // statistic row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){

                            htmlFooter += '    <th class="'+getHeaderClass(idx)+'" colspan="'+el2.metrics.length+'">'+el2.statistic+'</th>';
                        });
                    });

                    htmlFooter += '</tr>';

                    htmlFooter += '<tr class="text-center">';
                    htmlFooter += '<th></th>;';

                    // polluntants row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        var cnt = 0;
                        $.each(labels, function(idx2, el2){
                            cnt += el2.metrics.length;
                        });

                        htmlFooter += '    <th class="'+getHeaderClass(idx)+'" colspan="'+cnt+'">'+el.pollutant_notation+'</th>';

                    });

                    htmlFooter += '</tr>';
                    // ATTENZIONE END FOOTER CONSTRUCTION

                    // append html
                    $('#dynamic-daily-table thead').append(htmlHead);
                    $('#dynamic-daily-table tbody').append(htmlBody);
                    $('#dynamic-daily-table tfoot').append(htmlFooter);
                    // show table
                    $('#tab-period-data').show();
                }
                else{
                    // warning message
                   swal("Attenzione", "Non è stata trovata nessuna statistica!", "info");
                }

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that retrieves the data of the calculated statistics of a given station of a given period.
     *
     * @param {integer} dateFrom Period start date.
     * @param {integer} dateTo Period end date.
     * @param {integer} stid Station ID.
     */
    function loadDataByStation(dateFrom, dateTo, stid){
        if(stid == -1)
            return;
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // reset all table elements (header, body and footer)
        $('#tab-staz-data').hide();
        $('#dynamic-staz-table thead').empty();
        $('#dynamic-staz-table tbody').empty();
        $('#dynamic-staz-table tfoot').empty();

        // get statistics via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_indicatori_get_table_by_station',
            type: "post",
            dataType: "json",
            data:{
                from: dateFrom,
                to: dateTo,
                stid: stid
            }
        })
        .done(function(result) {

            console.dir(result);
            // variables for dinamically building the html
            var htmlHead    = '';
            var htmlBody    = '';
            var htmlFooter  = '';

            // check result
            // if OK build all table components and append them
            // else error
            if(result.res == 'OK'){

                var header = result.header;

                // labels_obj: "[{\"statistic\" : \"media oraria\", \"metrics\" : [\"conc max (µg/m³)\",\"n° sup da inizio anno\",\"n° sup allarme\"]}, {\"statistic\" : \"media 24 ore\", \"metrics\" : [\"conc (µg/m³)\",\"n° sup da inizio anno\"]}, {\"statistic\" : \"media annuale\", \"metrics\" : [\"conc (µg/m³)\"]}, {\"statistic\" : \"\", \"metrics\" : [\"conc (µg/m³)\"]}]"
                // pollutant_id: 1
                // pollutant_notation: "SO2"

                // check header lenth
                // if equal to 0 then no statistics found -> warning message
                if(header.length != 0){

                    // ATTENZIONE HEADER CONSTRUCTION
                    // to even pollutants add class .tbl-bg-head in header and footer
                    htmlHead += '<tr class="text-center">';
                    htmlHead += '<th></th>;';
                    // polluntants row
                    $.each(header, function(idx, el){
                        // parse object
                        var labels = JSON.parse(el.labels_obj);
                        var cnt = 0;
                        // colspan equal to the number of metrics of all pollutant statistics
                        $.each(labels, function(idx2, el2){
                            cnt += el2.metrics.length;
                        });

                        htmlHead += '    <th class="'+getHeaderClass(idx)+'" colspan="'+cnt+'">'+el.pollutant_notation+'</th>';

                    });

                    // close header row
                    htmlHead += '</tr>';
                    // open statistic row
                    htmlHead += '<tr class="text-center">';
                    htmlHead += '    <th></th>';

                    // statistics row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){

                            htmlHead += '    <th class="'+getHeaderClass(idx)+'" colspan="'+el2.metrics.length+'">'+el2.statistic+'</th>';
                        });
                    });

                    // close statistics row
                    htmlHead += '</tr>';
                    // open metrics row
                    htmlHead += '<tr class="text-vertical">';
                    htmlHead += '    <th>Giorni</th>';

                    // metrics row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){
                            $.each(el2.metrics, function(idx3, metric){
                                htmlHead += '    <th class="'+getHeaderClass(idx)+'">'+metric+'</th>';
                            });
                        });
                    });
                    htmlHead += '</tr>';
                    // ATTENZIONE END HEADER CONSTRUCTION

                    // ATTENZIONE BODY CONSTRUCTION

                    // object in order to save last loop data
                    var old = {
                        date: null,
                        pollutant: null,
                        stat: null
                    };
                    var data = result.data;
                    // for each data build an html row
                    $.each(data, function(idx, el){
                        // if previous date not equal to current one and it isn't the first loop
                        // then close current row, open a new one and add date row header
                        if(old.date != el.res_date){
                            if(idx != 0)
                                htmlBody += '</tr>';

                            htmlBody += '<tr>';
                            htmlBody += '<th>'+moment(el.res_date).format('DD-MM-YYYY')+'</th>';

                            old.date = el.res_date;
                            old.pollutant = null;
                        }
                        // if previous pollutant not equal to the current one
                        // then update old object variables
                        if(old.pollutant != el.pollutant_id){
                            old.pollutant = el.pollutant_id;
                            old.stat = null;
                        }
                        // build a different td element based on statistic type and data value
                        if(old.stat != el.stat_id && el.stat_id <= 3 && el.type_num_sup == true ){
                            console.log('add conc');
                            if(el.stpr_id == null)
                                htmlBody += '<td class="text-muted font-italic">nr</td>';
                            else if(el.res_value == null || el.res_aggrules == false)
                                htmlBody += '<td class="text-muted font-italic">nd</td>';
                            else
                                htmlBody += '<td class="'+getClass(el.res_exceed_value)+'">'+el.res_value+'</td>';
                        }

                        var value;
                        var flag;
                        if(el.type_num_sup == true){
                            value = el.res_num_sup;
                            flag  = el.res_exceed_num_sup;
                        }
                        else{
                            value = el.res_value;
                            flag  = el.res_exceed_value;
                        }
                        // build a different td element based on data value and exceeded flag value
                        if(el.stpr_id == null)
                            htmlBody += '<td class="text-muted font-italic">nr</td>';
                        else if(value == null || el.res_aggrules == false)
                            htmlBody += '<td class="text-muted font-italic">nd</td>';
                        else
                            htmlBody += '<td class="'+getClass(flag)+'">'+value+'</td>';

                        old.stat = el.stat_id;
                    });

                    htmlBody += '</tr>';
                    // ATTENZIONE END BODY CONSTRUCTION

                    // ATTENZIONE FOOTER CONSTRUCTION
                    htmlFooter += '<tr class="text-vertical">';
                    htmlFooter += '    <th>Giorni</th>';
                    // metrics row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){
                            $.each(el2.metrics, function(idx3, metric){
                                htmlFooter += '    <th class="'+getHeaderClass(idx)+'">'+metric+'</th>';
                            });
                        });
                    });
                    htmlFooter += '</tr>';

                    htmlFooter += '<tr class="text-center">';
                    htmlFooter += '    <th></th>';
                    // statistics row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        $.each(labels, function(idx2, el2){

                            htmlFooter += '    <th class="'+getHeaderClass(idx)+'" colspan="'+el2.metrics.length+'">'+el2.statistic+'</th>';
                        });
                    });
                    htmlFooter += '</tr>';

                    htmlFooter += '<tr class="text-center">';
                    htmlFooter += '    <th></th>;';
                    // pollutants row
                    $.each(header, function(idx, el){

                        var labels = JSON.parse(el.labels_obj);
                        var cnt = 0;
                        $.each(labels, function(idx2, el2){
                            cnt += el2.metrics.length;
                        });

                        htmlFooter += '    <th class="'+getHeaderClass(idx)+'" colspan="'+cnt+'">'+el.pollutant_notation+'</th>';

                    });
                    htmlFooter += '</tr>';
                    // ATTENZIONE END FOOTER CONSTRUCTION

                    // append html
                    $('#dynamic-staz-table thead').append(htmlHead);
                    $('#dynamic-staz-table tbody').append(htmlBody);
                    $('#dynamic-staz-table tfoot').append(htmlFooter);
                    // show table
                    $('#tab-staz-data').show();
                }
                else{
                    // warning message
                   swal("Attenzione", "Non è stata trovata nessuna statistica!", "info");
                }

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };
});