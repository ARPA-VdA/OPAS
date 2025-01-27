// VALIDATION VARIABLES
var validationOptions;

var dateFrom;
var dateTo;

// disabble auto call highlightjs
hljs.initHighlighting.called = false;

/**
 * Document ready.
 */
$(document).ready(function() {
    // closure date from db - setted by the portal admin
    if(closureDate)
        $('.blocked-right strong').text(closureDate);

    // hide buttons
    $("#deselect-cells").hide();
    $("#undo-edit").hide();
    $(".clipboard-hide").hide();

    // !!MENU >> STRUMENTI
{
    /**
     * Change event - fields for the exported image of the chart
     */
    $("#exp-chart-title-font, #exp-chart-label-font, #exp-chart-legend-font").on("change", function() {
        // check values
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 15 ? 15 : val && val < 5 ? 5 : val;
    });

    /**
     * Change event - fields for the fonts of the chart
     */
    $("#chart-title-font, #chart-label-font, #chart-legend-font").on("change", function() {
        // check values
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 30 ? 30 : val && val < 5 ? 5 : val;
    });

    /**
     * Change event - fields for the labels of the chart
     */
    $("#label-x-axis").on("change", function() {
        // check values
        var val = Math.abs(parseInt(this.value, 10) || 0);
        this.value = val > 90 ? 90 : val;
    });

    // IMPOSTAZIONI
    /**
     * Change event - show jstree per station or per parameter
     */
    $("#data-per-param").on("change", function(e){
        e.preventDefault();
        // if user selects a "parameter" view then disable station options
        if($("#data-per-param").is(":checked")){

            $("#visible-stid").prop("checked", false);
            $("#visible-altitude").prop("checked", false);
        }
    });

    /**
     * Click event - reset options
     */
    $("#reset-settings").on("click", function(e){
        e.preventDefault();
         // IMPOSTAZIONI DI DEFAULT
        swal({
            title: "Resetta le impostazioni",
            text: "Sei sicuro di voler resettare le impostazioni a quelle di default?",
            type: "warning",
            showCancelButton: true,
            confirmButtonClass: "btn-danger",
            confirmButtonText: "Si, conferma",
            cancelButtonText: "Annulla",
            closeOnConfirm: true
        },
        function(){
            // set default options
            validationOptions = {
                general: {
                    perParam: false,
                    converted: true,
                    stidEnabled: false,
                    altitudeEnabled: true,
                    limitsValueEnabled: true
                },
                tabulator: {
                    filtersEnabled: false,
                },
                highstocks: {
                    // layout grafico online
                    navigatorEnabled: false,
                    numberYaxis: 1,
                    titleFontSize: 16,
                    labelFontSize: 11,
                    legendFontSize: 10,
                    // layout immagine esportata
                    expTitleFontSize: 7,
                    expLabelFontSize: 5,
                    expLegendFontSize: 5
                },
                filter: {
                   altitude: 0
                }
            };
            // fill options form with retrieved metadata
            setOptions();
        });
    });

    /**
     * Click event - apply button
     */
    $("#apply-settings").on("click", function(e){
        e.preventDefault();
        // apply form options to the global variable
        applyOptions();
        swal("Successo!", "Nuove impostazioni applicate con successo. Saranno visibili alla creazione di nuovi/e grafici/tabelle", "success");
    });

    /**
     * Click event - save button
     */
    $("#save-settings").on("click", function(e){
        e.preventDefault();
        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // apply form options to the global variable
        applyOptions();
        // save options in the db
        saveOptions();
    });

    /**
     * Click event - load all nodes button
     */
    $('#all-tree').click(function(e){
        e.preventDefault();
        // show confirm message
        swal({
            title: "Albero Stazioni",
            text: "Sei sicuro di voler caricare l'albero completo delle stazioni?",
            showCancelButton: true,
            closeOnConfirm: true,
            confirmButtonText: "Si, carica!",
            cancelButtonText: "Annulla",
        }, function () {
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // trigger load all event
            $('#station-json').jstree().open_all();

        });
    });
}
    // END MENU >> STRUMENTI

    // !!SECOND MENU
{
    // CLICK EVENTS
    // prevent the dropdown of the start date selection from closing after the click
    $('#start-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // prevent the end date selection dropdown from closing after the click
    $('#end-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // DATES INPUT
    // START Click events initializations for dates sub-menu
    // ///////////////////////////////////////////////////////
    $("#start-date-today").on('click', function(e){
        e.preventDefault();

        console.log("start-date-today");
        dateFrom = moment().utc().format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates( $("#date-start").val(), $("#date-end").val(), 'date-start');
    });

    $("#start-date-yest").on('click', function(e){
        e.preventDefault();

        console.log("start-date-yest");
        dateFrom = moment().utc().add(-1, 'days').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-start');
    });

    $("#start-date-tda").on('click', function(e){
        e.preventDefault();

        console.log("start-date-tda");
        dateFrom = moment().utc().add(-3, 'days').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-start');
    });

    $("#start-date-fdm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdm");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-fdy").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdy");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-curr-fdy").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdy");
        dateFrom = moment().format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-start');
    });

    $("#start-date-curr-fdm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdm");
        dateFrom = moment().format('01/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-start');
    });

    $("#start-date-pd").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pa");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-pm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pm");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-pa").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pa");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-nd").on('click', function(e){
        e.preventDefault();

        console.log("start-date-nd");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-nm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-nm");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#start-date-na").on('click', function(e){
        e.preventDefault();

        console.log("start-date-na");
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    $("#end-date-today").on('click', function(e){
        e.preventDefault();

        console.log("end-date-today");
        dateTo = moment().utc().format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-end');
    });

    $("#end-date-copy").on('click', function(e){
        e.preventDefault();

        console.log("end-date-copy");
        dateTo = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('DD/MM/YYYY 23:59');;
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");
    });

    $("#end-date-ldy").on('click', function(e){
        e.preventDefault();

        console.log("end-date-ldy");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').format('31/12/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-end');
    });

    $("#end-date-ldm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-ldm");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').endOf('month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), $("#date-end").val(), 'date-end');
    });

    $("#end-date-pd").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pa");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    $("#end-date-pm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pm");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    $("#end-date-pa").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pa");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    $("#end-date-nd").on('click', function(e){
        e.preventDefault();

        console.log("end-date-nd");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    $("#end-date-nm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-nm");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    $("#end-date-na").on('click', function(e){
        e.preventDefault();

        console.log("end-date-na");
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        $('#station-json').jstree(true).refresh_node("9999");

        validDates($("#date-start").val(), dateTo, 'date-end');
    });
    // ///////////////////////////////////////////////////////
    // END Click events initializations for dates sub-menu

    /**
     * Change event: aggregation select
     */
    $("#time-period").on("change", function(e){
        e.preventDefault();
        activeMacro.macro.aggregation = $(this).val();
    });

    // LOAD DATA WITH SELECTED OPTIONS
    $("#update-data").on("click",function(e){
        e.preventDefault();

        dateFrom = $("#date-start").val();
        dateTo = $("#date-end").val();

        // check if dates are valid - global.js
        if( !validDates($("#date-start").val(), $("#date-end").val(), 'date-start') )
        {
            console.log('Non valido');
            swal('Attenzione!', 'Date inserite non valide', 'warning');
            return;
        }

        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;


        // NOT USED - $("#deselect-cells").trigger('click');
        // reset selected cells and variable with modified cells
        selectedCells = [];
        modifiedCells = [];

        rightClickCell = null;

        // disable clipboard
        clipboardEnabled = false;

        // change button classes and text based on clipboard status
        $("#val-clipboard").removeClass('btn-danger');
        $("#val-clipboard").addClass('btn-secondary');
        $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: OFF');

        // remove class on maintable container
        $("#maintable-container").removeClass('clipboard-enabled');
        // hide clipboard copy-save-canc-info buttons
        $('.clipboard-hide').hide();

        // if is a multiview tab then force to switch to main tab
        if(componentState.type != 'table'){
            centralContainer.setActiveContentItem(centralContainer.contentItems[0]);
            componentState = centralContainer.getActiveContentItem().container.getState();
        }

        componentState.conv = validationOptions.general.convEnabled;

        // get station_id and param_id stored in tab component
        var station_id = componentState.stid;
        var param_id = componentState.prid;

        if (station_id != null){
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // load station data - validazione.js
            loadStationData(station_id);
        }
        else if(param_id != null){
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // load parameter data - validazione.js
            loadParameterData(param_id, componentState.grid);
        }
        else{
            return;
        }
    });

    // SET FINAL VALIDATION CODE
    $("#validate-daily").on("click", function(e){
        e.preventDefault();

        // set code equal to 1
        var code = 1;
        // get from -to dates
        var from = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');
        var to = moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 23:59');

        // get all displayed columns
        var columns = maintable.getColumns();
        var cellsArray = [];
        var checkGrant = 0;
        // loop through all columns
        // for each of them create an object to be sent to server and push it to a global array
        columns.forEach(function(column, index) {
            if(index != 0){
                var definition = column.getDefinition().editorParams;
                var cellElement = {
                    stprid : definition.id,
                    tableid : definition.tableid,
                    table: definition.table,
                    grant: definition.updateGrant,
                    final_code: code
                };
                // variable to control user grants
                checkGrant = checkGrant || definition.updateGrant;
                cellsArray.push(cellElement);
            }
        });

        // check user's grants
        // if false then show warning message and return from event
        if(!checkGrant){
            swal('Azione non consentita', 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione sulla stazione selezionata!', 'warning');
            return false;
        }

        // show confirm message
        var text = "Si stanno per modificare <strong><b>TUTTI</b></strong> i parametri visualizzati compresi tra il <strong><b>"+dateFrom+" 00:00</b></strong> e il <strong><b>"+dateTo+" 23:59</b></strong>. Proseguire nell'operazione?"
        swal({
            title: "Attenzione",
            text: text,
            html: true,
            type: "warning",
            showCancelButton: true,
            closeOnConfirm: true,
            confirmButtonText: "Si, prosegui!",
            cancelButtonText: "Annulla",
        }, function (isConfirm) {
            if (isConfirm){
                // trigger click in order to deselect all cells
                $("#deselect-cells").trigger('click');
                // save validated data - validazione.js
                checkCells(from, to, cellsArray);
            }
            else{
                return false;
            }
        });
    });

    //////// VALIDAZIONE: MODAL CALENDARIO - start ////////

    // variable for calendar modal
    var dateToCal = moment().utc().format('YYYY-MM-DD HH:00');
    var dateFromCal = moment(dateToCal).add('-1','days').format('YYYY-MM-DD 00:00');

    // variable for datepicker plugin (different format)
    var startCal = moment(dateFromCal).format("DD/MM/YYYY HH:mm");
    var endCal = moment(dateToCal).format("DD/MM/YYYY HH:mm");
    var endMaxCal = moment(dateToCal).add('1', 'day').format("DD/MM/YYYY HH:mm");

    // Daterange picker
    $('.input-daterange-datepicker').daterangepicker({
        startDate: startCal,
        endDate: endCal,
        maxDate: endMaxCal,
        minDate: closureDate ? closureDate : '01/01/1970 00:00',
        timePicker: true,
        timePicker24Hour: true,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        locale: dateRangePickerSettings.locale
    }, function(startCal, endCal, label) {
        //on change event, get reports within new daterange
        console.log(startCal.format('YYYY-MM-DD HH:mm'), endCal.format('YYYY-MM-DD HH:mm'), label);
        dateFromCal = startCal.format('YYYY-MM-DD HH:mm');
        dateToCal = endCal.format('YYYY-MM-DD HH:mm');
    });

    // the stations have multiple select
    $.fn.select2.defaults.set("width", null);
    $("#val-cal-stat").select2({
        dropdownParent: $("#validation-by-calendar"),
        matcher: searchGroupedSelect2
    });

    // hide div container in the modal
    $(".filtering-group, .filtering-code-group, .editing-group, .validation-group").hide();

    /**
     * Change event - province filter
     */
    $( "#val-cal-prov" ).on( "change", function() {
        var prid = $(this).val();
        // load stations linked to selected province
        loadStations(prid);
    });

    // select option -1 and load all stations
    $("#val-cal-prov").trigger("change");

    /**
     * Change event - station filter
     */
    $( "#val-cal-stat" ).on( "change", function() {
        var stid = $(this).val();
        // ajax call in order to load parameters linked to selected station
        var jqxhr = $.ajax({
            url: '/dat_val_get_parameters',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {
            // check result
            // - if OK then fill parameter select
            // - else  show error message
            if(result.res == 'OK'){
                $('#val-cal-param').empty();
                var params = result.params;
                // variable for build dynamic html
                var opts = '';
                // loop through all parameters
                // for each element build an html option
                $.each(params, function(index, param){

                    opts += '<option value="'+ param.stpr_id+'">'+param.parameter_name+'</option>';
                });
                $('#val-cal-param').append('<option value="-1">Seleziona parametro...</option>');
                $('#val-cal-param').append(opts);
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
    });

    /**
     * Click event on any button in modal
     */
    $("#val-cal-form").on('click', '#filtering button, #filtering-code button, #calendar-operations button', function(e){
        e.preventDefault();

        $(this).parent().children().removeClass('sel');
        $(this).addClass('sel');
    });

    /**
     * Click event on radio buttons "Modifica" - "Validazione"
     */
    $('#val-cal-form input[type="radio"]').click(function(){
        // show / hide different div containers based on checked radio
        if($("#editing-btn").is(":checked")) {
            $(".editing-group").show();
            $(".validation-group").hide();
        }
        else if($("#validation-btn").is(":checked")){
            $(".validation-group").show();
            $(".editing-group").hide();
        }
        // enable filters buttons
        $('#val-cal-save').prop('disabled', false);
        $('#filtering-btn').prop('disabled', false);
        $('#filtering-code-btn').prop('disabled', false);
    });

    /**
     * Click event on "Filtra per valore"
     */
    $('#val-cal-form #filtering-btn').click(function(){
        if($(this).is(":checked")){
            $(".filtering-group").show();
        }else{
            $(".filtering-group").hide();
        }
    });

    /**
     * Click event on "Filtra per codice"
     */
    $('#val-cal-form #filtering-code-btn').click(function(){
        if($(this).is(":checked")){
            $(".filtering-code-group").show();
        }else{
            $(".filtering-code-group").hide();
        }
    });

    // validate form
    $('#val-cal-form').validate({ // initialize the plugin
        rules: {
            "val-cal-date" : {
                required: true
            },
            "val-cal-param":{
                required: true,
                min: 0
            },
            "val-cal-filter" : {
                dotSeparator: true,
                required: function(){
                    return $('#filtering-btn').is(':checked');
                }
            },
            "code-cal-filter" : {
                required: function(){
                    return $('#filtering-code-btn').is(':checked');
                }
            },
            "val-cal-cod" : {
                required: function(){
                    return $('#validation-btn').is(':checked');
                }
            },
            "val-cal-oper" : {
                dotSeparator: true,
                required: function(){
                    return $('#editing-btn').is(':checked');
                }
            }
        },
        messages: {
            "val-cal-date" : {
                required: "Inserire periodo temporale"
            },
            "val-cal-filter" : {
                required: "Inserire valore per cui filtrare"
            },
            "code-cal-filter" : {
                required: "Selezionare codice"
            },
            "val-cal-param":{
                required: "Selezionare parametro",
                min: "Selezionare parametro"
            },
            "val-cal-cod" : {
                required: "Selezionare codice di validazione",
                min: "Selezionare codice di validazione"
            },
            "val-cal-oper" : {
                required: "Inserire valore da applicare all'operazione"
            }
        },
        ignore: "",
        errorPlacement: function ( error, element ) {
            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * Submit event
     */
    $('#val-cal-form').on('submit', function (e) {
        e.preventDefault();

        var start = moment(dateFromCal).format('DD/MM/YYYY HH:mm');
        var end = moment(dateToCal).format('DD/MM/YYYY HH:mm');

        // check if form is valid
        if (! $('#val-cal-form').valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti o errati. Sistemare prima di validare.", "info");
            return false;
        }
        else{

            // get names of selected station and parameter
            var stat = $( "#val-cal-stat option:selected" ).text();
            var par = $( "#val-cal-param option:selected" ).text();
            // flag that determines the action: true = validation, false = mathematical operation
            var actionValidation = $('#validation-btn').is(':checked');
            var filter;
            var filterCode;
            var operation;

            // check if a filter by value has been selected
            if( $('#filtering-btn').is(':checked') ){
                // retrieve operation and value
                // if not null build the string for the filter
                var operator =  $("#filtering button.sel").text();
                var value = parseFloat($("#val-cal-filter").val());

                if(operator == null || operator == ""){
                    swal("Info", "Selezionare un'operazione da applicare al filtro", "info");
                    return false;
                }
                filter = operator+' '+value;
            }
            else{
                filter = '';
            }

            // check if a filter by code has been selected
            if( $('#filtering-code-btn').is(':checked') ){
                // retrieve operator and code
                // if not null build the string for the filter
                var operator =  $("#filtering-code button.sel").text();
                var value = parseInt($("#code-cal-filter").val());

                if(operator == null || operator == ""){
                    swal("Info", "Selezionare un'operazione da applicare al filtro del codice", "info");
                    return false;
                }

                filterCode = operator+' '+value;
            }
            else{
                filterCode = '';
            }

            // if it's a mathematical operation
            // then build the string for the operation
            if( ! actionValidation){
                var operator =  $("#calendar-operations button.sel").text();
                var value = parseFloat($("#val-cal-oper").val());

                if(operator == null || operator == ""){
                    swal("Info", "Selezionare un'operazione da applicare ai dati", "info");
                    return false;
                }
                else if(operator == '/' && value == 0){
                    swal("Info", "Operazione non permessa!", "info");
                    return false;
                }

                operation = operator+' '+value;
            }

            // show confirm message
            var text = "Si stanno per modificare <strong><b>TUTTI</b></strong> i dati del parametro <strong>"+par+"</strong> nella stazione <strong>"+stat+"</strong> compresi tra il <strong><b>"+start+"</b></strong> e il <strong><b>"+end+"</b></strong>. Proseguire nell'operazione?"
            swal({
                title: "Operazione in corso",
                text: text,
                type: "warning",
                html: true,
                showCancelButton: true,
                confirmButtonText: "Si, procedi",
                closeOnConfirm: false,
                cancelButtonText: "Annulla"
            }, function () {
                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // update cells
                var jqxhr = $.ajax({
                    url: '/dat_val_put_action_by_calendar',
                    type: "post",
                    dataType: "json",
                    data: {
                        from: dateFromCal,
                        to: dateToCal,
                        stprid: $('#val-cal-param').val(),
                        action_val: actionValidation,
                        filter: filter,
                        filter_code: filterCode,
                        operation: operation,
                        code: $('#val-cal-cod').val()
                    }
                })
                .done(function(result) {
                    // check result
                    // - if 1 then success and refresh layout
                    // else error message
                    if(result == 1){
                        // success message
                        swal("Parametro modificato", "Il parametro è stato modificato con successo!", "success");

                        // refresh jstree
                        $('#station-json').jstree(true).refresh_node("9999");
                        // refresh data
                        $("#update-data").trigger("click");
                    }
                    else{
                        // error message
                        swal("Errore!", "Errore durante la validazione", "error");
                    }
                    // at the end of the process hide preloader
                    $('.preloader').hide();
                })
                .fail(function(xhr, err) {
                    // error message
                    swal("Errore!", "Errore durante la validazione", "error");
                    // at the end of the process hide preloader
                    $('.preloader').hide();
                });
            });
        };
    });

    /**
     * Click event: cancel button
     */
    $('#val-cal-reset').on('click', function(e){
        e.preventDefault();

        $('#val-cal-form select').val(-1);
        $('#val-cal-form #val-cal-cod, #val-cal-form #val-cal-oper,  #val-cal-form #val-cal-filter, #val-cal-form #code-cal-filter').val('');
        $('#val-cal-stat').trigger('change');

        $('#val-cal-save').prop('disabled', true);
        $('#filtering-btn').prop('disabled', true);
        $('#filtering-btn').prop('checked', false);
        $('#filtering-code-btn').prop('disabled', true);
        $('#filtering-code-btn').prop('checked', false);
        $('#editing-btn').prop('checked', false);
        $('#validation-btn').prop('checked', false);

        // hide div containers
        $(".filtering-group").hide();
        $(".filtering-code-group").hide();
        $(".validation-group").hide();
        $(".editing-group").hide();

        $('#filtering button, #filtering-code button, #calendar-operations button').removeClass('sel');

        // reset validation plugin
        $('#val-cal-form').validate().resetForm();
    });

    /**
     * hide modal event: reset form
     */
    $('#validation-by-calendar').on('hidden.bs.modal', function (e) {
        e.preventDefault();

        $('#val-cal-form select').val(-1);
        $('#val-cal-form #val-cal-cod, #val-cal-form #val-cal-oper,  #val-cal-form #val-cal-filter, #val-cal-form #code-cal-filter').val('');
        $('#val-cal-stat').trigger('change');

        $('#val-cal-save').prop('disabled', true);
        $('#filtering-btn').prop('disabled', true);
        $('#filtering-btn').prop('checked', false);
        $('#filtering-code-btn').prop('disabled', true);
        $('#filtering-code-btn').prop('checked', false);
        $('#editing-btn').prop('checked', false);
        $('#validation-btn').prop('checked', false);

        // hide div containers
        $(".filtering-group").hide();
        $(".filtering-code-group").hide();
        $(".validation-group").hide();
        $(".editing-group").hide();

        $('#filtering button, #filtering-code button, #calendar-operations button').removeClass('sel');

        // reset validation plugin
        $('#val-cal-form').validate().resetForm();
    });

    //////// VALIDAZIONE: MODAL CALENDARIO - end ////////

    //////// CLIPBOARD - start ////////
    // button for enable/disable "clipboard" option
    $("#val-clipboard").on('click', function(e){
        e.preventDefault();

        // reset selected cells and variable with modified cells
        $("#deselect-cells").trigger('click');

        // enable / disable clipboard
        clipboardEnabled = ! clipboardEnabled;

        // change button classes and text based on clipboard status
        $("#val-clipboard").toggleClass('btn-secondary btn-danger');
        if(clipboardEnabled)
            $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: ON');
        else
            $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: OFF');

        // toggle class on maintable container
        $("#maintable-container").toggleClass('clipboard-enabled');
        // show / hide copy-save-canc-info buttons
        $('.clipboard-hide').toggle();
    });

    // button allways visibile
    $("#val-clipboard-copy").on('click', function(e){
        e.preventDefault();

        // if table is initialized then copy active rows
        // "active" - Rows currently in the table (rows that pass current filters etc)
        if(maintable)
            maintable.copyToClipboard("active");
    });

    // button visibile only with "clipboard" option enabled
    $("#val-clipboard-save").on('click', function(e){
        e.preventDefault();

        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // save into db changes applied by the clipboard system
        updateCells(modifiedCells, true);
    });

    // button visibile only with "clipboard" option enabled
    $("#val-clipboard-canc").on('click', function(e){
        e.preventDefault();

        // for each selected cell, restore initial value and remove classes
        // selectedCells.forEach(function(cell, idx){

        //     console.log('restore value');
        //     cell.restoreInitialValue();

        //     console.log('classlist remove');
        //     cell.getElement().classList.remove('cell-modified');
        //     setClasses(cell);
        // });

        // // reset selected cells and variable with modified cells
        // $("#deselect-cells").trigger('click');
        // modifiedCells = [];

        // ACK for by-passing initialValue bug of Tabulator
        $('#update-data').trigger('click');


    });
    //////// CLIPBOARD - end ////////

    /**
     * Click button: reset current tab
     */
    $("#reset-active-tab").on('click', function(e){
        e.preventDefault();

        // get current tab
        var activeContentItem = centralContainer.header.activeContentItem;
        // reset tab
        resetTab(activeContentItem);
    });

    /**
     * Click button: reset all tabs
     */
    $("#reset-all-tabs").on('click', function(e){
        e.preventDefault();
        // reset all tabs
        resetAllTabs();
    });

    /**
     * Click button: deselect cells button
     */
    $("#deselect-cells").on('click', function(e){
        e.preventDefault();

        // loop through selected cells
        // for each cell remove class "selected"
        for(var i = 0; i< selectedCells.length; i++){
            selectedCells[i].getElement().classList.remove('cell-selected');
            // set classes based on the validity of the value - validazione.js
            setClasses(selectedCells[i]);
        }
        // reset global array
        selectedCells = [];
        // hide button
        $("#deselect-cells").hide();

        // reset left-bottom box
        $("#codes-detail").empty();
        $("#changes-detail").empty();
    });

    /**
     * Click button: undo button
     */
    $("#undo-edit").on('click', function(e){
        e.preventDefault();
        // reset selected cells
        $("#deselect-cells").trigger('click');
        // undo last action
        maintable.undo();

        // check number of stored actions
        // if equal to 0 then hide button
        if(maintable.getHistoryUndoSize() == 0)
            $("#undo-edit").hide();
    });

} // END SECOND MENU

    // load app options
    loadOptions();
    // load all rules
    // loadAutoInvalidation(-1);

    // LOCAL FUNCTIONS
    /////////////////////////////////////////////////////////////////////////
    /**
    * Function for retrieving user settings from database
    * No args needed
    */
    function loadOptions(){

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_val_get_validation_user_options',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);

            var options = result.options;
            // check if options are not defined
            // if true then set global variable with default options
            // else set user options
            if( options == null){
                // DEFAULT SETTINGS
                validationOptions = {
                    general: {
                        perParam: false,
                        convEnabled: true,
                        stidEnabled: false,
                        altitudeEnabled: true
                    },
                    tabulator: {
                        filtersEnabled: false,
                    },
                    highstocks: {
                        // layout grafico online
                        navigatorEnabled: false,
                        numberYaxis: 1,
                        labelXangle: 0,
                        titleFontSize: 16,
                        labelFontSize: 11,
                        legendFontSize: 10,
                        // layout immagine esportata
                        expTitleFontSize: 10,
                        expLabelFontSize: 6,
                        expLegendFontSize: 5
                    },
                    filter: {
                       altitude: 0
                    }
                };

            }
            else{
                // SETTINGS FROM DB WITH CHECK FOR THE PRESENCE OF FIELDS OTHERWISE SET DEFAULT
                validationOptions = {
                    general: {
                        perParam: options.general.perParam == null ? false : options.general.perParam,
                        convEnabled: options.general.convEnabled == null ? true : options.general.convEnabled,
                        stidEnabled:  options.general.stidEnabled == null ? false : options.general.stidEnabled,
                        altitudeEnabled: options.general.altitudeEnabled == null ? true : options.general.altitudeEnabled,
                    },
                    tabulator: {
                        filtersEnabled: options.tabulator == null || options.tabulator.filtersEnabled == null ? false : options.tabulator.filtersEnabled
                    },
                    highstocks: {
                        // layout grafico online
                        navigatorEnabled: options.highstocks.navigatorEnabled == null ? false : options.highstocks.navigatorEnabled,
                        numberYaxis: options.highstocks.numberYaxis == null ? 1 : options.highstocks.numberYaxis,
                        labelXangle: options.highstocks.labelXangle == null ? 0 : options.highstocks.labelXangle,
                        titleFontSize: options.highstocks.titleFontSize == null ? 16 : options.highstocks.titleFontSize,
                        labelFontSize: options.highstocks.labelFontSize == null ? 11 : options.highstocks.labelFontSize,
                        legendFontSize: options.highstocks.legendFontSize == null ? 10 : options.highstocks.legendFontSize,
                        // layout immagine esportata
                        expTitleFontSize: options.highstocks.expTitleFontSize == null ? 10 : options.highstocks.expTitleFontSize,
                        expLabelFontSize: options.highstocks.expLabelFontSize == null ? 6 : options.highstocks.expLabelFontSize,
                        expLegendFontSize: options.highstocks.expLegendFontSize == null ? 5 : options.highstocks.expLegendFontSize
                    },
                    filter: {
                       altitude: options.filter.altitude == null ? 0 : options.filter.altitude
                    }
                };
            }

            // fill options form with retrieved metadata
            setOptions();

            // check variables from server (passed by url)
            if(id != null && id != '' && dateStart != null && dateStart != ''){
                // case of /station_id/date_start/date_end
                // load data between date_start and date_end for selected station
                if(dateEnd != null && dateEnd != ''){
                    // convert dates from milliseconds to human format
                    // set dates mask
                    dateFrom = moment.utc(parseInt(dateStart)).format('DD/MM/YYYY 00:00');
                    $("#date-start").inputmask("setvalue", dateFrom);

                    dateTo = moment.utc(parseInt(dateEnd)).format('DD/MM/YYYY 23:59');
                    $("#date-end").inputmask("setvalue", dateTo);

                    // show preloader, waiting for the end of the process
                    $('.preloader').show();

                    // set active tab variables
                    var activeTabElement = centralContainer.getActiveContentItem();
                    var componentState = activeTabElement.container.getState();
                    componentState.stid = id;
                    componentState.prid = null;
                    componentState.grid = null;
                    componentState.conv = validationOptions.general.convEnabled;

                    // load station data - validazione.js
                    loadStationData(id);
                }
                // case of /st_pr_id/date_start
                // load data +24 and -24 hours around date_start for station-param-id
                else{
                    // convert date from milliseconds to human format
                    var date = moment.utc(parseInt(dateStart)).format('YYYY-MM-DD HH:mm:00');
                    // retrieve data for the selected stprid and add new tab
                    addMultiView(id, date);
                }
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");
        });
        return;
    }

    /**
    * Function that populates settings form mask
    */
    function setOptions(){
        // general
        $("#data-per-param").prop("checked", validationOptions.general.perParam);
        $("#data-converted").prop("checked", validationOptions.general.convEnabled);
        $("#visible-stid").prop("checked", validationOptions.general.stidEnabled);
        $("#visible-altitude").prop("checked", validationOptions.general.altitudeEnabled);

        // charts
        $("#chart-nav").prop("checked", validationOptions.highstocks.navigatorEnabled);
        $("#chart-number-y-axis").val(validationOptions.highstocks.numberYaxis);
        $("#chart-label-x-angle").val(validationOptions.highstocks.labelXangle);
        $("#chart-title-font").val(validationOptions.highstocks.titleFontSize);
        $("#chart-label-font").val(validationOptions.highstocks.labelFontSize);
        $("#chart-legend-font").val(validationOptions.highstocks.legendFontSize);
        // exported image
        $("#exp-chart-title-font").val(validationOptions.highstocks.expTitleFontSize);
        $("#exp-chart-label-font").val(validationOptions.highstocks.expLabelFontSize);
        $("#exp-chart-legend-font").val(validationOptions.highstocks.expLegendFontSize);

        // tables
        $("#table-filters").attr("checked", validationOptions.tabulator.filtersEnabled);
    }

    /**
    * Function that applies form options to the global variable
    */
    function applyOptions(){
        // global variables
        validationOptions = {
            general: {
                perParam: $("#data-per-param").is(":checked"),
                convEnabled: $("#data-converted").is(":checked"),
                stidEnabled: $("#visible-stid").is(":checked"),
                altitudeEnabled: $("#visible-altitude").is(":checked"),
            },
            tabulator: {
                filtersEnabled: $("#table-filters").is(":checked"),
            },
            highstocks: {
                navigatorEnabled: $("#chart-nav").is(":checked"),
                numberYaxis: parseInt($("#chart-number-y-axis").val()),
                labelXangle: parseInt($("#chart-label-x-angle").val()),
                titleFontSize: parseInt($("#chart-title-font").val()),
                labelFontSize: parseInt($("#chart-label-font").val()),
                legendFontSize: parseInt($("#chart-legend-font").val()),
                // layout immagine esportata
                expTitleFontSize: parseInt($("#exp-chart-title-font").val()),
                expLabelFontSize: parseInt($("#exp-chart-label-font").val()),
                expLegendFontSize: parseInt($("#exp-chart-legend-font").val())
            },
            filter: {
                altitudeFilter: 0
            }
        };

        // refresh left tree
        $('#station-json').jstree(true).refresh();
        // refresh central container
        $("#update-data").trigger('click');

        return;
    }

    /**
    * Function for saving user options
    */
    function saveOptions(){
        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_val_put_validation_user_options',
            type: "post",
            dataType: "json",
            data: {
                options: JSON.stringify(validationOptions)
            }
        })
        .done(function(result) {
            // check result
            // if true then show success message otherwise show error message
            if(result){
                swal("Successo!", "Le impostazioni sono state salvate con successo", "success");
            }
            else{
                swal("Errore!", "Errore durante il salvataggio delle impostazioni", "error");
            }
            // at the end of the process hide preloader
            $('.preloader').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");
            // at the end of the process hide preloader
            $('.preloader').hide();
        });
    }

     /**
     * Function that retrieves the stations of a given parameter.
     *
     * @param {integer} prid Parameter ID.
     */
    function loadStations(prid){
        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_val_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {
            // check result
            //  - if res is 'OK' then success, build stations options
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                // empty select
                $('#val-cal-stat').empty();
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
                $('#val-cal-stat').append('<option value="-1">Seleziona stazione...</option>');
                $('#val-cal-stat').append(opts);

                $('#val-cal-stat').val(-1).trigger('change');
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
     * Function that resets the active tab with destruction of objects (table or graph)
     *
     * @param {object} contentItem object of active tab.
     */
    function resetTab(contentItem){

        // check tab type
        // if table then the active tab is the main one
        // otherwise it's a multiview tab
        var componentState = contentItem.config.componentState;
        if(componentState.type == 'table'){
            // reset tab variables
            componentState.stid = null;
            componentState.prid = null;
            componentState.grid = null;
            // set default title
            contentItem.setTitle('TABELLA');
            console.log('Destroy main table');
            // destroy the main table
            maintable.destroy();
            maintable.clearData();
            maintable = null;

            // reset global variables
            $("#deselect-cells").trigger('click');
            modifiedCells = [];
            rightClickCell = null;
            // disable clipboard
            clipboardEnabled = false;

            // change button classes and text based on clipboard status
            $("#val-clipboard").removeClass('btn-danger');
            $("#val-clipboard").addClass('btn-secondary');
            $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: OFF');

            // remove class on maintable container
            $("#maintable-container").removeClass('clipboard-enabled');
            // hide copy-save-canc-info buttons
            $('.clipboard-hide').hide();
        }
        else{
            // destroy tab's chart and table
            chart[componentState.id].destroy();
            chart[componentState.id] = null;

            table[componentState.id].destroy();
            table[componentState.id].clearData();
            table[componentState.id] = null;
            // remove multiview tab
            centralContainer.removeChild( contentItem );
        }
        return;
    }

    /**
     * Function that resets all tabs
     * No args needed
     */
    function resetAllTabs(){
        // get the array of tabs
        var tabs = centralContainer.header.tabs;
        var index = tabs.length-1;
        // loop through all tabs
        // for each tab call resetTab function
        for(; index >= 0; index--) {
            console.log(index);
            var tab = tabs[index];

            resetTab(tab.contentItem);
        };
        // reset global variables
        counter = 0;
        chart = [];
        table = [];

        return;
    }
    /////////////////////////////////////////////////////////////////////////
    // END LOCAL FUNCTIONS
});

// GLOBAL FUNCTIONS
/////////////////////////////////////////////////////////////////////////
/**
 * Function that retrieves the validation codes and fill right column
 * No args needed
 */
function loadValidityCodes(){
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_get_validation_codes',
        type: "post",
        dataType: "json"
    })
    .done(function(result) {
        var codes = result.codes;
        // check that at least one code exists
        if( codes != null && codes.length > 0 ){

            // variables for dynamically build html elements
            var html = '<p><button type="button" class="btn btn-sm btn-secondary" id="reset-code"><i class="ti-loop"></i> Reset codici</button> <button type="button" class="btn btn-sm btn-danger btn-circle" data-toggle-second="tooltip" data-placement="top" data-original-title="Visualizza elenco dei codici" data-target="#validation-codes" data-toggle="modal"><i class="mdi mdi-help"></i></button></p><ul>';
            var htmlInvalid = '';
            var sel = '';
            // loop through all elements
            // for each code build a li and a option elements
            $.each(codes, function(index, code) {

                // populate the right column of the program
                var myClass = 'code-default';
                var toolTitle;
                if( code.uvc_code_id == 0 ){
                    myClass += ' code-disabled';
                    toolTitle = 'Codice disabilitato';
                }
                else if(code.uvc_code_id == -1 ){
                    myClass = 'code-auto';
                    toolTitle = 'Codice sospetto';
                }
                else if (code.uvc_code_id == -2){
                    myClass = 'code-auto-invalid';
                    toolTitle = 'Codice automatico da prevalidazione';
                }
                else if(code.uvc_code_id > 0){
                    myClass = 'code-valid';
                    toolTitle = 'Codice valido';
                }
                else if(code.uvc_code_id < -2){
                    myClass = 'code-invalid';
                    toolTitle = 'Codice non valido';

                    htmlInvalid = '<option value="'+code.uvc_code_id+'">[ '+code.uvc_code_id+' ] '+code.uvc_code_desc+'</option>' + htmlInvalid;
                }
                html += '   <li><a class="val-code '+myClass+'" href="#" data-code="'+code.uvc_code_id+'" data-toggle="tooltip" data-placement="top" title="'+toolTitle+'"><span></span>[ '+code.uvc_code_id+' ] '+code.uvc_code_desc+'</a></li>';

                // populate the validation's code select inside the calendar form
                sel += '<option value="'+code.uvc_code_id+'">[ '+code.uvc_code_id+' ] '+code.uvc_code_desc+'</option>';
            });

            html += '</ul>';

            // append new html in the right column of the application
            $('#codes-list').append(html);
            $('#invalid-code').append(htmlInvalid);
            $('[data-toggle="tooltip"]').tooltip();
            $('[data-toggle-second="tooltip"]').tooltip();

            // select inside the calendar form
            $('#val-cal-cod').append(sel);
            $('#code-cal-filter').append(sel);
        }
        else{
            // error message
            swal("Errore!", "Errore durante il recupero dei codici di validazione", "error");
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei codici di validazione", "error");
    });
}

/**
 * Function used for the initialization of all validation elements
 * Called when golden-layout initialization is completed (analyser_layout.js)
 * No args needed
 */
function initialiseElements(){

    // tooltip initialization
    $('[data-toggle="tooltip"]').tooltip();
    $('[data-toggle-second="tooltip"]').tooltip();

    // retrieve validation codes
    loadValidityCodes();

    // ON TAB CHANGED, UPDATE ACTIVE MACRO AND INFO DETAIL
    /**
     * activeContentItemChanged event - goldenlayout
     */
    centralContainer.on( 'activeContentItemChanged', function( activeContentItem ){
        console.log('Tab changed: load tab macro');

        // reset left-bottom box
        $("#codes-detail").empty();
        $("#changes-detail").empty();
        // reset selectedCells variable
        $("#deselect-cells").trigger('click');

        // get component state object of the new active element
        var componentState = activeContentItem.config.componentState;
        // check if the user is returning in the first tab from a multiview tab
        // if true then scroll tabulator view to the clicked cell
        if(componentState.id == 0 && rightClickCell != null){
            setTimeout(function(){
                if(maintable){
                    console.log('scroll');
                    maintable.scrollToRow(rightClickCell.getRow(), 'center', false)
                        .then(function(){
                            maintable.scrollToColumn(rightClickCell.getColumn(), 'center', false);
                        })
                        .catch(function(error){
                            //handle error scrolling to row
                            // do nothing
                        });
                }
            }, 15);
        }
    });

    // input date start and date end initializations
    $("#date-start").inputmask({
        alias: "datetime",
        mask: "99/99/9999",
        insertMode: false,
        "oncomplete": function(){
            console.log('complete');
            dateFrom = $("#date-start").val();
        }
    }).on('keyup', function(){
        // check if dates are valid - global.js
        if( validDates($("#date-start").val(), $("#date-end").val(), 'date-start'))
            $('#station-json').jstree(true).refresh_node("9999");
    });

    dateFrom = moment().utc().add('-1','days').format('DD/MM/YYYY 00:00');
    $("#date-start").inputmask("setvalue", dateFrom);

    $("#date-end").inputmask( {
        alias: "datetime",
        mask: "99/99/9999",
        insertMode: false,
        oncomplete: function(){
            dateTo = $("#date-end").val();
        }
    }).on('keyup', function(){
        // check if dates are valid - global.js
        if( validDates($("#date-start").val(), $("#date-end").val(), 'date-end') )
            $('#station-json').jstree(true).refresh_node("9999");
    });

    dateTo = moment().utc().add('-1','days').format('DD/MM/YYYY 23:59');
    $("#date-end").inputmask("setvalue", dateTo);

    // jstree initialization - left tree
    $('#station-json').jstree({
        'core' : {
            // 'check_callback': true,
            'data' : {
                url: function (node) {

                    var url = "";
                    console.log('NODE.id: '+ node.id);


                    if (node.id === '#')
                    {
                        url = "/dat_val_get_validation_groups";
                    }
                    else
                    {
                        // different load routes based on the type of the node
                        switch (node.li_attr.type) {
                            case 'group':
                                if(validationOptions.general.perParam)
                                    url = "/dat_val_get_group_params";
                                else
                                    url = "/dat_val_get_group_stations";
                                break;
                            case 'suspect':
                                url = "/dat_val_get_group_suspects";
                                break;
                            case 'suspect_station':
                                url = "/dat_val_get_group_suspect_params";
                                break;
                            default:
                                break;
                        }
                    }

                    console.log(url);
                    return url;
                },
                // 'type': "get",
                'contentType': "application/json",
                'dataType': 'JSON',
                data: function (node) {
                    // send via ajax different data based on node's type
                    if( node.id === "#"){
                        return;
                    }
                    else if( node.li_attr.type === 'suspect' || node.li_attr.type === 'suspect_station'){
                        var from = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');
                        var to = moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 23:59');
                        return {"nodeid": node.id, "id": node.li_attr.id, "from": from, "to": to};
                    }
                    else{
                        return {"nodeid": node.id, "id": node.li_attr.id, "options": JSON.stringify(validationOptions)};
                    }

                }
            }
        },
        'plugins' : ["search"],
        'search' : {
            // ajax
            show_only_matches: true,
            show_only_matches_children: true
        }
    });

    // SEARCH PLUGIN FOR JSTREE
    var to = false;
    // keyup event on input search
    $('#input-search').keyup(function () {
        if(to) { clearTimeout(to); }
        to = setTimeout(function () {
            var v = $('#input-search').val();
            $('#station-json').jstree(true).search(v);
        }, 250);
    });

    /**
     * "open_all.jstree" event - triggered after the tree is fully loaded
     */
    $('#station-json').on("open_all.jstree", function(e, data){
        // close all nodes
        $('#station-json').jstree().close_all();
        // at the end of the process hide preloader
        $('.preloader').hide();
        // success message
        swal("Successo!", "Albero caricato con successo", "success");
    });

    /**
     * "search.jstree" event - return filtered nodes
     */
    $('#station-json').on("search.jstree", function(e, data){
        filtered_obj = data.nodes;
    });

    /**
     * "changed.jstree" event - triggered by a click on a node
     */
    $('#station-json').on("changed.jstree", function (e, data) {
        var event;

        // reset left-bottom box
        $("#codes-detail").empty();
        $("#changes-detail").empty();

        if(data.event)
            event = data.event.originalEvent;

        // get selected dates
        dateFrom = $("#date-start").val();
        dateTo = $("#date-end").val();

        // if node is not empty then load data
        if(data.node) {
            // reset righClickcell global variable
            rightClickCell = null;
            // get clicked node
            var node = data.node;
            // check event type (click) and node type
            // different behaviors based on node type (station - parameter)
            if((node.li_attr.type == 'station' || node.li_attr.type == 'suspect_station' ) && event && event.which == 1){
                console.log('station');
                // check if dates are valid - global.js
                if( ! validDates($("#date-start").val(), $("#date-end").val(), 'date-start') ){
                    console.log('Non valido');
                    swal('Attenzione!', 'Date inserite non valide', 'warning');
                    return;
                }

                // retrieve station_id
                var st_id = node.li_attr.id;
                // get active tab
                var activeTabElement = centralContainer.getActiveContentItem();
                var componentState = activeTabElement.container.getState();
                // if is a multiview tab then force to switch to main tab
                if(componentState.type != 'table'){
                    centralContainer.setActiveContentItem(centralContainer.contentItems[0]);
                    componentState = centralContainer.getActiveContentItem().container.getState();
                }

                // reset tab variables
                componentState.stid = st_id;
                componentState.prid = null;
                componentState.grid = null;

                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // NOT USED - $("#deselect-cells").trigger('click');
                // reset selected cells and variable with modified cells
                selectedCells = [];
                modifiedCells = [];

                rightClickCell = null;

                // disable clipboard
                clipboardEnabled = false;

                // change button classes and text based on clipboard status
                $("#val-clipboard").removeClass('btn-danger');
                $("#val-clipboard").addClass('btn-secondary');
                $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: OFF');

                // remove class on maintable container
                $("#maintable-container").removeClass('clipboard-enabled');
                // hide clipboard's copy-save-canc-info buttons
                $('.clipboard-hide').hide();

                // set tab title equal to node text
                // var title = node.text;
                // var titleFormatted = title.replace(/\s?\{\d+\}?/g, '');
                // var titleFormatted = titleFormatted.replace(/\s?\[.+\]?/g, '');

                // centralContainer.getActiveContentItem().setTitle(titleFormatted.trim().toUpperCase());
                // set conv variable
                componentState.conv = validationOptions.general.convEnabled;
                // load station data - validazione.js
                loadStationData(st_id);
            }
            else if(node.li_attr.type == 'param' && event && event.which == 1){
                console.log('param');
                // check if dates are valid - global.js
                if( ! validDates($("#date-start").val(), $("#date-end").val(), 'date-start') ){
                    console.log('Non valido');
                    swal('Attenzione!', 'Date inserite non valide', 'warning');
                    return;
                }

                // retrieve param_id
                var pr_id = node.li_attr.id;
                var gr_id = parseInt(node.parent);
                // get active tab
                var activeTabElement = centralContainer.getActiveContentItem();
                var componentState = activeTabElement.container.getState();
                // if is a multiview tab then force to switch to main tab
                if(componentState.type != 'table'){
                    centralContainer.setActiveContentItem(centralContainer.contentItems[0]);
                    componentState = centralContainer.getActiveContentItem().container.getState();
                }

                // reset tab variables
                componentState.stid = null;
                componentState.prid = pr_id;
                componentState.grid = gr_id;

                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // NOT USED - $("#deselect-cells").trigger('click');
                // reset selected cells and variable with modified cells
                selectedCells = [];
                modifiedCells = [];

                rightClickCell = null;

                // disable clipboard
                clipboardEnabled = false;

                // change button classes and text based on clipboard status
                $("#val-clipboard").removeClass('btn-danger');
                $("#val-clipboard").addClass('btn-secondary');
                $("#val-clipboard").html('<i class="icon-note"></i> Mod. avanzata: OFF');

                // remove class on maintable container
                $("#maintable-container").removeClass('clipboard-enabled');
                // hide clipboard copy-save-canc-info buttons
                $('.clipboard-hide').hide();

                // !! title arriva da DB
                // var title = node.text;
                // centralContainer.getActiveContentItem().setTitle(title);
                componentState.conv = validationOptions.general.convEnabled;
                // load parameter data - validazione.js
                loadParameterData(pr_id, gr_id);
            }
            else if(node.li_attr.type == 'station_param' && event && event.which == 1){
                console.log('station_param');
                // get station parameter id stpr_id
                var stprid = node.li_attr.id;
                var date = node.li_attr.date;
                date = moment(date).format('YYYY-MM-DD HH:mm:00');

                // add multiview tab - validazione_layout.js
                addMultiView(stprid, date);
            }
            else if(node.li_attr.type == 'link' && event && event.which == 1){
                // Visualizer panel case
                // convert from and to dates in seconds
                var from = moment(dateFrom, 'DD/MM/YYYY').valueOf()/1000;
                var to = moment(dateTo, 'DD/MM/YYYY').add(23, 'hours').valueOf()/1000;
                // add converted dates in final URL
                var url = node.li_attr.url+'/'+from+'/'+to;
                // open new browser's tab
                window.open(url, '_blank');
            }
        }
    });

    // EVENTs INITIALIZATION: called after goldenlayout init

    /**
     * Click event on "reset" button, right column
     */
    $("#validation-main").on("click", "#reset-code", function(e){
        e.preventDefault();

        var cellArray = [];
        var checkGrant;
        // loop through all selected cells
        // for each element build an object to be sent to the server
        selectedCells.forEach(function(cell) {

            var definition = cell.getColumn().getDefinition().editorParams;
            var cellElement = {
                table: definition.table,
                tableid : definition.tableid,
                stprid: definition.id,
                grant: definition.updateGrant,
                date : cell.getRow().getCells()[0].getValue()
            };
            // variable to control user grants
            checkGrant = checkGrant || definition.updateGrant;
            cellArray.push(cellElement);
        });

        // check user's grants
        // if false then show warning message and return from event
        if(!checkGrant){
            swal('Azione non consentita', 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione sulla stazione selezionata!', 'warning');
            return false;
        }

        // show confirm message
        swal({
            title: "Reset codici",
            text: "Sei sicuro di voler proseguire con il reset dei codici di validazione?",
            type: "warning",
            showCancelButton: true,
            closeOnConfirm: true,
            confirmButtonText: "Si, resetta!",
            cancelButtonText: "Annulla",
        }, function (isConfirm) {
            if (isConfirm){
                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // reset cells - validazione.js
                resetCellsCode(cellArray);
            }
            else{
                return false;
            }
        });
    });

    /**
     * Click event on any code button, list in the right column
     */
    $("#validation-main").on("click", ".val-code", function(e){
        e.preventDefault();

        // if clipboard is enabled then disable all other events (return from event)
        if(clipboardEnabled == true)
            return;

        // get clicked code and if it's not equal to 0
        // then check user's grants
        valcode = parseInt($(this).data("code"));
        //do nothing
        if(valcode == 0 )
            return false;
        else if ( !update_grant || (station_grants != null && !station_grants.station_update)) {
            swal('Azione non consentita', 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione sulla stazione selezionata!', 'warning');
            return false;
        }

        var cellArray = [];
        var checkGrant = 0;

        // check if selectedCells is empty
        // if true data may be blocked due to the settings set by the portal admin
        if(!selectedCells || selectedCells.length == 0){
            swal({
                title: 'Attenzione',
                text: '<strong>Nessuna cella selezionata</strong> a cui applicare il codice di validazione oppure <strong>dati bloccati</strong>',
                type: 'info',
                html: true
            });
            return false;
        }
        else if(selectedCells.length == 1){

            var cellDate = selectedCells[0].getRow().getCells()[0].getValue();
            // check if value date is before closure date (portal options)
                // - if true then select do nothing
                // - else continue
            if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                swal({
                    title: 'Attenzione',
                    text: 'Il dato selezionato è <strong>bloccato</strong>. Impossibile applicare il codice di validazione',
                    type: 'info',
                    html: true
                });
                return false;
            }
        }

        // loop through all selected cells
        // for each element build an object to be sent to the server
        selectedCells.forEach(function(cell) {
            // ajax stprid-data update post-validity-code
            var definition = cell.getColumn().getDefinition().editorParams;
            var cellElement = {
                table: definition.table,
                tableid : definition.tableid,
                stprid: definition.id,
                grant: definition.updateGrant,
                date : cell.getRow().getCells()[0].getValue(),
                code : valcode,
                value: cell.getValue(),
                dirty: 0,
                // conv : definition.conv,
                decimals: definition.decimals
            };
            // variable to control user grants
            checkGrant = checkGrant || definition.updateGrant;
            cellArray.push(cellElement);
        });

        // check user's grants
        // if false then show warning message and return from event
        if(!checkGrant){
            swal('Azione non consentita', 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione sulla stazione selezionata!', 'warning');
            return false;
        }

        // check if clicked code is an automatic code
        // if true ask for confirmation
        if(valcode == -2){
            swal({
                title: "Codice automatico",
                text: "Sei sicuro di voler assegnare un codice della validazione automatica?",
                type: "warning",
                showCancelButton: true,
                closeOnConfirm: true,
                confirmButtonText: "Si, invalida!",
                cancelButtonText: "Annulla",
            }, function (isConfirm) {
                if (isConfirm){
                    // show preloader, waiting for the end of the process
                    $('.preloader').show();
                    // save into db changes applied by the event - validazione.js
                    updateCells(cellArray);
                }
                else{
                    return false;
                }
            });
        }
        else{
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // save into db changes applied by the event - validazione.js
            updateCells(cellArray);
        }
    });

    // FORM OPERAZIONI
    /**
     * Click event on any operation button, form in the right column
     */
    $("#validation-main").on('click', '#operations-form button', function(e){
        e.preventDefault();
        // take care of elements classes
        $("#operations-form button").removeClass('sel');
        $(this).addClass('sel');
    });

    /**
     * Click event on "Esegui" button, form in the right column
     */
    $("#validation-main").on('click', '#update-value-cells', function(e){
        e.preventDefault();

        // if clipboard is enabled then disable all other events - return from click event
        if(clipboardEnabled == true)
            return;
        else if(selectedCells && selectedCells.length == 1){

            var cellDate = selectedCells[0].getRow().getCells()[0].getValue();
            // check if value date is before closure date (portal options)
            // - if true then select do nothing
            // - else continue
            if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                swal({
                    title: 'Attenzione',
                    text: 'Il dato selezionato è <strong>bloccato</strong>. Impossibile eseguire l\'operazione',
                    type: 'info',
                    html: true
                });
                return false;
            }
        }

        // retrieve operation and value to be used
        var operator =  $("#validation-main #operations-form button.sel").text();
        var value = $("#validation-main #valid-value").val();

        // check that value is not empty
        if(value == ''){
            swal("Info", "Inserire un valore valido", "info");
            return;
        }

        // check that operator is not empty
        if(operator == null || operator == ""){
            swal("Info", "Selezionare un'operazione da applicare ai dati", "info");
            return;
        }
        // prevent division by 0
        else if(operator == '/' && value == 0){
            swal("Info", "Operazione non permessa!", "info");
            return;
        }

        // build string for the operation managing the case of replacement
        var tmpOp;
        if(operator == '='){
            tmpOp = 'y='+value;
        }
        else{
            tmpOp = 'y=x'+operator + value;
        }

        // show confirm message
        swal({
            title: "Attenzione",
            text: 'Stai per <strong>modificare il valore</strong> delle celle selezionate secondo la seguente operazione: <strong> '+tmpOp+'</strong><br>Procedere?',
            html: true,
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, procedi",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {

            var operation = operator + value;
            // save into db changes applied by the event - validazione.js
            updateSelectedCellsByOperations(operation);
        });
    });

    /**
     * Click event on "Annulla" button, form in the right column
     */
    $("#validation-main").on('click', '#reset-operations', function(e){
        e.preventDefault();
        // reset form
        $("#operations-form button").removeClass('sel');
        $("#validation-main #valid-value").val('');
    });
}
/////////////////////////////////////////////////////////////////////////
// END GLOBAL FUNCTIONS
