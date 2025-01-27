/**
 * Document ready
 */
$( document ).ready(function() {
    // GLOBAL VARIABLES
    var chart;
    var table;
    var yearFrom = moment().format('YYYY');

    if(closureDate)
        $('.blocked-right strong').html(closureDate+'  <i class="fa-sharp fa-solid fa-circle-info"></i>');

    // general options for highcharts
    Highcharts.setOptions({
        colors: ['#39b905', '#199bff', '#d500ff', '#e20202', '#eeb700']
    });

    ///////////***** First BIG tab: VIEW VALIDATION *****///////////
{
    $('#show-container').hide();
    $('#show-provinces, #show-networks').select2();
    $('#show-stations').select2({
        matcher: searchGroupedSelect2
    });

    // variable for loadReport function
    var yearEnd = moment().format("YYYY-01-01");

    // Datepicker
    $('.input-year-datepicker').datepicker({
        format: 'yyyy',
        viewMode: 'years',
        minViewMode: 'years',
        endDate: yearEnd,
        language: 'it',
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        // startDate: start,
        // maxDate: end,
        // locale: dateRangePickerSettings.locale
    }).on('changeDate', function(e) {

        yearFrom = moment(e.date).format('YYYY');

        var stid = $( "#show-stations" ).val();
        if( stid != -1){
            console.log('loadStats');
            loadStats(yearFrom, stid);
        }

    });
    $('.input-year-datepicker').datepicker('update', yearEnd);

    // FILTERS
    ////////////////////////////////////////////////////////////

    /**
     * Networks and provinces filters change events
     */
    $( "#show-networks, #show-provinces" ).on( "change", function() {
        console.log('change net');
        // if networks changed then reset provinces
        if($(this).attr('id') == 'show-networks'){
            $("#show-provinces").val(-1);
        }

        var dest = $(this).data('dest');

        // get values
        var net = $('#show-networks').val();
        var prid = $('#show-provinces').val();
        // refresh stations list
        loadStationsByNet(net, prid, dest);
    });

    /**
     * Stations filter change events
     */
    $( "#show-stations" ).on( "change", function() {
        // get value
        var stid = parseInt($(this).val());
        // check id and if not equal to -1 refresh list of statistics per year and station
        if( stid != -1){
            console.log('loadStats');
            loadStats(yearFrom, stid);
        }
    });
    ////////////////////////////////////////////////////////////
    // END FILTERS

    $( "#show-refresh" ).on( "click", function(e) {
        e.preventDefault();

        // get value
        var stid = parseInt($("#show-stations").val());
        // check id and if not equal to -1 refresh list of statistics per year and station
        if( stid != -1){
            console.log('loadStats');
            loadStats(yearFrom, stid);
        }
    });
}
    ///////////***** /END First BIG tab: VIEW VALIDATION *****///////////


    ///////////***** Second BIG tab: SET VALIDATION *****///////////
{
    // hide elements
    $('.hide-el').hide();

    // variable for loadData function
    var dateTo = moment().subtract(1, 'month').endOf('month').format('YYYY-MM-DD 23:00:00');
    var dateFrom = moment().subtract(1, 'month').startOf('month').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // based on current quarter calculates date start and date end of the last semester
    var quarter = moment().quarter();
    var semesterStart;
    var semesterEnd;

    // if quarter lower or equal to 2
    // then pick last semester in the previous year
    // else pick it from the current year
    if(quarter <= 2){
        semesterStart = moment().subtract(1, 'year').quarter(3).startOf('quarter');
        semesterEnd = moment().subtract(1, 'year').quarter(4).endOf('quarter');
    }
    else{
        semesterStart = moment().quarter(1).startOf('quarter');
        semesterEnd = moment().quarter(2).endOf('quarter');
    }

    // Daterange picker
    $('#final-daterange').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: moment().subtract(1, 'day').format("DD/MM/YYYY"),
        minDate: (closureDate != '' ? closureDate : '01/01/1900'),
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultima settimana': [moment().subtract(1, 'week').startOf('week'), moment().subtract(1, 'week').endOf('week')],
            'Ultimo mese': [moment().subtract(1, 'month').startOf('month'), moment().subtract(1, 'month').endOf('month')],
            'Ultimo trimestre': [moment().subtract(1, 'quarter').startOf('quarter'), moment().subtract(1, 'quarter').endOf('quarter')],
            'Ultimo semestre': [semesterStart, semesterEnd],
            'Ultimo anno': [moment().subtract(1, 'year').startOf('year'), moment().subtract(1, 'year').endOf('year')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get data within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:00:00');

        // refresh data in the validation table
        loadData(dateFrom, dateTo);
    });

    // select2 initializations
    $('#provinces').select2();

    $('#stations').select2({
        matcher: searchGroupedSelect2,
        placeholder: "Seleziona stazioni..."
    });

    const addSelectAll = matches => {
        if (matches.length > 0) {
            // Insert a special "Select all matches" item at the start of the
            // list of matched items.
            return [
                {id: 'selectAll', text: 'Seleziona tutti', matchIds: matches.map(match => match.id)},
                ...matches
            ];
        }
    };

    const handleSelection = event => {
        if (event.params.data.id === 'selectAll') {
            curSelIds = $('#parameters').val() || [];
            $('#parameters').val([...curSelIds, ...event.params.data.matchIds]);
            $('#parameters').trigger('change');
        };
    };

    $('#parameters').select2({
        placeholder: "Seleziona parametri...",
        sorter: addSelectAll
    });

    $('#parameters').on('select2:select', handleSelection);

    // bootstrapToggle initialization
    $('#showconv').bootstrapToggle();

    // FILTERS
    ////////////////////////////////////////////////////////////
    /**
     * Provinces filter change event
     */
    $( "#provinces" ).on( "change", function() {
        var prid = $(this).val();
        // empty stations and trigger change
        $("#stations").val([]);
        $("#stations").trigger('change');

        var dest = $(this).data('dest');

        // reload stations linked to selected province
       loadStations(prid, dest);
    });

    /**
     * Others filters change event
     */
    $( "#stations, #parameters, #levels, #showconv" ).on( "change", function() {
        console.log('loadData');
        // refresh data in the validation table
        loadData(dateFrom, dateTo);
    });

    $('#reset-params').on('click', function(e){
        e.preventDefault();

        $('#parameters').val([]);
        $('#parameters').trigger('change');
    });
    ////////////////////////////////////////////////////////////
    // END FILTERS

    $( "#refresh" ).on( "click", function(e) {
        e.preventDefault();

        // refresh data in the validation table
        loadData(dateFrom, dateTo);
    });

    /**
     * Click event on table row's "show chart" button
     */
    $('#add-validation-tbl').on('click', '.show-chart', function(e){
        e.preventDefault();

        // get stprid stored in the tr element
        var stprid = $(this).parent().parent().data('id');
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_station_param_data',
            type: "post",
            dataType: "json",
            data: {
                stprid: stprid,
                from: dateFrom,
                to: dateTo,
                conv: $('#showconv').is(':checked')
            },
        })
        .done(function(result) {

            // console.dir(result);
            // check result
            // - if OK then create chart showing retrieved data from the server
            // - else show error message and close popup
            if(result.res == 'OK')
                createChart(result.data);
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
                // take care of popup
                $.magnificPopup.close();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // take care of popup
            $.magnificPopup.close();
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

    /**
     * Click event on table row's "submit" button
     */
    $('#add-validation-tbl').on('click', 'button[name="btn-submit"]', function(e){
        e.preventDefault();

        // get metadata from clicked button
        var lvl = $(this).data('lvl');
        var lvlText = $(this).text();
        // get stprid stored in tr element
        var stprid  = $(this).parent().parent().data('id');
        // get station and parameter name stored in siblings td
        var station = $(this).parent().parent().find('td:eq(1)').text();
        var param   = $(this).parent().parent().find('td:eq(2)').text();

        var moreText = '';
        if(lvl != 1){
            var previousPerc = $(this).parent().parent().find('[data-lvl="'+lvl+'"]').prev().text();
            if(previousPerc != '100%'){
                moreText = 'Inoltre la validazione per i livelli inferiori <strong>non è COMPLETA</strong>!<br><br>';
            }
        }

        // format dates
        var dateRange = 'Da <strong>'+moment(dateFrom).format('DD/MM/YYYY')+'</strong> a <strong>'+moment(dateTo).format('DD/MM/YYYY 23:00')+'</strong>';

        // show confirm message with summary information
        swal({
            title: "Validazione dei dati",
            text: "<div class=\"lightbox-txt\"><h4>Stai per validare i <strong>seguenti elementi</strong></h4><ul> <li>Stazione: <strong>"+station+"</strong></li><li>Parametro: <strong>"+param+"</strong></li><li>Validazione <strong>"+lvlText+"</strong></li><li>"+dateRange+"</li></ul>"+moreText+"<hr class=\"hr-dashed\"><strong>Vuoi Proseguire?</strong></div>",
            html: true,
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, Valida",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();

            // ajax call
            var jqxhr = $.ajax({
                url: '/dat_validaz_finale_put_final_validation',
                type: "post",
                dataType: "json",
                data: {
                    stprid: stprid,
                    from: dateFrom,
                    to: dateTo,
                    code: lvl
                }
            })
            .done(function(result) {

                // check result
                // - if OK then do more controls
                // - else error message
                if(result.res == 'OK'){
                    // check number of rows affected by the update
                    // if equal to zero then data have been already validated with a greater code than the one selected
                    var rows = result.rows;
                    if(rows > 0){
                        // success message
                        swal("Fatto!", "Validazione effettuata con successo", "success");
                        // reload data
                        loadData(dateFrom, dateTo);
                        // refresh activities log
                        loadActivitiesLog(regDateFrom, regDateTo);
                    }
                    else{
                        // warning message
                        swal({
                            title: "Attenzione",
                            text: "Non è stata applicata <strong>nessuna modifica</strong>!<br> I dati sono già stati certificati con un <strong>codice di livello superiore</strong> a quello selezionato.",
                            html: true,
                            type: "warning"
                        });
                        // at the end of the process hide preloader
                        $('.inner-preloader').hide();
                    }
                }
                else{
                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                    // error message
                    swal("Errore!", "Errore durante la procedura: la modifica non è stata applicata!", "error");
                }
            })
            .fail(function(xhr, err) {
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
                // error message
                swal("Errore!", "Errore durante la procedura: la modifica non è stata applicata!", "error");

            });
        });

    });
}
    ///////////***** /END Second BIG tab: SET VALIDATION *****///////////

    ///////////***** Third BIG tab: REGISTRO LOG *****///////////
{
    // hide elements
    $('.hide-register-el').hide();

    // variable for loadData function
    var regDateTo = moment().format('YYYY-MM-DD HH:mm:00');
    var regDateFrom = moment().subtract(1, 'week').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var regStart = moment(regDateFrom).format("DD/MM/YYYY");
    var regEnd = moment(regDateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#register-daterange').daterangepicker({
        startDate: regStart,
        endDate: regEnd,
        maxDate: regEnd,
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

        //on change event, get data within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        regDateFrom = start.format('YYYY-MM-DD');
        regDateTo = end.format('YYYY-MM-DD 23:59:00');

        // refresh data in the validation table
        loadActivitiesLog(regDateFrom, regDateTo);
    });

    // initialize select2
    $('#register-provinces, #register-stations, #register-user').select2();

    // datatable
    table = $('#register-table').DataTable({
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
        "order": [[ 0, "desc" ]]
    });

    // FILTERS
    ////////////////////////////////////////////////////////////

    /**
     * Networks and provinces filters change events
     * #register-networks,
     */
    $( "#register-provinces" ).on( "change", function() {
        console.log('change net');
        // if networks changed then reset provinces
        // if($(this).attr('id') == 'register-networks'){
        //     $("#register-provinces").val(-1);
        // }

        var dest = $(this).data('dest');

        // get values
        // var net = $('#register-networks').val();
        var prid = $('#register-provinces').val();
        // refresh stations list
        loadStations(prid, dest);
    });

    /**
     * Stations and user filter change events
     */
    $( "#register-levels, #register-provinces, #register-stations, #register-user" ).on( "change", function() {
        // refresh table with the list of activities
        loadActivitiesLog(regDateFrom, regDateTo);
    });


    loadActivitiesLog(regDateFrom, regDateTo);
}
    ///////////***** /END Third BIG tab: REGISTRO LOG *****///////////

    // FUNCTIONS
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
     * Function that builds a td element with specific classes based on passed value
     *
     * @param {text} value.
     * @param {integer} month Index of month [0-11]
     *
     * @return string containing the td's html
     */
    function formatTd(value, month) {
        // get selected station id
        var stid  = parseInt($('#show-stations').val());
        // format in milliseconds first and last date of passed month for the selected year
        var start = String(moment.utc(yearFrom+'-'+String(month).leftPad(2), 'YYYY-MM').startOf('month').valueOf());
        var end   = String(moment.utc(yearFrom+'-'+String(month).leftPad(2), 'YYYY-MM').endOf('month').valueOf());

        if(value == 100)
            return '<td>'+value+'</td>';
        else //if (value == 0)
            return '<td class="few-data">'+value+'</td>';
        // else
            // if value between 1 and 99 then add a link to Validazione tool
            // return '<td class="few-data">'+value+' <a href="/dat_validazione/'+stid+'/'+start+'/'+end+'" target="_blank" data-toggle="tooltip" data-original-title="Visualizza in VALIDAZIONE"><i class="fa-sharp fa-solid fa-arrow-up-right-from-square"></i></a></td>';
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     */
    function loadStationsByNet(net, prid, dest){

        // load stations via an ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_stations_by_network',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
            },
        })
        .done(function(result) {

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#'+dest+'-stations').empty();
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

                    $('#'+dest+'-provinces').empty();
                    $('#'+dest+'-provinces').append('<option value="-1">Seleziona provincia...</option>');
                    $('#'+dest+'-provinces').append(optsProv);
                    $('#'+dest+'-provinces').append('</optgroup>');

                    $('#'+dest+'-provinces').val(-1);
                }

                // append options
                $('#'+dest+'-stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest+'-stations').append(opts);
                $('#'+dest+'-stations').append('</optgroup>');
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
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     */
    function loadStations(prid, dest){
        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();

                var stations = result.stations;

                // variable for dynamically building the html
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

                if(dest == 'register-stations'){
                    $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                }

                // append options
                $('#'+dest).append(opts);
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
     * Function that retrieves validation statistics for a given station in a selected year.
     *
     * @param {integer} year
     * @param {integer} stid Station ID
     */
    function loadStats(year, stid){
        // hide container
        $('.station-validation').hide();

        // clear tables
        $('#add-validation-tbl-1 tbody').empty();
        $('#add-validation-tbl-2 tbody').empty();
        $('#add-validation-tbl-4 tbody').empty();
        $('#add-validation-tbl-8 tbody').empty();

        // clear charts
        $('#status-charts .row').empty();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_validation_per_year',
            type: "post",
            dataType: "json",
            data: {
                year: year,
                stid: stid
            },
        })
        .done(function(result) {

            console.dir(result);
            // get selected station name from select
            var station = $('#show-stations option:selected').text();
            $('#show-container h3 strong').text(station);

            // check result
            // if OK then fill table with data
            // else show error message
            if(result.res == 'OK'){
                var data = result.data;
                var codes = result.codes;
                // variable for dynamically building the html
                var htmlTbl1 = '';
                var htmlTbl2 = '';
                var htmlTbl4 = '';
                var htmlTbl8 = '';

                // loop through all elements and for each row build:
                // - a html tr to be added to the table
                // - a div element as container for the spiderweb chart
                data.forEach(function(el){

                    var html ='<div class="col-xl-4 col-lg-6 m-b-25" id="chart-'+el.stpr_id+'"></div>\n';
                    $('#status-charts .row').append(html);

                    // parse json of statistics
                    var stats = JSON.parse(el.stats_obj);

                    htmlTbl1 += '<tr data-stprid="'+el.stpr_id+'">';
                    htmlTbl2 += '<tr data-stprid="'+el.stpr_id+'">';
                    htmlTbl4 += '<tr data-stprid="'+el.stpr_id+'">';
                    htmlTbl8 += '<tr data-stprid="'+el.stpr_id+'">';

                    htmlTbl1 += '<th>'+el.param_name+'</th>';
                    htmlTbl2 += '<th>'+el.param_name+'</th>';
                    htmlTbl4 += '<th>'+el.param_name+'</th>';
                    htmlTbl8 += '<th>'+el.param_name+'</th>';

                    var statsObj = {
                        lvl1: [],
                        lvl2: [],
                        lvl4: [],
                        lvl8: []
                    };

                    // loop through all elements and for each row build:
                    // - one td for each month
                    // - a series for the spiderweb chart
                    stats.forEach(function(el2){
                        htmlTbl1 += formatTd(el2.obj.perc_validity_lvl1, el2.month);
                        htmlTbl2 += formatTd(el2.obj.perc_validity_lvl2, el2.month);
                        htmlTbl4 += formatTd(el2.obj.perc_validity_lvl4, el2.month);
                        htmlTbl8 += formatTd(el2.obj.perc_validity_lvl8, el2.month);

                        statsObj.lvl1.push([ el2.month-1, el2.obj.perc_validity_lvl1 ]);
                        statsObj.lvl2.push([ el2.month-1, el2.obj.perc_validity_lvl2 ]);
                        statsObj.lvl4.push([ el2.month-1, el2.obj.perc_validity_lvl4 ]);
                        statsObj.lvl8.push([ el2.month-1, el2.obj.perc_validity_lvl8 ]);

                    });

                    // close row
                    htmlTbl1 += '</tr>';
                    htmlTbl2 += '</tr>';
                    htmlTbl4 += '</tr>';
                    htmlTbl8 += '</tr>';

                    // create spiderweb chart
                    // inside setTimeout in order to run function asynchronously
                    setTimeout(function(){
                        createSpiderwebChart(el.stpr_id, el.param_name, codes, statsObj);
                    }, 10);

                });

                // append new html to tables tbody
                $('#add-validation-tbl-1 tbody').html(htmlTbl1);
                $('#add-validation-tbl-2 tbody').html(htmlTbl2);
                $('#add-validation-tbl-4 tbody').html(htmlTbl4);
                $('#add-validation-tbl-8 tbody').html(htmlTbl8);

                // show only tables for available codes
                codes.forEach(function(el){
                    $('#title-validation-tbl-'+el.fvc_code_id).text(el.fvc_code_desc);
                    $('#title-validation-tbl-'+el.fvc_code_id).closest('.station-validation').show();
                });

                $('#show-container').show('slow');
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
    };

    /**
     * Function that creates a spiderweb chart object for a given series
     *
     * @param {integer} index Html element suffix
     * @param {text} name CHart title
     * @param {array} codes Array of available codes
     * @param {obj} data Object containing data of the series
     */
    function createSpiderwebChart(index, name, codes, data){

        var tmpChart = Highcharts.chart( 'chart-'+index, {
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
            }
        });

        // loop through all codes
        // for each element build a series
        codes.forEach(function(el){

            var series = {
                name: el.fvc_code_desc,
                data: data['lvl'+el.fvc_code_id]
            };
            // add series to chart without redrawing it
            tmpChart.addSeries(series, false);
        });
        // redraw char all at once
        tmpChart.redraw();
    }

    /**
     * Function that retrieves the log of all activities for a given station and in a specific daterange
     *
     * @param {integer} from Date start of the range
     * @param {integer} to   Date end of the range
     */
    function loadActivitiesLog(from, to){

        var lvl  = parseInt($('#register-levels').val());
        var prid = parseInt($('#register-provinces').val());
        var stid = parseInt($('#register-stations').val());
        var usid = parseInt($('#register-user').val());

        // reset table
        if(table)
            table.clear();

        // check validity of selected elements
        // if(stid == -1 && usid == -1){
        //     $('.hide-register-el').hide('slow');
        //     return;
        // }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_activities_log',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                lvl: lvl,
                prid: prid,
                stid: stid,
                usid: usid
            },
        })
        .done(function(result) {

            // check result
            // if OK then fill table with data
            // else show error message
            if(result.res == 'OK'){
                var activities = result.data;
                // check if at least one element exists
                if( activities.length > 0 ){
                    // variable for dynamically building the html
                    var html = '';
                    // loop through all elements
                    // for each row build a html tr to be added to the table
                    activities.forEach(function(el){
                        html += '<tr>';
                        html += '    <td>'+getFormattedDateDT(el.fvl_insert_ts, 'basic_timeStartMin')+'</td>';
                        html += '    <td><span class="valid-level code-'+el.fvc_code_id+'"></span> '+el.fvc_code_desc+'</td>';
                        html += '    <td class="bobo-nowrap operators">';
                        html += '        <img src="'+el.us_avatar_thumb+'">';
                        html += '        '+el.user_fullname;
                        html += '    </td>';
                        html += '    <td>'+el.station_name+'</td>';
                        html += '    <td>'+el.param_name+'</td>';
                        html += '    <td>'+el.fvl_date_range+'</td>';
                        html += '    <td>'+el.fvl_rows+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    $('.hide-register-el').show('slow');

                    // add rows to datatable by using html object
                    table.rows.add($( html ));
                    // // redraw it
                    table.draw();
                    // // adjust columns size
                    // table.columns.adjust();

                } else {
                    table.draw();
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
    };

    /**
     * Function that retrieves data and validation statistics for selected stations and parameters.
     *
     * @param {integer} from Start date
     * @param {integer} to   End date
     */
    function loadData(from, to){

        // get filters values
        var stations = $('#stations').val();
        var params = $('#parameters').val();
        var lvl = $('#levels').val();
        var lvlText = $('#levels option:selected').text();

        // check validity of selected elements
        if(stations.length == 0 || params.length == 0 || lvl == -1){
            $('.hide-el').hide('slow');
            return;
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // clear table
        $('#add-validation-tbl tbody').empty();
        $('#add-validation-tbl th').removeClass('grey-cell');

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_validaz_finale_get_validation_table',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                stid: JSON.stringify(stations),
                param: JSON.stringify(params),
                conv: $('#showconv').is(':checked')
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill table with data
            // else show error message
            if(result.res == 'OK'){
                // set content title
                $('#title-lvl').text(lvlText);

                var data = result.data;
                var codes = result.codes;

                // check if at least one element exists
                if(data.length > 0){
                    // variable for dynamically building the html
                    var html = '';

                    console.dir(codes);
                    // loop through all elements
                    // for each row, build a html tr to be added to the table
                    data.forEach(function(el, idx){
                        // parse json of statistics
                        var stat = JSON.parse(el.stats_obj);

                        html += '<tr data-id="'+el.stpr_id+'">';
                        html += '    <td>';
                        html += '        <a href="#lightbox-chart" class="show-chart" data-toggle="tooltip" data-original-title="Visualizza grafico"> <i class="fa-solid fa-chart-column text-info"></i> </a>';
                        html += '    </td>';
                        html += '    <td class="name-place">'+el.station_name+'</td>';
                        html += '    <td class="name-place">'+el.param_name+'</td>';
                        html += '    <td>'+stat.perc_value+'%</td>';
                        html += '    <td>'+stat.perc_valid_values+'%</td>';
                        html += '    <td>'+formatTextField(stat.min_value)+'</td>';
                        html += '    <td>'+formatTextField(stat.max_value)+'</td>';
                        html += '    <td>'+formatTextField(stat.avg_value)+'</td>';
                        // create a td element for each available code
                        codes.forEach(function(code){
                            html += '    <td class="val-lvl" data-lvl="'+code.fvc_code_id+'">'+stat['perc_validity_lvl'+code.fvc_code_id]+'%</td>';
                        });

                        html += '    <td class="text-right">';
                        // format in milliseconds first and last date of passed month for the selected year
                        var start = String(moment.utc(from).valueOf());
                        var end   = String(moment.utc(to).valueOf());
                        if(stat['perc_validity_lvl'+lvl] == 100)
                            html += '        <a href="/dat_validazione/'+el.station_id+'/'+start+'/'+end+'" target="_blank" data-toggle="tooltip" data-original-title="Visualizza in VALIDAZIONE"><i class="fa-solid fa-arrow-up-right-from-square"></i></a>&nbsp;&nbsp;<button type="button" class="btn btn-success btn-sm" name="btn-submit" data-toggle="tooltip" data-original-title="Dati già validati" disabled> <i class="fa-solid fa-check"></i> Validato</button>';
                        else{

                            var classDisabled = '';
                            var txtDisabled = '';
                            if(el.station_update == 0){
                                classDisabled = 'disabled';
                                txtDisabled = 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione';
                            }

                            html += '        <a href="/dat_validazione/'+el.station_id+'/'+start+'/'+end+'" target="_blank" data-toggle="tooltip" data-original-title="Visualizza in VALIDAZIONE"><i class="fa-solid fa-arrow-up-right-from-square"></i></a>&nbsp;&nbsp;<button type="button" class="btn btn-info btn-sm" name="btn-submit" data-toggle="tooltip" data-original-title="'+txtDisabled+'" data-lvl="'+lvl+'" '+classDisabled+'> <i class="fa-regular fa-play"></i> <strong>'+lvlText+'</strong></button>';
                        }
                        html += '    </td>';
                        html += '</tr>';

                    });

                    // append html to table
                    $('#add-validation-tbl tbody').append(html);

                    // take care of td classes based on selected level and td value
                    $('#add-validation-tbl th[data-lvl="'+lvl+'"]').addClass('grey-cell');
                    $('#add-validation-tbl td[data-lvl="'+lvl+'"]').addClass('grey-cell');
                    $('#add-validation-tbl td.val-lvl').each(function(){

                        if($(this).text() == '100%')
                            $(this).addClass('font-weight-bold text-success');
                    });

                    // plugin initialization
                    $('.show-chart').magnificPopup({
                        type:'inline',
                        // Allow opening popup on middle mouse click.
                        // Always set it to true if you don't provide alternative source in href.
                        midClick: true,
                        callbacks: {
                            close: function() {
                                console.log('close');
                                if(chart){
                                    chart.destroy();
                                    chart = null;
                                }
                            }
                        }
                    });

                    // initializes the tooltips of all lines
                    $('#add-validation-tbl [data-toggle="tooltip"]').tooltip();


                    // show title and table div
                    $('.hide-el').show('slow');
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

    /**
     * Function that creates a chart object for a given series
     *
     * @param {obj} value Object containing data and metadata of the series
     */
    function createChart(value){

        var conv = $('#showconv').is(':checked');

        // --------- DEFAULT OPTIONS ---------- //
        var chart_title = value.parameter_name;
        var chart_type = 'line';
        // ------------------------------------ //


        if(value.parameter_unit != ''){
            chart_title = value.parameter_name + ' ['+(conv ? value.parameter_unit_conv : value.parameter_unit)+']';
        }

        if(value.station_param_measure_type_id == 3 || value.parameter_treatment == 'sum'){ //on demand, random o somme
            chart_type = 'column';
        }

        if(value.station_param_cadence_min != null){
            chart_pointInterval = value.station_param_cadence_min*60*1000;
        }

        // parse json data
        var stationData = JSON.parse(value.station_data);

        chart = Highcharts.chart('container-chart', {
            // -- DISABILITATE TUTTE -- //
            chart:{
                zooming: {
                    type: "xy",
                    mouseWheel:{
                        enabled:true
                    }
                }
            },
            title: {
                text: chart_title
            },
            rangeSelector: {
                enabled: false
            },
            boost: {
                enabled: false
            },
            xAxis: {
                title:'Data',
                type:'datetime',
                ordinal: false,
                labels: {
                    // step: 2,
                    useHtml: true,
                    formatter: function() {
                        var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                        if (diff > (5*24*3600*1000)){ // 5 giorni
                            return getFormattedDateHC(this.value, 'basic'); //global.js
                        }
                        else{
                            return getFormattedDateHC(this.value, 'basic_timeStartMin');
                        }
                    }

                }
            },
            yAxis: {
                title: {
                    text: conv ? value.parameter_unit_conv : value.parameter_unit
                }
            },
            plotOptions: {
                series: {
                    dataGrouping:{
                        enabled: false
                    },
                    label: {
                        connectorAllowed: false
                    },
                    events: {
                        click: function (e) {
                            if(e.ctrlKey){
                                // on CTRL + click event
                                // get point fulldate and series stprid
                                var stprid = parseInt(value.station_param_id);
                                // creates a dynamic url for "Validazione" tool
                                var url = '/dat_validazione/'+stprid+'/'+e.point.x;
                                window.open(url, '_blank');
                            }
                        }
                    }
                },
                line: {
                    marker: {
                        enabled: false,
                        // radius: 3
                    }
                }
            },
            tooltip: {
                valueDecimals: 2,
                split: false,
                dateTimeLabelFormats: {
                    day: '%A %e %b %Y',
                    hour: '%A %e %b, %H:%M',
                    minute: '%A %e %b, %H:%M',
                    second: '%A %e %b, %H:%M:%S',
                    week: '%A %e %b %Y',
                    year: '%Y'
                }
            }
        });

        console.log(value.station_param_cadence_type_id)

        // create "Valid" data series
        var valid = {
            name: value.parameter_name+' - valido',
            data: stationData.meanvalue_valid,
            type: chart_type,
            color: '#15598f',
            marker: {
                enabled: (value.station_param_cadence_type_id > 5 ? true : false),
                radius: (value.station_param_cadence_type_id > 5 ? 3 : 0)
            },
            lineWidth: 2,
            zIndex: 99
        };
        // add series to chart without redrawing it
        chart.addSeries(valid, false);

        // create "Not valid" series
        var notValid = {
            name: value.parameter_name+' - non valido',
            data: stationData.meanvalue_not_valid,
            type: chart_type,
            color: '#da3a89',
            marker: {
                enabled: true,
                radius: 3
            },
            lineWidth: 2,
            zIndex: 99
        };
        // add series to chart without redrawing it
        chart.addSeries(notValid, false);
        // redraw chart all at once
        chart.redraw();
    }

});