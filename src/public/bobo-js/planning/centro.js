/**
 * Document ready
 */
$(document).ready(function() {

    var mainDropzone;
    var dropzones = [];

    var user;
    var metadata;

    getMetadata();

    $('[data-toggle-second="tooltip"]').tooltip();

    // variable for loadTickets function
    dateFrom = moment().subtract(6, 'day').format('YYYY-MM-DD 00:00');
    dateTo = moment().format('YYYY-MM-DD 23:59:59');

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
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimi 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimi 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, update global variables
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        loadTickets(dateFrom, dateTo);
    });

    // boostraptoggle
    $( "#show-useful" ).bootstrapToggle();

    // datatable
    table = $('#activities-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "responsive": {
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
            { orderable: false, targets: 0 },
            { responsivePriority: 1, targets: [0,1,5,7] },
            { responsivePriority: 10, targets: [4,6,8] }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 3, "desc" ]],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        // "ordering": false
    });
    // ajust columns width in base of page size
    table.columns.adjust().draw();

    $('#status, #urgencies, #types, #show-useful').on('change', function(e){
        e.preventDefault();

        loadTickets(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive ticket detail.
     */
    $('#activities-table').on('click', '.show-ticket', function(e){
        e.preventDefault();
        console.log("Visualizza e/o modifica stato");

        // get ticket id stored in tr
        var tkid = parseInt($(this).parent().parent().data("id"));

        // check if the ticket's detail is already open
        if( $('#tk'+tkid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#tk' + tkid + '"]').tab('show');
            return;
        }

        loadTicketDetail(tkid);
    });

    /**
     * Copy ticket link 
     */
    $('#activities-table').on('click', '.share-ticket', function(e){
        e.preventDefault();
        console.log("Condividi ticket copiando il link");

        // get ticket id stored in tr
        var tkid = parseInt($(this).parent().parent().data("id"));

        // create a temporary input
        var $temp = $("<input>");
        // append it to document body
        $("body").append($temp);
        // set the input value with the text of the element to be copied
        $temp.val('https://opas.isprambiente.it/plan_centro/'+tkid).select();
        // execute system command "copy"
        document.execCommand("copy");
        // remove temporary input
        $temp.remove();

        // show success message
        $.toast({
            heading: 'Info',
            text: 'Link copiato',
            position: 'top-right',
            loaderBg:'#ff6849',
            icon: 'info',
            hideAfter: 3000,
            stack: 6
        });
    });

    /**
     * Edit report.
     */
    $('#activities-table').on('click', '.edit-ticket', function(e){
        e.preventDefault();
        console.log("Modifica");

        // get ticket id stored in tr
        var tkid = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // get ticket detail via ajax call
        var jqxhr = $.ajax({
            url: '/plan_centro_get_selected_ticket',
            type: "post",
            dataType: "json",
            data: {
                id: tkid
            },
        })
        .done(function(result) {
            // check result
            // if OK then fill ticket form and show the "new" tab
            // else do nothing
            if(result.res == 'OK'){
                var ticket      = result.ticket;
                var statusArray = result.status_list;

                // get first status "open" in the array
                var firstStatus = statusArray[0];

                $('#newtic-id').val(tkid);
                $('#newtic-type').val(firstStatus.ctt_id);
                $('#newtic-urgency').val(firstStatus.ctu_id);
                $('#newtic-assigned').val(firstStatus.gr_id);
                $('#newtic-title').val(ticket.ct_title);
                // manage summernote
                $('#newtic-body').summernote('code', ticket.ct_description);

                // check if report has attachments
                //  - if true then add attachemnts to the report's detail page
                if(firstStatus.attachments){
                    var htmlImages = '';

                    var attachments = JSON.parse(firstStatus.attachments);
                    // loop through attachments
                    // different items depending on the file type
                    $.each(attachments, function(idx, attachment){
                        // check if current looped attachment is an image
                        if(attachment.file_image == true){
                            // image files
                            htmlImages +='    <div class="del-my-img">\n';
                            htmlImages +='      <span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span><a href="/uploads/planning/centro/'+attachment.file_archive+'" class="clearfix thumb-gallery"><img src="/uploads/planning/centro/'+attachment.file_archive+'"></a>\n';
                            htmlImages +='    </div>\n';
                        }
                    });

                    // append files
                    $('#img-container').append(htmlImages);

                    // image gallery
                    refreshGalleryBig();
                }

                // modify 'Nuovo' text in 'Modifica'
                $('#inner-new-report').text('Modifica');
                $('#new .box-title').html('Modifica TICKET');
                $('#confirm-newtic-form').html(' <i class="ti-save"></i> Modifica ticket');

                // show ticket form tab
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
     * Delete report.
     */
    $('#activities-table').on('click', '.delete-ticket', function(e){
        e.preventDefault();

        // get ticket id and type stored in tr
        var tkid = parseInt($(this).parent().parent().data('id'));

        // show confirm message
        swal({
            title: "Stai per eliminare il ticket",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {

            // delete the selected report
            var jqxhr = $.ajax({
                url: '/plan_centro_del_selected_ticket',
                type: "post",
                dataType: "json",
                data: {
                    id: tkid
                }
            })
            .done(function(result) {
                // check result
                //  - if '1' then the report is correctly deleted -> remove it from table
                //  - else error
                if(result){
                    // delete row from datatable without reloading the entire list and refresh it
                    $.toast({
                        heading: "Ticket eliminato",
                        text: "L'elemento è stato eliminato con successo!",
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 3000
                    });
                    table.row($("tr[data-id='"+tkid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del ticket", "error");
                }

            })
            .fail(function(xhr, err) {
                swal("Errore!", "Errore durante l'eliminazione del ticket", "error");
            });
        });
    });

    /**
     * Change the state of usefulness of the ticket
     */
    $('#activities-table').on('change', '.ticket-useful', function(e){
        e.preventDefault();

        // get ticket id and type stored in tr
        var tkid = parseInt($(this).parent().parent().parent().data('id'));
        let useful = $(this).is(':checked');

        console.log(tkid);

        // update the selected ticket
        var jqxhr = $.ajax({
            url: '/plan_centro_put_ticket_usefulness',
            type: "post",
            dataType: "json",
            data: {
                id: tkid,
                useful: useful
            }
        })
        .done(function(result) {
            // check result
            //  - if '1' then the ticket is correctly updated -> show success message
            //  - else error
            if(result){
                $.toast({
                    heading: "Successo",
                    text: "L'aggiornamento è avvenuto con successo!",
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 3000
                });
            }
            else{
                // error message
                swal("Errore!", "Errore durante l'aggiornamento del ticket", "error");
            }

        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante l'aggiornamento del ticket", "error");
        });
    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // summernote initialization
    $('#newtic-body').summernote({
        // height: 350, // set editor height
        minHeight: 300, // set minimum height of editor
        maxHeight: null, // set maximum height of editor
        focus: false, // set focus to editable area after initializing summernote
        lang: 'it-IT',
        placeholder: 'Descrivi nel dettaglio:<br>• Pagina in cui ti trovavi;<br>• Punto esatto dell’interfaccia;<br>• Azione attesa;<br>• Risultato ottenuto;<br>• Hai ripetuto l’operazione?<br>• Allega eventuali screenshot.',
        toolbar: [
            ['font', ['style']],
            ['style', ['bold', 'italic', 'underline', 'clear']],
            ['para', ['ul', 'ol']],
            ['view', ['fullscreen']]
        ],
        styleTags: [
            { title: 'Normale', tag: 'p', className: 'p', value: 'p' }, 'pre'
            // 'h1', 'h2', 'h3', 'h4', 'h5'
        ]
    });

    // START Dropzone //
    let url = "/plan_centro_put_ticket";

    mainDropzone = initDropzone(url);
    // END Dropzone //

    /**
     * Selection of the area classification.
     */
    $('.select-with-desc').on('change', function(){
        // get area type
        var value = $(this).val();
        if (value == -1 ){
            $(this).next().empty();
            return;
        }

        // add html description
        var desc = $(this).find('option:selected').data('desc');
        $(this).next().html('<strong>Descrizione</strong>: '+ desc);
    });

    /**
     * Delete attachement.
     */
    $('.tab-content').on('click', '.del-attachment-ico', function(e){
        e.preventDefault();

        // get attachment id
        var id = $(this).data("attid");

        // show confirm message
        swal({
            title: "Stai per eliminare un allegato",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            // ajax call
            var jqxhr = $.ajax({
                url: '/plan_centro_del_selected_attachment',
                type: "post",
                dataType: "json",
                data: {
                    id: id
                }
            })
            .done(function(result) {
                // check result
                if(result){
                    // if true remove element parent
                    $("span[data-attid='"+id+"']").parent().remove();
                }
                else{
                    // else show error message
                    swal("Errore!", "Errore durante l'eliminazione dell'allegato", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione dell'allegato", "error");
            });
        });
    });

    /**
     * Validate form.
     */
    $('#newtic-form').validate({ // initialize the plugin
        rules: {
            "newtic-type":{
                required: true,
                min: 0
            },
            "newtic-urgency":{
                required: true,
                min: 0
            },
            "newtic-title" : {
                required: true
            }
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
            "newtic-title" : {
                required: "Inserisci titolo ticket"
            },
        },
        ignore: ":hidden:not(.summernote), .note-editable",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }

        },
    });

    /**
     * Function called when using Dropzone submit.
     */
    mainDropzone.on("sendingmultiple", function(files, xhr, formData) {
        // serialize total form
        var form = $('#newtic-form').serializeArray();

        // take care of disabled select
        form.push({ name: "newtic-assigned" , value: parseInt($('#newtic-assigned').val())});
        // manage summernote
        form.push({ name: "newtic-body", value: $('#newtic-body').summernote('code') });

        // add form fields to the dropzone submission object
        $.each(form, function(index, input){
            formData.append(input.name, input.value);
        });

    });

    /**
     * Function called at the Dropzone submit return.
     */
    mainDropzone.on("successmultiple", function(files, response) {
        // get report id from form
        var id   = $("#newtic-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata correttamente salvata';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // check result
        //  - if true then success, reload the list in the first tab, show the table and reset form
        //  - if false then error
        if(response == true){
            swal("Successo", msg_ok, "success");

            // refresh tickets list in the first tab
            loadTickets(dateFrom, dateTo);
            // show first tab
            $('.customtab a[href="#task-list"]').tab('show');
            // reset form
            clearFields();
        }
        else{
            // take care of any errors
            swal("Errore!", msg_err, "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // manage files, add error class and re-queue them
            $.each(files, function(index, file) {
                file.previewElement.classList.add("dz-error");
                file.status = Dropzone.QUEUED
            });
        }
    });

    /**
     * Submit ticket new/edit form.
     */
    $('#newtic-form').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if(! $(this ).valid() || $('#newtic-body').summernote('isEmpty')){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare il ticket", "info");
            return false;
        };

        var form = $("#newtic-form").serializeArray();
        var id   = $("#newtic-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata correttamente salvata';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        form.push({ name: "newtic-assigned" , value: parseInt($('#newtic-assigned').val())});
        form.push({ name: "newtic-body"     , value: $('#newtic-body').summernote('code') });

        // Check if attachments exist:
        // if exists     -> use the dropzone submit function and add fields of the form to the submission
        // if not exist  -> normal form submit
        if (mainDropzone.getQueuedFiles().length > 0) {
            console.log(mainDropzone.getQueuedFiles().length);
            mainDropzone.processQueue();
        }
        else {
             console.log("Invio normale");

            // ajax call
            $.ajax({
                url: '/plan_centro_put_ticket',
                type: 'post',
                dataType: "json",
                data: form
            }).done(function(result) {
                // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
                if(result){
                    swal("Successo", msg_ok, "success");

                    // refresh tickets list in the first tab
                    loadTickets(dateFrom, dateTo);
                    // show first tab
                    $('.customtab a[href="#task-list"]').tab('show');
                    // reset form
                    clearFields();
                }
                else{
                    // take care of any errors
                    swal("Errore!", msg_err, "error");
                }
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            })
            .fail(function(xhr, err) {
                // take care of any errors
                swal("Errore!", msg_err, "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });
        }
    });

    /**
     * Cancel button.
     */
    $('#clear-newtic-form').on('click', function(e) {
        e.preventDefault();

        //reset form
        clearFields();
    });

    /**
     * Cancel button.
     */
    $('#cancel-newtic-form').on('click', function(e) {
        e.preventDefault();

        // show report table and reset form
        $('.customtab a[href="#task-list"]').tab('show');
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    //END FORM FUNCTIONS

    //TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close view report.
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
     * Share ticket link.
     */
    $('.card-body').on('click', '.share-ticket-link', function(e){
        e.preventDefault();

        // get ticket id stored in tr
        var tkid = parseInt($(this).data("id"));

        // create a temporary input
        var $temp = $("<input>");
        // append it to document body
        $("body").append($temp);
        // set the input value with the text of the element to be copied
        $temp.val('https://opas.isprambiente.it/plan_centro/'+tkid).select();
        // execute system command "copy"
        document.execCommand("copy");
        // remove temporary input
        $temp.remove();

        // show success message
        $.toast({
            heading: 'Info',
            text: 'Link copiato',
            position: 'top-right',
            loaderBg:'#ff6849',
            icon: 'info',
            hideAfter: 3000,
            stack: 6
        });
    });

    /////////////////////////////////////////////////////////////////////
    //END TAB FUNCTIONS

    if(tkid != null && tkid != ''){
        loadTicketDetail(tkid);
    }

    /**
     * Function that refreshes the gallery item.
     */
    function refreshGalleryBig() {
        // re-initialize MagnificPopup for report-gallery-big in report detail
        console.log("Refresh gallery BIG");
        $('.report-gallery-big').each(function() { // the containers for all your galleries
            $(this).magnificPopup({
                delegate: 'a', // the selector for gallery item
                type: 'image',
                gallery: {
                  enabled:true
                }
            });
        });
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
     * Function that returns set of row's icons in the main table
     *
     * @param {object} ticket Ticket object
     *
     * @return html
     */
    function getRowIcons(ticket){

        var html = '';

        html += '<a href="javascript:void(0)" class="show-ticket text-info" data-toggle="tooltip" data-original-title="Visualizza e/o aggiorna stato"> <i class="fa-light fa-magnifying-glass-arrow-right"></i> </a>';
        html += '<a href="javascript:void(0)" class="share-ticket text-success" data-toggle="tooltip" data-original-title="Copia link ticket"> <i class="fa-light fa-share"></i> </a>';
        // ticket editable / deletable only if ticket has status "open" (not "taken charge", "reassign" or "closed")
        // and current user is the creator
        if(ticket.last_status == 'open' && user.us_id == ticket.us_id){
            html += '<br>';
            // if user has update grant
            if(update_grant)
                html += '<a href="javascript:void(0)" class="edit-ticket text-info" data-toggle="tooltip" data-original-title="Modifica ticket"> <i class="fa-light fa-pencil"></i> </a>';
            // if user has delete grant
            if(delete_grant)
                html += '<a href="javascript:void(0)" class="delete-ticket text-danger" data-toggle="tooltip" data-original-title="Elimina ticket"> <i class="fa-light fa-trash-can"></i> </a>';
        }

        return html;
    }

    /**
     * Function that returns formatted html for the title of status element
     *
     * @param {object} status Status object
     *
     * @return html
     */
    function getStatusTitle(status){

        // {
        //     "attachments": null,
        //     "ct_id": 1,
        //     "cts_description": "<p></p>",
        //     "cts_fulldate": "2024-10-24 11:36:21",
        //     "cts_id": 2,
        //     "cts_status": "reassign",
        //     "ctu_colour": "info",
        //     "ctu_desc": "Utile",
        //     "ctu_id": 1,
        //     "gr_id": 126,
        //     "gr_name": "Manutentori CED",
        //     "status_action": "Riassegna",
        //     "status_desc": "Riassegnato",
        //     "us_id": 4,
        //     "user_avatar_thumb": "/bobo-img/default/avatar/ava01.png",
        //     "user_fullname": ""
        // }
        let html = '';

        if(status.cts_status == 'reassign'){
            html += '<div class="form-group row first-row text-info">';
            html += '    <label for="" class="control-label col-lg-2 col-form-label label-big"><i class="fa-solid fa-turn-right"></i> '+status.user_fullname+'</label>';
            html += '    <div class="col-lg-10 view-param">il '+moment(status.cts_fulldate).format('DD/MM/YYYY [h.] HH:mm')+' ha assegnato il ticket a <strong>'+status.gr_name+'</strong></div>';
            html += '</div>';
        }
        else if(status.cts_status == 'taken charge'){
            html += '            <div class="form-group row first-row text-info">';
            html += '                <label for="" class="control-label col-lg-2 col-form-label label-big"><i class="fa-solid fa-check-double"></i> '+status.user_fullname+'</label>';
            html += '                <div class="col-lg-10 view-param">il '+moment(status.cts_fulldate).format('DD/MM/YYYY [h.] HH:mm')+' ha <strong>preso in carico il ticket</strong></div>';
            html += '            </div>';
        }
        else if(status.cts_status == 'closed'){
            html += '            <div class="form-group row first-row text-danger">';
            html += '                <label for="" class="control-label col-lg-2 col-form-label label-big"><i class="fa-solid fa-lock"></i> '+status.user_fullname+'</label>';
            html += '                <div class="col-lg-10 view-param">il '+moment(status.cts_fulldate).format('DD/MM/YYYY [h.] HH:mm')+' ha <strong>chiuso il ticket</strong></div>';
            html += '            </div>';
        }
        // else{ }

        return html;

    }

    /**
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields() {
        console.log('clearFields');

        // reset all input tag values
        $('.clear-input').val('');
        // reset all select tag values
        $('.clear-select').val(-1).trigger('change');
        // manage summernote
        $('#newtic-body').summernote('reset');

        // remove all attachments
        mainDropzone.removeAllFiles(true);
        // reset div for attachments
        $('#img-container').empty();

        // reset form texts
        $('#inner-new-report').text('Nuovo');
        $('#new .box-title').html('Inserisci nuovo TICKET');
        $('#confirm-newtic-form').html(' <i class="ti-save"></i> Inserisci ticket');
        // reset form validation
        $("#newtic-form").validate().resetForm();
    }

    /**
     * Function that resets fields of the status form
     *
     * @param {integer} tkid Ticket ID
     */
    function clearStatusFields(tkid){

        // reset all select tag values
        $('#uptic-form-'+tkid+' option.default-option').prop('selected', true);
        $('#uptic-form-'+tkid+' .clear-select').trigger('change');

        // manage summernote
        $('#uptic-body-'+tkid).summernote('reset');

        // remove all attachments
        dropzones[tkid].removeAllFiles(true);
    }

    /**
     * Function that retrieves the user role
     * No args needed
     */
    function getMetadata(){

        // get user role via ajax call
        var jqxhr = $.ajax({
            url: '/plan_centro_get_metadata',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            metadata = {};

            // check result
            if(result.res == 'OK'){
                user = result.user;

                if(user.is_ctp){
                    $('#newtic-assigned').val(126);
                    $('#newtic-assigned').prop('disabled', true);
                }
                else{
                    $('#newtic-assigned').val(125);
                    $('#newtic-assigned').prop('disabled', true);

                    // check if the account is a base user
                    if( !user.is_maintainer){
                        // hide "Rilevanti" filter
                        $('#show-useful').parent().parent().hide();
                        // hide table column
                        table.column(9).visible(false);
                    }
                }

                metadata.status = result.status;
                metadata.types = result.types;
                metadata.urgencies = result.urgencies;
                metadata.groups = result.groups;

                loadTickets(dateFrom, dateTo);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei metadati", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei metadati", "error");

        });
    }

    /**
     * Function that retrieves tickets of a given period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     *
     */
    function loadTickets(from, to){

        // reset datatable
        if(table)
            table.clear();

        var status = $('#status').val();
        var urgency = $('#urgencies').val();
        var type = $('#types').val();
        var useful = $('#show-useful').is(':checked');

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get list of tickets via an ajax call
        var jqxhr = $.ajax({
            url: '/plan_centro_get_tickets',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                status: status,
                urgency: urgency,
                type: type,
                useful: useful
            }
        })
        .done(function(result) {
            console.log( "success" );
            console.dir(result);
            var tickets = result.tickets;

            // check if at least one element exists
            if( tickets.length > 0 ){
                // variable for dinamically building the html
                var html = '';
                // loop through all elements
                // for each ticket, build a html row to be added to the datable
                $.each(tickets, function(idx, el) {

                    // if the user is a maintainer
                    // then create the html only for the tickets he is the recipient of
                    if(user.is_maintainer && el.last_gr_id != 126 )
                        return;

                    html += '<tr data-id="'+el.ct_id+'" class="'+getRowClass(el.last_status) +'">';
                    html += '    <td class="bobo-nowrap tkt-icons">'+getRowIcons(el)+'</td>';
                    html += '    <td class="bobo-nowrap">'+el.ct_id+'</td>';
                    html += '    <td class="bobo-nowrap operators-company">';
                    html += '        <span>'+el.user_fullname+'<br><small>'+el.comp_name+'</small></span>';
                    html += '    </td>';
                    html += '    <td>'+getFormattedDateDT(el.ct_fulldate, 'basic_timeStartMin')+'</td>';
                    html += '    <td class="font-bold">'+el.last_group_name+'</td>';
                    html += '    <td><span class="badge badge-'+el.ctu_colour+'">'+el.ctu_name+'</span></td>';
                    html += '    <td>'+el.status_desc+'</td>';
                    // html += '    <td>'+(el.last_status == 'closed' ? getFormattedDateDT(el.last_status_date, 'basic_timeStartMin') : '--' )+'</td>';
                    html += '    <td><span class="badge badge-type"><i class="'+el.ctt_icon+' text-'+el.ctt_colour+'"></i> '+el.ctt_name+'</span></td>';
                    html += '    <td class="font-bold">'+el.ct_title+'</td>';
                    html += '    <td><input type="checkbox" class="ticket-useful" '+(el.last_status == 'closed' && user.is_ctp ? '' : 'disabled' )+' data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+(el.ct_useful ? 'checked' : '' )+'></td>';
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
                table.rows({page: 'all'}).every(function() {
                    var row = this;
                    // get all tr node and transform it into a jquery items
                    // in order to find all tooltip elements
                    $(row.node())
                        .find('[data-toggle="tooltip"]')
                        .tooltip();
                    
                    $(row.node())
                        .find("td input[type='checkbox']")
                        .bootstrapToggle();
                });

            }
            else{
                table.draw();
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            console.log( "error" );
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that builds the ticket detail.
     *
     * @param {integer} tkid Ticket ID.
     */
    function loadTicketDetail(tkid){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // get ticket detail via ajax call
        var jqxhr = $.ajax({
            url: '/plan_centro_get_selected_ticket',
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
                var ticket      = result.ticket;
                var statusArray = result.status_list;

                // get first status "open" in the array
                let firstStatus = statusArray[0];
                let lastStatus = (statusArray.slice(-1))[0];

                console.dir(ticket);
                console.dir(statusArray);

                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#tk'+tkid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+ticket.ct_title+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-ticket" data-close="tk'+tkid+'"></i></a></li>';
                $('.nav').append(html);

                html = '';
                html += '<div class="tab-pane p-20" id="tk'+tkid+'" role="tabpanel">';
                html += '    <div class="form-body panel-report-view panel-view-mobile">';
                html += '        <h4 class="box-title">Ticket del <strong>'+moment(firstStatus.cts_fulldate).format('DD/MM/YYYY HH:mm')+'</strong> con priorità: <strong>'+lastStatus.ctu_name+'</strong></h4>';
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Aperto da</label>';
                html += '            <div class="col-md-4 view-param">'+ticket.user_fullname+'</div>';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Email</label>';
                html += '            <div class="col-md-4 view-param">'+ticket.user_email+'</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">1° tipologia</label>';
                html += '            <div class="col-md-4 view-param"><span class="badge badge-type"><i class="' + firstStatus.ctt_icon + ' text-' + firstStatus.ctt_colour + '"></i> ' + firstStatus.ctt_name + '</span></div>';
                html += '            <label for="" class="control-label col-md-2 col-form-label">1° priorità</label>';
                html += '            <div class="col-md-4 view-param font-italic"><span class="badge badge-'+firstStatus.ctu_colour+'">'+firstStatus.ctu_name+'</span></div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">1° assegnazione</label>';
                html += '            <div class="col-md-4 view-param font-italic"> ' + firstStatus.gr_name + '</div>';
                html += '        </div>';
                html += '        <h5 class="divider-title m-t-20 m-b-20"><i class="fa-regular fa-pencil"></i> Oggetto: <strong>'+ticket.ct_title+'</strong></h5>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Descrizione</label>';
                html += '            <div class="col-md-10 view-param">';
                html += ticket.ct_description;
                html += '            </div>';
                html += '        </div>';
                html += '        <h5 class="divider-title m-t-20 m-b-20"><i class="fa-regular fa-paperclip"></i> <strong>Allegati</strong> del ticket</h5>';
                if(firstStatus.attachments){

                    var attachments = JSON.parse(firstStatus.attachments);
                    console.dir(attachments);
                    html += '        <div class="form-group row report-gallery-big">';
                    html += '            <div class="col-lg-12 m-b-20">';
                    // loop through attachments
                    // different items depending on the file type
                    $.each(attachments, function(idx, attachment){
                        // check if current looped attachment is an image
                        if (attachment.file_image == true){
                            html += '                    <a href="/uploads/planning/centro/'+attachment.file_archive+'" class="clearfix thumb-gallery">';
                            html += '                        <img src="/uploads/planning/centro/'+attachment.file_archive+'" />';
                            html += '                    </a>';
                        }
                    });
                    html += '                </div>';
                    html += '            </div>';
                }
                else {

                    html += '            <div class="form-group row">';
                    html += '                <div class="col-12 view-param">Nessun allegato</div>';
                    html += '            </div>';
                }

                // check if there are more than 1 status (the first one is the "open" status)
                // if true then build the history of all changes of status
                if(statusArray.length > 1){

                    html += '        <hr class="m-t-0 m-b-20">';
                    html += '        <h4 class="box-title"><strong>Stati di aggiornamento</strong> del ticket</h4>';

                    statusArray.forEach(function(el, idx){
                        // if first status "open" then skip
                        if(idx == 0)
                            return;

                        // {
                        //     "attachments": null,
                        //     "ct_id": 1,
                        //     "cts_description": "<p></p>",
                        //     "cts_fulldate": "2024-10-24 11:36:21",
                        //     "cts_id": 2,
                        //     "cts_status": "reassign",
                        //     "ctu_colour": "info",
                        //     "ctu_desc": "Utile",
                        //     "ctu_id": 1,
                        //     "gr_id": 126,
                        //     "gr_name": "Manutentori CED",
                        //     "status_action": "Riassegna",
                        //     "status_desc": "Riassegnato",
                        //     "us_id": 4,
                        //     "user_avatar_thumb": "/bobo-img/default/avatar/ava01.png",
                        //     "user_fullname": ""
                        // }

                        var statusClass;
                        if(idx%2 == 1){
                            statusClass = 'tkt-closed';
                        }
                        else{
                            statusClass = 'tkt-reopened';
                        }

                        html += '        <div class="'+statusClass+'">';
                        html += '            <img src="'+el.user_avatar_thumb+'" class="avatar" alt="avatar di '+el.user_fullname+'">';
                        html += getStatusTitle(el);
                        html += '            <div class="form-group row">';
                        html += '                <label for="" class="control-label col-lg-2 col-form-label">Tipologia</label>';
                        html += '               <div class="col-lg-5 view-param"><span class="badge badge-type"><i class="'+el.ctt_icon+' text-'+el.ctt_colour+'"></i> '+el.ctt_name+'</span></div>';
                        html += '            </div>';
                        html += '            <div class="form-group row">';
                        html += '                <label for="" class="control-label col-lg-2 col-form-label">Priorità</label>';
                        html += '                <div class="col-lg-5 view-param"><span class="badge badge-'+el.ctu_colour+'">'+el.ctu_name+'</span></div>';
                        html += '            </div>';
                        html += '            <div class="form-group row">';
                        html += '                <label for="" class="control-label col-lg-2 col-form-label">Testo</label>';
                        html += '                <div class="col-lg-10 view-param">'+el.cts_description+'</div>';
                        html += '            </div>';
                        if(el.attachments){
                            var attachments = JSON.parse(el.attachments);
                            html += '            <div class="form-group row report-gallery-big">';
                            html += '                <label for="" class="control-label col-lg-2 col-form-label">Allegati</label>';
                            html += '                <div class="col-lg-10 m-b-20">';
                            // loop through attachments
                            // different items depending on the file type
                            $.each(attachments, function(idx, attachment){
                                // check if current looped attachment is an image
                                if (attachment.file_image == true){
                                    html += '                    <a href="/uploads/planning/centro/'+attachment.file_archive+'" class="clearfix thumb-gallery">';
                                    html += '                        <img src="/uploads/planning/centro/'+attachment.file_archive+'" />';
                                    html += '                    </a>';
                                }
                            });
                            html += '                </div>';
                            html += '            </div>';
                        }

                        html += '        </div>';
                    });

                } // END statusArray > 1

                // show only if user is a CTP component or a CED maintainer
                if(user.is_ctp || user.is_maintainer){

                    html += '        <hr class="m-t-50 m-b-20">';
                    html += '        <h4 class="box-title text-primary m-b-5"><strong>Aggiornamento</strong> del ticket</h4>';
                    html += '        <h6>Modifica lo stato del ticket oppure riassegnalo a chi di competenza <strong>tramite il form qui sotto</strong></h6>';
                    html += '        <hr class="m-t-10 m-b-20">';
                    html += '        <form class="form form-medium" id="uptic-form-'+tkid+'" name="uptic-form">';
                    html += '            <input type="hidden" id="uptic-id-'+tkid+'" name="uptic-id" value="'+tkid+'">';
                    html += '            <div class="form-group row">';
                    html += '                <label for="uptic-action" class="col-md-2 col-form-label">Azioni <span class="text-danger">*</span></label>';
                    html += '                <div class="col-md-4">';
                    html += '                    <select class="custom-select clear-select col-md-12" id="uptic-action-'+tkid+'" name="uptic-action">';
                    html += '                        <option value="" class="default-option">Seleziona azione...</option>';

                    metadata.status.forEach(function(el){
                        if(el.status_label != 'open')
                            html += '                            <option value="'+el.status_label+'">'+el.status_action+'</option>';
                    });
                    html += '                    </select>';
                    html += '                </div>';
                    html += '                <label for="uptic-urgency" class="col-md-2 col-form-label">Priorità <span class="text-danger">*</span></label>';
                    html += '                <div class="col-md-4">';
                    html += '                    <select class="custom-select clear-select col-md-12" id="uptic-urgency-'+tkid+'" name="uptic-urgency">';
                    html += '                        <option value="-1">Seleziona urgenza...</option>';
                    metadata.urgencies.forEach(function(el){
                        html += '                            <option value="'+el.ctu_id+'">'+el.ctu_name+'</option>';
                    });
                    html += '                    </select>';
                    html += '                </div>';
                    html += '                <label for="uptic-assigned" class="col-md-2 col-form-label m-t-5">Assegnato a <span class="text-danger">*</span></label>';
                    html += '                <div class="col-md-4 m-t-5">';
                    html += '                    <select class="custom-select clear-select col-md-12" id="uptic-assigned-'+tkid+'" name="uptic-assigned">';
                    html += '                        <option value="-1">Seleziona destinatario..</option>';
                    metadata.groups.forEach(function(el){
                        html += '                            <option value="'+el.gr_id+'">'+el.gr_name+'</option>';
                    });
                    html += '                    </select>';
                    html += '                </div>';
                    html += '                <label for="uptic-type" class="col-md-2 col-form-label m-t-5">Tipologia <span class="text-danger">*</span></label>';
                    html += '                <div class="col-md-4 m-t-5">';
                    html += '                    <select class="custom-select clear-select col-md-12" id="uptic-type-'+tkid+'" name="uptic-type">';
                    html += '                        <option value="-1">Seleziona tipologia..</option>';
                    metadata.types.forEach(function(el){
                        html += '                            <option value="'+el.ctt_id+'">'+el.ctt_name+'</option>';
                    });
                    html += '                    </select>';
                    html += '                </div>';

                    html += '            </div>';
                    html += '            <div class="form-group row">';
                    html += '                <label for="uptic-body" class="col-md-2 col-form-label">Testo e allegati <span class="text-danger">*</span></label>';
                    html += '                <div class="col-md-6">';
                    html += '                    <div class="summernote" id="uptic-body-'+tkid+'" name="uptic-body" required></div>';
                    html += '                </div>';
                    html += '                <div class="col-md-4">';
                    html += '                    <div id="uptic-attach-'+tkid+'" class="dropzone"></div>';
                    html += '                    <p class="text-grey">Puoi aggiungere allegati che <strong>spiegano al meglio il tuo punto di vista</strong></p>';
                    html += '                </div>';
                    html += '            </div>';
                    html += '            <div class="form-group row">';
                    html += '                <div class="col-sm-10 offset-md-2">';
                    html += '                    <button type="submit" class="btn btn-info uptic-confirm" name="uptic-confirm" id="uptic-confirm-'+tkid+'"><i class="fa-regular fa-floppy-disk"></i> Salva</button>';
                    html += '                    <button type="button" class="btn btn-outline-primary uptic-cancel" name="uptic-cancel" id="uptic-cancel-'+tkid+'"><i class="fa-regular fa-arrow-rotate-left"></i> Annulla</button>';
                    html += '                </div>';
                    html += '            </div>';
                    html += '        </form>';
                }
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <div class="form-group row m-b-0">';
                html += '            <div class="col-md-12">';
                html += '                <button type="button" class="btn btn-inverse close-ticket" data-close="tk'+tkid+'"><i class="fa-regular fa-circle-xmark"></i> Chiudi dettaglio</button>';
                html += '                <a href="#" data-id="'+tkid+'" class="btn btn-success share-ticket-link"><i class="fa-solid fa-share-from-square"></i> Condividi ticket</a>';
                html += '            </div>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                $('.tab-content').append(html);

                refreshGalleryBig();

                if(user.is_ctp || user.is_maintainer){

                    initializeForm(tkid);

                    $('#uptic-id-'+tkid).val(tkid);
                    $('#uptic-urgency-'+tkid).val(lastStatus.ctu_id);
                    $('#uptic-urgency-'+tkid+' option[value="'+lastStatus.ctu_id+'"]').addClass('default-option');

                    $('#uptic-assigned-'+tkid).val(lastStatus.gr_id);
                    $('#uptic-assigned-'+tkid+' option[value="'+lastStatus.gr_id+'"]').addClass('default-option');

                    $('#uptic-type-'+tkid).val(lastStatus.ctt_id);
                    $('#uptic-type-'+tkid+' option[value="'+lastStatus.ctt_id+'"]').addClass('default-option');

                    $('#uptic-assigned-'+tkid).prop('disabled', true);
                    $('#row-useful-'+tkid).hide();

                    $('#uptic-action-'+tkid).on('change', function(){

                        let action = $(this).val();
                        if(action == 'reassign'){
                            $('#uptic-assigned-'+tkid).prop('disabled', false);
                        }
                        else{
                            $('#uptic-assigned-'+tkid+' option.default-option').prop('selected', true);
                            $('#uptic-assigned-'+tkid).prop('disabled', true);
                        }
                    });
                    
                }

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
    };


    /**
     * Function that initializes all form's events
     *
     * @param {integer} tkid Ticket ID
     */
    function initializeForm(tkid){

        // initialize boostraptoggle
        $('#uptic-useful-'+tkid).bootstrapToggle();

        // initialize summernote plugin
        $('#uptic-body-'+tkid).summernote({
            // height: 350, // set editor height
            minHeight: 300, // set minimum height of editor
            maxHeight: null, // set maximum height of editor
            focus: false, // set focus to editable area after initializing summernote
            lang: 'it-IT',
            toolbar: [
                ['font', ['style']],
                ['style', ['bold', 'italic', 'underline', 'clear']],
                ['para', ['ul', 'ol']],
                ['view', ['fullscreen']]
            ],
            styleTags: [
                { title: 'Normale', tag: 'p', className: 'p', value: 'p' }, 'pre'
                // 'h1', 'h2', 'h3', 'h4', 'h5'
            ]
        });

        // initialize dropzone plugin
        let url = '/plan_centro_put_ticket_status';
        dropzones[tkid] = initDropzoneBySelector('#uptic-attach-'+tkid, url);

        /**
         * Validate form.
         */
        $('#uptic-form-'+tkid).validate({ // initialize the plugin
            rules: {
                "uptic-action":{
                    required: true
                },
                "uptic-urgency":{
                    required: true,
                    min: 0
                },
                "uptic-assigned" : {
                    required: true,
                    min: 0
                },
                "uptic-type":{
                    required: true,
                    min: 0
                }
            },
            messages: {
                "uptic-action":{
                    required: "Selezionare azione",
                    min: "Selezionare azione"
                },
                "uptic-urgency":{
                    required: "Selezionare livello di urgenza",
                    min: "Selezionare livello di urgenza"
                },
                "uptic-assigned" : {
                    required: "Selezionare destinatario",
                    min: "Selezionare destinatario"
                },
                "uptic-type":{
                    required: "Selezionare tipologia",
                    min: "Selezionare tipologia"
                }
            },
            ignore: ":hidden:not(.summernote), .note-editable",
            errorPlacement: function ( error, element ) {

                if(element.parent().hasClass('input-group')){
                  error.insertAfter( element.siblings() );
                }else{
                    error.insertAfter( element );
                }

            },
        });

        /**
         * Function called when using Dropzone submit.
         */
        dropzones[tkid].on("sendingmultiple", function(files, xhr, formData) {
            // serialize total form
            var form = $('#uptic-form-'+tkid).serializeArray();

            // take care of disabled select
            if( $('#uptic-assigned-'+tkid).is(':disabled') )
                form.push({ name: "uptic-assigned" , value: parseInt($('#uptic-assigned-'+tkid).val())});
            // manage summernote
            form.push({ name: "uptic-body", value: $('#uptic-body-'+tkid).summernote('code') });

            // add form fields to the dropzone submission object
            $.each(form, function(index, input){
                formData.append(input.name, input.value);
            });

        });

        /**
         * Function called at the Dropzone submit return.
         */
        dropzones[tkid].on("successmultiple", function(files, response) {
            // get report id from form
            var id   = $('#uptic-id-'+tkid).val();

            // different messages based on the type of action (insert or update)
            // if the id is setted then is an update
            //  otherwise is an insert
            if(id){
                msg_ok = 'La modifica è stata correttamente salvata';
                msg_err = 'Si è verificato un errore durante la modifica';
            }
            else{
                msg_ok  = 'Il salvataggio è avvenuto correttamente';
                msg_err = 'Si è verificato un errore durante il salvataggio';
            }

            // check result
            //  - if true then success, reload the list in the first tab and refresh current tab
            //  - if false then error
            if(response == true){
                // refresh tickets list in the first tab
                loadTickets(dateFrom, dateTo);

                $.toast({
                    heading: "Successo",
                    text: msg_ok,
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 3000
                });

                // close tab and re-build it
                $('#tk'+tkid+' .close-ticket').trigger('click');
                loadTicketDetail(tkid);

                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else{
                // take care of any errors
                swal("Errore!", msg_err, "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // manage files, add error class and re-queue them
                $.each(files, function(index, file) {
                    file.previewElement.classList.add("dz-error");
                    file.status = Dropzone.QUEUED
                });
            }
        });

        /**
         * Submit new ticket status form.
         */
        $('#uptic-form-'+tkid).on('submit', function (e) {
            e.preventDefault();

            // check if all form fields are valid
            if(! $(this ).valid() || $('#uptic-body-'+tkid).summernote('isEmpty')){
                swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare il ticket", "info");
                return false;
            };

            // serialize total form
            var form = $('#uptic-form-'+tkid).serializeArray();

            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';

            // show preloader, waiting for the end of the process
            $(".inner-preloader").show();

            // take care of disabled select
            if( $('#uptic-assigned-'+tkid).is(':disabled') )
                form.push({ name: "uptic-assigned" , value: parseInt($('#uptic-assigned-'+tkid).val())});
            // manage summernote
            form.push({ name: "uptic-body", value: $('#uptic-body-'+tkid).summernote('code') });

            // Check if attachments exist:
            // if exists     -> use the dropzone submit function and add fields of the form to the submission
            // if not exist  -> normal form submit
            if (dropzones[tkid].getQueuedFiles().length > 0) {
                console.log(dropzones[tkid].getQueuedFiles().length);
                dropzones[tkid].processQueue();
            }
            else {
                 console.log("Invio normale");

                // ajax call
                $.ajax({
                    url: '/plan_centro_put_ticket_status',
                    type: 'post',
                    dataType: "json",
                    data: form
                }).done(function(result) {
                    // check result
                    //  - if true then success, reload the list in the first tab and refresh current tab
                    //  - if false then error
                    if(result){
                        // refresh tickets list in the first tab
                        loadTickets(dateFrom, dateTo);

                        $.toast({
                            heading: "Successo",
                            text: msg_ok,
                            position: 'top-right',
                            loaderBg:'#e8bb05',
                            icon: 'success',
                            hideAfter: 3000
                        });

                        // close tab and re-build it
                        $('#tk'+tkid+' .close-ticket').trigger('click');
                        loadTicketDetail(tkid);
                    }
                    else{
                        // take care of any errors
                        swal("Errore!", msg_err, "error");
                    }
                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                })
                .fail(function(xhr, err) {
                    // take care of any errors
                    swal("Errore!", msg_err, "error");
                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                });
            }
        });

        /**
         * Reset form.
         */
        $('#uptic-cancel-'+tkid).on('click', function(e){
            e.preventDefault();

            clearStatusFields(tkid);
        });
    };
});