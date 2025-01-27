/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var cnt = 0;
    var filtersResults = [];

    // variable for loadReport function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(1, 'months').format('YYYY-MM-DD');

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
            'Oggi': [moment(), moment()],
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimo 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimo 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        loadReports(dateFrom, dateTo)
    });

    // select2 initializations
    $("#provinces").select2();
    $("#stations, #analytics").select2({
        matcher: searchGroupedSelect2
    });

    /**
     * Change event on filter "Provincia"
     */
    $( "#provinces" ).on( "change", function() {
        // get selected province id
        var prid = $(this).val();
        // get selector of station's select to be updated
        var dest = $(this).data('change');
        // get all stations of selected province
        loadStations(prid, dest);
    });

    /**
     * Change event on filters
     */
    $("#stations, #analytics").on( "change", function() {
        // refresh reports list
        loadReports(dateFrom, dateTo);
    });

    //datatable
    table = $('#report-table').DataTable({
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
            { "orderable": false, "width": "50px", "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 3, "desc" ]]
    });

    //TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Click event on "Visualizza" button
     */
    $('#report-table').on('click', '.show-report', function(e){
        e.preventDefault();

        // get report ID stored inside the html
        var rpid = parseInt($(this).parent().parent().data("id"));

        //check if the report's detail is already open
        if( $('#rep'+rpid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#rep' + rpid + '"]').tab('show');
            return;
        }
        // build html detail and open new tab
        createReportDetail(rpid);
    });

    /**
     * Click event on "Modifica" button
     */
    $('#report-table').on('click', '.edit-report', function(e){
        e.preventDefault();

        // get report ID stored inside the html
        var rpid = parseInt($(this).parent().parent().data("id"));

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // clear form's field
        clearFields();

        // get metadata from server via ajax call
        var jqxhr = $.ajax({
            url: '/rep_alims_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {

            // fill form's fields
            var el = result.report;
            var filters = result.filters;

            $('#id-alims').val(rpid);
            $('#datetime-alims').val('');
            $('#datetime-alims').bootstrapMaterialDatePicker('setDate', moment(el.rep_fulldate).format('DD/MM/YYYY HH:mm'));
            $('#number-alims').val(el.rep_number);
            $('#prov-alims').val(el.province_id).trigger('change', [el.station_id, el.instr_id]);
            $('#argument-alims').val(el.argument_id);
            $('#analytics-alims').val(el.analytics_id).trigger('change.select2');

            $('#multi-alims').prop('checked', el.rep_multi_filters).trigger('change');

            filters.forEach(function(filter, idx){
                addFilter(filter);
            });

            // if(el.rep_multi_filters == true)
            //     calcTotVolume();

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

            // show edit tab
            $('.customtab a[href="#new"]').tab('show');
            // update titles
            $('#new .box-title').text('Modifica VERBALE ALIMS');
            $('#inner-new-report').text('Modifica');
            $('#btn-alims-form').html(' <i class="ti-save"></i> Modifica verbale');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio del verbale", "error");

        });
    });

    /**
     * Click event on "Visualizza" button
     */
    $('#report-table').on('click', '.delete-report', function(e){
        e.preventDefault();

        // get report ID stored insider the html
        var rpid = parseInt($(this).parent().parent().data("id"));
        // show confirm message
        swal({
            title: "Stai per eliminare il verbale",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/rep_alims_del_report',
                type: "post",
                dataType: "json",
                data: {
                    id: rpid
                }
            })
            .done(function(result) {
                // check result
                // if TRUE then remove row using the datatable method and show success message
                // else show error message
                if(result == true){
                    // success message
                    swal("Report eliminato", "Il verbale è stato eliminato con successo!", "success");
                    // remove row
                    table.row($("tr[data-id='"+rpid+"']")).remove().draw();
                }
                else{
                    swal("Errore!", "Errore durante l'eliminazione del verbale", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione del verbale", "error");
            });
        });
    });

    /**
     * Click event on "Visualizza" button
     */
    $('#report-table').on('click', '.pdf-report', function(e){
        e.preventDefault();

        // get report ID stored inside the html
        var rpid = parseInt($(this).parent().parent().data("id"));
        // get td element
        var td = $(this).parent();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // initialize url for requesting the pdf
        var url = "/rep_alims_get_pdf";

        /*http://johnculviner.com/category/jquery-file-download/*/
        $.fileDownload(url, {
            httpMethod: 'GET',
            data: {
                rpid: rpid
            },
            successCallback: function(url) {

                // if the send button doesn't exist then add it
                if(td.find('.send-report').length == 0){
                    var html = '<a href="javascript:void(0)" class="send-report" data-send="no" data-toggle="tooltip" data-original-title="Invia report"> <i class="fa-regular fa-paper-plane text-primary"></i> </a>';
                    td.append(html);
                }
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            },
            failCallback: function(responseHtml, url, error) {
                // error message
                swal("Errore!", "Il file pdf non è stato creato oppure errore durante lo scarico", "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        });

        // this is critical to stop the click event which will trigger a normal file download!
        return false;
    });

    /**
     * Click event on "Visualizza" button
     */
    $('#report-table').on('click', '.send-report', function(e){
        e.preventDefault();

        // get report ID stored inside the html
        var rpid = parseInt($(this).parent().parent().data("id"));
        // get "send" attribute
        var sended = $(this).data('send');
        var txt;

        if(sended == 'yes'){
            txt = 'Verbale già inviato';
        }else{
            txt = 'Verbale non ancora inviato';
        }

        // show confirm message
        swal({
            title: txt,
            text: "Sei sicuro di voler proseguire all'invio?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, invia",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {
            // check if user has confirmed the action
            if(isConfirm){
                // show preloader, waiting for the end of the process
                $('.inner-preloader').show();

                // send report to ALIMS ws
                var jqxhr = $.ajax({
                    url: '/rep_alims_put_send',
                    type: "post",
                    dataType: "json",
                    data: {
                        id: rpid
                    }
                })
                .done(function(result) {
                    // check result
                    // if TRUE then show success message and refresh main list
                    // else error message
                    if(result == true){

                        $.toast({
                            heading: 'Verbale inviato',
                            text: 'Il verbale è stato inviato con successo!',
                            position: 'top-right',
                            loaderBg:'#e8bb05',
                            icon: 'success',
                            hideAfter: 5000
                        });
                        loadReports(dateFrom, dateTo);
                    }
                    else{
                        swal("Errore!", "Errore durante l'invio del verbale", "error");
                    }
                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                })
                .fail(function(xhr, err) {
                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                    // error message
                    swal("Errore!", "Errore durante l'invio del verbale", "error");
                });
            }
            else{
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
        });

    });

    /////////////////////////////////////////////////////////////////////
    //END TABLE FUNCTIONS

    //FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // initialize select2 at the tab entry to manage placeholder (it will be cut otherwise)
    $('#new-report').on('shown.bs.tab', function(){

        $('#analytics-alims').select2({
            placeholder: "Selezionare pacchetti analitici..."
        });
    });

    // hide containers
    $('#volume-tot').hide();
    $('.hide-filters').hide();


    // select2 initializations
    $("#station-alims, #prov-alims").select2({
        matcher: searchGroupedSelect2
    });

    // plugins initialization
    $('#multi-alims').bootstrapToggle();

    $('#datetime-alims').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    });
    $('#datetime-alims').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

    // set default value for report identifier
    $('#number-alims').val('OPAS'+moment().format('YYYY')+'_xxxx');
    $('#number-alims').prop('disabled', true);

    /**
     * Change event on datetime input
     */
    $("#datetime-alims" ).on( "change", function() {
        // get selected date
        var dt = $(this).val();
        // get selected station
        var stid = parseInt($('#station-alims').val());
        // if station is not -1
        // then load all instruments allocated in the selected station and date
        if(stid != -1){
            loadInstruments(stid, dt);
        }
    });

    /**
     * Change event on province input, passing station id and instrument id as arguments for edit action
     */
    $('#prov-alims').on( "change", function(e, stid, instrid) {
        // get selected province ID
        var prid = $(this).val();
        // get selector of station select to be updated
        var dest = $(this).data('change');

        // load stations
        loadStations(prid, dest, stid, instrid);
    });
    // select option -1 and load all stations
    $('#prov-alims').trigger("change");

    /**
     * Change event on station input, passing instrument id as argument for edit action
     */
    $('#station-alims').on("change", function(e, instrid){
        // get selected station ID
        var stid = parseInt($(this).val());
        // get selected date
        var dt = $('#datetime-alims').val();

        // if station is not -1
        // then load all instruments allocated in the selected station and date
        // else clear select
        if(stid != -1){
            loadInstruments(stid, dt, instrid);
        }
        else{
            $('#instrument-alims').empty();
            $('#instrument-alims').append('<option value="-1">Seleziona strumento...</option>');
        }
    });

    /**
     * Change event on switch
     */
    $('#multi-alims').on( "change", function() {
        // get new status
        var ckd = $(this).prop('checked');
        // hide/show elements based on new selected status
        if(ckd == true){
            $("#volume-tot").show();
            // dynamically calculate total volume
            calcTotVolume();
        }else{
            $("#volume-tot").hide();
        }
    });

    /**
     * Hide event of modal
     */
    $("#multiple-volumes").on("hide.bs.modal", function(){
        $('#volumes-form').empty();
    });


    /**
     * Click event on "Ottieni volume" button
     */
    $('#filters-table').on('click', '.get-volume-filter', function(e) {
        e.preventDefault();

        // get tr element and index stored inside of it
        var tr = $(this).parent().parent();
        var cnt = tr.data('cnt');

        // get selected instrument
        var instr = $( "#instrument-alims" ).val();
        // if no instrument has been selected then show a warning message
        if (!instr || instr == '-1'){
            swal("Seleziona strumento", "Devi selezionare uno strumento per trovarne il volume", "info");
            return;
        }

        // get station id
        var stid = parseInt($( "#station-alims" ).val());
        // get selected date and format it
        var date = tr.find('input[name="filter-start"]').val();
        var formattedDate = moment(date, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');

        // get volumes by an ajax call
        var jqxhr = $.ajax({
            url: '/rep_alims_get_volume',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                inid: instr,
                dt: formattedDate
            },
        })
        .done(function(result) {
            // check result
            if(result.res == 'OK' && result.volume.length > 0){

                // if length of volumes is equal to 1 then programatically set input field inside the row
                // otherwise fill modal's content and show it
                var volumes = result.volume;
                if(volumes.length == 1){
                     tr.find('input[name="filter-volume"]').val(volumes[0].measure_value).trigger('change');
                }
                else{

                    // loop through all retrieved volumes and build an html element
                    var html = '<input type="hidden" id="volume-cnt" name="volume-cnt" value="'+cnt+'">';
                    volumes.forEach(function(el, idx){

                        // stpr_table_id
                        // param_name
                        // measure_value
                        // param_unit
                        html += '<div class="custom-control custom-radio m-t-5">';
                        html += '    <input type="radio" id="volume-'+idx+'" name="radio-volume" class="custom-control-input" value="'+el.measure_value+'">';
                        html += '    <label class="custom-control-label" for="volume-'+idx+'">'+el.param_name+': '+el.measure_value+'</label>';
                        html += '</div>';
                    });

                    // take care of title
                    $('#multiple-volumes .modal-title').html('Volumi trovati per lo strumento <strong>'+$( "#instrument-alims option:selected" ).text()+'</strong>');
                    // append new html
                    $('#volumes-form').append(html);
                    // show modal
                    $("#multiple-volumes").modal('show');
                }
            }
            else{
                // info message
                swal("Attenzione", "Non è stato possibile recuperare il volume! Inserire manualmente", "info");
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del volume! Inserire manualmente", "error");

        });
    });

    /**
     * Click event on "Seleziona" button inside the modal
     */
    $('#multiple-volumes').on('click', '#select-volume', function(e){
        e.preventDefault();

        // get value of checked volume
        var vol = $('#volumes-form input[name="radio-volume"]:checked').val();
        // check that at least one volume has been selected
        if(!vol){
            swal("Attenzione", "Selezionare almeno un volume", "info");
            return false;
        }

        // get row index and set value of linked volume
        var cnt = $('#volume-cnt').val();
        $('#filter-volume-'+cnt).val(vol).trigger('change');
        // hide modal
        $("#multiple-volumes").modal('hide');
    });

    /**
     * Click event on "Elimina" button inside the modal
     */
    $('#filters-table').on('click', '.delete-single-filter', function(e){
        e.preventDefault();

        // get tr element
        var tr = $(this).parent().parent();
        // show confirm message
        swal({
            title: "Stai per eliminare il filtro",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected filter
            tr.remove();
            // if table does not contain any filter then hide it
            if( $('#filters-table tbody tr').length == 0 ){
                $('.hide-filters').hide();
            }

            // refresh volume
            calcTotVolume();
        });
    });

    /**
     * Change event on "Bianco" checkbox inside tr
     */
    $('#filters-table').on('change', 'input[name="filter-white"]', function(){

        // get new status
        var ckd = $(this).is(':checked');
        // get tr element
        var tr = $(this).parent().parent().parent();

        // change volume availability based on "bianco" status
        if(ckd == true){
             tr.find('input[name="filter-volume"]').val(1);
             tr.find('input[name="filter-volume"]').prop('disabled', true);
        }
        else{
            tr.find('input[name="filter-volume"]').prop('disabled', false);
        }
    });

    /**
     * Change event on input fields
     */
    $('#filters-table').on('change', 'input', function(e){
        e.preventDefault();

        // get Filtro multiplo status
        var ckd = $('#multi-alims').prop('checked');
        // if it is a multiple filter then calculate total volume
        // otherwise return and do nothing
        if(ckd == true){

            calcTotVolume();
        }
        else{
            return;
        }

    });

    /**
     * Click event on "Aggiungi filtro" button
     */
    $('#add-filter-alims').on('click', function(e){
        e.preventDefault();
        // build new html row
        addFilter();
    });

    /**
     * Click event on "Svuota tabella" button
     */
    $( "#delete-all-filters" ).on( "click", function(e) {
        e.preventDefault();

        // show confirm message
        swal({
            title: "Stai per eliminare TUTTI i filtri",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {
            // clear table
            $('#filters-table tbody').empty();
            // set total volume equal to 0
            $('#volume-tot strong').text('0');
            // hide elements
            $('.hide-filters').hide();
        });
    });

    // validate first part of the form
    var validator = $('#form-alims').validate({ // initialize the plugin
        rules: {
            "datetime-alims" : {
                required: true
            },
            "station-alims":{
                required: true,
                min: 0
            },
            "instrument-alims":{
                required: true,
                min: 0
            },
            "argument-alims":{
                required: true,
                min: 0
            },
            "analytics-alims":{
                required: true,
                allowEmpty: false
            }
        },
        messages: {
            "datetime-alims" : {
                required: "Inserire data/ora report"
            },
            "station-alims":{
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "instrument-alims":{
                required: "Selezionare strumento",
                min: "Selezionare strumento"
            },
            "argument-alims":{
                required: "Selezionare Argomento",
                min: "Selezionare Argomento"
            },
            "analytics-alims":{
                required: "Selezionare almeno un Pacchetto analitico",
                allowEmpty: "Selezionare almeno un Pacchetto analitico"
            }
        },
        ignore: "",
        errorPlacement: function ( error, element ) {
            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    // validate filters
    var validatorFilter = $('#form-filters-alims').validate({ // initialize the plugin
        rules: {
            "filter-start" : {
                required: true
            },
            "filter-end" : {
                required: true
            },
            "filter-name":{
                required: true,
                regex: function(){
                    if($('#multi-alims').prop('checked'))
                        return '^[a-zA-Z0-9]{1,6}$';
                    else
                        return '^[a-zA-Z0-9]+$';
                }
            },
            "filter-volume" : {
                required: true,
                dotSeparator: true
            }
        },
        messages: {
            "filter-start" : {
                required: "Inserire data/ora inizio filtro"
            },
            "filter-end" : {
                required: "Inserire data/ora fine filtro"
            },
            "filter-name" : {
                required: "Inserire nome filtro",
                regex: function(){
                    if($('#multi-alims').prop('checked'))
                        return "Inserire nome alfanumerico, max 6 caratteri [a-z, A-Z, 0-9]";
                    else
                        return "Inserire nome alfanumerico [a-z, A-Z, 0-9]";
                }
            },
            "filter-volume" : {
                required: "Inserire volume filtro",
            },
        },
        ignore: "",
        errorPlacement: function ( error, element ) {
            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * Click event on submit button
     */
    $('#btn-alims-form').on('click', function (e) {
        e.preventDefault();

        // check it at least one filter exists
        // else show warning message and return
        if( $('#filters-table tbody tr').length == 0 ){
            swal("Attenzione", "Deve essere presente almeno un filtro", "warning");
            return false;
        };

        // check form and filters validity
        if(! $('#form-alims').valid() || ! $('#form-filters-alims').valid()){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare report", "info");
            return false;
        };

        // initialize an empty array to be sent to server
        var filtersArray = [];

        // loop through all filters
        // for each item build a temporary object and push it inside the array variable
        $('#filters-table tbody tr').each(function(){

            var filterObj = {
                name:      $('input[name="filter-name"]'  , this).val(),
                start:     $('input[name="filter-start"]' , this).val(),
                end:       $('input[name="filter-end"]'   , this).val(),
                volume:    $('input[name="filter-volume"]', this).val(),
                cancelled: $('input[name="filter-null"]'  , this).is(':checked'),
                white:     $('input[name="filter-white"]' , this).is(':checked')
            };

            filtersArray.push(filterObj);
        });

        // serialize first part of the form
        var formMain = $("#form-alims").serializeArray();
        // get report id if exists
        var id = $("#id-alims").val();

        // append to main form the array of filters
        formMain.push({ name: "filters-alims", value: JSON.stringify(filtersArray) });

        var msg_err, msg_ok;
        // initialize different messages based on the type of action
        // if ID is defined then it's an UPDATE action
        // otherwise it's an INSERT action
        if(id){
            msg_ok = 'La modifica è stata correttamente salvata';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // save report via an ajax call
        $.ajax({
            type: 'post',
            url: '/rep_alims_put_report',
            data: formMain
        }).done(function(result) {
            // check result
            // if TRUE then show success message and clear form
            // else error message
            if(result){
                swal("Successo", msg_ok, "success");
                clearFields();
                // refresh main list
                loadReports(dateFrom, dateTo);
                // show first tab
                $('.customtab a[href="#report-list"]').tab('show');
            }
            else{
                swal("Errore!", msg_err, "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", msg_err, "error");
        });
    });

    /**
     * Click event on cancel button
     */
    $("#cancel-alims-form").on( "click", function() {
        // clear form
        clearFields();
        // show first tab
        $('.customtab a[href="#report-list"]').tab('show');
    });

    /////////////////////////////////////////////////////////////////////
    //END FORM FUNCTIONS

    //TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Click event on close button
     */
    $('.card-body').on('click', '.close-report', function(e){
        e.preventDefault();

        // get selector of the element to be closed
        var close = $(this).data("close");

        setTimeout(function(){
            // remove tab link and content
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            // show first tab
            $('.customtab a[href="#report-list"]').tab('show');

        }, 1);
    });

    // initialize json editor plugin
    var container = document.getElementById('jsoneditor-result');
    var options = {
        mode: 'view',
        modes: [],
        search: false,
        indentation: 4,
        name: 'Risultato',
        navigationBar: false,
        language: 'it',
        languages: jsonEditorlang
    };
    var resultEditor = new JSONEditor(container, options);

    /**
     * Click event on "json" button
     */
    $('.card-body').on('click', '.view-result', function(e){
        e.preventDefault();

        // get report id
        var rpid = parseInt($(this).parent().parent().data('rpid'));
        // get filter index
        var idx = parseInt($(this).parent().parent().data('id'));
        // fill json editor with filter's result object
        resultEditor.set(JSON.parse(filtersResults[rpid][idx]));
        resultEditor.expandAll();
    });

    /////////////////////////////////////////////////////////////////////
    //END TAB FUNCTIONS

    // select option -1, load all stations and reports
    $("#provinces").trigger("change");


    // FUNCTIONS
    /**
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} value Boolean value provided to format.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */
    function formatBooleanField(value){
        if(value == true)
            return '<i class="fa-solid fa-circle-check text-info"></i> Si';
        else
            return '<i class="fa-solid fa-circle-xmark text-danger"></i> No';
    }

    /**
     * Function that checks a boolean value and adds the html icon.
     * No args needed
     */
    function clearFields(){
        cnt= 0;

        // clear all form's fields
        $('.clear-input' ).val('');
        $('.clear-select').val(-1);

        $('#analytics-alims').val([]).trigger('change.select2');
        $('#datetime-alims').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY 23:59'));
        $('#multi-alims').prop( "checked", false ).trigger('change');

        $('#number-alims').val('OPAS'+moment().format('YYYY')+'_xxxx');
        $('#number-alims').prop('disabled', true);

        $('#prov-alims').trigger("change");

        // clear filters table
        $('#filters-table tbody').empty();
        $('.hide-filters').hide();

        // reset validate plugin
        $('#form-alims').validate().resetForm();
        $('#form-filters-alims').validate().resetForm();

        // reset titles
        $('#new .box-title').text('Inserisci nuovo VERBALE ALIMS');
        $('#inner-new-report').text('Nuovo');
        $('#btn-alims-form').html(' <i class="ti-save"></i> Inserisci verbale');
    }

    /**
     * Function that calculates total filters volume
     * No args needed
     */
    function calcTotVolume(){
        // initialize variable
        var volTot = 0;

        // loop through all filters
        // for each item get volume and sum it to the variable
        $('#filters-table tbody tr').each(function(){

            // get "null" and "white" properties status
            var nullFlag = $('input[name="filter-null"]'  , this).is(':checked');
            var whiteFlag = $('input[name="filter-white"]' , this).is(':checked');

            // consider only non-null and non-white filters
            if(!nullFlag && !whiteFlag && $('input[name="filter-volume"]', this).val() != ''){
                volTot += parseFloat($('input[name="filter-volume"]', this).val());
            }
        });

        // fill html with result
        $('#volume-tot strong').text(volTot.toFixed(1));
    }

    /**
     * Function that retrieves all stations
     *
     * @param {integer} prid Province ID.
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} stid Station ID.
     * @param {integer} instrid Instrument ID.
     */
    function loadStations(prid, dest, stid, instrid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/rep_alims_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();
                var stations = result.stations;
                // variable for dinamically building the html
                var opts = '';
                var net;
                // loop through all elements
                // for each station, build a html option to be added to the select
                $.each(stations, function(index, station){

                    if(net != station.station_network_type_id){

                        if(index != 0)
                            opts += '</optgroup>';

                        net = station.station_network_type_id;
                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                    }

                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });
                // append options
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);

                // check station ID
                // if not null then select it and trigger change event
                if(stid)
                    $('#'+dest).val(stid).trigger('change', instrid);
                else
                    $('#'+dest).val(-1).trigger('change');

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
     * Function that retrieves the instruments of a given station.
     *
     * @param {integer} stid Station ID
     * @param {date} dt datetime.
     * @param {integer} instrid Instrument ID.
     */
    function loadInstruments(stid, dt, instrid){

        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_alims_get_instruments',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                dt  : moment(dt, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
            }
        })
        .done(function(result) {
            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#instrument-alims').empty();
                var instruments = result.instruments;
                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each instrument, build a html option to be added to the select
                $.each(instruments, function(index, instrument){
                    var instrName = instrument.instrument_type_fullname;

                    if(instrument.instrument_name != '')
                        instrName += ' - '+instrument.instrument_name;

                    if(instrument.instrument_serial_num != '')
                        instrName += ' sn '+instrument.instrument_serial_num;

                    if(instrument.instrument_arpa_id != '')
                        instrName = instrName+' ['+instrument.instrument_arpa_id+']';

                    opts += '<option value="'+ instrument.instr_id+'">'+instrName+'</option>';
                });
                // append options
                $('#instrument-alims').append('<option value="-1">Seleziona strumento...</option>');
                $('#instrument-alims').append(opts);

                // check instrument id
                // if not null then select it and trigger a change event
                if(instrid)
                    $('#instrument-alims').val(instrid).trigger('change');
                else
                    $('#instrument-alims').val(-1).trigger('change');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti", "error");
        });
    };

    /**
     * Function that retrieves reports list in a given period
     *
     * @param {date} dateFrom Starting date
     * @param {date} dateTo Ending date
     */
    function loadReports(dateFrom, dateTo){

        console.log('loadReports');
        // get selected data
        var prid  = $( "#provinces" ).val();
        var stid  = $( "#stations" ).val();
        var pack  = $( "#analytics" ).val();

        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
            url: '/rep_alims_get_reports',
            type: "post",
            dataType: "json",
            data: {
                from : dateFrom,
                to   : dateTo,
                prid : prid,
                stid : stid,
                pack : pack
            },
        })
        .done(function(result) {
            console.dir(result);

            var reports = result.reports;
            // check that at least one report exists
            if( reports.length > 0 ){
                // variable for dinamically building the html
                var html= '';

                // loop through all reports
                // for each element, build a html row to be added to the datatable
                $.each(reports, function(index, value) {

                    html += '<tr data-id="'+value.report_id+'">';
                    html += '    <td class="bobo-nowrap">';
                    html += '        <a href="javascript:void(0)" class="show-report" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                    // if user has update grant
                    if(update_grant)
                        html += '        <a href="javascript:void(0)" class="edit-report" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                    // if user has delete grant
                    if(delete_grant)
                        html += '        <a href="javascript:void(0)" class="delete-report" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                    html += '        <br>';
                    html += '        <a href="javascript:void(0)" class="pdf-report" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';
                    if(insert_grant && value.report_pdf == true){
                        if(value.report_sent == true)
                            html += '        <a href="javascript:void(0)" class="send-report" data-toggle="tooltip" data-send="yes" data-original-title="Re-invia report"> <i class="fa-regular fa-paper-plane text-success"></i> </a>';
                        else
                            html += '        <a href="javascript:void(0)" class="send-report" data-send="no" data-toggle="tooltip" data-original-title="Invia report"> <i class="fa-regular fa-paper-plane text-primary"></i> </a>';
                    }
                    html += '    </td>';
                    html += '    <td>'+getFormattedDateDT(value.report_fulldate, 'basic_timeStartMin')+'</td>';
                    html += '    <td class="bobo-nowrap operators">';
                    html += '        <img src="'+value.user_avatar_thumb+'">';
                    html += value.user_fullname;
                    html += '    </td>';
                    html += '    <td>'+value.report_number+'</td>';
                    html += '    <td>'+value.station_name+'</td>';

                    var instrName = value.instr_type_fullname;

                    if(value.instr_name)
                        instrName += ' - '+value.instr_name;

                    if(value.instr_serial_num)
                        instrName += ' sn '+value.instr_serial_num;

                    if(value.instr_arpa_id != '')
                        instrName = instrName+' ['+value.instr_arpa_id+']';

                    html += '    <td>'+instrName+'</td>';
                    // html += '    <td>'+value.report_filter_number+'</td>';
                    html += '    <td>' + value.report_num_valid + '</td>';
                    html += '    <td>' + value.report_num_cancelled + '</td>';
                    html += '    <td class="hidden-lbl-icon">';
                    if(value.report_multi_filters == true)
                        html += '        <i class="fa-solid fa-square-check text-success" data-toggle="tooltip" data-original-title="Filtro multiplo"></i>&nbsp;<span>multiplo</span>';
                    html += '    </td>';
                    html += '    <td class="hidden-lbl-icon">';
                    if(value.report_sent == true)
                        html += '        <i class="fa-solid fa-circle-check text-info" data-toggle="tooltip" data-original-title="Report inviato"></i>&nbsp;<span>si</span>';
                    html += '    </td>';
                    html += '    <td class="hidden-lbl-icon">';
                    if(value.report_received == true)
                        html += '        <i class="fa-solid fa-circle-check text-info" data-toggle="tooltip" data-original-title="Analisi ricevuta"></i>&nbsp;<span>si</span>';
                    html += '    </td>';
                    html += '    <td></td>';
                    html += '</tr>';

                });

                // add rows to datatable by using html object
                table.rows.add($( html ));
                // redraw it
                table.draw();
                // adjust columns size
                table.columns.adjust();

                // initializes the tooltips of all lines
                // loop through each table row contained in all pages (not only the visible one )
                table.rows({page: 'all'}).every(function() {
                    var row = this;
                    // get all tr node and transform it into a jquery items
                    // in order to find all tooltip elements
                    $(row.node())
                        .find('[data-toggle="tooltip"]')
                        .tooltip();
                });

            } else {
                table.draw();
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei verbali ALIMS", "error");

        });

    };

    /**
     * Function that retrieves report metadata and build the detail
     *
     * @param {integer} rpid report ID
     */
    function createReportDetail(rpid){

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        filtersResults[rpid] = [];

        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_alims_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {
            console.dir(result);
            var el = result.report;
            var filters = result.filters;

            // add link for the new tab
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#rep'+rpid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+el.rep_number+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-report" data-close="rep'+rpid+'"></i></a></li>';
            $('.nav').append(html);

            // variable for dinamically building the html
            var html = '';

            // after variable reset, build report detail
            html += '<div class="tab-pane p-20" id="rep'+rpid+'" role="tabpanel">';
            html += '    <div class="form-body panel-report-view panel-view-mobile">';
            html += '        <h4 class="box-title">Verbale ALIMS del <strong>'+moment(el.rep_fulldate).format('DD/MM/YYYY')+'</strong> alle <strong>'+moment(el.rep_fulldate).format('HH:mm')+'</strong></h4>';
            html += '        <hr class="m-t-0 m-b-20">';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Numero verbale</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.rep_number+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Operatore</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.user_fullname+'</div>';
            html += '        </div>';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Provincia</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.province_name+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Stazione</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.station_name+'</div>';
            html += '        </div>';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Strumento</label>';
            var instrName = el.instr_type_fullname;

            if(el.instr_name)
                instrName += ' - '+el.instr_name;

            if(el.instr_serial_num)
                instrName += ' sn '+el.instr_serial_num;

            if(el.instr_arpa_id != '')
                instrName = instrName+' ['+el.instr_arpa_id+']';

            html += '            <div class="col-md-4 col-8 view-param">'+instrName+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Argomento</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.argument_desc+'</div>';
            html += '        </div>';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Pacchetti analitici</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.analytics_desc_str+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Filtro multiplo</label>';
            html += '            <div class="col-md-4 col-8 view-param">';
            if(el.rep_multi_filters == true)
                html += '                <i class="fa-solid fa-circle-check text-info"></i> Si';
            else
                html += '                <i class="fa-solid fa-circle-xmark text-danger"></i> No';

            html += '            </div>';
            html += '        </div>';
            if(el.rep_multi_filters == true){
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Identificativo tot</label>';
                html += '            <div class="col-md-4 col-8 view-param">'+filters[0].filter_tot_name+'</div>';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Volume tot</label>';
                html += '            <div class="col-md-4 col-8 view-param">'+filters[0].filter_tot_volume+'</div>';
                html += '        </div>';
            }
            html += '        <h4 class="box-title"><strong>Stato</strong> del verbale</h4>';
            html += '        <hr class="m-t-0 m-b-20">';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">PDF creato</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+formatBooleanField(el.rep_pdf)+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Data inserimento verbale</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.rep_insert_ts+'</div>';
            html += '        </div>';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Verbale inviato</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+formatBooleanField(el.rep_sent)+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Data ultimo invio</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.rep_sent_ts+'</div>';
            html += '        </div>';
            html += '        <div class="form-group row">';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Analisi ricevute</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+formatBooleanField(el.rep_received)+'</div>';
            html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Data ricezione</label>';
            html += '            <div class="col-md-4 col-8 view-param">'+el.analisys_receive_ts+'</div>';
            html += '        </div>';

            html += '        <hr class="m-t-0 m-b-20">';
            html += '        <h4 class="box-title"><strong>Filtri</strong> inseriti</h4>';
            html += '        <div class="table-responsive">';
            html += '            <table class="table table-striped table-compressed table-font-smaller form-table m-b-10">';
            html += '                <thead>';
            html += '                    <tr>';
            html += '                        <th>Filtro</th>';
            html += '                        <th>Data/ora Inizio</th>';
            html += '                        <th>Data/ora Fine</th>';
            html += '                        <th>Volume</th>';
            html += '                        <th>Annullato</th>';
            html += '                        <th>Bianco</th>';
            html += '                        <th>Risultato</th>';
            html += '                    </tr>';
            html += '                </thead>';
            html += '                <tbody>';

            filters.forEach(function(value, idx){

                html += '                    <tr data-rpid="'+rpid+'" data-id="'+idx+'">';
                html += '                        <td>'+value.filter_name+'</td>';
                html += '                        <td>'+value.filter_start_fulldate_formated+'</td>';
                html += '                        <td>'+value.filter_end_fulldate_formated+'</td>';
                html += '                        <td>'+value.filter_volume+'</td>';
                html += '                        <td class="hidden-lbl-icon">';
                if(value.filter_cancelled == true)
                    html += '                            <i class="fa-solid fa-square-check text-success" data-toggle="tooltip" data-original-title="Annullato"></i> <span>Annullato</span>';
                html += '                        </td>';
                html += '                        <td class="hidden-lbl-icon">';
                if(value.filter_white == true)
                    html += '                            <i class="fa-solid fa-square-check text-success" data-toggle="tooltip" data-original-title="Bianco"></i> <span>Bianco</span>';
                html += '                        </td>';
                html += '                        <td>';
                if(value.filter_results_obj){

                    filtersResults[rpid][idx] = value.filter_results_obj;
                    html += '                            <a href="" class="text-info view-result ellipsis-modal" data-toggle="modal" data-target=".modal-result" data-toggle-second="tooltip" data-original-title="Clicca qui per vedere il risultato completo">&nbsp;<i class="fa-solid fa-up-right-from-square"></i> json</a></td>';
                }
                html += '                        </td>';
                html += '                    </tr>';
            });

            html += '                </tbody>';
            html += '            </table>';
            html += '        </div>';
            html += '        <hr class="m-t-20">';
            html += '        <div class="form-group row">';
            html += '            <div class="col-md-12">';
            html += '                <button type="button" class="btn btn-primary close-report" data-close="rep'+rpid+'"> <i class="icon-close"></i> Chiudi report</button>';
            html += '            </div>';
            html += '        </div>';
            html += '    </div>';
            html += '</div>';

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // append tab content
            $('.tab-content').append(html);

            // initialize tooltip
            $('[data-toggle="tooltip"]').tooltip();
            // show new tab
            $('.customtab a[href="#rep'+rpid+'"]').tab('show');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio del report", "error");

        });
    };

    /**
     * Function that creates new filter row and takes care of edit case
     *
     * @param {object} el Filter object
     */
    function addFilter(el){
        // increase filter counter
        cnt++;
        // variable for dynamically building row's html
        var html = '';

        // create row
        html += '<tr data-cnt="'+cnt+'">';
        html += '    <td>';
        html += '        <a href="javascript:void(0)" class="get-volume-filter" data-toggle="tooltip" data-original-title="Ottieni volume"> <i class="icon-chemistry text-info"></i></a>';
        html += '        <a href="javascript:void(0)" class="delete-single-filter" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i></a>';
        html += '    </td>';
        html += '    <td data-name="name"><input type="text" class="form-control" id="filter-name-'+cnt+'" name="filter-name" placeholder="Filtro..."></td>';
        html += '    <td data-name="start">';
        html += '        <div class="input-group">';
        html += '            <input type="text" class="form-control" id="filter-start-'+cnt+'" name="filter-start" placeholder="mm/dd/yyyy hh:mm">';
        html += '            <div class="input-group-append">';
        html += '                <span class="input-group-text"><i class="icon-calender"></i></span>';
        html += '            </div>';
        html += '        </div>';
        html += '    </td>';
        html += '    <td data-name="end">';
        html += '        <div class="input-group">';
        html += '            <input type="text" class="form-control" id="filter-end-'+cnt+'" name="filter-end" placeholder="mm/dd/yyyy hh:mm">';
        html += '            <div class="input-group-append">';
        html += '                <span class="input-group-text"><i class="icon-calender"></i></span>';
        html += '            </div>';
        html += '        </div>';
        html += '    </td>';
        html += '    <td data-name="volume"><input type="text" class="form-control" id="filter-volume-'+cnt+'" name="filter-volume" placeholder="Sep. decimale: PUNTO"></td>';
        html += '    <td data-name="cancelled">';
        html += '        <div class="custom-control custom-checkbox inline-ckb">';
        html += '            <input type="checkbox" class="custom-control-input" id="filter-null-'+cnt+'" name="filter-null">';
        html += '            <label class="custom-control-label" for="filter-null-'+cnt+'"></label>';
        html += '        </div>';
        html += '    </td>';
        html += '    <td data-name="white">';
        html += '        <div class="custom-control custom-checkbox inline-ckb">';
        html += '            <input type="checkbox" class="custom-control-input " id="filter-white-'+cnt+'" name="filter-white">';
        html += '            <label class="custom-control-label" for="filter-white-'+cnt+'"></label>';
        html += '        </div>';
        html += '    </td>';
        html += '</tr>';
        // append row to table
        $('#filters-table tbody').append(html);

        // initialize datepicker plugin
        $('#filters-table input#filter-start-'+cnt+', #filters-table input#filter-end-'+cnt).bootstrapMaterialDatePicker({
            maxDate: moment().format("DD/MM/YYYY HH:mm"),
            format: 'DD/MM/YYYY HH:mm',
            lang : 'it',
            cancelText : 'Annulla'
        });

        // check element
        // if it is defined then it's an update action -> fill new row with filter's metadata
        // else set default values
        if(el){

            $('#filter-name-'+cnt).val(el.filter_name);
            $('#filter-start-'+cnt).bootstrapMaterialDatePicker('setDate', moment(el.filter_start_fulldate).format('DD/MM/YYYY HH:mm'));
            $('#filter-end-'+cnt).bootstrapMaterialDatePicker('setDate', moment(el.filter_end_fulldate).format('DD/MM/YYYY HH:mm'));
            $('#filter-volume-'+cnt).val(el.filter_volume);
            $('#filter-null-'+cnt).prop('checked', el.filter_cancelled);
            $('#filter-white-'+cnt).prop('checked', el.filter_white).trigger('change');
        }
        else{
            $('#filters-table input#filter-start-'+cnt).bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY 00:00'));
            $('#filters-table input#filter-end-'+cnt).bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY 23:59'));
        }

        // add change event to new datepicker elements
        $('#filters-table input[name="filter-start"]').on('change', function(e){
            var start = $(this).val();
            var id = $(this).attr('id');
            var idx = parseInt( id.replace('filter-start-', '') );

            $('#filters-table input#filter-end-'+idx).bootstrapMaterialDatePicker('setDate', moment(start, 'DD/MM/YYYY HH:mm').format('DD/MM/YYYY 23:59'));
            $('#filters-table input#filter-end-'+idx).val(moment(start, 'DD/MM/YYYY HH:mm').format('DD/MM/YYYY 23:59'));
        });

        // show filters container
        if( $('.hide-filters').is(':hidden') )
            $('.hide-filters').show();

        // initialize tooltip
        $('[data-toggle="tooltip"]').tooltip();
    };
});

