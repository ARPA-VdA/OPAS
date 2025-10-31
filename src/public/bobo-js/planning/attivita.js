/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var mySwitch;
    var mySwitchActive;

    var dateFrom, dateTo;

    var badges = [
        'badge-default',
        'badge-success',
        'badge-info',
        'badge-danger',
        'badge-primary',
        'badge-warning'
    ];

    $('.hide-el').hide();

    // variable for loadTickets function
    dateTo = moment().add(7, 'day').format('YYYY-MM-DD 23:59:59');
    dateFrom = moment().format('YYYY-MM-DD 00:00');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Oggi': [moment(), moment()],
            'Prossimi 7 giorni': [moment(), moment().add(7, 'days')],
            'Prossimo mese': [moment(), moment().add(1, 'month')],
            'Prossimi 2 mesi': [moment(), moment().add(2, 'months')],
            'Prossimi 6 mesi': [moment(), moment().add(6, 'months')],
            'Prossimo anno': [moment(), moment().add(1, 'year')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, update global variables
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // get tickets within new daterange
        // also considering the selected company, province and station
        var comp = parseInt($('#companies').val());
        var prid = parseInt($('#provinces').val());
        var stid = parseInt($('#stations').val());

        loadTickets(comp, prid, stid);

    });

    // datatable
    table = $('#activities-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "responsive": {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [ {
            className: 'control',
            orderable: false,
            targets:   -1
        } ],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        "ordering": false
    });
    // ajust columns width in base of page size
    table.columns.adjust().draw();

    // new ticket insertion datetime
    $('#newtic-insdate').bootstrapMaterialDatePicker({
        minDate: moment(),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    });
    // set value to now
    $('#newtic-insdate').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

    // new ticket expiration datetime
    $('#newtic-expdate').bootstrapMaterialDatePicker({
        minDate: moment(),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    });

    // repeat ticket end date
    $('#newtic-repeat-dateto').bootstrapMaterialDatePicker({
        minDate: moment(),
        time: false,
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla'
    });
    // initialize select 2
    $("#provinces, #newtic-prov").select2();
    $("#stations, #newtic-station, #newtic-email").select2({
        matcher: searchGroupedSelect2
    });

    $('#companies').on('change', function(e){
        var comp = parseInt( $(this).val() );
        var prid = parseInt($('#provinces').val());
        var stid = parseInt($('#stations').val());

        // get tickets by company
        // also considering the selected daterange
        loadTickets(comp, prid, stid);
    });


    $( "#provinces" ).on( "change", function() {

        var prid = parseInt($(this).val());
        var dest = $(this).data('dest');

        var comp = parseInt($('#companies').val());

        loadStations(prid, dest);
        loadTickets(comp, prid, -1);
    });

    $( "#stations" ).on( "change", function() {

        var stid = parseInt($(this).val());

        var comp = parseInt($('#companies').val());
        var prid = parseInt($('#provinces').val());

        loadTickets(comp, prid, stid);
    });

    mySwitchActive = new Switchery($("#hide-closed")[0], $("#hide-closed").data());
    $('#hide-closed').on('change', function(){

        console.log('switch change');
        var comp = parseInt($('#companies').val());
        var prid = parseInt($('#provinces').val());
        var stid = parseInt($('#stations').val());

        loadTickets(comp, prid, stid);
    });


    //!! TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    { 
        /**
         * Retreive ticket detail.
         */
        $('#activities-table').on('click', '.show-ticket', function(e){
            e.preventDefault();
            console.log("Visualizza");

            // get ticket id stored in tr
            var tkid = parseFloat($(this).parent().parent().data("id"));

            // check if the ticket's detail is already open
            if( $('#tk'+tkid).length ) {
                console.log('The report\'s detail is already open');
                $('.customtab a[href="#tk' + tkid + '"]').tab('show');
                return;
            }

            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();
            // get ticket detail via ajax call
            var jqxhr = $.ajax({
                url: '/plan_attivita_get_selected_ticket',
                type: "post",
                dataType: "json",
                data: {
                    id: tkid
                },
            })
            .done(function(result) {
                // check result
                // if OK then create ticket detail and add a new tab
                // else do nothing
                if(result.res == 'OK'){
                    var ticket = result.ticket;
                    console.dir(ticket);

                    var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#tk'+tkid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+ticket.tk_title+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-ticket" data-close="tk'+tkid+'"></i></a></li>';
                    $('.nav').append(html);

                    // create ticket detail
                    // the function returns html content to be appended into the tab
                    html = createTicketDetail(tkid, ticket);

                    $('.tab-content').append(html);
                    // show ticket detail tab
                    $('.customtab a[href="#tk'+ tkid +'"]').tab('show');

                }

                // at the end of the process hide preloader
                $('.inner-preloader').hide();

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio del ticket", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });
        });
 
        /**
         * Close ticket.
         */
        $('#activities-table').on('click', '.unlocked-ticket', function(e){
            console.log("Ticket APERTO");
            // NO preventDefault() otherwise the modal does not appear

            // get ticket id stored in tr
            var tkid = $(this).parent().parent().data('id');

            // retrieve maintenances that can be associated to ticket closure
            // maintenances must be:
            // - after the opening of the ticket
            // - done by the same company receiving the ticket
            loadMaintenances(tkid);

            // format modal for closure case
            $('#ticket-comment .modal-title').html('<i class="icon-speech"></i> <strong>Chiusura</strong> del ticket');
            $('#changestatus-maintenance').parent().parent().show();
            $('#confirm-opentic').hide();
            $('#confirm-closetic').show();

            $('#changestatus-id').val(tkid);
            $('#changestatus-status').val('closed');
        });
 
        /**
         * Re-open ticket.
         */
        $('#activities-table').on('click', '.locked-ticket', function(e){
            console.log("Ticket CHIUSO");
            // NO preventDefault() otherwise the modal does not appear

            // get ticket id stored in tr
            var tkid = $(this).parent().parent().data('id');

            // format modal for opening case
            $('#ticket-comment .modal-title').html('<i class="icon-speech"></i> Riapertura del ticket');
            $('#changestatus-maintenance').parent().parent().hide();
            $('#confirm-closetic').hide();
            $('#confirm-opentic').show();

            $('#changestatus-id').val(tkid);
            $('#changestatus-status').val('rejected');
        });
 
        /**
         * Edit ticket.
         */
        $('#activities-table').on('click', '.edit-ticket', function(e){
            e.preventDefault();
            console.log("Modifica");

            // reset form to the original status
            clearMainForm();

            // get ticket id stored in tr
            var tkid = parseFloat($(this).parent().parent().data("id"));

            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();
            // get ticket detail via ajax call
            var jqxhr = $.ajax({
                url: '/plan_attivita_get_selected_ticket',
                type: "post",
                dataType: "json",
                data: {
                    id: tkid
                },
            })
            .done(function(result) {

                // check result
                if(result.res == 'OK'){
                    // if it's OK then compile fields of the form with metadata arriving from database
                    var ticket = result.ticket;
                    console.dir(ticket);

                    // change form text for the update case
                    $("#inner-new-report").text('Modifica');
                    $("#new .box-title").text('Modifica ticket');
                    $("#confirm-newtic-form").html(' <i class="ti-save"></i> Modifica ticket');

                    $('#clear-newtic-form').hide();

                    // Hidden
                    $("#newtic-id" ).val(tkid);

                    // GENERALI
                    $("#newtic-type").val(ticket.tt_id).trigger('change');
                    $("#newtic-category").val(ticket.tc_id);
                    $("#newtic-urgency").val(ticket.tu_id);
                    $("#newtic-insdate").val(ticket.tk_opening_date_formatted);
                    $("#newtic-expdate").val(ticket.tk_expiry_date_formatted);

                    // SPECIFICHE DEL TICKET
                    $("#newtic-prov" ).val(ticket.province_id).trigger('change.select2');
                    $("#newtic-station").val(ticket.station_id).trigger('change.select2'); // does not trigger main "change" event

                    // retrieve equipments associated to the ticket station
                    // by passing equipment_id argument, the "newtic-equipment" field will be programatically setted
                    loadEquipments(ticket.station_id, ticket.equipment_id);

                    $("#newtic-assigned").val(ticket.tk_recipient_comp_fk);
                    $("#newtic-repeat").val(ticket.tf_id).trigger('change');

                    $("#newtic-title").val(ticket.tk_title);
                    $("#newtic-body").val(ticket.tk_opening_note);

                    // disable fields that cannot be changed
                    $("#newtic-prov" ).prop('disabled', true);
                    $("#newtic-station").prop('disabled', true);
                    $("#newtic-equipment").prop('disabled', true);
                    $("#newtic-assigned").prop('disabled', true);
                    $("#newtic-repeat").prop('disabled', true);
                    $("#newtic-repeat-dateto").prop('disabled', true);

                    $("#newtic-email").val(ticket.ml_ids).trigger('change');

                    // show "new" tab
                    $('.customtab a[href="#new"]').tab('show');
                }

                // at the end of the process hide preloader
                $('.inner-preloader').hide();

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio del ticket", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });
        });
 
        /**
         * Delete ticket.
         */
        $('#activities-table').on('click', '.delete-ticket', function(e){
            console.log("Elimina");

            e.preventDefault();

            // get ticket id and type stored in tr
            var tkid = parseInt($(this).parent().parent().data('id'));
            var type = parseInt($(this).parent().parent().data('type'));

            // show confirm message
            swal({
                title: "Stai per eliminare il ticket",
                text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
                type: "warning",
                showCancelButton: true,
                confirmButtonText: "Si, elimina",
                closeOnConfirm: false,
                cancelButtonText: "Annulla"
            }, function () {

                var flagAll = false;
                // if ticket type is "Programmato"
                // then ask to user if want delete all successive tickets
                if(type == 2){ // Programmato
                    swal({
                        title: "Ticket programmato",
                        text: "Eliminare anche i ticket successivi?",
                        type: "warning",
                        showCancelButton: true,
                        confirmButtonText: "Si, elimina",
                        closeOnConfirm: false,
                        cancelButtonText: "No, solo questo",
                        closeOnCancel: false
                    }, function (isConfirm) {
                        if(isConfirm)
                            flagAll = true;
                        // delete ticket by id
                        deleteTicket(tkid, flagAll);
                    });
                }
                else{
                    // delete ticket by id
                    deleteTicket(tkid, flagAll);
                }

            });
        });
    }
    /////////////////////////////////////////////////////////////////////
    //!! END TABLE FUNCTIONS


    //!! EVENTS IN "NEW" TAB
    /////////////////////////////////////////////////////////////////////
    {
        /**
         * Ticket type selection.
         */
        $( "#newtic-type" ).on( "change", function() {
            var id = $(this).val();
            $('.hide-el').show('slow');

            // based on the selected ticket type
            // change datepicker label and value
            switch(parseInt(id)){
                case 1: // Correttivo
                    $('.mod-label').text("Apertura il");
                    $('#newtic-insdate').prop('disabled', true);

                    // Add 3 WORKING days (holydays excluded) to opening day
                    // in order to obtain the expiration date
                    var ins_date = moment();
                    var counter;
                    for(counter=3; counter>0; counter--){
                        // isHoliday is a moment() function
                        if( ins_date.add(1, 'days').isHoliday() ){
                            while( ins_date.add(1, 'days').isHoliday() ){

                            };
                        }
                    }
                    $('#newtic-expdate').val( ins_date.format('DD/MM/YYYY HH:mm'));
                    $('.hide-exp').show('slow');
                    break;
                case 2: // Programmato
                    $('.mod-label').text("Inserito il");
                    $('#newtic-insdate').prop('disabled', true);

                    $('#newtic-expdate').val( moment().format('DD/MM/YYYY HH:mm'));
                    $('.hide-exp').show('slow');
                    break;
                case 3: // Evolutivo
                    $('.mod-label').text("Da eseguire il");
                    $('#newtic-insdate').prop('disabled', false);

                    $('#newtic-expdate').val( moment().format('DD/MM/YYYY HH:mm'));
                    $('.hide-exp').show('slow');
                    break;
                case 4: // Generale
                    $('.mod-label').text("Inserito il");
                    $('#newtic-insdate').prop('disabled', true);

                    $('.hide-exp').hide('slow');
                    break;
                default:
                    break;
            };
        });

        /**
         * Ticket province selection.
         */
        $( "#newtic-prov" ).on( "change", function() {
            var prid = $(this).val();
            var dest = $(this).data('dest');
            // load stations by province
            loadStations(prid, dest);
        });

        $( "#newtic-prov" ).trigger('change');

        /**
         * Ticket station selection.
         */
        $( "#newtic-station" ).on( "change", function() {
            var stid = $(this).val();
            // load equipments by stations
            loadEquipments(stid);
        });

        /**
         * Ticket equipment selection.
         */
        $("#newtic-equipment").on( "change", function() {
            var type = $(this).find('option:selected').data('type');
            // save in a different field what kind of equipment has been selected
            $('#newtic-objtype').val(type);
        });

        /**
         * Ticket assignement selection.
         */
        $("#newtic-assigned").on("change", function() {
            var comp = $(this).val();

            // check selected value
            if(comp == -1){
                // reset mailing list selection
                $('#newtic-email').val([]).trigger('change');
            }
            else{
                // if not equal of -1
                // then retrieve mailing lists eventually associated to the selected company
                var optsArray = [];
                $('#newtic-email').find("option[data-comp='" + comp + "']").each(function(idx, el){
                    optsArray.push(parseInt($(el).val()));
                });
                // select all found mailing list linked to company
                $('#newtic-email').val(optsArray).trigger('change');
            }
        });

        /**
         * Ticket repeat selection.
         */
        $( "#newtic-repeat" ).on( "change", function() {
            var id = $(this).val();

            // if "Solo una volta" no repetition needed
            // then disable field
            if(id == 0){
                $('#newtic-repeat-dateto').val('').trigger('change');
                $('#newtic-repeat-dateto').prop('disabled', true);
            }
            else{
                // else enable field and force ticket type to "Programmato"
                $('#newtic-repeat-dateto').prop('disabled', false);
                $('#newtic-repeat-dateto').bootstrapMaterialDatePicker('setDate', moment().format('31/12/YYYY'));
                $('#newtic-type').val(2).trigger('change');
            }
        });

        /**
         * Ticket mailing list selection.
         */
        $('#newtic-email').on('change', function(e){
            // reset element
            $('#ml-details').empty();

            // for each selected option show linked metadata
            $(this).find('option:selected').each(function(idx, el){
            // get metadata (name and description) of selected mailing lists and show them
                var name = $(el).text();
                var desc = $(el).data('desc');

                // build a li element and append it to main container
                var html = '<li><strong>'+name+':</strong> '+desc+'</li>';
                $('#ml-details').append(html);
            });
        });

        /**
         * Validate form.
         */
        var validator = $('#newtic-form').validate({ // initialize the plugin
            rules: {
                "newtic-type":{
                    required: true,
                    min: 0
                },
                "newtic-urgency":{
                    required: true,
                    min: 0
                },
                "newtic-insdate" : {
                    required: true
                },
                "newtic-expdate" : {
                    required: function(){
                        return parseInt($('#newtic-type').val()) != 4;
                    }
                },
                "newtic-station":{
                    required: true,
                    min: 0
                },
                "newtic-assigned":{
                    required: true,
                    min: 0
                },
                "newtic-category":{
                    required: true,
                    min: 0
                },
                "newtic-repeat":{
                    required: true,
                    min: 0
                },
                "newtic-repeat-dateto":{
                    required: function(){
                        return parseInt($("#newtic-repeat").val()) > 1;
                    }
                },
                "newtic-title" : {
                    required: true
                },
                "newtic-body" : {
                    required: true
                },
            },
            messages: {
                "newtic-type":{
                    required: "Selezionare tipo",
                    min: "Selezionare tipo"
                },
                "newtic-urgency":{
                    required: "Selezionare livello di urgenza",
                    min: "Selezionare livello di urgenza"
                },
                "newtic-insdate" : {
                    required: "Data inserimento obbligatoria"
                },
                "newtic-expdate" : {
                    required: "Data scadenza obbligatoria"
                },
                "newtic-station":{
                    required: "Selezionare stazione",
                    min: "Selezionare stazione"
                },
                "newtic-assigned":{
                    required: "Selezionare società",
                    min: "Selezionare società"
                },
                "newtic-category":{
                    required: "Selezionare stazione",
                    min: "Selezionare stazione"
                },
                "newtic-repeat":{
                    required: "Selezionare ripetizione",
                    min: "Selezionare ripetizione"
                },
                "newtic-title" : {
                    required: "Inserisci titolo ticket"
                },
                "newtic-body" : {
                    required: "Inserisci testo ticket"
                },
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
         * Submit ticket form.
         */
        $('#newtic-form').on('submit', function (e) {
            e.preventDefault();

            // check if the form is valid
            if (! $(this).valid() ){
                swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare report", "info");
                return false;
            };

            var form = $("#newtic-form");
            var msg_err = 'Si è verificato un errore durante il salvataggio del ticket';
            var msg_ok  = 'Il ticket è stato salvato correttamente';

            // ajax call
            $.ajax({
                type: 'post',
                url: '/plan_attivita_put_ticket',
                data: form.serialize()
            }).done(function(result) {
                // check result
                //  - if true then success, reload the list in the first tab
                //  - if false then error message
                if(result){
                    swal("Successo", msg_ok, "success");

                    var comp = parseInt($('#companies').val());
                    var prid = parseInt($('#provinces').val());
                    var stid = parseInt($('#stations').val());

                    loadTickets(comp, prid, stid);
                }
                else{
                    swal("Errore!", msg_err, "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", msg_err, "error");

            });
        });

        /**
         * Clear main form's fields.
         */
        $('#newtic-form').on('click', '#clear-newtic-form', function(e){
            e.preventDefault();

            console.log("clear main form");
            clearMainForm();
        });

        /**
         * Go back to tickets datatable.
         */
        $('#newtic-form').on('click', '#cancel-newtic-form', function(e){
            e.preventDefault();

            clearMainForm();
            // show firt tab
            $('.customtab a[href="#task-list"]').tab('show');
        });
    }
    /////////////////////////////////////////////////////////////////////
    //!! EVENTS IN "NEW" TAB


    //!! EVENTS IN TICKET DETAIL
    /////////////////////////////////////////////////////////////////////
    {
        /**
         * Close the ticket detail.
         */
        $('.card-body').on('click', '.close-ticket', function(e){
            e.preventDefault();

            var close = $(this).data("close");
            console.log(close);
            // close ticket detail tabl and show first tab
            setTimeout(function(){
                $('.customtab a[href="#' + close + '"]').remove();
                $('.tab-content #'+close).remove();
                $('.customtab a[href="#task-list"]').tab('show');

            }, 1);
        });

        /**
         * Take charge of ticket.
         */
        $('.card-body').on('click', '.confirm-takechargetic', function(e){
            e.preventDefault();

            // get ticket id and type stored in button element
            var tkid = parseInt($(this).data('id'));
            var type = parseInt($(this).data('type'));
            var form = $('#takechargetic-form-'+tkid).serializeArray();

            // check ticket type
            if(type == 1){ // Correttivo
                // show confirm message
                swal({
                    title: "Ticket correttivo",
                    text: "Alla presa in carico verrà aggiornata la data di scadenza del ticket. Confermi l'operazione?",
                    type: "warning",
                    showCancelButton: true,
                    confirmButtonText: "Si, confermo",
                    closeOnConfirm: false,
                    cancelButtonText: "Annulla"
                }, function (isConfirm) {

                    if(isConfirm){
                        // update expiration date
                        var formatted_date= moment();
                        var new_exp_date = moment();
                        var counter;

                        // Add 2 WORKING days (holydays excluded) from now
                        // in order to obtain the new expiration date
                        for(counter=2; counter>0; counter--){
                            if( new_exp_date.add(1, 'days').isHoliday() ){
                                console.log(new_exp_date.isHoliday());
                                while( new_exp_date.add(1, 'days').isHoliday() ){
                                    console.log(new_exp_date.isHoliday());
                                };
                            }
                        }

                        // add new field to the form and sent it to database
                        form.push({ name: "changestatus-expdate", value: new_exp_date.format('DD/MM/YYYY HH:mm') });
                        changeTicketStatus( tkid, form );
                    }
                });
            }
            else{
                // sent form to database
                changeTicketStatus( tkid, form );
            }
        });

        /**
         * Cancel take charge of ticket.
         */
        $('.card-body').on('click', '.cancel-takechargetic', function(e){
            e.preventDefault();

            $('.changestatus-note').val('');
        });

        /**
         * Change ticket status.
         */
        $('.card-body').on('click', '.change-status', function(e){
            // NO preventDefault() otherwise the modal does not appear

            // get ticket id and action type stored in the button element
            var tkid = $(this).data('id');
            var action = $(this).data('action');

            // close ticket
            if(action == 'closed'){
                // retrieve maintenances that can be associated to ticket closure
                // maintenances must be:
                // - after the opening of the ticket
                // - done by the same company receiving the ticket
                loadMaintenances(tkid);

                // format modal for closure case
                $('#ticket-comment .modal-title').html('<i class="icon-speech"></i> Chiusura del ticket');
                $('#changestatus-maintenance').parent().parent().show();
                $('#confirm-opentic').hide();
                $('#confirm-closetic').show();
            }
            else{
                // format modal for opening case
                $('#ticket-comment .modal-title').html('<i class="icon-speech"></i> Riapertura del ticket');
                $('#changestatus-maintenance').parent().parent().hide();
                $('#confirm-closetic').hide();
                $('#confirm-opentic').show();
            }

            // save ticket id and action type in 2 different fields int the modal form
            $('#changestatus-id').val(tkid);
            $('#changestatus-status').val(action);
        });
    }
    /////////////////////////////////////////////////////////////////////
    //!! END EVENTS IN TICKET DETAIL

    /**
     * Change status of ticket.
     */
    $('.confirm-changestatus').on('click', function(e){
        e.preventDefault();

        var tkid = parseInt($('#changestatus-id').val());
        var form = $('#changestatus-form').serializeArray();

        // sent form to database
        changeTicketStatus( tkid, form );
    });

    /**
     * Reset form at the modal closure.
     */    
    $('#ticket-comment').on('hide.bs.modal', function(e){

        $('#changestatus-form input').val('');
        $('#changestatus-form select').val(-1);
        $('#changestatus-form textarea').val('');

    });

    /**
     * Retrieve tickets of selected company.
     */    
    $('#companies').trigger('change');



    //!! FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Function that clears and resets all main form's fields.
     * No args needed
     */
    function clearMainForm(){
        // Reset form texts
        $("#inner-new-report").text('Nuovo');
        $("#new .box-title").text('Inserisci nuovo ticket');
        $("#confirm-newtic-form").html(' <i class="ti-save"></i> Inserisci ticket');

        $('#clear-newtic-form').show();
        // manage input type text
        $('.clear-input').val("");
        // enable all inputs
        $('.clear-input').prop('disabled', false);
        // manage selects
        $('.clear-select').val(-1);
        // enable all selects
        $('.clear-select').prop('disabled', false);
        // trigger events in order to reset all dependent fields
        $('#newtic-assigned').trigger('change');
        $('#newtic-prov').val(-1).trigger('change');
        $('#newtic-insdate').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

        $('.hide-el').hide();
        // reset validate plugin
        $('#newtic-form').validate().resetForm();
    }

    /**
     * Function that returns row's class in the main table
     *
     * @param {text} status Ticket last status
     *
     * @return status class
     */
    function getRowClass(status){

        if(status == 'closed')
            return 'closed';
        else if (status == 'taken charge')
            return 'text-muted-sec';
        else
            return '';
    }

    /**
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     */
    function loadStations(prid, dest){

        // reset select
        $('#'+dest).empty();

        // get stations via ajax call
        var jqxhr = $.ajax({
            url: '/plan_attivita_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            if(result.res == 'OK'){

                var stations = result.stations;

                var opts = '';
                var net;
                // var stations_id = [];

                // build html for stations divided into option group
                // each group represent a different network
                $.each(stations, function(index, station){

                    if(net != station.station_network_type_id){

                        if(index != 0)
                            opts += '</optgroup>';

                        net = station.station_network_type_id;
                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                    }

                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });

                // append first default option and the created html to the select
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);
                $('#'+dest).append('</optgroup>');

                if(dest == 'newtic-station'){
                    // programatically select -1 and trigger event in order to reset equipments field
                    $('#newtic-station').val(-1).trigger('change');
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
    }

    /**
     * Function that retrieves the equipments of a given station.
     *
     * @param {integer} stid Station ID.
     * @param {integer} eqid Equipment ID; if provided, the function programatically set the field value.
     */
    function loadEquipments(stid, eqid){

        // reset fields
        $('#newtic-equipment').empty();
        $('#newtic-objtype').val('');

        // get equipments via ajax call
        // the resulting equipment is strictly dependent on the metadata
        // declared in other sections of the portal
        var jqxhr = $.ajax({
            url: '/plan_attivita_get_equipments',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                dt: moment().format('YYYY-MM-DD HH:mm')
            },
        })
        .done(function(result) {

            console.dir(result);
            // check results
            if(result.res == 'OK'){

                // append the first default options
                $('#newtic-equipment').append("<option value='-1'>Seleziona...</option>");
                // build equipment options divided in 3 different categories
                // - instruments
                // - tanks
                // - miscellanies
                var opts = '';
                if(result.instruments.length > 0){
                    $('#newtic-equipment').append("<optgroup label='Strumenti'>");
                    $.each(result.instruments, function(index, instrument){
                        var instrName = instrument.instrument_type_fullname;

                        if(instrument.instrument_name != '')
                            instrName += ' - '+instrument.instrument_name;

                        if(instrument.instrument_arpa_id != '')
                            instrName = instrName + ' ['+instrument.instrument_arpa_id+']';

                        opts += '<option value="instr-'+ instrument.instr_id+'" data-type="instr">'+instrName+'</option>';
                    });

                    $('#newtic-equipment').append(opts);
                    $('#newtic-equipment').append("</optgroup>");
                }

                var opts = '';
                if(result.tanks.length > 0){
                    $('#newtic-equipment').append("<optgroup label='Bombole'>");
                    $.each(result.tanks, function(index, tank) {

                        var tankName = tank.cylinder_fullname;
                        var expiryTxt = '';
                        if( moment().isSameOrAfter(tank.cylinder_expiry_date) ){
                            expiryTxt = ' scad. '+ tank.cylinder_expiry_date_format;
                        }

                        opts += '<option value="tank-'+tank.cy_id+'" data-type="tank">'+tankName+''+expiryTxt+'</option>';
                    });
                    $('#newtic-equipment').append(opts);
                    $('#newtic-equipment').append("</optgroup>");
                }

                var opts = '';
                if(result.miscellanies.length > 0){
                    $('#newtic-equipment').append("<optgroup label='Dotazioni'>");
                    $.each(result.miscellanies, function(index, miscellany) {
                        var miscName = miscellany.miscellany_fullname;

                        opts += '<option value="misc-'+miscellany.mi_id+'" data-type="misc">'+miscName+'</option>';
                    });
                    $('#newtic-equipment').append(opts);
                    $('#newtic-equipment').append("</optgroup>");
                }

                // check argument
                // if defined set "newtic-equipment" value
                if (eqid != null){
                    console.log('Modifica');
                    $("#newtic-equipment").val(eqid).trigger('change');
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            }


        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti", "error");
        });
    };

    /**
     * Function that retrieves the ticket list of a given company.
     *
     * @param {integer} company Company ID.
     * @param {integer} prid Province ID.
     * @param {integer} stid station ID.
     */
    function loadTickets(company, prid, stid){
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        if(table)
            table.clear();

        console.log('ajax');

        var flag = $('#hide-closed').is(':checked');

        var jqxhr = $.ajax({
            url: '/plan_attivita_get_tickets',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                comp: company,
                prov: prid,
                stid: stid,
                hide: flag
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is OK
            if(result.res == 'OK'){

                var tickets = result.tickets;
                // variable for dinamically building the table html
                var html = '';

                // SUMMARY of permissions
                // ------------------
                // VIEW:
                //      - ADMIN company sees all               | Only tickets associated with stations on
                //      - NON ADMIN company sees its tickets   | wich user has visibility
                // NEW:
                //      - Permissions on the page (recipients displayed depending on whether the comapny IS ADMIN or not)
                // CHANGE FIELDS (before taking charge) / DELETE:
                //      - Permissions on the page + ticket creator company
                //      - Permissions on the page + ADMIN company
                // CHANGE STATUS
                //      - Take in charge   -> only recipient company of the ticket;
                //      - Closing          -> creator and recipient of the ticket;
                //      - Reopening        -> ticket creator;

                // check if at least one element exists
                if(tickets.length > 0){
                    // loop through all elements
                    // for each ticket, build a html row to be added to the datable
                    $.each(tickets, function(index, ticket){

                        var userCanModify = false;

                        // if user comp is Admin or user comp is the same of ticket comp creator, user can modify or delete tickets still open
                        if( isCompAdmin == 1 || ticket.tk_opening_comp_fk == userComp)
                            userCanModify = true;

                        html += '<tr class="'+getRowClass(ticket.tk_status)+' "data-id="'+ticket.tk_id+'" data-type="'+ticket.tt_id+'">';
                        html += '    <td class="bobo-nowrap tkt-icons">';
                        html += '        <a href="javascript:void(0)" class="show-ticket" data-toggle="tooltip" data-original-title="Visualizza"> <i class="fa-light fa-magnifying-glass-arrow-right text-info"></i> </a>';
                        // if user has update grant and ticket has been at least taken in charge
                        if(update_grant && ticket.tk_status != null){
                            // if closed
                            if ( ticket.tk_status == 'closed' && userCanModify ){
                                html += '        <a href="javascript:void(0)" class="locked-ticket" data-toggle-second="tooltip" data-original-title="Ticket CHIUSO" data-target="#ticket-comment" data-toggle="modal"> <i class="fa-light fa-lock-keyhole text-success"></i> </a>';
                            }
                            else if( ticket.tk_status != 'closed' && (userCanModify || ticket.tk_recipient_comp_fk == userComp) ) {
                                html += '        <a href="javascript:void(0)" class="unlocked-ticket" data-toggle-second="tooltip" data-original-title="Ticket APERTO" data-target="#ticket-comment" data-toggle="modal"> <i class="fa-light fa-lock-keyhole-open text-primary"></i> </a>';
                            }
                        }

                        // if ticket is open and user can modify
                        if(ticket.tk_status == null && userCanModify){
                            html += '        <br>';
                            if(update_grant){
                                html += '        <a href="javascript:void(0)" class="edit-ticket" data-toggle="tooltip" data-original-title="Modifica"> <i class="fa-light fa-pencil text-info"></i> </a>';
                            }
                            if(delete_grant){
                                html += '        <a href="javascript:void(0)" class="delete-ticket" data-toggle="tooltip" data-original-title="Elimina"> <i class="fa-light fa-trash-can text-danger"></i> </a>';
                            }
                        }

                        html += '    </td>';
                        html += '    <td>'+ticket.tk_id+'</td>';
                        html +='    <td class="bobo-nowrap operators-company">';
                        html +='        <span>'+ticket.us_fullname+'<br><small>'+ticket.opening_comp_name+'</small></span>';
                        html +='    </td>';
                        html += '    <td>'+moment(ticket.tk_opening_date).format('DD/MM/YYYY<br>HH:mm')+'</td>';
                        if(ticket.tk_expiry_date == 'infinity')
                            html += '    <td>Assente</td>';
                        else
                            html += '    <td>'+moment(ticket.tk_expiry_date).format('DD/MM/YYYY<br>HH:mm')+'</td>';

                        html += '    <td><span class="badge badge-'+ticket.tu_colour+'">'+ticket.tu_desc+'</span></td>';
                        if(ticket.tk_status != null ){
                            // html += '    <td><i class="icon-check text-info"></i></td>';

                            switch(ticket.tk_status){
                                case 'taken charge':
                                    html += '    <td>Preso in carico</td>';
                                    break;
                                case 'closed':
                                    html += '    <td>Chiuso</td>';
                                    break;
                                case 'rejected':
                                    html += '    <td>Riaperto</td>';
                                    break;
                                default:
                                    break;
                            }
                        }
                        else{
                            html += '    <td>Aperto</td>';
                        }

                        var badge = badges[ ticket.tk_recipient_comp_fk % badges.length ];

                        html += '    <td class="font-bold">'+ticket.comp_name+'</td>';
                        html += '    <td>'+ticket.tt_desc+'</td>';
                        html += '    <td><span class="badge badge-type"><i class="'+ticket.tc_class+'"></i>&nbsp;'+ticket.tc_desc+'</span></td>';
                        html += '    <td>'+ticket.station_name+'</td>';
                        html += '    <td>'+ticket.equipment_name+'</td>';
                        html += '    <td class="font-bold">'+ticket.tk_title+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
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
                            .find('[data-toggle="tooltip"], [data-toggle-second="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    // redraw table
                    table.draw();
                }

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei ticket", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il recupero dei ticket", "error");
            $('.inner-preloader').hide();

        });
    }

    /**
     * Function that retrieves the maintenances associated to a given ticket.
     *
     * @param {integer} tkid Ticket ID.
     */
    function loadMaintenances(tkid){
        // reset select
        $('#changestatus-maintenance').empty();

        // retrieve maintenances via ajax call
        var jqxhr = $.ajax({
            url: '/plan_attivita_get_maintenances',
            type: "post",
            dataType: "json",
            data: {
                tkid: tkid
            },
        })
        .done(function(result) {

            console.dir(result);
            // check if result is OK
            if(result.res == 'OK'){

                // add first default option
                $('#changestatus-maintenance').append("<option value='-1'>Seleziona manutenzione...</option>");
                var opts = '';
                // check if at least one element exists
                if(result.reports.length > 0){
                    // for each report build an option element
                    $.each(result.reports, function(index, report){

                        var name = '['+report.maintenance_fulldate+'] Operatore: '+report.user_fullname;

                        if(report.maintenance_calib_flag == true)
                            name += ' (manutenzione con calibrazione)';

                        opts += '<option value="'+ report.ma_id+'">'+name+'</option>';
                    });

                    // append options to the select
                    $('#changestatus-maintenance').append(opts);
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle manutenzioni", "error");
            }


        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle manutenzioni", "error");
        });
    }

    /**
     * Function that builds the ticket detail.
     *
     * @param {integer} tkid Ticket ID.
     * @param {object}  ticket Ticket's data to visualize.
     */
    function createTicketDetail(tkid, ticket){

        // check if user can modify
        var userCanModify = false;
        if( isCompAdmin == 1 || ticket.tk_opening_comp_fk == userComp)
            userCanModify = true;

        var html = '';
        // build ticket detail
        html += '<div class="tab-pane p-20" id="tk'+tkid+'" role="tabpanel">';
        html += '    <div class="form-body panel-report-view panel-view-mobile">';
        html += '        <h4 class="box-title">Ticket del <strong>'+ticket.tk_opening_date_formatted+'</strong> con priorità: <strong>'+ticket.tu_desc.toUpperCase()+'</strong></h4>';
        html += '        <hr class="m-t-0 m-b-20">';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Aperto da</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.user_fullname+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Scade il</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.tk_expiry_date_formatted+'</div>';
        html += '        </div>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Tipo</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.tt_desc+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Categoria</label>';
        html += '            <div class="col-md-4 view-param ticket-cat"><span class="badge badge-type"><i class="'+ticket.tc_class+'"></i> '+ticket.tc_desc+'</span></div>';
        html += '        </div>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Provincia</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.province_name+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Stazione</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.station_name+'</div>';
        html += '        </div>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Strum. o dotaz.</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.equipment_name+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Assegnato a</label>';

        var badge = badges[ ticket.tk_recipient_comp_fk % badges.length ];

        html += '            <div class="col-md-4 view-param">'+ticket.comp_name+'</div>';
        html += '        </div>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Ripetizione</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.tf_desc+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Mailing lists</label>';
        html += '            <div class="col-md-4 view-param">'+ticket.mailing_lists.join(', ')+'</div>';
        html += '        </div>';
        html += '        <h5 class="divider-title m-t-20 m-b-20"><i class="ti-ruler-pencil"></i> Oggetto: <strong>'+ticket.tk_title+'</strong></h5>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-form-label">Descrizione</label>';
        html += '            <div class="col-md-10 view-param">';
        html += ticket.tk_opening_note;
        html += '            </div>';
        html += '        </div>';
        html += '        <h4 class="box-title m-t-25"><strong>Presa in carico</strong> del ticket</h4>';
        html += '        <hr class="m-t-0 m-b-20">';

        // Nobody took charge of it
        if( ticket.ticket_status == null){

            // if you are part of the company receiving the ticket, you can take charge of it
            if( ticket.tk_recipient_comp_fk == userComp ){
                html += '        <form class="form" id="takechargetic-form-'+tkid+'" name="takechargetic-form">';
                html += '            <input type="hidden" id="changestatus-id-'+tkid+'" name="changestatus-id" value="'+tkid+'">';
                html += '            <input type="hidden" id="changestatus-status-'+tkid+'" name="changestatus-status" value="taken charge">';
                html += '            <div class="form-group row">';
                html += '                <label for="changestatus-note" class="col-md-2 col-form-label">Note</label>';
                html += '                <div class="col-md-10">';
                html += '                    <textarea class="form-control clear-input changestatus-note" rows="6" id="changestatus-note-'+tkid+'" name="changestatus-note"></textarea>';
                html += '                </div>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <div class="col-sm-10 offset-md-2">';
                html += '                    <button type="submit" class="btn btn-info confirm-takechargetic" name="confirm-takechargetic" id="confirm-takechargetic-'+tkid+'" data-id="'+tkid+'" data-type="'+ticket.tt_id+'"> <i class="mdi mdi-comment-alert"></i> Prendi in carico</button>';
                html += '                    <button type="button" class="btn btn-inverse cancel-takechargetic" name="cancel-takechargetic" id="cancel-takechargetic-'+tkid+'">Annulla</button>';
                html += '                </div>';
                html += '            </div>';
                html += '        </form>';
            }
            else{ // otherwise show only a message
                html += '       <div class="form-group row">';
                html += '            <div class="col-sm-12">';
                html += '               <p><i class="icon-close text-danger"></i> Ticket non ancora preso in carico</p>';
                html += '            </div>';
                html += '       </div>';
            }

            html += '        <hr class="m-t-0 m-b-20">';
            html += '        <div class="form-group row">';
            html += '            <div class="col-md-12">';
            html += '                <button type="button" class="btn btn-inverse close-ticket" data-close="tk'+tkid+'"> <i class="icon-close"></i> Chiudi dettaglio</button>';
            html += '            </div>';
            html += '        </div>';
            html += '    </div>';
            html += '</div>';
        }
        else{ // It has been taken in charge

            var status = JSON.parse(ticket.ticket_status);
            console.dir(status);

            var word = 'Riaperto';
            // Loop over all ticket status steps
            $.each(status, function(idx, el){
                // Take in charge state
                if(idx == 0){
                    html += '       <div class="form-group row">';
                    html += '            <div class="col-sm-12">';
                    html += '               <p><i class="ti-check-box text-info"></i> Preso in carico da <strong>'+el.user_fullname+'</strong> il <strong>'+el.ts_fulldate_formatted+'</strong></p>';
                    html += '            </div>';
                    html += '            <label for="" class="control-label col-md-2 col-form-label">Note</label>';
                    html += '            <div class="col-md-10 view-param m-b-25">'+el.ts_note+'</div>';
                    html += '       </div>';


                    if(status.length > 1){
                        html += '        <h4 class="box-title"><strong>Stato</strong> del ticket</h4>';
                    }
                }
                else{ // Closure and Opening states

                    word = 'Chiuso';
                    css  = 'tkt-closed';
                    if(el.ts_status == 'rejected'){
                        word = 'Riaperto';
                        css  = 'tkt-reopened';
                    }

                    html += '    <div class="'+css+'">';
                    html += '        <img src="'+el.user_avatar_thumb+'" class="avatar" alt="avatar di '+el.user_fullname+'" />';
                    html += '        <div class="form-group row first-row">';
                    html += '            <label for="" class="control-label col-lg-2 col-form-label">'+word+' il</label>';
                    html += '            <div class="col-lg-10 view-param">'+el.ts_fulldate_formatted+' <strong>da</strong> '+el.user_fullname+'</div>';
                    html += '        </div>';

                    if(el.ts_status == 'closed'){
                        html += '        <div class="form-group row">';
                        html += '            <label for="" class="control-label col-lg-2 col-form-label">Manutenzione</label>';
                        if(el.ma_id == null)
                            html += '            <div class="col-lg-5 view-param">'+el.maintenance+'</div>';
                        else
                            html += '            <div class="col-lg-5 view-param"><a href="/rep_qa_manutenzioni/'+el.ma_id+'" target="_blank">'+el.maintenance+'</a></div>';
                        html += '        </div>';
                    }

                    html += '        <div class="form-group row">';
                    html += '            <label for="" class="control-label col-lg-2 col-form-label">Note</label>';
                    html += '            <div class="col-lg-10 view-param">'+el.ts_note+'</div>';
                    html += '        </div>';
                    html += '    </div>';

                }
            });

            // if the last state is reopened, propose a button to close it
            if(word == 'Riaperto'){
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <div class="form-group row">';
                html += '            <div class="col-md-12">';
                html += '                <button type="button" class="btn btn-inverse close-ticket" data-close="tk'+tkid+'"> <i class="icon-close"></i> Chiudi dettaglio</button>';
                html += '                <button type="submit" class="btn btn-info change-status" name="change-status" id="change-status-'+tkid+'" data-id="'+tkid+'" data-action="closed" data-target="#ticket-comment" data-toggle="modal"> <i class="icon-speech"></i> Chiudi ticket</button>';
                html += '            </div>';
                html += '        </div>';
            }
            else{ // otherwise propose a button to close it

                if(userCanModify){
                    html += '        <hr class="m-t-0 m-b-20">';
                    html += '        <div class="form-group row">';
                    html += '            <div class="col-md-12">';
                    html += '                <button type="button" class="btn btn-inverse close-ticket" data-close="tk'+tkid+'"> <i class="icon-close"></i> Chiudi dettaglio</button>';
                    html += '                <button type="submit" class="btn btn-danger change-status" name="change-status" id="change-status-'+tkid+'" data-id="'+tkid+'" data-action="rejected" data-target="#ticket-comment" data-toggle="modal"> <i class="icon-speech"></i> Riapri ticket</button>';
                    html += '            </div>';
                    html += '        </div>';
                }
            }

            html += '    </div>';
            html += '</div>';
        }

        return html;
    }

    /**
     * Function to update the ticket status.
     *
     * @param {integer} tkid Ticket ID.
     * @param {form}    form Ticket closure data.
     */
    function changeTicketStatus(tkid, form){
        var obj = {};
        $.each(form, function() {
            obj[this.name] = this.value;
        });

        // possible status 'taken charge', 'closed', 'rejected'
        // ajax call
        var jqxhr = $.ajax({
            url: '/plan_attivita_put_ticket_status',
            type: "post",
            dataType: "json",
            data: form
        })
        .done(function(result) {
            // check result if ok
            if(result == 1){
                swal("Successo", "Cambio di stato avvenuto correttamente", "success");

                var comp = parseInt($('#companies').val());
                var prid = parseInt($('#provinces').val());
                var stid = parseInt($('#stations').val());

                loadTickets(comp, prid, stid);

                // check chamge status type
                // if taken charge, reload ticket detail tab
                if(obj['changestatus-status'] == 'taken charge'){
                    $('.customtab a[href="#tk' + tkid + '"]').remove();
                    $('.tab-content #tk'+tkid).remove();
                    $('#activities-table tr[data-id='+tkid+'] .show-ticket').trigger('click');
                }
                else{
                    // else close modal and detail tab and show first tab
                    setTimeout(function(){
                        $('#ticket-comment').modal('hide');
                        $('.customtab a[href="#tk' + tkid + '"]').remove();
                        $('.tab-content #tk'+tkid).remove();
                        $('.customtab a[href="#task-list"]').tab('show');

                    }, 1);
                }

            }
            else if(result == -1)
                // warning message
                swal("Attenzione!", "Sono ancora presenti dei ticket precedenti da prendere in carico", "warning");
            else
                // error message
                swal("Errore!", "Errore durante il cambio di stato", "error");


        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il cambio di stato", "error");

        });
    }

    /**
     * Function to delete the ticket/tickets.
     *
     * @param {integer} tkid Ticket ID.
     * @param {boolean} flagAll Boolean value to choose if delete all tickets
     *                          or just the selected one.
     */
    function deleteTicket(tkid, flagAll){
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        var msg;
        // in case of ticket Programmato, different message to be shown if flagAll is true
        if(flagAll == true){
            msg = 'Eliminati tutti i ticket con successo';
        }
        else{
            msg = 'Ticket selezionato eliminato con successo';
        }
        // delete the selected report
        var jqxhr = $.ajax({
            url: '/plan_attivita_del_selected_ticket',
            type: "post",
            dataType: "json",
            data: {
                id: tkid,
                flag: flagAll
            }
        })
        .done(function(result) {
            if(result){

                swal("Ticket eliminato", msg, "success");
                var comp = parseInt($('#companies').val());
                var prid = parseInt($('#provinces').val());
                var stid = parseInt($('#stations').val());

                loadTickets(comp, prid, stid);
            }
            else{
                // error message
                swal({
                    title: "Errore!",
                    text: "Se si tratta del primo ticket è necessario <strong>eliminare anche tutti i successivi</strong>!",
                    type: "error",
                    html: true
                });
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante l\'eliminazione del ticket", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

});

