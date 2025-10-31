/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var myDropzone;

    var mapView = [];

    // variable for loadInstruments function
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

        // on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh instruments list in the first tab
        loadInstruments();
    });
    
    // define all datetime formats to be managed by datatable
    // $.fn.dataTable.moment("DD/MM/YYYY");

    // Custom type added that manages Moment and '--'
    $.fn.dataTable.ext.type.order['custom-date-pre'] = function (d) {
        // If it is '-', return a very large value
        if (d.trim() === '--') {
            return -Infinity;
        }

        // Parsing with moment
        var m = moment(d, 'DD/MM/YYYY', true); // true = strict parsing
        if (m.isValid()) {
            return m.valueOf(); // timestamp
        }

        return -Infinity; // fallback if parsing fails
    };

    // datatable
    table = $('#list-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        lengthMenu: [[10, 25, 50, 100, -1], [10, 25, 50, 100, "Tutti"]],
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
            { "orderable": false, "targets": 0, "width": "60px" },
            { "type": "custom-date", "targets": [7,8] }
        ],
        "order": [[ 7, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    $( "#nets, #categories" ).select2();

    /**
     * Change event on filters
     */
    $( "#nets, #categories" ).on( "change", function() {
        // refresh instruments list in the first tab
        loadInstruments();
    });

    /**
     * Change event on checkbox filter
     */
    $('#all-instruments').on('change', function() {
        if ($(this).is(':checked')) {
            // disabilita input
            $('.input-daterange-datepicker').prop('disabled', true);

            // svuota campo
            $('.input-daterange-datepicker').val('');

            // reset variabili globali (se servono)
            dateFrom = '-infinity';
            dateTo = '+infinity';
        } else {
            // riabilita input
            $('.input-daterange-datepicker').prop('disabled', false);

            // variable for loadInstruments function
            dateTo = moment().format('YYYY-MM-DD 23:59:59');
            dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

            // variable for datepicker plugin (different format)
            start = moment(dateFrom).format("DD/MM/YYYY");
            end = moment(dateTo).format("DD/MM/YYYY");

            // ripristina date di default
            $('.input-daterange-datepicker').data('daterangepicker').setStartDate(start);
            $('.input-daterange-datepicker').data('daterangepicker').setEndDate(end);

            // aggiorna valore del campo visibile
            $('.input-daterange-datepicker').val(
                start.format('DD/MM/YYYY') + ' - ' + end.format('DD/MM/YYYY')
            );
        }

        loadInstruments();
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive instrument detail.
     */
    $('#list-table').on('click', '.show-element', function(e){
        e.preventDefault();

        // get instrument id stored in tr
        var inid = parseInt($(this).parent().parent().data("id"));

        // check if the instrument's detail is already open
        if( $('#in'+inid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#in' + inid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createInstrumentDetail(inid);
    });

    /**
     * Edit instrument.
     */
    $('#list-table').on('click', '.edit-element', function(e){
        e.preventDefault();

        // get instrument id stored in tr
        var inid = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get instrument detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instrument_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: inid
            },
        })
        .done(function(result) {
            console.log('edit instrument!');

            // category_id: 5
            // category_name: "Analizzatore BTX"
            // insert_time: "2022-02-18 08:00:14.689151"
            // insert_user: null
            // instr_id: 1
            // instr_type_fullname: "SYNTHEC SPECTRAS GC955"
            // instr_type_id: 181
            // instrument_active: 1
            // instrument_arpa_id: "00512"
            // instrument_owner: "Arpa Valle d'Aosta"
            // instrument_attachments: null
            // instrument_delivery_date: null
            // instrument_dismiss_date: null
            // instrument_locations: "[{\"id\":1,\"location_id\":1000,\"location_name\":\"Aosta - Plouves\",\"location_prov\":\"Aosta\",\"location_lat\":45.7369,\"location_lon\":7.32372,\"location_start\":\"2015-10-01T00:00:00\",\"location_end\":\"infinito\",\"stin_dismiss_date\":\"infinity\",\"location_note\":\"--\"}]"
            // instrument_name: null
            // instrument_note: null
            // instrument_serial_num: "1752"
            // network_names: ["Arpa Valle d'Aosta"]
            // network_types: [1]
            // user_avatar_thumb: null
            // user_fullname:

            console.log('edit cylider!');

            var instrument = result.instrument;
            // json objects to be parsed
            var attachments = JSON.parse(instrument.instrument_attachments);

            console.dir(instrument);
            console.dir(attachments);

            // compile fields of the form with metadata arriving from database
            $('#instr-id').val(instrument.instr_id);
            $('#instr-type').val(instrument.instr_type_id).trigger('change');
            $('#instr-name').val(instrument.instrument_name);
            $('#instr-arpa-id').val(instrument.instrument_arpa_id);
            $('#instr-serial-num').val(instrument.instrument_serial_num);
            $('#instr-owner').val(instrument.instrument_owner);

            $('#instr-date-delivery').val('');
            $('#instr-date-disuse').val('');
            if(instrument.instrument_delivery_date)
                $('#instr-date-delivery').bootstrapMaterialDatePicker('setDate', moment(instrument.instrument_delivery_date).format('DD/MM/YYYY'));
            if(instrument.instrument_dismiss_date)
                $('#instr-date-disuse').bootstrapMaterialDatePicker('setDate', moment(instrument.instrument_dismiss_date).format('DD/MM/YYYY'));
            // destroy and re-itialize bootstraptoggle in order to not trigger change event
            $('#instr-active').prop('checked', instrument.instrument_active).bootstrapToggle('destroy').bootstrapToggle();

            $('#instr-networks').val(instrument.network_types).trigger('change.select2');

            $('#instr-note').val(instrument.instrument_note);

            // check if instrument has attachments
            //  - if true then add attachemnts to the instrument's detail page
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
                        htmlImages +='      <span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="fa-regular fa-trash"></i> </span><a href="'+attachment.file_path+'" class="clearfix thumb-gallery"><img src="'+attachment.file_path+'"></a>\n';
                        htmlImages +='    </div>\n';
                    }
                    else{
                        // other files
                        htmlFiles +='<li><span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="fa-regular fa-trash"></i></span> <a href="'+attachment.file_path+'"><i class="fa-regular fa-paperclip"></i> '+attachment.file_name+'</a></li>';
                    }
                });

                htmlFiles += '</ul>';

                // append files
                $('#img-container').append(htmlImages);
                $('.attachment-files').append(htmlFiles);

                // image gallery
                refreshGalleryBig();
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // hide section that cannot be visible during "edit" action
            $('#hide-edit').hide();

            // show form tab
            $('.customtab a[href="#new-element"]').tab('show');

            // modify 'Nuovo' text in 'Modifica'
            $('#new-element .box-title').text('Modifica strumento');
            $('#btn-instrument-form').html(' <i class="fa-regular fa-arrow-down-to-arc"></i> Modifica');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dello strumento", "error");
        });
    });

    /**
     * Download instrument detail.
     */
    $('#list-table').on('click', '.pdf-element', function(e){
        e.preventDefault();
        swal("Report scaricato", "Il report è stato scaricato con successo!", "success");
    });

    /**
     * Delete instrument.
     */
    $('#list-table').on('click', '.delete-element', function(e){
        e.preventDefault();

        // get instrument id stored in tr
        var inid = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai per eliminare <strong>definitivamente</strong> lo strumento",
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
                url: '/cnf_strumenti_del_instrument',
                type: "post",
                dataType: "json",
                data: {
                    id: inid
                }
            })
            .done(function(result) {
                // check result
                //  - if '-1' then it's impossible to delete the instrument because it has been already used in other applications
                //  - if '1' then the instrument is correctly deleted -> clear all fields
                //  - else error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile eliminare lo strumento perchè <strong>GIÀ USATO</strong> nei report.",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == 1){
                    swal("Strumento eliminato", "Lo strumento è stato eliminato con successo!", "success");
                    // remove row from table
                    table.row($("tr[data-id='"+inid+"']")).remove().draw();

                    clearFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione dello strumento", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione dello strumento", "error");
            });
        });
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    $('#instr-active').bootstrapToggle();
    $("#add-location-fields").hide();

    $( "#instr-type, #instr-networks" ).select2();
    $( "#loc-prov" ).select2();
    // select2 initialization
    $( "#loc-stat" ).select2({
        matcher: searchGroupedSelect2
    })

    mySwitch = new Switchery($("#add-location")[0], $("#add-location").data());
    console.dir(mySwitch);

    // START Dropzone //
    var url = "/cnf_strumenti_put_instrument";

    myDropzone = initDropzoneFiles(url);
    // END Dropzone //

    // // Form element // //
    $('#instr-date-delivery').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang: 'it',
        cancelText: 'Annulla',
        time: false
    });
    /**
     * Dismission/disuse date of the new instrument.
     */
    $('#instr-date-delivery, #instr-date-disuse').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    });
    
    $('#instr-date-disuse').on('change', function(){
        // destroy and re-itialize bootstraptoggle in order to not trigger change event
        $('#instr-active').prop('checked', false).bootstrapToggle('destroy').bootstrapToggle();
    });

    /**
     * Change event on checkbox 
     */
    $('#instr-active').on('change', function(){
        // get toggle status
        var status = $(this).is(':checked');

        // check toggle status
        //  - if false: reset datetime to now
        //  - if true: clear field only
        if(status == false){
            $('#instr-date-disuse').val('');
            $('#instr-date-disuse').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));
        }
        else{
            $('#instr-date-disuse').val('');
        }
    });

    /**
     * Network selection of the new instrument.
     */
    $('#instr-networks').on('change', function(e){
        // if(flag == false)
        //     return;
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
     * Delete attachement.
     */
    $('.tab-content').on('click', '.del-attachment-ico', function(e){
        e.preventDefault();

        console.log('click');

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
                url: '/cnf_strumenti_del_attachment',
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
     * Add location to new instrument Switchery button.
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
     * New location start and end insertion datetime.
     */
    $('#loc-start-date, #loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date as start time picker value
        $('#loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#loc-end-date').val('');
    });

    /**
     * New location province selection.
     */
    $( "#loc-prov" ).on( "change", function() {
        var prid = $(this).val();
        var dest = $(this).data('change');
        var nets = JSON.stringify($('#instr-networks').val());
        // refresh stations in the "dest" element
        loadStationsByNetworks(dest, prid, nets);
    });

    $( "#instr-type, #loc-stat" ).on( "change", function() {
        var stid = $('#loc-stat').val();
        var dest = $('#loc-stat').data('change');
        var intyid = $('#instr-type').val();
        // refresh parameters in the "dest" element
        loadParametersByInstrument(dest, stid, intyid);
    });

    /**
     * Validate form.
     */
    var validator = $('#instrument-form').validate({ // initialize the plugin
        rules: {
            "instr-type":{
                required: true,
                min: 0
            },
            "instr-name":{
                required: function(element){
                    return ( $('#instr-arpa-id').val() == '' && $('#instr-serial-num').val() == '' );
                }
            },
            "instr-arpa-id":{
                required: function(element){
                    return ( $('#instr-name').val() == '' && $('#instr-serial-num').val() == '' );
                }
            },
            "instr-serial-num":{
                required: function(element){
                    return ( $('#instr-arpa-id').val() == '' && $('#instr-name').val() == '' );
                }
            },
            "instr-date-delivery" : {
                required: true
            },
            "instr-networks":{
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
            "loc-params":{
                required:  function (element) {
                    if(mySwitch.isChecked()){return true;}else{return false;}
                },
                min:  function (element) {
                    if(mySwitch.isChecked()){return 0;}else{return -1;}
                },
            },
        },
        messages: {
            "instr-type":{
                required: "Selezionare tipologia",
                min: "Selezionare tipologia"
            },
            "instr-name":{
                required: "Inserire almeno un campo tra Nome, Arpa ID e Numero di serie"
            },
            "instr-arpa-id":{
                required: "Inserire almeno un campo tra Nome, Arpa ID e Numero di serie"
            },
            "instr-serial-num":{
                required: "Inserire almeno un campo tra Nome, Arpa ID e Numero di serie"
            },
            "instr-date-delivery" : {
                required: "Inserire data consegna",
            },
            "instr-networks":{
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
            "loc-params" : {
                required: "Selezionare parametri collegati",
                min: "Selezionare parametri collegati"
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

        var form = $('#instrument-form');

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
        var id   = $("#instr-id").val();

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
        //  - if -1 then the parameter is already associated to another instrument
        //  - if 1 then success, reload the list in the first tab, show the table and reset form
        //  - else then error
        if(response == -1){
            swal({
                title: "Attenzione!",
                text: "Impossibile associare lo strumento al parametro nel periodo selezionato, perchè il parametro è <strong>GIÀ COLLEGATO</strong> ad un altro strumento.<br>Disabilitare il primo strumento oppure modificare le date dello stanziamento",
                type: "warning",
                html: true
            });
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        }
        else if(response == 1){
            console.log('Success');
            swal("Successo", msg_ok, "success");

            // refresh instruments list in the first tab
            loadInstruments();
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
     * Submit new/edit instrument form.
     */
    $('#instrument-form').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Strumento non salvato!", "info");
            return false;
        };

        var form = $("#instrument-form");
        var id   = $("#instr-id").val();

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
                url: '/cnf_strumenti_put_instrument',
                type: 'post',
                dataType: "json",
                data: form.serialize()
            }).done(function(result) {
                console.dir(result);
                // check result
                //  - if -1 then the parameter is already associated to another instrument in the selected period
                //  - if 1 then success, reload the list in the first tab, show the table and reset form
                //  - else then error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile associare lo strumento al parametro nel periodo selezionato, perché il parametro è <strong>GIÀ COLLEGATO</strong> ad un altro strumento.<br>Disabilitare il primo strumento oppure modificare le date dello stanziamento",
                        type: "warning",
                        html: true
                    });

                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }
                else if(result == 1){
                    console.log('Success');
                    swal("Successo", msg_ok, "success");

                    // refresh instruments list in the first tab
                    loadInstruments();
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
    $('#cancel-instrument-form').on('click', function(e) {
        e.preventDefault();

        $('.customtab a[href="#list"]').tab('show');
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM NEW INSTRUMENT FUNCTIONS

    // TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close detail.
     */
    $('.card').on('click', '.close-detail', function(e){
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


    // UTILITIES

    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null, the string '--';
     *         If not, the string provided before.
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
            return '<i class="fa-solid fa-check text-info"></i> Si';
        else
            return '<i class="fa-regular fa-x text-danger"></i> No';
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
        $("#instr-type").trigger('change.select2');
        // manage checkbox
        $("#first-instr").prop("checked", true);
        // manage select 2
        $('#instr-networks').val([]).trigger('change');
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
        $('#new-element .box-title').text('Inserisci nuovo STRUMENTO');
        $('#btn-instrument-form').html(' <i class="fa-regular fa-arrow-down-to-arc"></i> Inserisci');
        // reset validate plugin
        $('#instrument-form').validate().resetForm(); // reset form error
    };

    /**
     * Function that retrieves the stations of some given networks.
     *
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} prid Province ID.
     * @param {integer} nets ID of networks.
     * @param {integer} stid Station ID.
     * @param {integer} groupid Instrument-parameter ID.
     */
    function loadStationsByNetworks(dest, prid, nets, stid, groupid){
        console.dir(nets);
        console.log(dest);

        // get stations by nets via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_stations_bynets',
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

                if(stid){
                    $('#'+dest).val(stid).trigger('change', groupid);
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
    };

    /**
     * Function that retrieves the parameters that can be associated to a given instrument.
     *
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} stid Station ID.
     * @param {integer} intyid Instrument type ID.
     * @param {integer} groupid Instrument-parameter ID.
     */
    function loadParametersByInstrument(dest, stid, intyid, groupid){
        console.log('loadParametersByInstrument');
        console.log(groupid);

        // get parameters by instrument type via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_params_by_instr_type',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                intyid: intyid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();
                var params = result.params;
                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each parameter, build a html option to be added to the select
                $.each(params, function(index, param){
                    opts += '<option value="'+ param.stpr_group_id+'">'+param.parameters+'</option>';
                });
                // append options
                $('#'+dest).append('<option value="-1">Seleziona...</option>');
                $('#'+dest).append('<option value="0">Nessun parametro associabile</option>');
                $('#'+dest).append(opts);

                if(groupid != null)
                    $('#'+dest).val(groupid);
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
    };

    /**
     * Function that retrieves the instruments of a given period.
     * No args needed
     */
    function loadInstruments(){

        // type: false instruments list, true locations list
        var type = false;
        var net  = $("#nets").val();
        var stid = $("#stations").val();
        var cat  = $("#categories").val();

        // reset datatable
        if ( table )
            table.clear();

        $('.inner-preloader').show();

        // get instruments via ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instruments',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: dateFrom,
                to: dateTo,
                net: net,
                stid: stid,
                cat: cat
            }
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadInstruments');

            // check if result is 'OK'
            if(result.res == 'OK'){
                var instruments = result.instruments;
                // variable for dinamically building the html
                var html= '';

                // check if at least one element exists
                if( instruments.length > 0 ){
                    
                    // loop through all elements
                    // for each instrument, build a html row to be added to the datable
                    $.each(instruments, function(index, value) {
                        var isActive = '';
                        if (value.instrument_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }
                        html += '<tr data-id="'+value.instr_id+'" data-stinid="'+value.location_id+'" class="'+isActive+'">';
                        html += '    <td class="bobo-nowrap toolbar-icons">';
                        html += '        <a href="javascript:void(0)" class="show-element" data-toggle="tooltip" data-original-title="Visualizza strumento"> <i class="fa-light fa-magnifying-glass-plus text-info"></i> </a>';
                        // if user has update grant
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-element" data-toggle="tooltip" data-original-title="Modifica strumento"> <i class="fa-light fa-pen text-info"></i> </a>';
                        }

                        // Tipo
                        // Nome
                        // S.N.
                        // Categoria
                        // Arpa ID
                        // Consegnato
                        // Dismesso
                        // Location
                        // Reti

                        // if user has delete grant
                        if(delete_grant){
                            html += '        <a href="javascript:void(0)" class="delete-element" data-toggle="tooltip" data-original-title="Elimina tutto"> <i class="fa-light fa-trash-can text-danger"></i> </a>';
                        }
                        html += '    </td>';
                        html += '    <td>'+value.instr_id+'</td>'; // Tipo
                        html += '    <td>'+value.instrument_type_fullname+'</td>'; // Tipo
                        html += '    <td>'+value.instrument_name+'</td>'; // Nome
                        html += '    <td>'+value.instrument_serial_num+'</td>'; // SN
                        html += '    <td>'+value.category_name+'</td>';
                        html += '    <td>'+value.instrument_arpa_id+'</td>';
                        html += '    <td>'+( !value.instrument_delivery_date ? '--' : moment(value.instrument_delivery_date).format('DD/MM/YYYY') )+'</td>';
                        html += '    <td>'+( !value.instrument_dismiss_date  ? '--' : moment(value.instrument_dismiss_date).format('DD/MM/YYYY') )+'</td>';
                        html += '    <td>'+value.location+'</td>';
                        html += '    <td>'+value.network_names.join(', ')+'</td>';
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
                swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli strumenti", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that builds the instrument detail.
     *
     * @param {integer} inid Instrument ID.
     */
    function createInstrumentDetail(inid){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_strumenti_get_instrument_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: inid
            },
        })
        .done(function(result) {
            console.log('show instrument!');

            var instrument = result.instrument;
            // json objects to be parsed
            var attachments = JSON.parse(instrument.instrument_attachments);
            var locations = JSON.parse(instrument.instrument_locations);

            console.dir(instrument);
            console.dir(attachments);
            console.dir(locations);

            var fullname = instrument.instr_type_fullname;
            if(instrument.instrument_name != null){
                fullname = fullname+' - '+instrument.instrument_name;
            }

            // add link for the new tab
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#in'+inid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-wave-sine"></i></span> <span class="hidden-xs-down">'+fullname+'</span>&nbsp;&nbsp;<i class="fa-solid fa-xmark text-danger close-detail" data-close="in'+inid+'"></i></a></li>';
            $('.nav').append(html);

            // variable for dinamically building the html
            var html = '';

            /**
             * category_id
             * category_name
             * insert_time
             * insert_user
             * instr_id
             * instr_type_fullname
             * instr_type_id
             * instrument_active
             * instrument_arpa_id
             * instrument_attachments
             * instrument_delivery_date
             * instrument_dismiss_date
             * instrument_locations
             * instrument_name
             * instrument_note
             * instrument_serial_num
             * network_names
             * network_types
             * user_avatar_thumb
             * user_fullname
             * instrument_owner
             */

            // after variable reset, build instrument detail
            html += '<div class="tab-pane p-20" id="in'+inid+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '         <h4 class="box-title"><strong>'+fullname+'</strong> (categoria: <strong>'+instrument.category_name+'</strong>)</h4>\n';
            html += '         <hr class="m-t-0 m-b-20">\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Arpa ID</label>\n';
            html += '             <div class="col-4 view-param">'+formatTextField(instrument.instrument_arpa_id)+'</div>\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Numero di serie</label>\n';
            html += '             <div class="col-4 view-param">'+formatTextField(instrument.instrument_serial_num)+'</div>\n';
            html += '         </div>\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Consegnato il</label>\n';
            if(instrument.instrument_delivery_date)
                html += '             <div class="col-4 view-param">'+moment(instrument.instrument_delivery_date).format('DD/MM/YYYY')+'</i></div>\n';
            else
                html += '             <div class="col-4 view-param">'+formatFlagField(false)+'</i></div>\n';

            html += '             <label for="" class="control-label col-2 col-form-label">Dismesso il</label>\n';
            if(instrument.instrument_dismiss_date)
                html += '             <div class="col-4 view-param">'+moment(instrument.instrument_dismiss_date).format('DD/MM/YYYY')+'</i></div>\n';
            else
                html += '             <div class="col-4 view-param">'+formatFlagField(false)+'</i></div>\n';
            html += '         </div>\n';
            html += '         <div class="form-group row">\n';
            html += '             <label for="" class="control-label col-2 col-form-label">Proprietario</label>\n';
            html += '             <div class="col-4 view-param">' + formatTextField(instrument.instrument_owner) + '</div>\n';
            var isActive;
            if(instrument.instrument_active){
                isActive = "Strumento attivo";
            }else{
                isActive = "Strumento NON attivo";
            }
            html += '             <label for="" class="control-label col-2 col-form-label">'+isActive+'</label>\n';
            html += '             <div class="col-4 view-param">' + formatFlagField(instrument.instrument_active) +'</i></div>\n';
            html += '         </div>\n';
            html += '        <h4 class="box-title">Ulteriori dettagli</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Reti di appartenenza</label>\n';
            html += '            <div class="col-4 view-param">'+instrument.network_names.join(', ')+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Note strumento</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(instrument.instrument_note)+'</div>\n';
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
                        htmlFiles +='<a href="'+attachment.file_path+'" target="_blank"><i class="fa-regular fa-download"></i> '+attachment.file_name+'</a><br>\n';
                    }
                });

                htmlImages +='            </div>\n';
                htmlImages += '        </div>\n'; // row closure

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
                if (actualLoc.stin_dismiss_date == 'infinity' || moment(actualLoc.stin_dismiss_date).isSameOrAfter(moment()) ){

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

                    html += '        <h4 class="box-title m-t-30">Location attuale dello strumento <strong>'+fullname+'</strong></h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <div class="row">\n';
                    html += '            <div class="col-md-7 col-xl-6">\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Provincia</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_prov+'</div>\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Stazione</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_name+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Data/ora inizio</label>\n';
                    html += '                    <div class="col-7 view-param">'+moment(actualLoc.location_start).format('DD/MM/YYYY HH:mm')+'</div>\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Data/ora fine</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_end+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Parametri collegati</label>\n';
                    html += '                    <div class="col-7 view-param">'+(actualLoc.location_params.length == 0 ? '--' : actualLoc.location_params.join(', '))+'</div>\n';
                    html += '                    <div class="col-7 offset-5 view-param">Strumento principale: '+formatFlagField(actualLoc.location_master)+'</div>\n';
                    html += '                </div>\n';
                    html += '                <div class="form-group row">\n';
                    html += '                    <label for="" class="control-label col-5 col-form-label">Note location</label>\n';
                    html += '                    <div class="col-7 view-param">'+actualLoc.location_note+'</div>\n';
                    html += '                </div>\n';
                    html += '            </div>\n';
                    html += '            <div class="col-md-5 col-xl-6">\n';
                    html += '                 <div id="map-view-'+inid+'" class="mini-map" tabindex="0"></div>\n';
                    html += '            </div>\n';
                    html += '        </div>\n';

                    // html += '        <hr class="m-t-0 m-b-20">\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Provincia</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_prov+'</div>\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Stazione</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_name+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Data/ora inizio</label>\n';
                    // html += '            <div class="col-4 view-param">'+moment(actualLoc.location_start).format('DD/MM/YYYY HH:mm')+'</div>\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Data/ora fine</label>\n';
                    // html += '            <div class="col-4 view-param">'+actualLoc.location_end+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Parametri collegati</label>\n';
                    // html += '            <div class="col-4 view-param">'+(actualLoc.location_params.length == 0 ? '--' : actualLoc.location_params.join(', '))+'</div>\n';
                    // html += '            <div class="col-4 offset-2 view-param">'+formatFlagField(actualLoc.location_master)+' Strumento principale</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div class="form-group row">\n';
                    // html += '            <label for="" class="control-label col-2 col-form-label">Note location</label>\n';
                    // html += '            <div class="col-10 view-param">'+actualLoc.location_note+'</div>\n';
                    // html += '        </div>\n';
                    // html += '        <div id="map-view-'+inid+'" class="mini-map" tabindex="0"></div>\n';
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
                    html += '        <table id="pos-table-'+inid+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed" cellspacing="0" width="100%">\n';
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
                    html += '        <hr class="m-t-20 m-b-20">\n';
                    html += '        <div id="container-instr-'+inid+'" class="">\n';
                    html += '        </div>\n';
                }
            }

            html += '        <hr class="m-t-30">\n';
            html += '        <div class="form-group row">\n';
            html += '            <div class="col-12">\n';
            html += '                <button type="button" class="btn btn-primary close-detail" data-close="in'+inid+'"> <i class="fa-regular fa-xmark-large"></i> Chiudi elemento</button>\n';
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

                // initialize instrument detail map
                initMapView(inid, footer);
                // create layer and add coordinates of the last location
                var layer = createLayer('Attuale location', 0, mapView[inid]);

                layer.setStyle(defaultStyleFunction);
                var feature = new ol.Feature({
                    popup_flag: false,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(locations[0].location_lon), parseFloat(locations[0].location_lat)], 'EPSG:4326', 'EPSG:3857'))
                });

                // add point to the layer
                layer.getSource().addFeature(feature);
                // zoom map view to point
                mapView[inid].getView().fit(feature.getGeometry(), {
                    minResolution: 15
                });
                // check if there are previous locations
                // then initialize datatable
                if(locations.length >1 ){
                    $('#pos-table-'+inid).DataTable({
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

                    // create the gantt chart with all the previous locations
                    let obj = result.gantt_locations;
                    let locs = JSON.parse(obj.instrument_locations);

                    Highcharts.ganttChart('container-instr-'+ inid, {
                        title: {
                            text: obj.instrument_fullname
                        },
                        xAxis: [{
                            labels: {
                                format: '{value:%Y}'
                            },
                            min: locs[0].start,
                            max: locs[locs.length - 1].end,
                            tickInterval: 1000 * 60 * 60 * 24 * 365// year
                        }],
                        yAxis: {
                            uniqueNames: true
                        },
                        tooltip: {
                            formatter: function () {
                                // console.dir(this);
                                return '<b>' + this.name + '</b><br>Data inizio: <b>' + getFormattedDateDT(this.start, 'basic_timeStartMin') + '</b><br>Data fine: <b>' + getFormattedDateDT(this.end, 'basic_timeStartMin') + '</b>';
                            }
                            // format:
                        },
                        credits: {
                            text: '© ' + footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                            href: company_web
                        },
                        series: [{
                            name: 'Stanziamenti',
                            data: locs
                        }]
                    });
                }
            }

            // show the detail tab
            $('.customtab a[href="#in'+inid+'"]').tab('show');

            // manage resize map
            if(mapView[inid]){
                setTimeout(function(){
                    // console.log(rpid);
                    mapView[inid].updateSize();
                }, 100);
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dello strumento", "error");
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
