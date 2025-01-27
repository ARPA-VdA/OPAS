/**
 * Document ready.
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;

    // hide container
    $(".to-hide").hide();

    // initialize filters
    $("#provinces, #networks" ).select2();
    $("#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    // datatable
    table = $('#insta-table').DataTable({
        // "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            // 'csv',
            // 'pdf',
            // {
            //     "extend": 'print',
            //     "text"  : 'STAMPA'
            // }
        ],
        "ordering": false,
        "paging":   false,
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            // { "type": "datetime", "targets": 1 }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    /*
     * Filter change event
     */
    $( "#provinces, #networks" ).on( "change", function(e, stid) {
        e.preventDefault();

        // check if event occured on "networks" filter
        if($(this).attr('id') == 'networks'){
            // reset province
            $("#provinces").val(-1);
        }

        // get selected data
        var network = parseInt($( "#networks" ).val());
        var province = parseInt($("#provinces").val());
        // hide container with data
        $(".to-hide").hide();

        // reload stations
        loadStations(province, network, stid);
    });

    /*
     * Filter change event
     */
    $( "#stations" ).on( "change", function(e) {
        e.preventDefault();
        // retrieve selected station
        var stid = $('#stations').val();
        // clearInterval(loop);

        // if a station has been selected
        if(stid != -1){
            // refresh data
            loadData(stid);
            // loop = setInterval(function(){
            //     loadData(stid)
            // }, 60000);
        }
        else{
            // hide container and reset title
            $(".to-hide").hide();
            $(".to-hide h5").html();
        }
    });

    /*
     * Click event on "Aggiorna" button
     */
    $('#refresh').on('click', function(e){
        e.preventDefault();
        // retrieve selected station
        var stid = $('#stations').val();
        // clearInterval(loop);

        // if a station has been selected
        if(stid != -1){
            // refresh data
            loadData(stid);
            // loop = setInterval(function(){
            //     loadData(stid)
            // }, 60000);
        }
    });

    // check if stid from server (url) is defined
    if(stid != null && stid != ''){
        console.log('stid from server');
        // load station data
        loadData(stid);
        // loop = setInterval(function(){
        //     loadData(stid)
        // }, 60000);
        // select option -1 and load all stations
        // pre-select stid from server
        $( "#networks" ).trigger("change", stid);
    }
    else{
        // select option -1 and load all stations
        $( "#networks" ).trigger("change");
    }

    // UTILITIES
    /////////////////////////////////////////
    /**
     * Function that formats a given field
     *
     * @param {text} value value to be formatted.
     *
     * @return 'N.A.' if value is undefined, otherwise returns value itself
     */
    function formatVal(value){

        return (value == null) ? 'N.A.' : value;
    };

    /**
     * Function that formats a given alarm
     *
     * @param {integer} measureAlarm alarm to be formatted.
     *
     * @return html element with the icon
     */
    function formatMeasureAlarmIcons(measureAlarm){

        var alarms = [];

        // check if measureAlarm is defined
        // if true then break the number into an array of powers of 2
        if(measureAlarm && measureAlarm != 0){
            for(counter = 15; counter >= 0; counter--){
                var binPower = Math.pow(2, counter);

                if( parseInt(measureAlarm / binPower) == 1 ){

                    measureAlarm = measureAlarm % binPower;
                    alarms.push(binPower);
                }
            }
        } else {
            // normal status
            alarms.push(0);
        }

        var icons = '';
        // loop through all powers of 2
        // for each element append the corresponding icon
        $.each(alarms, function(index, alarm){

            // MEASURE CODE
            //     0  >  VALID
            //     1  >  SPAN_LOW
            //     2  >  SPAN_HIGH
            //     4  >  ZERO_LOW
            //     8  >  ZERO_HIGH
            //    16  >  CALIBRATION
            //    32  >  MAINT_ORDINARY
            //    64  >  MAINT_EXTRA_ORD
            //   128  >  MIN_READING_PERC
            //   256  >  INTRUMENT_ERROR
            //   512  >  DETECTION_LIMIT
            //  1024  >  MIN_DETECTION_LIMIT
            //  2048  >  MIN_THERSHOLD
            //  4096  >  MAX_THERSHOLD
            //  8192  >  MIN_MEAN
            // 16384  >  MAX_VARIANCE
            // 32768  >  INSTRUMENT_WRONG_DATE

            // "badge badge-pill badge-primary"     >Primary    blu
            // "badge badge-pill badge-secondary"   >Secondary  grigio
            // "badge badge-pill badge-success"     >Success    verde
            // "badge badge-pill badge-danger"      >Danger     rosso
            // "badge badge-pill badge-warning"     >Warning    giallo
            // "badge badge-pill badge-info"        >Info       azzurro
            // "badge badge-pill badge-light"       >Light      bianco
            // "badge badge-pill badge-dark"        >Dark       nero

            switch (alarm) {
                case 16:
                    icons += '<span class="badge badge-success bobo-nowrap"><i class="fas fa-heart-rate"></i> Verifica taratura</span> ';
                break;
                case 32:
                    icons += '<span class="badge badge-info bobo-nowrap"><i class="fas fa-dolly"></i> Manutenz. preventiva</span> ';
                break;
                case 64:
                    icons += '<span class="badge badge-info bobo-nowrap"><i class="fas fa-dolly-flatbed"></i> Manutenz. correttiva</span> ';
                break;
                case 256:
                    icons += '<span class="badge badge-warning bobo-nowrap"><i class="fas fa-tools"></i> Errori Strumento</span> ';
                break;
                case 512:
                    icons += '<span class="badge badge-success bobo-nowrap"><i class="fa-sharp fa-thin fa-ruler"></i> Valore tra -DL e DL</span> ';
                break;
                case 1024:
                    icons += '<span class="badge badge-primary bobo-nowrap"><i class="fa-sharp fa-thin fa-ruler"></i> Valore inferiore a -DL</span> ';
                break;
                case 32768:
                    icons += '<span class="badge badge-danger bobo-nowrap"><i class="fas fa-clock"></i> Data errata strumento</span> ';
                break;
                default:
                    icons += '<span class="badge badge-default bobo-nowrap"><i class="fas fa-thin fa-thumbs-up"></i> Normale</span> ';
                break;
            }

        });

        // return the total icons
        return icons;
    };
    /**
     * Function that formats a given alarm
     *
     * @param {integer} stationAlarm alarm to be formatted.
     *
     * @return html element with the icon
     */
    function formatStationAlarmIcons(stationAlarm){

        var alarms = [];

        // check if stationAlarm is defined
        // if true then break the number into an array of powers of 2
        if(stationAlarm && stationAlarm != 0){
            for(counter = 10; counter >= 0; counter--){
                var binPower = Math.pow(2, counter);

                if( parseInt(stationAlarm / binPower) == 1 ){

                    stationAlarm = stationAlarm % binPower;
                    alarms.push(binPower);
                }
            }
        } else {
            // normal status
            alarms.push(0);
        }
        // console.dir(alarms);

        var icons = '';
        // loop through all powers of 2
        // for each element append the corresponding icon
        $.each(alarms, function(index, alarm){

            // STATION CODE
            // 0  >  NORMAL
            // 1  >  SOFTWARE_ERROR
            // 2  >  SYSTEM_RESTART
            // 4  >  LOW_DISK_SPACE

            // "badge badge-pill badge-primary"     >Primary    blu
            // "badge badge-pill badge-secondary"   >Secondary  grigio
            // "badge badge-pill badge-success"     >Success    verde
            // "badge badge-pill badge-danger"      >Danger     rosso
            // "badge badge-pill badge-warning"     >Warning    giallo
            // "badge badge-pill badge-info"        >Info       azzurro
            // "badge badge-pill badge-light"       >Light      bianco
            // "badge badge-pill badge-dark"        >Dark       nero

            switch (alarm) {
                case 1:
                    icons += '<span class="badge badge-warning bobo-nowrap"><i class="fas fa-desktop"></i> Errore software</span> ';
                break;
                case 2:
                    icons += '<span class="badge badge-info bobo-nowrap"><i class="fas fa-power-off"></i> Riavvio sistema</span> ';
                break;
                case 4:
                    icons += '<span class="badge badge-danger bobo-nowrap"><i class="far fa-disc-drive"></i> Spazio insufficiente disco</span></i> ';
                break;
                default:
                    icons += '<span class="badge badge-default bobo-nowrap"><i class="fas fa-thin fa-thumbs-up"></i> Normale</span> ';
                break;
            }

        });

        // return the total icons
        // console.dir(icons);
        return icons;
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} prid Province ID.
     * @param {integer} netid Network ID.
     * @param {integer} stid Station ID.
     */
    function loadStations(prid, netid, stid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_inst_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                net: netid
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

                    // append options to provinces filter and close last optgroup
                    $('#provinces').empty();
                    $('#provinces').append('<option value="-1">Seleziona provincia...</option>');
                    $('#provinces').append(optsProv);
                    $('#provinces').append('</optgroup>');

                    $('#provinces').val(-1);
                }

                // append options and close last optgroup
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                $('#stations').append('</optgroup>');

                if(stid){
                    // pre select stid arriving from server
                    $('#stations').val(stid);
                }    
                else{
                    // pre select -1 value
                    $('#stations').val(-1);
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
     * Function that retrieves last instataneous data for a given station
     *
     * @param {integer} stid Station ID.
     */
    function loadData(stid){

        console.log('loadData');

        // clear table
        if(table)
            table.clear();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_inst_get_data',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {

            // console.dir(result);
            var values = result.data;

            // check result
            //  - if res is 'OK' then success, build html for the list of instantaneous data
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                // check if at least one element exists
                if( values.length > 0 ){
                    // variable for dinamically building the html
                    var html = '';

                    // initialize container's title
                    $("#table-title").html('Stazione di <strong>'+values[0].station_name+'</strong> - dati del <strong>'+moment(values[0].measure_date_time).format('DD/MM/YYYY HH:mm')+'</strong>');
                    // loop through all elements
                    // for each data, build a html row to be added to the datatable
                    $.each(values, function(index, value) {

                        // station_name
                        // parameter_name
                        // parameter_shortname
                        // parameter_icon
                        // instrument_name
                        // parameter_unit
                        // measure_date_time
                        // measure_value
                        // station_code
                        // measure_code

                        html += '<tr>';
                        html += '    <td>'+value.parameter_icon+'</td>';
                        html += '    <td>'+value.instrument_name+'</td>';
                        html += '    <td>'+value.parameter_name+'</td>';
                        html += '    <td class="font-bold">'+formatVal(value.measure_value)+'</td>';
                        html += '    <td>'+value.parameter_unit+'</td>';
                        html += '    <td>'+formatMeasureAlarmIcons(value.measure_code)+'</td>';
                        html += '    <td>'+formatStationAlarmIcons(value.station_code)+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    // show container
                    $(".to-hide").show();

                    // add rows to datatable by using html object
                    table.rows.add($( html ));
                    // redraw it
                    table.draw();
                    // adjust columns size
                    table.columns.adjust();

                    // show success message
                    $.toast({
                        heading: 'Successo',
                        text: 'Sono stati recuperati gli ultimi dati disponibili!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                } else {
                    // show warning message
                    swal('Attenzione!', 'Dati istantanei non disponibili per questa stazione', 'warning');
                    // clearInterval(loop);

                    // reset html elements text and visibility
                    $(".to-hide h5").html();
                    $(".to-hide").hide();
                    table.draw();
                }

                // re-initialize tooltip plugin
                // no need to use datatable methods because the pagination functionality is disabled
                $('[data-toggle="tooltip"]').tooltip();
            }
            else if(result.res == 'NOT'){
                // show warning message
                swal('Attenzione!', 'Dati istantanei non disponibili per questa stazione', 'warning');
                // clearInterval(loop);

                // reset html elements text and visibility
                $(".to-hide h5").html();
                $(".to-hide").hide();
                table.draw();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
                // clearInterval(loop);
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // clearInterval(loop);
        });
    };
});

