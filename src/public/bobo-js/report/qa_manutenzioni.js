/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;

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

    $("#networks, #provinces").select2();
    $("#stations").select2({
        matcher: searchGroupedSelect2
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
                    }
                    else{
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

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    /**
     * Filters change events
     */
    $( "#networks, #provinces" ).on( "change", function() {
        console.log('change net');

        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        var net = $('#networks').val();
        var prid = $('#provinces').val();
        var dest = $('#provinces').data('change');
        // refresh stations list
        loadStations(net, prid, dest);
    });

    $( "#stations" ).on( "change", function() {

        var stid = $(this).val();
        // refresh reports list in the first tab
        loadReports(dateFrom,dateTo, stid);
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
        clearForm();
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // recover report detail via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_selected_report',
            type: "post",
            dataType: "json",
            data: {
                id: rpid
            },
        })
        .done(function(result) {
            console.dir(result);

            // check result
            if(result.res == 'OK'){
                // fill fields of the form with metadata arriving from database
                var report = result.report;
                var operations   = result.operations;
                var miOperations = result.mi_operations;

                // ma_id: 12
                // maintenance_fulldate: "2021-02-09 12:13:00"
                // maintenance_fulldate_formatted: "09-02-2021 12:13"
                // maintenance_note: "Prova"
                // province_id: 1
                // province_name: "Aosta"
                // station_id: 1000
                // station_name: "Stazione UNO"
                // us_id: 4
                // user_avatar: null
                // user_avatar_thumb: "/bobo-img/default/avatar/000004/file-20210209112808-08534.jpg"
                // user_fullname: "Utente UNO"

                $('#maintenance-id').val(report.ma_id);
                // manage date
                $('#maintenance-datetime').val("");
                $('#maintenance-datetime').bootstrapMaterialDatePicker('setDate', report.maintenance_fulldate_formatted);

                $('#maintenance-prov').val(report.province_id).trigger('change', report.station_id);
                $('#maintenance-note').val(report.maintenance_note);

                // check if there is at least one operation
                if(operations.length > 0){
                    // loop through operations and build an editable tr element
                    $.each(operations, function(index, ope){

                        // calib_fulldate: ""
                        // calib_id: null
                        // calib_multipoint: null
                        // calib_note: ""
                        // calib_user_avatar_thumb: ""
                        // calib_user_fullname: ""
                        // calib_values: null
                        // category_id: 1
                        // category_name: "Categoria UNO"
                        // freq_id: 4
                        // frequency_db: "3 mons"
                        // frequency_desc: "Trimestrale"
                        // frequency_label: "3m"
                        // in_op_id: 20
                        // instr_arpa_id: "OPAS00010"
                        // instr_id: 3
                        // instr_name: "Nome strumento UNO"
                        // instr_serial_num: "1200010"
                        // instr_type_fullname: "Strumento UNO"
                        // instr_type_id: 4
                        // ma_op_id: 13
                        // main_operation_filters_exp: "28-02-2021"
                        // main_operation_note: ""
                        // op_ca_id: 4
                        // op_id: 20
                        // operation_category_desc: "Strumento"
                        // operation_description: "Operazione UNO"

                        var row;
                        row += '<tr>';
                        row += '    <td>';
                        row += '        <a href="javascript:void(0)" class="delete-single-operation" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        row += '    </td>';
                        var instrName = ope.instr_type_fullname;

                        if(ope.instr_name != '')
                            instrName += ' - '+ope.instr_name;

                        if(ope.instr_arpa_id != '')
                            instrName = instrName+' ['+ope.instr_arpa_id+']';

                        row += '    <td data-id="'+ope.instr_id+'">'+instrName+'</td>';
                        row += '    <td data-id="'+ope.in_op_id+'">'+ope.operation_description+'</td>';
                        // row += '    <td>'+ope.frequency_desc+'</td>';
                        row += '    <td>';
                        row += '        <select class="custom-select maintenance-calib" name="maintenance-calib-'+ope.op_id+'" disabled>';
                        if(ope.calib_id == null){
                            row += '            <option value="-1">Seleziona taratura...</option>';
                        }else{
                            row += '            <option value="'+ope.calib_id+'">'+ope.calib_fulldate+' - '+ope.calib_user_fullname+'</option>';
                        }
                        row += '        </select>';
                        row += '    </td>';
                        row += '    <td>';
                        row += '        <div class="input-group">';
                        row += '            <input type="text" class="form-control maintenance-filter-expire" name="maintenance-filter-expire-'+ope.op_id+'" placeholder="mm/dd/yyyy" value="'+ope.main_operation_filters_exp+'" disabled>';
                        row += '            <div class="input-group-append">';
                        row += '                <span class="input-group-text"><i class="icon-calender"></i></span>';
                        row += '            </div>';
                        row += '        </div>';
                        row += '    </td>';
                        row += '    <td>';
                        row += '        <textarea class="form-control maintenance-instr-note" name="maintenance-instr-note-'+ope.op_id+'" rows="1" oninput=\'this.style.height = "";this.style.height = this.scrollHeight + "px"\' disabled>'+ope.main_operation_note+'</textarea>';
                        row += '    </td>';
                        row += '</tr>';

                        $('#operations-table tbody').append(row);
                    });

                    $('#oprs-insert').show();
                }

                // check if there is at least one operation
                if(miOperations.length > 0){
                    // loop through operations and build an editable tr element
                    $.each(miOperations, function(idx, el){

                        var row;
                        row += '<tr>';
                        row += '    <td>';
                        row += '        <a href="javascript:void(0)" class="delete-single-operation-mi" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        row += '    </td>';
                        row += '    <td data-id="'+el.mi_id+'">'+el.miscellany_fullname+'</td>';
                        row += '    <td data-id="'+el.mi_op_id+'">'+el.mi_op_desc+'</td>';
                        row += '    <td><textarea class="form-control maintenance-mi-note" name="maintenance-mi-note-'+el.mi_op_id+'" rows="1">'+el.mami_op_note+'</textarea></td>';
                        row += '</tr>';

                        // append rows to the table
                        $('#operations-mi-table tbody').append(row);
                        // reset operations select2
                    });

                    // show operations container
                    $('#oprs-insert-mi').show();
                }

                // after 5 ms trigger input event in order to resize rows
                setTimeout(function(){
                    $('#operations-table tbody textarea').trigger('input');
                }, 5);

                // modify 'Nuovo' text in 'Modifica'
                $('#new .box-title').text('Modifica MANUTENZIONE');
                $('#inner-new-report').text('Modifica');
                $('#save-report').html(' <i class="ti-save"></i> Modifica report');

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
        var url = "/rep_qa_manutenzioni_get_pdf";

        /*http://johnculviner.com/category/jquery-file-download/*/
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

        //this is critical to stop the click event which will trigger a normal file download!
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
                url: '/rep_qa_manutenzioni_del_report',
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
                    swal("Report eliminato", "Il report è stato eliminato con successo!", "success");
                    table.row($("tr[data-id='"+rpid+"']")).remove().draw();
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
    // hide container for operations
    $('#oprs-insert, #oprs-insert-mi').hide();

    /**
     * New maintenance insertion datetime.
     */
    $('#maintenance-datetime').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('open', function(){
        $('#maintenance-datetime').bootstrapMaterialDatePicker('setMaxDate', moment().format('DD/MM/YYYY HH:mm'));
    });
    // set default datetime
    $('#maintenance-datetime').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));

    // select2 initializations
    $("#maintenance-stat").select2({
        matcher: searchGroupedSelect2
    });
    $("#maintenance-prov, #maintenance-instrument, #maintenance-operation, #maintenance-miscellany, #maintenance-operation-mi" ).select2();

    /**
     * New maintenance province selection.
     */
    $( "#maintenance-prov" ).on( "change", function(e, stid) {
        // retrieve province id and station select id
        var prid = $(this).val();
        var dest = $(this).data('change');
        // refresh stations list
        // if prid equal to -1 then load all stations
        loadStations(-1, prid, dest, stid);
    });

    /**
     * New maintenance station selection.
     */
    $( "#maintenance-stat" ).on( "change", function() {
        // retrieve station id and report fulldate
        var stid = parseInt($(this).val());
        var dt = $('#maintenance-datetime').val();

        // if stid equal to -1 reset instruments
        // else load instruments linked to station at the time of maintenance and fill select element
        if(stid == -1){
            $('#maintenance-instrument').empty();
            $('#maintenance-instrument').append('<option value="-1">Seleziona strumento...</option>');

            $('#maintenance-miscellany').empty();
            $('#maintenance-miscellany').append('<option value="-1">Seleziona dotazione...</option>');
        }
        else{
            loadInstruments(stid, dt);
            loadMiscellanies(stid, dt);
        }
    });

    /**
     * New maintenance instrument selection.
     */
    $( "#maintenance-instrument" ).on("change", function() {
        // retrieve instrument id and its category
        var instrid = parseInt($(this).val());
        var catid = parseInt($("#maintenance-instrument option:selected").data('ctid'));

        // reset select element
        $('#maintenance-operation').empty();
        // if instr id not equal to -1 then load all associated operations
        if (instrid != -1){
            loadOperations(instrid, catid);
        }
    });

    /**
     * Validate operations form.
     */
    var validOprs = $('#maintenance-operations-form').validate({ // initialize the plugin
        rules: {
            "maintenance-instrument" : {
                required: true,
                min: 0
            },
            "maintenance-operation[]" : {
                required: true,
                // minlength: 1
            }
        },
        messages: {
            "maintenance-instrument" : {
                required: "Selezionare strumento",
                min: "Selezionare strumento"
            },
            "maintenance-operation[]" : {
                required: "Selezionare almeno una operazione",
                // minlength: "Selezionare almeno una operazione"
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
     * Add operations submit form: click on green button 'Aggiungi'
     */
    $('#maintenance-operations-form').on('submit', function (e) {
        e.preventDefault();
        // check if all form fields are valid
        if (! $(this).valid() ){
            swal("Attenzione", "Compilare i campi obbligatori per aggiungere una operazione", "info");
            return false;
        };

        // get name of selected instrument
        var strum   = $( "#maintenance-instrument option:selected" ).text();
        // get instrument id
        var strumid = $( "#maintenance-instrument" ).val();
        // get selected perations id
        var operid  = $( "#maintenance-operation" ).val();
        // get station and report fulldate
        var stid = parseInt($('#maintenance-stat').val());
        var dt = $('#maintenance-datetime').val();

        // for selected instrument get all reports calibration created before the maintenance
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_calibrations',
            type: "post",
            dataType: "json",
            data: {
                stid : stid,
                instr: strumid,
                dt   : moment(dt, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
            },
        })
        .done(function(result) {

            // check result
            if(result.res == 'OK'){
                var calibrations = result.calibrations;
                // loop through operations and build an editable tr element
                $.each(operid, function(index, ope){

                    var lbl = $("#maintenance-operation option[value='"+ope+"']").text();

                    var row;
                    row += '<tr>';
                    row += '    <td>';
                    row += '        <a href="javascript:void(0)" class="delete-single-operation" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                    row += '    </td>';
                    row += '    <td data-id="'+strumid+'">'+strum+'</td>';
                    row += '    <td data-id="'+ope+'">'+lbl+'</td>';
                    // row += '    <td>'+freq+'</td>';
                    row += '    <td>';
                    row += '        <select class="custom-select maintenance-calib" name="maintenance-calib-'+ope+'">';
                    row += '            <option value="-1">Seleziona taratura...</option>';
                    // foreach calibration retrieved from the db build an option element
                    $.each(calibrations, function(index, calibration){
                        row += '<option value="'+ calibration.calib_id+'">'+calibration.user_fullname+' - '+calibration.instr_type_fullname+' (del '+calibration.calib_fulldate+')</option>';
                    });

                    row += '        </select>';
                    row += '    </td>';
                    row += '    <td>';
                    row += '        <div class="input-group">';
                    row += '            <input type="text" class="form-control maintenance-filter-expire" name="maintenance-filter-expire-'+ope+'" placeholder="mm/dd/yyyy">';
                    row += '            <div class="input-group-append">';
                    row += '                <span class="input-group-text"><i class="icon-calender"></i></span>';
                    row += '            </div>';
                    row += '        </div>';
                    row += '    </td>';
                    row += '    <td>';
                    row += '        <textarea class="form-control maintenance-instr-note" name="maintenance-instr-note-'+ope+'" rows="1"  oninput=\'this.style.height = "";this.style.height = this.scrollHeight + "px"\' ></textarea>';
                    row += '    </td>';
                    row += '</tr>';

                    // append rows to the table
                    $('#operations-table tbody').append(row);
                    // reset operations select2
                    $( "#maintenance-operation" ).val([]);
                    $( "#maintenance-operation" ).trigger('change');

                });

                // for each row initialize bootstrap datepicker
                $('.maintenance-filter-expire').bootstrapMaterialDatePicker({
                    minDate: moment().format("DD/MM/YYYY"),
                    format: 'DD/MM/YYYY',
                    lang : 'it',
                    cancelText : 'Annulla',
                    time: false
                });

                // show operations container
                $('#oprs-insert').show();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle operazioni", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle tarature", "error");
        });

    });

    /**
     * Delete all operations.
     */
    $('.tab-content').on('click', '#delete-operations', function(e){
        e.preventDefault();

        // show confirm message before proceeding in deleting all operations
        swal({
            title: "Eliminare TUTTE le operazioni su STRUMENTI",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // hide operations container
            $('#oprs-insert').hide();
            // empty the table
            $('#operations-table tbody').empty();
            // show success message
            swal("Operazioni su strumenti eliminate", "Le operazioni sono state eliminate con successo!", "success");
            // reset operations select2
            $( "#maintenance-operation" ).val([]);
            $( "#maintenance-operation" ).trigger('change');

        });
    });

    /**
     * Delete single operation.
     */
    $('#operations-table').on('click', '.delete-single-operation', function(e){
        e.preventDefault();

        // get row element
        var del = $(this).parent().parent();
        // show confirm message before proceeding in deleting the operation
        swal({
            title: "Eliminare operazione su strumento selezionata",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            // remove row fro the table
            del.remove();
            // show success message
            swal("Operazione su strumento", "Eliminata con successo!", "success");
        });
    });

    /**
     * Validate operations form.
     */
    var validMiOprs = $('#maintenance-miscellanies-form').validate({ // initialize the plugin
        rules: {
            "maintenance-miscellany" : {
                required: true,
                min: 0
            },
            "maintenance-operation-mi[]" : {
                required: true,
                // minlength: 1
            }
        },
        messages: {
            "maintenance-miscellany" : {
                required: "Selezionare dotazione",
                min: "Selezionare dotazione"
            },
            "maintenance-operation-mi[]" : {
                required: "Selezionare almeno una operazione",
                // minlength: "Selezionare almeno una operazione"
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
     * Add miscellanies operations submit form: click on green button 'Aggiungi'
     */
    $('#maintenance-miscellanies-form').on('submit', function (e) {
        e.preventDefault();
        // check if all form fields are valid
        if (! $(this).valid() ){
            swal("Attenzione", "Compilare i campi obbligatori per aggiungere una operazione", "info");
            return false;
        };

        // get name of selected miscellany
        var miscellany   = $( "#maintenance-miscellany option:selected" ).text();
        // get miscellany id
        var miid = $( "#maintenance-miscellany" ).val();
        // get selected perations id
        var opIds  = $( "#maintenance-operation-mi" ).val();

        // loop through operations and build an editable tr element
        $.each(opIds, function(idx, opid){

            var lbl = $("#maintenance-operation-mi option[value='"+opid+"']").text();

            var row;
            row += '<tr>';
            row += '    <td>';
            row += '        <a href="javascript:void(0)" class="delete-single-operation-mi" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
            row += '    </td>';
            row += '    <td data-id="'+miid+'">'+miscellany+'</td>';
            row += '    <td data-id="'+opid+'">'+lbl+'</td>';
            row += '    <td><textarea class="form-control maintenance-mi-note" name="maintenance-mi-note-'+opid+'" rows="1"></textarea></td>';
            row += '</tr>';

            // append rows to the table
            $('#operations-mi-table tbody').append(row);
            // reset operations select2
            $( "#maintenance-operation-mi" ).val([]);
            $( "#maintenance-operation-mi" ).trigger('change');

        });

        // show operations container
        $('#oprs-insert-mi').show();
    });

    /**
     * Delete all miscellanies operations.
     */
    $('.tab-content').on('click', '#delete-operations-mi', function(e){
        e.preventDefault();

        // show confirm message before proceeding in deleting all operations
        swal({
            title: "Eliminare TUTTE le operazioni su DOTAZIONI",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // hide operations container
            $('#oprs-insert-mi').hide();
            // empty the table
            $('#operations-mi-table tbody').empty();
            // show success message
            swal("Operazioni su dotazioni eliminate", "Le operazioni sono state eliminate con successo!", "success");
            // reset operations select2
            $( "#maintenance-operation-mi" ).val([]);
            $( "#maintenance-operation-mi" ).trigger('change');

        });
    });

    /**
     * Delete all miscellanies single operation.
     */
    $('#operations-mi-table').on('click', '.delete-single-operation-mi', function(e){
        e.preventDefault();

        // get row element
        var del = $(this).parent().parent();
        // show confirm message before proceeding in deleting the operation
        swal({
            title: "Eliminare operazione su dotazione selezionata",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            // remove row from the table
            del.remove();
            // show success message
            swal("Operazione su dotazione", "Eliminata con successo!", "success");
        });
    });

    /**
     * Validate form.
     */
    var validator = $('#maintenance-form').validate({ // initialize the plugin
        rules: {
            "maintenance-datetime" : {
                required: true
            },
            "maintenance-stat" : {
                required: true,
                min: 0
            }
        },
        messages: {
            "maintenance-datetime" : {
                required: "Inserire data"
            },
            "maintenance-stat" : {
                required: "Selezionare stazione",
                min: "Selezionare stazione"
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
     * Submit maintenance new/edit form.
     */
    $('#maintenance-closure-form').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if (! $('#maintenance-form').valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare report", "info");
            return false;
        };

        var opArray = [];
        // create an object to be sent to database with all operations
        $('#operations-table tr').each(function(i){
            if(i == 0)
            return;

            var opObj = {
                instrid: parseInt($("td:nth-child(2)", this).data("id")),
                opid: parseInt($("td:nth-child(3)", this).data("id")),
                calibid: parseInt($("td:nth-child(4) select", this).val()),
                expdate: $("td:nth-child(5) input[type=text]", this).val(),
                note: $("td:nth-child(6) textarea", this).val()
            };

            opArray.push(opObj);
        });

        var miOpArray = [];
        // create an object to be sent to database with all operations
        $('#operations-mi-table tr').each(function(i){
            if(i == 0)
            return;

            var opObj = {
                miid: parseInt($("td:nth-child(2)", this).data("id")),
                opid: parseInt($("td:nth-child(3)", this).data("id")),
                note: $("td:nth-child(4) textarea", this).val()
            };

            miOpArray.push(opObj);
        });

        // searialize form and add to id the operations object and extra fields
        var formMain = $("#maintenance-form").serializeArray();
        var notes    = $("#maintenance-closure-form #maintenance-note").val();
        var id       = $("#maintenance-id").val();

        formMain.push({ name: "maintenance-operations" , value: JSON.stringify(opArray) });
        formMain.push({ name: "miscellanies-operations", value: JSON.stringify(miOpArray) });
        formMain.push({ name: "maintenance-note", value: notes });

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

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // ajax call
        $.ajax({
            type: 'post',
            url: '/rep_qa_manutenzioni_put_report',
            data: formMain
        }).done(function(result) {
            // check result
                //  - if true then success, reload the list in the first tab, show the table and reset form
                //  - if false then error
            if(result){
                swal("Successo", msg_ok, "success");

                var stid  = $( "#stations" ).val();
                // refresh reports list in the first tab
                loadReports(dateFrom, dateTo, stid);
                // show first tab
                $('.customtab a[href="#report-list"]').tab('show');
                // reset form
                clearForm();
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
    $('#cancel-report').on('click', function(e) {
        e.preventDefault();

        // show report table and reset form
        $('.customtab a[href="#report-list"]').tab('show');
        clearForm();
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
     * Select option -1 and load all stations and reports
     */
    $( "#networks, #maintenance-prov" ).trigger("change");

    // if id is defined then automatically load report detail
    if(rpid != null && rpid != ''){
        console.log('rpid from server');
        createReportDetail(rpid);
    }

    /**
     * Function that clears ad resets all form's fields.
     */
    function clearForm(){
        // clear all form fields
        $('#maintenance-id').val('');
        $('#maintenance-note').val('');
        // manage bootstrap datetime picker
        $('#maintenance-datetime').val('');
        $('#maintenance-datetime').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        // reset province and loadd all stations
        $('#maintenance-prov').val(-1);
        $('#maintenance-prov').trigger('change');

        // empty operations table and hide it
        $('#operations-table tbody').empty();
        $('#oprs-insert').hide();

        // empty operations table and hide it
        $('#operations-mi-table tbody').empty();
        $('#oprs-insert-mi').hide();

        // reset form texts
        $('#new .box-title').text('Inserisci nuova MANUTENZIONE');
        $('#inner-new-report').text('Nuovo');
        $('#save-report').html(' <i class="ti-save"></i> Inserisci report');

        // reset form validation
        $('#maintenance-form').validate().resetForm();
        $('#maintenance-operations-form').validate().resetForm();
    };

    // LOADS

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} stid Station ID, if provided.
     */
    function loadStations(net, prid, dest, stid){

        // load stations via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_stations',
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
                    $('#'+dest).val(stid).trigger('change');
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
     */
    function loadInstruments(stid, dt){

        // load instruments via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_instruments',
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
                $('#maintenance-instrument').empty();
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
                $('#maintenance-instrument').append('<option value="-1">Seleziona strumento...</option>');
                $('#maintenance-instrument').append(opts);
                // trigger change event in order to reset operations select
                $('#maintenance-instrument').val(-1).trigger('change');

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
     * Function that retrieves the miscellanies of a given station.
     *
     * @param {integer} stid Station ID.
     * @param {date}    dt Date of allocation.
     */
    function loadMiscellanies(stid, dt){

        // load instruments via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_miscellanies',
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
                $('#maintenance-miscellany').empty();
                var miscellanies = result.miscellanies;

                // variable for dinamically building the html
                var opts = '';
                // loop through all elements
                // for each miscellany, build a html option to be added to the select
                $.each(miscellanies, function(idx, el){

                    opts += '<option value="'+el.mi_id+'">'+el.miscellany_fullname+'</option>';
                });

                // append options
                $('#maintenance-miscellany').append('<option value="-1">Seleziona dotazione...</option>');
                $('#maintenance-miscellany').append(opts);
                // trigger change event in order to reset operations select
                $('#maintenance-miscellany').val(-1).trigger('change');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle dotazioni", "error");
            }


        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle dotazioni", "error");
        });
    };

    /**
     * Function that retrieves the operations associated to a given instrument of a given category.
     *
     * @param {integer} intrid Instrument ID.
     * @param {integer} catid Category ID.
     */
    function loadOperations(intrid, catid){

        // load operations via an ajax call
        var jqxhr = $.ajax({
            url: '/rep_qa_manutenzioni_get_operations',
            type: "post",
            dataType: "json",
            data: {
                instr: intrid,
                cat: catid
            },
        })
        .done(function(result) {

            console.dir(result);
            // check if result is 'OK'
            if(result.res == 'OK'){

                var operations = result.operations;
                // loop through all elements
                // for each operation, build a html option to be added to the select
                var opts = '';
                $.each(operations, function(index, operation){
                    opts += '<option value="'+ operation.in_op_id+'" data-freq="'+operation.frequency_desc+'">'+operation.operation_description+'</option>';
                });
                // append options
                $('#maintenance-operation').append(opts);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle operazioni", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle operazioni", "error");
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

        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
        url: '/rep_qa_manutenzioni_get_reports',
        type: "post",
        dataType: "json",
        data: {
            from    : dateFrom,
            to      : dateTo,
            net     : net,
            prid    : prid,
            stid    : stid
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

                    html +='<tr data-id="'+value.ma_id+'">';
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
                    html +='    <td>'+getFormattedDateDT(value.maintenance_fulldate, 'basic_timeStartMin')+'</td>';
                    html +='    <td class="bobo-nowrap operators">';
                    html +='        <img src="'+value.user_avatar_thumb+'">';
                    html +='        '+value.user_fullname;
                    html +='    </td>';
                    html +='    <td>'+value.network_name+'</td>';
                    html +='    <td>'+value.station_name+'</td>';
                    html +='    <td>'+value.maintenance_note+'</td>';
                    if(value.maintenance_operation_flag)
                        html +='    <td><i class="icon-check text-info"></i></td>';
                    else
                        html +='    <td></td>';

                    if(value.miscellanies_operation_flag)
                        html +='    <td><i class="icon-check text-info"></i></td>';
                    else
                        html +='    <td></td>';

                    if(value.maintenance_calib_flag)
                        html +='    <td><i class="icon-check text-info"></i></td>';
                    else
                        html +='    <td></td>';

                    html += '    <td></td>';
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
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei report manutenzione", "error");
            // redraw it
            table.draw();
        });

        return;
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
            url: '/rep_qa_manutenzioni_get_selected_report',
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
                var operations = result.operations;
                var miOperations = result.mi_operations;

                // add link for the new tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#rep'+rpid+'" role="tab"><span class="hidden-sm-up"><i class="fa fa-file-text-o"></i></span> <span class="hidden-xs-down">'+report.maintenance_fulldate_formatted+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-report" data-close="rep'+rpid+'"></i></a></li>';
                $('.nav').append(html);

                // variable for dinamically building the html
                html = '';
                html +='<div class="tab-pane p-20" id="rep'+rpid+'" role="tabpanel">';
                html +='    <div class="form-body panel-report-view panel-view-mobile">';
                html +='        <h4 class="box-title">Report del <strong>'+report.maintenance_fulldate_formatted+'</strong></h4>';
                html +='        <hr class="m-t-0 m-b-20">';
                html +='        <div class="form-group row">';
                html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Operatore</label>';
                html +='            <div class="col-8 col-md-4 view-param">'+report.user_fullname+'</div>';
                html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Provincia</label>';
                html +='            <div class="col-8 col-md-4 view-param">'+report.province_name+'</div>';
                html +='        </div>';
                html +='        <div class="form-group row">';
                html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Stazione</label>';
                html +='            <div class="col-8 col-md-4 view-param">'+report.station_name+'</div>';
                html +='            <label for="" class="control-label col-4 col-md-2 col-form-label">Note generali</label>';
                html +='            <div class="col-8 col-md-4 view-param">'+report.maintenance_note+'</div>';
                html +='        </div>';
                // check if there is at least one operation
                // if true then build the table
                if(operations.length != 0){
                    html +='        <hr class="m-t-20 m-b-10">';
                    html +='        <h4 class="box-title p-t-10">Operazioni inserite <strong>su strumenti</strong></h4>';
                    html +='        <div class="table-responsive">';
                    html +='            <table class="table table-striped table-font-smaller" id="view-operation">';
                    html +='                <thead>';
                    html +='                    <tr>';
                    html +='                        <th>Strumento</th>';
                    html +='                        <th>Operazione</th>';
                    html +='                        <th>Taratura</th>';
                    html +='                        <th>Scad. filtri</th>';
                    html +='                        <th>Note</th>';
                    html +='                    </tr>';
                    html +='                </thead>';
                    html +='                <tbody>';
                    // loop through operations and create a tr element
                    $.each(operations, function(index, obj){
                        html +='                    <tr>';

                        var instrName = obj.instr_type_fullname;

                        if(obj.instr_name != '')
                            instrName += ' - '+obj.instr_name;

                        if(obj.instr_arpa_id != '')
                            instrName = instrName+' ['+obj.instr_arpa_id+']';

                        html +='                        <td>'+instrName+'</td>';
                        html +='                        <td>'+obj.operation_description+'</td>';
                        // html +='                        <td>'+obj.frequency_desc+'</td>';
                        if(obj.calib_id)
                            html +='                        <td><a href="/rep_qa_tarature/'+obj.calib_id+'" target="_blank"><strong>Taratura del '+obj.calib_fulldate+'</strong></a> - '+obj.calib_user_fullname+'</td>';
                        else
                            html +='                        <td>--</a></td>';

                        html +='                        <td>'+obj.main_operation_filters_exp+'</td>';
                        html +='                        <td>'+obj.main_operation_note+'</td>';
                        html +='                    </tr>';
                    });

                    html +='                </tbody>';
                    html +='            </table>';
                    html +='        </div>';
                };


                // check if there is at least one operation
                // if true then build the table
                if(miOperations.length != 0){
                    html +='        <hr class="m-t-20 m-b-10">';
                    html +='        <h4 class="box-title p-t-10">Operazioni inserite <strong>su dotazioni</strong></h4>';
                    html +='        <div class="table-responsive">';
                    html +='            <table class="table table-striped table-font-smaller" id="view-operation-eq">';
                    html +='                <thead>';
                    html +='                    <tr>';
                    html +='                        <th>Dotazione</th>';
                    html +='                        <th>Operazione</th>';
                    html +='                        <th>Note</th>';
                    html +='                    </tr>';
                    html +='                </thead>';
                    html +='                <tbody>';
                    // loop through operations and create a tr element
                    $.each(miOperations, function(idx, el){
                        html +='                    <tr>';
                        html +='                        <td>'+el.miscellany_fullname+'</td>';
                        html +='                        <td>'+el.mi_op_desc+'</td>';
                        html +='                        <td>'+el.mami_op_note+'</td>';
                        html +='                    </tr>';
                    });

                    html +='                </tbody>';
                    html +='            </table>';
                    html +='        </div>';
                }

                html +='        <hr class="m-t-30">';
                html +='        <div class="form-group row">';
                html +='            <div class="col-12">';
                html +='                <button type="button" class="btn btn-primary close-report" data-close="rep'+rpid+'"> <i class="icon-close"></i> Chiudi report</button>';
                html +='            </div>';
                html +='        </div>';
                html +='    </div>';
                html +='</div>';

                // append new html to main content
                $('.tab-content').append(html);
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
            swal("Errore!", "Errore durante il recupero del dettaglio del report", "error");

        });
    };

    /**
     * Function that downloads the maintenence's total pdf of a given network and, if provieded, of a given station.
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
        var url = "/rep_qa_manutenzioni_get_total_pdf";

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
                swal("Errore!", "Il file pdf non è stato creato oppure errore durante lo scarico", "error");
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            }
        });

        console.log('End download');
        //this is critical to stop the click event which will trigger a normal file download!
        return false;
    };
});

