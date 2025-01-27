/**
 * Document ready.
 */
$(document).ready(function() {
/////////// PRIMO TAB: INVIO E2A ///////////
{
    // GLOBAL VARIABLES
    var arrayParams;
    var table;

    // INIZIALIZZAZIONE
    /////////////////////////////////////////////////////////////////////////
    $.fn.select2.defaults.set('width', null);

    $('#networks, #provinces').select2();
    // select2 initialization
    $('#stations').select2({
        matcher: searchGroupedSelect2
    });

    // datatable
    table = $('#table-switch-params').DataTable({
        "ordering": false
    });

    // boostraptoggle
    $("#to-send input[type='checkbox']").bootstrapToggle();

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    $('#networks').on( 'change', function() {
        var net  = $(this).val();
        var prid = $('#provinces').val();

        // load list of stations
        loadStations(net, prid, 'stations');
        // load list of stations - parameters
        loadStationsParams(net, prid, -1);
    });

    $('#provinces').on( 'change', function() {
        var net  = $('#networks').val();
        var prid = $(this).val();

        // load list of stations
        loadStations(net, prid, 'stations');
        // load list of stations - parameters
        loadStationsParams(net, prid, -1);
    });

    // select option -1 and load all stations
    $('#provinces').trigger('change');

    $('#stations').on( 'change', function() {
        var net  = $('#networks' ).val();
        var prid = $('#provinces').val();
        var stid = $(this).val();

        // load list of stations - parameters
        loadStationsParams(net, prid, stid);
    });

    $('#parameters').on( 'change', function() {
        var net  = $('#networks' ).val();
        var prid = $('#provinces').val();
        var stid = $('#stations' ).val();

        // load list of stations - parameters
        loadStationsParams(net, prid, stid);
    });

    /**
     * Click on button to set all stations - parameters in table.
     * Triggered before change event, show confirm message
     */
    $("#container-all-chk").on('click.bs.toggle', 'div.android', function(e) {

        e.stopImmediatePropagation();
        var checkbox = $('input[type=checkbox]', this);

        var action;
        if(checkbox.is(':checked')){
            action = 'disattivare';
        }
        else{
            action = 'attivare';
        }

        // confirm message
        swal({
            title: "Attenzione",
            text: 'Stai per <strong>'+action+' TUTTI i parametri</strong><br>Proseguire?',
            html: true,
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, procedi",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        },
        function(isConfirm){
            // if confirmed then trigger toggle on bootstrap
            if (isConfirm) {
                checkbox.bootstrapToggle('toggle');
            }
        });
    });

    /**
     * Button to set all stations - parameters in table.
     */
    $("#to-send").on('change', '.all-param', function(){
        // get current button status
        var status = $(this).prop('checked');

        // set status of each parameter for the selected dataset
        for (var key in arrayParams) {
            arrayParams[key] = status;
        };

        $('.inner-preloader').show();
        // update all stations - parameters's status
        updateParamsStatus(-1);
    });

    /**
     * Button to set a single stations - parameters from the table.
     */
    $("#to-send").on('change', '.single-param', function(){
        // get current button status
        var status = $(this).prop('checked');
        // get the chosen station-parameter id
        var stprid = $(this).parent().parent().data('id');
        console.log(stprid);

        // set status of the chosen station-parameter
        arrayParams[stprid] = status;

        // update the chosen stations - parameters's status
        updateParamsStatus(stprid);
    });
}

/////////// SECONDO TAB: VISTA  ///////////
{
    $('#view-networks, #view-provinces').select2();
    // select2 initialization
    $('#view-stations').select2({
        matcher: searchGroupedSelect2
    });

    //datatable
    var tblView = $('#list-table').DataTable({
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        lengthMenu: [25, 50, 75, 100],
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
        ],
        "order": []
    });

    /**
     * Filter change event
     */
    $('#view-networks, #view-provinces').on( 'change', function() {
        var net  = $('#view-networks').val();
        var prid = $('#view-provinces').val();
        // load list of stations
        loadStations(net, prid, 'view-stations');
        // load list of active stations - parameters
        loadStationsParamsRecap(net, prid, -1);
    });

    /**
     * Filter change event
     */
    $('#view-stations').on( 'change', function() {
        var net  = $('#view-networks').val();
        var prid = $('#view-provinces').val();
        var stid = $('#view-stations').val();

        // load list of active stations - parameters
        loadStationsParamsRecap(net, prid, stid);
    });

    $('#view-update').on('click', function(e){
        e.preventDefault();

        $('#view-provinces').trigger('change');
    });

    $('#view-provinces').trigger('change');
}
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

    /**
     * Function that retrieves the stations of a given network and a given province (if provided).
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {text} dest html element
     */
    function loadStations(net, prid, dest){
        console.log('loadStations: '+prid);

        // get stations via ajax call
        var jqxhr = $.ajax({
            url: '/info_dataset_e_get_stations',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
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
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);

            }
            else{
                // error massage
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

        })
        .fail(function(xhr, err) {
            // error massage
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that retrieves the station-parameter associations of a given network and a given province (if provided).
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {integer} prid Station ID.
     *
     */
    function loadStationsParams(net, prov, sta){

        if(table)
            table.clear();

        $('.inner-preloader').show();

        // parameter id chosen by the user
        var param = $('#parameters').val();

        // get stations - parameters via ajax call
        var jqxhr = $.ajax({
            url: '/info_dataset_e_get_stations_params',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prov: prov,
                stid: sta,
                prid: param
            },
        })
        .done(function(result) {

            console.dir(result);
            var statusTotal = true;

            // check if result is OK
            if(result.res == 'OK'){
                var params = result.params;

                arrayParams = [];

                // variable for dinamically building the html
                var html = '';
                // loop through all elements
                // for each parameter, build a html row to be added to the datatable
                $.each(params, function(index, param){

                    if(index % 2 == 0){
                        html += '<tr>';
                    }

                    // populate array storing the status (enabled/disabled) for each stprid
                    arrayParams[param.stpr_id] = {};
                    arrayParams[param.stpr_id] = param.e2a_active;

                    // manage "Total" status
                    statusTotal = statusTotal && ( arrayParams[param.stpr_id] ? true : false );
                    // set class based on status
                    var classCheck = arrayParams[param.stpr_id] ? 'checked' : '';

                    html += '    <td class="text-right">'+param.parameter_fullname+'</td>';
                    html += '    <td data-id="'+param.stpr_id+'"><input type="checkbox" class="single-param" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+classCheck+'/></td>';

                    // check if it's the second parameter then close row
                    if(index % 2 == 1){
                        html += '</tr>';
                    }


                });

                // for the last element, check if it's necessary to add an empty td to complete and close the row
                if(params.length % 2 == 1){
                    html += '    <td class="text-right"></td>';
                    html += '    <td></td>';
                    html += '</tr>';
                }

                // add rows to datatable by using html object and redraw it
                table.rows.add($( html ));
                // adjust columns size
                table.columns.adjust();
                // loop through each table row contained in all pages (not only the visible one)
                table.rows({page: 'all'}).every(function() {
                    var row = this;
                    // get all nodes contained by the row and transform them into a jquery items
                    row = $(row.node());

                    row.find("input[type='checkbox']").bootstrapToggle();
                });
                // redraw table
                table.draw();
                // manage "Total" button
                $("#to-send .all-param").prop('checked', statusTotal).bootstrapToggle('destroy').bootstrapToggle();
            }
            else{
                // error massage
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // error massage
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that retrieves the station-parameter associations of a given network and a given province (if provided).
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {integer} stid Station ID.
     *
     */
    function loadStationsParamsRecap(net, prid, stid){

        if(tblView)
            tblView.clear();

        $('.inner-preloader').show();

        // get stations - parameters via ajax call
        var jqxhr = $.ajax({
            url: '/info_dataset_e_get_stations_params_e2a_recap',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prov: prid,
                stid: stid
            },
        })
        .done(function(result) {
            console.dir(result);

            // check if result is OK
            if(result.res == 'OK'){
                var params = result.params;

                // variable for dinamically building the html
                var html = '';
                // loop through all elements
                // for each parameter, build a html row to be added to the datatable
                $.each(params, function(idx, el){

                    var trClass = '';
                    if(el.spo_name == null)
                        trClass = 'very-late';

                    html += '<tr class="'+trClass+'">';
                    html += '    <th>'+formatTextField(el.spo_name)+'</th>';
                    html += '    <td>'+formatTextField(el.st_info_eu_code)+'</td>';
                    html += '    <td>'+formatTextField(el.st_info_name)+'</td>';
                    html += '    <td>'+formatTextField(el.pollutant_id)+'</td>';
                    html += '    <td>'+formatTextField(el.pollutant_notation)+'</td>';
                    html += '    <td>'+formatTextField(el.stpr_startup_date)+'</td>';
                    html += '    <td>'+formatTextField(el.instr_type_fullname)+'</td>';
                    html += '    <td>'+formatTextField(el.method)+'</td>';
                    html += '    <td></td>';
                    html += '</tr>';

                });

                // add rows to datatable by using html object and redraw it
                tblView.rows.add($( html ));
                // adjust columns size
                tblView.columns.adjust();
                // redraw table
                tblView.draw();
            }
            else{
                // error massage
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // error massage
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that updates the current status of the chosen station-parameter associations.
     *
     * @param {integer} stprid Station-Parameter ID.
     */
    function updateParamsStatus(stprid){

        var statusObjArray = [];

        // check if it has been modified a specific parameter
        // if -1 then no, so create an array of objects with all the associations
        // else create the array with only the selected association
        if(stprid == -1){
            console.log('tutte le associazioni stazioni - parametri');

            for (var key in arrayParams) {

                var statusObj = {
                    stprid : parseInt(key),
                    e2a: arrayParams[key]
                };

                // push object into the array
                statusObjArray.push(statusObj);
            }
        }
        else{
            var statusObj = {
                stprid : parseInt(stprid),
                e2a: arrayParams[stprid]
            };

            // push object into the array
            statusObjArray.push(statusObj);
        }

        console.dir(statusObjArray);
        // var grid = parseInt($("#filter-group-stations").val());

        // put status via ajax call
        var jqxhr = $.ajax({
            url: '/info_dataset_e_put_status',
            type: "post",
            dataType: "json",
            data: {
                status: JSON.stringify(statusObjArray)
            },
        })
        .done(function(result) {

            if(! result){
                // error massage
                swal("Errore!", "Errore durante il salvataggio", "error");
            }
            else{
                if(stprid == -1){
                    // loop through each table row contained in all pages (not only the visible one)
                    table.rows({page: 'all'}).every(function() { // the containers
                        var row = this;
                        row = $(row.node());

                        // get element containing the first param in row
                        var param1 = row.find('td:nth-child(2)');
                        // get stprid stored in the td element
                        var stprid1 = param1.data('id');
                        // manage bootstrap toggle button for the first param
                        // destroy and re-create bootstrap toggle in order to refresh status
                        param1.find('.single-param').prop('checked', arrayParams[stprid1]).bootstrapToggle('destroy').bootstrapToggle();

                        // get element containing the second param in row
                        var param2 = row.find('td:nth-child(4)');
                        // get stprid stored in the td element
                        var stprid2 = param2.data('id');
                        // check if it's null
                        if(stprid2 != null){
                            // manage bootstrap toggle button for the second param
                            // destroy and re-create bootstrap toggle in order to refresh status
                            param2.find('.single-param').prop('checked', arrayParams[stprid2]).bootstrapToggle('destroy').bootstrapToggle();
                        }
                    });
                }

                var net  = $('#view-networks').val();
                var prid = $('#view-provinces').val();
                var stid = $('#view-stations').val();

                // load list of active stations - parameters
                loadStationsParamsRecap(net, prid, stid);
            }
        })
        .fail(function(xhr, err) {
            // error massage
            swal("Errore!", "Errore durante il salvataggio", "error");
        });
    }

});
