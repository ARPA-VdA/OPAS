/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var tableParams;
    // third tab
    var tblInstr;
    var tblCyl;
    var tblMisc;


    // select2 initialization
    $("#networks, #networks2, #networks3" ).select2();
    $("#provinces, #provinces2, #provinces3" ).select2();

    ////////// -- FIRST TAB: Prametri nelle stazioni -- //////////
{

    // select2 initialization
    $( "#parameters" ).select2({
        placeholder: "Seleziona parametri...",
        allowClear: true
    });

    //datatable
    tableParams = $('#parameters-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "pageLength": 25,
        "lengthMenu": [25, 50, 75, 100],
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
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    /*
     * Filters change event
     */
    $('#parameters, #networks2, #provinces2').on('change', function(e){
        var params = $("#parameters").val();
        // check if at least one element has been selected
        if(params.length == 0){
            tableParams.clear();
            // redraw it
            tableParams.draw();
            return;
        }
        // refresh list of parameters
        loadParameters();
    });
}

    ////////// -- SECONDO TAB: Strumenti nelle stazioni -- //////////
{
    // variable for loadInstruments function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).format('YYYY-MM-DD');

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

        // on change event, get instruments allocated within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh instruments list in the second tab
        loadInstruments();
    });

    // select2 initialization
    $( "#instruments" ).select2({
        placeholder: "Seleziona strumenti...",
        allowClear: true
    });

    //datatable
    table = $('#stations-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "pageLength": 25,
        "lengthMenu": [25, 50, 75, 100],
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
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    /*
     * Filters change event
     */
    $('#instruments, #networks, #provinces').on('change', function(e){
        var types = $("#instruments").val();
        // check if at least one element has been selected
        if(types.length == 0){
            table.clear();
            // redraw it
            table.draw();
            return;
        }
        // refresh list of instruments
        loadInstruments();
    });
}

    ////////// -- THIRD TAB: Equipaggiamento nella stazione selezionata -- //////////
{
    $('#selected-station').hide();
    $('#all-equipments').hide();

    // FILTERS
    /////////////////////////////////////////////////////////////////////
    $.fn.select2.defaults.set("width", null);
    // select2 initialization taking care of not-active stations
    $("#stations3").select2({
        templateResult: function (data) {
            // We only really care if there is an element to pull classes from
            if (!data.element) {
                return data.text;
            }

            var $element = $(data.element);

            var $wrapper = $('<span></span>');
            $wrapper.addClass($element[0].className);

            $wrapper.text(data.text);

            return $wrapper;
        },
        matcher: searchGroupedSelect2
    });

    // Hide inactive elements switchery initialization
    flag = new Switchery($("#hide-inactive")[0], $("#hide-inactive").data());

    // CHANGE EVENTS
    /**
     * Provinces and networks change event
     */
    $("#provinces3, #networks3").on("change", function (e, stid) {
        e.preventDefault();
        // if event is triggered by networks filter then reset provinces
        if($(this).attr('id') == 'networks3'){
            $("#provinces3").val(-1);
        }

        // load stations
        loadStations(stid);
    });

    /**
     * Stations change event
     */
    $("#stations3, #hide-inactive").on("change", function(e){
        e.preventDefault();

        // get station id and station name from selected option
        var stid = $('#stations3').val();
        var stname = $('#stations3').find('option:selected').text();

        // check if station exists (case of stid from url)
        if (stid == null) {
            // warning message
            swal('Attenzione!', 'Non si possiedono i permessi necessari per visualizzare questa stazione', 'warning');
            // reset filter
            $('#stations3').val(-1);
            return false;
        }

        // if user select a station then take care of container visibility and set box title
        // else reset all
        if(stid != -1){
            $("#selected-station").html('Hai selezionato la stazione di: <strong>'+stname+'</strong> <small class="font-bold">&rarr; STID '+stid+'</small>');
            $('.selected-station-name').text(stname);
            $('#tobe-selected').hide('slow');
            $('#selected-station').show('slow');

            loadStationEquipments(stid);
        }
        else{
            $('#tobe-selected').show('slow');
            $('#selected-station').hide('slow');
            $('#all-equipments').hide('slow');
            $("#selected-station").empty();
        }
    });
    /////////////////////////////////////////////////////////////////////
    // END FILTERS


    // datatable
    tblInstr = $('#tbl-summary-instruments').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-6"l><"col-lg-6 col-sm-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 10,
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "Tutti"]],
        autoWidth: false,
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [],
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
        ],
        "order": [[ 7, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // datatable
    tblCyl = $('#tbl-summary-cylinders').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-6"l><"col-lg-6 col-sm-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 10,
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "Tutti"]],
        autoWidth: false,
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [],
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
        ],
        "order": [[ 7, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });


    // datatable
    tblMisc = $('#tbl-summary-miscellanies').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-6"l><"col-lg-6 col-sm-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 10,
        lengthMenu: [[10, 25, 50, -1], [10, 25, 50, "Tutti"]],
        autoWidth: false,
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [],
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
        ],
        "order": [[ 4, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // first load of all stations
    $('#networks3').trigger('change');
}


    // UTILITIES
    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null or empty then returns string '--';
     *         If not null then returns the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    };

    /**
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} field Boolean value provided to format.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */
    function formatFlagField(field) {
        if(field != null){
            if(field == true)
                return '<i class="fa-sharp fa-solid fa-check text-success"></i>&nbsp;Si';
            else
                return '<i class="fa-sharp fa-solid fa-xmark text-danger"></i>&nbsp;No';
        }
        else
            return '--';
    }

    /**
     * Function that retrieves the list of active parameters in filtered stations
     * No args needed
     */
    function loadParameters(){
        var params = $("#parameters").val();
        var net   = $("#networks2").val();
        var prov  = $("#provinces2").val();

        // reset datatable
        if ( tableParams )
            tableParams.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
            url: '/ang_stazioni_get_parameters',
            type: "post",
            dataType: "json",
            data: {
                params  : JSON.stringify(params),
                net     : net,
                prov    : prov
            },
        })
        .done(function(result) {

            var parameters = result.parameters;

            // check if at least one element exists
            if( parameters.length > 0 ){
                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each parameter, build a html row to be added to the datable
                $.each(parameters, function(index, value) {

                    var trClass = '';
                    if(!value.station_active || !value.stpr_active)
                        trClass = 'not-active';

                    html += '<tr class="'+trClass+'">';
                    html += '    <td>'+value.station_network_type_name+'</td>';
                    html += '    <td>'+value.station_name+'</td>';
                    html += '    <td>'+formatFlagField(value.station_active)+'</td>';
                    html += '    <td class="font-weight-bold">'+value.param_name+'</td>';
                    html += '    <td>'+formatFlagField(value.stpr_active)+'</td>';
                    html += '    <td>'+value.param_unit+'</td>';
                    html += '    <td>'+value.param_unit_conv+'</td>';
                    html += '    <td>'+value.stpr_table_id+'</td>';
                    html += '    <td>'+value.param_id+'</td>';
                    html += '    <td>'+value.stpr_id+'</td>';
                    html += '    <td>'+formatTextField(value.stpr_group_id)+'</td>';
                    html += '    <td></td>';
                    html += '</tr>';

                });

                // add rows to datatable by using html object
                tableParams.rows.add($( html ));
                // redraw it
                tableParams.draw();
                // adjust columns size
                tableParams.columns.adjust();
            } else {
                // redraw it
                tableParams.draw();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");
            // redraw it
            tableParams.draw();
        });

        return;
    }

    /**
     * Function that retrieves the list of active instruments of a given period.
     * No args needed
     */
    function loadInstruments(){
        // get selected values from filters
        var types = $("#instruments").val();
        var net   = $("#networks" ).val();
        var prov  = $("#provinces" ).val();

        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
            url: '/ang_stazioni_get_instruments',
            type: "post",
            dataType: "json",
            data: {
                from    : dateFrom,
                to      : dateTo,
                types   : JSON.stringify(types),
                net     : net,
                prov    : prov
            },
        })
        .done(function(result) {

            var instruments = result.instruments;

            // check if at least one element exists
            if( instruments.length > 0 ){
                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each instrument, build a html row to be added to the datable
                $.each(instruments, function(index, value) {

                    html += '<tr>';
                    html += '    <td>'+value.station_id+'</td>';
                    html += '    <td>'+value.station_name+'</td>';
                    html += '    <td>'+value.instrument_type_fullname+'</td>';
                    html += '    <td>'+formatTextField(value.instrument_identifier)+'</td>';
                    html += '    <td>'+formatFlagField(value.station_instr_master)+'</td>';
                    html += '    <td>'+getFormattedDateDT(value.location_start, 'basic_timeStartMin')+'</td>';
                    html += '    <td>'+value.location_end+'</td>';
                    html += '    <td>'+value.instrument_note+'</td>';
                    html += '    <td></td>';
                    html += '</tr>';

                });

                // add rows to datatable by using html object
                table.rows.add($( html ));
                // redraw it
                table.draw();
                // adjust columns size
                table.columns.adjust();
            } else {
                // redraw it
                table.draw();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            // redraw it
            table.draw();
        });

        return;
    }

    /**
     * Function that retrieves all stations in order to fill provinces and stations filters
     *
     * @param {numeric} stid: Station ID
     */
    function loadStations(stid){

        var prid = parseInt($("#provinces3").val());
        var netid = parseInt($("#networks3").val());

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        var jqxhr = $.ajax({
            url: '/ang_stazioni_get_stations',
            type: "post",
            dataType: "json",
            data: {
                netid: netid,
                prid: prid,
                status: -1
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill province filter and main table with retrieved data
            if(result.res == 'OK'){

                // reset "province" filter
                if(prid == -1){
                    $('#provinces3').empty();
                    $('#provinces3').append('<option value="-1">Seleziona provincia...</option>');
                }

                $("#stations3").empty();
                $('#stations3').append('<option value="-1">Seleziona stazione...</option>');

                var stations = result.stations;
                // perform the distinct of the provinces
                // exclude null values
                var provinces = stations.filter((value, index, self) =>
                    index === self.findIndex((t) => (
                        t.province_id === value.province_id && t.province_id != null
                    ))
                );
                // order them by region name and province name
                provinces.sort((a, b) => a.region_name.localeCompare(b.region_name) || a.province_name.localeCompare(b.province_name));

                // variable for dinamically building the html
                var opts = '';
                var rows = '';
                var net;

                var optsProv = '';
                var reg;
                var prov;

                if(stations.length > 0){
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

                        var classOption = '';
                        if(! station.station_active){
                            classOption = 'not-active';
                        }

                        opts += '<option class="'+classOption+'" value="'+ station.station_id+'">'+station.station_name+'</option>';
                    });

                    // check prid value
                    //     - if equal to -1 then, loadStations called by a network change
                    //     -> reset select and fill it again with filtered provinces
                    if(prid == -1){
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


                        $('#provinces3').append(optsProv);
                        $('#provinces3').append('</optgroup>');

                        $('#provinces3').val(-1);
                    }

                    $('#stations3').append(opts);
                    $('#stations3').append('</optgroup>');

                    // set station_id (arrived from db)
                    if(stid != null){
                        $('#stations3').val(stid).trigger('change');
                    }
                    else{
                        $('#stations3').val(-1).trigger('change');
                    }
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that retrieves all equipments linked to selected station
     *
     * @param {numeric} stid: Station ID
     */
    function loadStationEquipments(stid){

        tblInstr.clear();
        tblCyl.clear();
        tblMisc .clear();

        var flag = $('#hide-inactive').is(':checked');

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        var jqxhr = $.ajax({
            url: '/ang_stazioni_get_station_equipments',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                flag: flag
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill province filter and main table with retrieved data
            if(result.res == 'OK'){

                $('#all-equipments').show('slow');

                var instruments = result.instruments;

                // variable for dinamically building the html
                var html = '';
                // check if at least one element exists
                if(instruments.length > 0){
                    // loop through all elements
                    // for each station, build a html option to be added to the select
                    $.each(instruments, function(index, value) {
                        // <tr>
                        //     <th>Tipo</th>
                        //     <th>Nome</th>
                        //     <th>S.N.</th>
                        //     <th>Categoria</th>
                        //     <th>Arpa&nbsp;ID</th>
                        //     <th>Dal</th>
                        //     <th>Al</th>
                        //     <th>Primario</th>
                        //     <th>Parametri associati</th>
                        //     <th></th>
                        // </tr>

                        var isActive = '';
                        if (value.instrument_active == false){
                            isActive = "inactive "
                        }else{
                            isActive = '';
                        }
                        html += '<tr class="'+isActive+'">';
                        html += '    <td>'+value.instr_id+'</td>';
                        html += '    <td>'+value.location_id+'</td>';
                        html += '    <td>'+value.instrument_type_fullname+'</td>'; // Tipo
                        html += '    <td>'+value.instrument_name+'</td>'; // Nome
                        html += '    <td>'+value.instrument_serial_num+'</td>'; // SN
                        html += '    <td>'+value.category_name+'</td>';
                        html += '    <td>'+value.instrument_arpa_id+'</td>';
                        html += '    <td>'+getFormattedDateDT(value.location_start, 'basic_timeStartMin')+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td>'+formatFlagField(value.station_instr_master)+'</td>';
                        html += '    <td>'+formatFlagField(value.has_linked_parameters)+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblInstr.rows.add($( html ));
                    // redraw it
                    tblInstr.draw();
                    // adjust columns size
                    tblInstr.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblInstr.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    tblInstr.draw();
                }

                var cylinders = result.cylinders;

                // define all datetime formats to be managed by datatable
                $.fn.dataTable.moment([
                    "DD/MM/YYYY",
                    "DD/MM/YYYY HH:mm"
                ]);

                // variable for dinamically building the html
                html = '';
                // check if at least one element exists
                if(cylinders.length > 0){
                    // loop through all elements
                    // for each station, build a html option to be added to the select
                    $.each(cylinders, function(index, value) {
                        // <tr>
                        //     <th>Arpa&nbsp;ID</th>
                        //     <th>Nome</th>
                        //     <th>Scadenza</th>
                        //     <th>Miscela</th>
                        //     <th>Valori</th>
                        //     <th>Dal</th>
                        //     <th>Al</th>
                        //     <th>Esaurita</th>
                        //     <th>Attiva</th>
                        //     <th></th>
                        // </tr>

                        var isActive = '';
                        if (value.cylinder_active == false){
                            isActive = "inactive "
                        }else{
                            isActive = '';
                        }

                        html += '<tr class="'+isActive+'">';
                        html += '    <td>'+value.cy_id+'</td>'; //
                        html += '    <td>'+value.location_id+'</td>'; //
                        html += '    <td>'+value.cylinder_arpa_id+'</td>';
                        html += '    <td>'+value.cylinder_name+'</td>';
                        html += '    <td>'+moment(value.cylinder_expiry_date).format('DD/MM/YYYY')+'</td>';
                        html += '    <td>'+value.cylinder_mixture+'</td>';
                        html += '    <td>[ '+value.cylinder_ch_values.join(', ')+' ]</td>';
                        html += '    <td>'+moment(value.location_start).format('DD/MM/YYYY HH:mm')+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td class="hidden-lbl-icon">'+formatFlagField(value.cylinder_is_exhausted)+'</td>';
                        html += '    <td class="hidden-lbl-icon">'+formatFlagField(value.cylinder_active)+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblCyl.rows.add($( html ));
                    // redraw it
                    tblCyl.draw();
                    // adjust columns size
                    tblCyl.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblCyl.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    tblCyl.draw();
                }

                var miscellanies = result.miscellanies;
                // variable for dinamically building the html
                html = '';
                // check if at least one element exists
                if( miscellanies.length > 0 ){

                    // <th>Arpa ID</th>
                    // <th>Dotazione</th>
                    // <th>Dal</th>
                    // <th>Al</th>
                    // <th>Attiva</th>
                    // <th>Note</th>
                    // <th></th>

                    // loop through all elements
                    // for each miscellany, build a html row to be added to the datable
                    $.each(miscellanies, function(index, value) {
                        var isActive = '';
                        if (value.miscellany_active == false){
                            isActive = "inactive "
                        }else{
                            isActive = '';
                        }
                        html += '<tr class="'+isActive+'">';
                        html += '    <td>'+value.mi_id+'</td>'; // Tipo
                        html += '    <td>'+value.location_id+'</td>'; // Nome
                        html += '    <td>'+value.miscellany_arpa_id+'</td>';
                        html += '    <td>'+value.miscellany_name+'</td>';
                        html += '    <td>'+value.location_start+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td>'+formatFlagField(value.miscellany_active)+'</td>';
                        html += '    <td>'+formatTextField(value.station_mi_note)+'</td>';
                        html += '    <td></td>';

                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblMisc.rows.add($( html ));
                    // redraw it
                    tblMisc.draw();
                    // adjust columns size
                    tblMisc.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblMisc.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });

                } else {
                    tblMisc.draw();
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
    }
});