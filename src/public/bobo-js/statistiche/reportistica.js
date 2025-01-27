var funcRef;

/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var tblPdf;

    // First TAB
    /////////////////////////////////////////////////////////////////////////
{
    $('.hide-day, .hide-month, .hide-year').hide();
    $('#stats-calc, #stats-pdf').prop('disabled', true);

    // Daterange pickers initialization
    $('#stats-day').bootstrapMaterialDatePicker({
        maxDate: moment().add(-1, 'day').format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });
    // set default date
    $('#stats-day').bootstrapMaterialDatePicker('setDate', moment().add(-1, 'day').format("DD/MM/YYYY"));

    var end = moment().format("MM/YYYY");
    // Daterange pickers initialization
    $('#stats-month').datepicker({
        format: 'mm/yyyy',
        viewMode: 'months',
        minViewMode: 'months',
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        endDate: moment().format('MM/YYYY'),
    });

    $('#stats-month').datepicker('update', end);

    var end2 = moment().format("YYYY");
    // Daterange pickers initialization
    $('#stats-year').datepicker({
        format: 'yyyy',
        viewMode: 'years',
        minViewMode: 'years',
        // endDate: end,
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        endDate: moment().format('YYYY'),
    });

    // set default date
    $('#stats-year').datepicker('update', end2);

    $('#stats-signature').select2();

    // change event on principal fields (type, date and zone)
    $('#stats-type, #stats-day, #stats-month, #stats-year, #stats-zone').on('change', function(){
        // disable buttons
        $('#stats-calc, #stats-pdf').prop('disabled', true);
    });

    $( "#stats-type" ).on( "change", function() {
        var type = $(this).val();
        //console.log(type);
        switch (parseInt(type)) {
            case 0:
                $('.hide-day, .hide-month, .hide-year').hide();
                break;
            case 1:
                $('.hide-month, .hide-year').hide();
                $('.hide-day').show();
                break;
            case 2:
                $('.hide-day, .hide-year').hide();
                $('.hide-month').show();
                break;
            case 3:
                $('.hide-day, .hide-month').hide();
                $('.hide-year').show();
                break;
        }
    });

    $('#stats-zone').on('change', function(){

        // get zone id
        var zone = parseInt($(this).val());
        var dest = $(this).data('dest');
        // reset stations select
        $('#'+dest).empty();
        // if -1 then return
        if(zone == -1){
            $('#'+dest).append('<option value="-1">Seleziona inquinante...</option>');
            return;
        }

        // refresh stations list
        loadParametersByZone(zone, dest);
    });

    // validate form
    var validator = $('#stats-form').validate({ // initialize the plugin
        rules: {
            "stats-type":{
                required: true,
                min: 0
            },
            "stats-network":{
                required: true,
                min: 0
            },
            "stats-zone":{
                required: true,
                min: 0
            },
            "stats-day":{
                required: true
            },
            "stats-month":{
                required: true
            },
            "stats-year":{
                required: true
            },
            "stats-signature":{
                required: true,
                min: 0
            },
            "stats-param":{
                required: true,
                min: 0
            }
        },
        messages: {
            "stats-type":{
                required: "Selezionare tipologia",
                min: "Selezionare tipologia"
            },
            "stats-network":{
                required: "Selezionare rete",
                min: "Selezionare rete"
            },
            "stats-zone":{
                required: "Selezionare zona",
                min: "Selezionare zona"
            },
            "stats-day" : {
                required: "Selezionare giorno"
            },
            "stats-month" : {
                required: "Selezionare mese"
            },
            "stats-year" : {
                required: "Selezionare anno"
            },
            "stats-signature" : {
                required: "Selezionare firmatario",
                min: "Selezionare firmatario"
            },
            "stats-param" : {
                required: "Selezionare inquinante",
                min: "Selezionare inquinante"
            }
        },
        ignore: ":hidden",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        }
    });

    $('#stats-status').on('click', function(e) {
        e.preventDefault();

        $('#check-results').empty();

        var type = parseInt($('#stats-type').val());
        var zone = parseInt($('#stats-zone').val());

        // check form validity
        if(type == -1 || zone == -1 ){
            swal("Attenzione!", "I campi Tipologia e/o Zona non sono stati completati. Impossibile proseguire", "info");
            return false;
        }

        var from;
        var to;
        switch(type){
            case 1: // giornaliero
                var day = $('#stats-day').val();
                from = moment(day, 'DD/MM/YYYY').format('YYYY-MM-DD 00:00');
                to = moment(day, 'DD/MM/YYYY').format('YYYY-MM-DD 23:59');
                break;
            case 2:
                var month = $('#stats-month').val();
                from = moment(month, 'MM/YYYY').startOf('month').format('YYYY-MM-DD 00:00');
                to = moment(month, 'MM/YYYY').endOf('month').format('YYYY-MM-DD 23:59');
                break;
            case 3:
                var year = $('#stats-year').val();
                from = moment(year, 'YYYY').startOf('year').format('YYYY-MM-DD 00:00');
                to = moment(year, 'YYYY').endOf('year').format('YYYY-MM-DD 23:59');
                break;
            default:
                var day = $('#stats-day').val();
                from = moment(day, 'DD/MM/YYYY').format('YYYY-MM-DD 00:00');
                to = moment(day, 'DD/MM/YYYY').format('YYYY-MM-DD 23:59');
                break;
        };
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // send calculation request to server via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_check_data',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                zone: $('#stats-zone').val()
            }
        })
        .done(function(result) {
            console.dir(JSON.parse(result));

            result = JSON.parse(result);

            // check result
            // if 1 then show success message, start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result.res ){
                swal("Controllo completato", "I dati sono stati controllati e risultano essere tutti corretti!", "success");

                $('#stats-calc').prop('disabled', false);
            }
            else {
                var negatives = result.negatives;
                var suspects  = result.suspects;
                var notChecked = result.not_checked;
                var codeDifferences = result.code_diff;
                var pm10Problems = result.pm10_prob;

                var totalMessage = '';
                if( ! $.isEmptyObject(negatives) ){

                    totalMessage += '<h4>Presenza <strong>dati negativi</strong> per gli inquinanti</h4>';
                    totalMessage += '<ul>';
                    for (const key in negatives) {

                        var obj = negatives[key];
                        totalMessage += '<li><strong>'+obj.name+'</strong> - '+obj.params.join(', ')+'</li>';
                    }
                    totalMessage += '</ul>';
                }

                if( ! $.isEmptyObject(suspects) ){

                    totalMessage += '<h4>Presenza <strong>dati sospetti</strong> per gli inquinanti</h4>';
                    totalMessage += '<ul>';
                    for (const key in suspects) {

                        var obj = suspects[key];
                        totalMessage += '<li><strong>'+obj.name+'</strong> - '+obj.params.join(', ')+'</li>';
                    }
                    totalMessage += '</ul>';
                }

                if(! $.isEmptyObject(notChecked)){

                    totalMessage += '<h4>Presenza <strong>dati non validati</strong> per gli inquinanti</h4>';
                    totalMessage += '<ul>';
                    for (const key in notChecked) {

                        var obj = notChecked[key];
                        totalMessage += '<li><strong>'+obj.name+'</strong> - '+obj.params.join(', ')+'</li>';
                    }
                    totalMessage += '</ul>';
                }

                if(! $.isEmptyObject(codeDifferences)){

                    totalMessage += '<h4>Presenza <strong>validazioni diverse</strong> per NOX,NO,NO2</h4>';
                    totalMessage += '<ul>';
                    for (const key in codeDifferences) {

                        var obj = codeDifferences[key];
                        // totalMessage += '<li><strong>'+obj.name+'</strong> - '+obj.dates.map(function (d) { return moment(d).format('DD/MM/YYYY'); }).join(', ')+'</li>';
                        totalMessage += '<li><strong>'+obj.name+'</strong></li>';
                    }
                    totalMessage += '</ul>';
                }

                if(! $.isEmptyObject(pm10Problems)){

                    totalMessage += '<h4>Presenza <strong>problemi per PM10</strong></h4>';
                    totalMessage += '<ul>';
                    for (const key in pm10Problems) {

                        var obj = pm10Problems[key];
                        totalMessage += '<li><strong>'+obj.name+'</strong></li>';
                    }
                    totalMessage += '</ul>';
                }

                $('#check-results').append(totalMessage);
                $('#check-data-res').modal('show');

            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il controllo dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    $('#stats-calc').on('click', function(e) {
        e.preventDefault();

        var form = $('#stats-form');

        // check form validity
        if(! form.valid() ){
            swal("Attenzione!", "Sono presenti dei campi incompleti. Impossibile proseguire", "error");
            return false;
        }

        // send calculation request to server via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_put_stats_calculation',
            type: "post",
            dataType: "json",
            data: form.serialize()
        })
        .done(function(result) {

            // check result
            // if 1 then show success message, start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result == 1){
                swal("Richiesta inoltrata", "Al termine del processo riceverai una notifica", "info");
                startNotifier(notifierCallback);
            }
            else if(result == -1){
                swal({
                    title: "Attenzione",
                    text: "Il processo è <strong>già in esecuzione con i parametri selezionati</strong>: attenderne la conclusione per rilanciarlo!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il calcolo delle statistiche", "error");
        });
    });

    $('#stats-pdf').on('click', function(e) {
        e.preventDefault();

        var form = $('#stats-form');

        // check form validity
        if(! form.valid() ){
            swal("Attenzione!", "Sono presenti dei campi incompleti. Impossibile proseguire", "error");
            return false;
        }

        var type = parseInt($('#stats-type').val());
        var msg_ok;
        if(type)
            msg_ok = 'Il PDF è stato creato correttamente. Troverai il nuovo file nell\'archivio';
        else
            msg_ok = 'I PDF sono stati creati correttamente. Troverai i nuovi file nell\'archivio';

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // create pdf via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_put_pdf',
            type: "post",
            dataType: "json",
            data: form.serialize()
        })
        .done(function(result) {

            // check result
            // if 1 then show success message, start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result.res == 'OK'){
                swal("Successo!", msg_ok, "success");
                loadReports();
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
            swal("Errore!", "Errore durante la generazione del PDF", "error");
        });
    });

    $('#stats-cancel').on('click', function(e) {
        e.preventDefault();

        // clear form
        clearFields();
    });

    // MODAL
    // $('#check-data-copy').on('click', function(e) {
    //     e.preventDefault();

    //     copyToClipboard('#check-results');
    // });

    // variable for loadDataByStation function
    var filterDateTo = moment().add(-1, 'day').format('YYYY-MM-DD 23:59:59');
    var filterDateFrom = moment(filterDateTo).subtract(6, 'days').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var startF = moment(filterDateFrom).format("DD/MM/YYYY");
    var endF = moment(filterDateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#filter-date').daterangepicker({
        startDate: startF,
        endDate: endF,
        maxDate: endF,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().add(-1, 'day').subtract(6, 'days'), moment().add(-1, 'day')],
            'Ultimo mese': [moment().add(-1, 'day').subtract(1, 'month'), moment().add(-1, 'day')],
            'Ultimi 2 mesi': [moment().add(-1, 'day').subtract(2, 'months'), moment().add(-1, 'day')],
            'Ultimi 6 mesi': [moment().add(-1, 'day').subtract(6, 'months'), moment().add(-1, 'day')],
            'Ultimo anno': [moment().add(-1, 'day').subtract(1, 'year'), moment().add(-1, 'day')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(startF, endF, label) {

        //on change event, get reports within new daterange
        console.log(startF.format('YYYY-MM-DD'), endF.format('YYYY-MM-DD'), label);
        filterDateFrom = startF.format('YYYY-MM-DD 00:00');
        filterDateTo = endF.format('YYYY-MM-DD 23:59:59');
        // load reports
        loadReports();
    });

    // datatable initialization
    tblPdf = $('#stats-table').DataTable({
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
            },
            { "orderable": false, "targets": 0 },
            { "width": "30%", "targets": 7 }
        ],
        "order": [[ 8, "desc" ]]
    });

    $('#filter-type, #filter-zone').on('change', function(){

        loadReports();
    });

    /**
     * Delete report.
     */
    $('#stats-table').on('click', '.delete-report', function(e){
        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        // confirm message in order to continue in report deleting
        swal({
            title: "Stai per eliminare il report",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/stat_reportistica_del_report',
                type: "post",
                dataType: "json",
                data: {
                    id: rpid
                }
            })
            .done(function(result) {
                // check result
                //  - if '1' then the report is correctly deleted -> remove it from table
                //  - else error
                if(result == 1){
                    // delete row from datatable without reloading the entire list and refresh it
                    swal("Report eliminato", "Il report è stato eliminato con successo!", "success");
                    tblPdf.row($("tr[data-id='"+rpid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del report", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione del report", "error");
            });

        });
    });


    loadReports();
}
    /////////////////////////////////////////////////////////////////////////
    // First TAB

    // Second TAB
    /////////////////////////////////////////////////////////////////////////
{
    $('#tab-staz-data-day').hide();
    $('#tab-staz-data-month').hide();
    $('#tab-staz-data-year').hide();

    // !! STATISTICHE PER STAZIONE

    // variable for loadDataByStation function
    var dateTo = moment().add(-1, 'day').format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(6, 'days').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var startP = moment(dateFrom).format("DD/MM/YYYY");
    var endP = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#show-stats-day').daterangepicker({
        startDate: startP,
        endDate: endP,
        maxDate: endP,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().add(-1, 'day').subtract(6, 'days'), moment().add(-1, 'day')],
            'Ultimo mese': [moment().add(-1, 'day').subtract(1, 'month'), moment().add(-1, 'day')],
            'Ultimi 2 mesi': [moment().add(-1, 'day').subtract(2, 'months'), moment().add(-1, 'day')],
            'Ultimi 6 mesi': [moment().add(-1, 'day').subtract(6, 'months'), moment().add(-1, 'day')],
            'Ultimo anno': [moment().add(-1, 'day').subtract(1, 'year'), moment().add(-1, 'day')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(startP, endP, label) {

        //on change event, get reports within new daterange
        console.log(startP.format('YYYY-MM-DD'), endP.format('YYYY-MM-DD'), label);
        dateFrom = startP.format('YYYY-MM-DD');
        dateTo = endP.format('YYYY-MM-DD 23:59:59');
        // get selected station
        var stid = parseInt($('#show-stats-station-day').val());
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);
    });

    $('#show-stats-zone-day').on('change', function(){

        // get zone id
        var zone = parseInt($(this).val());
        // reset stations select
        $('#show-stats-station-day').empty();
        // if -1 then return
        if(zone == -1){
            $('#show-stats-station-day').append('<option value="-1">Seleziona stazione...</option>');
            return;
        }

        // refresh stations list
        loadStationsByZone(zone);
    });

    $('#show-stats-station-day').on('change', function(){
        // get zone id
        var stid = parseInt($(this).val());
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);
        // update content body title with the name of selected station
        var stat = $( "#show-stats-station-day option:selected" ).text();

        $('#tab-staz-data-day .subtitle-tabbing strong').text(stat);
    });

    // !! STATISTICHE PER MESE - ZONA

    var end = moment().format("MM/YYYY");
    // Daterange pickers initialization
    $('#show-stats-month').datepicker({
        format: 'mm/yyyy',
        viewMode: 'months',
        minViewMode: 'months',
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        endDate: moment().format('MM/YYYY')
    });

    // set default date
    $('#show-stats-month').datepicker('update', end);

    $('#show-stats-zone-month').on('change', function(){

        // get zone id
        var zone = parseInt($(this).val());
        var dest = $(this).data('dest');
        // reset stations select
        $('#show-stats-pollutant-month').empty();
        // if -1 then return
        if(zone == -1){
            $('#show-stats-pollutant-month').append('<option value="-1">Seleziona inquinante...</option>');

            $('#tab-staz-data-month').hide();
            $('#dynamic-staz-table-month thead').empty();
            $('#dynamic-staz-table-month tbody').empty();
            $('#dynamic-staz-table-month tfoot').empty();
            return;
        }

        // refresh stations list
        loadParametersByZone(zone, dest);
    });

    $('#show-stats-month, #show-stats-pollutant-month').on('change', function(){
        // get zone id
        var paramid = parseInt($('#show-stats-pollutant-month').val());

        var zone = $('#show-stats-zone-month').val();
        var month = $('#show-stats-month').val();

        if(paramid != -1){
            // load zone data
            loadDataByZoneType(2, month, zone, paramid);
            // update content body title with the name of selected station
            var zoneTxt = $( "#show-stats-zone-month option:selected" ).text();
            var paramTxt = $( "#show-stats-pollutant-month option:selected" ).text();

            $('#tab-staz-data-month .subtitle-tabbing').html('Hai selezionato <strong>'+paramTxt+'</strong> per la zona <strong>'+zoneTxt+'</strong>');
        }
        else{
            $('#tab-staz-data-month').hide();
            $('#dynamic-staz-table-month thead').empty();
            $('#dynamic-staz-table-month tbody').empty();
            $('#dynamic-staz-table-month tfoot').empty();
        }
    });

    // !! STATISTICHE PER ANNO - ZONA
    // Daterange pickers initialization
    $('#show-stats-year').datepicker({
        format: 'yyyy',
        viewMode: 'years',
        minViewMode: 'years',
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        endDate: moment().format('YYYY')
    });

    // set default date
    $('#show-stats-year').datepicker('update', end2);

    $('#show-stats-zone-year').on('change', function(){
        // get zone id
        var zone = parseInt($(this).val());
        var dest = $(this).data('dest');
        // reset stations select
        $('#show-stats-pollutant-year').empty();
        // if -1 then return
        if(zone == -1){
            $('#show-stats-pollutant-year').append('<option value="-1">Seleziona inquinante...</option>');

            $('#tab-staz-data-year').hide();
            $('#dynamic-staz-table-year thead').empty();
            $('#dynamic-staz-table-year tbody').empty();
            $('#dynamic-staz-table-year tfoot').empty();
            return;
        }

        // refresh stations list
        loadParametersByZone(zone, dest);
    });

    $('#show-stats-year, #show-stats-pollutant-year').on('change', function(){
        // get zone id
        var paramid = parseInt($('#show-stats-pollutant-year').val());

        var zone = $('#show-stats-zone-year').val();
        var year = $('#show-stats-year').val();

        if(paramid != -1){
            // load zone data
            loadDataByZoneType(3, year, zone, paramid);
            // update content body title with the name of selected station
            var zoneTxt = $( "#show-stats-zone-year option:selected" ).text();
            var paramTxt = $( "#show-stats-pollutant-year option:selected" ).text();

            $('#tab-staz-data-year .subtitle-tabbing').html('Hai selezionato <strong>'+paramTxt+'</strong> per la zona <strong>'+zoneTxt+'</strong>');
        }
        else{
            $('#tab-staz-data-year').hide();
            $('#dynamic-staz-table-year thead').empty();
            $('#dynamic-staz-table-year tbody').empty();
            $('#dynamic-staz-table-year tfoot').empty();
        }
    });
}
    /////////////////////////////////////////////////////////////////////////
    // Second TAB

    funcRef = function(){
        $('#stats-pdf').prop('disabled', false);
    };

    // UTILITIES
    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null then returns string '--';
     *         If not null then returns the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    };

    function clearFields(){
        console.log('clearFields');
        // manage input type text
        $('.clear-input').val("");
        // manage select
        $('.clear-select').val(-1);

        $('.hide-day, .hide-month, .hide-year').hide();

        $('#stats-day').bootstrapMaterialDatePicker('setDate', moment().add(-1, 'day').format("DD/MM/YYYY"));
        $('#stats-month').datepicker('update', moment().format("MM/YYYY"));
        $('#stats-year').datepicker('update',  moment().format("YYYY"));

        // disable button
        $('#stats-calc, #stats-pdf').prop('disabled', true);

        // reset form validation
        $('#stats-form').validate().resetForm();
    }

    /**
     * Function to copy element to clipboard.
     *
     * @param {element} element Element
     */
    function copyToClipboard(element){
        // create a temporary input
        var $temp = $("<input>");
        // append it to document body
        $("body").append($temp);
        // set the input value with the text of the element to be copied
        $temp.val($(element).text()).select();
        // execute system command "copy"
        document.execCommand("copy");
        // remove temporary input
        $temp.remove();

        // show success message
        $.toast({
            heading: 'Info',
            text: 'Testo copiato',
            position: 'top-right',
            loaderBg:'#ff6849',
            icon: 'info',
            hideAfter: 3000,
            stack: 6
        });
    }

    /**
     * Function that retrieves the list of stations linked to selected zone
     *
     * @param {integer} zone ID of the zone
     */
    function loadStationsByZone(zone){
        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_stations_by_zone',
            type: "post",
            dataType: "json",
            data: {
                zone: zone
            }
        })
        .done(function(result) {
            // check if result is OK
            if(result.res == 'OK'){
                var stations = result.stations;

                // variable for dinamically building the html
                var opts = '';

                // loop through all elements
                // for each station, build a html option to be added to the optgroup
                $.each(stations, function(index, station){
                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });
                // append options
                $('#show-stats-station-day').append('<option value="-1">Seleziona stazione...</option>');
                $('#show-stats-station-day').append(opts);
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
    }

    /**
     * Function that retrieves the list of parameters linked to stations of the selected zone
     *
     * @param {integer} zone ID of the zone
     * @param {text} destination select
     */
    function loadParametersByZone(zone, dest){
        console.log('loadParametersByZone');

        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_params_by_zone',
            type: "post",
            dataType: "json",
            data: {
                zone: zone
            }
        })
        .done(function(result) {
            // check if result is OK
            if(result.res == 'OK'){
                var params = result.params;

                // variable for dinamically building the html
                var opts = '';

                // loop through all elements
                // for each station, build a html option to be added to the optgroup
                $.each(params, function(index, param){
                    opts += '<option value="'+ param.param_id+'">'+param.param_name+'</option>';
                });

                console.log('#show-stats-pollutant-'+dest);
                // append options
                $('#'+dest).append('<option value="-1">Seleziona inquinante...</option>');
                $('#'+dest).append(opts);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");
        });
    }

    /**
     * Function that retrieves the list of reports for a given typology, zone and in a specific daterange
     *
     */
    function loadReports(){

        var type = parseInt($('#filter-type').val());
        var zone = parseInt($('#filter-zone').val());

        // reset table
        if(tblPdf)
            tblPdf.clear();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_reports',
            type: "post",
            dataType: "json",
            data: {
                from: filterDateFrom,
                to: filterDateTo,
                type: type,
                zone: zone
            },
        })
        .done(function(result) {
            console.dir(result);

            // check result
            // if OK then fill table with data
            // else show error message
            if(result.res == 'OK'){
                var reports = result.reports;
                // check if at least one element exists
                if( reports.length > 0 ){
                    // variable for dynamically building the html
                    var html = '';
                    // loop through all elements
                    // for each row build a html tr to be added to the table
                    reports.forEach(function(el){

                        var res = [];
                        var filename;
                        html += '<tr data-id="'+el.rep_id+'">';
                        html += '    <td class="bobo-nowrap">';
                        if(el.rep_file_name){
                            html += '        <a class="text-info status-icon-little" href="'+el.rep_file_name+'" target="_blank" data-original-title="Scarica PDF" data-toggle="tooltip"><i class="fa-solid fa-arrow-down-to-line"></i></a>';
                            res = el.rep_file_name.match(/^(.+\/)(.+\.pdf)$/);
                            filename = ( res && res.length == 3 ? res[2] : null );
                        }
                        html += '        <a class="text-danger status-icon-littlest delete-report" href="#" target="_blank" data-original-title="Elimina report" data-toggle="tooltip"><i class="fa-regular fa-trash"></i></a>';

                        html += '    </td>';
                        html += '    <td>'+el.rep_date_formatted+'</td>';
                        html += '    <td><span class="badge badge-'+el.rt_color+'"><i class="'+el.rt_icon+'"></i> '+el.rt_name+'</span></td>';
                        html += '    <td>'+formatTextField(filename)+'</td>';
                        html += '    <td>'+el.sz_name+'</td>';
                        html += '    <td>'+formatTextField(el.param_name)+'</td>';
                        html += '    <td>'+formatTextField(el.signer_fullname)+'</td>';
                        html += '    <td>'+formatTextField(el.rep_note)+'</td>';
                        html += '    <td>'+getFormattedDateDT(el.rep_insert_ts, 'basic_timeStartMin')+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblPdf.rows.add($( html ));
                    // redraw it
                    tblPdf.draw();
                    // adjust columns size
                    tblPdf.columns.adjust();

                } else {
                    tblPdf.draw();
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
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    };

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
    function getClass(exceedFlag, value){
        if(exceedFlag == true)
            return 'text-danger font-weight-bold';
        else
            return '';
    }

    /**
     * Function that retrieves the data of the calculated statistics of a given station of a given period.
     *
     * @param {integer} dateFrom Period start date.
     * @param {integer} dateTo Period end date.
     * @param {integer} stid Station ID.
     */
    function loadDataByStation(dateFrom, dateTo, stid){
        // reset all table elements (header, body and footer)
        $('#tab-staz-data-day').hide();
        $('#dynamic-staz-table thead').empty();
        $('#dynamic-staz-table tbody').empty();
        $('#dynamic-staz-table tfoot').empty();

        if(stid == -1)
            return;

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get statistics via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_stats_by_station',
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

                        htmlHead += '    <th class="'+getHeaderClass(idx)+'" colspan="'+cnt+'">'+el.param_name+'</th>';

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
                        // if(old.stat != el.stat_id && el.stat_id <= 3 && el.type_num_sup == true ){
                        //     console.log('add conc');
                        //     if(el.stpr_id == null)
                        //         htmlBody += '<td class="text-muted font-italic">nr</td>';
                        //     else if(el.res_value == null || el.res_aggrules == false)
                        //         htmlBody += '<td class="text-muted font-italic">nd</td>';
                        //     else
                        //         htmlBody += '<td class="'+getClass(el.res_exceed_value)+'">'+el.res_value+'</td>';
                        // }

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
                    $('#tab-staz-data-day').show();
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
     * Function that retrieves the data of the calculated statistics of a given zone and of a given parameter.
     *
     * @param {timestamp} month Selected month.
     * @param {integer} zone Selected zone.
     * @param {integer} param Selected parameter
     */
    function loadDataByZoneType(type, date, zone, param){

        var suffix;
        var formattedDate;
        if(type == 2){
            suffix = 'month';
            formattedDate = moment(date, 'MM/YYYY').format('YYYY-MM-01');
        }
        else if(type == 3){
            suffix = 'year';
            formattedDate = moment(date, 'YYYY').format('YYYY-01-01');
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // reset all table elements (header, body and footer)
        $('#tab-staz-data-'+suffix).hide();
        $('#dynamic-staz-table-'+suffix+' thead').empty();
        $('#dynamic-staz-table-'+suffix+' tbody').empty();
        $('#dynamic-staz-table-'+suffix+' tfoot').empty();

        // get statistics via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_reportistica_get_stats_by_type',
            type: "post",
            dataType: "json",
            data:{
                type: type, // Mensile / Annuale
                date: formattedDate,
                zone: zone,
                prid: param
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
                var data = result.data;
                // <thead>
                //     <tr class="text-center">
                //         <th></th>
                //         <th class="">Stazione 1</th>
                //         <th class="">Stazione 2</th>
                //         <th class="">Stazione 3</th>
                //         <th class="">Stazione 4</th>
                //         <th class="">Stazione 5</th>
                //     </tr>
                // </thead>

                // check header lenth
                // if equal to 0 then no statistics found -> warning message
                if(data.length != 0){

                    // ATTENZIONE ROW's HEADER CONSTRUCTION
                    // to even pollutants add class .tbl-bg-head in header and footer
                    htmlHead += '<tr class="text-center">';
                    htmlHead += '<th></th>;';
                    // polluntants row
                    $.each(data, function(idx, el){
                        htmlHead += '    <th class="">'+el.station_name+'</th>';
                    });

                    // close header row
                    htmlHead += '</tr>';
                    // ATTENZIONE END HEADER CONSTRUCTION

                    // ATTENZIONE BODY CONSTRUCTION
                    var data = result.data;
                    var htmlRows = [];
                    // for each data build an html row
                    $.each(data, function(idx, el){

                        // <tr>
                        //     <th>Dati reali</th>
                        //     <td class="">0</td>
                        //     <td class="">11</td>
                        //     <td class="">15</td>
                        //     <td class="text-muted font-italic">nd</td>
                        //     <td class="text-muted font-italic">nd</td>
                        // </tr>
                        // <tr>
                        //     <th>Percentile 99.9</th>
                        //     <td class="">0</td>
                        //     <td class="">10</td>
                        //     <td class="text-danger font-weight-bold">150</td>
                        //     <td class="">0.4</td>
                        //     <td class="">0.8</td>
                        // </tr>

                        $.each(el.results, function(idx2, result){

                            if(idx2 >= header.length)
                                return;

                            if(htmlRows[idx2] == null){
                                htmlRows[idx2] = '<tr>';
                                htmlRows[idx2] += '    <th>'+header[idx2].rs_label+'</th>';
                            }

                            var value = result;
                            var flag  = el.overcomings[idx2];

                            if(value == null)
                                htmlRows[idx2] += '<td class="text-muted font-italic">nd</td>';
                            else
                                htmlRows[idx2] += '<td class="'+getClass(flag)+'">'+value+'</td>';
                        });
                    });

                    $.each(htmlRows, function(idx, row){
                        htmlBody += row;
                        htmlBody += '</tr>';
                    });

                    // ATTENZIONE END BODY CONSTRUCTION

                    // ATTENZIONE FOOTER CONSTRUCTION
                    // to even pollutants add class .tbl-bg-head in header and footer
                    htmlFooter += '<tr class="text-center">';
                    htmlFooter += '<th></th>;';
                    // polluntants row
                    $.each(data, function(idx, el){
                        htmlFooter += '    <th class="">'+el.station_name+'</th>';
                    });

                    // close header row
                    htmlFooter += '</tr>';
                    // ATTENZIONE END FOOTER CONSTRUCTION

                    // append html
                    $('#dynamic-staz-table-'+suffix+' thead').append(htmlHead);
                    $('#dynamic-staz-table-'+suffix+' tbody').append(htmlBody);
                    $('#dynamic-staz-table-'+suffix+' tfoot').append(htmlFooter);
                    // show table
                    $('#tab-staz-data-'+suffix).show();
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



function notifierCallback(){

    funcRef();
}