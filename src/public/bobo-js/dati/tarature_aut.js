/**
 * Document ready.
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var calibChart;

    // hide containers
    $('#events-list').hide();
    $('#events-chart').hide();

    var dateTo;
    var dateFrom;

    if(stid != null && stid != '' && dateStart != null && dateStart != ''){

        // load data in date_start (expressed in seconds since 1970-01-01) for st_id
        // convert date from milliseconds to moment object
        var date    = moment.utc(parseInt(dateStart*1000));

        // variable for loadData function
        dateTo = date.format('YYYY-MM-DD 23:59:59');
        dateFrom = date.format('YYYY-MM-DD');
    }
    else{
        // variable for loadData function
        dateTo = moment().format('YYYY-MM-DD 23:59:59');
        dateFrom = moment(dateTo).format('YYYY-MM-DD');
    }


    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // initialize switchery
    mySwitchActive = new Switchery($("#result-active")[0], $("#result-active").data());

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
            'Ieri': [moment().subtract(1, 'days'), moment().subtract(1, 'days')],
            'Ultimi 3 giorni': [moment().subtract(3, 'days'), moment()]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end) {

        //on change event, get data within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'));
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // retrieve other metadata from filters
        var network = parseInt($( "#networks" ).val());
        var province = parseInt($( "#provinces" ).val());
        var stid = parseInt($( "#stations" ).val());
        var prid = parseInt($('#parameters').val());
        var flag = $('#result-active').is(':checked');

        // refresh data list
        loadData(dateFrom, dateTo);

    });

    // select2 initializations
    $("#provinces, #networks" ).select2();
    $( "#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    //datatable
    table = $('#calibs-table').DataTable({
        // https://datatables.net/reference/option/dom
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
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
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "targets": 0 },
            { "width": "40px", "targets": 0 }
        ],
        "order": [[ 1, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // FILTERS
    /////////////////////////////////////////////////////////////////////////

    /*
    * Change event on filters
    */
    $( "#provinces, #networks" ).on( "change", function(e) {
        e.preventDefault();

        // if networks have been changed then reset provinces
        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        // get selected values
        var network = parseInt($( "#networks" ).val());
        var province = parseInt($("#provinces").val());

        // refresh list of stations based on selected province and network
        loadStations(province, network);
        // referesh data
        loadData(dateFrom, dateTo);
    });

    /*
    * Change event on other filters
    */
    $( "#stations, #parameters, #result-active" ).on("change", function(e){
        e.preventDefault();

        // referesh data
        loadData(dateFrom, dateTo);
    });

    ////////////////////////////////////////////////////////////
    // END FILTERS

    // select option -1 and load all stations
    // $( "#networks" ).trigger("change");
    // refresh list of stations based on selected province and network
    loadStations(-1, -1);

    /*
    * Click event on "Show chart" option
    */
    $("#calibs-table").on( "click", ".show-chart", function(e) {
        e.preventDefault();
        // retrieve data stored in the tr row
        var calibId = $(this).parent().parent().data('id');
        var time = $(this).parent().next().text();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_tarature_aut_get_chart',
            type: "post",
            data: {
                id: calibId
            }
        })
        .done(function(result) {
            console.dir(result);

            // check result
            if(result.res){
                var metadata = result.metadata;
                var nParams = metadata.length;
                var data = result.data;

                // check how many parameters are linked to the same calibration
                // create chart with one or more series
                if(nParams == 1){
                    createChart(metadata, data);
                }
                else{
                    createNCharts(metadata, data);
                }

                // set titles of the lightbox
                $('#lightbox-chart strong:nth-child(1)').text(metadata[0].station_name);
                $('#lightbox-chart strong:nth-child(2)').text(time);
            }
            else{
                // error message
                swal('Errore', 'Errore durante il recupero dei dati', 'error');
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal('Errore', 'Errore durante il recupero dei dati', 'error');
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

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
            url: '/dat_tarature_aut_get_stations',
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

                // check variables from server (passed by url)
                // case of /sti_id/date_start
                if(stid != null && stid != '' && dateStart != null && dateStart != ''){

                    // set station then load data
                    $('#stations').val(stid).trigger('change');
                }
                else{
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
     * Function that retrieves data in a given period and based on selected values
     *
     * @param {integer} dateFrom date from
     * @param {integer} dateTo date to
     */
    function loadData(dateFrom, dateTo){
        console.log('loadData');

        // get selected values
        var netid = parseInt($( "#networks" ).val());
        var provid = parseInt($( "#provinces" ).val());
        var stid = parseInt($('#stations').val());
        var prid = parseInt($('#parameters').val());
        var flag = $('#result-active').is(':checked');

        console.log(dateFrom);
        console.log(dateTo);
        console.log(stid);

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // reset datatable
        if ( table )
            table.clear();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_tarature_aut_get_data',
            type: "post",
            data: {
                from: dateFrom,
                to: dateTo,
                netid: netid,
                provid: provid,
                stid: stid,
                prid: prid,
                flag: flag
            }
        })
        .done(function(result) {
            console.dir(result);
            // check result
            // if OK then fill table with data
            // else show error message
            if (result.res = 'OK'){
                // variable for dynamically building the html
                var html= '';
                // loop through all elements
                // for each data, build a html row to be added to the datatable
                $.each(result.data, function(index, value) {

                    html += '<tr role="row" data-id="'+value.calibration_id+'">';
                    html += '    <td><a href="#lightbox-chart" class="show-chart" data-original-title="Visualizza grafico" data-toggle="tooltip"><i class="mdi mdi-chart-areaspline text-info"></i></a></td>';
                    html += '    <td>'+getFormattedDateDT(value.calibration_date_time, 'basic_timeStartMin')+'</td>';
                    html += '    <td>'+value.station_name+'</td>';
                    html += '    <td>'+value.param_name+'</td>';
                    html += '    <td>'+value.calibration_step+'</td>';
                    html += '    <td>'+value.calibration_type+'</td>';
                    html += '    <td>'+value.result_value+'</td>';
                    html += '    <td>'+value.reference_value+'</td>';
                    html += '    <td>'+value.calibration_defect+'</td>';
                    html += '    <td>'+value.result_code_string+'</td>';
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
                table.rows({page: 'all'}).every(function() { // the containers for all your galleries
                    var row = this;
                    // get all tr node and transform it into a jquery items
                    // in order to find all tooltip elements
                    $(row.node())
                        .find('[data-toggle="tooltip"]')
                        .tooltip();

                    // get all tr node and transform it into a jquery items
                    // in order to find all magnificPopup elements
                    $(row.node())
                        .find('.show-chart').magnificPopup({
                            type:'inline',
                            midClick: true, // Allow opening popup on middle mouse click. Always set it to true if you don't provide alternative source in href.
                            callbacks: {
                                close: function() {
                                    console.log('close');
                                    if(calibChart)
                                        calibChart.destroy();
                                }
                            }
                        });
                });
            }
            else{
                // redraw table
                table.draw();
                // error message
                swal('Errore', 'Errore durante il recupero dei dati', 'error');
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal('Errore', 'Errore durante il recupero dei dati', 'error');
        });
    };

    /**
     * Function that creates an highchart with one series of data
     *
     * @param {object} metadata Object with all series metadata.
     * @param {object} data Array of relation date-value.
     */
    function createChart(metadata, data) {
        console.log('createChart');

        var step;
        var oldStep;
        var annotationPoints = [];

        // loop through all data and create a new formatted array of objects of x-y
        var series = [];
        $.each(data, function (key, rec) {
            // transform dates Unix Timestamp in milliseconds
            var dtime = moment.utc(rec.calibration_date_time).valueOf();
            // create realtion x-y and push it to the new array
            var dpoint = [dtime, parseFloat(rec.measure_value)];
            series.push(dpoint);

            // check the calibration step
            // if it is not equal to previous one then build a object
            // in order to add an annotation over the chart
            step = rec.calibration_step;
            if (oldStep != step){
                oldStep = step;
                var annotation = {
                    point :
                    {
                        x: dpoint[0],
                        y: dpoint[1],
                        xAxis: 0,
                        yAxis: 0
                    },
                    text : step
                };
                // push the new annotation in the array
                annotationPoints.push(annotation);
            }
        });

        // set alignment
        annotationPoints[0].align = 'left';
        annotationPoints[1].align = 'right';

        // drawing chart
        calibChart = Highcharts.chart('chart-container', {
            credits: {
                enabled: false
            },
            title: {
                text: 'Grafico di '+ metadata[0].param_name
            },
            chart: {
                zoomType: 'x'
            },
            annotations: [{
                draggable: '',
                labelOptions: {
                    backgroundColor: 'rgba(255,255,255,0.5)',
                    shape: 'connector',
                },
                labels: annotationPoints
            }],
            xAxis: {
                title:'Time',
                type:'datetime',
                // ...
                labels: {
                    formatter: function() {
                        return Highcharts.dateFormat('%H:%M', moment(this.value));
                    }
                }
            },
            yAxis: { // Primary yAxis
                title: {
                    text: metadata[0].param_unit
                }
            },
            tooltip: {
                formatter: function() {
                    return '<span style="font-size: 10px">' +
                    Highcharts.dateFormat('%a, %e %b %Y. %H:%M', moment(this.x))
                    + '</span><br/>' + '<span style="color:' + this.series.color
                    + '">\u25CF</span> ' + this.series.name + ': <b>'
                    + this.y  + '</b><br/>';
                },
                yDecimals: 2,
                crosshairs: true,
            },
            plotOptions: {
                series: {
                    connectNulls: true,
                    color: '#2293b5',
                    marker: {
                        enabled: false
                    }
                },
            },
            series: [{
                name: metadata[0].param_name,
                data: series,
            }],
            exporting: {
                buttons: {
                    contextButton: {
                        menuItems: ['downloadJPEG', 'downloadCSV']
                    }
                }
            }
        });

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    };

    /**
     * Function that creates an highchart with more than one series of data
     *
     * @param {object} metadata Object with all series metadata.
     * @param {object} data Array of relation date-value.
     */
    function createNCharts(metadata, data) {
        console.log('createNCharts');

        var id = data[0].measure_id;
        var count = 0;

        var step;
        var oldStep;
        var series = [];
        var annotationPoints = [];
        var startPoint;

        series[0] = [];
        // loop through all data and create multiple formatted arrays of objects of x-y
        $.each(data, function (key, rec) {
            // transform dates Unix Timestamp in milliseconds
            var dtime = moment.utc(rec.calibration_date_time).valueOf();
            // create realtion x-y and push it to the new array
            var dpoint = [dtime, parseFloat(rec.measure_value)];

            // check if the new id is equal to previous one
            // if true then add the point to the same array
            // otherwise create a new array of points
            if(rec.measure_id == id){

                series[count].push(dpoint);
                // if it is the first series then check for annotations
                if(count == 0){

                    // check the calibration step
                    // if it is not equal to previous one then build a object
                    // in order to add an annotation over the chart
                    step = rec.calibration_step;
                    if (oldStep != step){
                        oldStep = step;
                        var annotation = {
                            point :
                            {
                                x: dpoint[0],
                                y: dpoint[1],
                                xAxis: 0,
                                yAxis: 0
                            },
                            text : step
                        };
                        // push the new annotation in the array
                        annotationPoints.push(annotation);
                    }
                }
            }
            else{
                count++;
                series[count] = [];

                id = rec.measure_id;
                series[count].push(dpoint);
            }
        });
        // set alignment
        annotationPoints[0].align = 'left';
        annotationPoints[1].align = 'right';

        // drawing chart
        calibChart = Highcharts.chart('chart-container', {
            credits: {
                enabled: false
            },
            title: {
                text: 'Grafico combinato'
            },
            chart: {
                zoomType: 'x'
            },
            annotations: [{
                draggable: '',
                labelOptions: {
                    backgroundColor: 'rgba(255,255,255,0.5)',
                    shape: 'connector',
                },
                labels: annotationPoints
            }],
            xAxis: {
                title:'Time',
                type:'datetime',
                labels: {
                    formatter: function() {
                        return Highcharts.dateFormat('%H:%M', moment(this.value));
                    }
                }
            },
            yAxis: { // Primary yAxis
                title: {
                        text: metadata[0].param_unit
                }
            },
            tooltip: {
                formatter: function() {
                    return '<span style="font-size: 10px">' +
                    Highcharts.dateFormat('%a, %e %b %Y. %H:%M', moment(this.x))
                    + '</span><br/>' + '<span style="color:' + this.series.color
                    + '">\u25CF</span> ' + this.series.name + ': <b>'
                    + this.y  + '</b><br/>';
                },
                yDecimals: 2,
                crosshairs: true
            },
            plotOptions: {
                series: {
                    connectNulls: true,
                    //cursor: 'pointer',
                    marker: {
                        enabled: false
                    }
                }

            },
            exporting: {
                buttons: {
                    contextButton: {
                        menuItems: ['downloadJPEG', 'downloadCSV']
                    }
                }
            }
        });

        // loop through all series and set different color for each of them
        var colors = ['#79a030', '#dc5a08', '#e8bb06', '#2293b5', '#cb0b8f'];
        $.each(series, function (idx, el) {
            var options = {
                name: metadata[idx].param_name,
                data: series[idx],
                color: colors[idx]
            };
            // add series to chart and at last loop refresh it
            calibChart.addSeries(options, false);
            if(idx == series.length-1)
                calibChart.redraw();
        });

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    };
    ////////////////////////////////////////////////////////////
    // END FUNCTIONS
});



