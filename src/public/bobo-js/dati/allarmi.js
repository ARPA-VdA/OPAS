/**
 * Document ready.
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;

    // variable for loadAlarms function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(7, 'days').format('YYYY-MM-DD');

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
            'Ultimi 14 giorni': [moment().subtract(14, 'days'), moment()],
            'Ultimi 30 giorni': [moment().subtract(30, 'days'), moment()],
            'Mese precedente': [moment().subtract(1, 'month').startOf('month'), moment().subtract(1, 'month').endOf('month')]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get alarms within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        var netid = $( "#networks" ).val();
        var prid = $( "#provinces" ).val();
        var stid = $( "#stations" ).val();

        var flag = $('#hide-door').is(':checked');
        // refresh alarms
        loadAlarms(dateFrom, dateTo, netid, prid, stid, flag);

    });

    $("#provinces, #networks" ).select2();
    // initialize select 2
    $( "#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    // Hide door switchery initialization
    mySwitchActive = new Switchery($("#hide-door")[0], $("#hide-door").data());

    // datatable initialization
    table = $('#alarmst-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        order: [[ 0, "desc" ]],
        columnDefs: [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { className: "bobo-nowrap", "targets": [ 2 ] }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }

    });

    // FILTERS
    /////////////////////////////////////////////////////////////////////////

    /**
     * Change event: network/province filters
     */
    $( "#provinces, #networks" ).on( "change", function() {

        // reset province select if network selected
        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        // get values
        var netid = $( "#networks" ).val();
        var prid = $( "#provinces" ).val();
        var stid = -1;
        var flag = $('#hide-door').is(':checked');

        // load filtered stations
        loadStations(prid, netid);
        // load filtered alarms
        loadAlarms(dateFrom, dateTo, netid, prid, stid, flag);
    });

    /**
     * Change event: station and hide door switchery filters
     */
    $('#stations, #hide-door').on('change', function(){

        // get values
        var netid = $( "#networks" ).val();
        var prid = $( "#provinces" ).val();
        var stid = $( "#stations" ).val();
        var flag = $('#hide-door').is(':checked');

        // load filtered alarms
        loadAlarms(dateFrom, dateTo, netid, prid, stid, flag);
    });

    // select option -1 and load all stations and all alarms
    $( "#networks" ).trigger("change");

    // FUNCTIONS
    /////////////////////////////////////////////////////////////////////////

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} province Province ID.
     * @param {integer} network Network ID.
     */
    function loadStations(prid, netid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_allarmi_get_stations',
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
                // empty stations list
                $('#stations').empty();
                var stations = result.stations;
                // variable for dynamically build the html
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

                // append options and close last optgroup
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                $('#stations').append('</optgroup>');

                $('#stations').val(-1);
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
     * Function that retrieves the alarms of a given period of selected province and station.
     *
     * @param {date} dateFrom Data di inizio.
     * @param {date} dateTo Data di fine.
     * @param {integer} network Network ID.
     * @param {integer} province Province ID.
     * @param {integer} station Station ID.
     * @param {boolean} flag Boolean value used to considerate "Open door" alarms or not.
     */
    function loadAlarms(dateFrom, dateTo, network, province, station, flag){

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // reset datatable - clear the fields
        if ( table )
            table.clear();

        // get alarms between "dateFrom" and "dateTo" by selected province and station (ajax call)
        var jqxhr = $.ajax({
            url: '/dat_allarmi_get_alarms_bydate',
            type: "post",
            dataType: "json",
            data: {
                dateFrom: dateFrom,
                dateTo  : dateTo,
                net     : network,
                prov    : province,
                stat    : station,
                flag    : flag
            },
        })
        .done(function(result) {
            // console.dir(result);

            // variable that contains the alarms data
            var alarms = result.alarms;
            console.dir(alarms);

            // variable for dynamically build the html
            var html= '';

            // check if the list of alarms is larger than 0
            if( alarms.length > 0 ){

                // for each alarm create a row to attach to the main table
                $.each(alarms, function(index, value) {
                    if(value.station_alarm_off == 1){
                        var icon = '<i class="icon-check text-info" data-toggle="tooltip" data-original-title="allarme rientrato" alt="allarme rientrato"></i>';
                    }else{
                        var icon = '<i class="icon-close text-danger" data-toggle="tooltip" data-original-title="allarme NON rientrato" alt="allarme NON rientrato"></i>';
                    }

                    html +='<tr>';
                    html +='    <td>'+getFormattedDateDT(value.station_alarm_fulldate, "basic_timeStartMin")+'</td>';
                    html +='    <td>'+value.station_name+'</td>';
                    html +='    <td class="bobo-nowrap"><span class="badge '+value.alarm_color+'"><i class="'+value.alarm_icon+'"></i> '+value.alarm_label+'</span></td>';
                    html +='    <td><span class="ico-order">'+value.station_alarm_off+'</span>'+icon+'</td>';
                    html +='    <td></td>';
                    html +='</tr>';

                });

                // add rows to table and draw it
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
                // empty table
                table.draw();
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei bollettini", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        });
    }

});