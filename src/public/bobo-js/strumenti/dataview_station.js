/**
 * Document ready
 */
$( document ).ready(function() {

    // GLOBAL VARIABLES
    var chart = []; // array of highcharts
    var windChart;  // windrose
    var table;      // datatable
    var map;
    var mapNear;

    // LAYOUT STUFF //
    console.log('App mode: ' + app_mode);
    // disable log in console
    if (app_mode == 'production'){
        // var console = {};
        console.log = function(){};
        console.dir = function(){};
    }

    // set title
    $('#bottom-double strong').html('Dettaglio stazione');


    // initialize select2 plugin
    $("#select-station").select2({
        placeholder: "Seleziona stazione...",
        width: 'resolve' // need to override the changed default
    });

    // initialize plugin for main station photo
    $('.test-popup-link').magnificPopup({
        type: 'image'
    });

    // MAP STUFF
    map = initMap('map'); //mini-map
    mapNear = initMap('map-near');

    var layer = createLayer('Stazione', 0, map);
    layer.setStyle(defaultStyleFunction);


    // create layer for mapNear considering the existance of multiple style
    var layerNear = createLayer('Stazioni vicine', 0, mapNear);
    layerNear.setStyle(multiplePointsStyleFunction);

    /**
     * Change event of active tab
     */
    $('.nav').on('click', '.nav-item', function(e){
        e.preventDefault();

        // retrieve tab id
        var tmp = $(this).attr('id');
        setTimeout(function(){
            console.log('resize');
            // if tab contains the map then update map's view
            if(tmp == 'nav-contact-tab'){
                map.updateSize();
            }
            else if (tmp == 'nav-nearest-tab'){
                mapNear.updateSize();
                // zoom to nearest stations markers
                zoomToMarkers(mapNear);
            }
        }, 200);
    });
    // END MAP STUFF

    /**
     * Change event on station filter
     */
    $('#select-station').on('change', function(e){
        // get selected station ID
        var stid = $(this).val();

        // reload page with data of the new selected station
        window.open('/str_dataview_station/'+stid, '_self');
    });

    // LEFT COLUMN
    /**
     * Click event on << button to show/hide lateral menu
     */
    $("#page-info mark").click(function(e) {
        e.preventDefault();

        // toggle class for lateral menu
        $( "#page-info" ).toggleClass( "to-left" );

        // calculate new windows dimension
        var vpWidth = window.innerWidth;
        console.log('vpWidth: '+vpWidth);
        if(vpWidth >= 920){
            // refresh charts
            initChartsContainer();
            // set different width based on whether the side menu is open or closed
            if ($( "#page-info" ).hasClass("to-left")){
                $(".col-overflow").css("width", "calc(100vw - 75px)");
            }else{
                $(".col-overflow").css("width", "calc(100vw - 380px)");
            }

        }
    });

    /**
     * Change event on radio button inside the lateral menu
     */
    $('input[name=radioInline]').on('change', function(e){
        e.preventDefault();

        // possibile aggregation hh and dd
        var aggregation = $("input[name=radioInline]:checked").val();

        // if time period equal to 1 day and aggregation equal to dd, select time period 3 days
        if( aggregation == 'dd' && parseInt($('#set-time-period select').val()) == 1){
            $('#set-time-period select').val(3);
        }

        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();
        // reload data in highcharts and datatable
        // and refresh them
        initChartsContainer();
        initTable();
    });

    /**
     * Change event on time aggregation select
     */
    $('#set-time-period select').on('change', function(e){
        e.preventDefault();

        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();

        // reload data in highcharts and datatable
        // and refresh them
        initChartsContainer();
        initTable();
    });
    // END LEFT COLUMN

    // first load of station data
    initChartsContainer();
    initTable();
    // load 15 nearest stations
    loadNearStations();

    // tab from server: if not null, enable selected tab
    if(tab){
        $('#nav-tab a:nth-child('+tab+')').trigger('click');
    }

    /**
     * Function to initialize html containers and charts based on station parameters
     */
    function initChartsContainer(){
        // clear main container
        $('#container').empty();

        // get selected info
        var aggregation = $("input[name=radioInline]:checked").val(); //hh dd
        var rangeDate = $('#set-time-period select').val(); // number of days
        var dateFrom;

        // calculate the start date of the range based on the chosen time aggregation
        if(aggregation == 'dd'){
            dateFrom = moment.utc().subtract(rangeDate, 'days').format('YYYY-MM-DD 00:00:00');
        }
        else{
            dateFrom = moment.utc().subtract(rangeDate, 'days').format('YYYY-MM-DD HH:00:00');
        }

        // recover array of data for each parameter associated to the station
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_allparams_data',
            type: "post",
            dataType: "json",
            data: {
                id: st_id,
                aggr: aggregation,
                from: dateFrom,
                to: moment.utc().format('YYYY-MM-DD HH:59:59')
            },
        })
        // callback handler that will be called on success
        .done(function(result) {
            console.dir(result);
            var values = result.data;
            // variable for dinamically building the html
            var flagWind = false;
            var html = '';

            // loop through all parameters linket to the station
            // for each element create the charts containers
            $.each(values, function(index, value){

                // if station contains wind parameter (vel. or dir.)
                if(value.parameter_windv || value.parameter_windd ){
                    flagWind = true;

                    // in case of wind parameters (vel. or dir.) aggregations greater than hh have no sense
                    // -> no charts for them
                    if(aggregation == 'hh')
                        html +='<div class="col-lg-6 col-md-12" id="chart_'+value.station_param_id+'"></div>\n';
                }
                else{
                    // identification of container through st_pr_id
                    html +='<div class="col-lg-6 col-md-12" id="chart_'+value.station_param_id+'"></div>\n';
                }

            });

            // append html to main container
            $('#container').append(html);

            // create charts in each container
            $.each(values, function(index, value){
                createChart(value);
            });

            // if there are wind parameters associated to the station
            if(flagWind){

                // check if already exists
                if( $('#wr_label').length == 0){

                    // add a row in left table
                    var htmlTable = '<tr id="wr_label">\n';
                    htmlTable += '    <th>Rosa dei venti</th>\n';
                    htmlTable += '    <td></td>\n';
                    htmlTable += '</tr>\n';
                    $('#real-time-value').append(htmlTable);
                }

                // create the container and initialize the windrose
                html ='<div class="col-lg-6 col-md-12" id="chart_wind"></div>\n';
                $('#container').append(html);
                createChartWR();
            }
            else{
                // at the end of the process hide preloader
                $("#dataview-preloader").hide();
            }

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }

    /**
     * Function to create chart: called for each parameter associated to selected station
     *
     * @param {object} value: looped parameter
     */
    function createChart(value){

        // get selected time aggregation
        var aggregation = $("input[name=radioInline]:checked").val(); //hh dd

        // check if it's a wind parameter and the aggregation is greater than hh
        //  if true then return
        if ( (value.parameter_windv || value.parameter_windd) && aggregation == 'dd'){
            console.log('wind dd');
            return;
        }

        // format path in order to add a logo on the chart
        var logo = value.station_logo;
        logo = logo.replace('loghi/', 'loghi/chart_');

        // number of days
        var rangeDate = parseInt($('#set-time-period select').val());

        // always converted
        var converted = true;
        var unit = converted ? value.parameter_unit_conv : value.parameter_unit;

        // initialize highcharts
        chart[value.station_param_id] = Highcharts.stockChart('chart_'+value.station_param_id, {
            chart: {
                backgroundColor: '#FFF',
                zoomType: undefined,
                pinchType: undefined
            },
            title: {
                text: value.parameter_name + ' ['+ unit +']'
            },
            exporting: {
                // fallbackToExportServer: false,
                // allowHTML: true,
                // error: function(opt, e){
                    // console.dir(e);
                // },
                buttons: {
                    contextButton: {
                        menuItems: ["downloadJPEG"]
                    }
                },
                chartOptions: {
                    chart: {
                        events: {
                            load: function() {

                                this.renderer
                                // .image(chart_logo, 10, 5, 100, 20)
                                .image(logo, 10, 5, null, 25)
                                .add();
                            }
                        }
                    },
                    credits: {
                        enabled: false
                    }
                }
            },
            rangeSelector: {
                enabled: false
            },
            xAxis: {
                title:'Data',
                type:'datetime',
                labels: {
                    // step: 2,
                    useHtml: true,
                    formatter: function() {
                        var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                        if (diff > (5*24*3600*1000)){ // 5 giorni
                            return getFormattedDateHC(this.value, 'basic'); //global.js
                        }
                        else{
                            // this.chart.xAxis[0].labels.rotation = 0;
                            return getFormattedDateHC(this.value, 'basic_timeStartMin');
                        }
                    }

                }
            },
            yAxis: [
                {
                    labels: {
                        align: 'right'
                    },
                    title: {
                        margin: 25,
                        text: unit
                    }
                },
                {
                    opposite: false,
                    linkedTo: 0,
                    title: {
                        text: unit
                    },
                    lineWidth: 1
                }
            ],
            credits: {
                text: '©'+ chart_label,
                href: main_site
            },
            plotOptions: {
                series: {
                    label: {
                        connectorAllowed: false
                    },
                    dataGrouping: {
                        enabled: false
                    },
                    color: '#f87b00'
                },
                line: {
                    marker: {
                        enabled: (value.parameter_id == 11 || rangeDate <= 3 || (rangeDate > 3 && aggregation == 'dd')) ? true : false ,
                        radius: 3
                    },
                    lineWidth: value.parameter_id == 11 ? 0 : 2 // if wind direction
                }
            },
            series: [
                {
                    name: value.parameter_name,
                    data: value.station_param_values,
                    type: (value.parameter_treatment == 'sum') ? 'column' : 'line' // if pluviometro
                },
            ],

            responsive: {
                rules: [{
                    condition: {
                        maxWidth: 500
                    }
                }]
            }

        },
        // "complete" callback, draw logo of the agency
        function (chart) {
            chart.renderer
                .image(logo, 10, 5, null, 25)
                // .image(chart_logo, 10, 5, 100, 20) // value.station_logo 100, 20
                .add();

        });

        // if treatment is "sum" add series Cumulata (arriving from db)
        if(value.parameter_treatment == 'sum'){
            var cumul_series = {
                name: 'Cumulata',
                type: 'line',
                data: value.station_param_values_cum,
                color: 'rgb(6,209,222)'
            };

            // false to prevent multiple chart redraw
            chart[value.station_param_id].addSeries(cumul_series, false);
        }

        chart[value.station_param_id].redraw();

        // if there is a limit add it to the chart
        if (value.limit_value != null){

            var lineOption = {
                // className:undefined
                label:{
                     text: value.limit_note
                },
                color: '#0372A6',
                dashStyle: 'ShortDashDot',
                value: value.limit_value,
                width:2,
                zIndex: 3
            };

            // calculate 20% of the limit value for graphic aims
            var offset = parseFloat((value.limit_value / 100) * 20); // 20%

            chart[value.station_param_id].yAxis[0].addPlotLine(lineOption);
            // get vertival extremes shown by the chart
            var extremes = chart[value.station_param_id].yAxis[0].getExtremes();

            // if superior extreme is lower than the limit_value
            // -> set new superior extreme as limit_value + offset in order to make the limit visible
            if (extremes.max <= value.limit_value)
                chart[value.station_param_id].yAxis[0].setExtremes(null, (parseFloat(value.limit_value)+offset));
        }
    }

    /**
     * Function to create windorse chart: only for HH aggregation
     * No args needed
     */
    function createChartWR() {

        // number of days
        var rangeDate = $('#set-time-period select').val();
        // calculate the start date of the range
        var dateFrom = moment.utc().subtract(rangeDate, 'days').format('YYYY-MM-DD HH:00:00');

        // get data via an ajax call
        $.ajax({
            type : 'POST',
            url  : '/str_dataview_get_windrose_data',
            dataType : 'json',
            data: {
                id : st_id,
                from: dateFrom,
                to: moment.utc().format('YYYY-MM-DD HH:59:59')
            },
        })
        // callback handler that will be called on success
        .done(function(result) {
            console.dir(result);
            // drawing
            var seriesOptions = [];

            // initialize array of different typologies based on wind speed
            // from 0 to 0.5 not considered
            // = no wind
            seriesOptions[0] = {
                name: "0.5 - 3 m/s",
                data: result.json_debole,
            };
            seriesOptions[1] = {
                name: "3 - 5 m/s",
                data: result.json_moderata,
            };
            seriesOptions[2] = {
                name: "5 - 10 m/s",
                data: result.json_forte,
            };
            seriesOptions[3] = {
                name: "&gt; 10 m/s",
                data: result.json_molto_forte,
            };

            // Initialize chart
            windChart = new Highcharts.Chart('chart_wind', {
                chart: {
                    polar: true,
                    type: 'column',
                },
                title: {
                    text: 'Rosa dei venti'
                },
                pane: {
                    size: '85%'
                },
                exporting: {
                    buttons: {
                        contextButton: {
                            menuItems: ["downloadJPEG"]
                        }
                    },
                    chartOptions: {
                        chart: {
                            events: {
                                load: function() {
                                    this.renderer
                                    .image(chart_logo, 10, 5, 100, 20)
                                    .add();
                                }
                            }
                        }
                    }
                },
                legend: {
                    // reversed: true,
                    title: {
                        // add label to the legend for "CALMA" case
                        text: 'CALMA: '+result.perc_calma+'%'
                    },
                    align: 'right',
                    verticalAlign: 'top',
                    y: 100,
                    layout: 'vertical'
                },
                xAxis: {
                    tickmarkPlacement: 'on',
                    categories: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
                },
                yAxis: {
                    min: 0,
                    endOnTick: false,
                    showLastLabel: true,
                    title: {
                        text: 'Frequenza (%)'
                    },
                    labels: {
                        formatter: function () {
                            return this.value + '%';
                        }
                    },
                    reversedStacks: false
                },
                tooltip: {
                    valueSuffix: '%'
                },
                plotOptions: {
                    series: {
                        /*reversed: true,*/
                        stacking: 'normal',
                        shadow: false,
                        groupPadding: 0,
                        pointPlacement: 'on'
                    }
                },
                credits: {
                    text: '©'+chart_label,
                    href: main_site
                },
                colors: ['#e98131', '#3e78b2', '#939ba3', '#4c4f53', '#2ce9e7', '#f5ca00', '#f28f43', '#77a1e5', '#c42525', '#a6c96a'],
                series: seriesOptions
            },
            // "complete" callback, draw logo of the agency
            function (chart) {
                chart.renderer
                     .image(chart_logo, 10, 5, 100, 20)
                     .add();
            });

            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }

    /**
     * Function to initialize datatable with header and body html dynamically created
     * No args needed
     */
    function initTable(){

        // if table already initialized, clear it
        if(table){
            table.clear();
            table.destroy();
            $('#station-table thead').empty();
            $('#station-table tbody').empty();
        }

        // get selected info
        var aggregation = $("input[name=radioInline]:checked").val(); //hh dd
        var rangeDate = $('#set-time-period select').val(); // number days

        // calculate the start date of the range based on the chosen time aggregation
        var dateFrom;
        if(aggregation == 'dd'){
            dateFrom = moment.utc().subtract(rangeDate, 'days').format('YYYY-MM-DD 00:00:00');
        }
        else{
            dateFrom = moment.utc().subtract(rangeDate, 'days').format('YYYY-MM-DD HH:00:00');
        }

        // recover array of data for each parameter associated to the station
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_allparams_data_tbl',
            type: "post",
            dataType: "json",
            data: {
                id: st_id,
                aggr: aggregation,
                from: dateFrom,
                to: moment.utc().format('YYYY-MM-DD HH:59:59')
            },
        })
        .done(function(result) {
            // check result
            // if OK then fill main table
            // else show error message
            if(result.res == 'OK'){

                var values = result.data;
                // list of station parameters for columns setup
                var params = result.params;
                var n_params = 0;

                var dateFormat = 'basic_range';
                if( aggregation == 'dd')
                    dateFormat = 'basic';

                // columnsConfig contains the configuration of the table columns (thead)
                // for Data&Ora define how to render the first column with moment to be able to sort it
                var columnsConfig = [
                    {
                        title: 'Data & ora',
                        className: 'td-strong',
                        render: function ( data, type, row ) {
                            return (getFormattedDatePublic(row[0] , dateFormat));
                        },
                        visible: true
                    }
                ];

                // loop on each parameter and add the column into the configuration
                // counter +1 for each added parameter
                $.each(params, function(index, param){
                    if(aggregation == 'hh'){
                        n_params++;

                        columnsConfig.push({
                            title: param.parameter_fullname,
                            visible: true,
                            type: 'setlow'
                        });
                    }
                    else{
                        // wind parameters not considered in case of dd agreggation
                        if (param.parameter_windv == 0 && param.parameter_windd == 0){
                            n_params++;

                            columnsConfig.push({
                                title: param.parameter_fullname,
                                visible: true,
                                type: 'setlow'
                            });
                        }
                    }

                });

                // dynamically create table body based on number of added parameters in the columns configuration object
                var html_body = '';

                // loop through all retrieved data
                // for each element build a row to be added to the table
                $.each(values, function(index, value){
                    html_body += '<tr>\n';
                    // first column contains the data fulldate
                    html_body += '    <td>'+value['fulldate']+'</td>\n';
                    for(var i=0; i<n_params; i++){

                        html_body += '    <td>'+value['col'+i]+'</td>\n';
                    }

                    html_body += '</tr>\n';
                });

                // append html table body
                $('#station-table tbody').append(html_body);

                // initialize datatable plugin passing the columns configuration object
                table = $('#station-table').DataTable({
                    "dom": "Bfrtip",
                    searching: false,
                    responsive: true,
                    pageLength: 24,
                    columns: columnsConfig,
                    "language": {
                        "url": "/bobo-js/italian.json"
                    },
                    order: [[ 0, "desc" ]]
                });

                // refresh della tabella
                table.draw();
            }
            else{
                // show warning message
                swal("Attenzione", result.message, "info");
            }

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }

    /**
     * Function that retrieves 15 nearest stations
     * No args needed
     */
    function loadNearStations(){

        // get stations via an ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_near_stations',
            type: "post",
            dataType: "json",
            data: {
                stid: st_id
            },
        })
        .done(function(result) {
            var stations = result.stations;

            // clear list
            $('#nav-nearest .nearest-stations').empty();

            // variable to dynamically build html
            var html = '';
            var center;
            // create list of nearest stations with link in order to reload page with clicked station
            $.each(stations, function(idx, el){

                var station_color = 2;

                // create link only if current looped station is not equal to visible one
                if(el.main_station_id != st_id){
                    html += '<li><a href="/str_dataview_station/'+el.main_station_id+'">'+el.station_name+' ['+el.station_distance+' km]</a></li>';
                    station_color = 1;
                }
                else{
                    // create current station marker
                    var feature = new ol.Feature({
                        popup_flag: false,
                        geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.station_lon), parseFloat(el.station_lat)], 'EPSG:4326', 'EPSG:3857'))
                    });
                    // add marker to the layer of the main mini map
                    layer.getSource().addFeature(feature);
                    // fit view to marker
                    map.getView().fit(feature.getGeometry(), {
                        minResolution: 15
                    });
                }

                // create marker popup
                var desc = '<div>';
                desc += '    <h4>'+ el.station_name +'</h4>';
                desc += '    <strong>Distanza</strong>: '+el.station_distance+' km';
                desc += '    <p style="margin: 0;">';
                desc += '        <strong>Links : </strong><a href="/str_dataview_station/'+el.main_station_id+'">dati e anagrafica</a>';
                desc += '    </p>';
                desc += '</div>';

                // create feature and add it to the map
                var feature = new ol.Feature({
                    id: el.main_station_id,
                    type: 'station',
                    name: el.station_name,
                    description: desc,
                    network: el.st_network_name,
                    color: station_color,
                    icon: 'f3c5',
                    popup_flag: true,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.station_lon), parseFloat(el.station_lat)], 'EPSG:4326', 'EPSG:3857'))
                });

                // set marker id for search and filtering purposes
                feature.setId(el.station_id);
                // add feature to map's layer
                layerNear.getSource().addFeature(feature);
            });

            // append html list
            $('#nav-nearest .nearest-stations').append(html);
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");
        });
    }
});