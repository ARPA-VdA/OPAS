/**
 * Document ready
 */
$(document).ready(function() {

    // initialization of select2 inside a modal
    $("#select-late-stat-param").select2({
        dropdownParent: $("#parameters-late")
    });

    // datatable initialization
    var warningTable = $('#table-hp-params').DataTable({
        // dom: "Bfrtip",
        pageLength: 12,
        pagingType: 'simple_numbers',
        layout: {
            bottomEnd: {
                paging: {
                    buttons: 5,
                    type: 'simple_numbers'
                }
            }
        },
        searching: false,
        ordering: false,
        autoWidth: false,
        lengthChange: false,
        processing: true,
        language: { "processing": '<div class="d-flex justify-content-center"><div class="spinner-border" role="status"><span class="visually-hidden">Caricamento...</span></div></div>' },
        buttons: []
    });

    /**
     * Modal's "open" event
     */
    $('#parameters-late').on('show.bs.modal', function () {

        if( $('#select-late-stat-param option').length == 0 ){
            // load stations only if select is empty
            loadStations();
        }
    });


    /*
    * Change event on modal select2
    */
    $("#select-late-stat-param").on('change', function(e){

        // show preloader, waiting for the end of the process
        warningTable.processing( true );

        // get station id
        var stid = parseInt($(this).val());

        // clear table
        if(warningTable){
            warningTable.clear();
            // redraw it
            warningTable.draw();
        }

        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_station_params_delays',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {

            var delays = result.delays;
            console.dir(delays);

            // variable for dynamically build the html
            var html = '';
            // check if the list of delays is larger than 0
            if( delays && delays.length > 0 ){
                // for each delay create a row to attach at the main table
                $.each(delays, function(index, delay){

                    // {
                    //     "colour_gap": "warning",
                    //     "gap": "12 ora/e",
                    //     "measure_date": "2024-10-02 06:00",
                    //     "measure_insert": "2024-10-02 18:02",
                    //     "param_name": "[cont] Ferro - PX-375",
                    //     "table_id": 76
                    // }
                    html += '<tr>';
                    html += '    <td>'+delay.param_name+'</td>';
                    html += '    <td>'+moment(delay.measure_date).format('DD/MM/YYYY HH')+'</td>';
                    html += '    <td>'+moment.tz(delay.measure_insert, 'Etc/GMT').tz('Etc/GMT-1').format('DD/MM/YYYY HH:mm')+'</td>';
                    html += '    <td><span class="badge badge-timeline badge-'+delay.colour_gap+'">'+delay.gap+'</span></td>';
                    html += '</tr>';

                });

                // add rows to table and draw it
                warningTable.rows.add($( html ));
                // redraw it
                warningTable.draw();
                // adjust columns size
                warningTable.columns.adjust();
            }
            else{
                // redraw it
                warningTable.draw();
            }
            // at the end of the process hide preloader
            warningTable.processing( false );
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei ritardi dei parametri", "error");
            // at the end of the process hide preloader
            warningTable.processing( false );
        });
    });

    // load all delays
    loadDelays();

    /**
     * Function that retrieves the stations that are in delay.
     */
    function loadDelays(){
        // widget preloader
        // show preloader, waiting for the end of the process
        $('#preloader-instr-delays').show();
        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_instr_delays',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // console.dir(result);
            var delays = result.delays;
            console.dir(delays);

            // variable for dynamically build the html
            var html = '';
            // check if the list of delays is larger than 0
            if( delays.length > 0 ){

                // for each delay create a row to attach at the main table
                $.each(delays, function(index, value) {
                    var htmlInstr = '';

                    var instruments = JSON.parse(value.instr_last_update);

                    var cnt = 0;
                    var rowWeight = 0;
                    $.each(instruments, function(idx, el) {
                        if(el.class == 'bg-success')
                            cnt++;

                        rowWeight += el.weight;

                        htmlInstr += '            <div class="instrument-cell '+el.class+'">';
                        htmlInstr += '                <a class="mytooltip" href="javascript:void(0)">';
                        htmlInstr += '                    <span class="instrument-txt">'+el.cat+'</span>';
                        htmlInstr += '                    <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">'+el.instr+'<br>'+el.time+'</span></span></span>';
                        htmlInstr += '                </a>';
                        htmlInstr += '            </div>';
                    });


                    html += '<tr>';
                    html += '    <td>'+rowWeight+'</td>';
                    html += '    <td>';
                    // <i class="fa-solid fa-house" aria-hidden="true"></i>
                    html += '        <h6 class="instrument-title"><a class="text-info" href="/str_mapper/' + value.station_id + '" target="_blank" data-toggle="tooltip" data-original-title="Vai al sinottico"><i class="fa-solid fa-circle-location-arrow"></i></a> '+value.station_name+' <small>['+value.st_network_name+']</small></h6>';
                    html += '        <div class="instruments-content">';
                    html += '            <div class="instrument-cell rounded-val">';
                    html += '                 <i class="fa-solid fa-rotate" data-toggle="tooltip" data-original-title="Percentuale strumenti in orario"></i> '+ ((cnt/instruments.length)*100).toFixed(0)+'% ';
                    html += '            </div>';
                    html += htmlInstr;
                    html += '        </div>';
                    html += '    </td>';
                    html += '</tr>';
                });
                // append new content to table body
                $('#instr-delays-table tbody').append(html);
                // re-initialize tooltip plugin
                $('[data-toggle="tooltip"]').tooltip();

                // datatable
                var table = $('#instr-delays-table').DataTable({
                    // "dom": "Bfrtip",
                    "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
                    "autoWidth": true,
                    "pagingType": 'simple_numbers',
                    "layout": {
                        bottomEnd: {
                            paging: {
                                buttons: 5,
                                type: 'simple_numbers'
                            }
                        }
                    },
                    "pageLength": 7,
                    "buttons" : [],
                    'columnDefs': [
                        { visible: false, targets: 0 }
                    ],
                    "order": [[ 0, "desc" ]],
                    "drawCallback": function( settings ) {
                        $("#instr-delays-table thead").remove();
                    }
                });

                var timer = moment.utc().format('HH:00');
                console.log(timer);
                $('#instr-delays-utc-time').text('ore '+timer);
            }

            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-instr-delays').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei ritardi", "error");
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-instr-delays').hide();
        });
    }

    /**
     * Function that retrieves the stations list
     */
    function loadStations(){

        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: -1,
                net: -1
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                // empty stations list
                $('#select-late-stat-param').empty();
                var stations = result.stations;
                // variable for dynamically build the html
                var opts = '';
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

                // append options and close last optgroup
                $('#select-late-stat-param').append(opts);
                $('#select-late-stat-param').append('</optgroup>');
                // trigger change: select the first station and load all delays
                $('#select-late-stat-param').val( $('#select-late-stat-param option:first').val() ).trigger('change');
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
});

