/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;

    var mapView = [];

    $('.hide-loc').hide();

    // variable for loadInstruments function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        // maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimo 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimo 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh instruments list in the first tab
        loadInstruments();
    });

    // Custom type added that manages Moment and '--'
    $.fn.dataTable.ext.type.order['custom-date-pre'] = function (d) {
        // If it is '-', return a very large value
        if (d.trim() === '--') {
            return -Infinity;
        }

        // Parsing with moment
        var m = moment(d, 'DD/MM/YYYY HH:mm', true); // true = strict parsing
        if (m.isValid()) {
            return m.valueOf(); // timestamp
        }

        return -Infinity; // fallback if parsing fails
    };

    // datatable
    table = $('#list-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Tutti"]],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        "columnDefs": [
            { "orderable": false, "targets": 0, "width": "60px" },
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "type": "custom-date", "targets": [7] }
        ],
        "order": [[ 7, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    $( "#nets, #provinces, #categories, #place-instr-prov" ).select2();
    // select2 initialization
    $( "#stations, #place-instr-stat" ).select2({
        matcher: searchGroupedSelect2
    });

    /**
     * Change event on networks and provinces filters in order to refresh stations list
     */
    $( "#nets, #provinces" ).on( "change", function() {

        if($(this).attr('id') == 'nets'){
            $("#provinces").val(-1);
        }

        var net = $('#nets').val();
        var prid = $('#provinces').val();

        // load list of stations
        loadStations(net, prid);
    });

    /**
     * Change event on main filters in order to load instruments allocations
     */
    $( "#nets, #stations, #categories" ).on( "change", function() {
        // refresh instruments list in the first tab
        loadInstruments();
    });

    /**
     * Change event on checkbox filter
     */
    $('#all-allocations').on('change', function() {
        if ($(this).is(':checked')) {
            // disabilita input
            $('.input-daterange-datepicker').prop('disabled', true);

            // svuota campo
            $('.input-daterange-datepicker').val('');

            // reset variabili globali (se servono)
            dateFrom = '-infinity';
            dateTo = '+infinity';
        } else {
            // riabilita input
            $('.input-daterange-datepicker').prop('disabled', false);

            // variable for loadInstruments function
            dateTo = moment().format('YYYY-MM-DD 23:59:59');
            dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

            // variable for datepicker plugin (different format)
            start = moment(dateFrom).format("DD/MM/YYYY");
            end = moment(dateTo).format("DD/MM/YYYY");

            // ripristina date di default
            $('.input-daterange-datepicker').data('daterangepicker').setStartDate(start);
            $('.input-daterange-datepicker').data('daterangepicker').setEndDate(end);

            // aggiorna valore del campo visibile
            $('.input-daterange-datepicker').val(
                start.format('DD/MM/YYYY') + ' - ' + end.format('DD/MM/YYYY')
            );
        }

        loadInstruments();
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive instrument detail.
     */
    $('#list-table').on('click', '.show-element', function(e){
        e.preventDefault();

        // get instrument id stored in tr
        var inid = parseInt($(this).parent().parent().data("id"));

        // check if the instrument's detail is already open
        if( $('#in'+inid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#in' + inid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createInstrumentDetail(inid);
    });

    /**
     * Edit location.
     */
    $('#list-table').on('click', '.edit-loc-el', function(e){
        e.preventDefault();

        // get location id stored in tr
        var stinid = parseInt($(this).parent().parent().data("stinid"));

        // get instrument - location detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_location_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: stinid
            }
        })
        .done(function(result) {
            console.dir(result);

            // check if result is OK
            //  - if res is 'OK' then success, fill location form
            //  - if res is not 'OK then error
            if(result.res == 'OK'){
                var location = result.location;
                var check = result.check;

                // compile fields of the form with data arriving from database
                $('#place-id').val(location.stin_id);
                $('#place-instr-id').val(location.instr_id).trigger('change.select2');
                $('#place-networks').val( JSON.stringify( $('#place-instr-id option:selected').data('nets') )) ;
                $('#place-instr-prov').trigger('change', [location.station_id, location.stpr_group_id] );
                $('.hide-loc').show('slow');

                /**
                 * instr_id
                 * station_id
                 * stin_dismiss_date
                 * stin_id
                 * stin_master
                 * stin_note
                 * stin_startup_date
                 * stpr_group_id
                 */

                // $('#modal-loc-stat').val(location.station_id);
                $('#place-instr-start-date').val('');
                $('#place-instr-start-date').bootstrapMaterialDatePicker('setDate', moment(location.stin_startup_date).format('DD/MM/YYYY HH:mm'));
                $('#place-instr-start-date').trigger('change');

                $('#place-instr-end-date').val('');
                // manage datetime
                if(location.stin_dismiss_date != 'infinity')
                    $('#place-instr-end-date').bootstrapMaterialDatePicker('setDate', moment(location.stin_dismiss_date).format('DD/MM/YYYY HH:mm'));

                $('#place-instr-end-date').bootstrapMaterialDatePicker('setMinDate', moment(location.stin_startup_date) );

                $('#place-instr-first').prop('checked', location.stin_master);
                $('#place-instr-notes').val(location.stin_note);

                $('#place-instr-id').prop('disabled', true);

                // check if instrument has been already used during this allocation
                if(check.check_flag == 1){
                    // disable fields that cannot be modified
                    $('#place-instr-prov').prop('disabled', true);
                    $('#place-instr-stat').prop('disabled', true);
                    $('#place-instr-start-date').prop('disabled', true);
                    // manage datetime
                    $('#place-instr-end-date').bootstrapMaterialDatePicker('setMinDate', moment(check.check_date) );
                }

                // modify 'Nuovo' text in 'Modifica'
                $('.customtab a[href="#new-location"]').tab('show');
                $('#new-location .box-title').text('Modifica location');
                $('#new-location .divider-title').text('Modifica location');
                $('#btn-place-instr-form').html('<i class="fa-regular fa-arrow-down-to-arc"></i> Modifica');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati della location", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati della location", "error");
        });
    });

    /**
     * Close location.
     */
    $('#list-table').on('click', '.close-loc-el', function(e){
        e.preventDefault();

        // get location id stored in tr
        var stinid = parseInt($(this).parent().parent().data("stinid"));

        // show confirm message
        swal({
            title: "Chiudi location",
            text: 'Stai per impostare la data di chiusura location a <strong>'+moment().format('DD/MM/YYYY HH:mm')+'</strong><br>Procedere?',
            html: true,
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, chiudi",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // close the selected location
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_strumenti_put_location_closure',
                type: "post",
                dataType: "json",
                data: {
                    id: stinid
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, clear fields and load location list
                //  - if false then error
                if(result){
                    swal("Location chiusa", "La location è stata chiusa con successo!", "success");
                    // refresh instruments list in the first tab
                    loadInstruments();
                    // reset location form fields
                    clearLocationFields();
                    // reload lists in order to update all select html elements
                    loadInstrumentsForLocation();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante la chiusura della location", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante la chiusura della location", "error");
            });
        });
    });

    /**
     * Download instrument detail.
     */
    $('#list-table').on('click', '.pdf-element', function(e){
        swal("Report scaricato", "Il report è stato scaricato con successo!", "success");
        e.preventDefault();
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM NEW LOCATION FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    $('#place-instr-id').select2();

    /**
     * New location start and end insertion datetime.
     */
    $('#place-instr-start-date, #place-instr-end-date').bootstrapMaterialDatePicker({
        // maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date as start time picker value
        $('#place-instr-end-date').bootstrapMaterialDatePicker('setMinDate', $('#place-instr-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#place-instr-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#place-instr-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#place-instr-end-date').val('');
    });

    // set first value
    $('#place-instr-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
    $('#place-instr-start-date').trigger('change');

    /**
     * New location instrument selection.
     */
    $('#place-instr-id').on( "change", function(e, stid) {
        console.log($(this).val());
        var inid = parseInt($(this).val());

        if(inid != -1){
            $('#place-networks').val( JSON.stringify( $('#place-instr-id option:selected').data('nets') )) ;
            $('#place-instr-prov').trigger( "change");
            $('.hide-loc').show('slow');
        }
        else{
            $('#place-networks').val('');
            $('.hide-loc').hide('slow');
        }
    });

    /**
     * New location province selection.
     */
    $('#place-instr-prov').on( "change", function(e, stid, groupid) {
        var prid = $(this).val();
        var dest = $(this).data('change');
        var nets = $('#place-networks').val();
        // refresh stations in the "dest" element
        loadStationsByNetworks(dest, prid, nets, stid, groupid);
    });

    /**
     * New location parameters selection.
     */
    $( "#place-instr-stat" ).on( "change", function(e, groupid) {
        var stid = $(this).val();
        var dest = $(this).data('change');
        var intyid = $('#place-instr-id option:selected').data('intyid');
        // refresh parameters in the "dest" element
        loadParametersByInstrument(dest, stid, intyid, groupid);
    });

    /**
     * Validate form.
     */
    var validator2 = $('#add-place-instr-form').validate({ // initialize the plugin
        rules: {
            "place-instr-id" : {
                required: true,
                min: 0
            },
            "place-instr-stat":{
                required: true,
                min: 0
            },
            "place-instr-start-date":{
                required: true
            },
            "place-instr-params":{
                required: true,
                min: 0
            },

        },
        messages: {
            "place-instr-id" : {
                required: "Selezionare strumento",
                min: "Selezionare strumento"
            },
            "place-instr-stat":{
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "place-instr-start-date" : {
                required: "Inserire data inizio"
            },
            "place-instr-params" : {
                required: "Selezionare parametri collegati",
                min: "Selezionare parametri collegati"
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
     * New location's form submission.
     */
    $('#add-place-instr-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Stanziamento non salvato!", "info");
            return false;
        };

        var form = $("#add-place-instr-form");
        var id   = parseInt($("#place-id").val());
        var inid = parseInt($('#place-instr-id').val());

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        $.ajax({
            url: '/cnf_strumenti_put_location',
            type: 'post',
            dataType: "json",
            data: form.serialize()
        }).done(function(result) {
            // check result
            //  - if '-1' then it's impossible to associate the instrument to the parameter because the item has been already used
            //  - if '1' then the instrument is correctly associated -> clear all fields
            //  - else error
            if(result < 0){
                var txt;
                if(result == -1){
                    txt = "Impossibile associare lo strumento al parametro nel periodo selezionato, perché il parametro è <strong>GIÀ COLLEGATO</strong> ad un altro strumento.<br>Disabilitare il primo strumento oppure modificare le date dello stanziamento";
                }
                else{
                    txt = "Impossibile stanziare lo strumento nel periodo selezionato perché <strong>GIÀ STANZIATO</strong>.<br>Modificare le date dello stanziamento";
                }
                swal({
                    title: "Attenzione!",
                    text: txt,
                    type: "warning",
                    html: true
                });
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else if(result == 1){
                swal("Successo", msg_ok, "success");

                // refresh instruments list in the first tab
                loadInstruments();
                // reset location form fields
                clearLocationFields();
                // reload lists in order to update all select html elements
                loadInstrumentsForLocation();

                // show first tab
                $('.customtab a[href="#list"]').tab('show');
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else{
                // error message
                swal("Errore!", msg_err, "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", msg_err, "error");
        });
    });

    /**
     * Cancel button.
     */
    $('#cancel-place-instr-form').on('click', function(e) {
        e.preventDefault();

        // show first tab
        $('.customtab a[href="#list"]').tab('show');
        // reset location form fields
        clearLocationFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM NEW LOCATION FUNCTIONS

    // TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close detail.
     */
    $('.card').on('click', '.close-detail', function(e){
        e.preventDefault();
        // get "element" to be closed
        var close = $(this).data("close");
        console.log(close);

        setTimeout(function(){
            // remove element and show first tab
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#list"]').tab('show');
        }, 1);
    });

    /////////////////////////////////////////////////////////////////////
    // END TAB FUNCTIONS

    // load stations
    $("#nets").trigger('change');

    // first load of instruments list in the first tab
    // not needed -> called by nets' change event
    // loadInstruments(dateFrom, dateTo);

    // first load of lists in order to update all select html elements
    loadInstrumentsForLocation();

    // UTILITIES

    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null, the string '--';
     *         If not, the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    }

    /**
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} field Boolean value provided to format.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */
    function formatFlagField(field) {
        if(field == true)
            return '<i class="fa-solid fa-check text-info"></i> Si';
        else
            return '<i class="fa-regular fa-x text-danger"></i> No';
    }

    /**
     * Function that refreshes the gallery item.
     */
    function refreshGalleryBig(){
        console.log("Refresh gallery BIG");
        $('.attachment-gallery-big').each(function() { // the containers for all your galleries
            $(this).magnificPopup({
                delegate: 'a', // the selector for gallery item
                type: 'image',
                gallery: {
                  enabled:true
                }
            });
        });
    }

    // END UTILITIES

    /**
     * Function that resets fields of the location form.
     * No args needed
     */
    function clearLocationFields(){
        $('.hide-loc').hide();

        // reset form texts
        $('#new-location .box-title').text('Inserisci nuovo stanziamento');
        $('#new-location .divider-title').text('Inserisci location');
        $('#btn-place-instr-form').html('<i class="fa-regular fa-arrow-down-to-arc"></i> Inserisci');

        // enable fields
        $('#place-instr-id').prop('disabled', false);
        $('#place-instr-prov').prop('disabled', false);
        $('#place-instr-stat').prop('disabled', false);
        $('#place-instr-start-date').prop('disabled', false);

        // reset form fields
        $('#place-id').val('');
        $('#place-instr-id').val(-1).trigger('change');
        $('#place-instr-stat').val(-1).trigger('change.select2');
        $('#place-instr-start-date').val('');
        $('#place-instr-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        $('#place-instr-start-date').trigger('change');
        $('#place-instr-end-date').val('');
        $('#place-instr-end-date').bootstrapMaterialDatePicker('setDate',null);
        $('#place-instr-end-date').trigger('change');
        $('#place-instr-first').prop('checked', true);
        $('#place-instr-params').empty();
        $('#place-instr-params').append('<option value="-1">Seleziona...</option>');
        $('#place-instr-params').append('<option value="0">Nessun parametro associabile</option>');
        $('#place-instr-params').val(-1);
        $('#place-instr-notes').val('');

        // reset validate plugin
        $('#add-place-instr-form').validate().resetForm();
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     */
    function loadStations(net, prid){
        console.log('loadStations: '+prid);

        // get stations via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_stations',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#stations').empty();
                var stations = result.stations;
                // variable for dinamically building the html
                var opts = '';
                var optsProv = '';
                var net;
                var reg;
                var prov;
                // loop through all elements
                // for each station, build a html option to be added to the select
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

                // check prid value
                //     - if equal to -1 then, loadStations called by a network change
                //     -> reset select and fill it again with filtered provinces
                if(prid == -1){
                    var provinces = stations.filter((value, index, self) =>
                        index === self.findIndex((t) => (
                            t.province_id === value.province_id
                        ))
                    );
                    provinces.sort((a, b) => a.region_name.localeCompare(b.region_name) || a.province_name.localeCompare(b.province_name));

                    // loop through formatted array of provinces and build options for the select
                    $.each(provinces, function(index, el){

                        if (reg != el.region_id){

                            if(index != 0)
                                optsProv += '</optgroup>';

                            reg  = el.region_id;
                            optsProv += '<optgroup label="'+el.region_name+'">';
                        }

                        if(prov != el.province_id ){
                            prov = el.province_id;
                            optsProv += '<option value="'+el.province_id+'">'+el.province_name+'</option>';
                        }
                    });

                    $('#provinces').empty();
                    $('#provinces').append('<option value="-1">Seleziona provincia...</option>');
                    $('#provinces').append(optsProv);
                    $('#provinces').append('</optgroup>');

                    $('#provinces').val(-1);
                }
                // append options
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                $('#stations').append('</optgroup>');
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
     * Function that retrieves the stations of some given networks.
     *
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} prid Province ID.
     * @param {integer} nets ID of networks.
     * @param {integer} stid Station ID.
     * @param {integer} groupid Instrument-parameter ID.
     */
    function loadStationsByNetworks(dest, prid, nets, stid, groupid){
        console.dir(nets);
        console.log(dest);

        // get stations by nets via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_stations_bynets',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                nets: nets
            },
        })
        .done(function(result) {

            console.dir(result);

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
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);

                if(stid){
                    $('#'+dest).val(stid).trigger('change', groupid);
                }
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
     * Function that retrieves the parameters that can be associated to a given instrument.
     *
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} stid Station ID.
     * @param {integer} intyid Instrument type ID.
     * @param {integer} groupid Instrument-parameter ID.
     */
    function loadParametersByInstrument(dest, stid, intyid, groupid){
        console.log('loadParametersByInstrument');
        console.log(groupid);

        // get parameters by instrument type via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_params_by_instr_type',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                intyid: intyid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();
                var params = result.params;
                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each parameter, build a html option to be added to the select
                $.each(params, function(index, param){
                    opts += '<option value="'+ param.stpr_group_id+'">'+param.parameters+'</option>';
                });
                // append options
                $('#'+dest).append('<option value="-1">Seleziona...</option>');
                $('#'+dest).append('<option value="0">Nessun parametro associabile</option>');
                $('#'+dest).append(opts);

                if(groupid != null)
                    $('#'+dest).val(groupid);
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
    };

    /**
     * Function that retrieves the instruments of a given period.
     * No args needed
     */
    function loadInstruments(){

        var type = true;
        var net  = $("#nets").val();
        var stid = $("#stations").val();
        var cat  = $("#categories").val();

        // reset datatable
        if ( table )
            table.clear();

        $('.inner-preloader').show();

        // get instruments via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instruments',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: dateFrom,
                to: dateTo,
                net: net,
                stid: stid,
                cat: cat
            }
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadInstruments');

            // check if result is 'OK'
            if(result.res == 'OK'){
                var instruments = result.instruments;
                // variable for dinamically building the html
                var html= '';

                // check if at least one element exists
                if( instruments.length > 0 ){
                    // loop through all elements
                    // for each instrument, build a html row to be added to the datable

                    $.each(instruments, function(index, value) {
                        var isActive = '';
                        if (value.instrument_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }
                        html += '<tr data-id="'+value.instr_id+'" data-stinid="'+value.location_id+'" class="'+isActive+'">';
                        html += '    <td class="bobo-nowrap toolbar-icons">';
                        html += '        <a href="javascript:void(0)" class="show-element" data-toggle="tooltip" data-original-title="Visualizza strumento"> <i class="fa-light fa-magnifying-glass-plus text-info"></i> </a>';
                        if(update_grant){
                            if(value.location_id != null && (moment(value.location_end, 'DD/MM/YYYY HH:mm').isAfter(moment()) || value.location_end == 'infinito')) {

                                if(value.instrument_active)
                                    html += '        <a href="javascript:void(0)" class="edit-loc-el" data-toggle="tooltip" data-original-title="Modifica location"> <i class="fa-light fa-pen text-info"></i> </a>';

                                html += '        <a href="javascript:void(0)" class="close-loc-el" data-toggle="tooltip" data-original-title="Chiudi location corrente"> <i class="fa-regular fa-xmark text-danger"></i> </a>';
                            }
                        }
                        html += '    </td>';

                        html += '    <td>'+value.instrument_type_fullname+'</td>'; // Tipo
                        html += '    <td>'+value.instrument_name+'</td>'; // Nome
                        html += '    <td>'+value.instrument_serial_num+'</td>'; // SN
                        html += '    <td>'+value.category_name+'</td>';
                        html += '    <td>'+value.instrument_arpa_id+'</td>';
                        html += '    <td>'+value.location+'</td>';
                        html += '    <td>'+( !type ? '--' : getFormattedDateDT(value.location_start, 'basic_timeStartMin') )+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td>'+value.network_names.join(', ')+'</td>';
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
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that retrieves the instruments not yet allocated.
     * No args needed
     */
    function loadInstrumentsForLocation(){
        $('#place-instr-id').empty();
        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instruments_for_location',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            console.dir(result);
            var html = '<option value="-1">Seleziona...</option>';
            // check if result is 'OK'
            if(result.res == 'OK'){

                var instruments = result.instruments;

                // check if at least one element exists
                if( instruments.length > 0 ){
                    // loop through all instruments
                    // for each instrument, build a html option to be added to the select
                    $.each(instruments, function(index, value) {
                        html += '<option '+value.instrument_class+' value="'+value.instr_id+'" data-intyid="'+value.instr_type_id+'" data-nets="'+JSON.stringify(value.network_types)+'">'+value.instrument_fullname+'</option>';
                    });
                }
                // append html
                $('#place-instr-id').append(html);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero degli strumenti ancora non stanziati", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti ancora non stanziati", "error");
        });
    }

    /**
     * Function that builds the instrument detail.
     *
     * @param {integer} inid Instrument ID.
     */
    function createInstrumentDetail(inid){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instrument_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: inid
            },
        })
        .done(function(result) {
            console.log('show instrument!');

            var instrument = result.instrument;
            // json objects to be parsed
            var attachments = JSON.parse(instrument.instrument_attachments);
            var locations = JSON.parse(instrument.instrument_locations);

            console.dir(instrument);
            console.dir(attachments);
            console.dir(locations);

            var fullname = instrument.instr_type_fullname;
            if(instrument.instrument_name != null){
                fullname = fullname+' - '+instrument.instrument_name;
            }

            // add link for the new tab
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#in'+inid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-wave-sine"></i></span> <span class="hidden-xs-down">'+fullname+'</span>&nbsp;&nbsp;<i class="fa-solid fa-xmark text-danger close-detail" data-close="in'+inid+'"></i></a></li>';
            $('.nav').append(html);

            // variable for dinamically building the html
            var html = '';

            /**
             * category_id
             * category_name
             * insert_time
             * insert_user
             * instr_id
             * instr_type_fullname
             * instr_type_id
             * instrument_active
             * instrument_arpa_id
             * instrument_attachments
             * instrument_delivery_date
             * instrument_dismiss_date
             * instrument_locations
             * instrument_name
             * instrument_note
             * instrument_serial_num
             * network_names
             * network_types
             * user_avatar_thumb
             * user_fullname
             * instrument_owner
             */

            // after variable reset, build instrument detail
            html += '<div class="tab-pane p-20" id="in'+inid+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '         <h4 class="box-title"><strong>'+fullname+'</strong> (categoria: <strong>'+instrument.category_name+'</strong>)</h4>\n';
            html += '         <hr class="m-t-0 m-b-20">\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Arpa ID</label>\n';
            html += '             <div class="col-4 view-param">'+formatTextField(instrument.instrument_arpa_id)+'</div>\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Numero di serie</label>\n';
            html += '             <div class="col-4 view-param">'+formatTextField(instrument.instrument_serial_num)+'</div>\n';
            html += '         </div>\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Consegnato il</label>\n';
            if(instrument.instrument_delivery_date)
                html += '             <div class="col-4 view-param">'+moment(instrument.instrument_delivery_date).format('DD/MM/YYYY')+'</i></div>\n';
            else
                html += '             <div class="col-4 view-param">'+formatFlagField(false)+'</i></div>\n';

            html += '             <label for="" class="control-label col-2 col-form-label">Dismesso il</label>\n';
            if(instrument.instrument_dismiss_date)
                html += '             <div class="col-4 view-param">'+moment(instrument.instrument_dismiss_date).format('DD/MM/YYYY')+'</i></div>\n';
            else
                html += '             <div class="col-4 view-param">'+formatFlagField(false)+'</i></div>\n';
            html += '         </div>\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Proprietario</label>\n';
            html += '             <div class="col-4 view-param">' + formatTextField(instrument.instrument_owner) + '</div>\n';
            var isActive;
            if(instrument.instrument_active){
                isActive = "Strumento attivo";
            }else{
                isActive = "Strumento NON attivo";
            }
            html += '             <label for="" class="control-label col-2 col-form-label">'+isActive+'</label>\n';
            html += '             <div class="col-4 view-param">' + formatFlagField(instrument.instrument_active) +'</i></div>\n';
            html += '         </div>\n';
            html += '        <h4 class="box-title">Ulteriori dettagli</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Reti di appartenenza</label>\n';
            html += '            <div class="col-4 view-param">'+instrument.network_names.join(', ')+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Note strumento</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(instrument.instrument_note)+'</div>\n';
            html += '        </div>\n';

            // check if there are attachments
            if(attachments != null){
                html += '        <h4 class="box-title">Allegati</strong></h4>\n';
                html += '        <hr class="m-t-0 m-b-20">\n';
                html += '        <div class="form-group row">\n';
                html += '            <label for="" class="control-label col-2 col-form-label">Allegati</label>\n';
                html += '            <div class="col-10 view-param">\n';

                var htmlImages = '';
                var htmlFiles = '';

                htmlImages +='        <div class="form-group row attachment-gallery-big">\n';
                htmlImages +='            <div class="col-10 offset-lg-2">\n';

                // loop through attachments
                // different items depending on the file type
                $.each(attachments, function(idx, attachment){
                    // check if current looped attachment is an image
                    if(attachment.file_image == true){
                        // image files
                        htmlImages +='<a href="'+attachment.file_path+'" class="clearfix thumb-gallery-lg"><img src="'+attachment.file_path+'"></a>\n';
                    }
                    else{
                        // other files
                        htmlFiles +='<a href="'+attachment.file_path+'" target="_blank"><i class="fa-regular fa-download"></i> '+attachment.file_name+'</a><br>\n';
                    }
                });

                htmlImages +='            </div>\n';
                htmlImages += '        </div>\n'; // row closure

                html += htmlFiles;

                html += '            </div>\n';
                html += '        </div>\n'; // row closure
                html += htmlImages;
            }

            // check if there is already any location
            if(locations && locations.length > 0){

                // get last location (first in the array)
                var actualLoc = locations[0];
                var flagActualLoc = true;

                // check if the location is still active
                if (actualLoc.stin_dismiss_date == 'infinity' || moment(actualLoc.stin_dismiss_date).isSameOrAfter(moment()) ){

                    /**
                     * location_id
                     * location_name
                     * location_prov
                     * location_lat
                     * location_lon
                     * location_start
                     * location_end
                     * location_note
                     */

                    html += '        <h4 class="box-title m-t-30">Location attuale dello strumento <strong>'+fullname+'</strong></h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <div class="row">\n';
                    html += '            <div class="col-md-7 col-xl-6">\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Provincia</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_prov+'</div>\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Stazione</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_name+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Data/ora inizio</label>\n';
                    html += '                    <div class="col-7 view-param">'+moment(actualLoc.location_start).format('DD/MM/YYYY HH:mm')+'</div>\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Data/ora fine</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_end+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Parametri collegati</label>\n';
                    html += '                    <div class="col-7 view-param">'+(actualLoc.location_params.length == 0 ? '--' : actualLoc.location_params.join(', '))+'</div>\n';
                    html += '                    <div class="col-7 offset-5 view-param">Strumento principale: '+formatFlagField(actualLoc.location_master)+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Note location</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_note+'</div>\n';
                    html += '                </div>\n';
                    html += '            </div>\n';
                    html += '            <div class="col-md-5 col-xl-6">\n';
                    html += '                 <div id="map-view-'+inid+'" class="mini-map" tabindex="0"></div>\n';
                    html += '            </div>\n';
                    html += '        </div>\n';

                    // html += '        <hr class="m-t-0 m-b-20">\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Provincia</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_prov+'</div>\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Stazione</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_name+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Data/ora inizio</label>\n';
                    // html += '            <div class="col-4 view-param">'+moment(actualLoc.location_start).format('DD/MM/YYYY HH:mm')+'</div>\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Data/ora fine</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_end+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Parametri collegati</label>\n';
                    // html += '            <div class="col-4 view-param">'+(actualLoc.location_params.length == 0 ? '--' : actualLoc.location_params.join(', '))+'</div>\n';
                    // html += '            <div class="col-4 offset-2 view-param">'+formatFlagField(actualLoc.location_master)+' Strumento principale</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Note location</label>\n';
                    // html += '            <div class="col-10 view-param">'+actualLoc.location_note+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div id="map-view-'+inid+'" class="mini-map" tabindex="0"></div>\n';
                }
                else{
                    // last location already closed
                    flagActualLoc = false;
                }

                // check if last location is already closed (history previous locations)
                // or if thera are previous closed locations
                if( !flagActualLoc || locations.length > 1){
                    html += '        <h4 class="box-title m-t-20">Storico delle <strong>location precedenti</strong></h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <table id="pos-table-'+inid+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed" cellspacing="0" width="100%">\n';
                    html += '            <thead>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Stazione</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </thead>\n';
                    html += '            <tbody>\n';

                    $.each(locations, function(idx, location){

                        // if the last location (first in desc order) is still active
                        // then don't add it to the table
                        if (idx == 0 && flagActualLoc )
                            return;

                        html += '                <tr data-id="'+location.location_id+'">\n';
                        html += '                    <td>'+location.location_name+'</td>\n';
                        html += '                    <td>'+getFormattedDateDT(location.location_start, 'basic_timeStartMin')+'</td>\n';
                        html += '                    <td>'+location.location_end+'</td>\n';
                        html += '                    <td>'+location.location_note+'</td>\n';
                        html += '                </tr>\n';
                    });

                    html += '            </tbody>\n';
                    html += '            <tfoot>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Stazione</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </tfoot>\n';
                    html += '        </table>\n';
                    html += '        <hr class="m-t-20 m-b-20">\n';
                    html += '        <div id="container-instr-'+inid+'" class="">\n';
                    html += '        </div>\n';
                }
            }

            html += '        <hr class="m-t-30">\n';
            html += '        <div class="form-group row">\n';
            html += '            <div class="col-12">\n';
            html += '                <button type="button" class="btn btn-primary close-detail" data-close="in'+inid+'"> <i class="fa-regular fa-xmark-large"></i> Chiudi elemento</button>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '    </div>\n';
            html += '</div>\n';

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

            // append html
            $('.tab-content').append(html);

            // initialize gallery plugin
            refreshGalleryBig();

            // check if there is already any location
            if(locations && locations.length > 0){

                // initialize instrument detail map
                initMapView(inid, footer);
                // create layer and add coordinates of the last location
                var layer = createLayer('Attuale location', 0, mapView[inid]);

                layer.setStyle(defaultStyleFunction);
                var feature = new ol.Feature({
                    popup_flag: false,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(locations[0].location_lon), parseFloat(locations[0].location_lat)], 'EPSG:4326', 'EPSG:3857'))
                });

                // add point to the layer
                layer.getSource().addFeature(feature);
                // zoom map view to point
                mapView[inid].getView().fit(feature.getGeometry(), {
                    minResolution: 15
                });
                // check if there are previous locations
                // then initialize datatable
                if(locations.length >1 ){
                    $('#pos-table-'+inid).DataTable({
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
                        "order": [[ 1, "desc" ]]
                    });

                    // create the gantt chart with all the previous locations
                    let obj = result.gantt_locations;
                    let locs = JSON.parse(obj.instrument_locations);

                    Highcharts.ganttChart('container-instr-'+ inid, {
                        title: {
                            text: obj.instrument_fullname
                        },
                        xAxis: [{
                            labels: {
                                format: '{value:%Y}'
                            },
                            min: locs[0].start,
                            max: locs[locs.length - 1].end,
                            tickInterval: 1000 * 60 * 60 * 24 * 365// year
                        }],
                        yAxis: {
                            uniqueNames: true
                        },
                        tooltip: {
                            formatter: function () {
                                // console.dir(this);
                                return '<b>' + this.name + '</b><br>Data inizio: <b>' + getFormattedDateDT(this.start, 'basic_timeStartMin') + '</b><br>Data fine: <b>' + getFormattedDateDT(this.end, 'basic_timeStartMin') + '</b>';
                            }
                            // format:
                        },
                        credits: {
                            text: '© ' + footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                            href: company_web
                        },
                        series: [{
                            name: 'Stanziamenti',
                            data: locs
                        }]
                    });
                }
            }

            // show the detail tab
            $('.customtab a[href="#in'+inid+'"]').tab('show');

            // manage resize map
            if(mapView[inid]){
                setTimeout(function(){
                    // console.log(rpid);
                    mapView[inid].updateSize();
                }, 100);
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dello strumento", "error");
        });
    };

    /**
     * OpenStreetMap initialization function (detail map)
     *
     * @param {integer} id Map ID.
     * @param {string}  attributions Copyright attributions.
     */
    function initMapView(id, attributions) {

        // console.log('initMap');

        var selectedFeature;
        // set Italy map bounds
        var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
        boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

        var view = new ol.View();

        // create layer 'Satellite'
        var satellite = new ol.layer.Tile({
            name: 'Satellite',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                maxZoom: 23,
                attributions: 'Esri, Maxar, Earthstar Geographics, CNES/Airbus DS, USDA FSA, USGS, Getmapping, Aerogrid, IGN, IGP, and the GIS User Community - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // create layer 'Topografia'
        var hiking = new ol.layer.Tile({
            name: 'Topografia',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                // url: 'http://maps.refuges.info/hiking/{z}/{x}/{y}.png',
                url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                maxZoom: 23,
                attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors -  <a href="https://opentopomap.org/" target="_blank">OpenTopoMap</a> - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // initialize the map on the "map-view-XX" div
        // in the cylinder detail tab
        mapView[id] = new ol.Map({
            target: 'map-view-'+id,
            layers: [
                new ol.layer.Tile({
                    source: new ol.source.OSM({
                        attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors - '+attributions
                    }),
                    baseLayer: true,
                    name: 'Standard'
                }),
                hiking,
                satellite
            ],
            view: view,
            controls: ol.control.defaults.defaults({attribution: false})
        });

        view.fit(boundingExtent, mapView[id].getSize());

        /* CONTROLS */
        var fullscreen = new ol.control.FullScreen();
        mapView[id].addControl(fullscreen);

        // check if map attributions are not defined
        if(attributions != undefined ){
            // add attributions to the map
            var attribution = new ol.control.Attribution({
                collapsible: true
            });

            mapView[id].addControl(attribution);
        }

        return;
    };
});

