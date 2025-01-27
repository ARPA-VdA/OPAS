/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var mySwitch;
    var myDropzone;

    var mapView = [];

    $('.hide-loc').hide();

    // boostraptoggle
    $( "#search-type" ).bootstrapToggle();

    // variable for loadMiscellanies function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

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
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimo 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimo 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, get miscellanies within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh miscellanies list in the first tab
        loadMiscellanies(dateFrom, dateTo);
    });

    // datatable
    table = $('#list-table').DataTable({
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
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 2, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // hide columns
    table.column(5).visible(false);
    table.column(6).visible(false);

    $( "#provinces, #loc-prov, #place-loc-prov, #equipment-networks" ).select2();
    // select2 initialization
    $( "#stations, #loc-stat, #place-loc-stat" ).select2({
        matcher: searchGroupedSelect2
    });

    // 2 types of search: list of miscellanies or list of allocations
    // for each type there are different descriptions and filters shown/hidden throught .select-place class
    $('.select-place, #active-loc').hide();

    $('#search-type').on('change', function(e){
        e.preventDefault();
        var status = $(this).prop('checked'); // TRUE -> location ; FALSE -> miscellany
        // console.log(status);
        // check status
        //  - if true then location
        //  - if false then miscellany
        if (status){
            $('.select-place, #active-loc').show();
            $('#active-instr').hide();
        }else{
            $('.select-place, #active-loc').hide();
            $('#active-instr').show();
        }

        // refresh miscellanies list in the first tab
        loadMiscellanies(dateFrom, dateTo);
    });

    $( "#provinces" ).on( "change", function() {
        var prid = $(this).val();

        // load list of stations
        loadStations(prid);
    });

    $( "#stations" ).on( "change", function() {
        // refresh miscellanies list in the first tab
        loadMiscellanies(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive miscellany detail.
     */
    $('#list-table').on('click', '.show-element', function(e){
        e.preventDefault();

        // get miscellany id stored in tr
        var miscid = parseInt($(this).parent().parent().data("id"));

        // check if the miscellany's detail is already open
        if( $('#misc'+miscid).length ) {
            console.log('The miscellany\'s detail is already open');
            $('.customtab a[href="#misc' + miscid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createMiscellanyDetail(miscid);
    });

    /**
     * Edit miscellany.
     */
    $('#list-table').on('click', '.edit-element', function(e){
        e.preventDefault();

        // get miscellany id stored in tr
        var miscid = parseInt($(this).parent().parent().data("id"));

        // clear all fields
        clearFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get miscellany detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_miscellany_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: miscid
            },
        })
        .done(function(result) {
            console.log('edit miscellany!');

            /**
             * insert_time: "2021-12-21 09:59:03.314507"
             * insert_user: 4
             * mi_id: 1
             * miscellany_active: 1
             * miscellany_arpa_id: null
             * miscellany_owner: "Arpa Valle d'Aosta"
             * miscellany_attachments: null
             * miscellany_dismiss_date: null
             * miscellany_locations: "[{\"id\":1,\"location_id\":1004,\"location_name\":\"Aosta - I Maggio\",\"location_prov\":\"Aosta\",\"location_lat\":45.7324,\"location_lon\":7.32189,\"location_start\":\"2021-12-01T10:58:00\",\"location_end\":\"31/12/2022 10:58\",\"stmi_dismiss_date\":\"2022-12-31T10:58:00\",\"location_note\":\"test note location\"}]"
             * miscellany_name: "Test 001"
             * miscellany_note: "test note"
             * network_names: (2) ["Arpa Valle d'Aosta", 'Arpa Emilia-Romagna']
             * network_types: (2) [3, 1]
             * user_avatar_thumb: "/bobo-img/default/avatar/ava01.png"
             * user_fullname: "Nome Cognome"
             */

            var miscellany = result.miscellany;
            // json objects to be parsed
            var attachments = JSON.parse(miscellany.miscellany_attachments);
            console.dir(miscellany);
            console.dir(attachments);

            // populate the fields of "new miscellany" form
            $('#equipment-id').val(miscellany.mi_id);
            $('#equipment-arpa-id').val(miscellany.miscellany_arpa_id);
            $('#equipment-owner').val(miscellany.miscellany_owner);
            $('#equipment-name').val(miscellany.miscellany_name);
            $('#equipment-date-dismiss').val('');
            $('#equipment-date-dismiss').bootstrapMaterialDatePicker('setDate', moment(miscellany.miscellany_dismiss_date).format('DD/MM/YYYY'));

            $('#equipment-active').prop('checked', miscellany.miscellany_active ).trigger('change', false);
            $('#equipment-networks').val(miscellany.network_types).trigger('change.select2'); // does not trigger main "change" event

            // check if miscellany has attachments
            //  - if true then add attachments to the miscellany's detail page
            if(attachments){
                var htmlImages = '';
                var htmlFiles = '<ul>';

                // loop through attachments
                // different items depending on the file type
                $.each(attachments, function(idx, attachment){
                    // check if current looped attachment is an image
                    if(attachment.file_image == true){
                        // image files
                        htmlImages +='    <div class="del-my-img">\n';
                        htmlImages +='      <span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span><a href="'+attachment.file_path+'" class="clearfix thumb-gallery"><img src="'+attachment.file_path+'"></a>\n';
                        htmlImages +='    </div>\n';
                    }
                    else{
                        // other files
                        htmlFiles +='<li><span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i></span> <a href="'+attachment.file_path+'"><i class="icon-paper-clip"></i> '+attachment.file_name+'</a></li>';
                    }
                });

                htmlFiles += '</ul>';

                // append files
                $('#img-container').append(htmlImages);
                $('.attachment-files').append(htmlFiles);

                // image gallery
                refreshGalleryBig();
            }

            $('#equipment-note').val(miscellany.miscellany_note);

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

            // hide section that cannot be visible during "edit" action
            $('#hide-edit').hide();
            // show form tab
            $('.customtab a[href="#new-element"]').tab('show');

            // modify 'Nuovo' text in 'Modifica'
            $('#new-element .box-title').text('Modifica dotazione');
            $('#btn-equipment-form').html(' <i class="ti-save"></i> Modifica');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della dotazione", "error");
        });
    });

    /**
     * Edit location.
     */
    $('#list-table').on('click', '.edit-loc-el', function(e){
        e.preventDefault();

        // get location id stored in tr
        var stmiid = parseInt($(this).parent().parent().data("stmiid"));

        // get miscellany - location detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_location_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: stmiid
            }
        })
        .done(function(result) {
            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                var location = result.location;
                var check = result.check;

                // compile fields of the form with metadata arriving from database
                $('#place-loc-id').val(location.stmi_id);
                $('#place-loc-equipment').val(location.mi_id).trigger('change');
                $('#place-loc-prov').trigger('change', location.station_id);

                /**
                 * stmi_id
                 * station_id
                 * mi_id
                 * stmi_startup_date
                 * stmi_dismiss_date
                 * stmi_note
                 */

                // $('#modal-loc-stat').val(location.station_id);
                $('#place-loc-start-date').val('');
                $('#place-loc-start-date').bootstrapMaterialDatePicker('setDate', moment(location.stmi_startup_date).format('DD/MM/YYYY HH:mm'));
                $('#place-loc-start-date').trigger('change');

                $('#place-loc-end-date').val('');
                // manage datetime
                if(location.stmi_dismiss_date != 'infinity')
                    $('#place-loc-end-date').bootstrapMaterialDatePicker('setDate', moment(location.stmi_dismiss_date).format('DD/MM/YYYY HH:mm'));

                $('#place-loc-end-date').bootstrapMaterialDatePicker('setMinDate', moment() );
                $('#place-loc-notes').val(location.stmi_note);

                $('#place-loc-equipment').prop('disabled', true);

                // check if miscellany has been already used during this allocation
                if(check == 1){
                    // disable fields that cannot be modified
                    $('#place-loc-prov').prop('disabled', true);
                    $('#place-loc-stat').prop('disabled', true);
                    $('#place-loc-start-date').prop('disabled', true);
                }

                // modify 'Nuovo' text in 'Modifica'
                $('.customtab a[href="#new-location"]').tab('show');
                $('#new-location .box-title').text('Modifica location');
                $('#new-location .divider-title').text('Modifica location');
                $('#place-loc-insert').html('<i class="icon-location-pin"></i> Modifica');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati della location", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati della location", "error");
        });
    });

    /**
     * Close location.
     */
    $('#list-table').on('click', '.close-loc-el', function(e){
        e.preventDefault();

        // get location id stored in tr
        var stmiid = parseInt($(this).parent().parent().data("stmiid"));

        // show confirm message
        swal({
            title: "Chiudi location",
            text: "Sei proprio sicuro di voler chiudere questa location?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, chiudi",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // close the selected location
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_dotazioni_put_location_closure',
                type: "post",
                dataType: "json",
                data: {
                    id: stmiid
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, clear fields and refresh miscelannies lists
                //  - if false then error
                if(result){
                    swal("Location chiusa", "La location è stata chiusa con successo!", "success");
                    // refresh miscellanies list in the first tab
                    loadMiscellanies(dateFrom, dateTo);
                    // reload lists in order to update all select html elements
                    loadMiscellaniesForLocation();

                    // reset location form fields
                    clearLocationFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante la chiusura della location", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante la chiusura della location", "error");
            });
        });
    });

    /**
     * Download miscellany detail.
     */
    $('#list-table').on('click', '.pdf-element', function(e){
        swal("Report scaricato", "Il report è stato scaricato con successo!", "success");
        e.preventDefault();
    });

    /**
     * Delete miscellany.
     */
    $('#list-table').on('click', '.delete-element', function(e){
        e.preventDefault();

        // get miscellany id stored in tr
        var miscid = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai per eliminare <strong>definitivamente</strong> la dotazione",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?<br>Oltre all'elemento, verranno rimossi anche i suoi <strong>eventuali stanziamenti</strong>!",
            type: "warning",
            html: true,
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_dotazioni_del_miscellany',
                type: "post",
                dataType: "json",
                data: {
                    id: miscid
                }
            })
            .done(function(result) {
                // check result
                //  - if '-1' then it's impossible to delete the miscellany becaus it's already used in the planning
                //  - if '1' then the miscellany is correctly deleted -> clear all fields
                //  - else error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile eliminare la dotazione perchè <strong>GIÀ USATA</strong> nel planning.",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == 1){
                    swal("Dotazione eliminata", "La dotazione è stato eliminata con successo!", "success");
                    // remove row from table
                    table.row($("tr[data-id='"+miscid+"']")).remove().draw();

                    clearFields();
                    clearLocationFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della dotazione", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione della dotazione", "error");
            });
        });
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    $("#add-location-fields").hide();

    // START Dropzone //
    var url = "/cnf_dotazioni_put_miscellany";

    myDropzone = initDropzoneFiles(url);
    // END Dropzone //

    /**
     * Dismission date of the new miscellany.
     */
    $('#equipment-date-dismiss').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });

    /**
     * New location start and end insertion datetime.
     */
    $('#loc-start-date, #loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date equal to start time picker value
        $('#loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#loc-end-date').val('');
    });

    /**
     * Switchery button of new miscellany.
     */
    $('#equipment-active').bootstrapToggle();
    mySwitch = new Switchery($("#add-location")[0], $("#add-location").data());

    /**
     * Dismiss date change.
     */
    $('#equipment-date-dismiss').on('change', function(e){
        // set "active" to false
        $('#equipment-active').prop('checked', false).trigger('change', false);
    });

    /**
     * Active flag change.
     */
    $('#equipment-active').on('change', function(e, flag){
        if(flag == false)
            return;

        var status = $(this).is(':checked');
        // check status
        // if false, set dismiss date value
        if(status == false){
            $('#equipment-date-dismiss').val('');
            $('#equipment-date-dismiss').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        }
        else{
            $('#equipment-date-dismiss').val('');
        }
    });

    /**
     * Network selection of new miscellany.
     */
    $('#equipment-networks').on('change', function(e){

        // get element destination where appending new stations
        var dest = $(this).data('dest');

        // retrieve network ids and the province id
        // if networks are not empty
        if($(this).val().length > 0){
            console.log('change equipment-networks');

            var nets = JSON.stringify($(this).val());
            var prid = $("#loc-prov").val();

            // load stations and update "dest" select
            loadStationsByNetworks(dest, prid, nets);
        }
        else{
            // reset "dest" select
            $('#'+dest).empty();
            $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
        }
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
                url: '/cnf_dotazioni_del_attachment',
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
     * Switchery button: Add location to the miscellany
     */
    $("#add-location").on( "change", function() {
        var ckb = mySwitch.isChecked();
        // show/hide location form
        if (ckb){
            $("#add-location-fields").show();
        }else{
            $("#add-location-fields").hide();
        }
    });

    /**
     * Province selection of the new location.
     */
    $('#loc-prov').on( "change", function(e, stid) {
        // get element destination where appending new stations
        var dest = $(this).data('dest');

        // retrieve network ids and the province id
        // if networks are not empty
        if($('#equipment-networks').val().length > 0){
            console.log('change equipment-networks');

            var nets = JSON.stringify($('#equipment-networks').val());
            var prid = $("#loc-prov").val();

            // load stations and update "dest" select
            loadStationsByNetworks(dest, prid, nets);
        }
        else{
            // reset "dest" select
            $('#'+dest).empty();
            $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
        }
    });

    /**
     * Validate form.
     */
    var validator = $('#equipment-form').validate({ // initialize the plugin
        rules: {
            "equipment-name" : {
                required: true
            },
            "equipment-networks":{
                required: true,
                allowEmpty: false
            },
            "loc-stat":{
                required:  function (element) {
                    if(mySwitch.isChecked()){return true;}else{return false;}
                },
                min:  function (element) {
                    if(mySwitch.isChecked()){return 0;}else{return -1;}
                },
            },
            "loc-start-date":{
                required:  function (element) {
                    if(mySwitch.isChecked()){return true;}else{return false;}
                },
            },
        },
        messages: {
            "equipment-name" : {
                required: "Inserire dotazione"
            },
            "equipment-networks":{
                required: "Inserire almeno una rete",
                allowEmpty: "Inserire almeno una rete"
            },
            "loc-stat":{
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "loc-start-date" : {
                required: "Inserire data inizio"
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
     * Function called when using Dropzone submit.
     */
    myDropzone.on("sendingmultiple", function(files, xhr, formData) {

        var form = $('#equipment-form');

        // add form fields to the dropzone submission object
        var formValues = form.serializeArray();
        $.each(formValues, function(index, input){
            formData.append(input.name, input.value);
        });
    });

    /**
     * Function called at the Dropzone submit return.
     */
    myDropzone.on("successmultiple", function(files, response) {
        var id   = $("#equipment-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        // otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
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
            console.log('Success');
            swal("Successo", msg_ok, "success");

            // refresh miscellanies list in the first tab
            loadMiscellanies(dateFrom, dateTo);
            // reload lists in order to update all select html elements
            loadMiscellaniesForLocation();
            // show first tab
            $('.customtab a[href="#list"]').tab('show');
            // reset form
            clearFields();
        }
        else{
            swal("Errore", msg_err, "error");
            // manage files, add error class and re-queue them
            $.each(files, function(index, file) {
                file.previewElement.classList.add("dz-error");
                file.status = Dropzone.QUEUED
            });
        }

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    });

    /**
     * Submit of the new/edit miscellany form.
     */
    $('#equipment-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare questo elemento", "info");
            return false;
        };

        var form = $("#equipment-form");
        var id   = $("#equipment-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // Check if attachments exist:
        // if exists     -> use the dropzone submit function and add fields of the form to the submission
        // if not exist  -> normal form submit
        if (myDropzone.getQueuedFiles().length > 0) {
            console.log(myDropzone.getQueuedFiles().length);
            myDropzone.processQueue();
        }
        else {
            console.log("Invio normale");

            // ajax call
            $.ajax({
                url: '/cnf_dotazioni_put_miscellany',
                type: 'post',
                dataType: "json",
                data: form.serialize()
            }).done(function(result) {
                // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
                if(result == true){
                    swal("Successo", msg_ok, "success");

                    // refresh miscellanies list in the first tab
                    loadMiscellanies(dateFrom, dateTo);
                    // reload lists in order to update all select html elements
                    loadMiscellaniesForLocation();
                    // show first tab
                    $('.customtab a[href="#list"]').tab('show');
                    // reset form
                    clearFields();
                }
                else{
                    // error message
                    swal("Errore!", msg_err, "error");
                }

                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            })
            .fail(function(xhr, err) {
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // error message
                swal("Errore!", msg_err, "error");
            });
        }
    });

    /**
     * Cancel button.
     */
    $('#cancel-equipment-form').on('click', function(e) {
        e.preventDefault();

        // show first tab
        $('.customtab a[href="#list"]').tab('show');
        // reset form
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    // TAB LOCATION FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Selection of the miscellany
     */
    $('#place-loc-equipment').on( "change", function() {
        console.log($(this).val());
        var miscid = parseInt($(this).val());
        console.log(miscid);

        // check if miscellany is selected
        //  - if not '-1' then show new location form
        //  - if '-1' then hide new location form
        if(miscid != -1){
            // get networks to which selected miscellany is associated
            // and programatically select values
            $('#place-networks').val( JSON.stringify( $('#place-loc-equipment option:selected').data('nets') )) ;
            // reload stations
            $('#place-loc-prov').trigger( "change");
            // show "new location" form
            $('.hide-loc').show('slow');
        }
        else{
            // reset select
            $('#place-networks').val('');
            // hide "new location" form
            $('.hide-loc').hide('slow');
        }
    });

    /**
     * Province selection of the new location.
     */
    $('#place-loc-prov').on( "change", function(e, stid) {
        var prid = $(this).val();
        var dest = $(this).data('dest');
        var nets = $('#place-networks').val();

        // refresh stations in the "dest" element
        loadStationsByNetworks(dest, prid, nets, stid);
    });

    /**
     * New location start and end insertion datetime.
     */
    $('#place-loc-start-date, #place-loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date equal to start time picker value
        $('#place-loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#place-loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#place-loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#place-loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#place-loc-end-date').val('');
    });

    // set first value
    $('#place-loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
    $('#place-loc-start-date').trigger('change');

    /**
     * Validate form.
     */
    var placeValidator = $('#place-equipment-form').validate({ // initialize the plugin
        rules: {
            "place-loc-equipment" : {
                required: true
            },
            "place-loc-stat" : {
                required: true,
                min: 0
            },
            "place-loc-start-date" : {
                required: true
            }
        },
        messages: {
            "place-loc-equipment" : {
                required: "Selezionare bombola"
            },
            "place-loc-stat":{
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "place-loc-start-date" : {
                required: "Inserire data inizio"
            },
        },
        ignore: ":hidden",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }

        },
    });

    /**
     * New location's form submission.
     */
    $('#place-equipment-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Stanziamento non salvato!", "info");
            return false;
        };

        var form = $("#place-equipment-form");
        var id   = parseInt($("#place-loc-id").val());
        var miid = parseInt($('#place-loc-equipment').val());

        // different messages based on the type of action (insert or update)
        // - if the id is setted then is an update
        // - otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        $.ajax({
            url: '/cnf_dotazioni_put_location',
            type: 'post',
            dataType: "json",
            data: form.serialize()
        }).done(function(result) {
            // check result
            //  - if '-1' then it's impossible to delete the miscellany location because the item has been already used in other applications
            //  - if '1' then the miscellany location is correctly deleted -> clear all fields
            //  - else error
            if(result == -1){
                swal({
                    title: "Attenzione!",
                    text: "Impossibile stanziare la dotazione nel periodo selezionato perchè <strong>GIÀ STANZIATA</strong>.<br>Modificare le date dello stanziamento",
                    type: "warning",
                    html: true
                });
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else if(result == 1){
                swal("Successo", msg_ok, "success");

                // refresh miscellanies list in the first tab
                loadMiscellanies(dateFrom, dateTo);
                // reset location form
                clearLocationFields();
                // reload lists in order to update all select html elements
                loadMiscellaniesForLocation();
                // show first tab
                $('.customtab a[href="#list"]').tab('show');

                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else{
                // error message
                swal("Errore!", msg_err, "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", msg_err, "error");
        });
    });

    /**
     * Cancel button.
     */
    $('#place-loc-cancel').on('click', function(e){
        e.preventDefault();

        $('.customtab a[href="#list"]').tab('show');
        clearLocationFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END LOCATION FORM FUNCTIONS

    // TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close view report.
     */
    $('.card-body').on('click', '.close-detail', function(e){
        e.preventDefault();
        // get "element" to be closed
        var close = $(this).data("close");
        console.log(close);

        setTimeout(function(){
            // remove element and show first tab
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#list"]').tab('show');
        }, 1);
    });

    /////////////////////////////////////////////////////////////////////
    // END TAB FUNCTIONS

    // load stations
    $("#provinces, #loc-prov").trigger('change');
    // first load of miscellanies list in the first tab
    loadMiscellanies(dateFrom, dateTo);
    // first load of list in order to update all select html elements
    loadMiscellaniesForLocation();

    // UTILITIES
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
            return '<i class="icon-check text-info"></i> <span>Si</span>';
        else
            return '<i class="icon-close text-danger"></i> <span>No</span>';
    };

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
    };

    /**
     * Function that refreshes the gallery item.
     * No args needed
     */
    function refreshGalleryBig(){
        console.log("Refresh gallery BIG");
        $('.attachment-gallery-big').each(function() { // the containers for all your galleries
            $(this).magnificPopup({
                delegate: 'a', // the selector for gallery item
                type: 'image',
                gallery: {
                  enabled:true
                }
            });
        });
    };

    // END UTILITIES

    /**
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields(){
        // manage input type text
        $('.clear-input').val("");
        // manage select
        $('.clear-select').val(-1);
        // manage checkbox
        $('#equipment-active').prop("checked", true).trigger('change');
        // manage select 2
        $('#equipment-networks').val([]).trigger('change');
        // manage Switchery
        mySwitch.enable();
        setSwitchery(mySwitch, false);
        $("#add-location-fields").hide();
        // manage select
        $('#loc-stat').val(-1).trigger('change');
        // remove all attachments
        myDropzone.removeAllFiles(true);
        // reset div for attachments
        $('#img-container').empty();
        $('.attachment-files').empty();

        $('#hide-edit').show();

        // reset form text
        $('#new-element .box-title').text('Inserisci nuova dotazione');
        $('#btn-equipment-form').html(' <i class="ti-save"></i> Inserisci');

        // reset validate plugin
        $('#equipment-form').validate().resetForm(); // reset form error
    };

    /**
     * Function that resets fields of the location form.
     * No args needed
     */
    function clearLocationFields(){
        $('.hide-loc').hide();

        // reset form texts
        $('#new-location .box-title').text('Inserisci nuova location');
        $('#new-location .divider-title').text('Inserisci location');
        $('#place-loc-insert').html('<i class="icon-location-pin"></i> Inserisci');

        // enable fields
        $('#place-loc-equipment').prop('disabled', false);
        $('#place-loc-prov').prop('disabled', false);
        $('#place-loc-stat').prop('disabled', false);
        $('#place-loc-start-date').prop('disabled', false);

        // reset form fields
        $('#place-loc-id').val('');
        $('#place-loc-equipment').val(-1);
        $('#place-loc-stat').val(-1);
        $('#place-loc-start-date').val('');
        $('#place-loc-end-date').val('');
        $('#place-loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        $('#place-loc-start-date').trigger('change');
        $('#place-loc-notes').val('');

        // reset validate plugin
        $('#place-equipment-form').validate().resetForm();
    };

    /**
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     */
    function loadStations(prid, dest){
        console.log('loadStations: '+prid);

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#stations').empty();
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
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
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
     * Function that retrieves the stations of some given networks.
     *
     * @param {string}  dest Name of the html element.
     * @param {integer} prid Province ID.
     * @param {integer} nets ID of networks.
     * @param {integer} stid Station ID, if provided.
     */
    function loadStationsByNetworks(dest, prid, nets, stid){
        console.log('loadStationsByNetworks');
        console.dir(prid);
        console.dir(nets);
        console.log(dest);

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_stations_bynets',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                nets: nets
            },
        })
        .done(function(result) {
            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();
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
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);

                if(stid)
                    $('#'+dest).val(stid);
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
     * Function that retrieves the miscellanies of a given period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     */
    function loadMiscellanies(from, to){
        // get type of extraction and station id to be passed to server
        var type = $('#search-type').prop('checked');
        var stid = $("#stations").val();

        // reset datatable
        if ( table )
            table.clear();
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_miscellanies',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: from,
                to: to,
                stid: stid
            },
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadMiscellanies');

            // check if result is 'OK'
            if(result.res == 'OK'){
                var miscellanies = result.miscellanies;
                // variable for dinamically building the html
                var html= '';

                // check type of load
                // if true then search by location
                // if false then search by miscellanies
                if (type){ // STANZIAMENTO

                    // change table columns visibility
                    table.column(3).visible(false); // dismesso
                    $(table.column(4).header()).text('Location');
                    $(table.column(4).footer()).text('Location');
                    table.column(5).visible(true);
                    table.column(6).visible(true);

                    table.order( [ 5, 'desc' ] );
                }else{ // DOTAZIONI

                    // change table columns visibility
                    table.column(3).visible(true); // dismesso
                    $(table.column(4).header()).text('Location attuale');
                    $(table.column(4).footer()).text('Location attuale');
                    table.column(5).visible(false);
                    table.column(6).visible(false);

                    table.order( [ 2, 'asc' ] );
                }

                // check if at least one element exists
                if( miscellanies.length > 0 ){
                    /**
                     * <th class="bobo-nowrap"></th>
                     * <th class="bobo-nowrap">Arpa ID</th>
                     * <th>Dotazione</th>
                     * <th>Dismesso</th>
                     * <th>Location attuale</th>
                     * <th>Dal</th>
                     * <th>Al</th>
                     * <th>Attiva</th>
                     */

                    // loop through all elements
                    // for each miscellany, build a html row to be added to the datable
                    $.each(miscellanies, function(index, value) {
                        var isActive = '';
                        if (value.miscellany_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }
                        html += '<tr data-id="'+value.mi_id+'" data-stmiid="'+value.location_id+'" class="'+isActive+'">';
                        html += '    <td class="bobo-nowrap icons-little">';
                        html += '        <a href="javascript:void(0)" class="show-element" data-toggle="tooltip" data-original-title="Visualizza dotazione"> <i class="ti-zoom-in text-info"></i> </a>';
                        // if user has update grant
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-element" data-toggle="tooltip" data-original-title="Modifica dotazione"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        html += '        <a href="javascript:void(0)" class="pdf-element" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';
                        html += '        <br>';

                        if(update_grant){
                            if(value.location_id != null && (moment(value.location_end, 'DD/MM/YYYY HH:mm').isAfter(moment()) || value.location_end == 'infinito')) {
                                html += '        <a href="javascript:void(0)" class="edit-loc-el" data-toggle="tooltip" data-original-title="Modifica location"> <i class="icon-location-pin text-success"></i> </a>';
                                html += '        <a href="javascript:void(0)" class="close-loc-el" data-toggle="tooltip" data-original-title="Chiudi location corrente"> <i class="icon-close text-success"></i> </a>';
                            }
                        }
                        // if user has delete grant
                        if(delete_grant){
                            html += '        <a href="javascript:void(0)" class="delete-element" data-toggle="tooltip" data-original-title="Elimina tutto"> <i class="icon-trash text-danger"></i> </a>';
                        }
                        html += '    </td>';
                        html += '    <td>'+value.miscellany_arpa_id+'</td>';
                        html += '    <td>'+value.miscellany_name+'</td>';

                        var t = '<i class="icon-close text-danger"></i>';
                        if(value.miscellany_dismiss_date)
                            t = getFormattedDateDT(value.miscellany_dismiss_date, 'basic');

                        html += '    <td>'+t+'</td>';
                        html += '    <td>'+value.location+'</td>';
                        html += '    <td>'+value.location_start+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td class="hidden-lbl-icon">'+formatFlagField(value.miscellany_active)+'</td>';
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
                    });

                } else {
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle dotazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle dotazioni", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that retrieves the miscellanies not yet allocated.
     * No args needed
     */
    function loadMiscellaniesForLocation(){
        $('#place-loc-equipment').empty();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_miscellanies_for_location',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            var html = '<option value="-1">Seleziona...</option>';
            // check if the res is 'OK'
            if(result.res == 'OK'){

                var miscellanies = result.miscellanies;

                // check if at least one element exists
                if( miscellanies.length > 0 ){
                    // loop through all elements
                    // for each miscellany, build a html option to be added to the select
                    $.each(miscellanies, function(index, value) {
                        html += '<option '+value.miscellany_class+' value="'+value.mi_id+'" data-nets="'+JSON.stringify(value.network_types)+'">'+value.miscellany_name+'</option>';
                    });
                }
                // append html
                $('#place-loc-equipment').append(html);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle dotazioni ancora non stanziate", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle dotazioni ancora non stanziate", "error");
        });
    };

    /**
     * Function that builds the miscellany detail.
     *
     * @param {integer} miscid Miscellany ID.
     */
    function createMiscellanyDetail(miscid){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_dotazioni_get_miscellany_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: miscid
            },
        })
        .done(function(result) {
            console.log('show miscellany!');

            var miscellany = result.miscellany;
            // json objects to be parsed
            var attachments = JSON.parse(miscellany.miscellany_attachments);
            var locations = JSON.parse(miscellany.miscellany_locations);

            console.dir(miscellany);
            console.dir(attachments);
            console.dir(locations);

            var fullname = miscellany.miscellany_name;

            // add link for the new tab
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#misc'+miscid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+fullname+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-detail" data-close="misc'+miscid+'"></i></a></li>';
            $('.nav').append(html);

            // variable for dinamically building the html
            var html = '';

            /**
             * insert_time: "2021-12-21 09:59:03.314507"
             * insert_user: 4
             * mi_id: 1
             * miscellany_active: 1
             * miscellany_arpa_id: null
             * miscellany_owner: "Arpa Valle d'Aosta"
             * miscellany_attachments: null
             * miscellany_dismiss_date: null
             * miscellany_locations: "[{\"id\":1,\"location_id\":1004,\"location_name\":\"Aosta - I Maggio\",\"location_prov\":\"Aosta\",\"location_lat\":45.7324,\"location_lon\":7.32189,\"location_start\":\"2021-12-01T10:58:00\",\"location_end\":\"31/12/2022 10:58\",\"stmi_dismiss_date\":\"2022-12-31T10:58:00\",\"location_note\":\"test note location\"}]"
             * miscellany_name: "Test 001"
             * miscellany_note: "test note"
             * network_names: (2) ["Arpa Valle d'Aosta"]
             * network_types: (2) [3, 1]
             * user_avatar_thumb: "/bobo-img/default/avatar/ava01.png"
             * user_fullname: "Nome Cognome"
             */

            // after variable reset, build miscellany detail
            html += '<div class="tab-pane p-20" id="misc'+miscid+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '        <h4 class="box-title">Dotazione <strong>'+fullname+'</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Arpa ID</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(miscellany.miscellany_arpa_id)+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Dismesso il</label>\n';
            if (miscellany.miscellany_dismiss_date)
                html += '             <div class="col-4 view-param">' + moment(miscellany.miscellany_dismiss_date).format('DD/MM/YYYY') + '</i></div>\n';
            else
                html += '             <div class="col-4 view-param">' + formatFlagField(false) + '</i></div>\n';
            html += '        </div>\n';

            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Proprietario</label>\n';
            html += '            <div class="col-4 view-param">' + formatTextField(miscellany.miscellany_owner) + '</div>\n';
            var isActive;
            if(miscellany.miscellany_active){
                isActive = "Dotazione attiva";
            }else{
                isActive = "Dotazione NON attiva";
            }
            html += '            <label for="" class="control-label col-2 col-form-label">' + isActive + '</label>\n';
            html += '            <div class="col-4 view-param">' + formatFlagField(miscellany.miscellany_active) + '</i></div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Reti di appartenenza</label>\n';
            html += '            <div class="col-10 view-param">' + miscellany.network_names.join(', ') + '</div>\n';
            html += '        </div>\n';
            html += '       <div class="form-group row">\n';
            html += '           <label for="" class="control-label col-2 col-form-label">Note aggiuntive</label>\n';
            html += '           <div class="col-10 view-param">'+formatTextField(miscellany.miscellany_note)+'</div>\n';
            html += '       </div>\n';

            // check if there are attachments
            if(attachments != null){
                html += '        <h4 class="box-title">Allegati</strong></h4>\n';
                html += '        <hr class="m-t-0 m-b-20">\n';
                html += '        <div class="form-group row">\n';
                html += '            <label for="" class="control-label col-2 col-form-label">Allegati</label>\n';
                html += '            <div class="col-10 view-param">\n';

                var htmlImages = '';
                var htmlFiles = '';

                htmlImages +='        <div class="form-group row attachment-gallery-big">\n';
                htmlImages +='            <div class="col-10 offset-lg-2">\n';

                // loop through attachments
                // different items depending on the file type
                $.each(attachments, function(idx, attachment){
                    // check if current looped attachment is an image
                    if(attachment.file_image == true){
                        // image files
                        htmlImages +='<a href="'+attachment.file_path+'" class="clearfix thumb-gallery-lg"><img src="'+attachment.file_path+'"></a>\n';
                    }
                    else{
                        // other files
                        htmlFiles +='<a href="'+attachment.file_path+'"><i class="ti-download text-info"></i> '+attachment.file_name+'</a><br>\n';
                    }
                });

                htmlImages +='            </div>\n';
                htmlImages +='        </div>\n'; // row closure

                html += htmlFiles;

                html += '            </div>\n';
                html += '        </div>\n'; // row closure
                html += htmlImages;
            }

            // check if there is already any location
            if(locations && locations.length > 0){

                // get last location (first in the array)
                var actualLoc = locations[0];
                var flagActualLoc = true;

                // check if the location is still active
                if (actualLoc.stmi_dismiss_date == 'infinity' || moment(actualLoc.stmi_dismiss_date).isSameOrAfter(moment()) ){

                    /**
                     * location_id
                     * location_name
                     * location_prov
                     * location_lat
                     * location_lon
                     * location_start
                     * location_end
                     * location_note
                     */
                    html += '        <h4 class="box-title m-t-30">Location attuale della dotazione <strong>'+fullname+'</strong></h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <div class="form-group row">\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Provincia</label>\n';
                    html += '            <div class="col-4 view-param">'+actualLoc.location_prov+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Stazione</label>\n';
                    html += '            <div class="col-4 view-param">'+actualLoc.location_name+'</div>\n';
                    html += '        </div>\n';
                    html += '        <div class="form-group row">\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Data/ora inizio</label>\n';
                    html += '            <div class="col-4 view-param">'+moment(actualLoc.location_start).format('DD/MM/YYYY HH:mm')+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Data/ora fine</label>\n';
                    html += '            <div class="col-4 view-param">'+actualLoc.location_end+'</div>\n';
                    html += '        </div>\n';
                    html += '        <div class="form-group row">\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Note location</label>\n';
                    html += '            <div class="col-10 view-param">'+actualLoc.location_note+'</div>\n';
                    html += '        </div>\n';
                    html += '        <div id="map-view-'+miscid+'" class="mini-map" tabindex="0"></div>\n';

                }
                else{
                    // last location already closed
                    flagActualLoc = false;
                }

                // check if last location is already closed (history previous locations)
                // or if thera are previous closed locations
                if( !flagActualLoc || locations.length > 1){
                    html += '        <h4 class="box-title m-t-20">Storico delle <strong>location precedenti</strong></h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <table id="pos-table-'+miscid+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed" cellspacing="0" width="100%">\n';
                    html += '            <thead>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Stazione</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </thead>\n';
                    html += '            <tbody>\n';

                    $.each(locations, function(idx, location){

                        // if the last location (first in desc order) is still active
                        // then don't add it to the table
                        if (idx == 0 && flagActualLoc )
                            return;


                        html += '                <tr data-id="'+location.location_id+'">\n';
                        html += '                    <td>'+location.location_name+'</td>\n';
                        html += '                    <td>'+getFormattedDateDT(location.location_start, 'basic_timeStartMin')+'</td>\n';
                        html += '                    <td>'+location.location_end+'</td>\n';
                        html += '                    <td>'+location.location_note+'</td>\n';
                        html += '                </tr>\n';
                    });

                    html += '            </tbody>\n';
                    html += '            <tfoot>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Stazione</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </tfoot>\n';
                    html += '        </table>\n';
                }
            }

            html += '        <hr class="m-t-30">\n';
            html += '        <div class="form-group row">\n';
            html += '            <div class="col-12">\n';
            html += '                <button type="button" class="btn btn-primary close-detail" data-close="misc'+miscid+'"> <i class="icon-close"></i> Chiudi elemento</button>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '    </div>\n';
            html += '</div>\n';

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

            // append html
            $('.tab-content').append(html);

            // initialize gallery plugin
            refreshGalleryBig();

            // check if there is already any location
            if(locations && locations.length > 0){

                // initialize miscellany detail map
                initMapView(miscid, footer);
                // create layer and add coordinates of the last location
                var layer = createLayer('Attuale location', 0, mapView[miscid]);

                layer.setStyle(defaultStyleFunction);
                var feature = new ol.Feature({
                    popup_flag: false,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(locations[0].location_lon), parseFloat(locations[0].location_lat)], 'EPSG:4326', 'EPSG:3857'))
                });

                // add point to the layer
                layer.getSource().addFeature(feature);
                // zoom map view to point
                mapView[miscid].getView().fit(feature.getGeometry(), {
                    minResolution: 15
                });
                // check if there are previous locations
                // then initialize datatable
                if(locations.length >1 ){
                    $('#pos-table-'+miscid).DataTable({
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
                        "order": [[ 1, "desc" ]]
                    });
                }
            }

            // show the detail tab
            $('.customtab a[href="#misc'+miscid+'"]').tab('show');

            // manage resize map
            if(mapView[miscid]){
                setTimeout(function(){
                    // console.log(rpid);
                    mapView[miscid].updateSize();
                }, 100);
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della bombola", "error");
        });
    };

    /**
     * OpenStreetMap initialization function (detail map)
     *
     * @param {integer} id Map ID.
     * @param {string}  attributions Copyright attributions.
     */
    function initMapView(id, attributions) {

        // console.log('initMap');

        var selectedFeature;
        // set Italy map bounds
        var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
        boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

        var view = new ol.View();

        // create layer 'Satellite'
        var satellite = new ol.layer.Tile({
            name: 'Satellite',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                maxZoom: 23,
                attributions: 'Esri, Maxar, Earthstar Geographics, CNES/Airbus DS, USDA FSA, USGS, Getmapping, Aerogrid, IGN, IGP, and the GIS User Community - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // create layer 'Topografia'
        var hiking = new ol.layer.Tile({
            name: 'Topografia',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                // url: 'http://maps.refuges.info/hiking/{z}/{x}/{y}.png',
                url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                maxZoom: 23,
                attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors -  <a href="https://opentopomap.org/" target="_blank">OpenTopoMap</a> - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // initialize the map on the "map-view-XX" div
        // in the cylinder detail tab
        mapView[id] = new ol.Map({
            target: 'map-view-'+id,
            layers: [
                new ol.layer.Tile({
                    source: new ol.source.OSM({
                        attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors - '+attributions
                    }),
                    baseLayer: true,
                    name: 'Standard'
                }),
                hiking,
                satellite
            ],
            view: view,
            controls: ol.control.defaults.defaults({attribution: false})
        });

        // fit map view to Italy bounds
        view.fit(boundingExtent, mapView[id].getSize());

        /* CONTROLS */
        var fullscreen = new ol.control.FullScreen();
        mapView[id].addControl(fullscreen);

        // check if map attributions are not defined
        if(attributions != undefined ){
            // add attributions to the map
            var attribution = new ol.control.Attribution({
                collapsible: true
            });

            mapView[id].addControl(attribution);
        }

        return;
    };
});

