/**
 * Document ready.
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var new_subgroup_groups;

    var tblAbn;
    var tblAbnSt;

    var stpr_id;

    // add method to validate plugin
    $.validator.addMethod("maxSelection", function (value, element) {
        var count = $(element).find('option:selected').length;
        return count <= 15;
    });

    /*
     * Show different tab event
    */
    $('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
        // reize window
        $(window).trigger('resize');
    });

    ////// Attenzione TAB - sottogruppi - START //////
{
    // selec2 initialization
    $("#networks, #provinces").select2();
    new_subgroup_groups = $("#subgroup-groups").select2();

    // boostraptoggle
    $( "#subgroup-public" ).bootstrapToggle();

    // initialize jstree
    initializeLeftTree();

    // multiselect initialization
    $('#multiselect1').multiselect({
        right: '#subgroup-stat',
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

    $('#multiselect2').multiselect({
        right: '#subgroup-vis',
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

    // hide the preloader by default
    $('.preloader, #subgroup-detail, #subgroup-save').hide();

    /*
     * Change event on "public" checkbox
    */
    $("#subgroup-public").on("change", function(e){
        e.preventDefault();
        var state = $(this).prop('checked')

        // if the subgroup becomes public Idisable the association of user groups
        if(state){
            new_subgroup_groups.val([]); // Select the option with a value of '1'
            new_subgroup_groups.trigger('change'); // Notify any JS components that the value changed
            $('#subgroup-groups').prop("disabled", true);
        }
        else{
            $('#subgroup-groups').prop("disabled", false);
        }
    });

    // validate plugin
    $('#subgroup-config').validate({ // initialize the plugin
        rules: {
            "subgroup-name" : {
                required: true
            },
            "subgroup-groups" :{
                required: ! $("#subgroup-public").prop('checked')
            }
        },
        messages: {
            "subgroup-name" : {
                required: "Inserire nome sottogruppo"
            },
            "subgroup-groups" :{
                required: "Inserire gruppi"
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

    /*
     * Submit event
    */
    $('#subgroup-config').on('submit', function (e) {
        e.preventDefault();

        // check if form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile generare questo elemento", "info");
            return false;
        };

        // get empty flag
        var empty = $('#subgroup-fill').val();

        // If the structure has already been initialized, ask for confirmation
        if (empty != ''){
            swal({
                title: "Attenzione, sottogruppo già generato",
                text: "Sei proprio sicuro di voler proseguire con una nuova generazione? in caso affermativo tutto quanto compilato finora verrà eliminato.",
                type: "warning",
                showCancelButton: true,
                confirmButtonText: "Si, rigenera",
                closeOnConfirm: true,
                cancelButtonText: "Annulla"
            }, function () {

                $('#subgroup-fill').val('');
                // show div
                $('#subgroup-detail, #subgroup-save').show();

            });
        }
        else{
            // show div
            $('#subgroup-detail, #subgroup-save').show();
        }
    });

    /*
     * Change event on selects
    */
    $("#networks, #provinces").on('change', function(){
        var nets = $("#networks").val();
        var prid = $("#provinces").val();
        // refresh stations
        loadStationsByNetworks(prid, nets);
    });

    /*
     * Click event on "Save" button
    */
    $('#subgroup-add').on('click', function(e){
        e.preventDefault();

        // get options in right column and set attribute "selected" to true
        $('#subgroup-stat').find('option').prop('selected', true);
        // get selected stations
        var params = $( '#subgroup-stat').val();

        // check that selected stations are between 1 and 15
        if(params.length == 0 || params.length > 15){
            swal("Attenzione", "Selezionare almeno una stazione fino a un massimo di 15!", "info");
            return false;
        }

        // get options in right column and set attribute "selected" to true
        $('#subgroup-vis').find('option').prop('selected', true);

         // retrieve array of data sent via POST and add dateFrom and dateTo
        var fstForm = $('#subgroup-config').serializeArray();
        var sndForm = $('#subgroup-detail').serializeArray();

        var totalForm = fstForm.concat(sndForm);

        var obj = {};
        // build object to be sent to server
        $.each(totalForm, function () {
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

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_put_subgroup',
            type: "post",
            dataType: "json",
            data: {
                params: JSON.stringify(obj)
            }
        })
        .done(function(result) {

            // check result
            if(result){
                // refresh jstree
                $('#group-json').jstree(true).refresh(true);
                $('#subgroup-detail, #subgroup-save').hide();

                // clear form
                clearAll();
                // success message
                swal('Successo!', 'Il sottogruppo è stato salvato correttamente!', 'success');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il salvataggio", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il salvataggio", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    /*
     * Click event on "Cancel" button
    */
    $('#subgroup-cancel').on('click', function(e){
        e.preventDefault();

        // get empty flag
        var empty = $('#subgroup-fill').val();

        // if not null then ask for confimation
        if (empty != ''){
            swal({
                title: "Attenzione, sottogruppo già inizializzato",
                text: "Sei proprio sicuro di voler proseguire? in caso affermativo tutte le modifiche verranno perse.",
                type: "warning",
                showCancelButton: true,
                confirmButtonText: "Si, sono sicuro",
                closeOnConfirm: true,
                cancelButtonText: "Annulla"
            }, function () {

                swal("Sottogruppo non salvato", "Il sottogruppo non è stato modificato!", "success");
                // hide div
                $('#subgroup-detail, #subgroup-save').hide();
                // clear form
                clearAll();
            });
        }
        else{
            // clear form
            clearAll();
        }
    });

    // load stations in the first tab
    $('#provinces').trigger('change');
}
    ////// TAB - sottogruppi - END //////

    ////// Attenzione TAB - anomalie - START //////
{
    // hide div
    $( "#view-data-abnormal" ).hide();
    $( "#edit-data-abnormal" ).hide();

    // select2 initialization
    $("#abn-net").select2();

    // datatable initialization
    tblAbn = $('#abnormal-data-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "responsive": true,
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        "columnDefs": [
            // { "width": 50, "targets": 0 },
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 2, "asc" ]]
    });

    // //////////////////////////////////////////////////////////
    // TABLE FUNCTION
    /*
     * Click event on view button
     */
    $('#abnormal-data-table').on('click', '.view-abn', function(e){
        e.preventDefault();

        // retrieve id stored in the tr row
        var dataid = parseFloat($(this).parent().parent().data("id"));
        console.log(dataid);
        // reset text
        $( "#view-data-abnormal .clear-view" ).html('');
        // sloly hide div
        $( "#edit-data-abnormal" ).hide('slow');

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_abnormals_data_by_id',
            type: "post",
            dataType: "json",
            data: {
                plid: dataid
            },
        })
        .done(function(result) {

            // check result
            // if ok fill view with retrieved data
            // else show error message
            if(result.res == 'OK'){

                var limit = result.limit;

                $('#view-param').html(limit.param_name+' <small>('+limit.networks_name.join(', ')+')</small>');
                $('#view-date-from').text(limit.pl_jd_from);
                $('#view-date-to').text(limit.pl_jd_to);

                $('#view-data-error-min').html( formatValue(limit.pl_error_min) +'<br><small>'+limit.param_unit+'</small>');
                $('#view-data-susp-min').html( formatValue(limit.pl_suspect_min) +'<br><small>'+limit.param_unit+'</small>');
                $('#view-data-susp-max').html( formatValue(limit.pl_suspect_max) +'<br><small>'+limit.param_unit+'</small>');
                $('#view-data-error-max').html( formatValue(limit.pl_error_max) +'<br><small>'+limit.param_unit+'</small>');

                $('#view-gap-error').text( formatValue(limit.pl_error_gap));
                $('#view-gap-susp').text( formatValue(limit.pl_suspect_gap));
                $('.view-gap-unit').text('('+limit.param_unit+')');

                $('#view-pers-susp').text( formatValue(limit.pl_suspect_persistence));
                $('#view-pers-error').text( formatValue(limit.pl_error_persistence));

                $( "#view-data-abnormal" ).show('slow');
                scrollToAnchor('tab-main');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
        });
    });

    /*
     * Click event on edit button
     */
    $('#abnormal-data-table').on('click', '.edit-abn', function(e){
        e.preventDefault();

        // sloly hide div
        $( "#view-data-abnormal" ).hide('slow');

        // clear form
        clearEditAbn();
        // get id stored in the tr row
        var dataid = parseInt($(this).parent().parent().data("id"));

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_abnormals_data_by_id',
            type: "post",
            dataType: "json",
            data: {
                plid: dataid
            },
        })
        .done(function(result) {

            // check result
            // if ok then fill form with retrieved data
            // else error message
            if(result.res == 'OK'){

                var limit = result.limit;

                $('#abn-net').val( limit.networks ).trigger('change');
                $('#abn-plid').val( limit.pl_id );

                $('#abn-param').val( limit.param_id);
                $('#abn-param').prop('disabled', true);

                $('#abn-date-from').val( limit.pl_jd_from);
                $('#abn-date-to').val( limit.pl_jd_to);

                $('#abn-error-min').val( limit.pl_error_min );
                $('#abn-susp-min').val( limit.pl_suspect_min );
                $('#abn-susp-max').val( limit.pl_suspect_max );
                $('#abn-error-max').val( limit.pl_error_max );

                $('#abn-gap-error').val( limit.pl_error_gap);
                $('#abn-gap-susp').val( limit.pl_suspect_gap);

                $('#abn-pers-susp').val( limit.pl_suspect_persistence);
                $('#abn-pers-error').val( limit.pl_error_persistence);

                $('.clear-edit-label').text( limit.param_unit );


                $( "#edit-data-abnormal" ).show('slow');
                scrollToAnchor('tab-main');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
        });
    });

    /*
     * Click event on delete button
     */
    $('#abnormal-data-table').on('click', '.del-abn', function(e){
        e.preventDefault();

        // get id stored in the tr row
        var plid = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai eliminando l'anomalia per parametro",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected report
            var jqxhr = $.ajax({
                url: '/str_ava_val_del_abnormals_limit',
                type: "post",
                dataType: "json",
                data: {
                    id: plid
                }
            })
            .done(function(result) {
                // check result
                if(result){
                    // success message
                    swal("Anomalia eliminata", "Anomalia eliminata con successo!", "success");
                    // remove row from table and refresh it
                    tblAbn.row($("tr[data-id='"+plid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione", "error");
            });
        });
    });
    // END TABLE FUNCTION
    // //////////////////////////////////////////////////////////

    /*
     * Click event on close button
     */
    $('#view-data-abnormal').on('click', '#view-data-close', function(e){
        e.preventDefault();
        $( "#view-data-abnormal" ).hide('slow');
        $( "#view-data-abnormal .clear-view" ).html('');
    });

    /*
     * Click event on cancel button
     */
    $('#edit-data-abnormal').on('click', '#abn-cancel', function(e){
        e.preventDefault();
        $( "#edit-data-abnormal" ).hide('slow');
        // clear form
        clearEditAbn();
    });

    /*
     * Click event on New button
     */
    $('.box-title').on('click', '#new-abnormal', function(e){
        e.preventDefault();
        // clear form
        clearEditAbn();
        $( "#view-data-abnormal" ).hide('slow');
        $( "#edit-data-abnormal" ).show('slow');
        scrollToAnchor('tab-main');
    });

    /*
     * Change event on Parameter select
     */
    $('#abn-param').on('change', function(){

        var unit = $(this).find('option:selected').data('unit');

        $('.clear-edit-label').text(unit);
    });

    // initialize the plugin
    $('#new-parameter-abn').validate({
        rules: {
            'abn-net':{
                required: true,
                allowEmpty: false
            },
            'abn-param':{
                required: true,
                min: 1
            },
            'abn-date-from':{
                required: true,
                integer: true,
                min: 1,
                max: function(){ return $('#abn-date-to').val() ? parseInt( $('#abn-date-to').val() ) : 366; }
            },
            'abn-date-to':{
                required: true,
                integer: true,
                max: 366,
                min: function(){ return $('#abn-date-from').val() ? parseInt( $('#abn-date-from').val() ) : 1; }
            },
            'abn-error-min':{
                dotSeparator: true,
                max: function(){ return $('#abn-error-max').val() ? parseFloat( $('#abn-error-max').val()) : 999999999; }
            },
            'abn-susp-min':{
                dotSeparator: true,
                max: function(){ return $('#abn-susp-max').val() ? parseFloat( $('#abn-susp-max').val()) : 999999999; }
            },
            'abn-susp-max':{
                dotSeparator: true,
                min: function(){ return $('#abn-susp-min').val() ? parseFloat( $('#abn-susp-min').val()) : -999999999; }
            },
            'abn-error-max':{
                dotSeparator: true,
                min: function(){ return $('#abn-error-min').val() ? parseFloat( $('#abn-error-min').val()) : -999999999; }
            },
            'abn-gap-susp':{
                dotSeparator: true,
                max: function(){ return $('#abn-gap-error').val() ? parseFloat( $('#abn-gap-error').val()) : 999999999; }
            },
            'abn-gap-error':{
                dotSeparator: true,
                min: function(){ return $('#abn-gap-susp').val() ? parseFloat( $('#abn-gap-susp').val()) : -999999999; }
            },
            'abn-pers-susp':{
                integer: true,
                min: 1,
                max: function(){ return $('#abn-pers-error').val() ? parseFloat( $('#abn-pers-error').val()) : 999999999; }
            },
            'abn-pers-error':{
                integer: true,
                min: function(){ return $('#abn-pers-susp').val() ? parseFloat( $('#abn-pers-susp').val()) : 1; }
            },
        },
        messages: {
            'abn-net':{
                required: 'Selezionare almeno una rete'
            },
            'abn-param':{
                required: 'Selezionare un parametro',
                min: 'Selezionare un parametro'
            },
            'abn-date-from':{
                required: 'inserire numero da 1 a 366',
                min: 'inserire numero da 1 a 366',
                integer: 'inserire numero intero'
            },
            'abn-date-to':{
                required: 'inserire numero da 1 a 366',
                max: 'inserire numero da 1 a 366',
                integer: 'inserire numero intero'
            },
            'abn-pers-susp':{
                min: 'inserire numero maggiore di 1',
                integer: 'inserire numero intero'
            },
            'abn-pers-error':{
                integer: 'inserire numero intero'
            },
        },
        ignore: "",
        errorPlacement: function(error, element) {
            error.insertAfter(element);
        }
    });

    /*
     * Submit event
     */
    $('#new-parameter-abn').on('submit', function(e){
        e.preventDefault();

        // check if form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti oppure non corretti. Controllare prima di procedere.", "info");
            return false;
        };

        var id = $('#abn-plid').val();
        var msg_ok, msg_err;
        // check if id is not null
        // if true then edit action else insert action
        // build different messages
        if(id && id != ''){
            msg_ok = 'La modifica è stata salvata con successo!';
            msg_err = 'Errore durante il salvataggio della modifica!';
        }
        else{
            msg_ok = 'Il salvataggio dei dati è avvenuto con successo!';
            msg_err = 'Errore durante il salvataggio dei dati!';
        }

        var form = $('#new-parameter-abn');

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // ajax call
        $.ajax({
            type: 'post',
            url: '/str_ava_val_put_abnormals_limit',
            data: form.serialize()
        }).done(function(result) {
            // check result
            //  - if '-1' rule already exists for the selected pollutant / period
            //  - if '1' then show success message, refresh table and clear form
            //  - else error
            if(result == 1){
                swal("Successo", msg_ok, "success");

                // refresh table
                loadAbnTable();

                if( id ){
                    $( "#edit-data-abnormal" ).hide('slow');
                }
                // clear form
                clearEditAbn();
            }
            else if(result == -1){
                swal({
                    title: "Attenzione!",
                    text: "Regola <strong>GIÀ PRESENTE</strong> per l'inquinante e il periodo selezionati.<br>Modificare i dati inseriti e riprovare.",
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
    });

    // refresh list of rules
    loadAbnTable();
}
    ////// TAB - anomalie - END //////

    ////// Attenzione TAB - anomalie per stazione - START //////
{
    // hide div
    $( "#station-view-data-abnormal" ).hide();
    $( "#station-edit-data-abnormal" ).hide();

    // datatable initialization
    tblAbnSt = $('#station-abnormal-data-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
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
            // { "width": 50, "targets": 0 },
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    // select2 initialization
    $("#station-abn-st").select2({
        matcher: searchGroupedSelect2
    });

    /*
     * Change event on Station select
     */
    $("#station-abn-st").on('change', function(){
        // get station id
        var stid = $(this).val();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_parameters',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {
            // check result
            // if ok then build options for the parameters select
            if(result.res == 'OK'){
                $('#station-abn-param').empty();
                var params = result.params;

                // variable for dynamically build html elements
                var opts = '';
                // loop through all elements
                // for each parameter build an html option
                $.each(params, function(index, param){

                    opts += '<option value="'+ param.stpr_id+'" data-unit="'+param.parameter_unit+'">'+param.parameter_name+'</option>';
                });
                $('#station-abn-param').append('<option value="-1">Seleziona parametro...</option>');
                $('#station-abn-param').append(opts);

                // if stprid is not null then select it programmatically
                    $('#station-abn-param').val(stpr_id);
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
    });

    /*
     * Change event on Parameter select
     */
    $('#station-abn-param').on('change', function(){
        // update unit
        var unit = $(this).find('option:selected').data('unit');

        $('.clear-edit-label').text(unit);
    });

    // //////////////////////////////////////////////////////////
    // TABLE FUNCTION
    /*
     * Click event on view button
     */
    $('#station-abnormal-data-table').on('click', '.view-abn', function(e){
        e.preventDefault();

        // get id stored in tr row
        var dataid = parseFloat($(this).parent().parent().data("id"));

        // reset title and hide div
        $( "#station-view-data-abnormal .clear-view" ).html('');
        $( "#station-edit-data-abnormal" ).hide('slow');

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_stat_abnormals_data_by_id',
            type: "post",
            dataType: "json",
            data: {
                plid: dataid
            },
        })
        .done(function(result) {

            // check result
            // if ok then fill the view container with all retrieved data
            // else show error message
            if(result.res == 'OK'){

                var limit = result.limit;

                $('#station-view-param').html(limit.param_name+' <small>('+limit.station_name+')</small>');
                $('#station-view-date-from').text(limit.spl_jd_from);
                $('#station-view-date-to').text(limit.spl_jd_to);

                $('#station-view-data-error-min').html( formatValue(limit.spl_error_min) +'<br><small>'+limit.param_unit+'</small>');
                $('#station-view-data-susp-min').html( formatValue(limit.spl_suspect_min) +'<br><small>'+limit.param_unit+'</small>');
                $('#station-view-data-susp-max').html( formatValue(limit.spl_suspect_max) +'<br><small>'+limit.param_unit+'</small>');
                $('#station-view-data-error-max').html( formatValue(limit.spl_error_max) +'<br><small>'+limit.param_unit+'</small>');

                $('#station-view-gap-error').text( formatValue(limit.spl_error_gap));
                $('#station-view-gap-susp').text( formatValue(limit.spl_suspect_gap));
                $('.station-view-gap-unit').text('('+limit.param_unit+')');

                $('#station-view-pers-susp').text( formatValue(limit.spl_suspect_persistence));
                $('#station-view-pers-error').text( formatValue(limit.spl_error_persistence));

                $( "#station-view-data-abnormal" ).show('slow');
                scrollToAnchor('tab-main');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
        });
    });

    /*
     * Click event on edit button
     */
    $('#station-abnormal-data-table').on('click', '.edit-abn', function(e){
        e.preventDefault();

        // clear form
        clearEditAbnSt();
        // get id stored in tr row
        var dataid = parseInt($(this).parent().parent().data("id"));
        // hide div
        $( "#station-view-data-abnormal" ).hide('slow');

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_stat_abnormals_data_by_id',
            type: "post",
            dataType: "json",
            data: {
                plid: dataid
            },
        })
        .done(function(result) {

            // check result
            // if ok then fill form with retrieved metadata
            // else show error message
            if(result.res == 'OK'){

                var limit = result.limit;
                $('#station-abn-plid').val( limit.spl_id );

                $('#station-abn-st').val( limit.station_id ).trigger('change');
                stpr_id = limit.stpr_id;

                $('#station-abn-st').prop('disabled', true);
                $('#station-abn-param').prop('disabled', true);

                $('#station-abn-date-from').val( limit.spl_jd_from);
                $('#station-abn-date-to').val( limit.spl_jd_to);

                $('#station-abn-error-min').val( limit.spl_error_min );
                $('#station-abn-susp-min').val( limit.spl_suspect_min );
                $('#station-abn-susp-max').val( limit.spl_suspect_max );
                $('#station-abn-error-max').val( limit.spl_error_max );

                $('#station-abn-gap-error').val( limit.spl_error_gap);
                $('#station-abn-gap-susp').val( limit.spl_suspect_gap);

                $('#station-abn-pers-susp').val( limit.spl_suspect_persistence);
                $('#station-abn-pers-error').val( limit.spl_error_persistence);

                $('.clear-edit-label').text( limit.param_unit );


                $( "#station-edit-data-abnormal" ).show('slow');
                scrollToAnchor('tab-main');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio", "error");
        });
    });

    /*
     * Click event on delete button
     */
    $('#station-abnormal-data-table').on('click', '.del-abn', function(e){
        e.preventDefault();
        // get id stored in tr row
        var splid = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai eliminando l'anomalia per parametro",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected rule
            var jqxhr = $.ajax({
                url: '/str_ava_val_del_stat_abnormals_limit',
                type: "post",
                dataType: "json",
                data: {
                    id: splid
                }
            })
            .done(function(result) {
                // check result
                // if ok then show success message and remove the row
                // else show error message
                if(result){

                    swal("Anomalia eliminata", "Anomalia eliminata con successo!", "success");
                    tblAbnSt.row($("tr[data-id='"+splid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione", "error");
            });
        });
    });
    // END TABLE FUNCTION
    // //////////////////////////////////////////////////////////

    /*
     * Click event on close button
     */
    $('#station-view-data-abnormal').on('click', '#station-view-data-close', function(e){
        e.preventDefault();
        $( "#station-view-data-abnormal" ).hide('slow');
        $( "#station-view-data-abnormal .clear-view" ).html('');
    });

    /*
     * Click event on cancel button
     */
    $('#station-edit-data-abnormal').on('click', '#station-abn-cancel', function(e){
        e.preventDefault();
        $( "#station-edit-data-abnormal" ).hide('slow');

        // clear form
        clearEditAbnSt();
    });

    /*
     * Click event on New button
     */
    $('.box-title').on('click', '#station-new-abnormal', function(e){
        e.preventDefault();

        // clear form
        clearEditAbnSt();
        $( "#station-view-data-abnormal" ).hide('slow');
        $( "#station-edit-data-abnormal" ).show('slow');
        stpr_id = null;
        scrollToAnchor('tab-main');

    });

    // initialize the plugin
    $('#station-new-parameter-abn').validate({
        rules: {
            'abn-st':{
                required: true,
                min: 1
            },
            'abn-param':{
                required: true,
                min: 1
            },
            'abn-date-from':{
                required: true,
                integer: true,
                min: 1,
                max: function(){ return $('#station-abn-date-to').val() ? parseInt( $('#station-abn-date-to').val() ) : 366; }
            },
            'abn-date-to':{
                required: true,
                integer: true,
                max: 366,
                min: function(){ return $('#station-abn-date-from').val() ? parseInt( $('#station-abn-date-from').val() ) : 1; }
            },
            'abn-error-min':{
                dotSeparator: true,
                max: function(){ return $('#station-abn-error-max').val() ? parseFloat( $('#station-abn-error-max').val()) : 999999999; }
            },
            'abn-susp-min':{
                dotSeparator: true,
                max: function(){ return $('#station-abn-susp-max').val() ? parseFloat( $('#station-abn-susp-max').val()) : 999999999; }
            },
            'abn-susp-max':{
                dotSeparator: true,
                min: function(){ return $('#station-abn-susp-min').val() ? parseFloat( $('#station-abn-susp-min').val()) : -999999999; }
            },
            'abn-error-max':{
                dotSeparator: true,
                min: function(){ return $('#station-abn-error-min').val() ? parseFloat( $('#station-abn-error-min').val()) : -999999999; }
            },
            'abn-gap-susp':{
                dotSeparator: true,
                max: function(){ return $('#station-abn-gap-error').val() ? parseFloat( $('#station-abn-gap-error').val()) : 999999999; }
            },
            'abn-gap-error':{
                dotSeparator: true,
                min: function(){ return $('#station-abn-gap-susp').val() ? parseFloat( $('#station-abn-gap-susp').val()) : -999999999; }
            },
            'abn-pers-susp':{
                integer: true,
                min: 1,
                max: function(){ return $('#station-abn-pers-error').val() ? parseInt( $('#station-abn-pers-error').val()) : 999999999; }
            },
            'abn-pers-error':{
                integer: true,
                min: function(){ return $('#station-abn-pers-susp').val() ? parseInt( $('#station-abn-pers-susp').val()) : 1; }
            },
        },
        messages: {
            'abn-param':{
                required: 'Selezionare un parametro',
                min: 'Selezionare un parametro'
            },
            'abn-date-from':{
                required: 'inserire numero da 1 a 366',
                min: 'inserire numero da 1 a 366',
                integer: 'inserire numero intero'
            },
            'abn-date-to':{
                required: 'inserire numero da 1 a 366',
                max: 'inserire numero da 1 a 366',
                integer: 'inserire numero intero'
            },
            'abn-pers-susp':{
                min: 'inserire numero maggiore di 1',
                integer: 'inserire numero intero'
            },
            'abn-pers-error':{
                integer: 'inserire numero intero'
            },
        },
        ignore: "",
        errorPlacement: function(error, element) {
            error.insertAfter(element);
        }
    });

    /*
     * Submit event
     */
    $('#station-new-parameter-abn').on('submit', function(e){
        e.preventDefault();

        // check if form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti oppure non corretti. Controllare prima di procedere.", "info");
            return false;
        };

        var id = $('#station-abn-plid').val();
        var msg_ok, msg_err;

        // check if id is defined
        // if true then is an update action otherwise is an insert action
        // build different messages
        if(id && id != ''){
            msg_ok = 'La modifica è stata salvata con successo!';
            msg_err = 'Errore durante il salvataggio della modifica!';
        }
        else{
            msg_ok = 'Il salvataggio dei dati è avvenuto con successo!';
            msg_err = 'Errore durante il salvataggio dei dati!';
        }

        var form = $('#station-new-parameter-abn');

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // ajax call
        $.ajax({
            type: 'post',
            url: '/str_ava_val_put_stat_abnormals_limit',
            data: form.serialize()
        }).done(function(result) {
            // check result
            //  - if '-1' rule already exists for the selected pollutant / period
            //  - if '1' then show success message, refresh table and clear form
            //  - else error
            if(result == 1){
                // success message
                swal("Successo", msg_ok, "success");

                loadAbnStationTable();

                if( id ){
                    $( "#station-edit-data-abnormal" ).hide('slow');
                }
                clearEditAbnSt();
            }
            else if(result == -1){
                swal({
                    title: "Attenzione!",
                    text: "Regola <strong>GIÀ PRESENTE</strong> per l'inquinante e il periodo selezionati.<br>Modificare i dati inseriti e riprovare.",
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
    });

    // load stations and stations rules
    loadStations(-1);
    loadAbnStationTable();
}
    ////// TAB - anomalie per stazione - END //////

    // FUNCTIONS
    /////////////////////////////////////////////////////////////////////////

    // UTILITY FUNCTIONS

    /**
     * Function that clears and resets all form's fields in the first tab
     * No args needed
     */
    function clearAll() {
        console.log('clear all fields');

        // clear text fields
        $('input.clear-field').val('');
        // reset checkbox
        $('#subgroup-public').prop('checked', false).trigger('change');

        // reset select2 multiple
        new_subgroup_groups.val([]);
        new_subgroup_groups.trigger('change');
        // take care of multiselet
        $( '#multiselect1_leftAll' ).trigger("click");
        $( '#multiselect2_leftAll' ).trigger("click");
        // reset texts
        $('#settings-form h2').text('Aggiungi sottogruppo stazioni');
        $('#settings-form h3').text('Crea un nuovo sottogruppo');

        // reset validate plugin
        $('#subgroup-config').validate().resetForm();
    }

    /**
     * Function that clears and resets all form's fields in the second tab
     * No args needed
     */
    function clearEditAbn(){
        // enable parameter select
        $('#abn-param').prop('disabled', false);

        // take care of select and input fields
        $('#edit-data-abnormal #abn-net').val([]).trigger('change');
        $('#edit-data-abnormal select.clear-edit').val(-1);
        $('#edit-data-abnormal input.clear-edit').val('');
        // reset title
        $('#edit-data-abnormal small.clear-edit-label').html('');

        // reset validate plugin
        $('#new-parameter-abn').validate().resetForm();
    };

    /**
     * Function that clears and resets all form's fields in the third tab
     * No args needed
     */
    function clearEditAbnSt(){
        // reset global variable
        stpr_id = null;

        // enable parameter select
        $('#station-abn-st, #station-abn-param').prop('disabled', false);

        // take care of select and input fields
        $('#station-edit-data-abnormal select.clear-edit').val(-1).trigger('change');
        $('#station-edit-data-abnormal input.clear-edit').val('');
        // reset title
        $('#station-edit-data-abnormal small.clear-edit-label').html('');

        // reset validate plugin
        $('#station-new-parameter-abn').validate().resetForm();
    };

    /**
     * Function that clean subgroups in multiselect in order to prevent to having duplicates
     * (options in left column which are also present in the right one )
     *
     * @param {text} left Selector for left column
     * @param {text} right Selector for right column
     */
    function cleanMultiselect(left, right){
        // loop through all otpions in right column
        // for each element check if it is a normal option or anoption group and do different actions
        $(right).find('option').each(function(index, rightOption) {
            if ($(rightOption).parent().prop('tagName') == 'OPTGROUP') {
                // if it is an option group then remove from left column all linked options
                var optgroupSelector = 'optgroup[label="' + $(rightOption).parent().attr('label') + '"]';
                $(left).find(optgroupSelector + ' option[value="' + rightOption.value + '"]').each(function(index, leftOption) {
                    leftOption.remove();
                });
                $(left).find(optgroupSelector).removeIfEmpty();
            } else {
                // otherwise remove from left column the single option
                var $option = $(left).find('option[value="' + rightOption.value + '"]');
                $option.remove();
            }
        });
    }

    /**
     * Function for scrolling the page up
     *
     * @param {text} aid HTML element id attribute
     */
    function scrollToAnchor(aid){
        var aTag = $("#"+ aid );
        $('html,body').animate({scrollTop: aTag.offset().top},'slow');
    };

    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null then returns string 'na';
     *         If not null then returns the string provided before.
     */
    function formatValue(limit){

        if( limit == null)
            return 'na';
        else
            return limit;
    }

    // LEFT TREE FUNCTION
    /**
     * Function that builds the macro tree's menu on a right-click event
     *
     * @param {object} clicked node
     */
    function customMenu(node){
        // check depth of the node
        if ( node.parents.length != 1 ) {
            return false;
        }

        // build object for the menu to be visualized
        var items = {
            editItem: { // The "edit" menu item
                label: "Modifica sottogruppo",
                "_disabled": ! update_grant,
                action: function (){

                    $('#settings-form h2').text('Modifica sottogruppo stazioni');
                    $('#settings-form h3').text('Aggiorna sottogruppo selezionato: '+$(node)[0].text);
                    var empty = $('#subgroup-fill').val();
                    var subgroup = $(node)[0].li_attr.id;
                    // If the structure has already been initialized, ask for confirmation and reset the global variable boxes
                    // else fill subgroup form without asking confirmation
                    if (empty != ''){
                        swal({
                            title: "Attenzione, sottogruppo già generato",
                            text: "Sei proprio sicuro di voler proseguire con la modifica di un altro sottogruppo? in caso affermativo tutto quanto compilato finora verrà eliminato.",
                            type: "warning",
                            showCancelButton: true,
                            confirmButtonText: "Si, rigenera",
                            closeOnConfirm: true,
                            cancelButtonText: "Annulla"
                        }, function () {

                            clearAll();
                            editSubgroup(subgroup);
                        });
                    }
                    else{
                        editSubgroup(subgroup);
                    }
                }
            },
            deleteItem: { // The "delete" menu item
                label: "Elimina sottogruppo",
                "_disabled": ! delete_grant,
                action: function (){

                    var subgroup = $(node)[0].li_attr.id;
                    // show confirmation message
                    swal({
                        title: "Attenzione!",
                        text: "Sei proprio sicuro di voler proseguire con l'eliminazione del sottogruppo?",
                        type: "warning",
                        showCancelButton: true,
                        confirmButtonText: "Si, elimina",
                        closeOnConfirm: true,
                        cancelButtonText: "Annulla"
                    }, function (isConfirm) {
                        var empty = $('#subgroup-fill').val();

                        if(isConfirm){
                            deleteSubgroup(subgroup);

                            // if delete the same subgroup displayed in the form then clean everything
                            if (empty != '' && subgroup == parseInt($('#subgroup-id').val())){
                                $('#subgroup-detail, #subgroup-save').hide();
                                clearAll();
                            }
                        }
                        return;
                    });
                }
            }
        };

        return items;
    };

    /**
     * Function that initializes the left tree
     * No args needed
     */
    function initializeLeftTree(){

        // initialize jstree plugin
        $('#group-json').jstree({
            'core' : {
                // 'check_callback': true,
                'data' : {
                    url: function (node) {

                        var url = "";
                        console.log('NODE.id: '+ node.id);

                        // different load routes based on the type of the node
                        if (node.id === '#')
                        {
                            url = "/str_ava_val_get_validation_groups";
                        }
                        else
                        {
                            switch (node.li_attr.type) {
                                case 'group':
                                    url = "/str_ava_val_get_group_stations";
                                    break;
                                default:
                                    break;
                            }
                        }

                        console.log(url);
                        return url;
                    },
                    // 'type': "get",
                    'contentType': "application/json",
                    'dataType': 'JSON',
                    data: function (node) {

                        if( node.id === "#"){
                            return;
                        }
                        else{
                            return {"nodeid": node.id, "id": node.li_attr.id};
                        }
                    }
                }
            },
            'plugins' : ["search", "contextmenu"],
            'search' : {
                // ajax
                show_only_matches: true,
                show_only_matches_children: true
            },
            'contextmenu': {items: customMenu}
        });


        // SEARCH PLUGIN FOR JSTREE
        var to = false;
        // keyup event on input search
        $('#input-search').keyup(function () {
            if(to) { clearTimeout(to); }
            to = setTimeout(function () {
                var v = $('#input-search').val();
                $('#group-json').jstree(true).search(v);
            }, 250);
        });

        // at search end returns filtered nodes
        $('#group-json').on("search.jstree", function(e, data){
            filtered_obj = data.nodes;
        });
    };

    /**
     * Function that retrieves the stations of a given set of networks and of a given province.
     *
     * @param {integer} prid Province ID.
     * @param {array} nets Network IDs.
     */
    function loadStationsByNetworks(prid, nets){
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_stations_bynets',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                nets: JSON.stringify(nets)
            },
        })
        .done(function(result) {
            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                var stations = result.stations;

                var opts = '';
                var net;
                var lastNet;
                // loop through all elements
                // for each station, build a html option to be added to the multiselect
                $.each(stations, function(index, station){
                    // check if the network is the same of the previous one
                    // if true then add simple option
                    // otherwise close previous optgroup and open new one
                    if(lastNet != station.station_network_type_desc){

                        if(index != 0)
                            opts += '</optgroup>';

                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                        lastNet = station.station_network_type_desc;
                    }
                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';

                    if(index == stations.length -1)
                        opts += '</optgroup>';
                });

                // empty multiselect and fill it with new stations
                $('#multiselect1').empty();
                $('#multiselect1').append(opts);
                $('#multiselect1').multiselect();
                // clean columns of multiselect
                cleanMultiselect('#multiselect1', '#subgroup-stat');
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
     * Function that retrieves metadata of a given subgroup and fill the form.
     *
     * @param {integer} subgroup_id Subgroup ID.
     */
    function editSubgroup(subgroup_id){
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_subgroup_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: subgroup_id
            },
        })
        .done(function(result) {
            // check result
            // if ok then fill form with metadata
            // else show error message
            if(result.res == 'OK'){
                var subgroup = result.subgroup;

                $('#subgroup-fill').val(1);
                $('#subgroup-id').val(subgroup.tree_id);
                $('#subgroup-name').val(subgroup.tree_name);

                $('#subgroup-public').prop('checked', subgroup.tree_public).trigger('change');

                new_subgroup_groups.val(subgroup.groups_id); // Select the option with a value of '1'
                new_subgroup_groups.trigger('change');

                $('#multiselect1').val(subgroup.stations_id);
                $('#multiselect1_rightSelected').trigger('click');

                $('#multiselect2').val(subgroup.panels_id);
                $('#multiselect2_rightSelected').trigger('click');

                // show div
                $('#subgroup-detail, #subgroup-save').show();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del sottogruppo", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del sottogruppo", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that deletes a given subgroup
     *
     * @param {integer} subgroup_id Subgroup ID.
     */
    function deleteSubgroup(subgroup_id){
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_del_subgroup',
            type: "post",
            dataType: "json",
            data: {
                id: subgroup_id
            },
        })
        .done(function(result) {
            // check result
            // if true then refresh jstree and show success message
            // else error message
            if(result){
                $('#group-json').jstree(true).refresh(true);

                swal("Successo!", "Il sottogruppo è stato eliminato con successo", "success");
            }
            else{
                swal("Errore!", "Errore durante l'eliminazione del sottogruppo", "error");

            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'eliminazione del sottogruppo", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that load stations of a given province
     *
     * @param {prid} subgroup_id Subgroup ID.
     */
    function loadStations(prid){
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if ok build options to add to the select
            // else show error message
            if(result.res == 'OK'){
                // empty select
                $('#station-abn-st').empty();
                var stations = result.stations;

                // variable for dynamically build html
                var opts = '';
                var net;
                // loop through all elements
                // for each station build html option
                $.each(stations, function(index, station){
                    // check if current network is equal to previous one
                    // and take care of optgroup
                    if(net != station.station_network_type_id){

                        if(index != 0)
                            opts += '</optgroup>';

                        net = station.station_network_type_id;
                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                    }

                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';
                });
                $('#station-abn-st').append('<option value="-1">Seleziona stazione...</option>');
                $('#station-abn-st').append(opts);

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
     * Function that load rules for checking abnormal data
     * No args needed
     */
    function loadAbnTable(){

        // reset datatable
        if ( tblAbn )
            tblAbn.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_abnormals_data',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // check result
            // if ok build html rows and add them to table
            // else show error message
            if(result.res == 'OK'){
                var limits = result.limits;

                // check if at least one element exists
                if( limits.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    // loop through all elements
                    // for each rule, build a html row to be added to the datable
                    $.each(limits, function(index, value) {

                        html += '<tr data-id="'+value.pl_id+'">';
                        html += '    <td class="bobo-nowrap">';
                        html += '        <a class="view-abn" data-original-title="Visualizza" data-toggle="tooltip" href="javascript:void(0)"><i class="ti-zoom-in text-info"></i></a>';
                        if(update_grant){
                            html += '        <a class="edit-abn" data-original-title="Modifica" data-toggle="tooltip" href="javascript:void(0)"><i class="icon-pencil text-info"></i></a>';
                        }
                        if(delete_grant){
                            html += '        <a class="del-abn" data-original-title="Elimina" data-toggle="tooltip" href="javascript:void(0)"><i class="ti-trash text-danger"></i></a>';
                        }
                        html += '    </td>';
                        html += '    <td class="td-param">'+value.networks.join(', ')+'</td>';
                        html += '    <td class="td-param">'+value.param_name+'</td>';
                        html += '    <td>'+value.pl_jd_from+'</td>';
                        html += '    <td>'+value.pl_jd_to+'</td>';
                        html += '    <td>'+value.pl_suspect_min+'</td>';
                        html += '    <td>'+value.pl_suspect_max+'</td>';
                        html += '    <td>'+value.pl_error_min+'</td>';
                        html += '    <td>'+value.pl_error_max+'</td>';
                        html += '    <td>'+value.pl_suspect_gap+'</td>';
                        html += '    <td>'+value.pl_error_gap+'</td>';
                        html += '    <td>'+value.pl_suspect_persistence+'</td>';
                        html += '    <td>'+value.pl_error_persistence+'</td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblAbn.rows.add($( html ));
                    // redraw it
                    tblAbn.draw();
                    // adjust columns size
                    tblAbn.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblAbn.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });

                }
                else {
                    tblAbn.draw();
                }
            }
            else{
                // error mesage
                swal("Errore!", "Errore durante il recupero dei dati", "error");
                tblAbn.draw();
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");

        });
    };

    /**
     * Function that load stations rules for checking abnormal data
     * No args needed
     */
    function loadAbnStationTable(){

        // reset datatable
        if ( tblAbnSt )
            tblAbnSt.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_val_get_stat_abnormals_data',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // check result
            // if ok build html rows and add them to table
            // else show error message
            if(result.res == 'OK'){
                var limits = result.limits;
                // check if at least one element exists
                if( limits.length > 0 ){
                    // variable for dynamically building the html
                    var html= '';
                    // loop through all elements
                    // for each rule, build a html row to be added to the datable
                    $.each(limits, function(index, value) {

                        html += '<tr data-id="'+value.spl_id+'">';
                        html += '    <td class="bobo-nowrap">';
                        html += '        <a class="view-abn" data-original-title="Visualizza" data-toggle="tooltip" href="javascript:void(0)"><i class="ti-zoom-in text-info"></i></a>';
                        if(update_grant){
                            html += '        <a class="edit-abn" data-original-title="Modifica" data-toggle="tooltip" href="javascript:void(0)"><i class="icon-pencil text-info"></i></a>';
                        }
                        if(delete_grant){
                            html += '        <a class="del-abn" data-original-title="Elimina" data-toggle="tooltip" href="javascript:void(0)"><i class="ti-trash text-danger"></i></a>';
                        }
                        html += '    </td>';
                        html += '    <td class="td-param">'+value.station_name+'</td>';
                        html += '    <td class="td-param">'+value.param_name+'</td>';
                        html += '    <td>'+value.spl_jd_from+'</td>';
                        html += '    <td>'+value.spl_jd_to+'</td>';
                        html += '    <td>'+value.spl_suspect_min+'</td>';
                        html += '    <td>'+value.spl_suspect_max+'</td>';
                        html += '    <td>'+value.spl_error_min+'</td>';
                        html += '    <td>'+value.spl_error_max+'</td>';
                        html += '    <td>'+value.spl_suspect_gap+'</td>';
                        html += '    <td>'+value.spl_error_gap+'</td>';
                        html += '    <td>'+value.spl_suspect_persistence+'</td>';
                        html += '    <td>'+value.spl_error_persistence+'</td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object
                    tblAbnSt.rows.add($( html ));
                    // redraw it
                    tblAbnSt.draw();
                    // adjust columns size
                    tblAbnSt.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    tblAbnSt.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });

                }
                else {
                    tblAbnSt.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
                tblAbnSt.draw();
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");

        });
    };
    ////////////////////////////////////////////////////////////
    // END FUNCTIONS
});

