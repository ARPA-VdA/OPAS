/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;

    // variable for runImagesScript function
    var dateTo = moment().format('YYYY-MM-DD');
    var dateFrom = moment(dateTo).subtract(12, 'months').format('YYYY-MM-DD');

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
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimi 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
            'Anno scorso': [moment().subtract(1, 'year').startOf('year'), moment().subtract(1, 'year').endOf('year')]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event update global variables
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD');
    });

    // datatable
    table = $('#charts-table').DataTable({
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "ordering": false,
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
            }
            // { "type": "datetime", "targets": 1 }
        ]
    });

    $( "#openair-prov-poll, #openair-prov-wea" ).select2();

    // select2 initialization
    $( "#openair-stat-poll, #openair-stat-wea" ).select2({
        placeholder: "Seleziona stazioni...",
        allowClear: false,
        matcher: searchGroupedSelect2
    });

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    $( "#openair-prov-poll" ).on( "change", function() {
        var prid = $(this).val();
        var dest = $(this).data('change');
        // refresh stations list for "dest" select
        loadStations(prid, dest);
    });

    $( "#openair-prov-wea" ).on( "change", function() {
        var prid = $(this).val();
        var dest = $(this).data('change');
        // refresh stations list for "dest" select
        loadStations(prid, dest);
    });
    /////////////////////////////////////////////////////////////////////
    // END CHANGE EVENTS

    // select option -1 and load all stations
    $("#openair-prov-wea, #openair-prov-poll").trigger("change");

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    $('#charts-table').on('click', '.show-charts', function(e){
        e.preventDefault();

        // get job id stored in tr
        var jobid = parseInt($(this).parent().parent().data("id"));

        //check if the job's detail is already open
        if( $('#charts'+jobid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#charts' + jobid + '"]').tab('show');
            return;
        }

        // load charts created by the openair script
        // with arguments passed by the job object
        loadCharts(jobid);
    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    //FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    $('#openair-insert-num, #openair-insert-step').hide();

    // radio click event
    $('input[name="openair-scale"]').click(function() {
        // retrieve checked value
        var me = $(this).val();
        // manage visibility of other inputs
        if($('#openair-scale-numb').is(':checked')) {
            $('#openair-insert-num').show();
            $('#openair-insert-step').hide();
        }else if ($('#openair-scale-step').is(':checked')) {
            $('#openair-insert-num').hide();
            $('#openair-insert-step').show();
        } else {
            $('#openair-insert-num, #openair-insert-step').hide();
        }
    });

    /**
     * Validation method: check array order.
     *
     * @param {array}         value User insert value.
     * @param {html_element} element HTML element containig the value.
     *
     * @return If the array is ascending, the value;
     *         If not, the alert message.
     */
    $.validator.addMethod(
        "isAscending",
        function(value, element) {
            var arr = value.split(',');
            return this.optional(element) || arr.every(function (x, i) {
                return i === 0 || parseInt(x) >= parseInt(arr[i - 1]);
            });
        },
        "La sequenza deve essere in ordine crescente"
    );


    // validate form
    var validator = $('#openair-form').validate({ // initialize the plugin
        rules: {
            "openair-date" : {
                required: true
            },
            "openair-wind-calm" : {
                required: true,
                dotSeparator: true,
                min: 0.1,
                max: 1
            },
            "openair-stat-poll":{
                required: true,
                min: 0
            },
            "openair-stat-wea":{
                required: true,
                min: 0
            },
            "openair-limit-low":{
                dotSeparator: true
            },
            "openair-limit-high":{
                dotSeparator: true
            },
            "openair-insert-num":{
                required: function(){
                    return parseInt($('input[name="openair-scale"]:checked').val()) == 1;
                }
            },
            "openair-insert-step":{
                required: function(){
                    return parseInt($('input[name="openair-scale"]:checked').val()) == 2;
                },
                regex: '^(?:[0-9]+,)*[0-9]+$',
                isAscending: true
            }
        },
        messages: {
            "openair-date" : {
                required: "Inserire intervallo date"
            },
            "openair-wind-calm" : {
                required: "Inserire valore",
                min: "Valore minimo pari a 0.1",
                max: "Valore massimo pari a 1"
            },
            "openair-stat-poll":{
                required: "Selezionare una stazione",
                min: "Selezionare una stazione"
            },
            "openair-stat-wea":{
                required: "Selezionare una stazione",
                min: "Selezionare una stazione"
            },
            "openair-insert-num":{
                required: "Inserire numero di fasce"
            },
            "openair-insert-step":{
                required: "Inserire ripartizioni"
            }
        },
        ignore: "",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        }
    });

    /**
     * Submit new request with selected arguments
     */
    $('#openair-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ) {
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile generare i grafici", "info");
            return false;
        }

        runImagesScript();
    });

    /**
     * Cancel button.
     */
    $('#openair-cancel').on('click', function(e) {
        e.preventDefault();

        // clear form
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    //END FORM FUNCTIONS


    // the icon "x" and the close button can close the single job view
    $('.card-body').on('click', '.btn-close-view', function(e){
        e.preventDefault();

        // tab to be closed
        var close = $(this).data("close");
        console.log(close);

        // remove the single job tab and show the tab with the jobs list
        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#new"]').tab('show');
        }, 1);
    });

    // first load af all jobs of the current day
    loadScriptRuns();

    // FUNCTIONS

    /**
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields(){
        console.log('clearFields');
        // manage input type text
        $('.clear-input').val("");
        // manage select
        $('.clear-select').val(-1);
        // reset daterangepicker
        $('#openair-date').data('daterangepicker').setEndDate(moment().format("DD/MM/YYYY"));
        $('#openair-date').data('daterangepicker').setStartDate(moment().subtract(12, 'months').format("DD/MM/YYYY"));
        // manage select 2 elements
        $('#openair-stat-poll').val(-1).trigger('change');
        $('#openair-stat-wea').val(-1).trigger('change');

        // reset form validation
        $('#openair-form').validate().resetForm();
    }

    /**
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     * @param {text} dest Select to populate.
     * @param {integer} stid Station ID.
     *
     */
    function loadStations(prid, dest, stid){

        console.log('loadStations: '+prid);

        var jqxhr = $.ajax({
            url: '/str_openair_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {
            console.dir(result);

            // check if result is OK
            if(result.res == 'OK'){
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
                $('#'+dest).empty();
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);

                if(stid != null)
                    $('#'+dest).val(stid).trigger('change');
                else
                    $('#'+dest).val(-1).trigger('change');
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
     * Function that retrieves the stations of a given province.
     * No args needed
     */
    function loadScriptRuns(){

        // reset datatable
        if(table)
            table.clear();

        // get runs via ajax call
        var jqxhr = $.ajax({
            url: '/str_openair_get_runs',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            var runs = result.runs;
            console.dir(runs);

            // check if at least one element exists
            if( runs.length > 0 ){
                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each run, build a html row to be added to the datable
                $.each(runs, function(index, value) {
                    html +='<tr data-id="'+value.jq_id+'">';
                    html +='    <td class="bobo-nowrap icons-little">';
                    html +='        <a href="javascript:void(0)" class="show-charts" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                    html +='    </td>';
                    html +='    <td>'+value.start_d+' - '+value.end_d+'</td>';
                    html +='    <td>'+value.w_calm+'</td>';
                    html +='    <td>'+value.category_name+'</td>';
                    html +='    <td>'+value.station_pollutant+'</td>';
                    html +='    <td>'+value.station_weather+'</td>';
                    html +='    <td>'+value.l_limit+'</td>';
                    html +='    <td>'+value.u_limit+'</td>';
                    html +='    <td>'+value.scale_type_text+'</td>';
                    html +='    <td>'+value.scale_opt_formatted+'</td>';
                    html +='    <td></td>';
                    html +='</tr>';
                });

                // add rows to datatable by using html object
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
                table.draw();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle corse dello script", "error");
            table.draw();
        });

        return;
    }

    /**
     * Function that send the request to the server
     * No args needed
     */
    function runImagesScript(){

        console.log('Data inizio: '+dateFrom);
        console.log('Data fine: '+dateTo);

        // serialize the form
        var form = $('#openair-form').serializeArray();
        // push dates into serialized form object
        form.push({ name: "from", value: dateFrom });
        form.push({ name: "to", value: dateTo });

        var jqxhr = $.ajax({
            url: '/str_openair_put_images_creation',
            type: "post",
            dataType: "json",
            data: form
        })
        .done(function(result) {
            // check result
            // if 1 then show success message, start notifier process and refresh runs list
            // else if -1 then process with same arguments already exists, show info message
            if(result == 1){
                swal("Richiesta inoltrata", "Al termine del processo riceverai una notifica", "info");
                startNotifier();

                loadScriptRuns();
            }
            else if(result == -1){
                swal({
                    title: "Attenzione",
                    text: "Il processo è <strong>già in esecuzione con i parametri selezionati</strong>: attenderne la conclusione per rilanciarlo!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal('Errore', 'Errore durante la generazione delle immagini', 'error');
        });
    }

    /**
     * Function that retrieves run charts
     *
     * @param {integer} jobid job id
     */
    function loadCharts(jobid){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // get images via an ajax call
        var jqxhr = $.ajax({
            url: '/str_openair_get_images',
            type: "post",
            dataType: "json",
            data: {
                id: jobid
            }
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then create new tab
            // if WAIT then the process is not finished yet: show warning message
            // if EMPTY then the job is finished but it didn't generate any image: show warning message
            // else show error message
            if(result.res == 'OK'){

                // retrieve main variables from table row element
                var row = table.row($("tr[data-id='"+jobid+"']")).nodes().to$();
                var stationPName = row.find('td:nth-child(5)').text();
                var stationWName = row.find('td:nth-child(6)').text();
                var period = row.find('td:nth-child(2)').text();
                // get file list
                var files;
                files = result.img_files;

                // regular expressions in order to set the names of the groups of graphs
                var regxpWind = /wind/g;
                var regxpPollRose = /pollutionrose/g;
                var regxpPolarPlot = /polarplot/g;
                var regxpPolarAnnulus = /polarannulus/g;

                // control flag to avoid repeating the titles of the groups of graphs
                var flagWind = 0;
                var flagPollRose = 0;
                var flagPolarPlot = 0;
                var flagPolarAnnulus = 0;

                // built html tab label to add at the list
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#charts'+jobid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">Stazione '+stationPName+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger btn-close-view" data-close="charts'+jobid+'"></i></a></li>';
                $('.nav').append(html);

                // built html tab content to add at the group
                html  = '<div class="tab-pane p-20" id="charts'+jobid+'" role="tabpanel">';
                html += '    <h4 class="box-title">Stazione inquinante <strong>'+stationPName+'</strong> - stazione meteo <strong>'+stationWName+'</strong> - periodo: <strong>'+period+'</strong></h4>';
                html += '    <hr class="m-t-0 m-b-20">';

                // create 4 "div" containers
                htmlVento = '<h5 class="divider-title m-b-0">Vento</h5><div class="row el-element-overlay pollutant">';
                htmlPollRose = '<h5 class="divider-title m-b-0">Inquinanti - Pollution Rose</h5><div class="row el-element-overlay pollutant">';
                htmlPolarPlot = '<h5 class="divider-title m-b-0">Inquinanti - Polar Plot</h5><div class="row el-element-overlay pollutant">';
                htmlPolarAnnulus = '<h5 class="divider-title m-b-0">Inquinanti - Polar Annulus</h5><div class="row el-element-overlay pollutant">';

                // loop through all elements
                // for each file, build a html card to be added into the new tab
                $.each(files, function(idx, file){

                    if (regxpWind.test(file.name)) {
                        // 'Wind' group header
                        htmlVento += '        <div class="col-lg-3 col-md-6 no-spaces-element">';
                        htmlVento += '            <div class="card">';
                        htmlVento += '                <div class="el-card-item">';
                        htmlVento += '                    <div class="el-card-avatar el-overlay-1">';
                        htmlVento += '                        <img data-file="'+file.path+'" src="'+file.path+'" class="img-responsive" alt="'+file.name+'">';
                        htmlVento += '                        <div class="el-overlay">';
                        htmlVento += '                            <ul class="el-info">';
                        htmlVento += '                                <li><a class="btn default btn-outline image-popup-webcams" href="'+file.path+'"><i class="icon-magnifier"></i></a></li>';
                        htmlVento += '                            </ul>';
                        htmlVento += '                        </div>';
                        htmlVento += '                    </div>';
                        htmlVento += '                    <div class="el-card-content">';
                        htmlVento += '                        <h3 class="box-title">'+file.formatted_name+'</h3>';
                        htmlVento += '                    </div>';
                        htmlVento += '                </div>';
                        htmlVento += '            </div>';
                        htmlVento += '        </div>';

                    } else if (regxpPollRose.test(file.name)) {
                        // 'Pollution Rose' group header
                        htmlPollRose += '        <div class="col-lg-3 col-md-6 no-spaces-element">';
                        htmlPollRose += '            <div class="card">';
                        htmlPollRose += '                <div class="el-card-item">';
                        htmlPollRose += '                    <div class="el-card-avatar el-overlay-1">';
                        htmlPollRose += '                        <img data-file="'+file.path+'" src="'+file.path+'" class="img-responsive" alt="'+file.name+'">';
                        htmlPollRose += '                        <div class="el-overlay">';
                        htmlPollRose += '                            <ul class="el-info">';
                        htmlPollRose += '                                <li><a class="btn default btn-outline image-popup-webcams" href="'+file.path+'"><i class="icon-magnifier"></i></a></li>';
                        htmlPollRose += '                            </ul>';
                        htmlPollRose += '                        </div>';
                        htmlPollRose += '                    </div>';
                        htmlPollRose += '                    <div class="el-card-content">';
                        htmlPollRose += '                        <h3 class="box-title">'+file.formatted_name+'</h3>';
                        htmlPollRose += '                    </div>';
                        htmlPollRose += '                </div>';
                        htmlPollRose += '            </div>';
                        htmlPollRose += '        </div>';

                    } else if (regxpPolarPlot.test(file.name)) {
                        // 'Polar Plot' group header
                        htmlPolarPlot += '        <div class="col-lg-3 col-md-6 no-spaces-element">';
                        htmlPolarPlot += '            <div class="card">';
                        htmlPolarPlot += '                <div class="el-card-item">';
                        htmlPolarPlot += '                    <div class="el-card-avatar el-overlay-1">';
                        htmlPolarPlot += '                        <img data-file="'+file.path+'" src="'+file.path+'" class="img-responsive" alt="'+file.name+'">';
                        htmlPolarPlot += '                        <div class="el-overlay">';
                        htmlPolarPlot += '                            <ul class="el-info">';
                        htmlPolarPlot += '                                <li><a class="btn default btn-outline image-popup-webcams" href="'+file.path+'"><i class="icon-magnifier"></i></a></li>';
                        htmlPolarPlot += '                            </ul>';
                        htmlPolarPlot += '                        </div>';
                        htmlPolarPlot += '                    </div>';
                        htmlPolarPlot += '                    <div class="el-card-content">';
                        htmlPolarPlot += '                        <h3 class="box-title">'+file.formatted_name+'</h3>';
                        htmlPolarPlot += '                    </div>';
                        htmlPolarPlot += '                </div>';
                        htmlPolarPlot += '            </div>';
                        htmlPolarPlot += '        </div>';

                    } else if (regxpPolarAnnulus.test(file.name)) {
                        // 'Polar Annulus' group header
                        htmlPolarAnnulus += '        <div class="col-lg-3 col-md-6 no-spaces-element">';
                        htmlPolarAnnulus += '            <div class="card">';
                        htmlPolarAnnulus += '                <div class="el-card-item">';
                        htmlPolarAnnulus += '                    <div class="el-card-avatar el-overlay-1">';
                        htmlPolarAnnulus += '                        <img data-file="'+file.path+'" src="'+file.path+'" class="img-responsive" alt="'+file.name+'">';
                        htmlPolarAnnulus += '                        <div class="el-overlay">';
                        htmlPolarAnnulus += '                            <ul class="el-info">';
                        htmlPolarAnnulus += '                                <li><a class="btn default btn-outline image-popup-webcams" href="'+file.path+'"><i class="icon-magnifier"></i></a></li>';
                        htmlPolarAnnulus += '                            </ul>';
                        htmlPolarAnnulus += '                        </div>';
                        htmlPolarAnnulus += '                    </div>';
                        htmlPolarAnnulus += '                    <div class="el-card-content">';
                        htmlPolarAnnulus += '                        <h3 class="box-title">'+file.formatted_name+'</h3>';
                        htmlPolarAnnulus += '                    </div>';
                        htmlPolarAnnulus += '                </div>';
                        htmlPolarAnnulus += '            </div>';
                        htmlPolarAnnulus += '        </div>';
                    }
                });

                // close subs div
                htmlVento += '    </div>';
                htmlPollRose += '    </div>';
                htmlPolarPlot += '    </div>';
                htmlPolarAnnulus += '    </div>';

                // add cards of charts
                html += htmlVento;
                html += htmlPollRose;
                html += htmlPolarPlot;
                html += htmlPolarAnnulus;

                // close main div
                html += '    <hr class="m-t-30">';
                html += '    <div class="form-group row">';
                html += '        <div class="col-12">';
                html += '            <button type="button" class="btn btn-primary btn-close-view" data-close="charts'+jobid+'"> <i class="icon-close"></i> Chiudi elemento</button>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                // append created html to content tab
                $('.tab-content').append(html);

                // the containers for all galleries
                $('#charts'+jobid+' .pollutant').each(function() {
                    $(this).magnificPopup({
                        delegate: 'a.image-popup-webcams', // the selector for gallery item
                        type: 'image',
                        closeOnContentClick: true,
                        mainClass: 'mfp-img-mobile',
                        image: {
                            verticalFit: true
                        },
                        gallery: {
                          enabled: true
                        }
                    });
                });

                // show the new tab just added
                $('.customtab a[href="#charts'+jobid+'"]').tab('show');
            }
            else if (result.res == 'WAIT'){
                swal({
                    title: "Attenzione",
                    text: "Il processo è <strong>ancora in esecuzione</strong>: attenderne la conclusione per visualizzare le immagini!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });
            }
            else if (result.res == 'EMPTY'){
                swal({
                    title: "Attenzione",
                    text: "Il processo <strong>non ha generato immagini</strong>: provare a modificare i parametri di configurazione!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });
            }
            else{
                swal('Errore', 'Errore durante il recupero delle immagini', 'error');
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // show error message
            swal('Errore', 'Errore durante il recupero delle immagini', 'error');
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

});

