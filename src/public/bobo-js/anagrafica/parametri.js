/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var paramActive;
    var prTyId = [];

    var editor;

    // initialize select2 plugin
    $('#parameters-type, #param-unit, #param-unit-conv').select2({});

    //datatable
    table = $('#params-table').DataTable({
        // dom: "Bfrtip",
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        lengthMenu: [25, 50, 75, 100],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        columnDefs: [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "width": "55px", "targets": 0 },
            // { "type": "datetime", "targets": 1 }
        ],
        order: [[ 1, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    /**
     * Change event on filter "Tipologia parametri"
     */
    $("#parameters-type").on( "change", function() {
        prTyId = $(this).val();
        if (prTyId.length == 0)
            // load all parameters
            loadParameters();
        else
            // parameter types chosen: load parameters by type
            loadParametersByType(prTyId);
    });

    //TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    //View element
    $('#params-table').on('click', '.show-param', function(e){
        e.preventDefault();

        // get the parameter ID stored in tr element
        var prid = parseFloat($(this).parent().parent().data("id"));

        // check if the parameter's detail is already open
        if( $('#param'+prid).length ) {
            console.log('The param\'s detail is already open');
            $('.customtab a[href="#param'+prid+'"]').tab('show');
            return;
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // load the parameter's detail
        var jqxhr = $.ajax({
            url: '/ang_parametri_get_parameter_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: prid
            },
        })
        .done(function(result) {

            // check result
            // if OK then dynamically build new tab with parameter's detail
            // else take care of error
            if(result.res == 'OK'){
                // set variables with ajax result
                var param = result.param;
                var instr = result.instr;

                // built html tab label to add to the list of nav tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#param'+param.parameter_id+'" role="tab"><span class="hidden-sm-up"><i class="mdi mdi-flask"></i></span> <span class="hidden-xs-down">'+param.parameter_name+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger param-close-view" data-close="param'+param.parameter_id+'"></i></a> </li>';
                $('.nav').append(html);

                // build new tab content
                html = '<div class="tab-pane p-20" id="param'+param.parameter_id+'" role="tabpanel">';
                html += '   <div class="form-body panel-report-view panel-view-mobile">';
                html += '       <h4 class="box-title">Visualizza dati <strong>'+param.parameter_name.toUpperCase()+'</strong></h4>';
                html += '       <hr class="m-t-0 m-b-20">';
                html += '       <h5 class="divider-title">Generali</h5>';
                html += '       <div class="form-group row">';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">Nome</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_name+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">Tipo</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_type_desc+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">ID</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_id+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">Attivo</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_active_formatted+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">Nome breve</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_shortname+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">Nome molto breve</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_extra_shortname+'</div>';
                html += '           <label for="" class="control-label col-sm-3 col-lg-2 col-4 col-form-label">ID aggiuntivo</label>';
                html += '           <div class="col-sm-3 col-lg-2 col-8 view-param mb-2">'+param.parameter_external_id+'</div>';
                html += '       </div>';
                html += '       <h5 class="divider-title">Impostazioni</h5>';
                html += '       <div class="form-group row">';
                html += '           <label for="" class="control-label col-md-2 col-4 col-form-label">Unità di misura</label>';
                html += '           <div class="col-md-2 col-8 view-param">'+param.parameter_unit+'</div>';
                html += '           <label for="" class="control-label col-md-2 col-4 col-form-label">Decimali</label>';
                html += '           <div class="col-md-2 col-8 view-param">'+param.parameter_decimals+'</div>';
                html += '           <label for="" class="control-label col-md-2 col-4 col-form-label">Unità di conversione</label>';
                html += '           <div class="col-md-2 col-8 view-param">'+param.parameter_unit_conv+'</div>';
                html += '       </div>';
                html += '       <div class="form-group row">';
                html += '           <label for="" class="control-label col-md-3 col-12 col-form-label">Oggetto JSON</label>';
                html += '           <div class="col-md-9 col-12 view-param" id="jsoneditor-'+param.parameter_id+'" style="width: 100%; height: 400px;"></div>';
                html += '       </div>';

                html += '       <div class="row">';
                html += '       <div class="col-xl-5 col-lg-12">';
                // show the list of instruments that can acquire selected parameter
                html += '       <h5 class="divider-title">Strumenti associabili</h5>';
                html += '       <div class="form-group row">';
                html += '           <div class="col-12 view-param">';
                if (instr && instr.length > 0) {
                    html += '               <table id="param-instr-table-'+param.parameter_id+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed-middle" cellspacing="0" width="100%">';
                    html += '                   <thead>\n';
                    html += '                       <tr>\n';
                    html += '                           <th class="bobo-nowrap">Strumento</th>\n';
                    html += '                           <th class="bobo-nowrap">Categoria</th>\n';
                    html += '                       </tr>\n';
                    html += '                   </thead>\n';
                    html += '                   <tbody>\n';
                    $.each(instr, function (idx, instrument) {
                        html += '                    <tr>\n';
                        html += '                        <td>' + instrument.instr_fullname + '</td>\n';
                        html += '                        <td>' + instrument.category_name + '</td>\n';
                        html += '                    </tr>\n';
                    });
                    html += '                   </tbody>\n';
                    html += '               </table>\n';
                } else {
                    html += '           <div class="col-md-9 col-8 view-param">Nessuno strumento associabile</div>';
                }
                html += '           </div>';
                html += '       </div>';
                html += '       </div>';

                html += '       <div class="col-xl-7 col-lg-12">';
                // show the list of parameters's coefficients history
                html += '       <h5 class="divider-title">Coefficienti di conversione</h5>';
                html += '       <table class="table responsive table-striped table-compressed-middle table-font-smallerform-table m-b-10 hide-filters tbl-titles width-100 tbl-with-form" id="tbl-coeff-view">';
                html += '           <thead>';
                html += '               <tr>';
                html += '                   <th>Coefficente conversione</th>';
                html += '                   <th>Data inizio</th>';
                html += '                   <th>Data fine</th>';
                html += '                   <th>Note</th>';
                html += '               </tr>';
                html += '           </thead>';
                html += '           <tbody>';

                var convs = JSON.parse(param.parameter_convs);

                if(convs ){
                    convs.forEach(function(conv){
                        html += '               <tr>';
                        html += '                   <td>'+conv.pc_conv+'</td>';
                        html += '                   <td>'+formatFulldateField(conv.pc_from_fulldate, true)+'</td>';
                        html += '                   <td>'+formatFulldateField(conv.pc_to_fulldate, false)+'</td>';
                        html += '                   <td>'+formatTextField(conv.pc_note)+'</td>';
                        html += '               </tr>'
                    });
                }
                html += '           </tbody>';
                html += '       </table>';
                html += '       </div>';

                html += '       </div>';

                html += '       <h5 class="divider-title">Annotazioni</h5>';
                html += '       <div class="form-group row">';
                html += '           <label for="" class="control-label col-md-3 col-4 col-form-label">Note</label>';
                html += '           <div class="col-md-9 col-8 view-param">'+param.parameter_note+'</div>';
                html += '       </div>';

                html += '   </div>';
                html += '   <hr class="m-t-20 m-b-10">';
                html += '   <div class="form-actions">';
                html += '       <div class="row">';
                html += '           <div class="col-md-6">';
                html += '               <div class="row">';
                html += '                   <div class="col-md-offset-3 col-md-9">';
                // show edit button only if users has the update grant
                if(update_grant){
                    html += '                       <button type="submit" class="btn btn-info" id="param-edit" data-prid="'+param.parameter_id+'"> <i class="ti-pencil"></i> Modifica</button>';
                }
                html += '                       <button type="button" class="btn btn-secondary param-close-view" data-close="param'+param.parameter_id+'">Chiudi</button>';
                html += '                   </div>';
                html += '               </div>';
                html += '           </div>';
                html += '           <div class="col-md-6"> </div>';
                html += '       </div>';
                html += '   </div>';
                html += '</div>';

                // add new tab to the main body
                $('.tab-content').append(html);

                // initialize the DataTable only if there is any instrument
                if ($('#param-instr-table-'+param.parameter_id).length) {
                    $('#param-instr-table-'+param.parameter_id).DataTable({
                        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
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
                        buttons: [],
                        order: [[0, "asc"]],
                        columnDefs: [{
                            orderable: false,
                            targets: "no-sort"
                        }]
                    });
                }

                // initialize JsonEditor
                var container = document.getElementById('jsoneditor-'+param.parameter_id);
                var options = {
                    mode: 'view',
                    modes: [],
                    search: false,
                    indentation: 4,
                    name: 'Parameter OBJ',
                    navigationBar: false,
                    language: 'it',
                    languages: jsonEditorlang
                };
                var paramViewer = new JSONEditor(container, options);
                paramViewer.set(JSON.parse(param.parameter_object));
                paramViewer.expandAll();

                // show the new tab just added
                $('.customtab a[href="#param'+param.parameter_id+'"]').tab('show');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio del parametro", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio del parametro", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    //Edit report
    $('#params-table').on('click', '.edit-param', function(e){
        e.preventDefault();

        // clear fields and change descriptions in the panel
        clearFields(validator);
        $('.customtab a[href="#new"] span:nth-child(2)').text("Modifica");
        $('#new h4').text("Modifica parametro");

        // retrieve parameter ID stored in the tr element
        var prid = parseFloat($(this).parent().parent().data("id"));
        // call function in order to retrieve parameter's information
        // and to fill fileds of the form
        getParamToEdit(prid)
    });

    /////////////////////////////////////////////////////////////////////
    //END TABLE FUNCTIONS

    // DETAIL FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Click event on button "Chiudi"
     */
    $('.card-body').on('click', '#param-edit', function(e){
        e.preventDefault();

        // clear fields and change descriptions in the panel
        clearFields(validator);
        $('.customtab a[href="#new"] span:nth-child(2)').text("Modifica");
        $('#new h4').text("Modifica parametro");

        // retrieve parameter ID from clicked button
        var prid = parseFloat($(this).data("prid"));
        // call function in order to retrieve parameter's information
        // and to fill fileds of the form
        getParamToEdit(prid);

        // close and remove the detail's tab
        $('.customtab a[href="#param' + prid + '"]').remove();
        $('.tab-content #param'+prid).remove();
    });

    /**
     * Click event on button "Chiudi"
     */
    $('.card-body').on('click', '.param-close-view', function(e){
        e.preventDefault();

        // retrieve selector of the element to be closed
        var close = $(this).data("close");

        // remove the single tab with the parameter's detail (from list and group)
        // and show the tab with the parameters list
        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#param-list"]').tab('show');
        }, 1);
    });
    /////////////////////////////////////////////////////////////////////
    // END DETAIL FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Plugins initialization
     */

    // select2
    $('#param-unit, #param-unit-conv').select2();

    // Switchery - checkbox ON/OFF
    paramActive = new Switchery($("#param-active")[0], $("#param-active").data());

    //JsonEditor
    var container = document.getElementById("jsoneditor");
    var options = {
        modes: ['tree', 'code'],
        search: false,
        indentation: 4,
        name: 'Parameter OBJ',
        navigationBar: false,
        language: 'it',
        languages: jsonEditorlang,
        schema: schemaParam,
        templates: templateParam
    };
    editor = new JSONEditor(container, options);

    /**
     * Click event on button "+ Coefficiente"
     */
    $('#add-row').on('click', function(e){
        e.preventDefault();
        // create html row and add it to table
        addRow();
        // in order to add only one coefficient at a time
        // disable button
        $('#add-row').prop('disabled', true);
    });

    /**
     * Click event on button "Elimina coefficiente"
     */
    $('#tbl-coeff').on('click', '.delete-coeff', function(e){
        e.preventDefault();
        // get row element
        var tr = $(this).parent().parent();
        // remove row
        tr.remove();
        // enable + Coefficiente button
        $('#add-row').prop('disabled', false);

        // open again the current coefficient
        $('#tbl-coeff .edit-row td[name="param-coef-end"]').text('+infinito');
    });

    // form validation
    var validator = $('#form-param-new').validate({ // initialize the plugin
        rules: {
            "param-name":{
                required: true
            },
            "param-type": {
                required: true,
                min: 0
            },
            "param-shortname": {
                required: true
            },
            "param-unit": {
                required: true
            },
            "param-dec":{
                required: true,
                min: 0
            },
            "param-coef":{
                required: true,
                dotSeparator: true
            },
            "param-unit-conv":{
                required: true
            }
        },
        messages: {
            "param-name":{
                required: "Inserire nome"
            },
            "param-type": {
                required: "Inserire tipologia parametro",
                min: "Inserire tipologia parametro"
            },
            "param-shortname": {
                required: "Inserire nome abbreviato"
            },
            "param-unit": {
                required: "Inserire unità di misura"
            },
            "param-dec":{
                required: "Inserire numero di decimali >= a 0",
                min: "Inserire numero di decimali >= a 0"
            },
            "param-coef": {
                required: "Inserire coefficiente di conversione"
            },
            "param-unit-conv":{
                required: "Inserire unità di misura valore convertito"
            }
        },
        ignore: ".jsoneditor-field, .jsoneditor-value",
        errorPlacement: function(error, element) {
            error.insertAfter(element);
        }
    });

    /**
     * Submit event
     */
    $('#form-param-new').on('submit', function (e) {
        e.preventDefault();

        // sanity check
        if (! $(this).valid()){
            swal("Attenzione", "Sono presenti dei campi incompleti o formato JSON non valido. Parametro non salvato!", "info");
            return false;
        }
        // check that user has specified at least one coefficient
        else if(
            $('#tbl-coeff tbody tr [name="param-coef"]').filter(function(){
                return $(this).val();
            }).length == 0
        ){
            swal("Attenzione", "E' necessario specificare almeno un coefficiente di conversione. Parametro non salvato!", "info");
            return false;
        }

        // validate json structure
        // based on template specified at /bobo-js/include/common/jsoneditorVariables.js
        editor.validate().then(function(err){
            if(err.length > 0){
                // warning message
                swal("Attenzione", "Formato JSON non valido. Parametro non salvato!", "info");
                return false;
            }
            else{
                // show preloader, waiting for the end of the process
                $('.inner-preloader').show();

                var form = $("#form-param-new");
                var id   = $("#param-id").val();
                var msg_err = 'Si è verificato un errore durante il salvataggio del parametro';
                var msg_ok  = 'Il parametro è stato salvato correttamente';

                // serialize form into an array and push custom variables
                var totalForm = form.serializeArray();
                // push json object
                totalForm.push({ name: "param-obj", value: JSON.stringify(editor.get()) });

                // check if a new coefficient exists
                if($('#tbl-coeff .new-row').length > 0){
                    // create an object to be sent to database with new coefficient
                    var trNew = $('#tbl-coeff .new-row');
                    var coefObj = {
                        coef: $('[name="param-coef"]', trNew).val(),
                        from: ( $('[name="param-coef-start"]', trNew).text().trim() == '-infinito' ? '' : moment().format('DD/MM/YYYY') ),
                        desc: $('[name="param-coef-desc"]', trNew).val()
                    };

                    // push new rows
                    totalForm.push({name: 'new-coef', value: JSON.stringify(coefObj) });
                }

                // check if users has edited old coefficient
                if($('#tbl-coeff .edit-row').length > 0){
                    // create an object to be sent to database with new coefficient
                    var trEdit = $('#tbl-coeff .edit-row');
                    var coefObjEdit = {
                        id  : trEdit.data('id'),
                        to  : ( $('[name="param-coef-end"]', trEdit).text().trim() == '+infinito' ? '' : moment().subtract(1, 'day').format('DD/MM/YYYY 23:59') ),
                        desc: $('[name="param-coef-desc"]', trEdit).val()
                    };

                    // push new rows
                    totalForm.push({name: 'edit-coef', value: JSON.stringify(coefObjEdit) });
                }

                // ajax call
                $.ajax({
                    type: 'post',
                    url: '/ang_parametri_put_parameter',
                    data: totalForm
                }).done(function(result) {

                    // check ajax result
                    // if 1 then success, refresh the list of parameters
                    // else if -1 then there is a problem with defined coefficient
                    // else error, something goes wrong
                    if(result == 1){
                        swal("Successo", msg_ok, "success");

                        // refresh list in main tab
                        prTyId = $("#parameters-type").val();
                        if (prTyId.length == 0){
                            // load all parameters
                            loadParameters();
                        }
                        else{
                            // parameter types chosen: load parameters by type
                            loadParametersByType(prTyId);
                        }
                        // show first tab
                        $('.customtab a[href="#param-list"]').tab('show');
                        // clear form's fields
                        clearFields();
                    }
                    else if(result == -1){
                        swal({
                            title: "Attenzione",
                            text: "Sono stati definiti più di un coefficiente su <strong>periodi temporali che si sovrappongono</strong>.",
                            type: "warning",
                            html: true
                        });
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
            }
        })
    });

    /**
     * Click event on button "Annulla"
     */
    $('#form-param-new').on('click', '#cancel-param', function(e){
        e.preventDefault();

        // close tab and clear fields of the form
        $('.customtab a[href="#param-list"]').tab('show');
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    // first load of parameters list
    loadParameters();
    // create first row in "New" form
    addRow();

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
        if(field == null || field == '')
            return '--';
        else
            return field;
    };

    /**
     * Function that formats a fulldate for bootstrap datepicker input
     *
     * @param {string} field String provided.
     * @param {boolean} startField is fulldate start range.
     *
     * @return If empty then returns 'infinito';
     *         If not empty then returns the string provided before.
     */
    function formatFulldateField(field, startField){
        if(field == null || field == '')
            return (startField ? '-' : '+')+'infinito';
        else
            return field;
    }

    /**
     * Function that clears fields of the form
     *
     * @param {string} field String provided.
     * @param {boolean} startField is fulldate start range.
     *
     * @return If empty then returns 'infinito';
     *         If not empty then returns the string provided before.
     */
    function clearFields(){

        // reset form fields
        $('#form-param-new').find("input[type=text], textarea").val("");
        $('#form-param-new select').val(-1);

        $('#param-id').val("");
        $('#param-unit, #param-unit-conv').val(0).trigger('change');
        $('#param-dec').val(0);
        $('#param-coef').val(1);

        // take care of switchery
        setSwitchery(paramActive, true);
        // take care of JSONEditor plugin
        editor.setMode('tree');
        editor.setText('{}');

        // remove all rows
        $('#tbl-coeff tbody').empty();
        $('#add-row').data('idx', 0);

        // add first empty row
        addRow();
        // disable button "+ Coefficiente"
        $('#add-row').prop('disabled', true);

        // reset form's text and title
        $('.customtab a[href="#new"] span:nth-child(2)').text("Nuovo");
        $('#new h4').text("Inserisci nuovo parametro");

        // reset form validation
        $('#form-param-new').validate().resetForm();
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
     * Function that retrieves the list of all available parameters
     * No args needed
     */
    function loadParameters(){
        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get parameters via an ajax call
        var jqxhr = $.ajax({
            url: '/ang_parametri_get_parameters',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            // check ajax result
            // if OK then fill main table with the list of parameters
            // else take care of error
            if(result.res == 'OK'){
                var params = result.params;
                // check if at least one element exists
                if( params.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    // loop through all elements
                    // for each parameter, build a html row to be added to the datable
                    $.each(params, function(index, param) {
                        var isActive = '';
                        if (param.parameter_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }
                        html += '<tr data-id="'+param.parameter_id+'" class="'+isActive+'">';
                        html += '    <td class="bobo-nowrap">';
                        html += '        <a href="javascript:void(0)" class="show-param" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-param" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        // if(delete_grant){
                        //     html += '        <a href="javascript:void(0)" class="delete-param" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        // }
                        html += '    </td>';
                        html += '    <td>'+param.parameter_id+'</td>';
                        html += '    <td>'+param.parameter_name+'</td>';
                        html += '    <td>'+param.parameter_unit+'</td>';
                        html += '    <td>'+param.parameter_conv+'</td>';
                        html += '    <td>'+param.parameter_unit_conv+'</td>';
                        html += '    <td>'+param.parameter_decimals+'</td>';
                        html += '    <td>'+param.parameter_type_desc+'</td>';
                        if (param.parameter_active){
                            html +='    <td class="hidden-lbl-icon"><i class="icon-check text-info"></i> <span>si</span></td>';
                        }
                        else{
                            html +='    <td class="hidden-lbl-icon"><i class="icon-close text-danger"></i> <span>no</span></td>';
                        }
                        html += '    <td>'+param.parameter_note+'</td>';
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
                    table.rows({page: 'all'}).every(function() { // the containers for all your galleries
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });

                } else {
                    // redraw datatable
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that retrieves the list of all available parameters for a given set of typologies
     *
     * @param {array} types Set of parameters typologies
     */
    function loadParametersByType(types){
        // reset datatable
        if ( table )
            table.clear();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get parameters via an ajax call
        var jqxhr = $.ajax({
            url: '/ang_parametri_get_parameters_by_types',
            type: "post",
            dataType: "json",
            data: {
                pr_ty_id: JSON.stringify(types)
            }
        })
        .done(function(result) {

            // check ajax result
            // if OK then fill main table with the list of parameters
            // else take care of error
            if(result.res == 'OK'){
                var params = result.params;
                // check if at least one element exists
                if( params.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    // loop through all elements
                    // for each parameter, build a html row to be added to the datable
                    $.each(params, function(index, param) {

                        html += '<tr data-id="'+param.parameter_id+'">';
                        html += '    <td class="bobo-nowrap">';
                        html += '        <a href="javascript:void(0)" class="show-param" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-param" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        }
                        // if(delete_grant){
                        //     html += '        <a href="javascript:void(0)" class="delete-param" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        // }
                        html += '    </td>';
                        html += '    <td>'+param.parameter_id+'</td>';
                        html += '    <td>'+param.parameter_name+'</td>';
                        html += '    <td>'+param.parameter_unit+'</td>';
                        html += '    <td>'+param.parameter_conv+'</td>';
                        html += '    <td>'+param.parameter_unit_conv+'</td>';
                        html += '    <td>'+param.parameter_decimals+'</td>';
                        html += '    <td>'+param.parameter_type_desc+'</td>';
                        if (param.parameter_active){
                            html +='    <td class="hidden-lbl-icon"><i class="icon-check text-info"></i> <span>si</span></td>';
                        }
                        else{
                            html +='    <td class="hidden-lbl-icon"><i class="icon-close text-danger"></i> <span>no</span></td>';
                        }
                        html += '    <td>'+param.parameter_note+'</td>';
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
                    // redraw datatable
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei parametri", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that retrieves metadata of the selected parameters
     *
     * @param {integer} prid Parameter ID
     */
    function getParamToEdit(prid){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/ang_parametri_get_parameter_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: prid
            },
        })
        .done(function(result) {

            // check result
            // if OK fill form with metadata retrieved from db
            // else take care of error
            if(result.res == 'OK'){
                var param = result.param;

                $('#param-id').val(param.parameter_id );
                $('#param-name').val(param.parameter_name );
                $('#param-type').val(param.parameter_type_id );
                $('#param-shortname').val(param.parameter_shortname == '--' ? null : param.parameter_shortname );
                $('#param-extra-shortname').val(param.parameter_extra_shortname == '--' ? null : param.parameter_extra_shortname);
                $('#param-extra-id').val(param.parameter_external_id );
                $('#param-dec').val(param.parameter_decimals );
                $('#param-coef').val(param.parameter_conv );
                $('#param-note').val(param.parameter_note );

                setSwitchery(paramActive, param.parameter_active );
                $('#param-unit').val(param.parameter_unit).trigger('change');
                $('#param-unit-conv').val(param.parameter_unit_conv).trigger('change');

                editor.set(JSON.parse(param.parameter_object));
                editor.expandAll();

                $('#tbl-coeff tbody').empty();
                $('#add-row').data('idx', 0);
                $('#add-row').prop('disabled', false);

                var convs = JSON.parse(param.parameter_convs);

                if(convs){
                    convs.forEach(function(conv){
                        addRow(conv);
                    });
                }
                // show form tab
                $('.customtab a[href="#new"]').tab('show');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio del parametro", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio del parametro", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that build a new row for parameter's coefficents
     *
     * @param {object} el JSON object of the coefficient
     */
    function addRow(el){
        // get coefficient 's index'
        var coeffIdx = parseInt($('#add-row').data('idx'));

        // build html tr element
        var html= '';
        html +='<tr class="new-row" data-idx="'+coeffIdx+'" data-id="">';
        html +='    <td class="bobo-nowrap">';
        html +='        <a class="delete-coeff" data-original-title="Elimina coefficente" data-toggle="tooltip" href="javascript:void(0)"><i class="icon-trash text-danger"></i></a>';
        html +='    </td>';
        html +='    <td><input class="form-control" type="text" value="" id="param-coef-'+coeffIdx+'" name="param-coef" placeholder="Coefficiente (separatore dec. PUNTO)"></td>';
        html +='    <td id="param-coef-start-'+coeffIdx+'" name="param-coef-start">';
        html += ( $('#tbl-coeff tbody tr').length == 0 ? '-infinito' : moment().format('DD/MM/YYYY') );
        html +='    </td>';
        html +='    <td id="param-coef-end-'+coeffIdx+'" name="param-coef-end">+infinito</td>';
        html +='    <td><textarea class="form-control" id="param-coef-desc-'+coeffIdx+'" name="param-coef-desc"></textarea></td>';
        html +='</tr>';

        // append or prepend new rows
        // depending on whether the coefficient is new or already existing
        if( el )
            $('#tbl-coeff tbody').append( html );
        else
            $('#tbl-coeff tbody').prepend( html );

        // check if is an edit action
        // fill input fields with metadata of the coefficient
        if(el){

            $('#tbl-coeff tr[data-idx="'+coeffIdx+'"]').removeClass('new-row');
            $('#tbl-coeff tr[data-idx="'+coeffIdx+'"] .delete-coeff').remove();

            $('#param-coef-'+coeffIdx).val(el.pc_conv);

            $('#param-coef-start-'+coeffIdx).text( formatFulldateField(el.pc_from_fulldate, true) );
            $('#param-coef-end-'+coeffIdx).text( formatFulldateField(el.pc_to_fulldate, false) );

            $('#param-coef-desc-'+coeffIdx).val(el.pc_note);

            $('#param-coef-'+coeffIdx).prop('disabled', true);

            // check if it is the current coefficient
            // if true modify classes and set row id
            // otherwise  disable desc field
            if(el.pc_current == true){
                $('#tbl-coeff tr[data-idx="'+coeffIdx+'"]').addClass('edit-row');
                $('#tbl-coeff tr[data-idx="'+coeffIdx+'"]').data('id', el.pc_id);
            }
            else{
                $('#param-coef-desc-'+coeffIdx).prop('disabled', true);
            }
        }
        else{
            // close the current coefficient
            $('#tbl-coeff .edit-row td[name="param-coef-end"]').text(moment().subtract(1, 'day').format('DD/MM/YYYY'));
        }

        // increase the index by 1 and store it in the add button
        coeffIdx++;
        $('#add-row').data('idx', coeffIdx);
    }

});

