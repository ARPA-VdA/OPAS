/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var mySummernote;
    var myDropzone;

    // variable for loadReport function
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
            'Ultimi 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimi 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh reports list in the first tab
        loadReports(dateFrom, dateTo);
    });

    $('#provinces').select2();

    //datatable
    table = $('#report-table').DataTable({
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

    $( "#provinces" ).on( "change", function() {

        // refresh reports list in the first tab
        loadReports(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive report detail.
     */
    $('#report-table').on('click', '.show-report', function(e){
        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));
        // check if the report's detail is already open
        if( $('#rep'+rpid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#rep' + rpid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        loadReportDetail(rpid);
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
            url: '/rep_qa_sopralluoghi_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            }
        })
        .done(function(result) {

            console.dir(result);

            // check result
            if(result.res == 'OK'){

                // fill fields of the form with metadata arriving from database
                var report = result.report;
                // json objects to be parsed
                var attachments = JSON.parse(report.attachments);

                // {
                //   "survey-datetime" => "01/05/2023 08:33",
                //   "survey-district" => 4790,
                //   "survey-id" => "",
                //   "survey-operators" => [
                //                           3,
                //                           4,
                //                           5
                //                         ],
                //   "survey-place" => "localit\x{e0} test",
                //   "survey-prov" => 72,
                //   "survey-text" => "..."
                // }

                $('#survey-id').val(report.insp_id);
                $('#survey-prov').val(report.province_id).trigger('change', report.mu_id);
                $('#survey-place').val(report.insp_locality);
                // manage date
                $('#survey-datetime').val(moment(report.insp_fulldate).format('DD/MM/YYYY HH:mm'));
                $('#survey-datetime').bootstrapMaterialDatePicker('setDate', moment(report.insp_fulldate).format('DD/MM/YYYY HH:mm'));

                $('#survey-operators').val(report.insp_operators).trigger('change');

                // manage summernote
                $('.summernote').summernote('code', report.insp_note);

                // check if report has attachments
                //  - if true then add attachemnts to the report's detail page
                if(attachments){
                    var htmlImages = '';

                    // loop through attachments
                    // different items depending on the file type
                    $.each(attachments, function(idx, attachment){
                        // check if current looped attachment is an image
                        if(attachment.file_image == true){
                            // image files
                            htmlImages +='    <div class="del-my-img">\n';
                            htmlImages +='      <span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span><a href="/uploads/report/qa_sopralluoghi/'+attachment.file_archive+'" class="clearfix thumb-gallery"><img src="/uploads/report/qa_sopralluoghi/'+attachment.file_archive+'"></a>\n';
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
                $('#new .box-title').html('Modifica SOPRALLUOGO');
                $('#btn-survey-form').html(' <i class="ti-save"></i> Modifica report');

                // show form tab
                $('.customtab a[href="#new"]').tab('show');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del report", "error");
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
    });

    /**
     * Download PDF report.
     */
    $('#report-table').on('click', '.pdf-report', function(e){
        e.preventDefault();

        // get report id stored in table tr element
        var rpid = parseInt($(this).parent().parent().data("id"));

        // ajax call type GET in order to download pdf
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        var url = "/rep_qa_sopralluoghi_get_pdf";

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
                console.log('errore durante lo scarico.');
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
            title: "Stai per eliminare il verbale",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/rep_qa_sopralluoghi_del_report',
                type: "post",
                dataType: "json",
                data: {
                    id: rpid
                }
            })
            .done(function(result) {
                // check result
                //  - if '1' then the report is correctly deleted -> remove it from table
                //  - else error
                if(result){
                    // delete row from datatable without reloading the entire list and refresh it
                    swal("Verbale eliminato", "Il verbale è stato eliminato con successo!", "success");
                    table.row($("tr[data-id='"+rpid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del verbale", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione del verbale", "error");
            });

        });

    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // select2 initialization
    $( "#survey-prov, #survey-district, #survey-operators" ).select2();

    /**
     * New report insertion datetime.
     */
    $('#survey-datetime').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    });
    $('#survey-datetime').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

    // summernote initialization
    mySummernote = $('.summernote').summernote({
        // height: 350, // set editor height
        minHeight: 230, // set minimum height of editor
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
            { title: 'Normale', tag: 'p', className: 'p', value: 'p' },
            'h1', 'h2', 'h3', 'h4', 'h5'
        ]
    });

    // Dropzone initialization //
    var url = "/rep_qa_sopralluoghi_put_report";

    myDropzone = initDropzone(url);

    /**
     * Province change event
     */
    $('#survey-prov').on('change', function(e, muid){

        // retrieve province id
        var provid = parseInt($(this).val());
        // if id equal to -1 reset municipalities
        // else load municipalities and fill the select element
        if(provid == -1){
            $('#survey-district').empty();
            $('#survey-district').append('<option value="-1">Seleziona comune...</option>');
        }
        else
            loadMunicipalities(provid, muid);

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
                url: '/rep_qa_sopralluoghi_selected_attachment',
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

    //!! SUBMIT REGION
    /**
     * Validate form.
     */
    var validator = $('#survey-form').validate({ // initialize the plugin
        rules: {
            "survey-prov":{
                required: true,
                min: 0
            },
            "survey-district" : {
                required: true,
                min: 0
            },
            "survey-place" : {
                required: true
            },
            "survey-datetime" : {
                required: true
            }
        },
        messages: {
            "survey-prov":{
                required: "Selezionare provincia",
                min: "Selezionare provincia"
            },
            "survey-district" : {
                required: "Selezionare comune",
                min: "Selezionare comune"
            },
            "survey-place" : {
                required: "Inserire località"
            },
            "survey-datetime" : {
                required: "Inserire data"
            }
        },
        // ignore summernote
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
    myDropzone.on("sendingmultiple", function(files, xhr, formData) {

        // serialize total form
        var totalForm = $('#survey-form').serializeArray();
        // manage summernote
        totalForm.push({ name: "survey-text", value: $('.summernote').summernote('code') });

        // add form fields to the dropzone submission object
        $.each(totalForm, function(index, input){
            formData.append(input.name, input.value);
        });


    });

    /**
     * Function called at the Dropzone submit return.
     */
    myDropzone.on("successmultiple", function(files, response) {
        // at the end of the process hide preloader
        $(".inner-preloader").hide();

        var id   = $("#survey-id").val();

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

            // refresh reports list in the first tab
            loadReports(dateFrom, dateTo);
            // show first tab
            $('.customtab a[href="#report-list"]').tab('show');
            // reset form
            clearFields();
        }
        else{
            // take care of any errors
            swal("Errore!", msg_err, "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // manage files, add error class and re-queue them
            $.each(files, function(index, file) {
                file.previewElement.classList.add("dz-error");
                file.status = Dropzone.QUEUED
            });

            return false;
        }
    });

    /**
     * Submit report new/edit form.
     */
    $('#survey-form').on('submit', function (e) {

        e.preventDefault();

        // check if all form fields are valid
        if(! $(this ).valid() || $('#survey-text').summernote('isEmpty')){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare il report", "info");
            return false;
        };

        var form = $("#survey-form").serializeArray();
        var id   = $("#survey-id").val();

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

        form.push({ name: "survey-text"     , value: $('.summernote').summernote('code') });

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
                url: '/rep_qa_sopralluoghi_put_report',
                type: 'post',
                dataType: "json",
                data: form
            }).done(function(result) {
                // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
                if(result){
                    swal("Successo", msg_ok, "success");

                    // refresh reports list in the first tab
                    loadReports(dateFrom, dateTo);
                    // show first tab
                    $('.customtab a[href="#report-list"]').tab('show');
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
    $('#cancel-survey-form').on('click', function(e) {
        e.preventDefault();

        // show report table and reset form
        $('.customtab a[href="#report-list"]').tab('show');
        clearFields();
    });
    /////////////////////////////////////////////////////////////////////
    //END FORM FUNCTIONS

    //TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close view report.
     */
    $('.card-body').on('click', '.close-report', function(e){
        // get "element" to be closed
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
    //END TAB FUNCTIONS

    loadReports(dateFrom, dateTo);

    /**
     * Function that re-initializes MagnificPopup plugin for each row in datatable
     */
    function refreshGallery() {

        console.log("Refresh gallery");
        table.rows({page: 'all'}).every(function() { // the containers for all your galleries
            var row = this;
            // get all tr node and transform it into a jquery items
            // in order to find gallery elements
            $(row.node())
                .find(".report-gallery")
                .magnificPopup({
                    delegate: 'a', // the selector for gallery item
                    type: 'image',
                    gallery: {
                      enabled:true
                    }
                });
        });
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
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields() {
        console.log('clearFields');

        // reset all input tag values
        $('.clear-input').val('');
        // reset all select tag values
        $('.clear-select').val(-1);
        // manage select 2
        $( "#survey-prov" ).trigger('change');
        $( "#survey-operators" ).val([]).trigger('change');
        // manage date
        $('#survey-datetime').val(moment().format('DD/MM/YYYY HH:mm'));
        $('#survey-datetime').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        // manage summernote
        $('.summernote').summernote('reset');

        // remove all attachments
        myDropzone.removeAllFiles(true);
        // reset div for attachments
        $('#img-container').empty();
        $('.attachment-files').empty();

        // reset form texts
        $('#inner-new-report').text('Nuovo');
        $('#new .box-title').html('Inserisci nuovo SOPRALLUOGO');
        $('#btn-survey-form').html(' <i class="ti-save"></i> Inserisci report');
        // reset form validation
        $("#survey-form").validate().resetForm();
    }

    /**
     * Function that retrieves minucipalities
     *
     * @param {integer} Id of province
     * @param {integer} Id of municipality
     *
     */
    function loadMunicipalities(provid, muid){
        console.log('loadMunicipalities');

        // get municipalities via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_sopralluoghi_get_municipalities',
            dataType: "json",
            type: "post",
            data: {
                province: provid
            }
        })
        .done(function(result) {

            // check result
            // if OK then fill the select else show error message
            if(result.res == 'OK'){
                // empty select element
                $('#survey-district').empty();
                var municipalities = result.municipalities;

                // create option items for "dest" select
                // loop through all elements
                // for each municipality, build a html option to be added to the select
                var opts = '<option value="-1">Seleziona comune...</option>';
                $.each(municipalities, function(idx, el){

                    opts += '<option value="'+el.mu_id+'">'+el.mu_name+'</option>';
                });

                $('#survey-district').append(opts);

                // if municipality id is not null then select it and trigger change event
                if(muid)
                    $('#survey-district').val(muid).trigger('change');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei comuni", "error");
            }
        })
        .fail(function(xhr, err) {
            console.log( "error" );
            // error message
            swal("Errore!", "Errore durante il recupero dei comuni", "error");
        });
    }

    /**
     * Function that retrieves reports of a given period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     *
     */
    function loadReports(from, to){

        // reset datatable
        if(table)
            table.clear();

        var prov = parseInt($('#provinces').val());

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get list of reports via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_sopralluoghi_get_reports',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                prov: prov
            }
        })
        .done(function(result) {
            console.log( "success" );
            console.dir(result);
            var reports = result.reports;

            // check if at least one element exists
            if( reports.length > 0 ){
                // variable for dinamically building the html
                var html = '';
                // loop through all elements
                // for each report, build a html row to be added to the datable
                $.each(reports, function(idx, el) {

                    html +='<tr data-id="'+el.insp_id+'">';
                    html +='    <td class="bobo-nowrap icons-little">';
                    html +='        <a href="javascript:void(0)" class="show-report log-element" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';

                    // if user has update grant
                    if(update_grant){
                        html +='        <a href="javascript:void(0)" class="edit-report" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                    }
                    html +='        <br>';
                    html +='        <a href="javascript:void(0)" class="pdf-report" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';

                    // if user has delete grant
                    if(delete_grant){
                        html +='        <a href="javascript:void(0)" class="delete-report" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    html += '    </td>';
                    html += '    <td>'+getFormattedDateDT(el.insp_fulldate, 'basic_timeStartMin')+'</td>';

                    html += '    <td class="bobo-nowrap operators">';
                    html += '        <img src="'+el.us_avatar_thumb+'">';
                    html += el.us_fullname;
                    html += '    </td>';
                    html += '    <td>'+el.municipality_format+'</td>';
                    html += '    <td>'+el.insp_locality+'</td>';
                    html += '    <td>'+el.operators_name.join(', ')+'</td>';

                    html += '    <td class="bobo-nowrap">';

                    if(el.attachments.length > 0){

                        html += '<div class="report-gallery clearfix">';

                        $.each(el.attachments, function(inner_index, inner_value){
                            var img_url = '/uploads/report/qa_sopralluoghi/'+inner_value;
                            html += '<a href="'+img_url+'" class="clearfix thumb-gallery"><img src="'+img_url+'" /></a>';
                        });

                        html += '</div>';
                    } else {
                        html += '--';
                    }
                    html += '    </td>';
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

                // re-initialize gallery plugin
                refreshGallery();

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
     * Function that builds the report detail.
     *
     * @param {integer} rpid Report ID.
     */
    function loadReportDetail(rpid) {
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get report data via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_sopralluoghi_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            // if OK then build html
            if(result.res == 'OK'){
                var el = result.report;
                var attachments = result.attachments;

                // add link for the new tab
                var html = '<li class="nav-item" data-id="'+rpid+'"> <a class="nav-link" data-toggle="tab" href="#rep'+rpid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+el.insp_locality+' - '+moment(el.insp_fulldate).format('DD/MM/YYYY')+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-report" data-close="rep'+rpid+'"></i></a></li>';
                $('.nav').append(html);

                // variable for dinamically building the html
                html = '';
                html += '<div class="tab-pane p-20" id="rep'+rpid+'" role="tabpanel">';
                html += '    <div class="form-body panel-report-view panel-view-mobile">';
                html += '        <h4 class="box-title">Report del '+el.insp_fulldate_format+'</h4>';
                html += '        <hr class="m-t-0 m-b-20">';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Operatore</label>';
                html += '            <div class="col-md-10 col-8 view-param">'+el.us_fullname+'</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Provincia</label>';
                html += '            <div class="col-md-10 col-8 view-param">'+el.province_name+' ('+el.province_code+')</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Comune</label>';
                html += '            <div class="col-md-10 col-8 view-param">'+el.mu_name+'</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Località</label>';
                html += '            <div class="col-md-10 col-8 view-param">'+el.insp_locality+'</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Partecipanti</label>';
                html += '            <div class="col-md-10 col-8 view-param">'+el.operators_name.join(', ')+'</div>';
                html += '        </div>';
                html += '        <div class="form-group row">';
                html += '            <label for="" class="control-label col-md-2 col-form-label">Note</label>';
                html += '            <div class="col-md-10 view-param">'+el.insp_note+'</div>';
                html += '        </div>';
                html += '        <h4 class="box-title m-t-15">Allegati</h4>';
                html += '        <hr class="m-t-0 m-b-20">';

                // check if there are attachments
                if(el.attachments){

                    var attachments = JSON.parse(el.attachments);
                    console.dir(attachments);
                    html += '            <div class="form-group row ">';
                    html += '                <div class="col-md-12 report-gallery-big">';
                    // loop through attachments
                    // different items depending on the file type
                    $.each(attachments, function(idx, attachment){
                        // check if current looped attachment is an image
                        if (attachment.file_image == true){
                            html += '            <a href="/uploads/report/qa_sopralluoghi/'+attachment.file_archive+'" class="clearfix thumb-gallery-lg"><img src="/uploads/report/qa_sopralluoghi/'+attachment.file_archive+'"></a>';
                        }
                    });
                    html += '                </div>';
                    html += '            </div>';
                }
                else {
                    html += '                <div class="form-group row">';
                    html += '                    <div class="col-12 view-param">Nessun allegato</div>';
                    html += '                </div>';
                }

                html += '        </div>';
                html += '        <hr class="m-t-30">';
                html += '        <div class="form-group row">';
                html += '            <div class="col-12">';
                html += '                <button type="button" class="btn btn-primary close-report" data-close="rep'+rpid+'"> <i class="icon-close"></i> Chiudi report</button>';
                html += '            </div>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                $('.tab-content').append(html);

                $('.customtab a[href="#rep'+rpid+'"]').tab('show');

                refreshGalleryBig();
            }
            else{
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // error messare
                swal("Errore!", "Errore durante il recupero dettaglio del report", "error");
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio del report", "error");
        });
    };

});



