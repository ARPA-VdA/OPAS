/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    // global variables used in the config tab for
    // comparison with parameters uploaded by configuration file
    var stationParams;
    var configParams;

    var mySwitchParamActive;
    var mySwitchParamExport;
    var mySwitchParamWs;

    $('.show-selected').hide();
    $('#all-params').hide();

    // FILTERS
    /////////////////////////////////////////////////////////////////////
    $.fn.select2.defaults.set("width", null);
    $("#provinces, #networks").select2();
    $("#stations").select2({
        templateResult: function (data) {
            // We only really care if there is an element to pull classes from
            if (!data.element) {
                return data.text;
            }

            var $element = $(data.element);

            var $wrapper = $('<span></span>');
            $wrapper.addClass($element[0].className);

            $wrapper.text(data.text);

            return $wrapper;
        },
        matcher: searchGroupedSelect2
    });

    // CHANGE EVENTS
    /**
     * Provinces and networks change event
     */
    $("#provinces, #networks").on("change", function (e, stid) {
        e.preventDefault();
        // if event is triggered by networks filter then reset provinces
        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        // load stations
        loadStations(stid);
    });

    /**
     * Stations change event
     */
    $("#stations").on("change", function(e){
        e.preventDefault();

        // get station id and station name from selected option
        var stid = $(this).val();
        var stname = $(this).find('option:selected').text();

        // check if station exists (case of stid from url)
        if (stid == null) {
            // warning message
            swal('Attenzione!', 'Non si possiedono i permessi necessari per visualizzare questa stazione', 'warning');
            // reset filter
            $(this).val(-1);
            return false;
        }

        // if user select a station then take care of container visibility and set box title
        // else reset all
        if(stid != -1){
            $("#selected-station").html('Hai selezionato la stazione di: <strong>'+stname+'</strong> <small class="font-bold">&rarr; STID '+stid+'</small>');
            $("#selected-link").attr('href', '/cnf_stazioni/'+stid);
            $('#tobe-selected').hide('slow');
            $('.show-selected').show('slow');

            clearFields();
            clearConfigFields();
            $('#hidden-tab').hide();

            $("#categories").val(-1).trigger('change.select2');
            loadStationParams(stid, -1, false);
        }
        else{
            $('#tobe-selected').show('slow');
            $('.show-selected').hide('slow');
            $('#all-params').hide('slow');
            $("#selected-station").empty();
            $("#selected-link").attr('href', '#');
        }
    });
    /////////////////////////////////////////////////////////////////////
    // END FILTERS


    // PARAMETERS LIST
    /////////////////////////////////////////////////////////////////////

    $('#hidden-tab').hide();

    $("#categories").select2({
        templateResult: function(state){
            if (!state.id || state.id == -1) {
                return state.text;
            }
            var icon   = $(state.element).data('icon');
            var colour = $(state.element).data('colour');
            var $state = $(
            '<span class="btn btn-categories btn-'+colour+'">'+icon+' '+state.text+'</span>'
            );

            return $state;
        }
    });

    /**
     * Stations change event
     */
    $("#categories").on("change", function(e){
        e.preventDefault();

        // get parameter type and station id
        var type = parseInt($(this).val());
        var stid = parseInt($('#stations').val());

        // refresh list
        loadStationParams(stid, type, false);
    });

    //datatable
    table = $('#table-params').DataTable({
        "dom": '<"row"<"col-6"l><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        lengthMenu: [[25, 50, 75, 100, -1], [25, 50, 75, 100, "Tutti"]],
        // autoWidth: false,
        buttons: [
        //     'csv',
        //     'pdf',
        //     {
        //         "extend": 'print',
        //         "text"  : 'STAMPA'
        //     }
        ],
        order: [[ 1, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        },
        columnDefs: [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "targets": 0 }
        ]
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // View parameter
    $('#table-params').on('click', '.show-param', function(e){
        e.preventDefault();

        // get station-parameter id stored in tr
        var stprid = parseInt($(this).parent().parent().data("stprid"));

        // check if the station's detail is already open
        if( $('#param'+stprid).length ) {
            console.log('The parameter\'s detail is already open');
            $('.customtab a[href="#st' + stprid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createParameterDetail(stprid);
    });

    // Edit parameter
    $('#table-params').on('click', '.edit-param', function(e){
        e.preventDefault();
        // show "Modifica" tab
        $('#hidden-tab').show();

        // get station-parameter id stored in tr
        var stprid = parseInt($(this).parent().parent().data("stprid"));
        // retrieve parameter metadata and fill form's fields
        fillEditForm(stprid);
    });

    // Delete parameter
    $('#table-params').on('click', '.delete-param', function(e){
        e.preventDefault();

        // get station-parameter id stored in tr
        var stprid = parseInt($(this).parent().parent().data("stprid"));
        // get row element
        var tr = $(this).parent().parent();

        // show confirm message before proceed
        swal({
            title: "Stai per eliminare il parametro",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/cnf_parametri_del_station_param',
                type: "post",
                dataType: "json",
                data: {
                    id: stprid
                }
            })
            .done(function(result) {

                // check result
                // if TRUE remove row reloading the entire list
                // else show ERROR
                if(result){
                    swal("Parametro eliminato", "Il parametro è stato eliminato con successo!", "success");
                    var stid   = parseInt($("#stations").val());
                    var type   = parseInt($("#categories").val());

                    loadStationParams(stid, type, ( configParams != null ) );
                }
                else{
                    swal("Errore!", "Errore durante l'eliminazione del parametro", "error");
                }

            })
            .fail(function(xhr, err) {
                // take care of error
                swal("Errore!", "Errore durante l\'eliminazione del parametro", "error");
            });

        });
    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    $('#param-prid').select2();

    mySwitchParamActive = new Switchery($("#param-active")[0], $("#edit-param-active").data());
    mySwitchParamExport = new Switchery($("#param-export-active")[0], $("#edit-param-export-active").data());
    mySwitchParamWs     = new Switchery($("#param-ws-active")[0], $("#edit-param-ws-active").data());

    // date picker
    $('#param-startup-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(1, "month"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
        // autoclose: true,
        // todayHighlight: true
    });
    $('#param-startup-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));

    // date picker
    $('#param-dismiss-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(1, "month"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
        // autoclose: true,
        // todayHighlight: true
    });
    $("#param-dismiss-date").prop("disabled", true);

    /**
     * Change event on "param active" switch
     */
    $( "#param-active").on("change", function(){
        // get new status
        var check = $("#param-active").is(":checked");
        // if active then reset dismiss date field and disable it
        // else enable dismiss date and fill it with current date
        if(check){
            $("#param-dismiss-date").prop("disabled", true);
            $("#param-dismiss-date").val("");
        }
        else{
            $("#param-dismiss-date").prop("disabled", false);
            $("#param-dismiss-date").val("");
            $("#param-dismiss-date").bootstrapMaterialDatePicker("setDate", moment().format('DD/MM/YYYY'));
        }
    });

    // validate form
    $('#param-form').validate({ // initialize the plugin
        rules: {
            "param-tableid": {
                required: true,
                min: 1
            },
            "param-prid": {
                required: true,
                min: 0
            },
            "param-startup-date":{
                required: true,
                validDate: true
            },
            "param-dismiss-date":{
                required: function(){
                    return ! $("#edit-param-active").is(":checked")
                },
                validDate: true
            }
        },
        messages: {
            "param-tableid": {
                required: "Inserire l'ID per la tabella",
                min: "Inserire un numero intero maggiore di 0"
            },
            "param-prid": {
                required: "Selezionare parametro",
                min: "Selezionare parametro"
            },
            "param-startup-date":{
                required: "Inserire data di attivazione",
                validDate: "Inserire una data valida"
            },
            "param-dismiss-date":{
                required: "Inserire data di disattivazione",
                validDate: "Inserire una data valida"
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
     * Submit event
     */
    $('#param-form').on('submit', function (e) {
        e.preventDefault();

        // sanity check
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Modifiche non salvate!", "info");
            return false;
        };

        var form = $("#param-form");
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        $.ajax({
            type: 'post',
            url: '/cnf_parametri_put_station_param',
            data: form.serialize()
        }).done(function(result) {

            // check result
            // if 1 then show success message and refresh main list
            // if -1 then there is another station's parameter with selected table id: show warning message
            // else take care of error
            if(result == 1){
                // show success message
                $.toast({
                    heading: 'Successo',
                    text: 'Parametro modificato correttamente!',
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 5000
                });

                var stid   = parseInt($("#stations").val());
                var type   = parseInt($("#categories").val());

                loadStationParams(stid, type, ( configParams != null ) );
            }
            else if(result == -1){
                // warning message
                swal({
                    title: "Attenzione!",
                    text: "L'ID tabella impostato è <strong>GIÀ USATO</strong> in questa stazione per un altro parametro.<br> Modificare il campo e riprovare.",
                    type: "warning",
                    html: true
                });
            }
            else{
                // error message
                swal("Errore!", "Errore durante la modifica del parametro.", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante la modifica del parametro.", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        });
    });

    /**
     * Click event on "Annulla" button
     */
    $('#edit-tab').on('click', '.param-cancel', function(e){
        e.preventDefault();
        // reset form
        clearFields();

        // hide "Modifica" tab and show all parameters list
        $('#hidden-tab').hide();
        $('#all-params .customtab a[href="#list-tab"]').tab('show');
    });

    /**
     * Event click on "Next" button
     */
    $('#edit-tab').on('click', '.next-param', function(e){
        e.preventDefault();

        // get current stprid from hidden field in form
        var stprid = parseInt($('#param-stprid').val());

        // {
        //     // DataTables core
        //     order:  'current',  // 'current', 'applied', 'index', 'original', number
        //     page:   'all',      // 'all',     'current'
        //     search: 'none',     // 'none',    'applied', 'removed'

        //     // Extension - KeyTable (v2.1+) - cells only
        //     focused: undefined, // true, false, undefined

        //     // Extension - Select (v1.0+)
        //     selected: undefined // true, false, undefined
        // }
        var selectorModifier = {
            order: 'current',
            page: 'all',
            search: 'applied'
        };

        // get row's index for the datatable plugin
        // select row with jquery selector
        // take into consideration: all pages, current order and only filtered rows
        var currIdx     = parseInt(table.row('tr[data-stprid="'+stprid+'"]', selectorModifier).index());

        // get all rows indexes and calculate the NEXT one
        var rowsIndexes = table.rows(selectorModifier).indexes();
        var arrayIdx = rowsIndexes.indexOf(currIdx);
        var newArrayIdx = arrayIdx + 1;

        // if index is valid and not out of range
        // then retrieve the stprid from the next row
        // else show warning message
        if( newArrayIdx < rowsIndexes.length ){
            var nextRow = table.row( rowsIndexes[newArrayIdx], selectorModifier).node();
            var nextStprid = parseInt($(nextRow).data('stprid'));
            fillEditForm(nextStprid);
        }
        else{
            swal('Attenzione', 'Non ci sono altri parametri disponibili successivi al corrente', 'warning');
        }
    });

    /**
     * Event click on "Previous" button
     */
    $('#edit-tab').on('click', '.prev-param', function(e){
        e.preventDefault();

        // get current stprid from hidden field in form
        var stprid = parseInt($('#param-stprid').val());

        var selectorModifier = {
            order: 'current',
            page: 'all',
            search: 'applied'
        };

        // get row's index for the datatable plugin
        // select row with jquery selector
        // take into consideration: all pages, current order and only filtered rows
        var currIdx = parseInt(table.row('tr[data-stprid="'+stprid+'"]', selectorModifier).index());

        // get all rows indexes and calculate the PREVIOUS one
        var rowsIndexes = table.rows(selectorModifier).indexes();
        var arrayIdx = rowsIndexes.indexOf(currIdx);
        var newArrayIdx = arrayIdx - 1;

        // if index is valid and not out of range
        // then retrieve the stprid from the previous row
        // else show warning message
        if( newArrayIdx >= 0 ){
            var prevRow = table.row( rowsIndexes[newArrayIdx], selectorModifier).node();
            var prevStprid = parseInt($(prevRow).data('stprid'));
            fillEditForm(prevStprid);
        }
        else{
            swal('Attenzione', 'Non ci sono altri parametri disponibili precedenti al corrente', 'warning');
        }
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    //close view report
    $('#all-params').on('click', '.close-element', function(e){
        e.preventDefault();

        var close = $(this).data("close");
        console.log(close);

        setTimeout(function(){
            $('#main-list a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('#main-list a[href="#list-tab"]').tab('show');
        }, 1);
    });


// CONFIGURATION TAB
{

    $('.config-info').hide();

    /**
    * Click event on button "Apri in fullscreen"
    */
    $('#main-object').on( 'click', '.to-fullscreen', function(e){
        e.preventDefault();
        // take care of classes
        $(this).toggleClass('to-fullscreen not-fullscreen');
        $("#main-object").addClass('fullscreen-show');
        // modify icon
        $(this).find("i").toggleClass('icon-size-actual icon-size-fullscreen');
    });

    /**
     * Click event on button "Riduci fullscreen"
     */
    $('#main-object').on( 'click', '.not-fullscreen', function(e){
        e.preventDefault();
        // take care of classes
        $(this).toggleClass('to-fullscreen not-fullscreen');
        $("#main-object").removeClass('fullscreen-show');
        // modify icon
        $(this).find("i").toggleClass('icon-size-actual icon-size-fullscreen');
    });

    $('.hide-config').hide();
    // 2 possible types of movement: by parameter or by instrument
    // for each type there are different descriptions
    $('#active-instr').hide();

    // $('#table-anomalous-params').hide();

    // boostraptoggle
    $( "#move-type" ).bootstrapToggle();

    var container = document.getElementById('jsoneditor-result');
    var options = {
        mode: 'view',
        modes: [],
        search: false,
        indentation: 4,
        name: 'Risultato',
        navigationBar: false,
        language: 'it',
        languages: jsonEditorlang
    };
    var configViewer = new JSONEditor(container, options);

    /**
     * Change event on "Sposta" switch
     */
    $("#move-type").on('change', function(e){
        e.preventDefault();
        // TRUE -> strumento ; FALSE -> parametro
        // var status = $(this).prop('checked');

        // check status
        //  - if true then move all parameters linked to the same instrument
        //  - if false then move single parameter
        $('#active-instr').toggle();
        $('#active-param').toggle();
    });


    $( "#config-tab" ).on('click', '#load-config', function(e){

        $('#config-info strong').empty();
        $('#table-config-params tbody').empty();
        $('#table-anomalous-params tbody').empty();
        configParams = null;

        // take care of json viewer
        configViewer.setText('{}');

        // use FormData in order to take care of files
        var form = new FormData();
        // append station id if defined
        form.append('station-id', parseInt($('#stations').val()));
        // get loaded file
        var file = $('#config-tab input[type="file"]')[0].files[0];
        // check if at least one file exists
        if(! file ){
            swal("Attenzione", "Nessuna configurazione caricata! Impossibile proseguire", "info");
            return false;
        }

        // append file
        form.append($('#config-tab input[type="file"]').attr('name'), file);
        // ajax call
        $.ajax({
            type: 'post',
            url: '/cnf_parametri_put_config_file',
            processData: false, // IMPORTANT! mandatory for files uploads
            contentType: false, // IMPORTANT! mandatory for files uploads
            data: form
        }).done(function(result) {
            console.dir(result);

            if(result.res == 'OK'){
                // show success message
                $.toast({
                    heading: 'Successo',
                    text: 'Configurazione caricata correttamente!',
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 5000
                });

                // set JSONEditor plugin content
                configViewer.set(result.config);
                configViewer.expandAll();
                // set title
                $('.config-info').show('slow');
                $('#config-file-name').text(result.config.Name);
                $('#config-file-header').text(result.config.DataFileHeader);
                // parse ajax result
                var params = JSON.parse(result.params);
                configParams = params.found;

                // fill table in configuration tab
                // function used also to refresh the view
                fillConfigTable();

                // show table container
                $('.hide-config').show('slow');
                setTimeout(function(){
                    $( "#move-type" ).bootstrapToggle('destroy').bootstrapToggle();
                }, 100);

                // fill modal with anomalous results
                if(params.not_active.length + params.not_found.length == 0){

                    $('button[data-target="#view-formatted-anomalies"]').hide();

                    // $('#no-anomalies').show();
                    // $('#table-anomalous-params').hide();
                }
                else{
                    $('button[data-target="#view-formatted-anomalies"]').show();

                    // $('#no-anomalies').hide();
                    // $('#table-anomalous-params').show();

                    // variable for dinamically building the html
                    var html = '';
                    // loop through all parameters
                    // for each element build an html row to be added to the table
                    params.not_active.forEach(function(el){

                        html += '<tr>'
                        html += '    <td>'+el.id+'</td>';
                        html += '    <td>'+el.module+'</td>';
                        html += '    <td>'+el.name+'</td>';
                        html += '    <td class="">Non attivo</td>';
                        html += '</tr>';
                    });

                    // mapped with a generic parameter (prid 0)
                    params.not_found.forEach(function(el){

                        html += '<tr>'
                        html += '    <td>'+el.id+'</td>';
                        html += '    <td>'+el.module+'</td>';
                        html += '    <td>'+el.name+'</td>';
                        html += '    <td class="">Non trovato</td>';
                        html += '</tr>';
                    });

                    $('#table-anomalous-params tbody').append(html);
                }

            }
            else{
                // takes care of errr
                swal("Errore!", 'Errore durante il caricamento o la lettura del file di configurazione', "error");
            }
        })
        .fail(function(xhr, err) {
            // takes care of errr
            swal("Errore!", 'Errore durante il caricamento o la lettura del file di configurazione', "error");
        });
    });

    /**
     * Click event on ">>" button
     */
    $( "#config-tab" ).on( "click", ".add-all-param", function(e) {
        e.preventDefault();

        // Toggle icon and button classes
        $(this).find("i").toggleClass("fa-chevrons-right fa-chevrons-left");
        $(this).toggleClass("btn-warning btn-success");

        // Update tooltip message based on the type of movement (to the right or to the left column)
        // To the left <-
        if($(this).find("i").hasClass("fa-chevrons-right")){
            $(this).tooltip('hide').attr('data-original-title', 'Inserisci tutti i parametri nella configurazione');
            // loop through all elements and trigger click on "add-param" button
            // use setTimeout in order to do it asynchronously
            $( "#config-tab .new-param" ).find('.add-param').each(function(){
                var button = $(this);
                setTimeout(function(){
                    button.trigger('click', true);
                }, 1);
            });
        }
        // To the right ->
        else{
            $(this).tooltip('hide').attr('data-original-title', 'Rimuovi tutti i parametri nella configurazione');
            // loop through all elements and trigger click on "add-param" button
            // use setTimeout in order to do it asynchronously
            $( "#config-tab .to-right" ).find('.add-param').each(function(){
                var button = $(this);
                setTimeout(function(){
                    button.trigger('click', true);
                }, 1);
            });
        }
    });

    /**
     * Click event on ">" button
     */
    $( "#config-tab" ).on( "click", ".add-param", function(e, allFlag) {
        e.preventDefault();

        // TRUE -> strumento ; FALSE -> parametro
        var moveInstr = $('#move-type').prop('checked');
        // if click has been triggered from >> button or from an instrument movement
        // then move single parameter
        if(allFlag){
            moveInstr = false;
        }

        $(this).find("i").toggleClass("fa-less-than fa-greater-than");
        $(this).toggleClass("btn-warning btn-success");

        var tr = $(this).parent().parent();
        if(! tr.hasClass('warning-row'))
            tr.toggleClass("font-bold");
        // else
        // nothing to do

        tr.toggleClass("to-right new-param");

        var tds = $('td', tr).toArray();
        var halfIdx = parseInt( tds.length / 2 );
        var offset = halfIdx +1;

        // move param from right to left <-
        if($(this).find("i").hasClass("fa-greater-than")){
            // console.log('Move param from right to left');

            $(this).tooltip('hide').attr('data-original-title', 'Inserisci nella configurazione');

            for(let i= offset; i< tds.length; i++){
                // console.log('From '+i+' to '+(i-offset));

                let copyTo = $(tds[i]).clone();
                let copyFrom = $(tds[i-offset]).clone();
                $(tds[i]).replaceWith(copyFrom);
                $(tds[i-offset]).replaceWith(copyTo);
            }

            if(moveInstr){
               $('#table-config-params tbody').find('tr[data-module="'+tr.data('module')+'"]').each(function(){
                    var curr = $(this);
                    // if current row is the same one on which the event occurred
                    // or the parameter has been already added then do nothing
                    if(curr.is(tr) || curr.hasClass('to-right'))
                        // skip to next loop
                        return;

                    // use setTimeout in order to do it asynchronously
                    setTimeout(function(){
                        curr.find('.add-param').trigger('click', true);
                    }, 1);

               });
            }

            // check if at least one "new-param" exists otherwise toggle icon and class of "<<" button
            if( $('#table-config-params .new-param').length == 0 ){
                // Toggle icon and button classes
                $('#config-tab .add-all-param').find("i").removeClass("fa-chevrons-left");
                $('#config-tab .add-all-param').find("i").addClass("fa-chevrons-right");
                $('#config-tab .add-all-param').removeClass("btn-warning");
                $('#config-tab .add-all-param').addClass("btn-success");
            }
        }
        // move param from left to right ->
        else{
            // console.log('Move param from left to right');

            $(this).tooltip('hide').attr('data-original-title', 'Rimuovi dalla configurazione');

            for(let i = 0; i < halfIdx; i++){
                // console.log('From '+i+' to '+(i+offset));

                let copyTo = $(tds[i]).clone();
                let copyFrom = $(tds[i+offset]).clone();
                $(tds[i]).replaceWith(copyFrom);
                $(tds[i+offset]).replaceWith(copyTo);
            }

            if(moveInstr){
               $('#table-config-params tbody').find('tr[data-module="'+tr.data('module')+'"]').each(function(){
                    var curr = $(this);
                    // if current row is the same one on which the event occurred
                    // or the parameter has been already added then do nothing
                    if(curr.is(tr) || curr.hasClass('new-param'))
                        // skip to next loop
                        return;

                    // use setTimeout in order to do it asynchronously
                    setTimeout(function(){
                        curr.find('.add-param').trigger('click', true);
                    }, 1);

               });
            }

            // check if at least one "new-param" exists otherwise toggle icon and class of ">>" button
            if( $('#table-config-params .to-right').length == 0 ){
                // Toggle icon and button classes
                $('#config-tab .add-all-param').find("i").removeClass("fa-chevrons-right");
                $('#config-tab .add-all-param').find("i").addClass("fa-chevrons-left");
                $('#config-tab .add-all-param').removeClass("btn-success");
                $('#config-tab .add-all-param').addClass("btn-warning");
            }
        }
        // re-initialize tooltip
        $('.c-help', tr).tooltip();
    });

    /**
     * Click event on X button
     */
    $( "#config-tab" ).on( "click", ".del-param", function(e) {
        e.preventDefault();

        // take care of classes of clicked button
        $(this).find("i").toggleClass("fa-rotate-right fa-xmark-large");
        $(this).toggleClass("btn-warning btn-danger");


        // enable action
        if($(this).find("i").hasClass("fa-xmark-large")){
            $(this).tooltip('hide').attr('data-original-title', 'Disattiva dalla configurazione');
        }
        // disable action
        else{
            $(this).tooltip('hide').attr('data-original-title', 'Riattiva nella configurazione');
        }

        // get tr element and toggle classes
        var tr = $(this).parent().parent();
        tr.toggleClass("txt-lt font-bold");
        tr.toggleClass("disabled-param");
    });

    /**
     * Click event on "Salva" button
     */
    $("#config-tab").on('click', '.station-config-save', function(e){
        e.preventDefault();

        var close = parseInt($(this).data('close'));

        var stid = parseInt($('#stations').val());

        var newParams = [];
        var genericFlag = false;
        // loop through all added parameters and add object into array to be sent to server
        $('#table-config-params .new-param').each(function(){

            let currParam = $(this);
            // find param object in global variable configParams with the same table id of added parameter
            // Cloning the Object with Spread Operator
            let toBeAdded = { ... configParams.find(function(item) {
                                return item.id === parseInt(currParam.data('id'));
                            }) };


            // check if there is another parameter of the same module
            // that has already obtained a group id
            let tmpEl = $('#table-config-params tbody').find('tr[data-module="'+currParam.data('module')+'"][data-groupid]').first();
            if( ! isNaN( parseInt( $(tmpEl).data('groupid')) ) )
                toBeAdded.groupid = parseInt( $(tmpEl).data('groupid'));

            // check if it is a generic parameter
            if(toBeAdded.prid == 0)
                genericFlag = true;

            // add it into array
            newParams.push(toBeAdded);
        });

        // sort array per module id
        newParams.sort(function(a,b){
            return a.module - b.module;
        });

        // console.dir(newParams);

        var disabledParams = [];
        $('#table-config-params .disabled-param').each(function(){

            let currParam = $(this);
            disabledParams.push(parseInt(currParam.data('stprid')));
        });

        // if there is at least one generic parameter, display a warning message
        if(genericFlag){
            // html to inject into the swal
            var txt = '';
            txt += 'La procedura automatica non ha riconosciuto alcuni parametri della configurazione.<br>';
            txt += '<strong>È necessario mappare i parametri MANUALMENTE!</strong><br>';
            txt += 'Per eseguire la modifica cliccare sulla <i class="icon-pencil text-info"></i> nella prima scheda di questa pagina.<br><br>';
            txt += 'Confermi di aver preso visione della segnalazione?<br>';
            txt += '<input type="checkbox" id="warning-confirm" name="warning-confirm" /> <label for="warning-confirm">Confermo</label>';
    
            // show confirm message
            swal({
                title: "Attenzione",
                text: txt,
                type: "warning",
                html: true,
                showCancelButton: true,
                confirmButtonText: "Prosegui",
                closeOnConfirm: false,
                showLoaderOnConfirm: true,
                cancelButtonText: "Annulla"
            }, function (isConfirm) {
    
                // if Annulla then return
                if (isConfirm === false) return false;
                // if checkbox not checked then show validation error
                if (! $('#warning-confirm').is(':checked') ) {
                    swal.showInputError("E' necessario dare conferma di lettura");
                    return false;
                }

                // ajax call
                var jqxhr = $.ajax({
                    type: 'post',
                    url: '/cnf_parametri_put_config_params',
                    dataType: "json",
                    data: {
                        stid: stid,
                        new: JSON.stringify(newParams),
                        disabled: JSON.stringify(disabledParams)
                    }
                })
                .done(function(result) {
                    console.dir(result);

                    // check result
                    // if TRUE then reload station parameters
                    // else show error
                    if( result ){
                        // show success message
                        swal("Successo", "Modifiche salvate correttamente!", "success");

                        // get parameter type
                        let type   = parseInt($("#categories").val());

                        // refresh list
                        loadStationParams(stid, type, !close) ;

                        if(close){
                            // show list tab
                            $('.customtab a[href="#list-tab"]').tab('show');
                            // clear config form
                            clearConfigFields();
                        }
                    }
                    else{
                        // takes care of errr
                        swal("Errore!", 'Errore durante il salvataggio delle modifiche', "error");
                    }
                })
                .fail(function(xhr, err) {
                    // takes care of errr
                    swal("Errore!", 'Errore durante il salvataggio delle modifiche', "error");
                });
            });

        }
        else{
            // ajax call
            var jqxhr = $.ajax({
                type: 'post',
                url: '/cnf_parametri_put_config_params',
                dataType: "json",
                data: {
                    stid: stid,
                    new: JSON.stringify(newParams),
                    disabled: JSON.stringify(disabledParams)
                }
            })
            .done(function(result) {
                console.dir(result);

                // check result
                // if TRUE then reload station parameters
                // else show error
                if( result ){
                    // show success message
                    $.toast({
                        heading: 'Successo',
                        text: 'Modifiche salvate correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                    // get parameter type
                    let type   = parseInt($("#categories").val());

                    // refresh list
                    loadStationParams(stid, type, !close) ;

                    if(close){
                        // show list tab
                        $('.customtab a[href="#list-tab"]').tab('show');
                        // clear config form
                        clearConfigFields();
                    }
                }
                else{
                    // takes care of errr
                    swal("Errore!", 'Errore durante il salvataggio delle modifiche', "error");
                }
            })
            .fail(function(xhr, err) {
                // takes care of errr
                swal("Errore!", 'Errore durante il salvataggio delle modifiche', "error");
            });
        }
        
    });

    /**
     * Click event on "Annulla" button
     */
    $("#config-tab").on('click', '#station-config-cancel', function(e){
        e.preventDefault();

        clearConfigFields();
    });

}

    // first load of provinces and stations
    if (stid != null && ! isNaN(stid) ) {
        $("#networks").trigger("change", stid); // select option stid
    } else {
        $("#networks").trigger("change"); // select option -1 and load all stations
    }

    // UTILITIES FUNCTION

    /**
     * Function that sets the Switchery element.
     *
     * @param {html_element} switchElement HTML Switchery element.
     * @param {boolean} checkedBool Boolean value provided by the user.
     */
    function setSwitchery(switchElement, checkedBool) {
        if((checkedBool && !switchElement.isChecked()) || (!checkedBool && switchElement.isChecked())) {
            switchElement.setPosition(true);
            switchElement.handleOnchange(true);
        }
    }

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
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} field Boolean value provided to format.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */

    function formatFlagField(field) {
        if(field == true)
            return '<i class="fa-solid fa-check text-success"></i>&nbsp;Si';
        else
            return '<i class="fa-solid fa-xmark text-danger"></i>&nbsp;No';
    }
    // END UTILITIES

    /**
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields(){
        // manage input type text
        $('.clear-input').val("");
        // manage select
        $('.clear-select').val(-1).trigger('change');

        // manage Switchery
        setSwitchery(mySwitchParamActive   , true);
        setSwitchery(mySwitchParamExport  , false);
        setSwitchery(mySwitchParamWs      , false);

        $('#param-startup-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));
        $("#param-dismiss-date").prop("disabled", true);

        $('#edit-tab .box-title strong').text('');

        // reset validate plugin
        $('#param-form').validate().resetForm(); // reset form error
    };

    /**
     * Function that resets table in configuration tab
     * No args needed
     */
    function clearConfigFields(){

        configParams = null;

        $('#title-config-params').html('<i class="fa-light fa-pencil"></i> <strong>Prima configurazione</strong> - <em>Seleziona i parametri</em> che vuoi inserire nella tua configurazione');

        $('.config-info').hide();
        $('#config-file-name').empty();
        $('#config-file-header').empty();

        // clear modal result
        $('#config-info strong').empty();
        $('#table-config-params tbody').empty();
        $('#table-anomalous-params tbody').empty();

        // take care of input files
        $('#config-tab input[type="file"]').val('');
        // take care of json viewer
        configViewer.setText('{}');

        $('.hide-config').hide();
    };

    /**
     * Function that retrieves all stations in order to fill provinces and stations filters
     *
     * @param {numeric} stid: Station ID
     */
    function loadStations(stid){

        var prid = parseInt($("#provinces").val());
        var netid = parseInt($("#networks").val());

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_stations',
            type: "post",
            dataType: "json",
            data: {
                netid: netid,
                prid: prid,
                status: -1
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill province filter and main table with retrieved data
            if(result.res == 'OK'){

                // reset "province" filter
                if(prid == -1){
                    $('#provinces').empty();
                    $('#provinces').append('<option value="-1">Seleziona provincia...</option>');
                }

                $("#stations").empty();
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');

                var stations = result.stations;
                // perform the distinct of the provinces
                // exclude null values
                var provinces = stations.filter((value, index, self) =>
                    index === self.findIndex((t) => (
                        t.province_id === value.province_id && t.province_id != null
                    ))
                );
                // order them by region name and province name
                provinces.sort((a, b) => a.region_name.localeCompare(b.region_name) || a.province_name.localeCompare(b.province_name));

                // variable for dinamically building the html
                var opts = '';
                var rows = '';
                var net;

                var optsProv = '';
                var reg;
                var prov;

                // check if at least one station exists
                if(stations.length > 0){
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

                        var classOption = '';
                        if(! station.station_active){
                            classOption = 'not-active';
                        }

                        opts += '<option class="'+classOption+'" value="'+ station.station_id+'">'+station.station_name+'</option>';
                    });

                    // check prid value
                    //     - if equal to -1 then, loadStations called by a network change
                    //     -> reset select and fill it again with filtered provinces
                    if(prid == -1){
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


                        $('#provinces').append(optsProv);
                        $('#provinces').append('</optgroup>');

                        $('#provinces').val(-1);
                    }

                    $('#stations').append(opts);
                    $('#stations').append('</optgroup>');

                    // set station_id (arrived from db)
                    if(stid != null){
                        $('#stations').val(stid).trigger('change');
                    }
                    else{
                        $('#stations').val(-1).trigger('change');
                    }
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that retrieves all parameters linked to selected station
     *
     * @param {numeric} stid: Station ID
     * @param {numeric} type: Parameter type
     * @param {boolean} refresh: Refresh flag for reload table in configuration tab
     */
    function loadStationParams(stid, type, refresh){

        if(table)
            table.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        var jqxhr = $.ajax({
            url: '/cnf_parametri_get_parameters_by_stid',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                type: type
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill province filter and main table with retrieved data
            if(result.res == 'OK'){

                $('#all-params').show('slow');

                var params = result.params;

                // variable for dinamically building the html
                var html = '';
                stationParams = [];

                if(params.length > 0){
                    // loop through all elements
                    // for each station, build a html option to be added to the select
                    $.each(params, function(index, value){

                        // <th></th>
                        // <th>ID</th>
                        // <th>PRID</th>
                        // <th>STPRID</th>
                        // <th>GROUPID</th>
                        // <th>Nome</th>
                        // <th>Tipologia</th>
                        // <th>Unità</th>
                        // <th>Fattore conv.</th>
                        // <th>Unità conv.</th>
                        // <th>Attivo</th>
                        // <th>Exp. Attivo</th>
                        // <th>Exp. ID</th>
                        // <th></th>

                        html += '<tr data-stprid="'+value.stpr_id+'">';
                        html += '    <td class="bobo-nowrap icons-little">';
                        html += '        <a href="javascript:void(0)" class="show-param" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                        if(update_grant)
                            html +='        <a href="javascript:void(0)" class="edit-param" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        if(delete_grant)
                            html +='        <a href="javascript:void(0)" class="delete-param" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        html += '    </td>';
                        html += '    <td>'+value.stpr_table_id+'</td>';
                        html += '    <td>'+value.param_id+'</td>';
                        html += '    <td>'+value.stpr_id+'</td>';
                        html += '    <td>'+formatTextField(value.stpr_group_id)+'</td>';
                        html += '    <td class="font-bold">'+value.parameter_name+'</td>';
                        html += '    <td><span class="badge badge-'+value.parameter_type_colour+'"><i class="'+value.parameter_type_icon+'"></i> '+value.parameter_type_desc+'</span></td>';
                        html += '    <td>'+value.measure_cadence_desc+'</td>';
                        html += '    <td>'+value.param_unit+'</td>';
                        html += '    <td>'+value.parameter_formule+'</td>';
                        html += '    <td>'+value.param_unit_conv+'</td>';
                        html += '    <td>'+formatFlagField(value.stpr_active)+'</td>';
                        html += '    <td>'+formatFlagField(value.stpr_export_publish)+'</td>';
                        html += '    <td>'+value.stpr_export_ids+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';

                        let paramObj = {
                            'stprid' : value.stpr_id,
                            'prid'   : value.param_id,
                            'id'     : value.stpr_table_id,
                            'name'   : value.parameter_name,
                            'module' : (value.stpr_group_id ? value.stpr_group_id : ''),
                            // 'note': value.stpr_note,
                            'unit'   : value.param_unit,
                            // 'need-group': value.stpr_group_id ? true : false,
                            // 'daily': (value.stpr_info_cadence_fk && value.stpr_info_cadence_fk == 8 ) ? true : false
                            'active' : value.stpr_active
                        };

                        stationParams.push(paramObj);

                    });

                    // add rows to datatable by using html object and redraw it
                    table.rows.add($( html ));
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

                    // set content of configuration tab
                    $('#title-config-params').html('<i class="fa-light fa-paintbrush-pencil"></i> <strong>Modifica configurazione</strong> - <em>Seleziona i parametri</em> che vuoi inserire nella tua configurazione attuale, oppure <em>disabilita quelli che non sono più attivi</em>');
                    if(refresh){
                        $('#table-config-params tbody').empty();

                        fillConfigTable();
                    }
                }
                else{
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");

        });
    }

    /**
     * Function that builds station - parameter detail
     *
     * @param {numeric} stprid: Station parameter ID
     */
    function createParameterDetail(stprid){
        console.log('createParameterDetail: '+stprid);

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_parametri_get_parameter_by_stprid',
            type: "post",
            dataType: "json",
            data: {
                stprid: stprid
            },
        })
        .done(function(result) {

            // check result and if ok create new tab with parameter detail
            if(result.res == 'OK'){

                var el = result.parameter;

                // add link for the new tab
                var html = '<li class="nav-item hide-el"> <a class="nav-link" data-toggle="tab" href="#param'+stprid+'"  role="tab"><span class="hidden-sm-up"><i class="fa-sharp fa-light fa-book-open-cover"></i></span> <span class="hidden-xs-down">'+el.parameter_fullname+'</span> <i class="fa fa-times text-danger close-element" data-close="param'+stprid+'" aria-hidden="true"></i></a></li>';
                $('#main-list').append(html);

                // variable for dinamically building the html
                var html = '';

                // after variable reset, build station detail
                html += '<div class="tab-pane" id="param'+stprid+'" role="tabpanel">';
                html += '    <div class="card">';
                html += '        <div class="card-body">';
                html += '            <div class="form-body panel-report-view panel-view-mobile">';
                html += '                <h4 class="box-title">Visualizza <strong>'+el.parameter_fullname.toUpperCase()+'</strong></h4>';
                html += '                <hr class="m-t-0 m-b-20">';
                html += '                <h5 class="divider-title"><i class="icon-settings"></i> Generali</h5>';
                html += '                <div class="form-group row">';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Nome parametro</label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+el.param_name+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Note</label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_note)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">';
                html += '                        Cadenza misurazione';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Le tipologie sono: '+measuresCadences+'</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.measure_cadence_desc)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Parametro attivo</label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatFlagField(el.stpr_active)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Data attivazione</label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_startup_date)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Data disattivazione</label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_dismiss_date)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">ID sistema';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">STPRID: id univoco in tutto il sistema, assegnato automaticamente all\'aggiunta della serie di dati e non modificabile</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+stprid+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">ID parametro';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">PRID: id dell\'inquinante a cui la serie di dati fa riferimento</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+el.param_id+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">ID tabella';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">TABLEID: id della serie dei dati assegnato in periferia, univoco per la stazione</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+el.stpr_table_id+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">ID gruppo strumento';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">GROUPID: id che raggruppa le serie di dati acquisite dallo stesso strumento, univoco nel sistema, assegnato automaticamente e non modificabile</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_group_id)+'</div>';
                html += '                    <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">ID esterno';
                html += '                        <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">EXTID: id esposto dall\'API e usato per la mappatura con i sistemi interni di ciascuna ARPA</span></span></span>';
                html += '                        </a>';
                html += '                    </label>';
                html += '                    <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_ext_id)+'</div>';
                html += '                </div>';
                html += '                <div class="row">';
                html += '                    <div class="col-lg-4">';
                html += '                        <h5 class="divider-title"><i class="fa-light fa-file-import" aria-hidden="true"></i> Varie Import</h5>';
                html += '                        <div class="form-group row">';
                html += '                            <label class="control-label col-sm-6 col-lg-4 col-4 col-form-label" for="">Codice web service</label>';
                html += '                            <div class="col-sm-6 col-lg-8 col-8 view-param mb-2">'+formatTextField(el.stpr_import_ws_id)+'</div>';
                html += '                        </div>';
                html += '                    </div>';
                html += '                    <div class="col-lg-8">';
                html += '                        <h5 class="divider-title"><i class="fa-light fa-file-import" aria-hidden="true"></i> Varie Export</h5>';
                html += '                        <div class="form-group row">';
                html += '                            <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Export attivo</label>';
                html += '                            <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatFlagField(el.stpr_custom_export_publish)+'</div>';
                html += '                            <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Export ID 1';
                html += '                                <a class="mytooltip" href="javascript:void(0)">';
                html += '                                    <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                    <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Id parametro usato per l\'export di file CSV o estensioni personalizzate</span></span></span>';
                html += '                                </a>';
                html += '                            </label>';
                html += '                            <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_export_id1)+'</div>';
                html += '                            <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Export ID 2';
                html += '                                <a class="mytooltip" href="javascript:void(0)">';
                html += '                                    <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                    <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Id parametro usato per l\'export di file CSV o estensioni personalizzate</span></span></span>';
                html += '                                </a>';
                html += '                            </label>';
                html += '                            <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_export_id2)+'</div>';
                html += '                            <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Webservice attivo</label>';
                html += '                            <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatFlagField(el.stpr_ws_publish)+'</div>';
                html += '                            <label class="control-label col-sm-3 col-lg-2 col-4 col-form-label" for="">Webservice ID</label>';
                html += '                            <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+formatTextField(el.stpr_info_ws_id)+'</div>';
                html += '                        </div>';
                html += '                    </div>';
                html += '                </div>';
                html += '                <hr class="m-t-30">';
                html += '                <div class="row">';
                html += '                    <div class="col-12">';
                html += '                        <button class="btn btn-primary close-element" data-close="param'+stprid+'" type="button"><i class="icon-close"></i> Chiudi elemento</button>';
                html += '                    </div>';
                html += '                </div>';
                html += '            </div>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                // at the end of the process hide preloader
                $(".inner-preloader").hide();

                // append html
                $('#main-tab').append(html);

                // show the detail tab
                $('#main-list a[href="#param'+stprid+'"]').tab('show');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

    /**
     * Function that fills station - parameter form in order to modify the element
     *
     * @param {numeric} stprid: Station parameter ID
     */
    function fillEditForm(stprid){
        // reset form
        clearFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_parametri_get_parameter_by_stprid',
            type: "post",
            dataType: "json",
            data: {
                stprid: stprid
            },
        })
        .done(function(result) {

            // check result if OK then fill form with metadata retrieved from database
            if(result.res == 'OK'){

                var el = result.parameter;
                // take care of title
                $('#edit-tab .box-title strong').text(el.parameter_fullname);
                // fill input fields
                $('#param-stprid').val(stprid);
                $('#param-name').val(el.parameter_fullname);
                $('#param-prid').val(el.param_id).trigger('change');
                $('#param-tableid').val(el.stpr_table_id);
                $('#param-cadence').val((el.stpr_info_cadence_fk == null ? -1 : el.stpr_info_cadence_fk));
                $('#param-external-id').val(el.stpr_ext_id);

                setSwitchery(mySwitchParamActive, el.stpr_active);

                if(el.stpr_startup_date != null){
                    $("#param-startup-date").val(el.stpr_startup_date);
                    $("#param-startup-date").bootstrapMaterialDatePicker("setDate", el.stpr_startup_date);
                }
                else{
                    $("#param-startup-date").val("");
                    $("#param-startup-date").bootstrapMaterialDatePicker("setDate", moment().format('DD/MM/YYYY'));
                }

                if(el.stpr_active){
                    $("#param-dismiss-date").prop("disabled", true);
                    $("#param-dismiss-date").val("");
                }
                else{
                    $("#param-dismiss-date").prop("disabled", false);
                    $("#param-dismiss-date").val("");
                    $("#param-dismiss-date").bootstrapMaterialDatePicker("setDate", el.stpr_dismiss_date);
                }

                $('#param-note').val(el.stpr_note);

                $('#param-importid').val(el.stpr_import_ws_id);

                setSwitchery(mySwitchParamExport, el.stpr_custom_export_publish);
                $('#param-exportid-1').val(el.stpr_export_id1);
                $('#param-exportid-2').val(el.stpr_export_id2);

                setSwitchery(mySwitchParamWs, el.stpr_ws_publish);
                $('#param-ws-id').val(el.stpr_info_ws_id);

                    // show the detail tab
                $('#main-list a[href="#edit-tab"]').tab('show');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

    /**
     * Function that fill configuration table and compares the parameters extracted from the file with those already present in the portal
     * No args needed
     */
    function fillConfigTable(){

        // sort array per database id
        configParams.sort(function(a,b){
            return a.id - b.id;
        });

        // sort array per database id
        // stationParams initialized in loadStationParams function
        stationParams.sort(function(a,b){
            return a.id - b.id;
        });

        // create one single array with the totality of DatabaseIDs of both arrays
        var mergedArray = mergeArrays(configParams, stationParams);

        // variable for dinamically building the html
        var html = '';
        // loop through all elements
        // for each DatabaseIDs, build a html row to be added to the table
        $.each(mergedArray.left, function(idx){

            // 'module', (mo->>'ID')::integer,
            // 'prid', i,
            // 'name', n,
            // 'note', s,
            // 'unit', u,
            // 'id', (co->>'DatabaseId')::integer,
            // 'need-group', TRUE,
            // 'daily', d

            html += buildRow(mergedArray, idx);
        });

        // add rows
        $('#table-config-params tbody').append(html);
        // initialize tooltip plugin
        $('#table-config-params [data-toggle="tooltip"]').tooltip();
    }

    /**
     * Function that "merges" 2 arrays
     *
     * @param {array} a: array of parameters from station configuration
     * @param {array} b: array of parameters linked to station and retrived from db
     *
     * @return {array} res: final array with parameters correctly sorted and partitioned in two columns
     */
    function mergeArrays(a,b){

        console.log('mergeArrays');
        console.dir(a);

        // remove from a the DatabaseIDs that exist in array b
        var reduced = a.filter(function(aitem) {
            return !b.find(function(bitem) {
                return aitem.id === bitem.id;
            });
        });

        console.dir(a);
        console.dir(reduced);

        // create a new array of objects with the totality of DatabaseIDs without duplications
        var totalIds = reduced.concat(b);
        // sort the new array per DatabaseID
        totalIds.sort(function(a,b){
            return a.id - b.id;
        });

        // create new object with left and right attributes in order to
        // reproduce the html structure
        var res = {
            left: [],
            right: []
        };

        // loop through all DatabaseIDs
        // for each ID check if it exists in both arrays a and b
        // push the element in the correct "column" or push undefined if it does not exist
        totalIds.forEach(function(el){

            res.left[el.id] = a.find(function(aitem) {
                        return aitem.id === el.id;
                    });

            res.right[el.id] = b.find(function(bitem) {
                        return bitem.id === el.id;
                    });
        });

        // return final result
        return res;
    }

    /**
     * Function that builds table row based on left and right parameter
     *
     * @param {array} arr: total array returned by mergeArrays() function
     * @param {numeric} idx: index of element to be processed
     *
     * @return {text} html: table row
     */
    function buildRow(arr, idx){
        // if both left and right parameters are null then return empty string
        if(!arr.left[idx] && !arr.right[idx])
            return '';

        // variable for dinamically building the html
        var html = '';
        // get left and right parameters
        var left = arr.left[idx];
        var right = arr.right[idx];

        // different cases based on parameter ID value
        // - left OR right parameter is null
        // - left AND right parameters are defined and parameter IDs are equal
        // - left AND right parameters are defined and parameter IDs are NOT equal
        if(!left || !right){

            // new parameter in configuration and which can be added to the station
            if(left){
                let rowClass = (left.prid == 0 ? 'warning-row text-primary font-bold' : 'text-success');
                let rowIcon  = (left.prid == 0 ? '<i class="fa-solid fa-circle-question"></i> ' : '');
                let rowTooltip = (left.prid == 0 ? left.module_name+'<br><strong>Parametro da mappare MANUALMENTE</strong>': left.module_name);

                html += '<tr class="'+rowClass+' to-right" data-module="'+left.module+'" data-id="'+left.id+'">'
                html += '    <td>'+left.id+'</td>';
                html += '    <td>'+left.prid+'</td>';
                html += '    <td>'+left.module+'</td>';
                html += '    <td><span class="c-help" data-toggle="tooltip" data-html="true" data-original-title="'+rowTooltip+'">'+rowIcon+left.name+(left.note ? ' - '+left.note : '')+'</span></td>';
                html += '    <td class="">'+left.unit+'</td>';
                html += '    <td class="grey-cell text-center"><button type="button" class="btn btn-sm btn-success btn-params add-param" data-toggle="tooltip" data-original-title="Inserisci nella configurazione"><i class="fa-regular fa-greater-than"></i></button></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '</tr>';
            }
            // parameter no longer present in the configuration and which can be disabled
            else{
                // different style based on whether right parameter is active or not
                var classActive = 'text-danger';
                var buttonActive = '<button type="button" class="btn btn-sm btn-danger btn-params del-param" data-toggle="tooltip" data-original-title="Disattiva dalla configurazione"><i class="fa-regular fa-xmark-large"></i></button>';
                if(! right.active ){
                    classActive = 'not-active';
                    buttonActive = '<span class="btn btn-sm btn-secondary btn-params"><i class="fa-solid fa-trash-xmark"></i></span>';
                }

                html += '<tr data-stprid="'+right.stprid+'">';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td></td>';
                html += '    <td class=""></td>';
                html += '    <td class="grey-cell text-center">'+buttonActive+'</td>';
                html += '    <td class="'+classActive+'">'+right.id+'</td>';
                html += '    <td class="'+classActive+'">'+right.prid+'</td>';
                html += '    <td class="'+classActive+'">'+right.module+'</td>';
                html += '    <td class="'+classActive+'">'+right.name+'</td>';
                html += '    <td class="'+classActive+'">'+right.unit+'</td>';
                html += '</tr>';
            }

        }
        // left and right parameters are equal
        // nothing can be done in this section
        else if(left.prid == right.prid){
            // different style based on whether right parameter is active or not
            var classActive = '';
            var buttonActive = '<span class="btn btn-sm btn-secondary btn-params"><i class="fa-regular fa-equals"></i></span>';
            if(! right.active ){
                classActive = 'not-active';
                buttonActive = '<span class="btn btn-sm btn-secondary btn-params"><i class="fa-solid fa-trash-xmark"></i></span>';
            }

            let rowClass = (left.prid == 0 ? 'warning-row text-primary font-bold' : '');
            let rowIcon  = (left.prid == 0 ? '<i class="fa-solid fa-circle-question"></i> ' : '');
            let rowTooltip = (left.prid == 0 ? left.module_name+'<br><strong>Parametro da mappare MANUALMENTE</strong>': left.module_name);

            html += '<tr class="'+rowClass+'" data-module="'+left.module+'" data-groupid="'+right.module+'">';
            html += '    <td>'+left.id+'</td>';
            html += '    <td>'+left.prid+'</td>';
            html += '    <td>'+left.module+'</td>';
            html += '    <td><span class="c-help" data-toggle="tooltip" data-html="true" data-original-title="'+rowTooltip+'">'+rowIcon+left.name+(left.note ? ' - '+left.note : '')+'</span></td>';
            html += '    <td class="">'+left.unit+'</td>';
            html += '    <td class="grey-cell text-center">'+buttonActive+'</td>';
            html += '    <td class="'+classActive+'">'+right.id+'</td>';
            html += '    <td class="'+classActive+'">'+right.prid+'</td>';
            html += '    <td class="'+classActive+'">'+right.module+'</td>';
            html += '    <td class="'+classActive+'"><span class="c-help" data-toggle="tooltip" data-html="true" data-original-title="'+rowTooltip+'">'+rowIcon+right.name+'</td>';
            html += '    <td class="'+classActive+'">'+right.unit+'</td>';
            html += '</tr>';
        }
        // left and right parameters are NOT equal
        // nothing can be done in this section, but row is highligthed
        else if(left.prid != right.prid){
            html += '<tr class="text-primary font-bold">';
            html += '    <td>'+left.id+'</td>';
            html += '    <td>'+left.prid+'</td>';
            html += '    <td>'+left.module+'</td>';
            html += '    <td><span class="c-help" data-toggle="tooltip" data-original-title="'+left.module_name+'">'+left.name+(left.note ? ' - '+left.note : '')+'</span></td>';
            html += '    <td class="">'+left.unit+'</td>';
            html += '    <td class="grey-cell text-center"><span class="btn btn-sm btn-secondary btn-params" data-toggle="tooltip" data-original-title="Modifica il file di configurazione o richiedi assistenza all\'amministratore del sistema"><i class="text-primary fa-solid fa-triangle-exclamation"></i></span></td>';
            html += '    <td>'+right.id+'</td>';
            html += '    <td>'+right.prid+'</td>';
            html += '    <td>'+right.module+'</td>';
            html += '    <td>'+right.name+'</td>';
            html += '    <td class="">'+right.unit+'</td>';
            html += '</tr>';
        }

        // return row
        return html;
    }
});
