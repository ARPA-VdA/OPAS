/**
 * Document ready.
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var tableVal;

    // hide container
    $('.main-tab, .hide-el').hide();

    // variable for loadData function
    var dateFrom = moment().format('YYYY-01-01');
    var end = moment(dateFrom).format("YYYY-01-01");

    // Datepicker
    $('.input-daterange-datepicker').datepicker({
        format: 'yyyy',
        viewMode: 'years',
        minViewMode: 'years',
        endDate: end,
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        // startDate: start,
        // maxDate: end,
        // locale: dateRangePickerSettings.locale
    }).on('changeDate', function(e) {
        dateFrom = moment(e.date).format('YYYY-01-01');

        // retrieve selected station
        var stid = $( "#stations" ).val();
        // check if station is not equal to -1
        if( stid != -1){
            console.log('loadData');
            // refresh data
            loadData(dateFrom, stid);
        }
    });

    // set first date
    $('.input-daterange-datepicker').datepicker('update', end);

    // filter initialization
    $( "#provinces, #networks" ).select2();
    $( "#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    /*
     * Filter change event
     */
    $( "#provinces, #networks" ).on( "change", function(e) {
        e.preventDefault();

        // check if event occured on "networks" filter
        if($(this).attr('id') == 'networks'){
            // reset province
            $("#provinces").val(-1);
        }

        // get selected data
        var network = parseInt($( "#networks" ).val());
        var province = parseInt($("#provinces").val());

        // reload stations
        loadStations(province, network);
    });

    // select option -1 and load all stations
    $( "#networks" ).trigger("change");

    /*
     * Filter change event
     */
    $( "#stations" ).on("change", function(e){
        e.preventDefault();

        // retrieve station id and name
        var stid = $(this).val();
        var stname = $(this).find('option:selected').text();

        // check station id value
        // if not equal to -1 then show html container, set the title and get data
        // otherwise reset visibility of container and destroy table
        if(stid != -1){
            $("#sel-station").html(stname);
            $('.main-tab, .hide-el').show();
            // refresh data
            loadData(dateFrom, stid);
        }
        else{
            $('.main-tab, .hide-el').hide();
            $("#sel-station").html("");
            table.destroy();
            table.clearData();
        }
    });

    /*
     * Click event on button "Download CSV"
     */
    $( "#download-csv" ).on('click', function(e){
        e.preventDefault();
        // create file name
        var fileName = 'copertura_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY")+'.csv';
        table.download("csv", fileName, {}, "all");
    });

    /*
     * Click event on button "Download XLSX"
     */
    $( "#download-xlsx" ).on('click', function(e){
        e.preventDefault();
        // create file name
        var fileName = 'copertura_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY")+'.xlsx';
        table.download("xlsx", fileName, {sheetName:"Copertura"});
    });

    /*
     * Click event on button "Download CSV" for validity table
     */
    $( "#download-csv-validity" ).on('click', function(e){
        e.preventDefault();
        // create file name
        var fileName = 'copertura_validita_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY")+'.csv';
        table.download("csv", fileName, {}, "all");
    });

    /*
     * Click event on button "Download XLSX" for validity table
     */
    $( "#download-xlsx-validity" ).on('click', function(e){
        e.preventDefault();
        // create file name
        var fileName = 'copertura_validita_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY")+'.xlsx';
        table.download("xlsx", fileName, {sheetName:"Copertura validità"});
    });

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} province Province ID.
     * @param {integer} network Network ID.
     */
    function loadStations(province, network){

        console.log('loadStations: '+province+' '+network);

        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_ana_copertura_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: province,
                net: network
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
                if(province == -1){
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
    }

    /**
     * Function that retrieves data coverage statistics for a given station and year
     *
     * @param {date} from Reference Year.
     * @param {integer} stid Network ID.
     */
    function loadData(from, stid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_ana_copertura_get_data_coverage',
            type: "post",
            dataType: "json",
            data: {
                year: dateFrom,
                stid: stid
            },
        })
        .done(function(result) {
            // check result
            // if OK create tables and charts
            if(result.res == 'OK'){
                // show container
                $('.main-tab').show();
                createTables(result);
                createCharts(result);
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }

    /**
     * Function that create Tabulator table
     *
     * @param {object} result Ajax result.
     */
    function createTables(result){

        // create array of columns
        var columns = [];
        column_fulldate = {
            title: "Data",
            field: "fulldate",
            width: 150,
            frozen: true,
            headerSort: false,
            formatter:function(cell, formatterParams, onRendered){
                //cell - the cell component
                //formatterParams - parameters set for the column
                //onRendered - function to call when the formatter has been rendered
                return getFormattedDateDT(cell.getValue(), 'text_month'); //global.js
            }
        };

        columns.push(column_fulldate);
        // loop through alla station parameters
        // for each element build a table column
        $.each(result.params, function (data_key, data_value) {

            // var column_name = names.find(x => x.st_pr_id === data_value).column_name;
            var column_name = data_value.parameter_name;

            column_obj = {
                title: column_name,
                field: 'field_'+data_key,
                headerSort: false,
                // function that add a specific background to the cell based on contained value
                formatter: function(cell, formatterParams, onRendered){
                    var value = cell.getValue();

                    if(value && value != 'nd'){

                        value = parseInt(value);
                        if(value  == 0){
                           cell.getElement().classList.add("no-data");
                        }
                        else if (value >= 1 && value < 75){
                            cell.getElement().classList.add("few-data");
                        }
                        else if (value >= 75 && value < 100){
                            cell.getElement().classList.add("lot-data");
                        }
                        else{
                            cell.getElement().classList.add("all-data");
                       }
                    }
                    else{
                        cell.getElement().classList.add("all-data");
                        value = 'nd';
                    }
                    return value;
                }
            };

            columns.push(column_obj);

        });

        // initialize Tabulator by passing the array of columns
        // add coverage statistics for all data
        table = new Tabulator("#data-coverage", {
            locale: 'it',
            height:'100%',
            data: result.data,
            layout:"fitData", //fitColumn
            columns: columns,
            index:"fulldate",
            // pagination: true,
            // paginationMode: "local",
            // paginationSize: 12,
            placeholder:"Nessun dato"
        });

        // initialize Tabulator by passing the array of columns
        // add coverage statistics for valid data
        tableVal = new Tabulator("#data-validity", {
            locale: 'it',
            height:'100%',
            data: result.valid,
            layout:"fitData", //fitColumn
            columns: columns,
            index:"fulldate",
            // pagination: true,
            // paginationMode: "local",
            // paginationSize: 12,
            placeholder:"Nessun dato"
        });
    }

    /**
     * Function that create containers for all spiderweb charts
     *
     * @param {object} result Ajax result.
     */
    function createCharts(result){

        // reset container
        $('#coverage-chart .row').empty();
        var charts = result.charts;
        var params = result.params;

        // loop through results
        // for each element create the container for a "spiderweb" chart
        $.each(charts, function(index, chart){
            var html ='<div class="col-xl-4 col-lg-6 m-b-25" id="chart_'+chart.measure_id+'"></div>\n';
            // append div
            $('#coverage-chart .row').append(html);
            var name = params[index].parameter_name;
            // use setTimeout in order to make chart creation asynchronous
            setTimeout(function(){
                createSingleChart(chart, name);
            }, 10);
        });
    }

    /**
     * Function that initialize Highcharts
     *
     * @param {object} chart object.
     * @param {text} name Parameter name.
     */
    function createSingleChart(chart, name){

        // initialize Highcharts plugin
        Highcharts.chart('chart_'+chart.measure_id, {
            chart: {
                polar: true,
                type: 'line',
                zooming: {
                    mouseWheel:{
                        enabled:false
                    }
                }
            },
            title: {
                text: name
            },
            xAxis: {
                categories: ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno', 'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'],
                tickmarkPlacement: 'on',
                lineWidth: 0
            },
            yAxis: {
                min: 0,
                max: 100,
                gridLineInterpolation: 'polygon',
                lineWidth: 0,
            },
            tooltip: {
                shared: true,
                valueSuffix: ' %'
            },
            credits: {
                text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                href: company_web
            },
            series: [{
                name: 'Dati ricevuti',
                data: chart.measure_perc
            }, {
                name: 'Dati validi',
                data: chart.measure_validity_perc
            }]
        });
    }
});

