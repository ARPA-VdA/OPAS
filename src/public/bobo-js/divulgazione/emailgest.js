/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var tblLists;
    var tblExt;

    ///////////////////////////////// TAB MAILING LISTS ////////////////////////////////////
{
    //datatable
    tblLists = $('#lists-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // "ordering": false,
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
            { "width": "70px", "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // select destinations
    $("#mlist-company").select2({
        placeholder: "Seleziona azienda..."
    });

    $('#multiselect').multiselect({
        right: '#mlist-selected-users',
        submitAllLeft: false,
        ignoreDisabled: true,
        keepRenderingSort: true,
        search: {
            left: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
            right: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
        },
        fireSearch: function(value) {
            return true;
        }
    });

    //TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Show detail.
     */
    $('#lists-table').on('click', '.show-mlist', function(e){

        e.preventDefault();

        // get mailing list id stored in table tr element
        var mlid = parseInt($(this).parent().parent().data("id"));

        // check if the mailing list's detail is already open
        if( $('#mlist'+mlid).length ) {
            console.log('The detail is already open');
            $('.customtab a[href="#mlist'+mlid+'"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createMailingListDetail(mlid);
    });

    /**
     * Edit item.
     */
    $('#lists-table').on('click', '.edit-mlist', function(e){

        e.preventDefault();

        // get mailing list id stored in table tr element
        var mlid = parseInt($(this).parent().parent().data("id"));
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // reset form
        clearFields();

        // recover mailing list detail via an ajax call
        var jqxhr = $.ajax({
            url: '/div_gest_get_selected_mailing_list',
            type: "post",
            dataType: "json",
            data: {
                id: mlid
            },
        })
        .done(function(result) {
            console.log('edit report!');

            // fill fields of the form with metadata arriving from database
            var list = result.list;
            console.dir(list);

            $('#mlist-id').val(mlid);
            $('#mlist-name').val(list.ml_name);
            $('#mlist-company').val(list.comp_id).trigger('change');
            $('#mlist-desc').val(list.ml_description);


            $('#multiselect').val(list.total_mails);
            $('#multiselect_rightSelected').trigger('click');

            // modify 'Nuovo' text in 'Modifica'
            $('#lists-new .box-title').text('Modifica MAILING LIST');
            $('#inner-new-list').text('Modifica');
            $('#mlist-save').html(' <i class="ti-save"></i> Modifica');

            // show form tab
            $('.customtab a[href="#lists-new"]').tab('show');
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", msg_err, "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

    /**
     * Delete item.
     */
    $('#lists-table').on('click', '.delete-mlist', function(e){
        e.preventDefault();
        // get mailing list id stored in table tr element
        var mlid = parseInt($(this).parent().parent().data("id"));

        // confirm message in order to continue in item deleting
        swal({
            title: "Stai per eliminare la mailing list",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            var jqxhr = $.ajax({
                url: '/div_gest_del_mailing_list',
                type: "post",
                dataType: "json",
                data: {
                    id: mlid
                }
            })
            .done(function(result) {

                // check result
                //  - if '1' then the item is correctly deleted -> remove it from table
                //  - else error
                if(result == 1){
                    // delete row from datatable without reloading the entire list and refresh it
                    swal("Mailing list eliminata", "La mailing list è stata eliminata con successo!", "success");
                    tblLists.row($("tr[data-id='"+mlid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della mailing list", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione della mailing list", "error");
            });

        });
    });

    /////////////////////////////////////////////////////////////////////
    //END TABLE FUNCTIONS

    //FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    // validate form
    var validatorMlist = $('#form-mlist').validate({ // initialize the plugin
        rules: {
            "mlist-name":{
                required: true
            }
        },
        messages: {
            "mlist-name" : {
                required: "Inserire nome della mailing list",
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

    $('#mlist-save').on('click', function(e){
        e.preventDefault();

        // check if all form fields are valid
        if (! $('#form-mlist').valid() || $('#mlist-selected-users').find('option').length == 0 ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile generare questo elemento", "info");
            return false;
        };

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        var mlid = $('#mlist-id').val();
        if(mlid){
            msg_ok = 'La modifica è stata correttamente salvata';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // build specific object to be added to main form
        var portalMails = [];
        var externalMails = [];
        $('#mlist-selected-users').find('option').each(function(idx, el){

            var value = $(el).val();

            var tmp = value.split('-');
            var optType = tmp[0];
            var optId = parseInt(tmp[1]);
            // different array based on the type of address (internal or external)
            if(optType == 'port'){
                portalMails.push(optId);
            }
            else{
                externalMails.push(optId);
            }
        });

        // serialize form and add new fields
        var form = $('#form-mlist').serializeArray();
        form.push({ name: "portal-users", value: JSON.stringify(portalMails) });
        form.push({ name: "external-emails", value: JSON.stringify(externalMails) });

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        $.ajax({
            type: 'post',
            url: '/div_gest_put_mailing_list',
            data: form
        }).done(function(result) {
            // check result
            //  - if true then success, reload the list in the first tab, show the table and reset form
            //  - if false then error
            if(result){
                swal("Successo", msg_ok, "success");
                // update mailing list
                loadMailingLists();
                // show mailing list table
                $('.customtab a[href="#lists-tbl"]').tab('show');
                // clear form fields
                clearFields();
            }
            else{
                // error message
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
    });

    /**
     * Cancel button.
     */
    $('#mlist-cancel').on('click', function(e) {

        e.preventDefault();
        // show main table and reset form
        $('.customtab a[href="#lists-tbl"]').tab('show');
        clearFields();
    });
    /////////////////////////////////////////////////////////////////////
    //END FORM FUNCTIONS

    //TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    /**
     * Close view item.
     */
    $('#main-tab').on('click', '.close-detail', function(e){
        e.preventDefault();

        // get "element" to be closed
        var close = $(this).data("close");

        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.inner-content #'+close).remove();
            $('.customtab a[href="#lists-tbl"]').tab('show');

        }, 1);
    });
    /////////////////////////////////////////////////////////////////////
    //END TAB FUNCTIONS
}

    ///////////////////////////////// TAB EMAIL ESTERNE ////////////////////////////////////
{
    // select destinations
    $("#email-company").select2({
        placeholder: "Seleziona azienda..."
    });

    //datatable
    tblExt = $('#email-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // "ordering": false,
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
            { "width": "70px", "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 3, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }

    });

    //TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    /**
     * Edit item.
     */
    $('#email-table').on('click', '.email-edit', function(e){
        e.preventDefault();

        $('.new-external-email h4').html('Modifica <strong>EMAIL</strong> <span class="text-danger">*</span>');

        var extid = parseInt($(this).parent().parent().data("id"));
        var comp = parseInt($(this).parent().parent().data("comp"));

        // retrieve data from table row without doing an ajax request
        var tr = $(this).parent().parent();
        var name = $('td:nth-child(2)', tr).text();
        var surname = $('td:nth-child(3)', tr).text();
        var mail = $('td:nth-child(4)', tr).text();

        // fill form with data from the table's row
        $('#email-id').val(extid);
        $('#email-name').val(name);
        $('#email-surname').val(surname);
        $('#email-mail').val(mail);
        $('#email-company').val(comp).trigger('change');
        // disable field
        $('#email-mail').prop('disabled', true);
    });

    /**
     * Delete item.
     */
    $('#email-table').on('click', '.email-delete', function(e){
        e.preventDefault();

        // get item id stored in table tr element
        var extid = parseInt($(this).parent().parent().data("id"));
        // confirm message in order to continue in item deleting
        swal({
            title: "Stai per eliminare l'email",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();
            // delete the selected item
            var jqxhr = $.ajax({
                url: '/div_gest_del_external_mail',
                type: "post",
                dataType: "json",
                data: {
                    id: extid
                }
            })
            .done(function(result) {
                // check result
                //  - if '1' then the item is correctly deleted -> remove it from table
                //  - else error
                if(result){
                    // success message
                    swal("Email eliminata", "L'email è stata rimossa con successo! Mailing list sono state aggiornate automaticamente", "success");
                    // refresh list of external mails and of mailing lists
                    loadExternalMails();
                    loadMailingLists();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione dell'email", "error");
                }
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione dell'email", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });

        });
    });
    /////////////////////////////////////////////////////////////////////
    //END TABLE FUNCTIONS

    //FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    // validate form
    var validatorExt = $('#form-email').validate({ // initialize the plugin
        rules: {
            "email-mail" : {
                required: true,
                email: true
            }
        },
        messages: {
            "email-mail" : {
                required: "Inserire l'email dell'utente",
                email: "Inserire un indirizzo email valido"
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
     * Submit.
     */
    $('#form-email').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Mail non salvata!", "info");
            return false;
        };

        // get form element
        var form = $("#form-email");

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        var id = $("#email-id").val();
        var msg_err;
        var msg_ok;

        if(id){
            msg_ok = 'La mail esterna è stata modificata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica della mail esterna';
        }
        else{
            msg_ok = 'La mail esterna è stata aggiunta con successo! ';
            msg_err = 'Si è verificato un errore durante l\'inserimento della mail esterna';
        }

        // ajax call
        $.ajax({
            type: 'post',
            url: '/div_gest_put_external_mail',
            data: form.serialize()
        }).done(function(result) {

            // check result
            //  - if 1 then success, reload the list in the table and reset form
            //  - if -1 then warning, an external mail already exists with the specified address. Refresh list and reset form
            //  - if -2 then warning, an internal user already exists with the specified address. Reset form
            //  - else then error
            if(result == 1){
                swal("Successo", msg_ok, "success");
                // reload list
                loadExternalMails();
                // reset form
                clearExtFields();
            }
            else if( result == -1){
                swal("Attenzione!", "Nel sistema è già presente l'email esterna inserita. Aggiunta alla propria lista di email", "warning");

                // reload list
                loadExternalMails();
                // reset form
                clearExtFields();
            }
            else if( result == -2){
                swal("Attenzione!", "Nel sistema è già presente un utente con l'email inserita. Email non aggiunta", "warning");
                // reset form
                clearExtFields();
            }
            else
                // error message
                swal("Errore!", msg_err, "error");

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", msg_err, "error");
        });


    });

    /**
     * Cancel button
     */
    $('#email-cancel').on('click', function(e){
        e.preventDefault();
        // reset form
        clearExtFields();
    });
}

    // first load of mailing lists and external mails
    loadMailingLists();
    loadExternalMails();

    // UTILITIES FUNCTION
    // ///////////////////////////////////////

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
     * Function that scrolls the view to a specific html element
     *
     * @param {string} aid Html element id
     *
     */
    function scrollToAnchor(aid){
        var aTag = $("#"+ aid );
        $('html,body').animate({scrollTop: aTag.offset().top},'slow');
    }

    /**
     * Function that resets fields of the mailing list form
     * No args needed
     */
    function clearFields(){

        // reset all input tag values
        $('#form-mlist .clear-input' ).val('');
        // reset all select tag values
        $('#form-mlist .clear-select' ).val(-1).trigger('change');
        // reset multiselect plugin
        $('#multiselect_leftAll' ).trigger("click");

        // reset form texts
        $('#lists-new .box-title').text('Inserisci MAILING LIST');
        $('#inner-new-list').text('Nuova');
        $('#mlist-save').html(' <i class="ti-save"></i> Inserisci');
        // reset form validation
        $('#form-mlist').validate().resetForm();
    }

    /**
     * Function that resets fields of the external form
     * No args needed
     */
    function clearExtFields(){

        // reset all input tag values
        $( "#form-email .clear-input" ).val('');
        // reset all select tag values
        $( "#form-email .clear-select" ).val(-1).trigger('change');
        // reset field enable status
        $('#email-mail').prop('disabled', false);

        // reset form texts
        $('.new-external-email h4').html('Inserisci <strong>nuova EMAIL</strong> <span class="text-danger">*</span>');
        // reset form validation
        $('#form-email').validate().resetForm();
    }

    /**
     * Function that retrieves all the mailing lists
     * No args needed
     */
    function loadMailingLists(){
        // reset datatable
        if(tblLists)
            tblLists.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get mailing list visible for the user
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/div_gest_get_mailing_lists',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);

            // check result
            if(result.res == 'OK'){
                var lists = result.lists;
                // check if at least one element exists
                if( lists.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    // loop through all elements
                    // for each mailing list, build a html row to be added to the datable
                    $.each(lists, function(idx, el) {
                        // ee_id
                        // ee_name
                        // ee_surname
                        // ee_mail
                        // comp_id
                        // comp_name
                        html += '<tr data-id="'+el.ml_id+'">';
                        html += '    <td>';
                        html += '        <a href="javascript:void(0)" class="show-mlist" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-mlist" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        if(delete_grant){
                            html += '        <a href="javascript:void(0)" class="delete-mlist" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        }
                        html += '    </td>';
                        html += '    <td>'+el.ml_name+'</td>';
                        html += '    <td>'+el.ml_description+'</td>';
                        html += '    <td>'+el.comp_name+'</td>';
                        html += '    <td>'+el.total_mails.join(', ')+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';

                    });

                    // add rows to datatable by using html object
                    tblLists.rows.add($( html ));
                    // redraw it
                    tblLists.draw();
                    // adjust columns size
                    tblLists.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblLists.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    // redraw it
                    tblLists.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle mailing list", "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error emssage
            swal("Errore!", "Errore durante il recupero delle mailing list", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

    /**
     * Function that retrieves all the external mails
     * No args needed
     */
    function loadExternalMails(){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // reset datatable
        if ( tblExt )
            tblExt.clear();

        $('#ext-group').remove();

        // get external mails visible for the user
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/div_gest_get_external_mails',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);
            // check result
            if(result.res == 'OK'){
                var mails = result.mails;

                // check if at least one element exists
                if( mails.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    var htmlOpt = '';

                    htmlOpt += '<optgroup id="ext-group" label="Utenti esterni">';
                    // loop through all elements
                    // for each mailing list, build a html row to be added to the datable
                    // and a select option
                    $.each(mails, function(idx, el) {
                        // ee_id
                        // ee_name
                        // ee_surname
                        // ee_mail
                        // comp_id
                        // comp_name
                        html += '<tr data-id="'+el.ee_id+'" data-comp="'+el.comp_id+'">';
                        html += '    <td>';
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="email-edit" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        if(delete_grant){
                            html += '        <a href="javascript:void(0)" class="email-delete" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        }
                        html += '    </td>';
                        html += '    <td>'+el.ee_name+'</td>';
                        html += '    <td>'+el.ee_surname+'</td>';
                        html += '    <td>'+el.ee_mail+'</td>';
                        html += '    <td>'+el.comp_name+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';

                        var fullName = '';
                        if(el.ee_fullname != ''){
                            fullName = ' - '+el.ee_fullname;
                        }
                        htmlOpt += '<option value="ext-'+el.ee_id+'">'+el.ee_mail+''+fullName+'</option>';
                    });

                    htmlOpt += '</optgroup>';

                    $('#multiselect').append(htmlOpt);

                    // add rows to datatable by using html object
                    tblExt.rows.add($( html ));
                    // redraw it
                    tblExt.draw();
                    // adjust columns size
                    tblExt.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblExt.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    tblExt.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle mail esterne", "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle mail esterne", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

    /**
     * Function that builds the mailing list detail.
     *
     * @param {integer} mlid mailing list ID.
     */
    function createMailingListDetail(mlid){

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get mailing list data via an ajax call
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/div_gest_get_selected_mailing_list',
            type: "post",
            dataType: "json",
            data:{
                id: mlid
            }
        })
        .done(function(result) {
            console.dir(result);

            // check result
            //if OK then build html
            if(result.res == 'OK'){
                var el = result.list;

                // add link for the new tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#mlist'+mlid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+el.ml_name+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-detail" data-close="mlist'+mlid+'"></i></a></li>';
                $('.customtab').append(html);

                // variable for dinamically building the html
                html = '';
                html += '<div class="tab-pane p-20" id="mlist'+mlid+'" role="tabpanel">';
                html += '    <div class="form-body panel-report-view panel-view-mobile">';
                html += '        <h4 class="box-title">Mailing list <strong>'+el.ml_name+'</strong></h4>';
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Azienda</label>';
                html += '            <div class="col-md-4 view-param">'+formatTextField(el.comp_name)+'</div>';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Descrizione</label>';
                html += '            <div class="col-md-4 view-param">'+formatTextField(el.ml_description)+'</div>';
                html += '        </div>';
                html += '        <h4 class="box-title">Gli utenti della <strong>Mailing list</strong></h4>';
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <table id="email-mlist-table" class="display responsive table table-hover table-striped" cellspacing="0" width="100%">';
                html += '            <thead>';
                html += '                <tr>';
                html += '                    <th>Nome</th>';
                html += '                    <th>Cognome</th>';
                html += '                    <th>Email</th>';
                html += '                    <th>Azienda</th>';
                html += '                    <th></th>';
                html += '                </tr>';
                html += '            </thead>';
                html += '            <tbody>';

                var portalMails = JSON.parse(el.portal_mails);
                var externalMails = JSON.parse(el.external_mails);

                $.each(portalMails, function(idx, mail){
                    html += '                <tr>';
                    html += '                    <td>'+mail.name+'</td>';
                    html += '                    <td>'+mail.surname+'</td>';
                    html += '                    <td>'+mail.email+'</td>';
                    html += '                    <td>'+mail.comp_name+'</td>';
                    html += '                    <td></td>';
                    html += '                </tr>';
                });

                $.each(externalMails, function(idx2, mail2){
                    html += '                <tr>';
                    html += '                    <td>'+mail2.name+'</td>';
                    html += '                    <td>'+mail2.surname+'</td>';
                    html += '                    <td>'+mail2.email+'</td>';
                    html += '                    <td>'+mail2.comp_name+'</td>';
                    html += '                    <td></td>';
                    html += '                </tr>';
                });


                html += '                </tr>';
                html += '            </tbody>';
                html += '        </table>';
                html += '    </div>';
                html += '</div>';

                // append new html
                $('.inner-content').append(html);
                // show detail tab
                $('.customtab a[href="#mlist'+mlid+'"]').tab('show');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero della mailing list", "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero della mailing list", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

});
