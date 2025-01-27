/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var tableGroups;
    var tableStations;
    var tableSwitch;

    var newUserGroups;
    var arrayGroups;
    var arrayStations;
    var myDropzone;

    var groupWidgets;


    tableStations = $('#table-user-stations').DataTable({
        "order": [[ 1, "asc" ]],
        "lengthMenu": [ 15, 25, 50, 75, 100 ],
        "pageLength": 25
    });

    tableStations.columns.adjust();

/**
 * First tab: GROUPS
 */
{
    // datatable
    $.fn.DataTable.ext.pager.numbers_length = 5;
    // datatable initialization
    tableGroups = $('#group-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "pagingType": 'simple_numbers',
        "layout": {
            bottomEnd: {
                paging: {
                    buttons: 5,
                    type: 'simple_numbers'
                }
            }
        },
        "columnDefs": [
            { "orderable": false, "targets": 0 },
            { "width": "80px", "targets": 0 },
            { "visible": system_admin, targets: 5 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    // retrieve groups list
    loadGroups();

    /**
     * Click event: Show group detail.
     */
    $('#group-table').on('click', '.show-group', function(e){
        e.preventDefault();
        // get table row element
        var tr = $(this).parent().parent();
        // get id stored inside tr element
        var id = parseInt(tr.data('id'));

        $('#user-menu-list').html('');

        // show tabs inside modal "Informazioni sui gruppi di appartenenza"
        $('.customtab a[href="#statuser"]').parent().show();
        $('.customtab a[href="#menuser"]').parent().show();
        $('.customtab a[href="#menuser"]').tab('show');

        // load details of an array of groups
        loadGroupsDetail([id], true);
    });

    /**
     * Click event: Edit group.
     */
    $('#group-table').on('click', '.edit-group', function(e){
        e.preventDefault();

        // update title
        $('.col-lg-5 h4.box-title').html("Modifica <strong>questo gruppo</strong>");

        // get row element
        var tr = $(this).parent().parent();
        // get id stored inside the row
        var id = parseInt(tr.data('id'));
        // get name and description of selected group from table row
        var name = tr.find('td:nth-child(3)').text();
        var desc = tr.find('td:nth-child(4)').text();
        if(desc == '--')
            desc = null;

        // fill form with retrieved metadata
        $('#new-group-id').val(id);
        $('#new-group-portals').val(tr.data('portals')).trigger('change');
        $('#new-group-name').val(name);
        $('#new-group-desc').val(desc);

    });

    /**
     * Click event: Delete group.
     */
    $('#group-table').on('click', '.delete-group', function(e){
        e.preventDefault();

        // get row element
        var tr = $(this).parent().parent();
        // get id stored inside the row
        var id = parseInt(tr.data('id'));

        // show confirm message
        swal({
            title: "Elimina gruppo",
            text: "Sei proprio sicuro di voler eliminare questo gruppo?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report via an ajax call
            var jqxhr = $.ajax({
                url: '/usr_admin_del_group',
                type: "post",
                dataType: "json",
                data: {
                    id: id
                }
            })
            .done(function(result) {
                // check result
                // if TRUE remove row from table and clear form
                // else show error message
                if(result){
                    // success message
                    swal("Gruppo eliminato", "Il gruppo è stato eliminato con successo!", "success");

                    tableGroups.row($("tr[data-id='"+id+"']")).remove().draw();
                    // clear form
                    clearFieldsGroups();
                }
                else{
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile eliminare il gruppo perchè <strong>GIÀ ASSOCIATO</strong> ad altri elementi (utenti, pagine ecc. ecc.)",
                        type: "warning",
                        html: true
                    });
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione del gruppo", "error");
            });
        });
    });

    // initialize plugin
    $("#new-group-portals").select2();

    /**
     * Validate form.
     */
    var groupValid = $('#form_group_new').validate({ // initialize the plugin
        rules: {
            "new-group-name" : {
                required: true
            }
        },
        messages: {
            "new-group-name" : {
                required: "Inserire il nome del gruppo"
            }
        },
        ignore: "",
    });

    /**
     * Submit group new/edit form.
     */
    $('#form_group_new').on('submit', function (e) {
        e.preventDefault();

        // check validity
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Gruppo non salvato!", "info");
            return false;
        };

        // get form element
        var form = $("#form_group_new");
        // get id from form
        var id = $("#new-group-id").val();
        var msg_err;
        var msg_ok;

        // different messages based on the type of action (insert or update)
        // if the id is defined then it's an update
        // otherwise it's an insert
        if(id){
            msg_ok = 'Il gruppo è stato modificato correttamente';
            msg_err = 'Si è verificato un errore durante la modifica del gruppo';
        }
        else{
            msg_ok = 'Il gruppo è stato aggiunto con successo.';
            msg_err = 'Si è verificato un errore durante l\'inserimento del nuovo gruppo';
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // put group via ajax call
        $.ajax({
            url: '/usr_admin_put_group',
            type: 'post',
            dataType: "json",
            data: form.serialize()
        })
        .done(function(result) {

            // check result
            // if true then refresh list and clear form
            if(result == 1){
                swal("Successo", msg_ok, "success");
                loadGroups();
                clearFieldsGroups();
            }
            else{
                // error message
                swal("Errore!", msg_err, "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", msg_err, "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    /**
     * Cancel button.
     */
    $('#form_group_new').on('click', '#cancel-group-form', function(e){
        e.preventDefault();
        // clear form
        clearFieldsGroups();
    });
}

/**
 * Second tab: USERS
 */
{
    // hide image container inside the form
    $('#img-container').hide();

    // datatable
    table = $('#user-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "columnDefs": [
            { "orderable": false, "targets": 0 },
            { "width": "80px", "targets": 0 },
            { "visible": system_admin, "targets": 4 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    table.columns.adjust();

    // set default value
    $('#new-user-session').val("86400"); // default 1 giorno

    // initialize plugin
    $("#filter-group, #filter-group-pages, #filter-group-stations, #filter-group-other").select2();

    /**
     * Change event on filter group
     */
    $("#filter-group").on("change", function(e){
        e.preventDefault();
        // get selected group id
        var grid = $(this).val();
        // retrieve all users linked to selected group
        loadUsers(grid);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    /**
     * Click event: retrieve user detail.
     */
    $('#user-table').on('click', '.show_user', function(e){
        e.preventDefault();

        // get ID stored inside the row
        var userid = parseInt($(this).parent().parent().data("id"));

        //check if the report's detail is already open
        if( $('#user'+userid).length ) {
            console.log('The user\'s detail is already open');
            // show tab
            $('.customtab a[href="#user' + userid + '"]').tab('show');
            return;
        }

        // get user metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_user_byid',
            type: "post",
            dataType: "json",
            data: {
                id: userid
            },
        })
        .done(function(result) {

            var user = result.user;

            arrayGroups = user.groups_id;

            // Create nav-link
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#user'+user.user_id+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+user.user_fullname+'</span>&nbsp&nbsp<i class="fa fa-times text-danger user-close-view" data-close="user'+user.user_id+'"></i></a> </a> </li>';
            $('.big-nav').append(html);

            // create tab's content
            html  = '<div class="tab-pane p-20" id="user'+user.user_id+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '        <h4 class="box-title">Informazioni</h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Nome</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_name+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Secondo nome</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_second_name+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Cognome</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_surname+'</div>\n';
            html += '            <label for="" class="control-label control-label col-2 col-form-label">Ruolo</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_role+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Numero cellulare</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_mobile+'</div>\n';
            html += '            <label for="" class="control-label control-label col-2 col-form-label">Numero telefono</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_phone+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Email</label>\n';
            html += '            <div class="col-4 view-param">'+user.user_email+'</div>\n';
            html += '            <label for="" class="control-label control-label col-2 col-form-label"> Utente attivo</label>\n';
            if(user.user_active == 'Si'){
                html += '            <div class="col-4 view-param"><span class="text-info"><i class="mdi mdi-checkbox-marked-circle"></i> '+user.user_active+'</span></div>\n';
            }
            else{
                html += '            <div class="col-4 view-param"><span class="text-danger"><i class="mdi mdi-close-circle"></i> '+user.user_active+'</span></div>\n';
            }
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Avatar</label>\n';
            html += '            <div class="col-4 view-param"><img src="'+user.user_avatar_thumb+'" class="img-responsive"></div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <h4 class="box-title">Sessione</h4>\n';
            html += '                <hr class="m-t-0 m-b-20">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label for="" class="control-label col-2 col-form-label">Scadenza</label>\n';
            html += '                    <div class="col-4 view-param">' + user.user_expiration_time_text + '</div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <h4 class="box-title">Azienda associata</h4>\n';
            html += '                <hr class="m-t-0 m-b-20">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label for="" class="control-label col-2 col-form-label">Azienda</label>\n';
            html += '                    <div class="col-10 view-param">'+user.company_name+' <a id="azienda-detail" href="#info-azienda" role="button" data-toggle="modal" data-compid="'+user.company_id+'" class="info-box"><i class="icon-info"></i> Info azienda</a></div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <h4 class="box-title">Gruppi di appartenenza</h4>\n';
            html += '                <hr class="m-t-0 m-b-20">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label for="" class="control-label col-2 col-form-label">Associato a</label>\n';
            html += '                    <div class="col-10 view-param">'+user.groups_name.join(' - ')+'<a id="group-detail" href="#info-gruppi" role="button" class="info-box" data-toggle="modal" data-groups="'+JSON.stringify(arrayGroups)+'"><i class="icon-info"></i> Info gruppi</a></div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <hr class="m-t-20 m-b-10">\n';
            html += '        <div class="form-actions">\n';
            html += '            <div class="row">\n';
            html += '                <div class="col-md-6">\n';
            html += '                    <div class="row">\n';
            html += '                        <div class="col-md-offset-3 col-md-9">\n';
            html += '                            <button type="submit" class="btn btn-info user-edit" data-userid="'+user.user_id+'"> <i class="ti-pencil"></i> Modifica</button>\n';
            html += '                            <button type="button" class="btn btn-secondary user-close-view" data-close="user'+user.user_id+'">Chiudi</button>\n';
            html += '                        </div>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '                <div class="col-md-6"> </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '    </div>\n';
            html += '</div>\n';

            // append content
            $('.big-tab').append(html);
            // show user's tab
            $('.customtab a[href="#user' + user.user_id + '"]').tab('show');

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dell'utente", "error");
        });
    });

    /**
     * Click event: Edit user
     */
    $('#user-table').on('click', '.edit_user', function(e){
        e.preventDefault();

        // clear fields
        clearFields();
        // change titles in the panel
        $('.customtab a[href="#new"] span:nth-child(2)').text("Modifica");
        $('#new h4').text("Modifica utente");
        $('#user-active').removeAttr("disabled");

        // get ID stored inside the row
        var userid = parseInt($(this).parent().parent().data("id"));

        // get user metadata and fill form
        getUserToEdit(userid);
    });

    /**
     * Click event: Reset user password.
     */
    $('#user-table').on('click', '.reset_user', function(e){
        e.preventDefault();

        // get ID stored inside the row
        var userid = parseInt($(this).parent().parent().data("id"));
        // get user's name and surname from table row
        var name = $(this).parent().parent().children().eq(1).text();
        var surname = $(this).parent().parent().children().eq(2).text();
        // create fullname
        var nc = name + ' ' + surname;

        // show confirm message
        swal({
            title: "RESET Password",
            text: "Vuoi resettare la password di <strong style=\"text-transform:uppercase;\">"+nc+"</strong>?<br>La nuova password verrà recapitata al <em>suo indirizzo email</em>.",
            type: "warning",
            html: true,
            showCancelButton: true,
            confirmButtonText: "Si, resetta",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // in case of confirmation send request via an ajax call
            var jqxhr = $.ajax({
                url: '/usr_admin_get_user_password',
                type: "post",
                dataType: "json",
                data: {
                    id: userid
                }
            })
            .done(function(result) {
                // check result
                // - if TRUE the success
                // - else error
                if(result){
                    swal("Password resettata", "Successo! La nuova password è stata inviata all\'utente via mail.", "success");
                }
                else{
                    swal("Errore!", "Errore durante il reset della password, riprova!", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante il reset della password, riprova!", "error");
            });

        });

    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // TAB
    /////////////////////////////////////////////////////////////////////
    /**
     * Click event: Show company detail.
     */
    $('.big-tab').on('click', '#azienda-detail', function(e){
        e.preventDefault();

        // get company id
        var compid = $(this).data('compid');
        // reset container
        $('#info-azienda-result').html('');
        // load company detail
        loadCompanyDetail(compid);
    });

    /**
     * Show groups detail.
     */
    $('.big-tab').on('click', '#group-detail', function(e){
        e.preventDefault();

        $('#user-menu-list').html('');

        // show tabs
        $('.customtab a[href="#statuser"]').parent().show();
        $('.customtab a[href="#menuser"]').parent().show();
        // set first tab as the active one
        $('.customtab a[href="#menuser"]').tab('show');

        // load metadata of an array of groups stored inside the button element
        var groups = $(this).data('groups');
        loadGroupsDetail(groups);
    });

    /**
     * Edit user by clicking the "Modifica" button in the user detail.
     */
    $('.big-tab').on('click', '.user-edit', function(e){
        e.preventDefault();

        // clear fields
        clearFields();
        // change title inside the panel
        $('.customtab a[href="#new"] span:nth-child(2)').text("Modifica");
        $('#new h4').text("Modifica utente");
        $('#user-active').removeAttr("disabled");

        // get user id stored inside the edit button
        var userid = parseInt($(this).data("userid"));

        // retrieve user's metadata and fill form
        getUserToEdit(userid);

        // remove detail tab
        $('.customtab a[href="#user' + userid + '"]').remove();
        $('.big-tab #user'+userid).remove();
    });

    /**
     * Close user detail view.
     */
    $('#user-tab').on('click', '.user-close-view', function(e){
        e.preventDefault();

        // get selector of the element to be closed
        var close = $(this).data("close");
        // close tab and remove it
        $('.customtab a[href="#' + close + '"]').remove();
        $('.big-tab #'+close).remove();
        // show main list
        $('.customtab a[href="#users_list"]').tab('show');
    });

    // /**
    //  * Close tab button.
    //  */
    // $('.tab-pane').on('click', '.close_tab', function(e){
    //     e.preventDefault();
    //     var close = $(this).data("close");
    //     console.log(close);

    //     setTimeout(function(){
    //         $('.customtab a[href="#' + close + '"]').remove();
    //         $('.tab-content #'+close).remove();
    //         $('.customtab a[href="#users_list"]').tab('show');

    //     }, 1);
    // });

    /////////////////////////////////////////////////////////////////////
    // END TAB

    // ADD NEW USER
    /////////////////////////////////////////////////////////////////////

    // initialize select2
    newUserGroups = $("#new-user-groups").select2();

    /**
     * Click event: Show company detail (during new user insertion).
     */
    $('#form_user_new').on('click', '#selected-azienda-detail', function(e){
        e.preventDefault();

        // get company Id selected by the user
        var compid = parseInt($('#new-user-comp').val());

        // clear container
        $('#info-azienda-result').html('');
        // retrieve company's metadata and fill modal
        loadCompanyDetail(compid);
    });

    /**
     * Show groups detail (during new user insertion).
     */
    $('#form_user_new').on('click', '#selected-group-detail', function(e){
        e.preventDefault();

        // clear container
        $('#user-menu-list').html('');

        // get the arrays of selected groups
        arrayGroups = [];
        var sel_groups = newUserGroups.select2('data');

        // for each group get ID and push it in a temporary variable
        $.each(sel_groups, function(index, value) {
            arrayGroups.push(parseInt(value.id));
        });

        // show tabs
        $('.customtab a[href="#statuser"]').parent().show();
        $('.customtab a[href="#menuser"]').parent().show();
        // set the first tab as the active one
        $('.customtab a[href="#menuser"]').tab('show');
        // load metadata of an array of groups
        loadGroupsDetail(arrayGroups);
    });

    // form validation
    $('#form_user_new').validate({ // initialize the plugin
        rules: {
            "new-user-name" : {
                required: true
            },
            "new-user-surname" : {
                required: true
            },
            "new-user-mobile":{
                regex: '^([+][0-9]{2}(\-|\\s)?)?[0-9]{1,10}$'
            },
            "new-user-phone":{
                number: true
            },
            "new-user-email" : {
                required: true,
                email: true
            },
            "new-user-groups" : {
                required: true
            }
        },
        messages: {
            "new-user-name" : {
                required: "Inserire il nome dell'utente"
            },
            "new-user-surname" : {
                required: "Inserire il cognome dell'utente"
            },
            "new-user-mobile":{
                regex: "Inserire un numero di cellulare valido (+39 XXX)"
            },
            "new-user-phone":{
                number: "Inserire un numero di telefono valido"
            },
            "new-user-email" : {
                required: "Inserire l'email dell'utente",
                email: "Inserire un indirizzo email valido"
            },
            "new-user-groups" : {
                required: "Inserire almeno un gruppo di appartenenza dell'utente",
            }
        },
        ignore: "",
    });

    // START Dropzone //
    var url = "/usr_admin_put_user";

    // initialize dropzone plugin
    myDropzone = new Dropzone(".dropzone", {
        url: url,
        paramName: "file", // The name of the file param that gets transferred. Defaults to file
        uploadMultiple : false, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
        maxFiles: 1,
        acceptedFiles: "image/*",
        maxFilesize: 50, // MB
        addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
        clickable: true, // If true, the dropzone element itself will be clickable
        autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
        dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui una foto',
        dictResponseError: 'Caricamento fallito!',
        dictRemoveFile: 'Rimuovi file',
        dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
        dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti.',
        dictCancelUpload: 'Annulla caricamento',
        dictUploadCanceled: 'Il caricamento è stato annullato.',
        dictFileTooBig: 'La dimensione del file è superiore ai 15 MB.',
        dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
        // success: function(file, msg){},
        error: function(file, error) {
            swal("Errore", "Si è verificato un errore", "error");
        },
        maxfilesexceeded: function(file) {
            swal("Errore", "Hai raggiunto il massimo numero di file consentiti.", "error");
            this.removeFile(file);
        }
    });

    /**
     * Function called when using Dropzone submit.
     */
    myDropzone.on("sending", function(file, xhr, formData) {
        // add form fields to the dropzone submission object
        var formValues = $('#form_user_new').serializeArray();

        $.each(formValues, function(index, input){
            formData.append(input.name, input.value);
        });
    });

    /**
     * Function called at the Dropzone submit return.
     */
    myDropzone.on("success", function(file, response) {
        // get id stored inside the form
        var id = $("#new-user-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is defined then it's an update
        // otherwise it's an insert
        if(id){
            msg_ok = 'L\'utente è stato modificato correttamente';
            msg_err = 'Si è verificato un errore durante la modifica dell\'utente';
        }
        else{
            msg_ok = 'L\'utente è stato aggiunto con successo! A breve riceverà una mail con una password temporanea.';
            msg_err = 'Si è verificato un errore durante l\'inserimento del nuovo utente';
        }

        // check result
        // - if equal to 1 then success
        // - if equal to -1 then a user already exists with the same email
        // - else error
        if(response == 1){
            // success message
            swal("Successo", msg_ok, "success");

            // refresh users taking care of selected group
            var grid = parseInt($("#filter-group").val());
            loadUsers(grid);

            // show tab with list of users
            $('.customtab a[href="#users_list"]').tab('show');
            // clear form
            clearFields();
        }
        else if( response == -1){
            // show warning message
            swal("Attenzione!", "Nel sistema è già presente un utente con la mail inserita. Cambiare email per poter eseguire il salvataggio", "warning");
            // manage files, add error class and re-queue them
            file.previewElement.classList.add("dz-error");
            file.status = Dropzone.QUEUED;
        }
        else{
            swal("Errore!", msg_err, "error");
            // manage files, add error class and re-queue them
            file.previewElement.classList.add("dz-error");
            file.status = Dropzone.QUEUED;
        }
    });
    // END Dropzone //

    /**
     * Submit user new/edit form.
     */
    $('#form_user_new').on('submit', function (e) {
        e.preventDefault();

        // check form validity
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Report non salvato!", "info");
            return false;
        };

        // Check if attachments exist:
        // if exists     -> use the dropzone submit function and add fields of the form to the submission
        // if not exist  -> normal form submit
        if (myDropzone.getQueuedFiles().length > 0) {
            myDropzone.processQueue();
        }
        else {
            // get form element
            var form = $("#form_user_new");
            // get user id stored inside the form
            var id = $("#new-user-id").val();
            var msg_err;
            var msg_ok;

            // different messages based on the type of action (insert or update)
            // if the id is defined then it's an update
            // otherwise it's an insert
            if(id){
                msg_ok = 'L\'utente è stato modificato correttamente';
                msg_err = 'Si è verificato un errore durante la modifica dell\'utente';
            }
            else{
                msg_ok = 'L\'utente è stato aggiunto con successo! A breve riceverà una mail con una password temporanea.';
                msg_err = 'Si è verificato un errore durante l\'inserimento del nuovo utente';
            }

            // add / edit user via an ajax call
            $.ajax({
                type: 'post',
                url: '/usr_admin_put_user',
                data: form.serialize()
            }).done(function(result) {

                // check result
                // - if equal to 1 then success
                // - if equal to -1 then a user already exists with the same email
                // - else error
                if(result == 1){
                    // success message
                    swal("Successo", msg_ok, "success");

                    // refresh users list taking care of groups filter
                    var grid = parseInt($("#filter-group").val());
                    loadUsers(grid);

                    // show main list
                    $('.customtab a[href="#users_list"]').tab('show');
                    // clear form
                    clearFields();
                }
                else if( result == -1){
                    // warning message
                    swal("Attenzione!", "Nel sistema è già presente un utente con la mail inserita. Cambiare email per poter eseguire il salvataggio", "warning");
                }
                else
                    // error message
                    swal("Errore!", msg_err, "error");

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", msg_err, "error");
            });
        }
    });

    /**
     * Cancel button.
     */
    $('#form_user_new').on('click', '#annulla_report', function(e){
        e.preventDefault();

        // show mail list
        $('.customtab a[href="#users_list"]').tab('show');
        // clear form
        clearFields();
    });

    // first load, retrieve all users
    loadUsers(-1);
}

/**
 * Third tab: PAGES
 */
{
    /**
     * Accordion events: hide and show of collapsible elements
     * Take care of icons and classes based on accordion status
     */
    $('#main-tab').on('show.bs.collapse', '.collapse', function(e){
        if ($(this).is(e.target)) {
            $(this).parent().find(".icon-arrow-right").removeClass("icon-arrow-right").addClass("icon-arrow-down");
        }
    }).on('hide.bs.collapse', '.collapse', function(e){
        if ($(this).is(e.target)) {
            $(this).parent().find(".icon-arrow-down").removeClass("icon-arrow-down").addClass("icon-arrow-right");
        }
    });

    // Toggles the collapsible element on invocation
    $('#accordion-as-table').collapse({
        toggle: true
    });

    // hide container and table's headers
    $("#pages-group-detail").hide();
    $(".like-head").hide();


    /**
     * Change event on group filter
     */
    $("#filter-group-pages").on("change", function(e){
        e.preventDefault();

        // get selected group ID
        var grid = parseInt($(this).val());
        // load grants for selected group
        loadGroupPagesGrants(grid);

        // check ID
        // if equal to -1 then hide main container otherwise show it
        if(grid != -1){
            $("#pages-group-detail").show();
        }
        else{
            $("#pages-group-detail").hide();
        }

    });

    /**
     * CLick event: show groups detail.
     */
    $('#main-tab').on('click', '#pages-group-detail', function(e){
        e.preventDefault();

        // clear modal element
        $('#user-menu-list').html('');

        // hide station tab and show menu tab
        $('.customtab a[href="#statuser"]').parent().hide();
        $('.customtab a[href="#menuser"]').parent().show();
        $('.customtab a[href="#menuser"]').tab('show');
        // get selected group ID
        var group = parseInt($("#filter-group-pages").val());
        // load metadata of an array of groups (1 is the default group always existing)
        loadGroupsDetail([1, group]);
    });


    /**
     * Change event on permission switch: Visualizza
     */
    $( "#accordion-as-table" ).on( "change", ".view-pg", function() {
        // get new status
        var status = $(this).prop('checked');
        // get row element
        var myRow = $(this).parent().parent().parent();

        // check status
        // if true then show the other permission switches
        // else disable iud (insert, update, delete) switches and hide them
        if(status == true){
            myRow.find('.hide-el').show();
        }
        else{
            myRow.find('.mody-pg').bootstrapToggle('off');
            myRow.find('.hide-el').hide();
        }
    });
}

/**
 * Forth tab: STATIONS
 */
{
    // datatable
    tableSwitch = $('#table-switch-stations').DataTable({
        "columnDefs": [
            { "width": "10%", "targets": 0 },
            { "width": "30%", "targets": 1 },
            { "width": "12%", "targets": 2 },
            { "width": "12%", "targets": 3 },
            { "width": "12%", "targets": 4 },
            { "width": "12%", "targets": 5 },
            { "width": "12%", "targets": 6 },
        ],
        "order": [[ 1, "asc" ]],
        "autoWidth": false
    });

    // initialize bootstrap toggle
    $( "#table-switch-network input[type=checkbox]" ).bootstrapToggle();

    // hide rows of switches
    $( "#table-switch-network-row" ).hide();
    $( "#table-switch-stations-row" ).hide();

    /**
     * Change event: Group, province and network selections (filters).
     */
    $("#filter-group-stations, #filter-province-stations, #filter-network-stations").on("change", function(e){
        e.preventDefault();

        // get selected ID from filters
        var grid = parseInt($("#filter-group-stations").val());
        var prid = parseInt($("#filter-province-stations").val());
        var netid = parseInt($("#filter-network-stations").val());

        // load stations grants of selected group
        loadGroupStationsGrants(grid, prid, netid);
        $( "#table-switch-stations-row" ).show();
    });

    /**
     * Change event: Group selection.
     */
    $("#filter-group-stations").on("change", function(e){
        // get group ID
        var grid = parseInt($(this).val());

        // check ID
        // if group is equal to -1 then hide "all stations" row otherwise show it
        if(grid != -1){
            $( "#table-switch-network-row" ).show();
        }
        else{
            $( "#table-switch-network-row" ).hide();
        }

    });

    /**
     * Change event: change status of "view" grant inside "all stations" row
     */
    $( "#table-switch-network" ).on( "change", ".view-st", function(e) {

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get new status
        var status = $(this).prop('checked');
        // check new status
        // if true then show iud grants inside "all stations" row
        // otherwise hide them
        if(status == true){
            $('#table-switch-network .hide-el').show();

        }else{
            $('#table-switch-network .mody-st').bootstrapToggle('off');
            $('#table-switch-network .hide-el').hide();
        }

        // loop through the array of stations
        // for each element set "view" grant equal to the new status
        // and turn to false all others grants
        $.each(arrayStations, function(index, el) {

            if( !el )
                return;

            arrayStations[index].sho = status;
            arrayStations[index].ins = false;
            arrayStations[index].mod = false;
            arrayStations[index].del = false;

        });

        // update switches status for all stations
        updateStationsGrants(-1);
    });

    /**
     * Change event: change status of "iud" grants inside "all stations" row
     */
    $( "#table-switch-network" ).on( "change", ".mody-st", function() {

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get attributes and row of changed element
        var myClass = $(this).parent().parent().parent().attr('class');
        var myRow = $(this).parent().parent().parent().parent();
        // get "view" grant inside the row
        var status = myRow.find('.view-st').prop('checked');
        // if "view" grant is disabled then user cannot change other grants
        // return and do nothing
        if(status == false)
            return;

        // get checked properties of changed element
        var checkedTotal = myRow.find('.'+myClass+' input').prop('checked');
        // loop through the array of stations
        // for each element set changed grant equal to the new status
        $.each(arrayStations, function(index, el) {

            if( !el )
                return;

            arrayStations[index][myClass] = checkedTotal;
        });

        // update switches status for all stations
        updateStationsGrants(-1);
    });

    /**
     * Change event: change status of "view" grant for a specific station
     */
    $( "#table-switch-stations" ).on( "change", ".view-st", function() {

        // get new status
        var status = $(this).prop('checked');
        // get ID of updated station
        var stid = $(this).parent().parent().parent().data("id");
        // get row element
        var myRow = $(this).parent().parent().parent();

        // check new status
        // if true then show "iud" grants
        // otherwise disable and hide them
        if(status == true){
            myRow.find('.hide-el').show();
        }
        else{
            myRow.find('.mody-st').bootstrapToggle('off');
            myRow.find('.hide-el').hide();
        }
    });
}

/**
 * Fifth tab: OTHERS
 */
{
    // hide main container
    $('.other-row').hide();
    // initialize switches
    $(".cod-active-show" ).bootstrapToggle();

    /**
     * Change event: group selection.
     */
    $("#filter-group-other").on("change", function(e){
        e.preventDefault();

        // get ID of selected group
        var grid = parseInt($(this).val());
        // retrieve from server group's grants
        loadGroupOthersGrants(grid);

        // if group ID is equal to -1 then hide main container
        // else show it
        if(grid != -1){
            $('.other-row').show();
        }
        else{
            $('.other-row').hide();
        }

    });

    /**
     * Change VIEW grants of channels section.
     */
    $( "#other-tab" ).on( "change", ".view-ch", function() {

        // get new status
        var status = $(this).prop('checked');
        // get channel id stored inside the row
        var chid = $(this).parent().parent().parent().data("id");
        // get row element
        var myRow = $(this).parent().parent().parent();

        // if new status is true then show other grants
        // else disable and hide them
        if(status == true){
            myRow.find('.hide-el').show();
        }
        else{
            myRow.find('.mody-ch').bootstrapToggle('off');
            myRow.find('.hide-el').hide();
        }
    });

    // HOMEPAGE - LINKS NEI WIDGETS
    /////////////////////////////////////////////////////////////////////////

    // initialize select2 and hide form fields
    $( "#link-page-select" ).select2();
    $( "#link-page-selection, #link-external-selection" ).hide();

    /**
     * Hide event of modal "DESTINAZIONE WIDGET"
     */
    $("#widget-destination").on("hide.bs.modal", function(){
        // clear form
        clearFieldsDestination();
    });

    /**
     * Click event: Edit link destination.
     */
    $('#table-switch-widgets').on('click', '.edit-link', function(e){
        e.preventDefault();

        // get tr element and widget's id stored inside it
        var tr = $(this).parent().parent();
        var wdgId = parseInt(tr.data('id'));

        // retrieve metadata of clicked widget from global variable
        var wdgName = groupWidgets[wdgId].wdg_name;
        var wdgDesc = groupWidgets[wdgId].wdg_description;
        var wdgDest = JSON.parse(groupWidgets[wdgId].gw_dest);

        // fill input and modal titles
        $('#widget-id').val(wdgId);
        $('#form-link-widget h5').text(wdgName);
        $('#form-link-widget h6').text(wdgDesc);

        // get destination type and set it inside the form
        var type = wdgDest.type;
        $('#form-link-widget input[name="add-link"]').filter('[value='+type+']').prop('checked', true).trigger('change');

        // different fields based on destination type. 3 cases:
        // - none / default : no destination
        // - page : link refers to a page inside the portal
        // - external : link refers to an external page
        switch(type){
            case 'default':
            case 'none':

                break;
            case 'page':
                $('#link-page-title').val(wdgDest.title);
                $('#link-page-select').val($('#link-page-select option[data-link="'+wdgDest.link+'"]').val()).trigger('change');

                break;
            case 'external':
                $('#link-external-title').val(wdgDest.title);
                $('#link-external-link').val(wdgDest.link);
                break;

            default:
                break;
        }
    });

    /**
     * Chanke event: Link destination form.
     */
    $( "#form-link-widget" ).on( "change", "input[name='add-link']", function() {
        // get new destination type
        var name = $(this).attr('id');

        // take care of fields visibility based on selected typology
        switch(name) {
            case 'link-page':
                    $( "#link-external-selection" ).hide();
                    $( "#link-page-selection" ).show();
                break;
            case 'link-external':
                    $( "#link-external-selection" ).show();
                    $( "#link-page-selection" ).hide();
                break;
            default:
                    $( "#link-page-selection, #link-external-selection" ).hide();
                break;
        }
    });

    /**
     * Validate form.
     */
    $('#form-link-widget').validate({ // initialize the plugin
        rules: {
            "link-page-title" : {
                required: function(element){
                    return $("#link-page").is(":checked");
                },
            },
            "link-page-select" : {
                required: function(element){
                    return $("#link-page").is(":checked");
                },
                min: function(element){
                    return $("#link-page").is(":checked") ? 0 : -1
                }
            },
            "link-external-title" : {
                required: function(element){
                    return $("#link-external").prop("checked");
                },
            },
            "link-external-link" : {
                required: function(element){
                    return $("#link-external").prop("checked");
                },
            },
        },
        messages: {
            "link-page-title" : {
                required: "Inserire titolo del link"
            },
            "link-page-select" : {
                required: "Inserire pagina di destinazione",
                min: "Inserire pagina di destinazione",
            },
            "link-external-title" : {
                required: "Inserire titolo del link"
            },
            "link-external-link" : {
                required: "Inserire link di destinazione"
            },
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
     * Link destination form submit.
     */
    $('#form-link-widget').on('submit', function (e) {
        e.preventDefault();

        // check form validity
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare", "info");
            return false;
        };

        // get form element
        var form = $("#form-link-widget");
        var msg_err = 'Si è verificato un errore durante il salvataggio della destinazione';
        var msg_ok  = 'La destinazione del widget è stata salvata correttamente';

        // get widget id
        var wdgId = parseInt($('#widget-id').val());
        // get selected group
        var grid = parseInt($('#filter-group-other').val());

        // get metadata based on destination typology
        var obj={};
        var type = $('#form-link-widget input[name="add-link"]:checked').val();
        switch(type){
            case 'default':
                obj.type = type;
                break;
            case 'page':
                obj.type = type;
                obj.title = $('#link-page-title').val();
                obj.link = $('#link-page-select option:selected').data('link');
                break;
            case 'external':
                obj.type = type;
                obj.title = $('#link-external-title').val();
                obj.link = $('#link-external-link').val();
                break;
            case 'none':
                obj.type = type;
            default:
                break;
        }

        // send data via an ajax call
        $.ajax({
            type: 'post',
            url: '/usr_admin_put_widget_destination',
            data:{
                id: wdgId,
                grid: grid,
                obj: JSON.stringify(obj)
            }
        }).done(function(result) {
            // check result
            // if TRUE then show success message and update global variable
            // else show error message
            if(result){
                swal("Successo", msg_ok, "success");

                groupWidgets[wdgId].gw_dest = JSON.stringify(obj);
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
     * Click event: Cancel button.
     */
    $("#form-link-widget-cancel, #form-link-widget-close").on("click", function(e){
        e.preventDefault();
        // clear fields of form
        clearFieldsDestination();
    });
}

    // FUNCTIONS
    /**
     * Function that clears ad resets all group form's fields.
     * No args needed
     */
    function clearFieldsGroups(){
        $('.col-lg-5 h4.box-title').html("Inserisci <strong>nuovo gruppo</strong>");
        // take care of select2
        $('#form_group_new .clear-input').val('');
        $('#form_group_new select').val([]).trigger('change');
    }

    /**
     * Function that clears and resets all user form's fields.
     * No args needed
     */
    function clearFields(){

        // reset form fields
        $('#new-user-id').val("");
        $('#form_user_new').find("input[type=text], textarea").val("");
        $('#new-user-session').val("86400");
        // reset active checkbox
        $('#user-active').prop("checked", true);
        $('#user-active').attr("disabled", true);

        $('#new-user-portal').val(-1);
        $('#new-user-comp').val(1);
        // Select the option with a value of '1' (Shared)
        newUserGroups.val(['1']);
        // Notify any JS components that the value changed
        newUserGroups.trigger('change');

        // reset dropzone
        myDropzone.removeAllFiles(true);
        // clear and hide images container
        $('#img-container').hide();
        $('#img-container').empty();
        // reset dropzone classes
        $('#dpz-container').addClass("col-10");
        $('#dpz-container').removeClass("col-8");

        // reset titles
        $('.customtab a[href="#new"] span:nth-child(2)').text("Nuovo");
        $('#new h4').text("Inserisci nuovo utente");

        // reset form error
        $('#form_user_new').validate().resetForm();
    }

    /**
     * Function that clears ad resets all link destination form's fields.
     * No args needed
     */
    function clearFieldsDestination(){
        $( ".clear-input" ).val('');
        $( ".clear-select" ).val(-1);
        $('#link-page-select').trigger('change');
        // take care of radio buttons
        $("#form-link-widget #link-default").prop("checked", true).trigger('change');
    }



    /**
     * Function that retrieves the groups.
     * No args needed
     */
    function loadGroups(){

        // reset datatable
        if ( tableGroups )
            tableGroups.clear();

        // clear select
        $('#new-user-groups, #filter-group, #filter-group-pages, #filter-group-stations, #filter-group-other').empty();
        // get portal's groups
        var jqxhr = $.ajax({
            url: '/usr_admin_get_groups',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            var groups = result.groups;

            // check if at least one element exists
            if( groups.length > 0 ){

                // variables for dinamically building the html
                var html= '';
                var htmlOptions = '';
                // loop through all elements
                // for each group, build a html row and option to be added to the datable and all selects
                $.each(groups, function(index, value) {

                    html += '<tr data-id="'+value.gr_id+'" data-portals="'+JSON.stringify(value.gr_portals)+'">';
                    html += '    <td class="bobo-nowrap">';
                    html += '        <a href="#info-gruppi" class="show-group" data-toggle-second="tooltip" data-original-title="Visualizza gruppo" data-toggle="modal"> <i class="ti-zoom-in text-info"></i> </a>';
                    html += '        <a href="javascript:void(0)" class="edit-group" data-toggle-second="tooltip" data-original-title="Modifica gruppo"> <i class="icon-pencil text-info"></i> </a>';
                    // erasable only if group is not the portal admin
                    if(! value.gr_admin){
                        html += '        <a href="javascript:void(0)" class="delete-group" data-toggle-second="tooltip" data-original-title="Elimina gruppo"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    html += '    </td>';
                    html += '    <td>'+value.gr_id+'</td>';
                    html += '    <td>'+value.gr_name+'</td>';
                    html += '    <td>'+(value.gr_desc ? value.gr_desc : '--')+'</td>';
                    if(value.gr_admin){
                        html += '    <td><i class="fa fa-check-circle text-info" aria-hidden="true"></i></td>';
                    }
                    else{
                        html += '    <td></td>';
                    }

                    html += '    <td>'+value.gr_portals_names.join(', ')+'</td>';
                    html += '</tr>';


                    htmlOptions += '<option value="'+value.gr_id+'">'+value.gr_name+'</option>';
                });

                // add rows to datatable by using html object
                tableGroups.rows.add($( html ));
                // redraw it
                tableGroups.draw();
                // initializes the tooltips of all lines
                // loop through each table row contained in all pages (not only the visible one )
                tableGroups.rows({page: 'all'}).every(function() {
                    var row = this;
                    // get all tr node and transform it into a jquery items
                    // in order to find all tooltip elements
                    $(row.node())
                        .find('[data-toggle-second="tooltip"]')
                        .tooltip();
                });

                // take care of all selects
                // for each select, append the first default option
                $('#new-user-groups').append('<option value="1" selected>Shared</option>');
                $('#new-user-groups').append(htmlOptions);
                $('#filter-group').append('<option value="-1">Tutti i gruppi</option>');
                $('#filter-group').append(htmlOptions);
                $('#filter-group-pages, #filter-group-stations, #filter-group-other').append('<option value="-1">Seleziona un gruppo...</option>');
                $('#filter-group-pages').append(htmlOptions);
                $('#filter-group-stations').append(htmlOptions);
                $('#filter-group-other').append(htmlOptions);
            }
            else{
                // redraw it
                tableGroups.draw();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli utenti del portale", "error");
        });
    }

    /**
     * Function that retrieves the users of a given group.
     *
     * @param {integer} grid: Group ID
     */
    function loadUsers(grid){

        // reset datatable
        if ( table )
            table.clear();

        // get users via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_users',
            type: "post",
            dataType: "json",
            data: {
                grid: grid
            }
        })
        .done(function(result) {
            var users = result.users;

            // check if at least one element exists
            if( users.length > 0 ){
                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each user, build a html row to be added to the datable
                $.each(users, function(index, value) {
                    var notactive = '';
                    if (value.user_active == false){
                        notactive = 'not-active';
                    }
                    html += '<tr data-id="'+value.user_id+'" class="'+notactive+'">';
                    html += '    <td class="bobo-nowrap">';
                    html += '        <a href="javascript:void(0)" class="show_user" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                    html += '        <a href="javascript:void(0)" class="edit_user" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                    if(value.user_active == true){
                        html += '        <a href="javascript:void(0)" class="reset_user" data-toggle="tooltip" data-original-title="Reset password"> <i class="text-danger fal fa-key"></i> </a>';
                    }
                    html += '    </td>';
                    html += '    <td>'+value.user_name+'</td>';
                    html += '    <td>'+value.user_surname+'</td>';
                    html += '    <td>'+value.user_email+'</td>';
                    html += '    <td>'+value.portal_name+'</td>';
                    html += '    <td>'+value.company_name+'</td>';
                    if (value.user_admin == true){
                        html += '    <td><i class="fa fa-check-circle text-info" aria-hidden="true"></i></td>';
                    }
                    else{
                        html += '    <td></td>';
                    }

                    if (value.user_active == true){
                        html += '    <td><i class="fa fa-check-circle text-info" aria-hidden="true"></i></td>';
                    }
                    else{
                        html += '    <td></td>';
                    }

                    html += '</tr>';

                });

                // add rows to datatable by using html object
                table.rows.add($( html ));
                // redraw it
                table.draw();
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
            }
            else{
                // redraw it
                table.draw();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli utenti del portale", "error");

        });
    }

    /**
     * Function that retrieves the information of a given company.
     *
     * @param {integer} compid Company ID.
     */
    function loadCompanyDetail(compid){

        // get company detail via ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_comp_detail',
            type: "post",
            dataType: "json",
            data: {
                compid: compid
            }
        })
        .done(function(result) {
            console.dir(result);
            var company = result.comp;
            // variable for dinamically building the html
            var html = '';
            html += '<form class="form-horizontal view-form" role="form">\n';
            html += '    <div class="form-body">\n';
            html += '        <div class="logo"><img src="'+company.comp_logo+'"></div>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <h4 class="box-title">Generali</h4>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">Nome:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static">'+company.comp_name+'</p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">Indirizzo:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static">'+company.comp_address+'</p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">N° telefono:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static">'+company.comp_phone+'</p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">Sito web:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static"> <a href="'+company.comp_web+'" target="_blank"> '+company.comp_web+' </a></p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">Email:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static"> '+company.comp_email+' </p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '        <div class="row">\n';
            html += '            <div class="col-md-12">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label class="control-label text-right col-md-3">Descrizione:</label>\n';
            html += '                    <div class="col-md-9">\n';
            html += '                        <p class="form-control-static">'+company.comp_desc+'</p>\n';
            html += '                    </div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '    </div>\n';
            html += '</form>\n';

            // append detail to modal
            $('#info-azienda-result').append(html);
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dell'azienda", "error");
        });
    }

    /**
     * Function that retrieves the information of one or more given groups.
     *
     * @param {integer[]} groups Array of group ids.
     * @param {boolean}   hideDefault Boolean value to hide some details about the menu (non mandatory)
     */
    function loadGroupsDetail(groups, hideDefault){

        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_groups_detail',
            type: "post",
            dataType: "json",
            data: {
                groups_id: JSON.stringify(groups)
            }
        })
        .done(function(result) {

            // MENU TAB

            var menu = result.menu;
            // variables for dynamically building menu structure
            var last_level = 2;
            var html = '<ul>';

            if(menu[0].user_admin == true)
                $('#show-admin').show();
            else
                $('#show-admin').hide();

            // loop through all elements
            // for each element, build a html list item to be added to the modal
            $.each(menu, function(index, menu_element) {

                // check user grants
                var grants = parseInt(menu_element.total_user_grants, 2);
                var close_li = false;

                if(menu_element.page_href != null){
                    close_li= true;
                }
                // compare the level of the current element with the previous one
                // - if equal then nothing to do: build a list item with icons for each user grant
                // - if greater then add another level of menu with a new ul element and create a new list item
                // - if lower then close "diff" levels of menu and create a new list item
                if (menu_element.menu_page_level == last_level) {

                    html += '<li>'+menu_element.page_name;

                    if(grants != null){
                        if(grants & 4)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Aggiunta nuovi elementi"> <i class=" icon-plus text-info"></i> </a>';
                        if(grants & 2)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica degli elementi"> <i class="icon-pencil text-info"></i> </a>';
                        if(grants & 1)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Eliminazione degli elementi"> <i class="icon-trash text-danger"></i> </a>';
                    }

                    if (close_li){
                        // <!-- Close </li> because element cannot be a dropdown menu -->
                        html += '</li>';
                    }

                }
                else if (menu_element.menu_page_level > last_level){

                    html += '<ul>';
                    html += '   <li>'+menu_element.page_name;

                    if(grants != null){
                        if(grants & 4)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Aggiunta nuovi elementi"> <i class=" icon-plus text-info"></i> </a>';
                        if(grants & 2)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica degli elementi"> <i class="icon-pencil text-info"></i> </a>';
                        if(grants & 1)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Eliminazione degli elementi"> <i class="icon-trash text-danger"></i> </a>';
                    }

                    if (close_li){
                        // <!-- Close </li> because element cannot be a dropdown menu -->
                        html += '</li>';
                    }
                }
                else {

                    for(var i= last_level; i > menu_element.menu_page_level; i--){

                        html += '   </ul>';
                        html += '</li>';
                    }

                    html += '<li>'+menu_element.page_name;
                    if(grants != null){
                        if(grants & 4)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Aggiunta nuovi elementi"> <i class=" icon-plus text-info"></i> </a>';
                        if(grants & 2)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica degli elementi"> <i class="icon-pencil text-info"></i> </a>';
                        if(grants & 1)
                            html += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Eliminazione degli elementi"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    if (close_li){
                        // <!-- Close </li> because element cannot be a dropdown menu -->
                        html += '</li>';
                    }
                }
                // update previous level with the current one
                last_level = menu_element.menu_page_level;
            });

            // close all levels of menu
            for(; last_level > 2; last_level-- ){
                html += '</ul>';
            }

            // check flag
            // if FALSE then create menu with default pages
            if( ! hideDefault ){
                html += '   <li>Help</li>';
                html += '   <li>FAQ';
                html += '       <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Aggiunta nuovi elementi"> <i class=" icon-plus text-info"></i> </a>';
                html += '       <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica degli elementi"> <i class="icon-pencil text-info"></i> </a>';
                html += '       <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Eliminazione degli elementi"> <i class="icon-trash text-danger"></i> </a>';
                html += '   </li>';
                html += '   <li class="text-danger">Esci</li>';
            }
            html += '</ul>';
            // append structure to modal
            $('#user-menu-list').append(html);

            // STATIONS TAB

            // check stations table
            // if not empty then clear it
            if ( tableStations ){
                tableStations.clear();
            }

            var stations = result.stations;
            // check if at least one element exists
            if( stations.length > 0 ){
                // variable for dinamically building the html
                var html_station = '';
                // loop through all elements
                // for each station, build a html row to be added to the datable
                $.each(stations, function(index, value) {

                    var grants_station = parseInt(value.total_user_grants, 2);

                    html_station += '<tr>';
                    html_station += '   <td>'+value.station_id+'</td>';
                    html_station += '   <td>'+value.station_name+'</td>';
                    html_station += '   <td>'+value.province_code+'</td>';
                    html_station += '   <td>'+value.station_network_type_desc+'</td>';
                    if (value.station_active == true){
                        html_station += '    <td><i class="fa fa-check-circle text-info" aria-hidden="true"></i></td>';
                    }
                    else{
                        html_station += '    <td></td>';
                    }

                    // check grants
                    html_station += '   <td>';
                    if(grants_station != null){
                        if(grants_station & 4)
                            html_station += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Aggiunta nuovi elementi"> <i class=" icon-plus text-info"></i> </a>';
                        if(grants_station & 2)
                            html_station += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica degli elementi"> <i class="icon-pencil text-info"></i> </a>';
                        if(grants_station & 1)
                            html_station += '<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Eliminazione degli elementi"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    html_station += '   </td>';

                    html_station += '</tr>';

                });

                // add rows to datatable by using html object
                tableStations.rows.add($( html_station ));
                // redraw it
                tableStations.draw();
            }
            else{
                // redraw it
                tableStations.draw();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dei gruppi", "error");

        });
    }

    /**
     * Function that retrieves the page grants of a given group.
     *
     * @param {integer} grid Group ID.
     */
    function loadGroupPagesGrants(grid){

        // reset contents
        $("#accordion-as-table").empty();
        // check selected group id
        // if equal to -1 then hide container, return and do nothing
        if(grid == -1){
            $(".like-head").hide();
            return;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_group_pages_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid
            }
        })
        .done(function(result) {

            // check result
            // if OK then build menu structure
            if(result.res == 'OK'){
                var pages = result.pages;
                var admin = result.admin;
                // check if at least one element exists
                if(pages.length > 0){
                    // variables for dinamically building the html
                    var html= '';
                    // minimum level
                    var lastLevel = 2;
                    var accordionCnt = -1;
                    // loop through all elements
                    // for each page, build a html item to be added to the list
                    $.each(pages, function(index, el) {

                        var classInsert = '';
                        var classUpdate = '';
                        var classDelete = '';
                        // check if user is a system administrator
                        // if false then store inside variables grants of the selected group
                        if(system_admin == false){
                            classInsert = admin[index].class_insert;
                            classUpdate = admin[index].class_update;
                            classDelete = admin[index].class_delete;
                        }

                        // compare the level of the current element with the previous one
                        // - if equal then nothing to do: build a list item based on element typology (leaf or not)
                        // - if greater then go down one level, item inside the accordion
                        // - if lower then close "diff" levels of menu and create a new list item
                        if (el.menu_page_level == lastLevel) {

                            // if it is not a leaf = expanded FALSE then create accordion
                            if(el.menu_page_expanded == false){
                                // increase accordions counter
                                accordionCnt++;

                                html += '<div class="card">';
                                html += '    <div class="card-header" id="heading-'+accordionCnt+'">';
                                html += '        <button aria-controls="collapse-'+accordionCnt+'" aria-expanded="false" class="btn btn-link" data-target="#collapse-'+accordionCnt+'" data-toggle="collapse"><i class="'+el.menu_page_icon+'"></i>  '+el.page_name+' <span><i class="icon-arrow-right"></i></span></button>';
                                html += '    </div>';
                                html += '    <div aria-labelledby="heading-'+accordionCnt+'" class="collapse" data-parent="#accordion" id="collapse-'+accordionCnt+'">';
                                html += '        <div class="card-body">';
                                html += '            <div class="card">';
                            }
                            else{
                                // not inside an accordion -> open card
                                if(el.menu_page_level == 2)
                                    html += '<div class="card">';

                                html += '    <div class="pages-table" data-id="'+el.page_id+'">';
                                html += '        <div class="pages-head">';
                                if(el.menu_page_icon)
                                html += '           <i class="'+el.menu_page_icon+'"></i> ';
                                html += el.page_name+'</div>';
                                html += '        <div class="pages-cols sho"><input type="checkbox" class="view-pg" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_visibility+'></div>';
                                html += '        <div class="pages-cols ins"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_insert+' '+classInsert+'></span></div>';
                                html += '        <div class="pages-cols mod"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_update+' '+classUpdate+'></span></div>';
                                html += '        <div class="pages-cols del"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_delete+' '+classDelete+'></span></div>';
                                html += '    </div>';

                                // not inside an accordion -> close card
                                if(el.menu_page_level == 2)
                                    html += '<div class="card">';
                            }

                        }
                        else if (el.menu_page_level > lastLevel){

                            html += '    <div class="pages-table" data-id="'+el.page_id+'">';
                            html += '        <div class="pages-head">';
                            if(el.menu_page_icon)
                            html += '           <i class="'+el.menu_page_icon+'"></i> ';
                            html += el.page_name+'</div>';
                            html += '        <div class="pages-cols sho"><input type="checkbox" class="view-pg" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_visibility+'></div>';
                            html += '        <div class="pages-cols ins"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_insert+' '+classInsert+'></span></div>';
                            html += '        <div class="pages-cols mod"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_update+' '+classUpdate+'></span></div>';
                            html += '        <div class="pages-cols del"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_delete+' '+classDelete+'></span></div>';
                            html += '    </div>';

                        }
                        else {
                            for(var i= lastLevel; i > el.menu_page_level; i--){

                                // close open cards and accordions
                                html += '            </div>';
                                html += '        </div>';
                                html += '    </div>';
                                html += '</div>';
                            }

                            // if it is not a leaf = expanded FALSE then create accordion
                            if(el.menu_page_expanded == false){
                                // increase accordions counter
                                accordionCnt++;

                                html += '<div class="card">';
                                html += '    <div class="card-header" id="heading-'+accordionCnt+'">';
                                html += '        <button aria-controls="collapse-'+accordionCnt+'" aria-expanded="false" class="btn btn-link" data-target="#collapse-'+accordionCnt+'" data-toggle="collapse"><i class="'+el.menu_page_icon+'"></i>  '+el.page_name+' <span><i class="icon-arrow-right"></i></span></button>';
                                html += '    </div>';
                                html += '    <div aria-labelledby="heading-'+accordionCnt+'" class="collapse" data-parent="#accordion" id="collapse-'+accordionCnt+'">';
                                html += '        <div class="card-body">';
                                html += '            <div class="card">';
                            }
                            else{

                                // not inside an accordion -> open card
                                if(el.menu_page_level == 2)
                                    html += '<div class="card">';

                                html += '    <div class="pages-table" data-id="'+el.page_id+'">';
                                html += '        <div class="pages-head">';
                                if(el.menu_page_icon)
                                html += '           <i class="'+el.menu_page_icon+'"></i> ';
                                html += el.page_name+'</div>';
                                html += '        <div class="pages-cols sho"><input type="checkbox" class="view-pg" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_visibility+'></div>';
                                html += '        <div class="pages-cols ins"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_insert+' '+classInsert+'></span></div>';
                                html += '        <div class="pages-cols mod"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_update+' '+classUpdate+'></span></div>';
                                html += '        <div class="pages-cols del"><span class="hide-el"><input type="checkbox" class="mody-pg" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.page_delete+' '+classDelete+'></span></div>';
                                html += '    </div>';

                                // not inside an accordion -> close card
                                if(el.menu_page_level == 2)
                                    html += '<div class="card">';
                            }


                        }

                        lastLevel = el.menu_page_level;
                    });

                    for(; lastLevel >= 2; lastLevel-- ){
                        // close open cards and accordions
                        html += '            </div>';
                        html += '        </div>';
                        html += '    </div>';
                        html += '</div>';
                    }

                    // show container, add new html and initialize bootstrapToggles
                    $(".pages-table").show();
                    $("#accordion-as-table").append(html);
                    $(".pages-cols input[type='checkbox']").bootstrapToggle();
                    // trigger change event on "view" switch to hide/show other grants
                    $("#accordion-as-table .view-pg" ).trigger( "change" );

                    // add events on new html elements
                    // change event on "view" grant switch
                    $( ".pages-table .view-pg" ).on( "change", function() {

                        // get new status
                        var status = $(this).prop('checked');
                        // get row element and page's id stored inside the html
                        var myRow = $(this).parent().parent().parent();
                        var pageId = parseInt(myRow.data('id'));

                        // create a temporary object and save the new permissions
                        var grantsObj;
                        // if view grant is TRUE then put to false other grants
                        // otherwise reset them
                        if(status){
                            grantsObj = {
                                visible: true,
                                insert: false,
                                update: false,
                                delete: false
                            };
                        }
                        else{
                            grantsObj = {
                                visible: false,
                                insert: null,
                                update: null,
                                delete: null
                            };
                        }
                        // save page's grants
                        updatePageGrants(pageId, grantsObj);
                    });

                    // change event on "others" grants switch
                    $( ".pages-table .mody-pg" ).on( "change", function() {

                        // get row element and page's id stored inside the html
                        var myRow = $(this).parent().parent().parent().parent();
                        var pageId = parseInt(myRow.data('id'));
                        // get view grant
                        var status = myRow.find('.view-pg').prop('checked');

                        // if false then do nothing and return
                        if(status == false)
                            return;

                        // create a temporary object and save the new permissions
                        grantsObj = {
                            visible: true,
                            insert: myRow.find('.ins input').prop('checked'),
                            update: myRow.find('.mod input').prop('checked'),
                            delete: myRow.find('.del input').prop('checked')
                        };
                        // save page's grants
                        updatePageGrants(pageId, grantsObj);
                    });

                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
        });
    }

    /**
     * Function that retrieves stations grants of a given group.
     *
     * @param {integer} grid Group ID.
     * @param {integer} prid Province ID.
     * @param {integer} netid Network ID.
     */
    function loadGroupStationsGrants(grid, prid, netid){

        // clear table
        if(tableSwitch)
            tableSwitch.clear();

        // check selected group id
        // if equal to -1 then return and do nothing
        if(grid == -1){
            tableSwitch.draw();
            return;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_group_stations_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid,
                prid: prid,
                netid: netid
            }
        })
        .done(function(result) {

            // check result
            // if OK then fill table with results
            // else show error message
            if(result.res == 'OK'){

                var stations = result.stations;
                // check if at least one element exists
                if(stations.length > 0){
                    // variable for dinamically building the html
                    var html= '';

                    // variables to manage total permissions
                    var visibilityTotal = true;
                    var insertTotal = true;
                    var updateTotal = true;
                    var deleteTotal = true;

                    // initialize global array
                    arrayStations = [];
                    // loop through all elements
                    // for each station, build a html row to be added to the datable
                    $.each(stations, function(index, el) {

                        // calculate the boolean AND of the permissions to get the total grants
                        visibilityTotal = visibilityTotal && ( el.station_visibility == 'checked' ? true : false );
                        insertTotal = insertTotal && ( el.station_insert == 'checked' ? true : false );
                        updateTotal = updateTotal && ( el.station_update == 'checked' ? true : false );
                        deleteTotal = deleteTotal && ( el.station_delete == 'checked' ? true : false );

                        html += '<tr data-id="'+el.station_id+'">';
                        html += '    <td>'+el.station_id+'</td>';
                        html += '    <td>'+el.station_name+'</td>';
                        html += '    <td>'+el.station_network_type_desc+'</td>';
                        html += '    <td class="sho"><span class="nodisplay">'+el.station_visibility+'</span><input type="checkbox" class="view-st" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_visibility+'></td>';
                        html += '    <td class="ins"><span class="nodisplay">'+el.station_insert+'</span><span class="hide-el"><input type="checkbox" class="mody-st" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_insert+'></span></td>';
                        html += '    <td class="mod"><span class="nodisplay">'+el.station_update+'</span><span class="hide-el"><input type="checkbox" class="mody-st" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_update+'></span></td>';
                        html += '    <td class="del"><span class="nodisplay">'+el.station_delete+'</span><span class="hide-el"><input type="checkbox" class="mody-st" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_delete+'></span></td>';
                        html += '</tr>';

                        // store an object inside the global varaible
                        arrayStations[el.station_id] = {
                            sho : ( el.station_visibility == 'checked' ? true : false ),
                            ins : ( el.station_insert == 'checked' ? true : false ),
                            mod : ( el.station_update == 'checked' ? true : false ),
                            del : ( el.station_delete == 'checked' ? true : false )
                        };
                    });
                }

                // destroy and re-initialize the bootstrapToggle to avoid triggering the change event
                $("#table-switch-network .view-st"  ).prop('checked', visibilityTotal).bootstrapToggle('destroy').bootstrapToggle();
                // hide / show other total grants based on visibility permission
                if(visibilityTotal)
                    $("#table-switch-network .hide-el").show();
                else
                    $("#table-switch-network .hide-el").hide();

                $("#table-switch-network .ins input").prop('checked', insertTotal).bootstrapToggle('destroy').bootstrapToggle()
                $("#table-switch-network .mod input").prop('checked', updateTotal).bootstrapToggle('destroy').bootstrapToggle()
                $("#table-switch-network .del input").prop('checked', deleteTotal).bootstrapToggle('destroy').bootstrapToggle()

                // add rows to datatable by using html object
                tableSwitch.rows.add($( html ));
                // redraw it
                tableSwitch.draw();
                // initialize the bootstraptoggles of all lines
                // loop through each table row contained in all pages (not only the visible one )
                tableSwitch.rows({page: 'all'}).every(function() { // the containers
                    var row = this;
                    row = $(row.node());

                    row.find("td input[type='checkbox']").bootstrapToggle();
                    // hide / show other grants based on visibility permission
                    if(row.find(".view-st").prop('checked')){
                        row.find('.hide-el').show();
                    }else{
                        row.find('.hide-el').hide();
                    }
                });
                // redraw it
                tableSwitch.draw();

                // add events on new html elements
                // change event on "view" grant switch
                $( "#table-switch-stations" ).on( "change", ".view-st", function() {

                    // get row element and station's id stored inside the html
                    var stid = $(this).parent().parent().parent().data("id");
                    var myRow = $(this).parent().parent().parent();

                    // update global variable
                    arrayStations[stid].sho = myRow.find('.view-st').prop('checked');
                    arrayStations[stid].ins = myRow.find('.ins input').prop('checked');
                    arrayStations[stid].mod = myRow.find('.mod input').prop('checked');
                    arrayStations[stid].del = myRow.find('.del input').prop('checked');
                    // save station's grants
                    updateStationsGrants(stid);
                });

                // change event on "other" grants switch
                $( "#table-switch-stations" ).on( "change", ".mody-st", function() {

                     // get row element and station's id stored inside the html
                    var myRow = $(this).parent().parent().parent().parent();
                    var stid = myRow.data("id");
                    // get visibility grant
                    var status = myRow.find('.view-st').prop('checked');

                    // if false then do nothing and return
                    if(status == false)
                        return;

                     // update global variable
                    arrayStations[stid].sho = myRow.find('.view-st').prop('checked');
                    arrayStations[stid].ins = myRow.find('.ins input').prop('checked');
                    arrayStations[stid].mod = myRow.find('.mod input').prop('checked');
                    arrayStations[stid].del = myRow.find('.del input').prop('checked');
                    // save station's grants
                    updateStationsGrants(stid);
                });

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        });
    }

    /**
     * Function that retrives other grants of a given group.
     *
     * @param {integer} grid Group ID.
     */
    function loadGroupOthersGrants(grid){

        // reset datatables
        if($('#table-switch-nets').DataTable())
            $('#table-switch-nets').DataTable().destroy();

        if($('#table-switch-widgets').DataTable())
            $('#table-switch-widgets').DataTable().destroy();

        if($('#table-switch-telegram').DataTable())
            $('#table-switch-telegram').DataTable().destroy();

        // clear tables
        $('#table-switch-nets tbody').empty();
        $('#table-switch-widgets tbody').empty();
        $('#table-switch-telegram tbody').empty();
        $('#table-final-validation tbody').empty();

        // check selected group id
        // if equal to -1 then return and do nothing
        if(grid == -1){
            return;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_group_others_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid
            }
        })
        .done(function(result) {

            // check result
            // if OK fill tab with retrieved data
            if(result.res == 'OK'){

                // ! NETWORKS !
                var nets = result.nets;
                // check if at least one element exists
                if(nets && nets.length > 0){
                    // variable for dinamically building the html
                    var htmlNets = '';
                    // loop through all elements
                    // for each network, build a html row to be added to the datable
                    $.each(nets, function(index, net) {

                        htmlNets += '<tr data-id="'+net.st_network_id+'" data-type="net">';
                        htmlNets += '    <td>'+net.st_network_name+'</td>';
                        htmlNets += '    <td><input type="checkbox" class="view-ot" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+net.network_visibility+'></td>';
                        htmlNets += '</tr>';

                    });

                    // append rows and initialize the switches
                    $('#table-switch-nets tbody').html(htmlNets);
                    $('#table-switch-nets input[type=checkbox]').bootstrapToggle();
                    // if items are greater then 10 then initialize a datatable
                    // to add table's pagination
                    if(nets.length > 10){
                        $('#table-switch-nets').DataTable({
                            // dom: "Bfrtip",
                            pageLength: 10,
                            pagingType: 'simple_numbers',
                            layout: {
                                bottomEnd: {
                                    paging: {
                                        buttons: 5,
                                        type: 'simple_numbers'
                                    }
                                }
                            },
                            // 'copy', 'csv', 'excel', 'pdf', 'print'
                            searching: false,
                            ordering: false,
                            lengthChange: false,
                            buttons: []
                        });
                    }
                }

                var widgets = result.widgets;
                groupWidgets = [];
                // check if at least one element exists
                if(widgets && widgets.length > 0){
                    // variable for dinamically building the html
                    var htmlWidgets = '';
                    // loop through all elements
                    // for each widget, build a html row to be added to the datable
                    $.each(widgets, function(index, widget) {

                        groupWidgets[widget.wdg_id] = widget;

                        if (widget.wdg_visibility != "checked"){
                            groupWidgets[widget.wdg_id].gw_dest = JSON.stringify({
                                type: 'default'
                            });
                        }

                        htmlWidgets += '<tr data-id="'+widget.wdg_id+'"  data-type="widget">';
                        htmlWidgets += '    <td>'+widget.wdg_name+'</td>';
                        htmlWidgets += '    <td><input type="checkbox" class="view-ot" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+widget.wdg_visibility+'></td>';
                        var type = '';
                        if (widget.wdg_visibility == "checked"){
                            type = '';
                        }else{
                            type = 'not-viewed';
                        }
                        htmlWidgets += '    <td align="center" class="icon-big"><a href="javascript:void(0);" class="'+type+' edit-link" data-toggle="modal" data-target="#widget-destination" data-toggle-second="tooltip" data-original-title="Modifica destinazione link approfondimento"><i class="fa-regular fa-money-check-pen"></i></a></td>';
                        htmlWidgets += '</tr>';

                    });

                    // append rows and initialize the switches
                    $('#table-switch-widgets tbody').html(htmlWidgets);
                    $('#table-switch-widgets input[type=checkbox]').bootstrapToggle();
                    // if items are greater then 10 then initialize a datatable
                    // to add table's pagination
                    if(widgets.length > 10){
                        $('#table-switch-widgets').DataTable({
                            // dom: "Bfrtip",
                            pageLength: 10,
                            // 'copy', 'csv', 'excel', 'pdf', 'print'
                            searching: false,
                            ordering: false,
                            lengthChange: false,
                            buttons: []
                        });
                    }

                    $('[data-toggle-second="tooltip"]').tooltip();
                }

                var channels = result.channels;
                // check if at least one element exists
                if(channels && channels.length > 0){
                    // variable for dinamically building the html
                    var htmlChannels = '';
                    // loop through all elements
                    // for each channel, build a html row to be added to the datable
                    $.each(channels, function(index, channel) {

                        htmlChannels += '<tr data-id="'+channel.channel_id+'">';
                        htmlChannels += '    <td>'+channel.channel_name+' ['+channel.chat+']</td>';
                        htmlChannels += '    <td class="sho"><input type="checkbox" class="view-ch" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+channel.channel_visibility+'></td>';
                        htmlChannels += '    <td class="ins"><span class="hide-el"><input type="checkbox" class="mody-ch" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+channel.channel_insert+'></span></td>';
                        htmlChannels += '    <td class="del"><span class="hide-el"><input type="checkbox" class="mody-ch" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+channel.channel_delete+'></span></td>';
                        htmlChannels += '</tr>';

                    });

                    // append rows and initialize the switches
                    $('#table-switch-telegram tbody').html(htmlChannels);
                    $('#table-switch-telegram input[type=checkbox]').bootstrapToggle();
                    // if items are greater then 10 then initialize a datatable
                    // to add table's pagination
                    if(channels.length > 10){
                        $('#table-switch-telegram').DataTable({
                            // dom: "Bfrtip",
                            pageLength: 10,
                            pagingType: 'simple_numbers',
                            layout: {
                                bottomEnd: {
                                    paging: {
                                        buttons: 5,
                                        type: 'simple_numbers'
                                    }
                                }
                            },
                            // 'copy', 'csv', 'excel', 'pdf', 'print'
                            searching: false,
                            ordering: false,
                            lengthChange: false,
                            buttons: []
                        });
                    }

                    $('#table-switch-telegram .view-ch' ).trigger('change');
                }

                var codes = result.codes;
                // check if at least one element exists
                if(codes && codes.length > 0){
                    // variable for dinamically building the html
                    var htmlCodes = '';
                    // loop through all elements
                    // for each code, build a html row to be added to the datable
                    $.each(codes, function(index, code) {

                        htmlCodes += '<tr data-id="'+code.fvc_code_id+'" data-type="code">';
                        htmlCodes += '    <td style="width: 50px;">'+(index+1)+'</td>';
                        htmlCodes += '    <th style="width: 70%;" class="text-left">'+code.fvc_code_desc+'</td>';
                        htmlCodes += '    <td style="width: 10%;"><input type="checkbox" class="view-ot" data-onstyle="info" data-offstyle="danger" data-on="SI" data-off="NO" data-size="xs" data-style="android" '+code.code_visibility+'></td>';
                        htmlCodes += '    <td style="width: 10%;"><div class="code-'+code.fvc_code_desc+'"></div></td>';
                        htmlCodes += '</tr>';

                    });

                    // append rows and initialize the switches
                    $('#table-final-validation tbody').html(htmlCodes);
                    $('#table-final-validation input[type=checkbox]').bootstrapToggle();
                }

                // add events on new html elements
                // change event on "view" grant switch
                $('.tbl-oneshot .view-ot').on( "change", function() {

                    // get new status
                    var status = $(this).prop('checked');
                    // get destination stored inside the html
                    var dest = $(this).parent().parent().next().children();

                    // take care of items classes based on new status
                    if(status == false){
                        dest.addClass('not-viewed');
                    }
                    else{
                        dest.removeClass('not-viewed');
                    }

                    // get row element
                    var myRow = $(this).parent().parent().parent();
                    // get item ID
                    var otherId = parseInt(myRow.data('id'));
                    // get item type
                    var otherType = myRow.data('type');

                    // save grant
                    updateOthersGrants(otherId, otherType, status);
                });

                // change event on "view" grant switch in CHANNEL table
                $("#table-switch-telegram .view-ch" ).on( "change", function() {

                    // get new status
                    var status = $(this).prop('checked');
                    // get row element and ID stored inside html
                    var myRow = $(this).parent().parent().parent();
                    var channelId = parseInt(myRow.data('id'));

                    // create a temporary object and save the new permissions
                    var grantsObj;
                    // if view grant is TRUE then put to false other grants
                    // otherwise reset them
                    if(status){
                        grantsObj = {
                            visible: true,
                            insert: false,
                            update: false,
                            delete: false
                        };
                    }
                    else{
                        grantsObj = {
                            visible: false,
                            insert: null,
                            update: null,
                            delete: null
                        };
                    }
                    // save channel grants
                    updateChannelGrants(channelId, grantsObj);
                });

                // change event on "other" grants switch in CHANNEL table
                $( "#table-switch-telegram .mody-ch" ).on( "change", function() {

                    // get row element and ID stored inside html
                    var myRow = $(this).parent().parent().parent().parent();
                    var channelId = parseInt(myRow.data('id'));
                    // get view grant
                    var status = myRow.find('.view-ch').prop('checked');

                    // if it is false then return and do nothing
                    if(status == false)
                        return;

                    // create a temporary object and save the new permissions
                    grantsObj = {
                        visible: true,
                        insert: myRow.find('.ins input').prop('checked'),
                        update: false,
                        delete: myRow.find('.del input').prop('checked')
                    };

                    // save channel grants
                    updateChannelGrants(channelId, grantsObj);
                });
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati del gruppo selezionato", "error");
        });
    }

    /**
     * Function that retrieves the user's information to edit.
     *
     * @param {integer} userid User ID.
     */
    function getUserToEdit(userid){

        // get metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_get_user_byid',
            type: "post",
            dataType: "json",
            data: {
                id: userid
            },
        })
        .done(function(result) {

            var user = result.user;

            // fill form with retrieved metadata
            arrayGroups = user.groups_id;

            $('#new-user-id').val(user.user_id);
            $('#new-user-name').val(user.user_name);
            $('#new-user-secondname').val(user.user_second_name);
            $('#new-user-surname').val(user.user_surname);
            $('#new-user-role').val(user.user_role);
            $('#new-user-mobile').val(user.user_mobile);
            $('#new-user-phone').val(user.user_phone);
            $('#new-user-email').val(user.user_email);

            if(user.user_active == 'Si'){
                $('#user-active').prop("checked", true);
            }
            else{
                $('#user-active').prop("checked", false);
            }


            var html  ='      <img src="'+user.user_avatar_thumb+'" class="img-responsive"><br>\n';
                html +='      <strong class="text-danger">(Avatar attuale)</strong>'

            $('#new-user-session').val(user.user_expiration_time);

            $('#img-container').append(html);
            $('#img-container').show();
            $('#dpz-container').addClass("col-8");
            $('#dpz-container').removeClass("col-10");

            $('#new-user-portal').val(user.portal_id);
            $('#new-user-comp').val(user.company_id);

            //select2
            newUserGroups.val(arrayGroups);
            newUserGroups.trigger('change');

            // show edit tab
            $('.customtab a[href="#new"]').tab('show');
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dell'utente", "error");
        });
    }

    /**
     * Function that updates grants on a given page of a given group.
     *
     * @param {integer} pageId Page ID.
     * @param {object}  grantsObj Object containing the grants information.
     */
    function updatePageGrants(pageId, grantsObj){
        // get selected group id
        var grid = parseInt($("#filter-group-pages").val());
        // save grants via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_put_group_pages_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid,
                pgid: pageId,
                grants: JSON.stringify(grantsObj)
            },
        })
        .done(function(result) {
            // check result
            // if FALSE then show error message
            if(! result)
               swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        });
    }

    /**
     * Function that updates grants on all stations or only on the given one.
     *
     * @param {integer} stationId Station ID; if equalt to -1: all stations.
     */
    function updateStationsGrants(stationId){

        var grantsObjArray = [];
        // if station id equal to -1 then update all stations
        // otherwise update only the changed one
        if(stationId == -1){
            // loop through all stations
            // for each station create a temporary object to add it to an array to be sent via ajax
            $.each(arrayStations, function(index, el) {

                if( !el )
                    return;

                var grantsObj = {
                    stid : index,
                    visible: el.sho,
                    insert: el.ins,
                    update: el.mod,
                    delete: el.del
                };

                grantsObjArray.push(grantsObj);
            });
        }
        else{
            // create a temporary object to add it to an array to be sent via ajax
            var grantsObj = {
                stid : stationId,
                visible: arrayStations[stationId].sho,
                insert: arrayStations[stationId].ins,
                update: arrayStations[stationId].mod,
                delete: arrayStations[stationId].del
            };

            grantsObjArray.push(grantsObj);
        }

        // get selected group id
        var grid = parseInt($("#filter-group-stations").val());
        // save data via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_put_group_stations_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid,
                grants: JSON.stringify(grantsObjArray)
            },
        })
        .done(function(result) {
            // check result
            // if false then show error message
            // else update tab's contents
            if(! result){
                // error message
                swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
            }
            else{
                // check if all stations have been updated
                if(stationId == -1){
                    // initializes the switches of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tableSwitch.rows({page: 'all'}).every(function() {
                        var row = this;
                        row = $(row.node());

                        // get station id stored inside the html
                        var stid = row.data("id");

                        // take care of other grants based on visibility permission
                        // destroy and re-initialize switches to avoid triggering change event
                        if(arrayStations[stid].sho == true){
                            row.find(".view-st").prop('checked', true).bootstrapToggle('destroy').bootstrapToggle();
                            row.find(".ins input").prop('checked', arrayStations[stid].ins ).bootstrapToggle('destroy').bootstrapToggle();
                            row.find(".mod input").prop('checked', arrayStations[stid].mod ).bootstrapToggle('destroy').bootstrapToggle();
                            row.find(".del input").prop('checked', arrayStations[stid].del ).bootstrapToggle('destroy').bootstrapToggle();
                            row.find(".hide-el").show();
                        }
                        else{
                            row.find(".view-st").prop('checked', false).bootstrapToggle('destroy').bootstrapToggle();
                            row.find('.mody-st').prop('checked', false).bootstrapToggle('destroy').bootstrapToggle();
                            row.find(".hide-el").hide();
                        }
                    });
                }
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that updates grants on a given 'other' of a given group.
     *
     * @param {integer} otherId 'Other' ID.
     * @param {string}  otherType Typology of 'other' grant.
     * @param {boolean} status Boolean value visible/not visible.
     */
    function updateOthersGrants(otherId, otherType, status){
        // get selected group ID
        var grid = parseInt($("#filter-group-other").val());

        // save grants via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_put_group_others_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid,
                id: otherId,
                type: otherType,
                grant: status
            }
        })
        .done(function(result) {
            // check result
            // if false show error message
            if(! result)
               swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        });
    }

    /**
     * Function that updates grants on a given channel of a given group.
     *
     * @param {integer} channelId Channel ID.
     * @param {object}  grantsObj Object containing the grants informations.
     */
    function updateChannelGrants(channelId, grantsObj){
        // get selected group ID
        var grid = parseInt($("#filter-group-other").val());

        // save grants via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_put_group_channels_grants',
            type: "post",
            dataType: "json",
            data: {
                grid: grid,
                chid: channelId,
                grants: JSON.stringify(grantsObj)
            },
        })
        .done(function(result) {
            // check result
            // if false show error message
            if(! result)
               swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
        });
    }
});