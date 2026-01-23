/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var mySwitchMulti;
    var myDropzone;

    // edit variables
    var repCalib;

    // variable for loadReports function
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
            'Oggi': [moment(), moment()],
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

        var stid = $('#stations').val();
        // refresh reports list in the first tab
        loadReports(dateFrom, dateTo, stid);

    });

    // datatable
    table = $('#report-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            },
            {
                text: '<i class="fa-solid fa-copy"></i> PDF REPORTS',
                className: 'btn-custom',
                action: function ( e, dt, node, config ) {
                    var net = $('#networks').val();
                    if(net == -1){
                        swal('Attenzione', 'Selezionare almeno una rete per effettuare il download cumulativo dei report', 'warning');
                    }else{
                        downloadPDF(dateFrom, dateTo);
                    }
                }
            }
        ],
        responsive: {
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
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "desc" ]]
    });

    $( "#networks, #provinces" ).select2();

    $.fn.select2.defaults.set("width", null);
    $("#stations").select2({
        matcher: searchGroupedSelect2
    });

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    /**
     * Filters change events
     */
    $( "#networks, #provinces" ).on( "change", function() {

        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        var net = $('#networks').val();
        var prid = $('#provinces').val();
        var dest = $('#provinces').data('change');
        // refresh stations list
        loadStations(net, prid, dest);
    });

    $( "#stations, #str-categories" ).on( "change", function() {
        var stid = $('#stations').val();
        // refresh reports list in the first tab
        loadReports(dateFrom, dateTo, stid);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retrieve report detail.
     */
    $('#report-table').on('click', '.show-report', function(e){

        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        //check if the report's detail is already open
        if( $('#rep'+rpid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#rep' + rpid + '"]').tab('show');
            return;
        }
        // build html detail and open new tab
        createReportDetail(rpid);
    });

    /**
     * Edit report.
     */
    $('#report-table').on('click', '.edit-report', function(e){

        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // recover report detail via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_tarature_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {
            console.log('edit report!');

            // check result
            if(result.res == 'OK'){
                // fill fields of the form with metadata arriving from database
                var report = result.report;
                console.dir(report);

                // calib_fulldate: "2021-02-01 07:55:00"
                // calib_fulldate_formatted: "01/02/2021 alle 07:55"
                // calib_id: 1
                // calib_multipoint: 0
                // calib_note: "TEST TEST TEST"
                // calib_re_id: 6
                // calib_reason: "Altro"
                // category_id: 2
                // category_name: "Analizzatore NOx"
                // instr_arpa_id: "OPAS00011"
                // instr_id: 4
                // instr_name: "Test1_Plouves"
                // instr_serial_num: "1200011"
                // instr_type_fullname: "Teledyne API 200EU"
                // instr_type_id: 10
                // province_id: 1
                // province_name: "Aosta"
                // station_id: 1000
                // station_name: "Aosta - Plouves"
                // us_id: 4
                // user_fullname: ""

                $('#report-caid').val(report.calib_id);
                $('#datetime-calib').val("");
                $('#datetime-calib').bootstrapMaterialDatePicker('setDate', report.calib_fulldate_formatted);

                // store report in a global variable in order to build dinamic instrument fields
                repCalib  = report;

                $('#prov-calib').val(report.province_id).trigger("change", [report.station_id, report.instr_id]);

                $('#notes-calib').val(report.calib_note);
                $('#reason-calib').val(report.calib_re_id);

                // check if report has attachments
                //  - if true then add attachments to the form
                if(report.attachments){
                    // parse json object
                    var attachments = JSON.parse(report.attachments);
                    $('#report-del-attach').show();

                    var html = '';

                    html += '    <div class="del-my-imgs report-gallery-big clearfix">'
                    // loop through attachments
                    // different items depending on the file type
                    $.each(attachments, function(inner_index, inner_value){
                        if (inner_value.file_image == true){
                            html += '        <span><span class="del-attachment-ico" data-attid="'+inner_value.att_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span><a href="/uploads/report/qa_tarature/'+inner_value.file_archive+'" class="clearfix thumb-gallery"><img src="/uploads/report/qa_tarature/'+inner_value.file_archive+'"></a></span>';
                        }
                    });
                    html += '    </div>';

                    // loop for not image attachments
                    html += '    <div class="del-my-files attachment-files">';
                    html += '        <ul>';
                    $.each(attachments, function(inner_index, inner_value){
                        if (inner_value.file_image == false){
                            html += '            <li>';
                            html += '                <span class="del-attachment-ico" data-attid="'+inner_value.att_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span>'+inner_value.file_original+'';
                            html += '            </li>';
                        }
                    });
                    html += '        </ul>';
                    html += '    </div>';

                    $('#att-container').append(html);
                }
                // image gallery
                refreshGalleryBig();

                // modify 'Nuovo' text in 'Modifica'
                $('#new .box-title').text('Modifica TARATURA');
                $('#inner-new-report').text('Modifica');
                $('#save-calib').html(' <i class="ti-save"></i> Modifica report');

                // show form tab
                $('.customtab a[href="#new"]').tab('show');

                // not necessary, called in editInstrument function
                // $(".inner-preloader").hide();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del report", "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", msg_err, "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

    /**
     * Download PDF report.
     */
    $('#report-table').on('click', '.pdf-report', function(e){
        e.preventDefault();

        console.log('Download report\'s PDF');
        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        var url = "/rep_qa_tarature_get_pdf";

        /**
         * http://johnculviner.com/category/jquery-file-download/
         */
        $.fileDownload(url, {
            httpMethod: 'GET',
            data: {
                rpid: rpid
            },
            successCallback: function(url) {
                console.log("PDF scaricato correttamente");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            },
            failCallback: function(responseHtml, url, error) {
                // take care of any errors from ajax call
                // error message
                swal("Errore!", "Il file pdf non è stato creato oppure errore durante lo scarico", "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        });

        console.log('End download');
        // this is critical to stop the click event which will trigger a normal file download!
        return false;
    });

    /**
     * Delete report.
     */
    $('#report-table').on('click', '.delete-report', function(e){
        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        // confirm message in order to continue in report deleting
        swal({
            title: "Stai per eliminare il report",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/rep_qa_tarature_del_report',
                type: "post",
                dataType: "json",
                data: {
                    id: rpid
                }
            })
            .done(function(result) {
                // check result
                //  - if '1' then the report is correctly deleted -> remove it from table
                //  - if '-1' then it's impossible to delete the report because it has been already used in other applications
                //  - else error
                if(result == 1){
                    // delete row from datatable without reloading the entire list and refresh it
                    swal("Report eliminato", "Il report è stato eliminato con successo!", "success");
                    table.row($("tr[data-id='"+rpid+"']")).remove().draw();
                }
                else if(result == -1){
                    // warning message
                    swal("Attenzione!", "Il report selezionato è associato a un report manutenzione. Eliminazione non consentita", "warning");
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del report", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione del report", "error");
            });

        });
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // hide containers for multiple calibration fields
    $( "#row-multi" ).hide();
    $('.multiple-calibration').hide();
    // hide all instruments fields
    $('.hide-fields-instrument').hide();

    // set default value
    $('#reason-calib').val(1);

    $( "#prov-calib, #instrument-calib" ).select2();

    /**
     * New calibration insertion datetime.
     */
    $('#datetime-calib').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('open', function(){
        $('#datetime-calib').bootstrapMaterialDatePicker('setMaxDate', moment().format('DD/MM/YYYY HH:mm'));
    });
    // set default value
    $('#datetime-calib').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

    // select2 initialization
    $("#station-calib").select2({
        matcher: searchGroupedSelect2
    });

    // switchery initialization
    mySwitchMulti = new Switchery($("#flag-multi")[0], $("#flag-multi").data());

    // START Dropzone //
    var url = "/rep_qa_tarature_put_report";

    myDropzone = initDropzoneFiles(url);
    // END Dropzone //

    /**
     * Datetime change event
     */
    $("#datetime-calib" ).on( "change", function() {
        // retrieve report fulldate and station id
        var dt = $(this).val();
        var stid = parseInt($('#station-calib').val());

        // if station id equal to -1 then reset instruments select
        // else load instruments linked to station at the time of calibration and fill select element
        if(stid == -1){
            $('#instrument-calib').empty();
            $('#instrument-calib').append('<option value="-1">Seleziona strumento...</option>');
            $('#instrument-calib').val(-1).trigger('change');
        }
        else
            loadInstruments(stid, dt);
    });

    /**
     * New calibration province selection.
     */
    $( "#prov-calib" ).on( "change", function(e, stid, instrid) {
        // retrieve province id and station select id
        var prid = $(this).val();
        var dest = $(this).data('change');
        // refresh stations list
        // if prid equal to -1 then load all stations
        loadStations(-1, prid, dest, stid, instrid);
    });

    /**
     * New calibration station selection.
     */
    $( "#station-calib" ).on( "change", function(e, instrid) {
        // retrieve report fulldate and station id
        var stid = parseInt($(this).val());
        var dt = $('#datetime-calib').val();

        // if station id equal to -1 then reset instruments select
        // else load instruments linked to station at the time of calibration and fill select element
        if(stid == -1){
            $('#instrument-calib').empty();
            $('#instrument-calib').append('<option value="-1">Seleziona strumento...</option>');
            $('#instrument-calib').val(-1).trigger('change');
        }
        else
            loadInstruments(stid, dt, instrid);
    });

    /**
     * New calibration instrument selection.
     */
    $('#instrument-calib').on('change', function() {
        // Reset multiple calibration fields
        resetCalibObject();
        // reset insruments calibration fields
        clearFieldsInstruments();

        // get instrument id
        var instr = parseInt($('#instrument-calib').val());
        // get instrument id
        var catId = $('#instrument-calib option:selected').data('ctid');
        // get station id
        var stid = parseInt($('#station-calib').val());
        // get report fulldate
        var dt = $('#datetime-calib').val();

        // if repCalib object is defined then it's an EDIT action
        if (repCalib){

            // show corret div based on instrument category
            showInstrumentDiv(catId);
            // check if it's a multipoint calibration
            // and manage the switchery element
            if(repCalib.calib_multipoint == 1){
                setSwitchery(mySwitchMulti, true);
            }else{
                setSwitchery(mySwitchMulti, false);
            }

            // get calibration values object and parse it
            var instrObj = JSON.parse(repCalib.calib_values);
            // load metadata in order to fill calibration fields
            // and pass the previous object
            loadMetadata(stid, catId, dt, instrObj);
            // reset edit variable
            repCalib = null;
        }else{

            // if instrument not equal to -1
            // then show corret div based on instrument category
            // and load metadata in order to fill calibration fields
            if(instr != -1){
                showInstrumentDiv(catId);
                loadMetadata(stid, catId, dt);
            }

            // else do nothing
        }
    });

    /**
     * New calibration multiple calibration button selection.
     */
    $('#flag-multi').on('change', function() {
        // reset insruments calibration fields
        clearFieldsInstruments();

        // set default visibility
        $('.multiple-calibration').hide();
        $('.single-calibration').show();

        // check status of the switchery
        var status = mySwitchMulti.isChecked();
        var type = $('#row-multi').attr("data-id");
        // manage visibility
        if(status){
            $('#'+type+'-multi').show();
            $('#'+type+'-single').hide();
        }else{
            $('#'+type+'-multi').hide();
            $('#'+type+'-single').show();
        }
    });

    /**
     * Tank selection
     */
    $('.tanks').on('change', function() {

        // check if it's a tank for the span
        // if true then manage theory span values
        // else do nothing
        if(this.id.match(/^tank-span.+$/)){

            // check selected value
            // if equal to -1 then reset all theory span values
            // else set theory span values with tank values
            if($(this).val() == -1){
                var parent = $(this).parent().parent().parent();
                // find theory span input fields and reset them
                parent.find('input').filter(function() {
                    return this.id.match(/^theory.+span.+$/);
                }).each(function(idx,el){
                    $(el).val('');
                });
            }
            else{
                // get tank values
                var chValues = $(this).find('option:selected').data('values');

                var parent = $(this).parent().parent().parent();
                // find theory span input fields and set them with tank values
                parent.find('input').filter(function() {
                    return this.id.match(/^theory.+span.+$/);
                }).slice(0, chValues.length).each(function(idx,el){
                    $(el).val(chValues[idx]);
                });
            }
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
                url: '/rep_qa_tarature_selected_attachment',
                type: "post",
                dataType: "json",
                data: {
                    id: id
                }
            })
            .done(function(result) {

                // check result
                if(result.res == 'OK'){
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
    var validator = $('#form-calib').validate({ // initialize the plugin
        rules: {
            "datetime-calib" : {
                required: true
            },
            "station-calib" : {
                required: true,
                min: 0
            },
            "instrument-calib":{
                required: true,
                min: 0
            },
            "reason-calib" : {
                required: true,
                min: 0
            }
        },
        messages: {
            "datetime-calib" : {
                required: "Inserire data e ora"
            },
            "station-calib" : {
                required: "Selezionare stazione",
                min: "Selezionare stazione"
            },
            "instrument-calib":{
                required: "Selezionare strumento",
                min: "Selezionare strumento"
            },
            "reason-calib" : {
                required: "Selezionare motivazione",
                min: "Selezionare motivazione"
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

    // validate calibration input fields
    // only numeric values accepted
    $('#form-calib-obj').validate();
    $('#form-calib-obj input[type="text"]').each(function(){
        $(this).rules("add", {
            dotSeparator: true
        });
    });

    /**
     * Function called when using Dropzone submit.
     */
    myDropzone.on("sendingmultiple", function(files, xhr, formData) {

        // get serialized form
        var formMain = $("#form-calib").serializeArray();

        // add form fields to the dropzone submission object
        $.each(formMain, function(index, input){
            formData.append(input.name, input.value);
        });

        // serialize calibration values fields
        var formInstrument = $("#form-calib-obj").serializeArray();
        var notes = $("#notes-calib").val();

        var obj = {};
        // create an object key-value where the key corresponds to input element name
        $.each(formInstrument, function () {
            if (obj[this.name] !== undefined) {
                if (!obj[this.name].push) {
                    obj[this.name] = [obj[this.name]];
                }
                obj[this.name].push(this.value || '');
            }
            else {
                obj[this.name] = this.value || '';
            }
        });

        // add extra fields to the dropzone submission object
        formData.append( "obj-calib", JSON.stringify(obj) );
        formData.append( "notes-calib", notes );

    });

    /**
     * Function called at the Dropzone submit return.
     */
    myDropzone.on("successmultiple", function(files, response) {
        // get report id from form
        var id   = $("#rp-id").val();

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

            var stid = $('#stations').val();
            // refresh reports list in the first tab
            loadReports(dateFrom, dateTo, stid);
            // show first tab
            $('.customtab a[href="#report-list"]').tab('show');
            // reset form
            repCalib = null;
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
     * Submit calibration new/edit form.
     */
    $('#form-calib-close').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if (! $('#form-calib').valid() ||  ! $('#form-calib-obj').valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti o errati. Impossibile salvare report", "info");
            return false;
        };

        // Check if attachments exist:
        // if exists     -> use the dropzone submit function and add fields of the form to the submission
        // if not exist  -> normal form submit
        if (myDropzone.getQueuedFiles().length > 0) {
            $(".inner-preloader").show();
            console.log(myDropzone.getQueuedFiles().length);
            myDropzone.processQueue();
        }
        else {
            console.log("Invio normale");

            // get serialized form
            var formMain = $("#form-calib").serializeArray();
            // serialize calibration values fields
            var formInstrument = $("#form-calib-obj").serializeArray();
            var notes = $("#notes-calib").val();
            // get report id from form
            var id    = $("#report-caid").val();

            var obj = {};
            // create an object key-value where the key corresponds to input element name
            $.each(formInstrument, function () {
                if (obj[this.name] !== undefined) {
                    if (!obj[this.name].push) {
                        obj[this.name] = [obj[this.name]];
                    }
                    obj[this.name].push(this.value || '');
                }
                else {
                    obj[this.name] = this.value || '';
                }
            });

            // add extra fields to the main submission object
            formMain.push({ name: "obj-calib", value: JSON.stringify(obj) });
            formMain.push({ name: "notes-calib", value: notes });

            // different messages based on the type of action (insert or update)
            // if the id is setted then is an update
            //  otherwise is an insert
            var msg_err, msg_ok;
            if(id){
                msg_ok = 'La modifica è stata correttamente salvata';
                msg_err = 'Si è verificato un errore durante la modifica';
            }
            else{
                msg_ok  = 'Il salvataggio è avvenuto correttamente';
                msg_err = 'Si è verificato un errore durante il salvataggio';
            }

            $.ajax({
                type: 'post',
                url: '/rep_qa_tarature_put_report',
                data: formMain
            }).done(function(result) {

                // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
                if(result == true){
                    swal("Successo", msg_ok, "success");

                    var stid = $('#stations').val();
                    // refresh reports list in the first tab
                    loadReports(dateFrom, dateTo, stid);
                    // show first tab
                    $('.customtab a[href="#report-list"]').tab('show');
                    // reset form
                    repCalib = null;
                    clearFields();
                }
                else{
                    // error message
                    swal("Errore!", msg_err, "error");
                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }

            })
            .fail(function(xhr, err) {
                // take care of any errors
                swal("Errore!", msg_err, "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            });
        }
    });

    /**
     * Cancel button.
     */
    $('#cancel-calib').on('click', function(e) {
        e.preventDefault();
        // show first tab
        $('.customtab a[href="#report-list"]').tab('show');
        // reset form
        repCalib = null;
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    // TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close view report.
     */
    $('.card-body').on('click', '.close-report', function(e){
        var close = $(this).data("close");
        console.log(close);

        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#report-list"]').tab('show');

        }, 1);

        e.preventDefault();
    });

    /////////////////////////////////////////////////////////////////////
    // END TAB FUNCTIONS

    /**
     * Select option -1 and load all stations.
     */
    $("#networks, #prov-calib").trigger("change");

    // if id is defined then automatically load report detail
    if(rpid != null && rpid != ''){
        console.log('rpid from server');
        createReportDetail(rpid);
    }

    // UTILITIES
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
     * Function that returns "SI"/"NO" based on a boolean value.
     *
     * @param {boolean} info Boolean value retrived.
     *
     * @return If true, "SI";
     *         If false, "NO";
     */
    function dataMod(info){
        var res;
        if (info){
            res = "SI";
        }else{
            res = "NO";
        }
        return res;
    };

    /**
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} info Boolean value retrived.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */
    function dataModIcon(info){
        var res;
        if (info == true){
            res = '<i class="fa-solid fa-circle-check text-info"></i>';
        }
        else if(info == false){
            res = '<i class="fa-solid fa-circle-xmark text-danger"></i>';
        }
        else{
            res = '';
        }
        return res;
    };

    /**
     * Function that checks a html checkbox and sets the boolean value.
     *
     * @param {string} info HTML Checkbox's 'checked' value.
     *
     * @return If 'on', return TRUE, otherwise FALSE
     */
    function checkboxChecked(info){
        // console.log('sto checkando: '+info);
        var res;
        if (info == 'on'){
            res = true;
        }else{
            res = false;
        }
        return res;
    };

    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field Field provided to format.
     *
     * @return If null, the string '--';
     *         If not, the string provided before.
     */
    function checkIfExist(field) {
        if(!field)
            return '--';
        else
            return field;
    };

    /**
     * Reset multiple calibration form.
     */
    function resetCalibObject(){
        $( "#row-multi" ).hide();
        $( "#row-multi" ).attr( "data-id", "" );

        setSwitchery(mySwitchMulti, false);
        $('.hide-fields-instrument').hide();
    };

    /**
     * Function that clears ad resets all calibration fields of the instrument
     */
    function clearFieldsInstruments(){

        console.log('clearFieldsInstruments');
        $( "#form-calib-obj select" ).val(-1);
        $( "#form-calib-obj input[type=text]" ).val('');
        $( "#form-calib-obj input[type=checkbox]" ).prop("checked", false);
        $('#form-calib-obj').validate().resetForm();

        return;
    };

    /**
     * Function that clears ad resets all form's fields.
     */
    function clearFields(){

        console.log('clearFields');
        // Reset multiple calibration fields
        resetCalibObject();
        // reset insruments calibration fields
        clearFieldsInstruments();

        // reset all select elements
        $('#form-calib select').val(-1);
        // set default reason value
        $('#reason-calib').val(1);

        $('#report-caid').val('');
        // manage select2
        $('#station-calib').trigger('change');
        // take care of bootstrap date picker
        $('#datetime-calib').val('');
        $('#datetime-calib').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        $('#form-calib-close textarea' ).val('');

        // remove all attachments
        myDropzone.removeAllFiles(true);
        // reset div for attachments
        $('#report-del-attach').hide();
        $('#att-container').empty();

        // reset form texts
        $('#new .box-title').text('Inserisci nuova TARATURA');
        $('#inner-new-report').text('Nuovo');
        $('#save-calib').html(' <i class="ti-save"></i> Inserisci report');

        // reset form validation
        $('#form-calib').validate().resetForm();
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} stid Station ID, if provided.
     * @param {integer} instrid Instrument ID, if provided.
     */
    function loadStations(net, prid, dest, stid, instrid){

        // console.log('loadStations: '+prid);

        var jqxhr = $.ajax({
            url: '/rep_qa_tarature_get_stations',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid
            },
        })
        .done(function(result) {

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#'+dest).empty();
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
                if(dest == 'stations' && prid == -1){
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
                $('#'+dest).append('<option value="-1">Seleziona stazione...</option>');
                $('#'+dest).append(opts);
                $('#'+dest).append('</optgroup>');

                if(stid)
                    $('#'+dest).val(stid).trigger('change', instrid);
                else
                    $('#'+dest).val(-1).trigger('change');

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
     * Function that retrieves the instruments of a given station.
     *
     * @param {integer} stid Station ID.
     * @param {date}    dt Date of allocation.
     * @param {integer} instrid Instrument ID, if provided.
     */
    function loadInstruments(stid, dt, instrid){

        // load instruments via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_tarature_get_instruments',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                dt  : moment(dt, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
            },
        })
        .done(function(result) {

            // check if result is 'OK'
            if(result.res == 'OK'){
                // reset instruments select
                $('#instrument-calib').empty();
                var instruments = result.instruments;

                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each instrument, build a html option to be added to the select
                $.each(instruments, function(index, instrument){
                    var instrName = instrument.instrument_type_fullname;

                    if(instrument.instrument_name != '')
                        instrName += ' - '+instrument.instrument_name;

                    if(instrument.instrument_arpa_id != '')
                        instrName = instrName+' ['+instrument.instrument_arpa_id+']';

                    opts += '<option value="'+ instrument.instr_id+'" data-ctid="'+ instrument.category_id+'">'+instrName+'</option>';
                });
                // append options
                $('#instrument-calib').append('<option value="-1">Seleziona strumento...</option>');
                $('#instrument-calib').append(opts);

                if(instrid)
                    $('#instrument-calib').val(instrid).trigger('change');
                else
                    $('#instrument-calib').val(-1).trigger('change');
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
     * Function that retrieves the metadata of a given station.
     *
     * @param {integer} stid Station ID.
     * @param {integer} catId Instrument category ID.
     * @param {date}    dt Calibration date.
     * @param {object} instrObj All form fields of the selected calibration, if provided.
     */
    function loadMetadata(stid, catId, dt, instrObj){

        // load metadata via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_tarature_get_metadata',
            type: "post",
            dataType: "json",
            data: {
                stid: stid,
                cat: catId,
                dt: moment(dt, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is ok
            if(result.res == 'OK'){

                // fill form selects with retrieved metadata
                $('.tanks').empty();
                var cylinders = result.cylinders;

                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each cylinder, build a html option to be added to the select
                $.each(cylinders, function(index, el){
                    var chValues = el.cylinder_ch_values.join(',');

                    var expiryTxt = '';
                    if( moment().isSameOrAfter(el.cylinder_expiry_date) ){
                        expiryTxt = '<u> scad. '+ moment(el.cylinder_expiry_date).format('DD/MM/YYYY') + '</u>';
                    }

                    opts += '<option value="'+ el.cy_id+'" data-values="['+chValues+']">'+el.cylinder_fullname+' { '+chValues+' }'+expiryTxt+'</option>';
                });
                // append options
                $('.tanks').append('<option value="-1">Seleziona bombola...</option>');
                $('.tanks').append(opts);

                $('.methods').empty();
                var methods = result.methods;
                var opts2 = '';
                // loop through all elements
                // for each method, build a html option to be added to th
                $.each(methods, function(index, method){

                    opts2 += '<option value="'+ method.method_id+'" >'+method.method_name+'</option>';
                });
                $('.methods').append('<option value="-1">Seleziona metodo...</option>');
                $('.methods').append(opts2);

                // if object is defined then it's an edit action
                // fill input values end hide preloader at the end of the process
                if(instrObj){
                    editInstrument(catId, instrObj);
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei metadata", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei metadata", "error");
        });
    };

    /**
     * Function that retrieves the reports of a given period.
     *
     * @param {date}    dateFrom Start period datetime.
     * @param {date}    dateTo End period datetime.
     * @param {integer} stid Station ID, if provided.
     */
    function loadReports(dateFrom, dateTo, stid){
        var net   = $( "#networks" ).val();
        var prid  = $( "#provinces" ).val();
        var catid = $( "#str-categories" ).val();

        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
        url: '/rep_qa_tarature_get_reports',
        type: "post",
        dataType: "json",
        data: {
            from    : dateFrom,
            to      : dateTo,
            net     : net,
            prid    : prid,
            stid    : stid,
            catid   : catid
        },
        })
        .done(function(result) {

            var reports = result.reports;
            // check if at least one element exists
            if( reports.length > 0 ){

                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each report, build a html row to be added to the datable
                $.each(reports, function(index, value) {

                    html +='<tr data-id="'+value.calib_id+'">';
                    html +='    <td class="bobo-nowrap icons-little">';
                    html +='        <a href="javascript:void(0)" class="show-report" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';

                    // if user has update grant
                    if(value.user_has_grants && update_grant){
                        html +='        <a href="javascript:void(0)" class="edit-report" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                    }
                    html +='        <br>';
                    html +='        <a href="javascript:void(0)" class="pdf-report" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';

                    // if user has delete grant
                    if(value.user_has_grants && delete_grant){
                        html +='        <a href="javascript:void(0)" class="delete-report" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    html +='    </td>';
                    html +='    <td>'+getFormattedDateDT(value.calib_fulldate, 'basic_timeStartMin')+'</td>';
                    html +='    <td class="bobo-nowrap operators">';
                    html +='        <img src="'+value.user_avatar_thumb+'">';
                    html +='        '+value.user_fullname;
                    html +='    </td>';
                    html +='    <td>'+value.network_name+'</td>';
                    html +='    <td>'+value.station_name+'</td>';
                    html +='    <td>'+value.instr_fullname+ '</td>';
                    html +='    <td>'+dataModIcon(value.zero_mod)+'</td>';
                    html +='    <td>'+value.zero_found+'</td>';
                    html +='    <td>'+dataModIcon(value.span_mod)+ '</td>';
                    html +='    <td>'+value.span_found+'</td>';
                    html +='    <td>'+value.calib_note+'</td>';
                    html +='    <td></td>';
                    html +='</tr>';

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
                // redraw it
                table.draw();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei report tarature", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // redraw it
            table.draw();
        });

        return;
    }

    /**
     * Function that shows, given the instrument category ID, the relative html form.
     *
     * @param {integer} id instrument category ID.
     */
    function showInstrumentDiv( id ) {

        // Categorie
        // 1 = 'Analizzatore SO2'
        // 2 = 'Analizzatore NOx'
        // 3 = 'Analizzatore CO'
        // 4 = 'Analizzatore O3'
        // 5 = 'Analizzatore BTX'
        // 6 = 'Analizzatore IPA'
        // 7 = 'Analizzatore CH4'
        // 25 = 'Analizzatore di BIOGAS'
        // 26 = 'Sonda multiparametrica'

        // take care of div visibility
        switch ( parseInt(id) ) {
            case 1:
                $( "#row-multi" ).show();
                $( "#row-multi" ).attr( "data-id", "so2" );
                $("#so2").show();
                break;
            case 2:
                $("#row-multi").show();
                $("#noxnono2").show();
                $( "#row-multi" ).attr( "data-id", "noxnono2" );
                break;
            case 3:
                $("#row-multi").show();
                $("#co").show();
                $( "#row-multi" ).attr( "data-id", "co" );
                break;
            case 4:
                $("#row-multi").show();
                $("#o3").show();
                $( "#row-multi" ).attr( "data-id", "o3" );
                break;
            case 5:
                $("#row-multi").show();
                $("#btx").show();
                $( "#row-multi" ).attr( "data-id", "btx" );
                break;
            case 7:
                $("#ch4").show();
                break;
            case 8:  // 'Campionatore polveri'
            case 9:  // 'Campionatore polveri alto volume'
            case 10: // 'Campionatore polveri basso volume'
            case 11: // 'Campionatore polveri con PUF'
            case 12: // 'Campionatore polveri beta'
            case 13: // 'Campionatore polveri microbilancia'
                $("#sampler").show();
                break;
            case 14: //'Campionatore polveri ottico'
            case 15: //'Campionatore black carbon'
            case 18: //'Spettrometro aerosol'
                $("#aerosol").show();
                break;
            case 25:
                $("#biogas").show();
                break;
            case 26:
                $("#probe").show();
                break;
        }
    };

    /**
     * Create the report detail.
     *
     * @param {integer} rpid Report ID.
     */
    function createReportDetail(rpid){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get report data via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_tarature_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {
            // check result
            // if OK then build html
            if(result.res == 'OK'){
                var report = result.report;
                var instrObj = JSON.parse(report.calib_values);

                // add link for the new tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#rep'+rpid+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+report.calib_fulldate_formatted+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-report" data-close="rep'+rpid+'"></i></a></li>';
                $('.nav').append(html);

                // call function in order to create html contents
                html = createHtmlReportDetail(rpid, result, instrObj);

                // append new html to main body
                $('.tab-content').append(html);
                // refresh gallery plugin
                refreshGalleryBig();

                // show detail tab
                $('.customtab a[href="#rep'+rpid+'"]').tab('show');
            }
            else{
                // error messare
                swal("Errore!", "Errore durante il recupero dettaglio del report", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del report", "error");
        });
    }

    /**
     * Create html detail of the report.
     *
     * @param {integer} rpid Report ID.
     * @param {json}    result The report retrived from the database.
     * @param {object}  instrObj Calibration values retrived from the database.
     */
    function createHtmlReportDetail(rpid, result, instrObj){

        var report = result.report;
        var tankZero = result.tank_zero;
        var tankSpan = result.tank_span;
        var methodZero = result.method_zero;
        var methodSpan = result.method_span;
        var calibrator = result.calibrator;

        // calib_fulldate: "2021-01-29 12:14:00"
        // calib_fulldate_formatted: "29/01/2021 alle 12:14"
        // calib_id: 1
        // calib_multipoint: 0
        // calib_note: "TEST TEST TEST"
        // calib_re_id: 6
        // calib_reason: "Altro"
        // category_id: 2
        // category_name: "Analizzatore NOx"
        // instr_arpa_id: "OPAS00011"
        // instr_id: 4
        // instr_name: "Test1_Plouves"
        // instr_serial_num: "1200011"
        // instr_type_fullname: "Teledyne API 200EU"
        // instr_unit
        // instr_type_id: 10
        // station_id: 1000
        // station_name: "Aosta - Plouves"
        // us_id: 4
        // user_fullname: "Hillary Martello"

        // dynamically build tab content
        var html  ='<div class="tab-pane p-20" id="rep'+rpid+'" role="tabpanel">';
        html +='    <div class="form-body panel-report-view panel-view-mobile">';
        html +='        <!-- parte iniziale -->';
        // html +='        <div class="alert alert-danger alert-rounded"> <i class="icon-flag"></i> Parte iniziale = per tutti';
        // html +='            <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
        // html +='        </div>';
        html +='        <h4 class="box-title">Report del <strong>'+report.calib_fulldate_formatted+'</strong></h4>';
        html +='        <hr class="m-t-0 m-b-20">';
        html +='        <div class="form-group row">';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Operatore</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.user_fullname+'</div>';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Provincia</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.province_name+'</div>';
        html +='        </div>';
        html +='        <div class="form-group row">';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Stazione</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.station_name+'</div>';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Motivo</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.calib_reason+'</div>';
        html +='        </div>';
        html +='        <h4 class="box-title p-t-10">Strumento <strong>'+report.instr_fullname+'</strong> (cat. <strong>'+report.category_name+'</strong>)</h4>';
        html +='        <hr class="m-t-0 m-b-20">';
        html +='        <div class="form-group row">';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Arpa ID</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.instr_arpa_id+'</div>';
        html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Serial number</label>';
        html +='            <div class="col-md-4 col-8 view-param">'+report.instr_serial_num+'</div>';
        html +='        </div>';

        // calib-span-o3: "-1"
        // find-ben-zero-btx: ""
        // find-tol-zero-btx: ""
        // find-xil-zero-btx: ""
        // find-zero-ch4: ""
        // find-zero-co: ""
        // find-zero-o3: ""
        // find-zero-so2: ""
        // l1-read-no-span-noxnono2: ""
        // l1-read-nox-span-noxnono2: ""
        // l1-read-span-btx: ""
        // l1-read-span-co: ""
        // l1-read-span-o3: ""
        // l1-read-span-so2: ""
        // l1-theory-no-span-noxnono2: ""
        // l1-theory-nox-span-noxnono2: ""
        // l1-theory-span-btx: ""
        // l1-theory-span-co: ""
        // l1-theory-span-o3: ""
        // l1-theory-span-so2: ""
        // l2-read-no-span-noxnono2: ""
        // l2-read-nox-span-noxnono2: ""
        // l2-read-span-btx: ""
        // l2-read-span-co: ""
        // l2-read-span-o3: ""
        // l2-read-span-so2: ""
        // l2-theory-no-span-noxnono2: ""
        // l2-theory-nox-span-noxnono2: ""
        // l2-theory-span-btx: ""
        // l2-theory-span-co: ""
        // l2-theory-span-o3: ""
        // l2-theory-span-so2: ""
        // l3-read-no-span-noxnono2: ""
        // l3-read-nox-span-noxnono2: ""
        // l3-read-span-btx: ""
        // l3-read-span-co: ""
        // l3-read-span-o3: ""
        // l3-read-span-so2: ""
        // l3-theory-no-span-noxnono2: ""
        // l3-theory-nox-span-noxnono2: ""
        // l3-theory-span-btx: ""
        // l3-theory-span-co: ""
        // l3-theory-span-o3: ""
        // l3-theory-span-so2: ""
        // l4-read-no-span-noxnono2: ""
        // l4-read-nox-span-noxnono2: ""
        // l4-read-span-btx: ""
        // l4-read-span-co: ""
        // l4-read-span-o3: ""
        // l4-read-span-so2: ""
        // l4-theory-no-span-noxnono2: ""
        // l4-theory-nox-span-noxnono2: ""
        // l4-theory-span-btx: ""
        // l4-theory-span-co: ""
        // l4-theory-span-o3: ""
        // l4-theory-span-so2: ""
        // l5-read-span-btx: ""
        // l5-read-span-co: ""
        // l5-read-span-o3: ""
        // l5-read-span-so2: ""
        // l5-theory-span-btx: ""
        // l5-theory-span-co: ""
        // l5-theory-span-o3: ""
        // l5-theory-span-so2: ""
        // method-span-aerosol: "-1"
        // method-span-btx: "-1"
        // method-span-ch4: "-1"
        // method-span-co: "-1"
        // method-span-noxnono2: "6"
        // method-span-o3: "-1"
        // method-span-so2: "-1"
        // method-zero-btx: "-1"
        // method-zero-ch4: "-1"
        // method-zero-co: "-1"
        // method-zero-noxnono2: "0"
        // method-zero-o3: "-1"
        // method-zero-so2: "-1"
        // mod-zero-noxnono2: "on"
        // no2-zero-noxnono2: "-0.2"
        // no-zero-noxnono2: "0.5"
        // nox-zero-noxnono2: "0.3"
        // press-flow-sampler: ""
        // press-instr-flow-sampler: ""
        // read-ben-span-btx: ""
        // read-flow-sampler: ""
        // read-no2-span-noxnono2: ""
        // read-no-span-noxnono2: "220"
        // read-nox-span-noxnono2: "228"
        // read-span-aerosol: ""
        // read-span-ch4: ""
        // read-span-co: ""
        // read-span-o3: ""
        // read-span-so2: ""
        // read-tol-span-btx: ""
        // read-xil-span-btx: ""
        // reference-flow-sampler: ""
        // tank-span-aerosol: "-1"
        // tank-span-btx: "-1"
        // tank-span-ch4: "-1"
        // tank-span-co: "-1"
        // tank-span-noxnono2: "1"
        // tank-span-so2: "-1"
        // tank-zero-btx: "-1"
        // tank-zero-so2: "-1"
        // temp-flow-sampler: ""
        // temp-instr-flow-sampler: ""
        // theory-ben-span-btx: ""
        // theory-no2-span-noxnono2: ""
        // theory-no-span-noxnono2: "440"
        // theory-nox-span-noxnono2: "441.6"
        // theory-span-aerosol: ""
        // theory-span-ch4: ""
        // theory-span-co: ""
        // theory-span-o3: ""
        // theory-span-so2: ""
        // theory-tol-span-btx: ""
        // theory-xil-span-btx: ""

        var cat =  report.category_id;
        var multi = report.calib_multipoint;

        // Categorie
        // 1 = 'Analizzatore SO2'
        // 2 = 'Analizzatore NOx'
        // 3 = 'Analizzatore CO'
        // 4 = 'Analizzatore O3'
        // 5 = 'Analizzatore BTX'
        // 6 = 'Analizzatore IPA'
        // 7 = 'Analizzatore CH4'
        // 25 = 'Analizzatore di BIOGAS'

        var tank, tankName, tankArpaID;
        // take care of instrument category
        // different fieldsbased on instrument typology
        switch ( parseInt(cat) ) {
        // switch ( 1120 ) {
            case 1:
                // find-zero-so2: ""
                // l1-read-span-so2: ""
                // l1-theory-span-so2: ""
                // l2-read-span-so2: ""
                // l2-theory-span-so2: ""
                // l3-read-span-so2: ""
                // l3-theory-span-so2: ""
                // l4-read-span-so2: ""
                // l4-theory-span-so2: ""
                // l5-read-span-so2: ""
                // l5-theory-span-so2: ""
                // method-span-so2: "-1"
                // method-zero-so2: "-1"
                // read-span-so2: ""
                // tank-span-so2: "-1"
                // tank-zero-so2: "-1"
                // theory-span-so2: ""
                html +='        <!-- SO2 -->';
                html +='        <div class="view-so2">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> SO2';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero trovato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['find-zero-so2'])+' '+report.instr_unit+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-zero-so2'])+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';

                tankName = tankZero.cylinder_fullname;
                tankArpaID = tankZero.cylinder_arpa_id;

                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-so2'])+'</div>';
                html +='            </div>';
                if(multi == 0){
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                }else{
                    html +='            <div class="view-multi">';
                    html +='                <h5 class="box-title p-t-10">Taratura multipla</h5>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L1</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L2</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L3</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L4</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L5</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-read-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-theory-span-so2'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='            </div>';
                }
                html +='        </div>';
                break;
            case 2:
                html +='        <!-- NOx NO NO2 -->';
                html +='        <div class="view-noxnono2">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> NOx NO NO2';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-zero-noxnono2'])+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';
                html +='            <hr class="m-t-0 m-b-10">';
                html +='            <div class="row view-label disappear-med">';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">NOx</label>';
                html +='                <label for="" class="control-label col-md-4 col-8 col-form-label">NO</label>';
                html +='                <label for="" class="control-label col-md-3 col-form-label">NO2</label>';
                html +='            </div>';
                html +='            <div class="mobile-view m-b-5"><strong>Zero trovato</strong></div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Zero trovato</label>';
                html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['nox-zero-noxnono2'])+' '+report.instr_unit+'</div>';
                html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['no-zero-noxnono2'])+' '+report.instr_unit+'</div>';
                html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NO2:&nbsp;</strong>'+checkIfExist(instrObj['no2-zero-noxnono2'])+' '+report.instr_unit+'</div>';
                html +='            </div>';
                html +='            <div class="mobile-view m-b-5"></div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-noxnono2'])+'</div>';
                html +='            </div>';
                html +='            <hr class="m-t-0 m-b-10">';
                if(multi == 0){
                    html +='            <div class="row view-label disappear-med">';
                    html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">NOx</label>';
                    html +='                <label for="" class="control-label col-md-4 col-form-label">NO</label>';
                    html +='                <label for="" class="control-label col-md-3 col-form-label">NO2</label>';
                    html +='            </div>';
                    html +='            <div class="mobile-view m-b-5 m-t-15"><strong>Span letto</strong></div>';
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['read-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">NO:&nbsp;</strong> '+checkIfExist(instrObj['read-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NO2:&nbsp;</strong>'+checkIfExist(instrObj['read-no2-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                    html +='            <div class="mobile-view m-b-5 m-t-15"><strong>Span teorico</strong></div>';
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['theory-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">NO:&nbsp;</strong> '+checkIfExist(instrObj['theory-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">NO2:&nbsp;</strong>'+checkIfExist(instrObj['theory-no2-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                }else{
                    html +='            <div class="view-multi">';
                    html +='                <h5 class="box-title p-t-10">Taratura multipla</h5>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L1</div>';
                    html +='                    <div class="multi-label-values">';
                    html +='                        <div class="row view-label disappear-med">';
                    html +='                            <label for="" class="control-label col-5 offset-2 col-form-label">NOx</label>';
                    html +='                            <label for="" class="control-label col-5 col-form-label">NO</label>';
                    html +='                        </div>';
                    html +='                        <div class="mobile-view m-b-5"><strong>Span letto</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l1-read-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l1-read-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                        <div class="mobile-view m-t-10 m-b-5"><strong>Span teorico</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l1-theory-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l1-theory-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                    </div>';
                    html +='                    <div class="mobile-view m-b-5"></div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L2</div>';
                    html +='                    <div class="multi-label-values">';
                    html +='                        <div class="mobile-view m-b-5"><strong>Span letto</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l2-read-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l2-read-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                        <div class="mobile-view m-t-10 m-b-5"><strong>Span teorico</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l2-theory-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l2-theory-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                    </div>';
                    html +='                    <div class="mobile-view m-b-5"></div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L3</div>';
                    html +='                    <div class="multi-label-values">';
                    html +='                        <div class="mobile-view m-b-5"><strong>Span letto</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l3-read-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l3-read-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                        <div class="mobile-view m-t-10 m-b-5"><strong>Span teorico</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l3-theory-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l3-theory-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                    </div>';
                    html +='                    <div class="mobile-view m-b-5"></div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L4</div>';
                    html +='                    <div class="multi-label-values">';
                    html +='                        <div class="mobile-view m-b-5"><strong>Span letto</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l4-read-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l4-read-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                        <div class="mobile-view m-t-10 m-b-5"><strong>Span teorico</strong></div>';
                    html +='                        <div class="form-group row">';
                    html +='                            <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NOX:&nbsp;</strong>'+checkIfExist(instrObj['l4-theory-nox-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                            <div class="col-5 view-param"><strong class="mobile-view">NO:&nbsp;</strong>'+checkIfExist(instrObj['l4-theory-no-span-noxnono2'])+' '+report.instr_unit+'</div>';
                    html +='                        </div>';
                    html +='                    </div>';
                    html +='                    <div class="mobile-view m-b-5"></div>';
                    html +='                </div>';
                    html +='            </div>';
                }
                html +='        </div>';
                break;
            case 3:
                html +='        <!-- CO -->';
                html +='        <div class="view-co">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> CO';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero trovato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['find-zero-co'])+' '+report.instr_unit+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-zero-co'])+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-co'])+'</div>';
                html +='            </div>';
                if(multi == 0){
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                }else{
                    html +='            <div class="view-multi">';
                    html +='                <h5 class="box-title p-t-10">Taratura multipla</h5>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L1</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L2</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L3</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L4</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L5</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-read-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-theory-span-co'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='            </div>';
                }
                html +='        </div>';
                break;
            case 4:
                html +='        <!-- O3 -->';
                html +='        <div class="view-o3">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> O3';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero trovato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['find-zero-o3'])+' '+report.instr_unit+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-zero-o3'])+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';

                var calibratorName = 'Nessun calibratore';
                if(instrObj['calib-span-o3'] != -1){
                    calibratorName = calibrator.instr_fullname + ' ['+calibrator.instrument_arpa_id+']';
                }
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Calibratore</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+calibratorName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-o3'])+'</div>';
                html +='            </div>';
                if(multi == 0){
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                }else{
                    html +='            <div class="view-multi">';
                    html +='                <h5 class="box-title p-t-10">Taratura multipla</h5>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> 100</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l1-theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> 200</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l2-theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> 300</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l3-theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> 400</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l4-theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> 500</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-read-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['l5-theory-span-o3'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='            </div>';
                }
                html +='        </div>';
                break;
            case 5:
                // find-ben-zero-btx: ""
                // find-tol-zero-btx: ""
                // find-xil-zero-btx: ""
                // l1-read-span-btx: ""
                // l1-theory-span-btx: ""
                // l2-read-span-btx: ""
                // l2-theory-span-btx: ""
                // l3-read-span-btx: ""
                // l3-theory-span-btx: ""
                // l4-read-span-btx: ""
                // l4-theory-span-btx: ""
                // l5-read-span-btx: ""
                // l5-theory-span-btx: ""
                // method-span-btx: "-1"
                // method-zero-btx: "-1"
                // read-ben-span-btx: ""
                // read-tol-span-btx: ""
                // read-xil-span-btx: ""
                // tank-span-btx: "-1"
                // tank-zero-btx: "-1"
                // theory-ben-span-btx: ""
                // theory-tol-span-btx: ""
                // theory-xil-span-btx: ""

                html +='        <!-- BTX  -->';
                html +='        <div class="view-btx">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> BTX';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="row view-label disappear-med">';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">Benzene</label>';
                html +='                <label for="" class="control-label col-md-4 col-form-label">Toluene</label>';
                html +='                <label for="" class="control-label col-md-3 col-form-label">Xilene</label>';
                html +='            </div>';
                html +='            <div class="mobile-view m-b-5"><strong>Zero trovato</strong></div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-12 col-form-label disappear-med">Zero trovato</label>';
                html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Benzene:&nbsp;</strong>'+checkIfExist(instrObj['find-ben-zero-btx'])+' '+report.instr_unit+'</div>';
                html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">Toluene:&nbsp;</strong>'+checkIfExist(instrObj['find-tol-zero-btx'])+' '+report.instr_unit+'</div>';
                html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Xilene:&nbsp;</strong>'+checkIfExist(instrObj['find-xil-zero-btx'])+' '+report.instr_unit+'</div>';
                html +='            </div>';
                html +='            <div class="mobile-view m-b-5"></div>';
                html +='            <hr class="m-t-0 m-b-10">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-10 col-8 view-param">'+dataMod(instrObj['mod-zero-btx'])+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';

                tankName = tankZero.cylinder_fullname;
                tankArpaID = tankZero.cylinder_arpa_id;

                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-btx'])+'</div>';
                html +='            </div>';
                if(multi == 0){
                    html +='            <hr class="m-t-0 m-b-10">';
                    html +='            <div class="row view-label disappear-med">';
                    html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">Benzene</label>';
                    html +='                <label for="" class="control-label col-md-4 col-8 col-form-label">Toluene</label>';
                    html +='                <label for="" class="control-label col-md-3 col-form-label">Xilene</label>';
                    html +='            </div>';
                    html +='            <div class="mobile-view m-b-5"><strong>Span letto</strong></div>';
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span letto</label>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Benzene:&nbsp;</strong>'+checkIfExist(instrObj['read-ben-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">Toluene:&nbsp;</strong>'+checkIfExist(instrObj['read-tol-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Xilene:&nbsp;</strong>'+checkIfExist(instrObj['read-xil-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                    html +='            <div class="mobile-view m-b-5 m-t-15"><strong>Span teorico</strong></div>';
                    html +='            <div class="form-group row">';
                    html +='                <label for="" class="control-label col-md-2 col-4 col-form-label disappear-med">Span teorico</label>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Benzene:&nbsp;</strong>'+checkIfExist(instrObj['theory-ben-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-4 col-4 view-param"><strong class="mobile-view">Toluene:&nbsp;</strong>'+checkIfExist(instrObj['theory-tol-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                <div class="col-md-3 col-4 view-param"><strong class="mobile-view">Xilene:&nbsp;</strong>'+checkIfExist(instrObj['theory-xil-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='            </div>';
                    html +='            <div class="mobile-view m-b-5"></div>';
                }else{
                    html +='            <div class="view-multi">';
                    html +='                <h5 class="box-title p-t-10">Taratura multipla</h5>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L1</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l1-read-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l1-theory-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L2</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l2-read-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l2-theory-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L3</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l3-read-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l3-theory-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label multi-bordered">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L4</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l4-read-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l4-theory-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='                <div class="row-multi-label">';
                    html +='                    <div class="multi-label-tag"><i class="icon-arrow-right-circle"></i> L5</div>';
                    html +='                    <div class="form-group row multi-label-values">';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span letto</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l5-read-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                        <label for="" class="control-label col-md-2 col-7 col-form-label">Span teorico</label>';
                    html +='                        <div class="col-md-4 col-5 view-param">'+checkIfExist(instrObj['l5-theory-span-btx'])+' '+report.instr_unit+'</div>';
                    html +='                    </div>';
                    html +='                </div>';
                    html +='            </div>';
                }
                html +='        </div>';
                break;
            case 7:
                html +='        <!-- CH4 -->';
                html +='        <div class="view-ch4">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> CH4';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Zero</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="row view-label">';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">CH4</label>';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">TNMHC</label>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero trovato</label>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['find-zero-ch4']) + ' '+report.instr_unit+'</div>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['find-zero-tnmhc']) + ' '+report.instr_unit+'</div>';
                html +='            </div>';
                html +='            <hr class="m-t-0 m-b-10">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-zero-ch4'])+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodZero+'</div>';
                html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Span</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankArpaID+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-span-ch4'])+'</div>';
                html +='            </div>';
                html +='            <hr class="m-t-0 m-b-10">';
                html +='            <div class="row view-label">';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">CH4</label>';
                html +='                <label for="" class="control-label col-md-3 offset-2 col-form-label">TNMHC</label>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['read-span-ch4']) + ' '+report.instr_unit+'</div>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['read-span-tnmhc']) + ' '+report.instr_unit+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['theory-span-ch4']) + ' '+report.instr_unit+'</div>';
                html +='                <div class="col-5 view-param">' + checkIfExist(instrObj['theory-span-tnmhc']) + ' '+report.instr_unit+'</div>';
                html +='            </div>';
                html +='        </div>';
                break;
            case 8:  // 'Campionatore polveri'
            case 9:  // 'Campionatore polveri alto volume'
            case 10: // 'Campionatore polveri basso volume'
            case 11: // 'Campionatore polveri con PUF'
            case 12: // 'Campionatore polveri beta'
            case 13: // 'Campionatore polveri microbilancia'
                html +='        <!-- Campionatori, SM200 - Skypost - Teom - MCZ -->';
                html +='        <div class="view-sampler">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> Campionatori, SM200 - Skypost - Teom - MCZ';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html +='            <h4 class="box-title p-t-10">Flussi</h4>';
                html +='            <hr class="m-t-0 m-b-20">';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso letto</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['read-flow-sampler'])+' l/min</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso riferimento</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['reference-flow-sampler'])+' l/min</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Temp. Strumento</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['temp-instr-flow-sampler'])+' °C</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Press. Strumento</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['press-instr-flow-sampler'])+' hPa</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Temp. Ambiente</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['temp-flow-sampler'])+' °C</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Pressione</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['press-flow-sampler'])+' hPa</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso Calibrato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+dataMod(instrObj['mod-flow-sampler'])+'</div>';
                html +='            </div>';
                html +='        </div>';
                break;
            case 14: // 'Campionatore polveri ottico'
            case 15: // 'Campionatore black carbon'
            case 18: // 'Spettrometro aerosol'
                html +='        <!-- Aerosol -->';
                html +='        <div class="view-aerosol">';
                html += '           <h4 class="box-title p-t-10">Canale</h4>';
                html += '           <hr class="m-t-0 m-b-20">';

                html +='            <div class="form-group row">';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Riferimento</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+tankName+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+methodSpan+'</div>';
                html +='            </div>';
                html +='            <div class="form-group row">';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Canale misurato</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['read-span-aerosol'])+' '+report.instr_unit+'</div>';
                html +='                <label for="" class="control-label col-md-2 col-4 col-form-label">Canale riferimento</label>';
                html +='                <div class="col-md-4 col-8 view-param">'+checkIfExist(instrObj['theory-span-aerosol'])+' '+report.instr_unit+'</div>';
                html +='            </div>';
                html += '           <div class="form-group row">';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Canale calibrato</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + dataMod(instrObj['mod-span-aerosol']) + '</div>';
                html += '           </div>';
                html += '           <h4 class="box-title p-t-10">Flussi</h4>';
                html += '           <hr class="m-t-0 m-b-20">';
                html += '           <div class="form-group row">';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso letto</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['read-flow-aerosol']) + ' l/min</div>';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso riferimento</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['reference-flow-aerosol']) + ' l/min</div>';
                html += '           </div>';
                html += '           <div class="form-group row">';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Temp. Strumento</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['temp-instr-flow-aerosol']) + ' °C</div>';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Press. Strumento</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['press-instr-flow-aerosol']) + ' hPa</div>';
                html += '           </div>';
                html += '           <div class="form-group row">';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Temp. Ambiente</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['temp-flow-aerosol']) + ' °C</div>';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Pressione</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['press-flow-aerosol']) + ' hPa</div>';
                html += '           </div>';
                html += '           <div class="form-group row">';
                html += '               <label for="" class="control-label col-md-2 col-4 col-form-label">Flusso calibrato</label>';
                html += '               <div class="col-md-4 col-8 view-param">' + dataMod(instrObj['mod-flow-aerosol']) + '</div>';
                html += '           </div>';
                html +='        </div>';
                break;
            case 25: // 'Analizzatore di biogas'
                // BIOGAS
                html += '        <!-- BIOGAS -->';
                html += '        <div class="view-biogas">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> BIOGAS';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html += '            <h4 class="box-title p-t-10">Zero</h4>';
                html += '            <hr class="m-t-0 m-b-20">';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero modificato</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + dataMod(instrObj['mod-zero-biogas']) + '</div>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + methodZero + '</div>';
                html += '            </div>';
                html += '            <hr class="m-t-0 m-b-10">';
                html += '            <div class="row view-label">';
                html += '                <label for="" class="control-label col-md-3 offset-2 col-form-label">O2</label>';
                html += '                <label for="" class="control-label col-md-4 col-8 col-form-label">CH4</label>';
                html += '                <label for="" class="control-label col-md-3 col-form-label">CO2</label>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Zero trovato</label>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['o2-zero-biogas']) + ' %</div>';
                html += '                <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['ch4-zero-biogas']) + ' '+report.instr_unit+'</div>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['co2-zero-biogas']) + ' %</div>';
                html += '            </div>';
                html += '            <h4 class="box-title p-t-10">Span</h4>';
                html += '            <hr class="m-t-0 m-b-20">';
                html += '            <div class="form-group row">';

                tankName = tankSpan.cylinder_fullname;
                tankArpaID = tankSpan.cylinder_arpa_id;

                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Bombola</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + tankName + '</div>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + methodSpan + '</div>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + tankArpaID + '</div>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Span modificato</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + dataMod(instrObj['mod-span-biogas']) + '</div>';
                html += '            </div>';
                html += '            <hr class="m-t-0 m-b-10">';
                html += '            <div class="row view-label">';
                html += '                <label for="" class="control-label col-md-3 offset-2 col-form-label">O2</label>';
                html += '                <label for="" class="control-label col-md-4 col-8 col-form-label">CH4</label>';
                html += '                <label for="" class="control-label col-md-3 col-form-label">CO2</label>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Span letto</label>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['read-o2-span-biogas']) + ' %</div>';
                html += '                <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['read-ch4-span-biogas']) + ' '+report.instr_unit+'</div>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['read-co2-span-biogas']) + ' %</div>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Span teorico</label>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['theory-o2-span-biogas']) + ' %</div>';
                html += '                <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['theory-ch4-span-biogas']) + ' '+report.instr_unit+'</div>';
                html += '                <div class="col-md-3 view-param">' + checkIfExist(instrObj['theory-co2-span-biogas']) + ' %</div>';
                html += '            </div>';
                html += '        </div>';
                break;
            case 26: // 'Sonda multiparametrica'
                // Sonde
                html += '        <!-- SONDE -->';
                html += '        <div class="view-probe">';
                // html +='            <div class="alert alert-info alert-rounded m-t-20"> <i class="icon-magic-wand"></i> SONDE';
                // html +='                <button type="button" class="close" data-dismiss="alert" aria-label="Close"> <span aria-hidden="true">×</span> </button>';
                // html +='            </div>';
                html += '            <h4 class="box-title p-t-10">Sonde</h4>';
                html += '            <hr class="m-t-0 m-b-20">';
                html += '            <div class="form-group row">';

                // tankName = tankSpan.cylinder_fullname; // solutionName
                // tankArpaID = tankSpan.cylinder_arpa_id;

                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Soluzione</label>';
                // html += '                <div class="col-md-4 col-8 view-param">' + solutionName + '</div>';
                html += '                <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['solution-probe']) + '</div>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Metodo</label>';
                // html += '                <div class="col-md-4 col-8 view-param">' + methodSpan + '</div>';
                html += '                <div class="col-md-4 col-8 view-param">' + checkIfExist(instrObj['method-probe']) + '</div>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                // html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Arpa ID</label>';
                // html += '                <div class="col-md-4 col-8 view-param">' + tankArpaID + '</div>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Taratura</label>';
                html += '                <div class="col-md-4 col-8 view-param">' + dataMod(instrObj['mod-probe']) + '</div>';
                html += '            </div>';
                html += '            <hr class="m-t-0 m-b-10">';
                html += '            <div class="row view-label">';
                html += '                <label for="" class="control-label col-md-2 col-4 offset-2 col-form-label">Temperatura</label>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Conducibilità</label>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Ph</label>';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Redox</label>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Valore letto</label>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['read-temp-probe']) + ' °C</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['read-cond-probe']) + ' µS/cm</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['read-ph-probe']) + '</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['read-redox-probe']) + ' mV</div>';
                html += '            </div>';
                html += '            <div class="form-group row">';
                html += '                <label for="" class="control-label col-md-2 col-4 col-form-label">Valore teorico</label>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['theory-temp-probe']) + ' °C</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['theory-cond-probe']) + ' µS/cm</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['theory-ph-probe']) + '</div>';
                html += '                <div class="col-md-2 col-4 view-param">' + checkIfExist(instrObj['theory-redox-prob']) + ' mV</div>';
                html += '            </div>';
                html += '        </div>';
                break;

        };

        html +='        <h4 class="box-title m-t-30">Eventuali commenti</h4>';
        html +='        <hr class="m-t-0 m-b-20">';
        html +='        <div class="form-group row">';
        html +='            <label for="" class="control-label col-2 col-form-label">Nota</label>';
        html +='            <div class="col-10 view-param">'+checkIfExist(report.calib_note)+'</div>';
        html +='        </div>';

        // check if report has attachments
        //  - if true then add attachments to the report's detail tab
        if(report.attachments){
            html +='        <!-- parte Finale -->';
            html +='        <h4 class="box-title">Allegati</h4>';
            html +='        <hr class="m-t-0 m-b-20">';
            // parse json object
            var attachments = JSON.parse(report.attachments);
            console.dir(attachments);
            // loop through attachments
            // different items depending on the file type
            html +='         <div class="report-gallery-big clearfix">';
            $.each(attachments, function(inner_index, inner_value){
                if (inner_value.file_image == true){

                    html += '         <a href="/uploads/report/qa_tarature/'+inner_value.file_archive+'" class="clearfix thumb-gallery-lg"><img src="/uploads/report/qa_tarature/'+inner_value.file_archive+'"></a>';
                }
            });
            html +='         </div>';

            // loop for not image attachments
            html +='         <ul class="attachments-files">';
            $.each(attachments, function(inner_index, inner_value){
                if (inner_value.file_image == false){

                    html +='         <li>';
                    html +='             <a href="/uploads/report/qa_tarature/'+inner_value.file_archive+'" target="_blank"><i class="icon-paper-clip"></i> '+inner_value.file_original+'</a>';
                    html +='         </li>';
                }
            });
            html +='         </ul>';

        }
        html +='        <hr class="m-t-30">';
        html +='        <div class="form-group row">';
        html +='            <div class="col-12">';
        html +='                <button type="button" class="btn btn-primary close-report" data-close="rep'+rpid+'"> <i class="icon-close"></i> Chiudi report</button>';
        html +='            </div>';
        html +='        </div>';
        html +='    </div>';
        html +='</div>';

        return html;
    }

    /**
     * Function that fills the calibration form.
     *
     * @param {integer} catId Instrument category ID.
     * @param {object} instrObj Calibration values retrived from the database.
     */
    function editInstrument(catId, instrObj){
        console.log('modifica strumenti');
        console.dir(instrObj);

        // fill calibration values form
        // take care of different instrument category
        switch ( parseInt(catId) ) {
            case 1:
                // SO2
                // zero
                $("#find-zero-so2").val(instrObj['find-zero-so2']);
                $("#tank-zero-so2").val(instrObj['tank-zero-so2']);
                $("#method-zero-so2").val(instrObj['method-zero-so2']);
                $("#mod-zero-so2").prop('checked', checkboxChecked(instrObj['mod-zero-so2']));
                // span
                $("#tank-span-so2").val(instrObj['tank-span-so2']);
                $("#method-span-so2").val(instrObj['method-span-so2']);
                $("#read-span-so2").val(instrObj['read-span-so2']);
                $("#theory-span-so2").val(instrObj['theory-span-so2']);
                $("#mod-span-so2").prop('checked', checkboxChecked(instrObj['mod-span-so2']));
                // span multiple
                $("#l1-read-span-so2").val(instrObj['l1-read-span-so2']);
                $("#l1-theory-span-so2").val(instrObj['l1-theory-span-so2']);
                $("#l2-read-span-so2").val(instrObj['l2-read-span-so2']);
                $("#l2-theory-span-so2").val(instrObj['l2-theory-span-so2']);
                $("#l3-read-span-so2").val(instrObj['l3-read-span-so2']);
                $("#l3-theory-span-so2").val(instrObj['l3-theory-span-so2']);
                $("#l4-read-span-so2").val(instrObj['l4-read-span-so2']);
                $("#l4-theory-span-so2").val(instrObj['l4-theory-span-so2']);
                $("#l5-read-span-so2").val(instrObj['l5-read-span-so2']);
                $("#l5-theory-span-so2").val(instrObj['l5-theory-span-so2']);
                break;
            case 2:
                // NOx NO NO2
                // zero
                $("#method-zero-noxnono2").val(instrObj['method-zero-noxnono2']);
                $("#mod-zero-noxnono2").prop('checked', checkboxChecked(instrObj['mod-zero-noxnono2']));
                $("#nox-zero-noxnono2").val(instrObj['nox-zero-noxnono2']);
                $("#no-zero-noxnono2").val(instrObj['no-zero-noxnono2']);
                $("#no2-zero-noxnono2").val(instrObj['no2-zero-noxnono2']);
                // span
                $("#tank-span-noxnono2").val(instrObj['tank-span-noxnono2']);
                $("#method-span-noxnono2").val(instrObj['method-span-noxnono2']);
                $("#mod-span-noxnono2").prop('checked', checkboxChecked(instrObj['mod-span-noxnono2']));
                $("#read-nox-span-noxnono2").val(instrObj['read-nox-span-noxnono2']);
                $("#read-no-span-noxnono2").val(instrObj['read-no-span-noxnono2']);
                $("#read-no2-span-noxnono2").val(instrObj['read-no2-span-noxnono2']);
                $("#theory-nox-span-noxnono2").val(instrObj['theory-nox-span-noxnono2']);
                $("#theory-no-span-noxnono2").val(instrObj['theory-no-span-noxnono2']);
                $("#theory-no2-span-noxnono2").val(instrObj['theory-no2-span-noxnono2']);
                // span multiple
                $("#l1-read-nox-span-noxnono2").val(instrObj['l1-read-nox-span-noxnono2']);
                $("#l1-read-no-span-noxnono2").val(instrObj['l1-read-no-span-noxnono2']);
                $("#l1-theory-nox-span-noxnono2").val(instrObj['l1-theory-nox-span-noxnono2']);
                $("#l1-theory-no-span-noxnono2").val(instrObj['l1-theory-no-span-noxnono2']);
                $("#l2-read-nox-span-noxnono2").val(instrObj['l2-read-nox-span-noxnono2']);
                $("#l2-read-no-span-noxnono2").val(instrObj['l2-read-no-span-noxnono2']);
                $("#l2-theory-nox-span-noxnono2").val(instrObj['l2-theory-nox-span-noxnono2']);
                $("#l2-theory-no-span-noxnono2").val(instrObj['l2-theory-no-span-noxnono2']);
                $("#l3-read-nox-span-noxnono2").val(instrObj['l3-read-nox-span-noxnono2']);
                $("#l3-read-no-span-noxnono2").val(instrObj['l3-read-no-span-noxnono2']);
                $("#l3-theory-nox-span-noxnono2").val(instrObj['l3-theory-nox-span-noxnono2']);
                $("#l3-theory-no-span-noxnono2").val(instrObj['l3-theory-no-span-noxnono2']);
                $("#l4-read-nox-span-noxnono2").val(instrObj['l4-read-nox-span-noxnono2']);
                $("#l4-read-no-span-noxnono2").val(instrObj['l4-read-no-span-noxnono2']);
                $("#l4-theory-nox-span-noxnono2").val(instrObj['l4-theory-nox-span-noxnono2']);
                $("#l4-theory-no-span-noxnono2").val(instrObj['l4-theory-no-span-noxnono2']);
                break;
            case 3:
                // CO
                // zero
                $("#find-zero-co").val(instrObj['find-zero-co']);
                $("#method-zero-co").val(instrObj['method-zero-co']);
                $("#mod-zero-co").prop('checked', checkboxChecked(instrObj['mod-zero-co']));
                // span
                $("#tank-span-co").val(instrObj['tank-span-co']);
                $("#method-span-co").val(instrObj['method-span-co']);
                $("#read-span-co").val(instrObj['read-span-co']);
                $("#theory-span-co").val(instrObj['theory-span-co']);
                $("#mod-span-co").prop('checked', checkboxChecked(instrObj['mod-span-co']));
                // span multiple
                $("#l1-read-span-co").val(instrObj['l1-read-span-co']);
                $("#l1-theory-span-co").val(instrObj['l1-theory-span-co']);
                $("#l2-read-span-co").val(instrObj['l2-read-span-co']);
                $("#l2-theory-span-co").val(instrObj['l2-theory-span-co']);
                $("#l3-read-span-co").val(instrObj['l3-read-span-co']);
                $("#l3-theory-span-co").val(instrObj['l3-theory-span-co']);
                $("#l4-read-span-co").val(instrObj['l4-read-span-co']);
                $("#l4-theory-span-co").val(instrObj['l4-theory-span-co']);
                $("#l5-read-span-co").val(instrObj['l5-read-span-co']);
                $("#l5-theory-span-co").val(instrObj['l5-theory-span-co']);
                break;
            case 4:
                // O3
                // zero
                $("#find-zero-o3").val(instrObj['find-zero-o3']);
                $("#method-zero-o3").val(instrObj['method-zero-o3']);
                $("#mod-zero-o3").prop('checked', checkboxChecked(instrObj['mod-zero-o3']));
                // span
                $("#calib-span-o3").val(instrObj['calib-span-o3']);
                $("#method-span-o3").val(instrObj['method-span-o3']);
                $("#read-span-o3").val(instrObj['read-span-o3']);
                $("#theory-span-o3").val(instrObj['theory-span-o3']);
                $("#mod-span-o3").prop('checked', checkboxChecked(instrObj['mod-span-o3']));
                // span multiple
                $("#l1-read-span-o3").val(instrObj['l1-read-span-o3']);
                $("#l1-theory-span-o3").val(instrObj['l1-theory-span-o3']);
                $("#l2-read-span-o3").val(instrObj['l2-read-span-o3']);
                $("#l2-theory-span-o3").val(instrObj['l2-theory-span-o3']);
                $("#l3-read-span-o3").val(instrObj['l3-read-span-o3']);
                $("#l3-theory-span-o3").val(instrObj['l3-theory-span-o3']);
                $("#l4-read-span-o3").val(instrObj['l4-read-span-o3']);
                $("#l4-theory-span-o3").val(instrObj['l4-theory-span-o3']);
                $("#l5-read-span-o3").val(instrObj['l5-read-span-o3']);
                $("#l5-theory-span-o3").val(instrObj['l5-theory-span-o3']);
                break;
            case 5:
                // BTX
                // zero
                $("#method-zero-btx").val(instrObj['method-zero-btx']);
                $("#tank-zero-btx").val(instrObj['tank-zero-btx']);
                $("#mod-zero-btx").prop('checked', checkboxChecked(instrObj['mod-zero-btx']));
                $("#find-ben-zero-btx").val(instrObj['find-ben-zero-btx']);
                $("#find-tol-zero-btx").val(instrObj['find-tol-zero-btx']);
                $("#find-xil-zero-btx").val(instrObj['find-xil-zero-btx']);
                // span
                $("#tank-span-btx").val(instrObj['tank-span-btx']);
                $("#method-span-btx").val(instrObj['method-span-btx']);
                $("#mod-span-btx").prop('checked', checkboxChecked(instrObj['mod-span-btx']));
                $("#read-ben-span-btx").val(instrObj['read-ben-span-btx']);
                $("#read-tol-span-btx").val(instrObj['read-tol-span-btx']);
                $("#read-xil-span-btx").val(instrObj['read-xil-span-btx']);
                $("#theory-ben-span-btx").val(instrObj['theory-ben-span-btx']);
                $("#theory-tol-span-btx").val(instrObj['theory-tol-span-btx']);
                $("#theory-xil-span-btx").val(instrObj['theory-xil-span-btx']);
                // span multiple
                $("#l1-read-span-btx").val(instrObj['l1-read-span-btx']);
                $("#l1-theory-span-btx").val(instrObj['l1-theory-span-btx']);
                $("#l2-read-span-btx").val(instrObj['l2-read-span-btx']);
                $("#l2-theory-span-btx").val(instrObj['l2-theory-span-btx']);
                $("#l3-read-span-btx").val(instrObj['l3-read-span-btx']);
                $("#l3-theory-span-btx").val(instrObj['l3-theory-span-btx']);
                $("#l4-read-span-btx").val(instrObj['l4-read-span-btx']);
                $("#l4-theory-span-btx").val(instrObj['l4-theory-span-btx']);
                $("#l5-read-span-btx").val(instrObj['l5-read-span-btx']);
                $("#l5-theory-span-btx").val(instrObj['l5-theory-span-btx']);
                break;
            case 7:
                // CH4
                // zero
                $("#find-zero-ch4").val(instrObj['find-zero-ch4']);
                $("#find-zero-tnmhc").val(instrObj['find-zero-tnmhc']);
                $("#method-zero-ch4").val(instrObj['method-zero-ch4']);
                $("#mod-zero-ch4").prop('checked', checkboxChecked(instrObj['mod-zero-ch4']));
                // span
                $("#tank-span-ch4").val(instrObj['tank-span-ch4']);
                $("#method-span-ch4").val(instrObj['method-span-ch4']);
                $("#read-span-ch4").val(instrObj['read-span-ch4']);
                $("#read-span-tnmhc").val(instrObj['read-span-tnmhc']);
                $("#theory-span-ch4").val(instrObj['theory-span-ch4']);
                $("#theory-span-tnmhc").val(instrObj['theory-span-tnmhc']);
                $("#mod-span-ch4").prop('checked', checkboxChecked(instrObj['mod-span-ch4']));
                break;
            case 8:  // 'Campionatore polveri'
            case 9:  // 'Campionatore polveri alto volume'
            case 10: // 'Campionatore polveri basso volume'
            case 11: // 'Campionatore polveri con PUF'
            case 12: // 'Campionatore polveri beta'
            case 13: // 'Campionatore polveri microbilancia'
                // Campionatori, SM200 - Skypost - Teom - MCZ
                $("#read-flow-sampler").val(instrObj['read-flow-sampler']);
                $("#reference-flow-sampler").val(instrObj['reference-flow-sampler']);
                $("#temp-flow-sampler").val(instrObj['temp-flow-sampler']);
                $("#temp-instr-flow-sampler").val(instrObj['temp-instr-flow-sampler']);
                $("#press-flow-sampler").val(instrObj['press-flow-sampler']);
                $("#press-instr-flow-sampler").val(instrObj['press-instr-flow-sampler']);
                $("#mod-flow-sampler").prop('checked', checkboxChecked(instrObj['mod-flow-sampler']));
                break;
            case 14: // 'Campionatore polveri ottico'
            case 15: // 'Campionatore black carbon'
            case 18: // 'Spettrometro aerosol'
                // Aerosol
                $("#tank-span-aerosol").val(instrObj['tank-span-aerosol']);
                $("#method-span-aerosol").val(instrObj['method-span-aerosol']);
                $("#read-span-aerosol").val(instrObj['read-span-aerosol']);
                $("#theory-span-aerosol").val(instrObj['theory-span-aerosol']);
                $("#mod-span-aerosol").prop('checked', checkboxChecked(instrObj['mod-span-aerosol']));
                $("#read-flow-aerosol").val(instrObj['read-flow-aerosol']);
                $("#reference-flow-aerosol").val(instrObj['reference-flow-aerosol']);
                $("#temp-flow-aerosol").val(instrObj['temp-flow-aerosol']);
                $("#temp-instr-flow-aerosol").val(instrObj['temp-instr-flow-aerosol']);
                $("#press-flow-aerosol").val(instrObj['press-flow-aerosol']);
                $("#press-instr-flow-aerosol").val(instrObj['press-instr-flow-aerosol']);
                $("#mod-flow-aerosol").prop('checked', checkboxChecked(instrObj['mod-flow-aerosol']));
                break;
            case 25:
                // BIOGAS
                // zero
                $("#method-zero-biogas").val(instrObj['method-zero-biogas']);
                $("#mod-zero-biogas").prop('checked', checkboxChecked(instrObj['mod-zero-biogas']));
                $("#o2-zero-biogas").val(instrObj['o2-zero-biogas']);
                $("#ch4-zero-biogas").val(instrObj['ch4-zero-biogas']);
                $("#co2-zero-biogas").val(instrObj['co2-zero-biogas']);
                // span
                $("#tank-span-biogas").val(instrObj['tank-span-biogas']);
                $("#method-span-biogas").val(instrObj['method-span-biogas']);
                $("#mod-span-biogas").prop('checked', checkboxChecked(instrObj['mod-span-biogas']));
                $("#read-o2-span-biogas").val(instrObj['read-o2-span-biogas']);
                $("#read-ch4-span-biogas").val(instrObj['read-ch4-span-biogas']);
                $("#read-co2-span-biogas").val(instrObj['read-co2-span-biogas']);
                $("#theory-o2-span-biogas").val(instrObj['theory-o2-span-biogas']);
                $("#theory-ch4-span-biogas").val(instrObj['theory-ch4-span-biogas']);
                $("#theory-co2-span-biogas").val(instrObj['theory-co2-span-biogas']);
                break;
            case 26:
                // Sonde
                $("#solution-probe").val(instrObj['solution-probe']);
                $("#method-probe").val(instrObj['method-probe']);
                $("#mod-probe").prop('checked', checkboxChecked(instrObj['mod-probe']));
                $("#read-temp-probe").val(instrObj['read-temp-probe']);
                $("#read-cond-probe").val(instrObj['read-cond-probe']);
                $("#read-ph-probe").val(instrObj['read-ph-probe']);
                $("#read-redox-probe").val(instrObj['read-redox-probe']);
                $("#theory-temp-probe").val(instrObj['theory-temp-probe']);
                $("#theory-cond-probe").val(instrObj['theory-cond-probe']);
                $("#theory-ph-probe").val(instrObj['theory-ph-probe']);
                $("#theory-redox-probe").val(instrObj['theory-redox-probe']);
                break;
        };

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
        return;
    }

    /**
     * Function that downloads the calibration's total pdf of a given network and, if provieded, of a given station.
     *
     * @param {*} dateFrom Start period datetime.
     * @param {*} dateTo End period datetime.
     * @param {*} stid Station ID, if provided.
     *
     * @returns FALSE (this is critical to stop the click event which will trigger a normal file download!)
     */
    function downloadPDF(dateFrom, dateTo, stid){
        var net   = $( "#networks" ).val();
        var stid  = $( "#stations" ).val();

        console.log('Download report\'s PDF');

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        var url = "/rep_qa_tarature_get_total_pdf";

        /**
         * http://johnculviner.com/category/jquery-file-download/
         */
        $.fileDownload(url, {
            httpMethod: 'GET',
            data: {
                from: dateFrom,
                to: dateTo,
                net: net,
                stid: stid
            },
            successCallback: function(url) {
                console.log("PDF scaricato correttamente");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            },
            failCallback: function(responseHtml, url, error) {
                console.log('errore durante lo scarico.');
                // error message
                swal("Errore!", "Il file pdf non è stato creato oppure errore durante lo scarico", "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        });

        console.log('End download');

        // this is critical to stop the click event which will trigger a normal file download!
        return false;
    };
});

