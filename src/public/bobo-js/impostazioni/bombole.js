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

    // variable for loadCylinders function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        // maxDate: end,
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

        // on change event, get cylinders within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh cylinders list in the first tab
        loadCylinders(dateFrom, dateTo);

    });

    // datatable
    table = $('#list-table').DataTable({
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 10,
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
        "order": [[ 5, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // hide table columns
    table.column(8).visible(false);
    table.column(9).visible(false);

    $( "#nets, #provinces, #loc-prov, #modal-loc-prov" ).select2();
    // select2 initialization
    $( "#tank-networks, #stations, #loc-stat" ).select2({
        matcher: searchGroupedSelect2
    });

    // 2 types of search: list of cylinders or list of allocations
    // for each type there are different descriptions and filters shown/hidden throught .select-place class
    $('.select-place, #active-loc').hide();

    $('#values-ins').hide();

    $('#search-type').on('change', function(e){
        e.preventDefault();
        var status = $(this).prop('checked'); // TRUE -> location ; FALSE -> cylinder
        // console.log(status);
        // check status
        //  - if true then location
        //  - if false then cylinder
        if (status){
            $('.select-place, #active-loc').show();
            $('#active-bomb').hide();
        }else{
            $('.select-place, #active-loc').hide();
            $('#active-bomb').show();
        }
    
        // refresh cylinders list in the first tab
        loadCylinders(dateFrom, dateTo);
    });

    $( "#nets, #provinces" ).on( "change", function() {

        if($(this).attr('id') == 'nets'){
            $("#provinces").val(-1);
        }

        var net = $('#nets').val();
        var prid = $('#provinces').val();

        // load list of stations
        loadStations(net, prid);
    });

    $( "#nets, #stations" ).on( "change", function() {
        // refresh cylinders list in the first tab
        loadCylinders(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive cylinder detail.
     */
    $('#list-table').on('click', '.show-element', function(e){
        e.preventDefault();

        // get cylinder id stored in tr
        var cyid = parseInt($(this).parent().parent().data("id"));

        // check if the cylinder's detail is already open
        if( $('#cy'+cyid).length ) {
            console.log('The cylinder\'s detail is already open');
            $('.customtab a[href="#cy' + cyid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createCylinderDetail(cyid);
    });

    /**
     * Edit cylinder.
     */
    $('#list-table').on('click', '.edit-element', function(e){
        e.preventDefault();

        // get cylinder id stored in tr
        var cyid = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get cylinder detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_cylinder_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: cyid
            },
        })
        .done(function(result) {
            console.log('edit cylider!');

            var cylinder = result.cylinder;
            // json objects to be parsed
            var attachments = JSON.parse(cylinder.cylinder_attachments);
            console.dir(cylinder);
            console.dir(attachments);

            // compile fields of the form with metadata arriving from database
            $('#tank-cy-id').val(cylinder.cy_id);
            $('#tank-arpa-id').val(cylinder.cylinder_arpa_id);
            $('#tank-name').val(cylinder.cylinder_name);
            $('#tank-date-built').val('');
            $('#tank-date-expiry').val('');
            $('#tank-date-built').bootstrapMaterialDatePicker('setDate', moment(cylinder.cylinder_built_date).format('DD/MM/YYYY'));
            $('#tank-date-expiry').bootstrapMaterialDatePicker('setDate', moment(cylinder.cylinder_expiry_date).format('DD/MM/YYYY'));

            $('#tank-category').val(cylinder.category_id).trigger('change');
            $('#tank-description').val(cylinder.cylinder_mixture);
            $('#val-first').val(cylinder.cylinder_ch_values[0]);
            if(cylinder.cylinder_ch_values.length > 1){
                $('#val-second').val(cylinder.cylinder_ch_values[1]);
                $('#val-third').val(cylinder.cylinder_ch_values[2]);
            }
            $('#tank-iszero').prop('checked', cylinder.cylinder_is_zero );
            $('#tank-active').prop('checked', cylinder.cylinder_active ).trigger('change');
            $('#tank-exhausted').prop('checked', cylinder.cylinder_is_exhausted );
            $('#tank-returned').prop('checked', cylinder.cylinder_is_returned );
            $('#tank-not-compliant').prop('checked', cylinder.cylinder_not_compliant );
            $('#tank-all-stations').prop('checked', cylinder.cylinder_all_stations );
            $('#tank-networks').val(cylinder.network_types).trigger('change.select2');

            // check if cylinder has attachments
            //  - if true then add attachemnts to the cylinder's detail page
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

            $('#tank-note').val(cylinder.cylinder_note);

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // hide section that cannot be visible during "edit" action
            $('#hide-edit').hide();

            // show form tab
            $('.customtab a[href="#new-element"]').tab('show');

            // modify 'Nuovo' text in 'Modifica'
            $('#new-element .box-title').text('Modifica bombola');
            $('#btn-tank-form').html(' <i class="ti-save"></i> Modifica');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della bombola", "error");
        });
    });

    /**
     * Edit location.
     */
    $('#list-table').on('click', '.edit-loc-el', function(e){
        e.preventDefault();

        // get location id stored in tr
        var stcyid = parseInt($(this).parent().parent().data("stcyid"));

        // get cylinder - location detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_location_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: stcyid
            }
        })
        .done(function(result) {
            console.dir(result);

            // check if result is OK
            //  - if res is 'OK' then success, fill location form
            //  - if res is not 'OK then error
            if(result.res == 'OK'){
                var location = result.location;
                var check = result.check;

                // compile fields of the form with data arriving from database
                $('#modal-loc-id').val(location.stcy_id);
                $('#modal-loc-tank').val(location.cy_id).trigger('change');
                $('#modal-loc-prov').trigger('change', location.station_id);
                
                /**
                 * stcy_id
                 * station_id
                 * cy_id
                 * stcy_startup_date
                 * stcy_dismiss_date
                 * stcy_note
                 */

                $('#modal-loc-start-date').val('');
                $('#modal-loc-start-date').bootstrapMaterialDatePicker('setDate', moment(location.stcy_startup_date).format('DD/MM/YYYY HH:mm'));
                $('#modal-loc-start-date').trigger('change');

                $('#modal-loc-end-date').val('');
                // manage datetime
                if(location.stcy_dismiss_date != 'infinity')
                    $('#modal-loc-end-date').bootstrapMaterialDatePicker('setDate', moment(location.stcy_dismiss_date).format('DD/MM/YYYY HH:mm'));

                $('#modal-loc-end-date').bootstrapMaterialDatePicker('setMinDate', moment() );
                $('#modal-loc-notes').val(location.stcy_note);

                $('#modal-loc-tank').prop('disabled', true);

                // check if cylinder has been already used during this allocation
                if(check == 1){
                    // disable fields that cannot be modified
                    $('#modal-loc-prov').prop('disabled', true);
                    $('#modal-loc-stat').prop('disabled', true);
                    $('#modal-loc-start-date').prop('disabled', true);
                }

                // modify 'Nuovo' text in 'Modifica'
                $('.customtab a[href="#new-location"]').tab('show');
                $('#new-location .box-title').text('Modifica location');
                $('#new-location .divider-title').text('Modifica location');
                $('#modal-loc-insert').html('<i class="icon-location-pin"></i> Modifica');
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
        var stcyid = parseInt($(this).parent().parent().data("stcyid"));

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
                url: '/cnf_bombole_put_location_closure',
                type: "post",
                dataType: "json",
                data: {
                    id: stcyid
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, clear fields and load location list
                //  - if false then error
                if(result){
                    swal("Location chiusa", "La location è stata chiusa con successo!", "success");
                    // refresh cylinders list in the first tab
                    loadCylinders(dateFrom, dateTo);
                    // reset location form fields
                    clearLocationFields();
                    // reload lists in order to update all select html elements
                    loadCylindersForLocation();
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
     * Download cylinder detail.
     */
    $('#list-table').on('click', '.pdf-element', function(e){
        swal("PDF scaricato", "Il PDF è stato scaricato con successo!", "success");
        e.preventDefault();
    });

    /**
     * Delete cylinder.
     */
    $('#list-table').on('click', '.delete-element', function(e){
        e.preventDefault();

        // get cylinder id stored in tr
        var cyid = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai per eliminare <strong>definitivamente</strong> la bombola",
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
                url: '/cnf_bombole_del_cylinder',
                type: "post",
                dataType: "json",
                data: {
                    id: cyid
                }
            })
            .done(function(result) {
                // check result
                //  - if '-1' then it's impossible to delete the cylinder because it has been already used in other applications
                //  - if '1' then the cylinder is correctly deleted -> clear all fields
                //  - else error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile eliminare la bombola perchè <strong>GIÀ USATA</strong> nel report tarature e/o nel planning.",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == 1){
                    swal("Bombola eliminata", "La bombola è stata eliminata con successo!", "success");
                    // remove row from table
                    table.row($("tr[data-id='"+cyid+"']")).remove().draw();

                    clearFields();
                    clearLocationFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della bombola", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione della bombola", "error");
            });

        });
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    $("#add-location-fields").hide();

    // START Dropzone //
    var url = "/cnf_bombole_put_cylinder";

    myDropzone = initDropzoneFiles(url);
    // END Dropzone //

    /**
     * Dismission date of the new cylinder.
     */
    $('#tank-date-built').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });

    /**
     * Expiration datetime of the new cylinder.
     */
    $('#tank-date-expiry').bootstrapMaterialDatePicker({
        minDate: moment().format("DD/MM/YYYY"),
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
     * Switchery button of new cylinder.
     */
    $('#tank-active').bootstrapToggle();
    mySwitch = new Switchery($("#add-location")[0], $("#add-location").data());

    /**
     * Category selection of the new cylinder.
     */
    $('#tank-category').on('change', function() {

        $('.show-first').show();
        $('.show-second').show();
        $('.show-third').show();
        $('.show-first input').val('');
        $('.show-second input').val('');
        $('.show-third input').val('');

        // manage field visibility based on selected cylinder category
        var res = $('#tank-category').val();
        switch(parseInt(res)) {
            case 1: // so2
                $('#values-ins').show();
                $('label.show-first').text('Val SO2');
                $('.show-second').hide();
                $('.show-third').hide();
                break;
            case 2: // nox
                $('#values-ins').show();
                $('label.show-first').text('Val NOX');
                $('label.show-second').text('Val NO');
                $('label.show-third').text('Val NO2');
                break;
            case 3: // co
                $('#values-ins').show();
                $('label.show-first').text('Val CO');
                $('.show-second').hide();
                $('.show-third').hide();
                break;
            case 5: // btx
                $('#values-ins').show();
                $('label.show-first').text('Val BEN');
                $('label.show-second').text('Val TOL');
                $('label.show-third').text('Val XIL');
                break;
            case 7: // ch4
                $('#values-ins').show();
                $('label.show-first').text('Val CH4');
                $('.show-second').hide();
                $('.show-third').hide();
                break;
            case 16: // polveri
            case 18: // areosol
                $('#values-ins').show();
                $('label.show-first').text('Val RIF');
                $('.show-second').hide();
                $('.show-third').hide();
                break;
            default:
                $('#values-ins').hide();
                break;
        }
    });

    /**
     * Network selection of the new cylinder.
     */
    $('#tank-networks').on('change', function(e){
        // get element destination where appending new stations
        var dest = $(this).data('dest');

        // retrieve network ids and the province id
        // if networks are not empty
        if($(this).val().length > 0){
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
     * Disable Switcher button when 'Stanziata in tutte le stazioni' is selected.
     */
    $('input#tank-all-stations').on('change', function(e) {
        e.preventDefault();
        if ($(this).is(':checked')) {
            mySwitch.disable();
            setSwitchery(mySwitch, false);
            $("#add-location-fields").hide();
        }else{
            mySwitch.enable();
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
                url: '/cnf_bombole_del_attachment',
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
     * Add location to new cylinder Switchery button.
     */
    $('#add-location').on( "change", function() {
        var ckb = mySwitch.isChecked();
        // show/hide location form
        if (ckb){
            $("#add-location-fields").show();
        }else{
            $("#add-location-fields").hide();
        }
    });

    /**
     * New location province selection.
     */
    $('#loc-prov').on( "change", function() {
        var prid = $(this).val();
        var dest = $(this).data('dest');
        var nets = JSON.stringify($('#tank-networks').val());
        // refresh stations in the "dest" element
        loadStationsByNetworks(dest, prid, nets);
    });

    /**
     * Validate form.
     */
    var validator = $('#tank-form').validate({ // initialize the plugin
        rules: {
            "tank-description" : {
                required: true
            },
            "tank-date-built" : {
                required: true
            },
            "tank-date-expiry" : {
                required: true
            },
            "tank-category":{
                required: true,
                min: 0
            },
            "val-first" :{
                required: true,
                dotSeparator: true
            },
            "val-second" :{
                required: true,
                dotSeparator: true
            },
            "val-third" :{
                required: true,
                dotSeparator: true
            },
            "tank-networks":{
                required: true,
                allowEmpty: false
            },
            "loc-stat":{
                required:  function (element) {
                    return mySwitch.isChecked();
                },
                min:  function (element) {
                    if(mySwitch.isChecked()){return 0;}else{return -1;}
                },
            },
            "loc-start-date":{
                required:  function (element) {
                    return mySwitch.isChecked();
                },
            },
        },
        messages: {
            "tank-description" : {
                required: "Inserire miscela"
            },
            "tank-date-built" : {
                required: "Inserire data produzione"
            },
            "tank-date-expiry" : {
                required: "Inserire data scadenza"
            },
            "tank-category":{
                required: "Selezionare categoria",
                min: "Selezionare categoria"
            },
            "val-first" :{
                required: "Inserire concentrazione"
            },
            "val-second" :{
                required: "Inserire concentrazione"
            },
            "val-third" :{
                required: "Inserire concentrazione"
            },
            "tank-networks":{
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
     * Function called when using Dropzone submit.
     */
    myDropzone.on("sendingmultiple", function(files, xhr, formData) {

        var form = $('#tank-form');

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
        var id   = $("#tank-cy-id").val();

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

            // refresh cylinders list in the first tab
            loadCylinders(dateFrom, dateTo);
            // reload lists in order to update all select html elements
            loadCylindersForLocation();
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
     * Submit of the new/edit cylinder form.
     */
    $('#tank-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Bombola non salvata!", "info");
            return false;
        };

        var form = $("#tank-form");
        var id   = $("#tank-cy-id").val();

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
                url: '/cnf_bombole_put_cylinder',
                type: 'post',
                dataType: "json",
                data: form.serialize()
            }).done(function(result) {
                // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
                if(result){
                    swal("Successo", msg_ok, "success");

                    // refresh cylinders list in the first tab
                    loadCylinders(dateFrom, dateTo);
                    // reload lists in order to update all select html elements
                    loadCylindersForLocation();
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
    $('#cancel-tank-form').on('click', function(e) {
        $('.customtab a[href="#list"]').tab('show');
        clearFields();
        e.preventDefault();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    // TAB LOCATION FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Selection of the cylinder location.
     */
    $('#modal-loc-tank').on( "change", function() {
        console.log($(this).val());
        var cyid = parseInt($(this).val());
        console.log(cyid);

        // check if cylinder is selected
        //  - if not '-1' then show new location form
        //  - if '-1' then hide new location form
        if(cyid != -1){
            // get networks to which selected cylinder is associated
            // and programatically select values
            $('#modal-networks').val( JSON.stringify( $('#modal-loc-tank option:selected').data('nets') ));
            // reload stations
            $('#modal-loc-prov').trigger("change");
            // show "new location" form
            $('.hide-loc').show('slow');
        }
        else{
            // reset select
            $('#modal-networks').val('');
            // hide "new location" form
            $('.hide-loc').hide('slow');
        }
    });

    /**
     * Province selection of the new location.
     */
    $('#modal-loc-prov').on( "change", function(e, stid) {
        var prid = $(this).val();
        var dest = $(this).data('dest');
        var nets = $('#modal-networks').val();

        // refresh stations in the "dest" element
        loadStationsByNetworks(dest, prid, nets, stid);
    });

    /**
     * New location start and end insertion datetime.
     */
    $('#modal-loc-start-date, #modal-loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date equal to start time picker value
        $('#modal-loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#modal-loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#modal-loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#modal-loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#modal-loc-end-date').val('');
    });

    // set first value
    $('#modal-loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
    $('#modal-loc-start-date').trigger('change');

    /**
     * Validate form.
     */
    var modalValidator = $('#modal-tank-form').validate({ // initialize the plugin
        rules: {
            "modal-loc-tank" : {
                required: true
            },
            "modal-loc-stat" : {
                required: true,
                min: 0
            },
            "modal-loc-start-date" : {
                required: true
            }
        },
        messages: {
            "modal-loc-tank" : {
                required: "Selezionare bombola"
            },
            "modal-loc-stat":{
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "modal-loc-start-date" : {
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
    $('#modal-tank-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Stanziamento non salvato!", "info");
            return false;
        };

        var form = $("#modal-tank-form");
        var id   = parseInt($("#modal-loc-id").val());
        var cyid = parseInt($('#modal-loc-tank').val());

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

        // ajax call
        $.ajax({
            url: '/cnf_bombole_put_location',
            type: 'post',
            dataType: "json",
            data: form.serialize()
        }).done(function(result) {
            // check result
            //  - if '-1' then it's impossible to delete the cylinder location because the item has been already used in other applications
            //  - if '1' then the cylinder is correctly deleted -> clear all fields
            //  - else error
            if(result == -1){
                swal({
                    title: "Attenzione!",
                    text: "Impossibile stanziare la bombola nel periodo selezionato perchè <strong>GIÀ STANZIATA</strong>.<br>Modificare le date dello stanziamento",
                    type: "warning",
                    html: true
                });
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
            else if(result == 1){
                swal("Successo", msg_ok, "success");

                // refresh cylinders list in the first tab
                loadCylinders(dateFrom, dateTo);
                // reset location form fields
                clearLocationFields();
                // reload lists in order to update all select html elements
                loadCylindersForLocation();

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
    $('#modal-loc-cancel').on('click', function(e){
        e.preventDefault();

        // show first tab
        $('.customtab a[href="#list"]').tab('show');
        // reload lists in order to update all select html elements
        loadCylindersForLocation();
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
    $("#nets, #loc-prov").trigger('change');
    // first load of cylinders list in the first tab
    // not needed -> called by nets' change event
    // loadCylinders(dateFrom, dateTo);

    // first load of lists in order to update all select html elements
    loadCylindersForLocation();

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
    }

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
    }

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
        $('.clear-select').val(-1);
        // manage checkbox
        $(".clear-ckb").prop("checked", false);
        // manage checkbox
        $('#tank-active').prop("checked", true).trigger('change');
        // manage select 2
        $('#tank-networks').val([]).trigger('change');
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
        // reset form texts
        $('#new-element .box-title').text('Inserisci nuova bombola');
        $('#btn-tank-form').html(' <i class="ti-save"></i> Inserisci');
        // reset validate plugin
        $('#tank-form').validate().resetForm(); // reset form error
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
        $('#modal-loc-insert').html('<i class="icon-location-pin"></i> Inserisci');

        // enable fields
        $('#modal-loc-tank').prop('disabled', false);
        $('#modal-loc-prov').prop('disabled', false);
        $('#modal-loc-stat').prop('disabled', false);
        $('#modal-loc-start-date').prop('disabled', false);

        // reset form fields
        $('#modal-loc-id').val('');
        $('#modal-loc-tank').val(-1).trigger('change');
        $('#modal-loc-stat').val(-1);
        $('#modal-loc-start-date').val('');
        $('#modal-loc-end-date').val('');
        $('#modal-loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        $('#modal-loc-start-date').trigger('change');
        $('#modal-loc-notes').val('');

        // reset validate plugin
        $('#modal-tank-form').validate().resetForm();
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     */
    function loadStations(net, prid){
        console.log('loadStations: '+prid);

        // get stations via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_stations',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#stations').empty();
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

                    $('#provinces').empty();
                    $('#provinces').append('<option value="-1">Seleziona provincia...</option>');
                    $('#provinces').append(optsProv);
                    $('#provinces').append('</optgroup>');

                    $('#provinces').val(-1);
                }
                // append options
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                $('#stations').append('</optgroup>');
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
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} prid Province ID.
     * @param {integer} nets ID of networks.
     * @param {integer} stid Station ID.
     */
    function loadStationsByNetworks(dest, prid, nets, stid){
        console.dir(nets);

        // get stations by nets via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_stations_bynets',
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
     * Function that retrieves the cylinders of a given period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     */
    function loadCylinders(from, to){

        var type = $('#search-type').prop('checked');
        var net  = $("#nets").val();
        var stid = $("#stations").val();

        // reset datatable
        if ( table )
            table.clear();

        $('.inner-preloader').show();

        // get cylinders via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_cylinders',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: from,
                to: to,
                net: net,
                stid: stid
            },
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadCylinders');

            // check if result is 'OK'
            if(result.res == 'OK'){
                var cylinders = result.cylinders;
                // variable for dinamically building the html
                var html= '';

                // check type of load
                // if true then search by location
                // if false then search by cylinder
                if (type){ // STANZIAMENTO
                    // change table columns visibility
                    table.column(5).visible(false); // produzione
                    table.column(6).visible(false); // scadenza
                    $(table.column(7).header()).text('Location');
                    $(table.column(7).footer()).text('Location');
                    table.column(8).visible(true);
                    table.column(9).visible(true);

                    table.order( [ 8, 'desc' ] );
                }else{ // BOMBOLE
                    // change table columns visibility
                    table.column(5).visible(true); // produzione
                    table.column(6).visible(true); // scadenza
                    $(table.column(7).header()).text('Location attuale');
                    $(table.column(7).footer()).text('Location attuale');
                    table.column(8).visible(false);
                    table.column(9).visible(false);

                    table.order( [ 5, 'desc' ] );
                }

                // check if at least one element exists
                if( cylinders.length > 0 ){
                    // loop through all elements
                    // for each cylinder, build a html row to be added to the datable
                    $.each(cylinders, function(index, value) {
                        var isActive = '';
                        if (value.cylinder_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }

                        html += '<tr data-id="'+value.cy_id+'" data-stcyid="'+value.location_id+'" class="'+isActive+'">';
                        html += '    <td class="bobo-nowrap icons-little">';
                        html += '        <a href="javascript:void(0)" class="show-element" data-toggle="tooltip" data-original-title="Visualizza bombola"> <i class="ti-zoom-in text-info"></i> </a>';
                        // if user has update grant
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-element" data-toggle="tooltip" data-original-title="Modifica bombola"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        // html += '        <a href="javascript:void(0)" class="pdf-element" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';
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
                        html += '    <td>'+value.cylinder_arpa_id+'</td>';
                        html += '    <td>'+value.cylinder_name+'</td>';
                        html += '    <td>'+value.cylinder_mixture+'</td>';
                        html += '    <td>[ '+value.cylinder_ch_values.join(', ')+' ]</td>';
                        html += '    <td>'+getFormattedDateDT(value.cylinder_built_date, 'basic')+'</td>';
                        html += '    <td>'+getFormattedDateDT(value.cylinder_expiry_date, 'basic')+'</td>';
                        html += '    <td>'+value.location+'</td>';
                        html += '    <td>'+(type ? getFormattedDateDT(value.location_start, 'basic_timeStartMin') : '--')+'</td>';
                        html += '    <td>'+value.location_end+'</td>';
                        html += '    <td class="hidden-lbl-icon">'+formatFlagField(value.cylinder_is_exhausted)+'</td>';
                        html += '    <td class="hidden-lbl-icon">'+formatFlagField(value.cylinder_active)+'</td>';
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
                swal("Errore!", "Errore durante il recupero delle bombole", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle bombole", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that retrieves the cylinders not yet allocated.
     * No args needed
     */
    function loadCylindersForLocation(){

        $('#modal-loc-tank').empty();
        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_cylinders_for_location',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            var html = '<option value="-1">Seleziona...</option>';
            // check if result is 'OK'
            if(result.res == 'OK'){

                var cylinders = result.cylinders;

                // check if at least one element exists
                if( cylinders.length > 0 ){
                    // loop through all cylinders
                    // for each cylinder, build a html option to be added to the select
                    $.each(cylinders, function(index, value) {
                        var expiryTxt = '';
                        // check if the cylinder is expired
                        if( moment().isSameOrAfter(value.cylinder_expiry_date) ){
                            // add text info about expiration date
                            expiryTxt = ' scad. '+ moment(value.cylinder_expiry_date).format('DD/MM/YYYY');
                        }

                        html += '<option '+value.cylinder_class+' value="'+value.cy_id+'" data-nets="'+JSON.stringify(value.network_types)+'">'+value.cylinder_name+''+expiryTxt+'</option>';
                    });
                }
                // append html
                $('#modal-loc-tank').append(html);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle bombole ancora non stanziate", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle bombole ancora non stanziate", "error");
        });
    };

    /**
     * Function that builds the cylinder detail.
     *
     * @param {integer} cyid Cylinder ID.
     */
    function createCylinderDetail(cyid){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_bombole_get_cylinder_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: cyid
            },
        })
        .done(function(result) {
            console.log('show cylinder!');

            var cylinder = result.cylinder;
            // json objects to be parsed
            var attachments = JSON.parse(cylinder.cylinder_attachments);
            var locations = JSON.parse(cylinder.cylinder_locations);

            console.dir(cylinder);
            console.dir(attachments);
            console.dir(locations);

            var fullname = cylinder.cylinder_mixture;
            if(cylinder.cylinder_name != null){
                fullname = cylinder.cylinder_name+' - '+fullname;
            }

            // add link for the new tab
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#cy'+cyid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+fullname+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-detail" data-close="cy'+cyid+'"></i></a></li>';
            $('.nav').append(html);

            // variable for dinamically building the html
            var html = '';

            /**
             * category_id: 1
             * category_name: "Analizzatore SO2"
             * cy_id: 4
             * cylinder_active: 0
             * cylinder_all_stations: 0
             * cylinder_arpa_id: "OPAS0004"
             * cylinder_attachments: "[{\"file_id\":1,\"file_name\":\"smottamenti.jpg\",\"file_path\":\"uploads/impostazioni/bombole/000000004/file-20210907115710-95788.jpg\",\"file_image\":true},{\"file_id\":2,\"file_name\":\"caduta-massi.jpg\",\"file_path\":\"uploads/impostazioni/bombole/000000004/file-20210907115710-13496.jpg\",\"file_image\":true},{\"file_id\":3,\"file_name\":\"Aggiornamenti BOBO.txt\",\"file_path\":\"uploads/impostazioni/bombole/000000004/file-20210907115710-76009.txt\",\"file_image\":false},{\"file_id\":4,\"file_name\":\"Strumenti OPAS.xlsx\",\"file_path\":\"uploads/impostazioni/bombole/000000004/file-20210907115710-82395.xlsx\",\"file_image\":false}]"
             * cylinder_built_date: "2021-09-01"
             * cylinder_ch_values: [6.23]
             * cylinder_expiry_date: "2021-09-07"
             * cylinder_is_exhausted: 1
             * cylinder_is_returned: 0
             * cylinder_is_zero: 1
             * cylinder_mixture: "Test Miscela 4"
             * cylinder_name: "Test Nome 4"
             * cylinder_not_compliant: 0
             * cylinder_note: "test bombola"
             * insert_time: "2021-09-07 09:57:09.939776"
             * insert_user: null
             * network_names: (2) ['Arpa Liguria', 'Arpa Emilia-Romagna']
             * network_types: (2) [3, 2]
             */

            // after variable reset, build cylinder detail
            html += '<div class="tab-pane p-20" id="cy'+cyid+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '        <h4 class="box-title">Bombola <strong>'+fullname+'</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Arpa ID</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(cylinder.cylinder_arpa_id)+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Nome</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(cylinder.cylinder_name)+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Produzione</label>\n';
            html += '            <div class="col-4 view-param">'+moment(cylinder.cylinder_built_date).format('DD/MM/YYYY')+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Scadenza</label>\n';
            html += '            <div class="col-4 view-param">'+moment(cylinder.cylinder_expiry_date).format('DD/MM/YYYY')+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Categoria</label>\n';
            html += '            <div class="col-4 view-param">'+cylinder.category_name+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Miscela</label>\n';
            html += '            <div class="col-4 view-param">'+cylinder.cylinder_mixture+'</div>\n';
            html += '        </div>\n';
            html += '        <div class="form-group row">\n';

            switch(cylinder.category_id) {
                case 1: //so2
                    html += '            <label for="" class="control-label col-2 col-form-label">Val SO2</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>\n';
                    break;
                case 2: //nox
                    html += '            <label for="" class="control-label col-2 col-form-label">Val NOX</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Val NO</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[1]+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Val NO2</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[2]+'</div>\n';
                    break;
                case 3: //co
                    html += '            <label for="" class="control-label col-2 col-form-label">Val CO</label>';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>';
                    break;
                case 5: //btx
                    html += '            <label for="" class="control-label col-2 col-form-label">Val BEN</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Val TOL</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[1]+'</div>\n';
                    html += '            <label for="" class="control-label col-2 col-form-label">Val XIL</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[2]+'</div>\n';
                    break;
                case 7: //ch4
                    html += '            <label for="" class="control-label col-2 col-form-label">Val CH4</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>\n';
                    break;
                case 16: //polveri
                case 18: //areosol
                    html += '            <label for="" class="control-label col-2 col-form-label">Val RIF</label>\n';
                    html += '            <div class="col-2 view-param">'+cylinder.cylinder_ch_values[0]+'</div>\n';
                    break;
                default:
                    break;
            }

            html += '        </div>\n';
            html += '        <div class="form-group row">\n';
            if(cylinder.cylinder_is_zero){
                html += '            <div class="col-10 offset-2 view-param p-b-5 hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_is_zero)+' Bombola di zero</div>\n';
            }
            var isActive;
            if(cylinder.cylinder_active){
                isActive = "Bombola attiva";
            }else{
                isActive = "Bombola NON attiva";
            }
            html += '            <div class="col-10 offset-2 view-param"><strong class="hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_active)+' '+isActive+'</strong></div>\n';
            html += '        </div>\n';
            html += '        <h4 class="box-title">Ulteriori dettagli</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';

            html += '        <div class="form-group row">\n';
            html += '            <div class="offset-2 col-10 view-param view-ckb">\n';
            if(cylinder.cylinder_is_exhausted){
                html += '                <span class="hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_is_exhausted)+' Esaurita</span>\n';
            }
            if(cylinder.cylinder_is_returned){
                html += '                <span class="hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_is_returned)+' Resa</span>\n';
            }
            if(cylinder.cylinder_not_compliant){
                html += '                <span class="hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_not_compliant)+' Non conforme</span>\n';
            }
            if(cylinder.cylinder_all_stations){
                html += '                <span class="hidden-lbl-icon">'+formatFlagField(cylinder.cylinder_all_stations)+' Stanziata in tutte le stazioni</span>\n';
            }
            html += '            </div>\n';
            html += '        </div>\n';

            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Reti di appartenenza</label>\n';
            html += '            <div class="col-4 view-param">'+cylinder.network_names.join(', ')+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Note bombola</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(cylinder.cylinder_note)+'</div>\n';
            html += '        </div>\n';

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
                        htmlFiles +='<a href="'+attachment.file_path+'" target="_blank"><i class="ti-download text-info"></i> '+attachment.file_name+'</a><br>\n';
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
                if (actualLoc.stcy_dismiss_date == 'infinity' || moment(actualLoc.stcy_dismiss_date).isSameOrAfter(moment()) ){

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
                    html += '        <h4 class="box-title m-t-30">Location attuale della bombola <strong>'+fullname+'</strong></h4>\n';
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
                    html += '        <div id="map-view-'+cyid+'" class="mini-map" tabindex="0"></div>\n';

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
                    html += '        <table id="pos-table-'+cyid+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed" cellspacing="0" width="100%">\n';
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
            html += '                <button type="button" class="btn btn-primary close-detail" data-close="cy'+cyid+'"> <i class="icon-close"></i> Chiudi elemento</button>\n';
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

                // initialize cylinder detail map
                initMapView(cyid, footer);
                // create layer and add coordinates of the last location
                var layer = createLayer('Attuale location', 0, mapView[cyid]);

                layer.setStyle(defaultStyleFunction);
                var feature = new ol.Feature({
                    popup_flag: false,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(locations[0].location_lon), parseFloat(locations[0].location_lat)], 'EPSG:4326', 'EPSG:3857'))
                });

                // add point to the layer
                layer.getSource().addFeature(feature);
                // zoom map view to point
                mapView[cyid].getView().fit(feature.getGeometry(), {
                    minResolution: 15
                });
                // check if there are previous locations
                // then initialize datatable
                if(locations.length >1 ){
                    $('#pos-table-'+cyid).DataTable({
                        "dom": "Bfrtip",
                        // 'copy', 'csv', 'excel', 'pdf', 'print'
                        "buttons": [
                            'csv',
                            'pdf',
                            {
                                "extend": 'print',
                                "text"  : 'STAMPA'
                            }
                        ],
                        "order": [[ 1, "desc" ]],
                        "language": {
                            "url": "/bobo-js/italian.json"
                        }

                    });
                }
            }

            // show the detail tab
            $('.customtab a[href="#cy'+cyid+'"]').tab('show');

            // manage resize map
            if(mapView[cyid]){
                setTimeout(function(){
                    // console.log(rpid);
                    mapView[cyid].updateSize();
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

