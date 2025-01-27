/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var tables = [];

    // hide container
    $('.hidden-container').hide();

    // variable for loadWarnings function
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

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');
        // refresh warnings
        loadWarnings();
    });

    // select2 initialization
    $("#provinces").select2();
    $('#stations').select2({
        matcher: searchGroupedSelect2
    });

    /**
     * Change event on filter "Provincia"
     */
    $('#provinces').on( "change", function() {
        // get ID of the selected province
        var prid = $(this).val();
        // refresh list of stations
        loadStations(prid);
    });

    /**
     * Change event on filters "Stazioni", "Tipo strumento"
     */
    $('#stations, #types').on('change', function(){
        // refresh warnings
        loadWarnings();
    });
    // select option -1 and load all stations
    $('#provinces').trigger("change");

    /**
     * Click event on button "Espandi tutti"
     */
    $('.btn-show-all-children').on('click', function(e){
        e.preventDefault();
        // retrieve type index stored in clicked button
        var idx = parseInt($(this).data('idx'));
        // Expand row details
        tables[idx].rows(':not(.parent)').nodes().to$().find('td:first-child').trigger('click');
    });

    /**
     * Click event on button "Chiudi tutti"
     */
    $('.btn-hide-all-children').on('click', function(e){
        e.preventDefault();

        // retrieve type index stored in clicked button
        var idx = parseInt($(this).data('idx'));
        // Collapse row details
        tables[idx].rows(':not(.parent)').nodes().to$().find('td:first-child').trigger('click');
    });

    /**
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     */
    function loadStations(prid){

        // load stations via an ajax call
        var jqxhr = $.ajax({
            url: '/dat_warning_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#stations').empty();
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
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                // trigger change event in orde rto retrieve province warnings
                $('#stations').val(-1).trigger('change');

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
     * Function that retrieves the instruments warnings of a given period, station and type
     * No args needed
     */
    function loadWarnings(){

        // hide all containers
        $('.hidden-container').hide();

        // retrieve selected data
        var prid = parseInt($( "#provinces" ).val());
        var stid = parseInt($( "#stations" ).val());
        var type = parseInt($( "#types" ).val());

        // sanity check
        if(type == -1)
            return;

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // reset datatable
        if ( tables[type] ){
            tables[type].clear();
        }
        else{
            // initialize datatable
            tables[type] = $('.tbl-'+type).DataTable( {
                "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
                responsive: {
                    details: {
                        type: 'column',
                        target: 'tr'
                    }
                },
                "ordering": false,
                columnDefs: [ {
                    className: (type != 2 ? 'control' : ''),
                    orderable: false,
                    targets:   0
                } ],
                // 'copy', 'csv', 'excel', 'pdf', 'print'
                "buttons": [
                    'csv',
                    'pdf',
                    {
                        "extend": 'print',
                        "text": 'STAMPA'
                    }
                ]
            });

        }

        // get warnings between "dateFrom" and "dateTo" by selected provinces and stations
        var jqxhr = $.ajax({
            url: '/dat_warning_get_instruments_messages',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to  : dateTo,
                prov: prid,
                stat: stid,
                type: type
            },
        })
        .done(function(result) {

            var warnings = result.warnings;

            // create different table list
            // depending on the type of instruments selected
            switch(type){
                case 1: // swam

                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            var msgArray = JSON.parse(value.messages);

                            html += '<tr '+value.sw_class+'>';
                            html += '    <td></td>';
                            html += '    <td>'+getFormattedDateDT(value.sw_fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td>'+value.sw_line+'</td>';
                            html += '    <td><span class="badge badge-orange">'+msgArray.length+'</span></td>';
                            html += '    <td>'+value.sw_bit_mask+'</td>';
                            html += '    <td>';
                            html += '        <ul>';
                            $.each(msgArray, function(index, msg) {
                                html += '            <li><strong>'+msg.code+':</strong> '+msg.desc+'</li>';
                            });
                            html += '        </ul>';
                            html += '    </td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[1].rows.add($( html ));
                        // redraw it
                        tables[1].draw();
                        // adjust columns size
                        tables[1].columns.adjust();

                        // initializes the tooltips of all lines
                        // loop through each table row contained in all pages (not only the visible one )
                        tables[1].rows({page: 'all'}).every(function() {
                            var row = this;
                            // get all tr node and transform it into a jquery items
                            // in order to find all tooltip elements
                            $(row.node())
                                .find('[data-toggle="tooltip"]')
                                .tooltip();
                        });
                    } else {
                        // redraw it
                        tables[1].draw();
                    }
                    break;

                case 2: // tecora
                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            // console.dir(msgArray);

                            html += '<tr>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td><span class="badge badge-orange">'+value.num+'</span></td>';
                            html += '    <td>'+value.message+'</td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[2].rows.add($( html ));
                        // redraw it
                        tables[2].draw();
                        // adjust columns size
                        tables[2].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[2].draw();
                    }
                    break;

                case 3: //derenda

                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            // console.dir(msgArray);

                            html += '<tr>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td><span class="badge badge-orange">'+value.num+'</span></td>';
                            html += '    <td>'+value.message+'</td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[3].rows.add($( html ));
                        // redraw it
                        tables[3].draw();
                        // adjust columns size
                        tables[3].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[3].draw();
                    }
                    break;

                case 4: //envea

                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            var msgArray = JSON.parse(value.message);

                            html += '<tr>';
                            html += '    <td></td>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td>'+value.station_id+'</td>';
                            html += '    <td><span class="badge badge-orange">'+msgArray.length+'</span></td>';

                            //html += '    <td>'+value.desc+'</td>';

                            html += '    <td>'+value.warning_id+'</td>';
                            html += '    <td>';
                            html += '        <ul>';
                            $.each(msgArray, function(index, msg) {
                                html += '            <li><strong>'+msg.code+':</strong> '+msg.desc+'</li>';
                            });
                            html += '        </ul>';
                            html += '    </td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[4].rows.add($( html ));
                        // redraw it
                        tables[4].draw();
                        // adjust columns size
                        tables[4].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[4].draw();
                    }
                    break;

                case 5: //metone

                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            var msgArray = JSON.parse(value.message);

                            html += '<tr>';
                            html += '    <td></td>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td>'+value.station_id+'</td>';
                            html += '    <td><span class="badge badge-orange">'+msgArray.length+'</span></td>';

                            //html += '    <td>'+value.desc+'</td>';

                            html += '    <td>'+value.warning_id+'</td>';
                            html += '    <td>';
                            html += '        <ul>';
                            $.each(msgArray, function(index, msg) {
                                html += '            <li><strong>'+msg.code+':</strong> '+msg.desc+'</li>';
                            });
                            html += '        </ul>';
                            html += '    </td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[5].rows.add($( html ));
                        // redraw it
                        tables[5].draw();
                        // adjust columns size
                        tables[5].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[5].draw();
                    }
                    break;

                case 6: // fidas
                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            var msgArray = JSON.parse(value.messages);

                            html += '<tr>';
                            html += '    <td></td>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td>'+value.station_id+'</td>';
                            html += '    <td><span class="badge badge-orange">'+msgArray.length+'</span></td>';
                            html += '    <td>'+value.bit_mask+'</td>';
                            html += '    <td>';
                            html += '        <ul>';
                            $.each(msgArray, function(index, msg) {
                                html += '            <li><strong>'+msg.code+':</strong> '+msg.desc+'</li>';
                            });
                            html += '        </ul>';
                            html += '    </td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[6].rows.add($( html ));
                        // redraw it
                        tables[6].draw();
                        // adjust columns size
                        tables[6].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[6].draw();
                    }
                    break;

                case 7: // teledyne

                    // check if at least one element exists
                    if (warnings.length > 0){
                        // variable for dinamically building the html
                        var html = '';
                        // loop through all warnings
                        // for each element create a row to be added to the datable
                        $.each(warnings, function(index, value) {

                            var msgArray = JSON.parse(value.message);

                            html += '<tr>';
                            html += '    <td></td>';
                            html += '    <td>'+getFormattedDateDT(value.fulldate, 'basic_timeStart')+'</td>';
                            html += '    <td>'+value.province_code+'</td>';
                            html += '    <td>'+value.station_name+'</td>';
                            html += '    <td>'+value.station_id+'</td>';
                            html += '    <td>'+value.instrument_type_fullname+'</td>';
                            html += '    <td><span class="badge badge-orange">'+msgArray.length+'</span></td>';

                            //html += '    <td>'+value.desc+'</td>';

                            html += '    <td>'+value.warning_id+'</td>';
                            html += '    <td>';
                            html += '        <ul>';
                            $.each(msgArray, function(index, msg) {
                                html += '            <li><strong>'+msg.code+':</strong> '+msg.desc+'</li>';
                            });
                            html += '        </ul>';
                            html += '    </td>';
                            html += '</tr>';

                        });

                        // add rows to datatable by using html object
                        tables[7].rows.add($( html ));
                        // redraw it
                        tables[7].draw();
                        // adjust columns size
                        tables[7].columns.adjust();

                    } else {
                        // redraw datatable
                        tables[7].draw();
                    }
                    break;

                default:
                    break;
            };

            // show the specific warning container
            $('.cont-'+type).show();
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // take care of error
            swal("Errore!", "Errore durante il recupero dei warnings", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        });
    }
});


