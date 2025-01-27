/**
 * Document ready
 */
$( document ).ready(function() {

    // GLOBAL VARIABLES
    var multiObj;
    var arrStat, arrPar;

    console.log('App mode: ' + app_mode);
    // if in production mode then disable all messages in the console
    if (app_mode == 'production'){
        console.log = function(){};
        console.dir = function(){};
    }

    // if the polling is active, when user changes page let's start again the polling
    if( storageGet('dataview-notifier') ){
        startNotifier(loadDownloads);
    }

    // set page title
    $('#bottom-double strong').html('Scarico dati');
    // hide preloader
    $("#dataview-preloader").hide();

    // LEFT COLUMN
    // /////////////////////////////////////////////////////////
{
    // variable for datepicker function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(1, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#dw-date').daterangepicker({
        // startDate: start,
        // endDate: end,
        autoUpdateInput: false,
        maxDate: end,
        minDate: moment('1970-01-01', 'YYYY-MM-DD').format('DD/MM/YYYY'),
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-primary',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimo 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimo 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
            'Anno scorso': [moment().subtract(1, 'year').startOf('year'), moment().subtract(1, 'year').endOf('year')]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end) {

        $('#dw-date').val(start.format("DD/MM/YYYY") +' - '+ end.format("DD/MM/YYYY"));
        //on change event, get active stations or parameters (based on the selected type) within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'));
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');
        // deselect all elements
        $( '.col-param .deselect-all, .col-stat .deselect-all' ).trigger( "click");

        if( $(".btn-down.sel").data("type") == 'station'){
            // load active stations in the selected period
            loadStationsByDates(dateFrom, dateTo);
            $(".col-stat").show();
        }
        else if($(".btn-down.sel").data("type") == 'parameter'){
            // load active parameters in the selected period
            loadParameterByDates(dateFrom, dateTo);
            $(".col-param").show();
        }

        if( $("#dw-temp").val() != -1){
            $("#select-data").show();
        }
    });

     // Multiselect plugin - http://loudev.com
    multiObj = $('.multiselect select').multiSelect({
        selectableHeader: "<input type='text' class='search-input' autocomplete='off' placeholder='Cerca...'><div class='custom-header'><a href='#' class='select-all'>Aggiungi tutti &raquo;</a></div>",
        selectionHeader: "<input type='text' class='search-input' autocomplete='off' placeholder='Cerca...'><div class='custom-header'><a href='#' class='deselect-all'>&laquo; Rimuovi tutti</a></div>",
        keepOrder: true,
        afterInit: function(ms){
            var that = this,
            $selectableSearch = that.$selectableUl.prev().prev(),
            $selectionSearch = that.$selectionUl.prev().prev(),
            selectableSearchString = '#'+that.$container.attr('id')+' .ms-elem-selectable:not(.ms-selected)',
            selectionSearchString = '#'+that.$container.attr('id')+' .ms-elem-selection.ms-selected';

            that.qs1 = $selectableSearch.quicksearch(selectableSearchString)
            .on('keydown', function(e){
                if (e.which === 40){
                    that.$selectableUl.focus();
                    return false;
                }
            });

            that.qs2 = $selectionSearch.quicksearch(selectionSearchString)
            .on('keydown', function(e){
                if (e.which == 40){
                    that.$selectionUl.focus();
                    return false;
                }
            });
        },
        afterSelect: function(values){
            this.qs1.cache();
            this.qs2.cache();
        },
        afterDeselect: function(values){
            this.qs1.cache();
            this.qs2.cache();
        }
    });

    // multiselect change event
    $('.multiselect select').change(function(e){
        console.log('change');

        // get multiselect type
        var type = $(this).parent().data('id');

        // get array and last item added
        var arrAll = $(this).val();
        var arrDiff;
        if (arrStat) {
            // diff between two array
            if (type == 'stat') {
                // stations
                arrDiff = $(arrAll).not(arrStat).get();
            } else {
                // parameters
                arrDiff = $(arrAll).not(arrPar).get();
            }
        }else{
            lastItem = arrAll[arrAll.length-1];
        }
        console.dir(arrAll);
        console.dir('lastItem: %s', lastItem);
        // get number of selected stations and parameters
        var nStat  = $( "#duallistbox_stat option:selected" ).length;
        var nParam = $( "#duallistbox_param option:selected" ).length;
        console.log("nStat: %s, nParam: %s", nStat, nParam);

        // force 1 in order to obtain in the next multiplication a result not equal to 0
        if(nStat == 0)
            nStat = 1;
        if(nParam == 0)
            nParam = 1;
        // check not greater then 50
        if(nStat * nParam > 50){
            swal("Attenzione", "Numero massimo di files (n.stazioni x n.parametri) scaricabili è pari a 50", "warning");
            // remove last added items
            $.each(arrDiff, function(index, station){
                $('#duallistbox_'+type).multiSelect('deselect', station);
            });
            return;
        }

        // store array
        if (type == 'stat') {
            arrStat = arrAll;
        } else {
            arrPar = arrAll;
        }

    });

    // click on select-all button
    $('#new-plugin').on( "click", ".select-all", function() {
        // get type of multiselect
        var type = $(this).parent().parent().parent().parent().data('id');

        // check number of options
        // must be equal or LOWER than 50
        if ($( '#duallistbox_'+type+' option' ).length > 50){
            swal("Attenzione", "Numero massimo di files (n.stazioni x n.parametri) scaricabili è pari a 50", "warning");
            return false;
        }

        $('#duallistbox_'+type).multiSelect( 'select_all' );
        $('#duallistbox_'+type).multiSelect( 'refresh' );
        $('#duallistbox_'+type).trigger("change");
        return;
    });


    $("#select-data, .col-param, .col-stat, #processed-data, #download-time, #download-form-right, #dw-submit").hide();

    // click event on buttons in order to select the type of search
    $(".btn-down").click(function(e) {
        e.preventDefault();

        // reset views and form
        $("#select-data, .col-param, .col-stat, #processed-data").hide();
        $('#duallistbox_param option, #duallistbox_stat option').attr('selected', false);
        $('#duallistbox_param').multiSelect( 'refresh' );
        $('#duallistbox_stat').multiSelect( 'refresh' );
        $("#list-param, #list-stat").empty();
        $('#download-form-left #dw-temp').val(-1);

        // reset daterangepicker
        $('#dw-date').data('daterangepicker').setEndDate(moment());
        $('#dw-date').data('daterangepicker').setStartDate(moment());
        $('#dw-date').val("");

        // get new selected type
        $(".btn-down").removeClass("sel");
        $(this).addClass("sel");
        var type = $(this).data("type");

        // change views based on selected type
        switch(type) {
            case "station":
                $("#download-form-left").addClass('col-sm-8');
                $("#download-form-left").removeClass('col-sm-12');
                $("#select-data .col-stat").removeClass("order-2").addClass("order-1");
                $("#select-data .col-param").removeClass("order-1").addClass("order-2");
                $("#download-time").show('slow');
                $("#download-form-right").show('slow');
                $("#dw-submit").show();
                $(".to-disable").prop('disabled', false);
                break;
            case "parameter":
                $("#download-form-left").addClass('col-sm-8');
                $("#download-form-left").removeClass('col-sm-12');
                $("#select-data .col-param").removeClass("order-2").addClass("order-1");
                $("#select-data .col-stat").removeClass("order-1").addClass("order-2");
                $("#download-time").show('slow');
                $("#download-form-right").show('slow');
                $("#dw-submit").show();
                $(".to-disable").prop('disabled', false);
                break;
            default:
                break;
        }
    });

    // if removeall stations and "station" is the starting point of procedure then resetall and hide the parameters
    $( '.col-stat' ).on( "click", ".deselect-all", function(e) {
        console.log('click removeall stations');
        // reset views and form
        $('#list-stat').empty();
        $('#list-stat').siblings("h4").children("span").text("");
        $('#duallistbox_stat').multiSelect('deselect_all');
        $('#duallistbox_stat').multiSelect('refresh' );

        if($('.btn-down.sel').data("type") == 'station'){
            $('#list-param').empty();
            $('#duallistbox_param').multiSelect('deselect_all');
            $('#duallistbox_param').multiSelect('refresh');
            $('.col-param').hide();
        }
        e.preventDefault();
    });

    // if removeall parameters and "parameter" is the starting point of procedure then resetall and hide the stations
    $( '.col-param' ).on( "click", ".deselect-all", function(e) {
        console.log('click removeall params');
        // reset views and form
        $('#list-param').empty();
        $('#list-param').siblings("h4").children("span").text("");
        $('#duallistbox_param').multiSelect('deselect_all');
        $('#duallistbox_param').multiSelect('refresh');

        if($('.btn-down.sel').data("type") == 'parameter'){
            $('#list-stat').empty();
            $('#duallistbox_stat').multiSelect('deselect_all');
            $('#duallistbox_stat').multiSelect('refresh' );
            $('.col-stat').hide();
        }
        e.preventDefault();
    });

    // change event triggered by parameters multiselect
    // if "parameter" is the selected starting point then update list of the stations
    $( "#select-data" ).on( "change", "#duallistbox_param", function(e) {
        e.preventDefault();

        console.log("change #duallistbox_param");
        // empty the container for the list of selected parameters
        $("#list-param").empty();

        $(".col-stat").show();
        // fill it again with new selected parameters
        $( "#duallistbox_param option:selected" ).each(function() {
            $("#list-param").append("<li>"+$( this ).text()+"</li>");
        });

        $("#list-param").siblings("h4").children("span").text("["+$( "#duallistbox_param option:selected" ).length+"]");
        // load all stations which acquire all selected parameters
        if($('.btn-down.sel').data("type") == 'parameter'){
            $('#duallistbox_stat').multiSelect( 'refresh' );
            var params = $( "#duallistbox_param").val();
            refreshStations(params);
        }
    });

    // change event triggered by stations multiselect
    // if "station" is the selected starting point then update list of the parameters
    $( "#select-data" ).on( "change", "#duallistbox_stat", function(e) {
        e.preventDefault();

        console.log("change #duallistbox_stat");
        // empty the container for the list of selected stations
        $("#list-stat").empty();

        $(".col-param").show();
        // fill it again with new selected stations
        $( "#duallistbox_stat option:selected" ).each(function() {
            $("#list-stat").append("<li><a class='st-pr-detail' href='#station-info' data-toggle='modal' data-stid='"+$( this ).val()+"'>"+$( this ).text()+" <i class='mdi mdi-information'></i></a></li>")
        });

        $("#list-stat").siblings("h4").children("span").text("["+$( "#duallistbox_stat option:selected" ).length+"]");
        // load all parameters acquired by all the selected stations
        if($('.btn-down.sel').data("type") == 'station'){
            $('#duallistbox_param').multiSelect( 'refresh' );
            var stations = $( "#duallistbox_stat").val();
            refreshParameters(stations);
        }
    });

    // click on station li element in the list-stat
    $( "#download-form-left" ).on( "click", ".st-pr-detail", function(e){

        e.preventDefault();

        var stid = $(this).data('stid');
        var stname = $(this).text();
        console.log(stname);
        // retrieve information about all parameters acquired by the clicked station
        getStationInfoById(stname, stid);
    });

    // select "Passo temporale" change event
    $("#download-form-left").on("change", "#dw-temp", function(e){
        e.preventDefault();
        // refresh parameters or stations list based on the type of starting point
        if($('.btn-down.sel').data("type") == 'station'){
            var stations = $( "#duallistbox_stat").val();
            refreshParameters(stations);
        }
        else if($(".btn-down.sel").data("type") == 'parameter'){
            $( '.col-param .deselect-all, .col-stat .deselect-all' ).trigger( "click");
            loadParameterByDates(dateFrom, dateTo);
            $(".col-param").show();
        }
        // show multiselects container if previous fields are not empty
        if($('#dw-date').val() != "" && $(this).val() != -1){
            $("#select-data").show();
        }

    });
}
    // RIGHT COLUMN
    // /////////////////////////////////////////////////////////
{
     // validate form
    $('#download-form').validate({ // initialize the plugin
        rules: {
            "duallistbox_param[]" : {
                required: true
            },
            "duallistbox_stat[]" : {
                required: true
            },
        },
        messages: {
            "duallistbox_param[]" : {
                required: "aggiungere parametro"
            },
            "duallistbox_stat[]" : {
                required: "aggiungere stazione"
            },
        },
        ignore: "",
    });

    // submit event
    $( "#data-download" ).on( "click", "#dw-submit", function(e) {
        e.preventDefault();

        var btn = $( "#choise-start .sel" ).length;
        if(btn == 0){
            swal("Attenzione!", "selezionare il tipo di dati da cui si vuol partire (stazioni o parametri).", "error");
        }else{
            var dwl = $( "#download-form" ).valid();
            if (dwl){
                // immediately download data
                downloadDataFile();
            }else{
                swal("Attenzione!", "Per poter scaricare i dati devi completare correttamente tutti i campi!", "warning");
            };
        };
    });
}

    // check if user uuid already exists otherwise create it
    if( ! storageGet('user-uuid') ){
        storageStore('user-uuid', crypto.randomUUID() );
    }

    loadDownloads();

    // START FUNCTIONS
    // /////////////////////////////////////////////////////////
    /**
     * Function that clears left form
     * No args needed
     */
    function clearLeftForm(){
        console.log('clearRightForm');

        $('#select-data, .col-param, .col-stat, #processed-data').hide();
        $('.btn-down').removeClass("sel");

        $('#download-form-left #dw-temp').val(-1);
        // reset validate plugin
        $('#download-form-left').validate().resetForm();
    }

    /**
     * Function that clears right form
     * No args needed
     */
    function clearRightForm(){

        console.log('clearRightForm');
        $('#download-form-right input[type=text], #download-form-right input[type=email]').val("");
        // reset validate plugin
        $('#download-form-right').validate().resetForm();
    }

    /**
     * Function that refresh the lists with user's downloads
     * No args needed
     */
    function loadDownloads(){
        // get uuid from localstorage and check validity
        var uuid = storageGet('user-uuid');
        // if not valid then stop loop and reset localstorage variable
        if(!uuid || uuid == ''){
            return false;
        }

        // ajax call in order to retrieve all downloads (finished and pending)
        var jqxhr = $.ajax({
            url: '/str_dataview_get_downloads',
            type: "post",
            dataType: "json",
            data:{
                uuid: uuid
            }
        })
        .done(function(result) {
            console.dir(result);
            // clear container
            $('.downloads-container').empty();

            var html = '';
            // check ajax result
            // if not null and array length greater than 0 then create a list with all requests of the current day
            // else show a default message
            if(result.downloads != null && result.downloads.length > 0){

                html += '<ul class="list-user-download">';
                // for each request create a <li> element with all info selected by the user
                var downloads = result.downloads;
                downloads.forEach(function(el, idx){
                    html += '    <li>';
                    html += '        <p><strong>Intervallo date:</strong> '+el.start_date+' - '+el.end_date+'</p>';
                    html += '        <p><strong>Passo temporale:</strong> '+el.aggregation+'</p>';
                    html += '        <p><strong>Stazioni:</strong> '+el.stations+'</p>';
                    html += '        <p><strong>Parametri:</strong> '+el.parameters+'</p>';
                    if(el.download_link){
                        html += '        <p><a href="'+el.download_link+'" class="btn btn-sm btn-primary"><i class="ti-download"></i> Scarica zip</a></p>';
                    }
                    else{
                        html += '        <p><a href="javascript:void(0)" class="btn btn-sm btn-primary btn-disabled"><i class="ti-loop"></i> Elaborazione in corso...</a></p>';
                    }

                    html += '    </li>';
                });

                html += '</ul>';
            }
            else{
                html += '<p class="download-none">Al momento non hai effettuato nessuno scarico dati oppure i tuoi pacchetti non sono ancora pronti.</p>';
            }

            // append html
            $('.downloads-container').append(html);

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei download", "error");
        });
    }

    /**
     * Function that retrieves the list of all active public stations within a certain daterange
     * No args needed
     */
    function loadStationsByDates(){

        // ajax call
        var jqxhr = $.ajax({
            url: 'str_dataview_get_stations',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                params: []
            },
        })
        .done(function(result) {
            if(result.res == 'OK'){
                var stations = result.stations;
                // create options html
                var opts = '';
                $.each(stations, function(index, station){
                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });

                // show total number of retrieved stations
                $("#select-data").find("label[for='duallistbox_stat[]']").children("strong").text(stations.length);
                // fill stations multiselect
                $('#duallistbox_stat').empty();
                $('#duallistbox_stat').append(opts);
                $('#duallistbox_stat').multiSelect( 'refresh' );
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

        return;
    }

    /**
     * Function that retrieves the list of all active public stations within a certain daterange
     * AND that acquire selected parameters
     *
     * @param {array} params: array of selected parameters
     */
    function refreshStations(params){

        console.log('refreshStations');
        console.log('ajax');
        var jqxhr = $.ajax({
            url: 'str_dataview_get_stations',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                params: JSON.stringify(params)
            },
        })
        .done(function(result) {
            console.dir(result);

            // check ajax result
            // if 'OK' then fill the multiselect with stations and refresh it
            if(result.res == 'OK'){
                var stations = result.stations;
                // remove all stations previously selected by the user
                $('#duallistbox_stat option').removeAttr('selected');
                $("#list-stat").empty();
                $("#list-stat").siblings("h4").children("span").text("[0]");
                // create options html
                var opts = '';
                $.each(stations, function(index, station){
                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });

                // show total number of retrieved stations
                $("#select-data").find("label[for='duallistbox_stat[]']").children("strong").text(stations.length);
                // fill stations multiselect
                $('#duallistbox_stat').empty();
                $('#duallistbox_stat').append(opts);
                $('#duallistbox_stat').multiSelect( 'refresh' );
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

        return;
    }

    /**
     * Function that retrieves the list of all active public parameters within a certain daterange
     * No args needed
     */
    function loadParameterByDates(){
        // get selected aggregation
        var aggregation = $("#dw-temp").val();
        // retrieve parameters via an ajax call
        var jqxhr = $.ajax({
            url: 'str_dataview_get_params',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                aggr: aggregation,
                stations: []
            },
        })
        .done(function(result) {
            // check ajax result
            // if 'OK' then fill the multiselect with parameters and refresh it
            if(result.res == 'OK'){
                var parameters = result.params;
                // create options html
                var opts = '';
                $.each(parameters, function(index, parameter){
                    opts += '<option value="'+ parameter.parameter_id+'">'+parameter.parameter_name+'</option>';
                });

                // show total number of retrieved parameters
                $("#select-data").find("label[for='duallistbox_param[]']").children("strong").text(parameters.length);
                // fill parameters multiselect
                $('#duallistbox_param').empty();
                $('#duallistbox_param').append(opts);
                $('#duallistbox_param').multiSelect( 'refresh' );
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");

        });

        return;
    }

    /**
     * Function that retrieves the list of all active public parameters within a certain daterange
     * AND that are acquired by selected stations

     * @param {array} stations: array of selected stations
     */
    function refreshParameters(stations){

        // get selected aggregation
        var aggr = $("#dw-temp").val();

        // retrieve parameters via an ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_params',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                aggr: aggr,
                stations: JSON.stringify(stations)
            },
        })
        .done(function(result) {
            // check ajax result
            // if 'OK' then fill the multiselect with parameters and refresh it
            if(result.res == 'OK'){
                var parameters = result.params;
                // remove all parameters previously selected by the user
                $('#duallistbox_param option').removeAttr('selected');
                $("#list-param").empty();
                $("#list-param").siblings("h4").children("span").text("[0]");
                // create options html
                var opts = '';
                $.each(parameters, function(index, parameter){
                    opts += '<option value="'+ parameter.parameter_id+'">'+parameter.parameter_name+'</option>';
                });

                // show total number of retrieved parameters
                $("#select-data").find("label[for='duallistbox_param[]']").children("strong").text(parameters.length);
                // fill parameters multiselect
                $('#duallistbox_param').empty();
                $('#duallistbox_param').append(opts);
                $('#duallistbox_param').multiSelect( 'refresh' );
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");

        });

        return;
    }

    /**
     * Function that retrieves information about parameters acquired by a specific station

     * @param {string} stname : name of the station
     * @param {integer}  stid : id of the station
     */
    function getStationInfoById(stname, stid){

        console.log('getStationInfoById');
        console.log('ajax');
        var jqxhr = $.ajax({
            url: 'str_dataview_get_station_params',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {
            // check ajax result
            // if 'OK' then create the html with station parameters info
            if(result.res == 'OK'){
                // empty table body
                $("#station-info-table tbody").html('');
                // fill title
                $("#station-info strong").text(stname);

                var html= '';
                var params = result.params;
                // create a tr element for each parameter
                $.each(params, function(index, param){
                    html += '<tr>';
                    html += '    <td>'+param.parameter_name+'</td>';
                    html += '    <td>'+param.station_param_startup_date+'</td>';
                    html += '    <td>'+param.station_param_dismiss_date+'</td>';
                    html += '</tr>';
                });
                // add rows to the table
                $("#station-info-table tbody").append(html);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio della stazione", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della stazione", "error");
        });

        return;
    }

    /**
     * Function that sends a data download request with specific arguments
     * No args needed
     */
    function downloadDataFile(){
        console.log('downloadDataFile');
        $("#dataview-preloader").show();

        // add dateFrom and dateTo to serialized form
        var form = $('#download-form').serializeArray();
        form.push({ name: "from", value: dateFrom });
        form.push({ name: "to"  , value: dateTo });

        form.push({ name: "ck-data-licenses"    , value: false });
        form.push({ name: "ck-data-system"      , value: false });
        form.push({ name: "ck-privacy-legacy"   , value: false });
        form.push({ name: "ck-major-age"        , value: false });

        // retrieve uuid from storage and check validity
        var uuid = storageGet('user-uuid');
        if(!uuid || uuid == '')
            storageStore('user-uuid', crypto.randomUUID() );

        // add uuid for notifier
        form.push({ name: "uuid", value: storageGet('user-uuid') });
        // ajax call
        var jqxhr = $.ajax({
            url: 'str_dataview_get_data',
            type: "post",
            dataType: "json",
            data: form
        })
        .done(function(result) {
            // check result
            // if 1 then show success message and start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result == 1){
                swal({
                    title: "Richiesta inviata correttamente!",
                    text: "La tua richiesta è stata inviata correttamente. <br><strong>Riceverai una notifica</strong> quando il tuo zip è <strong>pronto per essere scaricato</strong>. <br><strong>Trovi i tuoi download</strong> nella colonna qui a fianco (oppure in basso se hai uno schermo di piccole dimensioni).",
                    type: "info",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok, ho capito",
                    closeOnConfirm: true
                });
                loadDownloads();
                startNotifier(loadDownloads);

            }
            else if(result == -1)
                swal({
                    title: "Attenzione",
                    text: "La richiesta di dati con i parametri selezionati è <strong>già in elaborazione</strong>: attenderne la conclusione per scaricare di dati!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });

            $("#dataview-preloader").hide();
        })
        .fail(function(xhr, err) {
            // show error message
            swal("Errore!", "Ops! Qualcosa è andato storto. Riprovare ad eseguire il download più tardi.", "error");
            $("#dataview-preloader").hide();
        });
    }

    // END FUNCTIONS
    // /////////////////////////////////////////////////////////
});
