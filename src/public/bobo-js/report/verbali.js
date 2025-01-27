var dirtyFlag = false;

$(window).on("beforeunload", function() {

    // if there is an unsaved report, it asks confirm before leave the page
    if(dirtyFlag)
        return true;
});

/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var mySummernote;
    var mySwitch;

    var loop;

    // variable for loadReports function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(6, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker initialization
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

        loadReports(dateFrom, dateTo);

    });

    // datatable initialization
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

    $('#provinces').select2();
    // "provinces" filter change event
    $('#provinces').on('change', function(){

        // load reports between dateFrom and dateTo, eventually filtered by province
        loadReports(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive report detail.
     */
    $('#report-table').on('click', '.show-report', function(e){
        e.preventDefault();

        // get report id
        var rpid = parseInt($(this).parent().parent().data("id"));
        // check if the report's detail is already open
        if( $('#rep'+rpid).length ) {
            console.log('The report\'s detail is already open');
            $('.customtab a[href="#rep' + rpid + '"]').tab('show');
            return;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // recover report data by an ajax call
        var jqxhr = $.ajax({
            url: '/rep_verbali_get_selected_report',
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

                var report = result.report;

                // create new tab link
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#rep'+rpid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+report.meet_date_format+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-report" data-close="rep'+rpid+'"></i></a></li>';
                $('.nav').append(html);

                // build html detail and open new tab
                var html = createDetail(report);

                $('.tab-content').append(html);
                $('.customtab a[href="#rep'+rpid+'"]').tab('show');

            }
            else{
                // error mesage
                swal("Errore!", "Errore durante il recupero del verbale", "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error mesage
            swal("Errore!", "Errore durante il recupero del verbale", "error");
        });
    });

    /**
     * Edit report.
     */
    $('#report-table').on('click', '.edit-report', function(e){
        e.preventDefault();

        // get report id stored in table tr elment
        var rpid = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // recover report data by an ajax call
        var jqxhr = $.ajax({
            url: '/rep_verbali_get_selected_report',
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

                // set tab texts
                $('#inner-new-report').text('Modifica');
                $('#new-element .box-title').text('Modifica VERBALE');
                $('#btn-report-form').html(' <i class="ti-save"></i> Modifica');

                // hide switch "Invia email riassuntiva": only available in insert mode
                $('.hide-edit').hide();

                // populate the fields of "new report" form
                var report = result.report;

                $('#report-id').val(report.meet_id);

                $('#report-verbalizer').val(report.us_id).trigger('change');
                $('#report-date').val(report.meet_date_format);

                if(report.meet_start_time){
                    $('#report-time-start').bootstrapMaterialDatePicker('setDate', report.meet_start_time);
                    $('#report-time-start').trigger('change');
                }
                if(report.meet_end_time){
                    $('#report-time-end').bootstrapMaterialDatePicker('setDate', report.meet_end_time);
                    $('#report-time-end').trigger('change');
                }

                $('#report-prov').val(report.province_id);
                $('#report-locality').val(report.meet_locality);
                // select2 needs trigger change
                $('#report-participants').val(report.meet_participants).trigger('change');
                $('#report-title').val(report.meet_title);

                $('.summernote').summernote('code', report.meet_desc);

                // show tab
                $('.customtab a[href="#new"]').tab('show');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del verbale", "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del verbale", "error");
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

        // ajax call type GET in order to download pdf
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        var url = "/rep_verbali_get_pdf";

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

        return false; //this is critical to stop the click event which will trigger a normal file download!

    });

    /**
     * Delete report.
     */
    $('#report-table').on('click', '.delete-report', function(e){
        e.preventDefault();

        // get report id
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
                url: '/rep_verbali_del_selected_report',
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

    // initialize select2 at tab "show" event to manage placeholders (otherwise it's cut)
    $('a[data-toggle="tab"]').on('shown.bs.tab', function(){

        if($(this).attr('id') == 'new-report'){
            $( "#report-participants").select2({
                placeholder: 'Seleziona partecipanti...'
            });
        }
    });

    // verbalizer select2 initialization
    $( "#report-verbalizer, #report-prov" ).select2();

    // date picker initialization
    $('#report-date').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        time: false,
        cancelText : 'Annulla'
    });

    // setting "today" as default date
    $('#report-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));

    // report start/end time plugin initialization
    $('#report-time-start, #report-time-end').bootstrapMaterialDatePicker({
        format: 'HH:mm',
        date: false,
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date as start time picker value
        $('#report-time-end').bootstrapMaterialDatePicker('setMinDate', $('#report-time-start').val() );

        // check if start time is same or after end time
        if( moment($('#report-time-start').val(), 'HH:mm').isSameOrAfter( moment($('#report-time-end').val(), 'HH:mm') ))
            // if true then reset end time
            $('#report-time-end').val('');

        // check if end time is not empty
        if( $('#report-time-end').val() != '' ){

            // calculating duration: diff between end time and start time
            var duration = moment.duration( moment($('#report-time-end').val(), 'HH:mm').diff( moment($('#report-time-start').val(), 'HH:mm') ) );
            var hours = duration.hours();
            var minutes = duration.minutes();
            var textDuration = ( (hours > 0) ? (hours+' ore ') : '' );
            textDuration += minutes+' minuti';
            console.log(textDuration);
            $('.duration').text(textDuration);

        }
        else{
            $('.duration').text('--');
        }
    });

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

    // switchery initialization
    // mySwitch = new Switchery($("#send-email")[0], $("#send-email").data());

    // at first change of any input, set dirtyFlag to true and take care of local storage
    $('.flag-el').on('change', function(e){

        if(dirtyFlag == false){

            // start a loop that every second re-initializes local storage "meeting" data
            loop = setInterval(function(){
                storageRemove('meeting');
                storageStore('meeting', JSON.stringify(createObject()) );
            }, 1000);

            dirtyFlag = true;
        }
    });

    /**
     * Validate form.
     */
    var validator = $('#report-form').validate({ // initialize the plugin
        rules: {
            "report-verbalizer":{
                required: true,
                min: 0
            },
            "report-date" : {
                required: true
            },
            "report-time-start" : {
                required: true
            },
            "report-time-end" : {
                required: true
            },
            "report-prov":{
                required: true,
                min: 0
            },
            "report-locality" : {
                required: true
            },
            "report-title" : {
                required: true
            },
            "report-text" : {
                required: true
            },
        },
        messages: {
            "report-verbalizer":{
                required: "Selezionare verbalizzante",
                min: "Selezionare verbalizzante"
            },
            "report-date" : {
                required: "Inserire data"
            },
            "report-time-start" : {
                required: "Inserire ora inizio"
            },
            "report-time-end" : {
                required: "Inserire ora fine"
            },
            "report-prov":{
                required: "Selezionare provincia",
                min: "Selezionare provincia"
            },
            "report-locality" : {
                required: "Inserire località"
            },
            "report-title" : {
                required: "Inserire un oggetto",
            },
            "report-text" : {
                required: "Inserire un testo",
            },
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
     * Submit report new/edit form.
     */
    $('#report-form').on('submit', function (e) {

        e.preventDefault();

        // check if all form fields are valid
        if(! $(this ).valid() || $('#report-text').summernote('isEmpty')){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare il verbale", "info");
            return false;
        };

        var id   = parseInt($("#report-id").val());

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

        // create complex object to be sent to server
        var formMain = createObject();
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        $.ajax({
            type: 'post',
            url: '/rep_verbali_put_report',
            data: formMain
        }).done(function(result) {

            // check result
            if(result == 1){
                swal("Successo", msg_ok, "success");
                // update report list
                // load reports between dateFrom and dateTo, eventually filtered by province
                loadReports(dateFrom, dateTo);
                // show report table
                $('.customtab a[href="#report-list"]').tab('show');

                // reset form and the "setInterval" loop
                clearFields();
                clearInterval(loop);
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
    });

    /**
     * Cancel button.
     */
    $('#cancel-report-form').on('click', function(e) {
        e.preventDefault();

        // show report table and reset form
        $('.customtab a[href="#report-list"]').tab('show');
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
        e.preventDefault();

        var close = $(this).data("close");
        console.log(close);

        // close tab and show first tab
        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#report-list"]').tab('show');

        }, 1);
    });

    /////////////////////////////////////////////////////////////////////
    // END TAB FUNCTIONS

    // load reports between dateFrom and dateTo, eventually filtered by province
    loadReports(dateFrom, dateTo);

    // check if a report exists in local storage
    if(storageGet('meeting')){
        console.log('STORAGE CON DATI');
        // confirm message in order to choose to continue with saved report or discard it
        swal({
            title: "Attenzione",
            text: "E' presente un verbale in bozza. Riprenderne la compilazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si",
            closeOnConfirm: true,
            cancelButtonText: "No"
        }, function (isConfirm) {

            if(isConfirm){
                // recover report from local storage and populate "new report" form
                formObj= JSON.parse(storageGet('meeting'));
                console.dir(formObj);
                recoverReport(formObj);
                $('.customtab a[href="#new"]').tab('show');
            }
            else{
                // empty local storage "meeting" data
                console.log('SVUOTA STORAGE');
                storageRemove('meeting');
            }
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
    }

    /**
     * Function resetting "new report" form.
     */
    function clearFields(){
        console.log('clearFields');
        // reset input type
        $('.clear-input').val("");
        // reset select
        $('.clear-select').val(-1);

        // reset form fields
        $('#report-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));
        $('#report-time-start').bootstrapMaterialDatePicker('setDate', moment().format('HH:mm'));
        $('.duration').text('--');
        // reset select 2
        $('#report-participants').val([]);
        $('#report-verbalizer, #report-participants').trigger('change');

        $('.summernote').summernote('reset');

        $('.hide-edit').show();
        // setSwitchery(mySwitch, true);

        // reset tab texts
        $('#inner-new-report').text('Nuovo');
        $('#new-element .box-title').text('Inserisci nuovo VERBALE');
        $('#btn-report-form').html(' <i class="ti-save"></i> Inserisci');

        // reset validator
        $('#report-form').validate().resetForm();

        // reset local storage and dirty flag
        dirtyFlag = false;
        clearInterval(loop);
        storageRemove('meeting');
    }

    /**
     * Function that retrieves the reports of a given period, eventually filtered by province.
     * 
     * @param {date} dateFrom Start period datetime.
     * @param {date} dateTo End period datetime.
     */
    function loadReports(dateFrom, dateTo){
        var prov  = $( "#provinces" ).val();

        // reset datatable
        if ( table )
            table.clear();

        // get reports created between "dateFrom" and "dateTo"
        // console.log('ajax');
        var jqxhr = $.ajax({
        url: '/rep_verbali_get_reports',
        type: "post",
        dataType: "json",
        data: {
            from    : dateFrom,
            to      : dateTo,
            prov    : prov
        },
        })
        .done(function(result) {
            var reports = result.reports;
            console.dir(reports);
            // variable for dinamically building the html
            var html= '';
            // check if at least one element exists
            if( reports.length > 0 ){

                // loop through all elements
                // for each municipality, build a html row to be added to datatable
                $.each(reports, function(index, value) {

                    html +='<tr data-id="'+value.meet_id+'">';
                    html +='    <td class="bobo-nowrap icons-little">';
                    html +='        <a href="javascript:void(0)" class="show-report" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';

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
                    html +='    </td>';
                    html +='    <td>'+getFormattedDateDT(value.meet_date, 'basic')+'</td>';
                    html +='    <td class="bobo-nowrap operators">';
                    html +='        <img src="'+value.user_avatar_thumb+'">';
                    html += value.user_fullname;
                    html +='    </td>';
                    html +='    <td>'+moment(value.meet_start_time, 'HH:mm:ss').format('HH:mm')+'</td>';
                    html +='    <td>'+moment(value.meet_end_time, 'HH:mm:ss').format('HH:mm')+'</td>';
                    html +='    <td>'+value.meet_title+'</td>';
                    html +='    <td>'+value.province_code+'</td>';
                    html +='    <td>'+value.meet_locality+'</td>';
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
                table.draw();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei verbali", "error");
            table.draw();
        });

        return;
    }

    /**
     * Create the object for local storage and form submit.
     * 
     * @returns The form.
     */
    function createObject(){

        var form = $('#report-form').serializeArray();
        form.push({ name: "report-text"    , value: $('.summernote').summernote('code') });
        form.push({ name: "array-participants" , value: $('#report-participants').val()   });

        return form;
    }

    /**
     * Recover report from local storage and populate form fields.
     * 
     * @param {object} report All form fields of the saved report.
     */
    function recoverReport(report){

        var obj = report.reduce(function(map, el) {
            map[el.name.replace(/-/g, '_')] = el.value;
            return map;
        }, {});

        // console.dir(obj);

        // report_date: "30/05/2022"
        // report_id: ""
        // report_locality: ""
        // report_participants: (3) ['4', '2', '5']
        // report_prov: "25"
        // report_text: "<p></p>"
        // report_time_end: ""
        // report_time_start: "09:46"
        // report_title: "test"
        // report_verbalizer: "4"

        // update tab texts as the edit case
        if(obj.report_id != ''){
            $('#new-element .box-title').text('Modifica VERBALE');
            $('#btn-report-form').html(' <i class="ti-save"></i> Modifica');
        }
        // fill "new report" form fields
        $('#report-id').val(obj.report_id);

        $('#report-verbalizer').val(obj.report_verbalizer).trigger('change');
        $('#report-date').val(obj.report_date);

        if(obj.report_time_start){
            $('#report-time-start').bootstrapMaterialDatePicker('setDate', obj.report_time_start);
            $('#report-time-start').trigger('change');
        }
        if(obj.report_time_end){
            $('#report-time-end').bootstrapMaterialDatePicker('setDate', obj.report_time_end);
            $('#report-time-end').trigger('change');
        }

        $('#report-prov').val(obj.report_prov);
        $('#report-locality').val(obj.report_locality);
        $('#report-participants').val(obj.array_participants).trigger('change');
        $('#report-title').val(obj.report_title);

        $('.summernote').summernote('code', obj.report_text);
    }

    /**
     * Create html detail of the report.
     * 
     * @param {object} report All form fields of the saved report.
     * 
     * @returns The html of the report detail.
     */
    function createDetail(report){

        // calculate the meeting duration time
        var duration = moment.duration( moment(report.meet_end_time, 'HH:mm').diff( moment(report.meet_start_time, 'HH:mm') ) );
        var hours = duration.hours();
        var minutes = duration.minutes();
        var textDuration = ( (hours > 0) ? (hours+' ore ') : '' );
        textDuration += minutes+' minuti';

        console.dir(report);
        // variable for dinamically building the html
        var html = '';
        // build report detail
        html += '<div class="tab-pane p-20" id="rep'+report.meet_id+'" role="tabpanel">';
        html += '    <div class="form-body panel-report-view panel-view-mobile">';
        html +='         <div class="mobile-view m-b-5"></div>';
        html += '        <h4 class="box-title">Verbale del <strong>'+report.meet_date_format+'</strong></h4>';
        html += '        <hr class="m-t-0 m-b-20">';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Verbalizzante</label>';
        html += '            <div class="col-md-4 col-8 view-param">'+report.user_fullname+'</div>';
        html += '            <label for="date-report" class="col-md-2 col-4 col-form-label">Durata riunione</label>\n';
        html += '            <div class="col-md-4 col-8 duration">\n';
        html += textDuration;
        html += '            </div>\n';
        html += '       </div>';
        html += '       <div class="form-group row">\n';
        html += '           <label for="date-report" class="col-md-2 col-4 col-form-label">Ora inizio</label>\n';
        html += '           <div class="col-md-4 col-8">\n';
        html += moment(report.meet_start_time, 'HH:mm').format('HH:mm');
        html += '           </div>\n';
        html += '           <label for="date-report" class="col-md-2 col-4 col-form-label">Ora fine</label>\n';
        html += '           <div class="col-md-4 col-8 end-report">\n';
        html += moment(report.meet_end_time, 'HH:mm').format('HH:mm');
        html += '           </div>\n';
        html += '       </div>\n';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Provincia</label>';
        html += '            <div class="col-md-4 col-8 view-param">'+report.province_name+'</div>';
        html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Località</label>';
        html += '            <div class="col-md-4 col-8 view-param">'+report.meet_locality+'</div>';
        html += '        </div>';
        html += '        <div class="form-group row">';
        html += '            <label for="" class="control-label col-md-2 col-4 col-form-label">Partecipanti</label>';
        html += '            <div class="col-md-10 col-8 view-param">'+report.participants.join(', ')+'</div>';
        html += '        </div>';
        html += '        <h4 class="box-title">Dettagli verbale</h4>';
        html += '        <hr class="m-t-0 m-b-20">';
        html += '        <div class="form-group row">';
        html += '            <label for="date-report" class="col-md-3 col-form-label">Oggetto</label>';
        html += '            <div class="col-md-9">';
        html += '                <h3 class="m-t-0 m-b-0 title-report">'+report.meet_title+'</h3>';
        html += '                <hr class="hr-dashed m-t-15 m-b-5">';
        html += '            </div>';
        html += '        </div>';
        html += '        <div class="mobile-view m-b-5"></div>';
        html += '        <div class="form-group row">';
        html += '            <label for="date-report" class="col-md-3 col-form-label">Descrizione verbale</label>';
        html += '            <div class="col-md-9">';
        html += report.meet_desc;
        html += '            </div>';
        html += '        </div>';
        html += '        <hr class="m-t-30">';
        html += '        <div class="form-group row">';
        html += '            <div class="col-md-12">';
        html += '                <button type="button" class="btn btn-primary close-report" data-close="rep'+report.meet_id+'"> <i class="icon-close"></i> Chiudi report</button>';
        html += '            </div>';
        html += '        </div>';
        html += '    </div>';
        html += '</div>';

        return html;
    }
});
