/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    // table,
    var multiObj;

    var defaultParams;
    var valCodes;
    var aggregations;

    var newCatGroups;
    var windowsArray = [];
    var windowsNum = -1;

    // hide buttons container
    $('#panel-save').hide();
    // change select2 setting
    $.fn.select2.defaults.set("width", null);

    // first load of metadata in order to fill form
    loadFormOptions();
    // initialize tree on the left column
    initializeLeftTree();

    // initialize sortable plugin pointing to .window element
    $('#accordion-windows').sortable({
        items: '> .window',
        handle: '.sort-handler'
    });

    // -- ! MODAL GESTIONE GRUPPI ! -- //
{
    // at modal closure clean the form
    $('#groups-settings').on('hidden.bs.modal', function (e) {
        clearGroupForm();
    });

    // boostraptoggle for public elements
    $( "#new-category input[type=checkbox]" ).bootstrapToggle();

    // multiple selection select
    newCatGroups = $(".select2").select2();

    // click event on edit category button
    $("#categories-table").on('click', '.edit_category', function(e){
        e.preventDefault();

        // retrieve category id stored in parent element
        var cat_id = $(this).parent().parent().data('id');

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_category_byid',
            type: "post",
            dataType: "json",
            data: {
                id: cat_id
            }
        })
        .done(function(result) {
            // check result
            // if OK then fill form with category's metadata
            // else take care of error
            if(result.res == 'OK'){
                var category = result.category;

                // fill form
                $('#new-cat-id').val(category.category_id);
                $('#new-cat-name').val(category.category_name);
                $('#new-cat-public').prop('checked', category.category_public);
                $('#new-cat-public').trigger('change');

                newCatGroups.val(category.category_groups);
                newCatGroups.trigger('change');
                // change button's text
                $('#save-cat').html('<i class="ti-save-alt"></i> Modifica');
            }
            else{
                // error mesasge
                swal("Errore!", "Errore durante il recupero del dettaglio del gruppo", "error");
            }
        })
        .fail(function(xhr, err) {
            // error mesasge
            swal("Errore!", "Errore durante il recupero del dettaglio del gruppo", "error");
        });
    });

    // click event on delete category button
    $("#categories-table").on('click', '.delete_category', function(e){
        e.preventDefault();

        // retrieve category id stored in parent element
        var cat_id = $(this).parent().parent().data('id');

        // show a confirm message
        swal({
            title: "Elimina gruppo",
            text: "Sei sicuro di voler eliminare il gruppo? Saranno eliminate anche tutti i pannelli ad esso associato!",
            type: "warning",
            showCancelButton: true,
            confirmButtonClass: "btn-danger",
            confirmButtonText: "Si, elimina",
            cancelButtonText: "Annulla",
            closeOnConfirm: true
        },
        function(){

            // if user confirm action then delete category via an ajax call
            $.ajax({
                type: 'post',
                url: '/str_ava_vis_del_category',
                data: {
                    id: cat_id
                }
            }).done(function(result) {

                // check result
                // if true then refresh categories and the left tree
                // else take care of error
                if(result){
                    loadCategories();

                    $('#group-json').jstree(true).refresh(true);
                    // success message
                    swal("Successo", "Gruppo eliminato con successo", "success");
                }
                else
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del gruppo", "error");

                // at the end of the process hide preloader
                $('.inner-preloader').hide();

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione del gruppo", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });
        });
    });

    // change event on bootstrap toggle
    $("#new-cat-public").on("change", function(e){
        e.preventDefault();
        // get new status
        var state = $(this).prop('checked')

        // if active then empty select2 groups and disable it
        // else enable it
        if(state){
            newCatGroups.val([]);
            // force change event on select2 component
            newCatGroups.trigger('change');
            $('#new-cat-groups').prop("disabled", true);
        }
        else{
            $('#new-cat-groups').prop("disabled", false);
        }
    });

    // define validation rules
    // initialize the plugin
    $('#new-category').validate({
        rules: {
            "new-cat-name" : {
                required: true
            },
            "new-cat-groups":{
                required: ! $("#new-cat-public").prop('checked')
            }
        },
        messages: {
            "new-cat-name" : {
                required: "Inserire il nome del gruppo"
            },
            "new-cat-groups" : {
                required: "Inserire gruppi UTENTI"
            }
        },
        ignore: "",
        errorPlacement: function(error, element) {
                error.insertAfter(element);
        }
    });

    // SUBMIT EVENT
    $('#new-category').on('submit', function (e) {
        e.preventDefault();

        // get form element
        var form = $("#new-category");
        // retrieve category id
        var id = $("#new-cat-id").val();
        var msg_err;
        var msg_ok;

        // if id is defined then it's an update action
        // otherwise it's an insert action
        if(id){
            msg_ok = 'La categoria è stata modificata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica della categoria';
        }
        else{
            msg_ok = 'La categoria è stata aggiunta con successo!';
            msg_err = 'Si è verificato un errore durante l\'inserimento della nuova categoria';
        }

        // check if form is valid
        if (! $(this).valid() ){
            return false;
        };

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // put new category by an ajax call
        $.ajax({
            type: 'post',
            url: '/str_ava_vis_put_category',
            data: form.serialize()
        }).done(function(result) {

            // check result
            // if OK then empty form, refresh all elements and show success message
            // else take care of error
            if(result.res  == 'OK'){
                // refresh categories
                loadCategories();
                // refresh left tree
                $('#group-json').jstree(true).refresh(true);
                // show success message
                swal("Successo", msg_ok, "success");
                // clear form
                clearGroupForm();
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
            swal("Errore!", "Errore durante l'aggiunta ", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    // click event on cancel button
    $("#new-category").on('click', '#reset-cat', function(e){
        e.preventDefault();
        // clear form
        clearGroupForm();
    });
}

    // panel form validation
    $('#panel-config').validate({ // initialize the plugin
        rules: {
            "panel-name": {
                required: true
            },
            "panel-group": {
                min: 0
            },

        },
        messages: {
            "panel-name": {
                required: "Inserire nome pannello"
            },
            "panel-group": {
                min: "Inserire gruppo di appartenenza"
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

    // click event on "Finestra manuale" button
    $('#settings-form').on( "click", "#panel-btn-add", function(e) {
        e.preventDefault();

        // check if the name of the panel and the category have been selected
        var form = $('#panel-config');
        if (! form.valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile proseguire", "info");
            return false;
        };

        // dynamically create the html for the new window and add it to the main container
        addNewWindow();

        // show final buttons container
        $('#panel-save').show();
    });

    // click event on "Finestra automatica" button
    $('#settings-form').on( "click", "#panel-btn-auto", function(e) {
        e.preventDefault();

        // check if the name of the panel and the category have been selected
        var form = $('#panel-config');
        if (! form.valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile proseguire", "info");
            return false;
        };
    });

    // click event on "Elimina finestre" button
    $('#settings-form').on( "click", "#panel-btn-cancel", function(e) {
        e.preventDefault();

        // show confirm message
        swal({
            title: "Attenzione, eliminazione finestre",
            text: "Sei proprio sicuro di voler proseguire nell'eliminazione di tutte le finestre?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {
            // if user confirm action then reset global variables containing all windows
            // and empty the main container
            if( isConfirm ){
                windowsArray = [];
                windowsNum = -1;

                $('#accordion-windows').empty();
                $('#panel-save').hide();
                // success message
                swal("Fatto!", "Le finestre sono state eliminate", "success");
            }
        });
    });

    // -- ! FORM AGGIUNGI PANNELLO ! -- //
{
    // click event on copy button present in every accordion
    $('#accordion-windows').on('click', '.copy-window', function(e){
        e.preventDefault();

        // get accordion element
        var parent = $(this).parent().parent();

        // create a temporary macro object
        var objMacro = {};
        objMacro.macro = {};
        objMacro.params = [];

        // creade validity operator
        var operator =  parent.find('.change-operators button.sel').text();
        if(operator == '='){
            var codes = parent.find('.multiple-select-code').val();
            codes.forEach(function(el, idx){
                codes[idx] = '= '+el;
            });
            validity = codes.join(', ');
        }
        else{
            console.log('single code');
            console.log(parent.find('.single-select-code').val());
            if( parent.find('.single-select-code').val() == "" ){
                validity = null;
            }
            else{
                validity = operator +' '+ parent.find('.single-select-code').val();
            }
        }

        // fill temporary macro with metadata inserted in the original window
        objMacro.macro.name  = parent.find('[name="window-name"]').val()+' - Copia';
        objMacro.macro.type  = parent.find('[name="window-type"]').val();
        objMacro.macro.aggregation  = parent.find('[name="select-aggr"]').val();
        objMacro.macro.days         = parent.find('[name="window-days"]').val() == '' ? null : parent.find('[name="window-days"]').val();
        objMacro.macro.percent_data = parent.find('[name="select-perc"]').val();
        objMacro.macro.min = parent.find('[name="chart-min"]').val() == '' ? null : parseFloat(parent.find('[name="chart-min"]').val());
        objMacro.macro.max = parent.find('[name="chart-max"]').val() == '' ? null : parseFloat(parent.find('[name="chart-max"]').val());
        objMacro.macro.Yaxys_min = parent.find('[name="chart-axis-min"]').val() == '' ? null : parseFloat(parent.find('[name="chart-axis-min"]').val());
        objMacro.macro.Yaxys_max = parent.find('[name="chart-axis-max"]').val() == '' ? null : parseFloat(parent.find('[name="chart-axis-max"]').val());
        objMacro.macro.validity_code = validity;

        // loop on each parameter form, retrieve the data and insert it into objMacro
        parent.find('.single-param').each(function(index){

            objMacro.params[index] = {};
            objMacro.params[index] = JSON.parse($(this).find('[name="param-object"]').val());

            objMacro.params[index].legend     = $(this).find('[name="param-name"]').val();
            objMacro.params[index].treatment  = $(this).find('[name="param-treatment"]').val();
            objMacro.params[index].chartstyle = $(this).find('[name="param-chart"]').val();
            objMacro.params[index].color      = $(this).find('[name="param-color"]').val().slice(1);
            objMacro.params[index].formule    = $(this).find('[name="param-formule"]').val();
            objMacro.params[index].minval     = $(this).find('[name="param-min-val"]').is(':checked');
            objMacro.params[index].maxval     = $(this).find('[name="param-max-val"]').is(':checked');

        });

        // dynamically create the html of the window filled with data of the temporary macro
        addNewWindow(objMacro);
        // show success message
        $.toast({
            heading: 'SUCCESSO',
            text: 'Duplicazione finestra avvenuta con successo!',
            position: 'top-right',
            loaderBg:'#ff6849',
            icon: 'info',
            hideAfter: 3000
        });
    });

    // click event on delete button present in every accordion
    $('#accordion-windows').on('click', '.del-window', function(e){

        // get accordion element
        var parent = $(this).parent().parent();
        // show confirm message
        swal({
            title: "Attenzione, eliminazione finestra",
            text: "Sei proprio sicuro di voler proseguire nell'eliminazione della finestra?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {
            // if user confirm
            // then remove the accordion elemeny
            if( isConfirm ){
                parent.remove();
                // success message
                swal("Fatto!", "La finestra è stata eliminata", "success");
            }
        });
    });

    // change event on winsow name field
    $('#accordion-windows').on('change', '.window-name', function(e){
        var name = $(this).val()
        var res = $(this).attr("id").split('-');
        var winIdx = parseInt(res[2]);
        // when the name changes update the title of the accordion
        $('.collapse'+winIdx+' strong').text(name);
    });

    // select the logical operator needed in relation to the validity code of my tab
    $('#accordion-windows').on('click', '.change-operators button', function(e){
        e.preventDefault();

        // get id from the parent and change classes to operators button
        var myid = $(this).parent().attr('id');
        $('#'+myid+' button').removeClass('sel');
        $(this).addClass('sel');

        var num = parseInt( myid.replace('validation-operators-', ''));
        // check the type of selected operator
        if( $(this).text() == '=' ){
            $('#select-code-'+num).hide();
            // with = operator user can select more than one code (= as "containing")
            // initialize and show the select2 element
            var optionDef = $('#multiple-select-code-'+num+' option.default-val').val();
            $('#multiple-select-code-'+num).attr('style', '');
            $('#multiple-select-code-'+num).select2();
            $('#multiple-select-code-'+num).val([optionDef]).trigger('change.select2')
        }
        else{
            // with operator different from = user can select only one code
            // hide select2 element
            var optionDef = $('#select-code-'+num+' option.default-val').val();
            $('#select-code-'+num).show();
            $('#select-code-'+num).val(optionDef);

            // Checking if select2 plugin is initialized
            if($('#multiple-select-code-'+num).hasClass("select2-hidden-accessible") ){
                $('#multiple-select-code-'+num).select2('destroy');
                $('#multiple-select-code-'+num).attr('style','display: none');
            }
        }
    });

    // change event on code select element
    $('#accordion-windows').on("change", '.single-select-code', function(e){
        e.preventDefault();

        // get id
        var myid = $(this).attr('id');
        var num = parseInt( myid.replace('select-code-', ''));

        // if code is empty then "Tutti i dati" case
        // disable operator buttons
        if( $(this).val() == ""){
            $('#validation-operators-'+num+' button').removeClass('sel');
            $('#validation-operators-'+num+' button').prop("disabled", true);
        }
        else{
            // if operator buttons are disabled then enable it and select the default operator
            if($('#validation-operators-'+num+' button').prop("disabled")){
                $('#validation-operators-'+num+' button').prop("disabled", false);
                $('#validation-operators-'+num+' .default-val').addClass('sel');
            }
        }
    });

    // change event on type field (chart/table )
    $('#accordion-windows').on( "change", ".window-type", function(e) {

        // get the new type
        var type = $(this).val();
        // get the window index by splitting element id
        var res = $(this).attr("id").split('-');
        var winIdx = parseInt(res[2]);

        // hide/show chart fields based on the selected type
        if(type == 'chart'){
            $('.chart-input-'+winIdx).show('slow');
        }
        else{
            $('.chart-input-'+winIdx).hide('slow');
        }
    });

    // click event on "Aggiungi parametri" button
    $('#accordion-windows').on('click', '.tab-add-params', function(e){
        // get window's index
        var winIdx = $(this).parent().data('winidx');
        // store it in the parameter modal
        $('#btn-add-params').parent().data('winidx', winIdx);
    });

    // click event on "Reset parametri" button
    $( '#accordion-windows' ).on( "click", ".tab-reset-params", function(e) {
        e.preventDefault();

        // get window's index
        var winIdx = $(this).parent().data('winidx');
        // show confirm message
        swal({
            title: "Attenzione, reset parametri",
            text: "Sei proprio sicuro di voler proseguire nell'eliminazione di tutti i parametri?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {
            // if user confirm action then empty the parameters' html container
            if( isConfirm ){

                $('#all-my-params-'+winIdx).empty();
                // success message
                swal("Fatto!", "I parametri sono stati eliminati", "success");
            }
        });
    });

    // click event on "Elimina parametro" button
    $( '#accordion-windows' ).on('click', '.del-param', function(e){
        e.preventDefault();
        // get parameter form element
        var parent= $(this).parent().parent().parent();

        // get window's index
        var res = $(this).parent().parent().parent().parent().attr("id").split('-');
        var winIdx = res[3];

        // show confirm message
        swal({
            title: "Attenzione, eliminazione parametro",
            text: "Sei proprio sicuro di voler proseguire nell'eliminazione del parametro?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {
            // if user confirm action then remove parameter
            if( isConfirm ){
                parent.remove();
                // success message
                swal("Fatto!", "Il parametro è stato eliminato", "success");
            }
        });
    });
}

    // -- ! MODAL GESTIONE PARAMETRI ! -- //
{
    // initialize select2
    $("#select-stations").select2({
        matcher: searchGroupedSelect2
    });

    // initialize bootstrap toggle
    $('#adding-parameters input[type=checkbox]').bootstrapToggle();

    // at modal closure clean the form
    $('#adding-parameters').on('hidden.bs.modal', function (e) {

        // destroy and re-itialize bootstraptoggle in order to not trigger change event
        $('#show-conv').prop('checked', false).bootstrapToggle('destroy').bootstrapToggle();
        // reset select
        $('#select-prov').val(-1);
        $('#select-net').val(-1);

        // forse reset of select2 element
        $('#adding-parameters select[multiple]').val([]).trigger("change.select2");

        // empty multiselect plugin
        $('#multiselect').empty();
        $('#select-params').empty();
        var opts = '';
        var lastSt;
        // loop through all default parameters
        // for each element build an html option to be added to multiselect plugin
        $.each(defaultParams, function(index, value) {

            if(lastSt != value.station_name){

                if(index != 0)
                    opts += '</optgroup>';

                // parameters are grouped by stations
                opts += '<optgroup label="'+value.station_name+'">';
                lastSt = value.station_name;
            }

            var unit = value.parameter_unit;
            opts += '   <option value="'+value.station_param_id+'">'+value.parameter_name+' ['+unit+']</option>';

            if(index == defaultParams.length -1)
                opts += '</optgroup>';
        });

        // add options to multiselect
        $('#multiselect').append(opts);
    });

    // change event on network field
    $('#select-net').on( "change", function(e) {

        // get station field id
        var dest = $(this).data('change');
        // reset province
        $('#select-prov').val(-1);

        // retrieve information in order to load correct parameters
        var net = $(this).val();
        var prid = -1;
        var stidArray = [];
        var conv = $('#show-conv').is(':checked');
        // load the stations that the user can see
        loadStations(net, prid, dest);
        // at network change, load the parameters associated with the stations
        loadParameters(net, prid, stidArray, conv);
    });

    // change event on province field
    $('#select-prov').on( "change", function(e) {

        // retrieve information in order to load correct parameters
        var dest = $(this).data('change');
        var prid = $(this).val();
        var net = $('#select-net').val();

        var stidArray = [];
        var conv = $('#show-conv').is(':checked');

        // load the stations that the user can see
        loadStations(net, prid, dest);
        // at province change, load the parameters associated with the stations
        loadParameters(net, prid, stidArray, conv);
    });

    // trigger change event on network select in order to load for the first time the list of stations
    $('#select-net').trigger('change');

    // change event on stations field
    $('#select-stations').on( "change", function(e) {

        // retrieve information in order to load correct parameters
        var net = $('#select-net').val();
        var prid = $('#select-prov').val();
        var stidArray = $(this).val();
        var conv = $('#show-conv').is(':checked');
        // at change event, load the parameters associated with the stations
        loadParameters(net, prid, stidArray, conv);
    });

    // change event on con bootstraptoggle
    $('#show-conv').on( "change", function(e) {

        // change type of multiselect parameters (converted or not)
        var conv = $(this).is(':checked');
        // retrieve information in order to load correct parameters
        var net = $('#select-net').val();
        var prid = $('#select-prov').val();
        var stidArray = $('#select-stations').val();

        // svuoto i parametri selezionati perchè non coerenti con la conversione selezionata
        $('#select-params').empty();
        // at change event, load the parameters associated with the stations
        loadParameters(net, prid, stidArray, conv);
    });

    //  click event on "Aggiungi parametri" modal button
    $( "#btn-add-params" ).on( "click", function(e) {
        e.preventDefault();

        // retrieve window index stored when modal has been opened
        var winIdx = $(this).parent().data('winidx');

        // set "selected" attribute to true for the parameters in the right field of the multiselect
        $('#select-params').find('option').prop('selected', true);
        // get array of selected parameters
        var params = $( '#select-params').val();

        // check if at least one parameter exists
        // otherwise show warning message
        if(params.length == 0){
            swal("Attenzione", "Devi selezionare almeno un parametro", "warning");
            return false;
        }

        // get conversion information
        var conv = $('#show-conv').is(':checked');

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // load metadata of selected parameters via an ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_params_info',
            type: "post",
            dataType: "json",
            data: {
                stprid: JSON.stringify(params),
                conv: conv
            }
        })
        .done(function(result) {

            // check result
            // if OK then hide modal and add parameters to window
            // else take care of error
            if(result.res == 'OK'){
                $('#adding-parameters').modal('hide');
                // for each parameter dynamically build a form to be added to the current window
                var params = result.params;
                addParametersForm(params, winIdx);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle informazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle informazioni", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });
}

    // -- ! MODAL GENERAZIONE AUTOMATICA FINESTRE ! -- //
{

    // hide diagnostics fields
    $('.diags-enabled').hide();

    // at modal closure clear the form
    $('#auto-windows').on('hidden.bs.modal', function (e) {
        clearFormAutoWindows();
    });

    $('#auto-net, #auto-prov').select2();
    // initialize select2 plugin
    $("#auto-stations").select2({
        matcher: searchGroupedSelect2
    });

    $("#auto-params-type, #auto-params, #auto-instruments").select2({
        dropdownParent: $("#auto-windows")
    });

    // initialize bootstraptoggle plugin
    $('#add-auto-windows input[type=checkbox]').bootstrapToggle();

    // change event on network field
    $("#auto-net").on( "change", function() {

        // reset province field
        $('#auto-prov').val(-1);

        // get information in order to load stations
        var net = $(this).val();
        var prid = -1;
        var dest = $(this).data('change');
        // refresh list of the stations
        loadStations(net, prid, dest);
    });

    // change event on network field
    $("#auto-prov").on( "change", function() {
        // get information in order to load stations
        var net = $('#auto-net').val();
        var prid = $(this).val();
        var dest = $(this).data('change');
        // refresh list of the stations
        loadStations(net, prid, dest);
    });

    // trigger change event on network select in order to load for the first time the list of stations
    $("#auto-net").trigger("change");

    // change event of station field
    $("#auto-stations").on('change',  function(){

        // get information in order to load the list of parameters
        var stidArray = $(this).val();
        var typeArray = $('#auto-params-type').val();
        var instrCategory = $("#auto-instruments").val();
        // refresh list of parameters
        loadStationsParams(stidArray, typeArray, instrCategory);
    });

    // change event on parameter type field
    $("#auto-params-type").on('change',  function(){
        console.dir('change type');

        var stidArray = $('#auto-stations').val();
        var typeArray = $(this).val();
        // check selected type
        // if "diagnostici" then show linked fields
        // else hide them
        if(typeArray.length == 1 && typeArray[0] == 13){
            $('.diags-enabled').show('slow');
            loadStationsParams(stidArray, typeArray, -1);
        }
        else{
            $('.diags-enabled').hide('slow');
            $('#auto-instruments').val(-1).trigger('change'); //
        }
    });

    // change event on instrument field
    $("#auto-instruments").on('change',  function(){
        // get information in order to load the list of parameters
        var stidArray = $('#auto-stations').val();
        var typeArray = $('#auto-params-type').val();
        var instrCategory = $(this).val();
        // refresh list of parameters
        loadStationsParams(stidArray, typeArray, instrCategory);
    });

    // initialize validation rules
    $('#add-auto-windows').validate({ // initialize the plugin
        rules: {
            "auto-stations": {
                required: true
            },
            "auto-params-type": {
                required: true
            },
        },
        messages: {
            "auto-stations": {
                required: "Inserire almeno una stazione"
            },
            "auto-params-type": {
                required: "Inserire almeno una tipologia di parametri"
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

    // cllick event on "Aggiungi finestre" button
    $( "#btn-add-auto-windows" ).on( "click", function(e) {
        e.preventDefault();

        // check form validity
        var form = $('#add-auto-windows');
        if (! form.valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti.", "info");
            return false;
        };
        // dynamically create windows html and add it to main container
        autoGenerateWindows();
    });
}

    // initialize windows validation rules
    $('#tab-config').validate({
        rules: {
            "window-name": {
                required: true
            },
            "window-type": {
                required: true
            },
            "select-perc" : {
                required: true,
                min: 1,
                max: 100
            },
            "chart-min" : {
                dotSeparator: true
            },
            "chart-max" : {
                dotSeparator: true
            },
            "chart-axis-min" : {
                dotSeparator: true
            },
            "chart-axis-max" : {
                dotSeparator: true
            },
            "param-name" : {
                required: true
            },
            "param-color" : {
                required: true
            },
            "param-chart":{
                required: true,
            },
            "param-treatment":{
                required: true
            },
            "param-formule":{
                required: true
            }
        },
        messages: {
            "window-name": {
                required: "Inserire nome finestra"
            },
            "window-type": {
                required: "Inserire tipologia finestra"
            },
            "select-perc" : {
                required: "Inserire perc. dati validi",
                min: "Inserire valori maggiori e/o uguali a 1",
                max: "Inserire valori minori e/o uguali a 100"
            },
            "param-name" : {
                required: "Inserire nome parametro"
            },
            "param-color" : {
                required: "Inserire colore parametro"
            },
            "param-chart":{
                required: "Selezionare tipo grafico",
                min: "Selezionare tipo grafico"
            },
            "param-treatment":{
                required: "Selezionare trattamento"
            },
            "param-formule":{
                required: "Inserire formula [Y = k*X+d]"
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

    // !!BOTTONI FINALI
    // click event on "Salva bozza" or "Salva e chiudi" buttons
    $('#panel-add, #panel-add-cancel').on('click', function(e){
        e.preventDefault();

        // resetFlag true > "Salva e chiudi", false > "Salva bozza"
        var resetFlag = parseInt($(this).data('reset'));
        console.log('submit form');

        // get form element and check validity
        var form = $('#tab-config');
        if (! form.valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare questo elemento", "info");
            return false;
        };

        // check if at least one window exists
        // else show warning message and return
        if($('#tab-config .window').length == 0 ){
            swal("Attenzione", "Configurare almeno una finestra", "info");
            return false;
        };

        // reset global variable which will contain the array of macros
        windowsArray = [];
        // initialize temporary variable for validity controls aims
        var flagValidity = 1;

        // loop through all html elements with class "window"
        // for each element build an object to be pushed in the global array
        $('#tab-config .window').each(function(){
            // check if it's a "bozza"
            // if true then allow windows without linked parameters
            // else set to false the validity flag and return
            if (resetFlag == 1 && $(this).find('.single-param').length == 0 ){
                flagValidity = 0;
                return false;
            };

            // create temporary macro object
            var objMacro = {};
            objMacro.macro = {};
            objMacro.params = [];

            // build the validity operators
            var operator =  $(this).find('.change-operators button.sel').text();
            // check the selected operator
            // if equal to = then it is possible that multiple codes have been selected
            // else only one code can exist
            if(operator == '='){
                var codes = $(this).find('.multiple-select-code').val();
                codes.forEach(function(el, idx){
                    codes[idx] = '= '+el;
                });
                validity = codes.join(', ');
            }
            else{
                // if selected code is empty then it is "Tutti i dati" case
                // no operator needed
                if( $(this).find('.single-select-code').val() == "" ){
                    validity = null;
                }
                else{
                    validity = operator +' '+ $(this).find('.single-select-code').val();
                }
            }

            // fill object with selected metadata
            objMacro.macro.name  = $(this).find('[name="window-name"]').val();
            objMacro.macro.type  = $(this).find('[name="window-type"]').val();
            objMacro.macro.aggregation  = $(this).find('[name="select-aggr"]').val();
            objMacro.macro.days         = $(this).find('[name="window-days"]').val() == '' ? null : $(this).find('[name="window-days"]').val();
            objMacro.macro.percent_data = $(this).find('[name="select-perc"]').val();
            objMacro.macro.min = $(this).find('[name="chart-min"]').val() == '' ? null : parseFloat($(this).find('[name="chart-min"]').val());
            objMacro.macro.max = $(this).find('[name="chart-max"]').val() == '' ? null : parseFloat($(this).find('[name="chart-max"]').val());
            objMacro.macro.Yaxys_min = $(this).find('[name="chart-axis-min"]').val() == '' ? null : parseFloat($(this).find('[name="chart-axis-min"]').val());
            objMacro.macro.Yaxys_max = $(this).find('[name="chart-axis-max"]').val() == '' ? null : parseFloat($(this).find('[name="chart-axis-max"]').val());
            objMacro.macro.validity_code = validity;

            // loop through each parameter form, retrieve the data and insert it into objMacro
            $(this).find('.single-param').each(function(index){

                objMacro.params[index] = {};
                objMacro.params[index] = JSON.parse($(this).find('[name="param-object"]').val());

                objMacro.params[index].legend     = $(this).find('[name="param-name"]').val();
                objMacro.params[index].treatment  = $(this).find('[name="param-treatment"]').val();
                objMacro.params[index].chartstyle = $(this).find('[name="param-chart"]').val();
                objMacro.params[index].color      = $(this).find('[name="param-color"]').val().slice(1);
                objMacro.params[index].formule    = $(this).find('[name="param-formule"]').val();
                objMacro.params[index].minval     = $(this).find('[name="param-min-val"]').is(':checked');
                objMacro.params[index].maxval     = $(this).find('[name="param-max-val"]').is(':checked');

            });

            // push temporary macro in the global array
            windowsArray.push(objMacro);
        });

        // check validity flag
        // if false then show warning message and return
        if(flagValidity == 0){
            swal("Attenzione", "Selezionare e configurare almeno un parametro per ogni finestra", "info");
            return false;
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // save windows via an ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_put_page',
            type: "post",
            dataType: "json",
            data: {
                id: $('#panel-id').val(),
                name: $('#panel-name').val(),
                cat: $('#panel-group').val(),
                boxes : JSON.stringify(windowsArray)
            },
        })
        .done(function(result) {

            // check result
            // if OK then refresh left tree and refresh visualization
            if(result.res == 'OK'){

                $('#group-json').jstree(true).refresh(true);

                // check if it's a definitive submit
                // if true then show success message and clear main container
                // else show toast message and do nothing also
                if(resetFlag == 1){
                    swal('Successo!', 'Il pannello è stato salvato correttamente!', 'success');

                    clearAll();
                }
                else{

                    // set id for update
                    // otherwise the procedure continues to insert new rows in the db
                    var id = result.id;
                    $('#panel-id').val(id);
                    $.toast({
                        heading: 'SUCCESSO',
                        text: 'Salvataggio bozza avvenuta con successo!',
                        position: 'top-right',
                        loaderBg:'#ff6849',
                        icon: 'info',
                        hideAfter: 3000
                    });

                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il salvataggio del pannello", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il salvataggio del pannello", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    // click event on "Annulla" button
    $('#panel-cancel').on('click', function(e){
        e.preventDefault();

        // check if main container is not empty
        var empty = $('#panel-fill').val();
        // if it isn't empty then show confirm message
        if (empty != ''){
            swal({
                title: "Attenzione, pannello già inizializzato",
                text: "Sei proprio sicuro di voler proseguire? in caso affermativo tutte le modifiche verranno perse.",
                type: "warning",
                showCancelButton: true,
                confirmButtonText: "Si, sono sicuro",
                closeOnConfirm: true,
                cancelButtonText: "Annulla"
            }, function () {
                // if user confirm then clear all
                clearAll();
            });
        }
        else{
            // clear all
            clearAll();
        }
    });

    // first load of categories
    loadCategories();
    // NOT USED first load of the total list of parameters linked to stations visible to the user
    // loadParameters(-1, -1, [], false);

    // UTILITIES
    /**
     * Function that resets all
     * No args needed
     */
    function clearAll(){

        // reset global variables
        windowsArray = [];
        windowsNum = -1;
        // reset form's titles
        $('#settings-form h5').text('Aggiungi un nuovo pannello');

        // reset first mini form about general data of new panel
        $('#panel-fill').val('');
        $('#panel-id').val('');
        $('#panel-name').val('');
        $('#panel-group').val(-1);

        // reset validate plugin
        $('#panel-config').validate().resetForm();
        $('#tab-config').validate().resetForm();
        // empty central container
        $('#accordion-windows').empty();
        // hide final buttons
        $('#panel-save').hide();
    };

    /**
     * Function that resets only the new category form
     * No args needed
     */
    function clearGroupForm(){
        // clear fields
        $('#new-cat-id').val("");
        $('#new-cat-name').val("");
        $('#new-cat-public').prop('checked', false);
        $('#new-cat-public').trigger('change');
        // forse select2 reset
        newCatGroups.val([]);
        newCatGroups.trigger('change');
        // enable groups field
        $('#new-cat-groups').prop('disabled', false);
        // reset button text
        $('#save-cat').html('<i class="ti-save-alt"></i> Aggiungi');
    };

    /**
    * Function to clean form for the automatic generation of the windows
    * No args needed
     */
    function clearFormAutoWindows(){
        // reset select fields
        $("#auto-prov").val(-1)
        $("#auto-net").val(-1).trigger('change');
        // force reset of select2
        $('#add-auto-windows select[multiple]').val([]).trigger("change.select2");
        $("#auto-instruments").val(-1).trigger('change.select2');

        // clear parameters
        $("#auto-params").empty();
        // destroy and re-initialize bootstraptoggle in order to prevent change event
        $('#auto-conv').prop('checked', false).bootstrapToggle('destroy').bootstrapToggle();
        // reset validate plugin
        $('#add-auto-windows').validate().resetForm();
    };

    // INIZIALIZZAZIONI
    /**
    * Function that manage the submenu for each node of the left tree
    * @param {object} node elementof the tree
    *
    * @return Object with the submenu options
     */
    function customMenu(node){

        // check if the node is a leaf
        // else return and don't show the sub-menu
        if ( node.parents.length  != 2 ) {
            return false;
        }

        var items = {
            addItem:{
                label: 'Anteprima',
                separator_after: true,
                action: function(){
                    var page = $(node)[0].li_attr.id;
                    // clicking on Anteprima a new page will be opened with visualizer tool
                    window.open("/str_visualizer/"+page, '_blank');
                }
            },
            editItem: { // The "edit" menu item
                label: "Modifica pannello",
                "_disabled": ! update_grant,
                action: function (){

                    var empty = $('#panel-fill').val();
                    var page = $(node)[0].li_attr.id;
                    // if the structure has already been initialized, ask for confirmation and reset the global variable boxes
                    if (empty != ''){
                        swal({
                            title: "Attenzione, pannello già generato",
                            text: "Sei proprio sicuro di voler proseguire con la modifica di un altro pannello? in caso affermativo tutto quanto compilato finora verrà eliminato.",
                            type: "warning",
                            showCancelButton: true,
                            confirmButtonText: "Si, rigenera",
                            closeOnConfirm: true,
                            cancelButtonText: "Annulla"
                        }, function () {
                            // if user confirm then clear all and fill central container with panel data
                            clearAll();
                            editPanel(page);
                        });
                    }
                    else{
                        // fill central container with panel data
                        editPanel(page)
                    }
                }
            },
            copyItem: {
                label: "Duplica pannello",
                "_disabled": ! update_grant,
                action: function (){
                    // create a copy of selected panel
                    var page = $(node)[0].li_attr.id;
                    duplicatePanel(page);
                }
            },
            deleteItem: {
                label: "Elimina pannello",
                "_disabled": ! delete_grant,
                action: function (){
                    // get panel id
                    var page = $(node)[0].li_attr.id;
                    // show confirm message
                    swal({
                        title: "Attenzione!",
                        text: "Sei proprio sicuro di voler proseguire con l'eliminazione del pannello?",
                        type: "warning",
                        showCancelButton: true,
                        confirmButtonText: "Si, elimina",
                        closeOnConfirm: false,
                        cancelButtonText: "Annulla"
                    }, function (isConfirm) {
                        // if user confirm then delete panel
                        if(isConfirm){

                            // check if selected panel is in edit mode
                            // if truen then clear central container
                            if($('#panel-fill').val() != '' && page == parseInt($('#panel-id').val())){
                                clearAll();
                            }
                            deletePanel(page);
                        }
                    });
                }
            }
        };

        // if it is a folder then remove delete option
        if ($(node).hasClass("folder")) {
            // Delete the "delete" menu item
            delete items.deleteItem;
        }

        return items;
    };

    /**
    * Function that initialize the left tree
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

                        // for each level define the route by which load children nodes
                        if (node.id === '#')
                        {
                            url = "/str_vis_get_groups";
                        }
                        else
                        {
                            switch (node.li_attr.type) {
                                case 'group':
                                    url = "/str_vis_get_group_pages";
                                    break;
                                case 'page':
                                    url = "/str_vis_get_page_boxes";
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
                            if (node.li_attr.type == 'group')
                                return {"nodeid": node.id, "id": node.li_attr.id, "loaded": false};
                            else
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
        $('#input-search').keyup(function () {
            if(to) { clearTimeout(to); }
            to = setTimeout(function () {
                var v = $('#input-search').val();
                $('#group-json').jstree(true).search(v);
            }, 250);
        });

        $('#group-json').on("search.jstree", function(e, data){
            filtered_obj = data.nodes;
        });
    };

    /**
    * Function for retrieving information with which to fill forms
    * No args needed
     */
    function loadFormOptions(){

        console.log('loadFormOptions');
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_form_options',
            type: "post",
            dataType: "json",
        })
        .done(function(result) {
            // check result
            // if OK then initialize global variables
            // else take care of error
            if(result.res == 'OK'){

                valCodes     = result.val_codes;
                aggregations = result.aggregations;
                treatments   = result.treatments;
                defaultParams = result.parameters;

                // initialize multiselect plugin
                $('#multiselect').multiselect({
                    right: '#select-params',
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

                // variable for dynamically building html options
                var opts = '';
                var lastSt;
                // loop through all default parameters
                // for each element build an html option to be added to multiselect plugin
                $.each(defaultParams, function(index, value) {

                    if(lastSt != value.station_name){

                        if(index != 0)
                            opts += '</optgroup>';

                        // parameters are grouped by stations
                        opts += '<optgroup label="'+value.station_name+'">';
                        lastSt = value.station_name;
                    }

                    var unit = value.parameter_unit;
                    opts += '   <option value="'+value.station_param_id+'">'+value.parameter_name+' ['+unit+']</option>';

                    if(index == defaultParams.length -1)
                        opts += '</optgroup>';
                });

                // add options to multiselect
                $('#multiselect').append(opts);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    };

    /**
    * Function for retrieving the categories visible to the user
    * No args needed
     */
    function loadCategories(){

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_categories',
            type: "post",
            dataType: "json",
        })
        .done(function(result) {
            // check result
            // if OK then fill categories table and select
            // else take care of err
            if(result.res == 'OK'){

                var categories = result.categories_list;
                // empty the select and the table's body
                $('#categories-table tbody').empty();
                $('#panel-group').empty();

                // variable for dynamically building the html
                var htmlPanel = '<option value="-1">Seleziona gruppo...</option>';
                var htmlTable = '';

                // loop through all categories
                // for each item build an option and a tr elements
                $.each(categories, function(key, category){
                    // build option
                    htmlPanel += '<option value="'+category.category_id+'">'+category.category_name+'</option>';

                    // build table row
                    htmlTable += '<tr data-id="'+category.category_id+'">';
                    htmlTable += '   <td scope="row">';
                    // check user permission
                    if(update_grant){
                        htmlTable += '       <a href="javascript:void(0)" class="edit_category" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i></a>';
                    }
                    if(delete_grant){
                        htmlTable += '       <a href="javascript:void(0)" class="delete_category" data-toggle="tooltip" data-original-title="Elimina"> <i class="ti-trash text-danger"></i></a>';
                    }
                    htmlTable += '   </td>';
                    htmlTable += '   <td>'+category.category_name+'</td>';
                    if(category.category_public){
                        htmlTable += '   <td><i class="ti-check-box text-primary"></i></td>';
                    }
                    else{
                        htmlTable += '   <td></td>';
                    }
                    htmlTable += '   <td>'+category.category_groups_name.join(', ')+'</td>';
                    htmlTable += '</tr>';
                });

                // add options and rows
                $('#panel-group').append(htmlPanel);
                $('#categories-table tbody').append(htmlTable);
                // initialize tooltip
                $('[data-toggle="tooltip"]').tooltip();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei gruppi", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei gruppi", "error");
        });
    };

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {text} dest select's jquery selector
     * @param {integer} stid Station id to be automatically selected (edit case)
     */
    function loadStations(net, prid, dest, stid){
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_stations',
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
                $('#'+dest+'-stations').empty();
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

                    $('#'+dest+'-prov').empty();
                    $('#'+dest+'-prov').append('<option value="-1">Seleziona provincia...</option>');
                    $('#'+dest+'-prov').append(optsProv);
                    $('#'+dest+'-prov').append('</optgroup>');

                    $('#'+dest+'-prov').val(-1);
                }

                $('#'+dest+'-stations').append(opts);
                // check if stid is defined
                // then automatically select it
                if(stid)
                    $('#'+dest+'-stations').val(stid).trigger('change');

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
     * Function that retrieves the parameters of a given network of a given province.
     *
     * @param {integer} net Network ID.
     * @param {integer} prid Province ID.
     * @param {array} stidArray List of stations ID
     * @param {boolean} conv Conversion toggle status
     */
    function loadParameters(net, prid, stidArray, conv){

        // reset multiselect
        $('#multiselect').empty();
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_parameters',
            type: "post",
            dataType: "json",
            data: {
                net: net,
                prid: prid,
                stid: JSON.stringify(stidArray)
            },
        })
        .done(function(result) {
            // check result
            // if OK then fill multiselect
            // else take care of error
            if(result.res == 'OK'){

                var parameters = result.params;
                // variable for dynamically building html options
                var opts = '';
                var lastSt;
                // loop through all parameters
                // for each element build an html option to be added to multiselect plugin
                $.each(parameters, function(index, value) {

                    // parameters are grouped by stations
                    if(lastSt != value.station_name){

                        if(index != 0)
                            opts += '</optgroup>';

                        opts += '<optgroup label="'+value.station_name+'">';
                        lastSt = value.station_name;
                    }
                    // take care of unit based on conv flag
                    var unit = value.parameter_unit;
                    if(conv == true)
                        unit = value.parameter_unit_conv;
                    opts += '   <option value="'+value.station_param_id+'">'+value.parameter_name+' ['+unit+']</option>';

                    if(index == parameters.length -1)
                        opts += '</optgroup>';
                });
                // add options
                $('#multiselect').append(opts);
                // $('#multiselect').multiselect();
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
    };

    /**
     * Function that retrieves the parameters of a given list of stations
     *
     * @param {array} stidArray List of stations ID
     * @param {array} typeArray List of parameter types
     * @param {integer} instrCategory Instrument category
     */
    function loadStationsParams(stidArray, typeArray, instrCategory){
        $('#auto-params').empty();
        // check if at least one station or one parameter's type exists
        // else return
        if(stidArray.length == 0 && typeArray.length == 0)
            return;

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_params_bystid_types',
            type: "post",
            dataType: "json",
            data: {
                stid: JSON.stringify(stidArray),
                types: JSON.stringify(typeArray),
                cat: instrCategory
            },
        })
        .done(function(result) {
            // check result
            // if OK then build option to be added to parameters field
            // else take care of error
            if(result.res == 'OK'){

                var parameters = result.params;
                // variable for dynamically building html
                var opts = '';
                // loop through all parameters
                // for each item build an option html element
                $.each(parameters, function(index, value) {
                    opts += '   <option value="'+value.param_id+'">'+value.param_name+'</option>';
                });
                // append new options to select
                $('#auto-params').append(opts);
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

    // FUNZIONI CREAZIONE DINAMICA HTML
    /**
     * Function that dynamically builds html for windows forms
     *
     * @param {object} windowEl macro object
     */
    function addNewWindow( windowEl ){
        // increase number of windows by 1
        windowsNum++;
        // set dirty field
        $('#panel-fill').val(1);

        // take care of accordion visibility
        var show = '';
        if (windowsNum == 0){
            show = ' show'
        };
        // variable for dynamically building html
        var html = '';
        html += '<div class="card window">';
        html += '    <div class="card-header" id="heading'+windowsNum+'">';
        html += '        <a href="#" class="copy-window text-info" data-toggle="tooltip" data-original-title="Duplica questa finestra" title=""><i class="ti-layers"></i></a>';
        html += '        <a href="#" class="del-window text-danger" data-toggle="tooltip" data-original-title="Elimina questa finestra" title=""><i class="ti-trash"></i></a>';
        html += '        <a href="#" class="sort-handler text-success" data-toggle="tooltip" data-original-title="Ordina questa finestra" title=""><i class="far fa-sort-circle"></i></a>';
        html += '        <h2 class="mb-0">';
        if(windowEl)
            html += '            <button aria-controls="collapse'+windowsNum+'" aria-expanded="true" class="btn btn-link btn-block text-left collapse'+windowsNum+'" data-target="#collapse'+windowsNum+'" data-toggle="collapse" type="button">Configura <strong>'+windowEl.macro.name+'</strong></button>';
        else
            html += '            <button aria-controls="collapse'+windowsNum+'" aria-expanded="true" class="btn btn-link btn-block text-left collapse'+windowsNum+'" data-target="#collapse'+windowsNum+'" data-toggle="collapse" type="button">Configura <strong>finestra '+(windowsNum+1)+'</strong></button>';
        html += '        </h2>';
        html += '    </div>';
        html += '    <div aria-labelledby="heading'+windowsNum+'" class="collapse'+show+'" data-parent="#accordion-windows" id="collapse'+windowsNum+'">';
        html += '        <div class="card-body">';
        html += '            <h4 class="tab-general-title">Impostazioni generali</h4>';
        html += '            <div class="form-group row">';
        html += '                <label for="window-name" class="col-sm-2 col-form-label">Nome Finestra</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <input type="text" class="form-control window-name" id="window-name-'+windowsNum+'" name="window-name" placeholder="Nome finestra...">';
        html += '                </div>';
        html += '                <label for="window-type" class="col-sm-2 col-form-label">Tipo</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <select class="custom-select col-12 window-type" id="window-type-'+windowsNum+'" name="window-type">';
        html += '                        <option value="">Tipo...</option>';
        html += '                        <option value="chart">Grafico</option>';
        html += '                        <option value="table">Tabella</option>';
        html += '                    </select>';
        html += '                </div>';
        html += '            </div>';
        html += '            <div class="form-group row">';
        html += '                <label for="select-aggr" class="col-sm-2 col-form-label">Aggregaz. temporale</label>';
        html += '                <div class="col-sm-4">';
        html += '                   <select class="form-control" id="select-aggr-'+windowsNum+'" name="select-aggr">';
        $.each(aggregations, function(index, aggregation) {
            if(aggregation.app_aggregation_default == true)
                html += '               <option value="'+aggregation.app_aggregation_label+'" selected>'+aggregation.app_aggregation_desc+'</option>';
            else
                html += '               <option value="'+aggregation.app_aggregation_label+'">'+aggregation.app_aggregation_desc+'</option>';
        });
        html += '                   </select>';
        html += '                </div>';
        html += '                <label for="select-perc" class="col-sm-2 col-form-label">Perc. dati validi</label>';
        html += '                <div class="col-sm-4 input-group">';
        html += '                    <input type="number" class="form-control" placeholder="Perc. dati validi" min="1" max="100" value="75" id="select-perc-'+windowsNum+'" name="select-perc">';
        html += '                    <div class="input-group-append">';
        html += '                        <span class="input-group-text">%</span>';
        html += '                    </div>';
        html += '                </div>';
        html += '            </div>';
        html += '            <div class="form-group row">';
        html += '                <label for="select-code" class="col-sm-2 col-form-label">Cod. validità</label>';
        html += '                <div class="col-sm-2 change-operators" id="validation-operators-'+windowsNum+'">';
        html += '                    <button type="button" class="btn btn-light"><=</button>';
        html += '                    <button type="button" class="btn btn-light">=</button>';
        html += '                    <button type="button" class="sel default-val btn btn-light">>=</button>';
        html += '                </div>';
        html += '                <div class="col-sm-2">';
        html += '                    <select class="form-control single-select-code" id="select-code-'+windowsNum+'" name="select-code">';
        html += '                        <option value="">Tutti i dati</option>';
        $.each(valCodes, function(index, valCode) {
            if(valCode.uvc_code_default == 1){
                html += '               <option class="default-val" selected value="'+valCode.uvc_code_id+'">'+valCode.uvc_code_formatted+'</option>';
            }else{
                html += '               <option value="'+valCode.uvc_code_id+'">'+valCode.uvc_code_formatted+'</option>';
            }
        });
        html += '                    </select>';
        html += '                    <select class="form-control clear-macro select2 select2-multiple multiple-select-code" id="multiple-select-code-'+windowsNum+'" name="select-code" multiple>';
        $.each(valCodes, function(index, valCode) {
            if(valCode.uvc_code_default == 1){
                html += '               <option class="default-val" value="'+valCode.uvc_code_id+'">'+valCode.uvc_code_formatted+'</option>';
            }else{
                html += '               <option value="'+valCode.uvc_code_id+'">'+valCode.uvc_code_formatted+'</option>';
            }
        });
        html += '                    </select>';
        html += '                </div>';
        html += '                <label for="window-days" class="col-sm-2 col-form-label">Giorni visibili</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <select class="custom-select col-12 window-days" id="window-days-'+windowsNum+'" name="window-days">';
        html += '                         <option value="">Seleziona...</option>';
        html += '                         <option value="1 d">1 giorno</option>';
        html += '                         <option value="2 d">2 giorni</option>';
        html += '                         <option value="4 d">4 giorni</option>';
        html += '                         <option value="8 d">8 giorni</option>';
        html += '                         <option value="16 d">16 giorni</option>';
        html += '                         <option value="1 M">1 mese</option>';
        html += '                         <option value="2 M">2 mesi</option>';
        html += '                         <option value="3 M">3 mesi</option>';
        html += '                    </select>';
        html += '                </div>';
        html += '            </div>';
        html += '            <div class="form-group row chart-input-'+windowsNum+'">';
        html += '                <label for="chart-min" class="col-sm-2 col-form-label">Linea gialla</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <input type="text" class="form-control" id="chart-min-'+windowsNum+'" name="chart-min" placeholder="Linea gialla...">';
        html += '                </div>';
        html += '                <label for="chart-max" class="col-sm-2 col-form-label">Linea rossa</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <input type="text" class="form-control" id="chart-max-'+windowsNum+'" name="chart-max" placeholder="Linea rossa...">';
        html += '                </div>';
        html += '            </div>';
        html += '            <div class="form-group row chart-input-'+windowsNum+'">';
        html += '                <label for="chart-axis-min" class="col-sm-2 col-form-label">Asse Y min</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <input type="text" class="form-control" id="chart-axis-min-'+windowsNum+'" name="chart-axis-min" placeholder="Valore asse Y minimo...">';
        html += '                </div>';
        html += '                <label for="chart-axis-max" class="col-sm-2 col-form-label">Asse Y max</label>';
        html += '                <div class="col-sm-4">';
        html += '                    <input type="text" class="form-control" id="chart-axis-max-'+windowsNum+'" name="chart-axis-max" placeholder="Valore asse Y massimo...">';
        html += '                </div>';
        html += '            </div>';
        html += '            <hr class="m-t-20 m-b-10" />';
        html += '            <div class="form-group row">';
        html += '                <div class="col-sm-6" data-winIdx="'+windowsNum+'">';
        html += '                    <button type="button" class="btn btn-info btn-sm tab-add-params" name="tab-add-params-'+windowsNum+'" id="tab-add-params-'+windowsNum+'" data-target="#adding-parameters" data-toggle="modal" data-winIdx="'+windowsNum+'"> <i class="icon-plus"></i> Aggiungi parametri</button>';
        html += '                    <button type="button" class="btn btn-danger btn-sm tab-reset-params" name="tab-reset-params" id="tab-reset-params-'+windowsNum+'"> <i class="icon-close"></i> Reset parametri</button>';
        html += '                </div>';
        html += '            </div>';
        // html += '           <hr>';
        html += '           <div id="all-my-params-'+windowsNum+'">';
        html += '           </div>';
        html += '        </div>';
        html += '    </div>';
        html += '</div>';

        // append new content to central container
        $('#accordion-windows').append(html);
        // refresh sortable plugin
        $('#accordion-windows').sortable('refresh')
        $('#accordion-windows').sortable( "enable" );

        // hide fields
        $('#multiple-select-code-'+windowsNum).attr('style','display: none');
        // initialize bootstrap toggle plugin
        $( ".accordion input[type=checkbox]" ).bootstrapToggle();

        // check if the associated object already exists (edit)
        if(windowEl){
            // fill form with metadata of passed argument
            console.log('riempio form');
            $('#window-name-'+windowsNum).val(windowEl.macro.name);
            $('#window-type-'+windowsNum).val(windowEl.macro.type);
            $('#window-days-'+windowsNum).val(windowEl.macro.days);

            $('#select-aggr-'+windowsNum).val(windowEl.macro.aggregation);
            $('#select-perc-'+windowsNum).val(windowEl.macro.percent_data);
            $('#chart-min-'+windowsNum).val(windowEl.macro.min);
            $('#chart-max-'+windowsNum).val(windowEl.macro.max);
            $('#chart-axis-min-'+windowsNum).val(windowEl.macro.Yaxys_min);
            $('#chart-axis-max-'+windowsNum).val(windowEl.macro.Yaxys_max);

            var operator;
            var validityArray =  windowEl.macro.validity_code;

            if( validityArray != null ){

                validityArray = validityArray.split(', ');
                if(validityArray.length > 1)
                    operator = '=';
                else{
                    var res = validityArray[0].split(" ");
                    operator = res[0];
                }

                $('#validation-operators-'+windowsNum+' button').filter(
                    function (){
                        return $( this ).text() === operator;
                    }
                ).trigger('click');
            }


            if(operator == '='){
                var codes = [];
                validityArray.forEach(function(el, idx){
                    codes[idx] = parseInt(el.replace('= ', ''));
                });
                $('#multiple-select-code-'+windowsNum).val(codes).trigger('change.select2');
            }
            else{
                var code;
                if( validityArray == null)
                    code= '';
                else
                    code = parseInt(validityArray[0].replace(operator, ''));

                $('#select-code-'+windowsNum).val(code).trigger('change');
            }

            // dynamically create parameters forms
            addParametersForm(windowEl.params, windowsNum);

            // show/hide chart fields based on macro type
            if(windowEl.macro.type == 'table')
                $('.chart-input-'+windowsNum).hide();
            else
                $('.chart-input-'+windowsNum).show();

        }
    };

    /**
     * Function that dynamically builds html for parameters forms
     *
     * @param {array} params Array of parameters
     * @param {integer} windowIdx Window index
     */
    function addParametersForm(params, windowIdx){

        var colorArray = [];
        // options for jscolor plugin
        jscolor.presets.default = {
            width:101,
            padding:0,
            shadow:false,
            borderWidth:0,
            backgroundColor: 'transparent',
            controlBorderColor :'#ccc',
            hash:true
        };

        // retrieve number of parameters by counting how many "single-param" elements are associated to window
        var indexParam = 0;
        if($('#all-my-params-'+windowIdx+' .single-param').length > 0)
            indexParam = parseInt($('#all-my-params-'+windowIdx+' .single-param:last .del-param').data("pos")) +1;

        // loop through all parameters
        // for each item automatically build form's html
        params.forEach(function(param){

            var html= '';

            html += '<div class="single-param">';
            html += '    <input type="hidden" class="form-control param-object-' + indexParam + '" name="param-object" value=\'' + JSON.stringify(param).replace(/\'/g, '')+'\'>';
            html += '    <h4>Configura parametro: '+param.legend+'</h4>';
            html += '    <div class="form-group row">';
            html += '        <label class="col-sm-2 col-form-label" for="param-name-'+indexParam+'">Nome parametro</label>';
            html += '        <div class="col-sm-4">';
            html += '            <input aria-invalid="false" class="form-control valid param-name-'+indexParam+'" name="param-name" placeholder="Nome parametro..." type="text" value="">';
            html += '        </div>';
            html += '        <label class="col-sm-2 col-form-label" for="param-treatment-'+indexParam+'">Trattamento</label>';
            html += '        <div class="col-sm-4">';
            html += '            <select class="custom-select col-12 param-treatment-'+indexParam+'" name="param-treatment">';
            $.each(treatments, function(index, treatment) {
                html += '               <option value="'+treatment.treatment_id+'">'+treatment.treatment_name+'</option>';
            });
            html += '            </select>';
            html += '        </div>';
            html += '    </div>';
            html += '    <div class="form-group row chart-input-'+windowIdx+'">';
            html += '        <label class="col-sm-2 col-form-label" for="param-chart-'+indexParam+'">Tipo grafico</label>';
            html += '        <div class="col-sm-4">';
            html += '            <select class="custom-select col-12 param-chart-'+indexParam+'" name="param-chart">';
            html += '                <option value="">Seleziona...</option>';
            html += '                <option value="line">Linea</option>';
            html += '                <option value="line_marker">Linea con punti</option>';
            html += '                <option value="point">Punti</option>';
            html += '                <option value="column">Barre</option>';
            html += '                <option value="areaspline">Area</option>';
            html += '            </select>';
            html += '        </div>';
            html += '        <label class="col-sm-2 col-form-label" for="param-color-'+indexParam+'">Colore linea</label>';
            html += '        <div class="col-sm-4">';
            html += '            <input autocomplete="off" class="form-control my-color param-color-'+indexParam+'" name="param-color" placeholder="Colore linea..." type="text" data-jscolor="">';
            html += '        </div>';
            html += '    </div>';
            html += '    <div class="form-group row">';
            html += '        <label class="col-sm-2 col-form-label" for="param-formule-'+indexParam+'">Formula</label>';
            html += '        <div class="col-sm-4">';
            html += '            <input aria-invalid="false" class="form-control valid param-formule-'+indexParam+'" name="param-formule" placeholder="Formula parametro..." type="text" value="">';
            html += '        </div>';
            html += '    </div>';
            html += '    <div class="form-group row ckb-toggled">';
            html += '        <label class="col-sm-2 col-form-label"></label>';
            html += '        <div class="col-sm-4">';
            html += '            <input class="param-min-val-'+indexParam+'" name="param-min-val" type="checkbox" data-onstyle="success" data-offstyle="primary" data-on="SI" data-off="NO" data-size="xs" data-style="android"> <label class="form-check-label" for="param-min-val-'+indexParam+'">&nbsp;Valori minimi</label>';
            html += '        </div><label class="col-sm-2 col-form-label"></label>';
            html += '        <div class="col-sm-4">';
            html += '            <input class="param-max-val-'+indexParam+'" name="param-max-val" type="checkbox" data-onstyle="success" data-offstyle="primary" data-on="SI" data-off="NO" data-size="xs" data-style="android"> <label class="form-check-label" for="param-max-val-'+indexParam+'">&nbsp;Valori massimi</label>';
            html += '        </div>';
            html += '    </div>';
            html += '    <div class="form-group row">';
            html += '        <div class="col-sm-12">';
            html += '            <button class="btn btn-sm btn-secondary del-param" data-pos="'+indexParam+'" type="button"><i class="ti-trash"></i> Elimina parametro</button>';
            html += '        </div>';
            html += '    </div>';
            html += '    <hr class="m-t-20">';
            html += '</div>';

            $('#all-my-params-'+windowIdx).append(html);

            // https://jscolor.com/docs/
            // initialize jscolo plugin
            colorArray[indexParam] = new JSColor('#all-my-params-'+windowIdx+' .param-color-'+indexParam);
            colorArray[indexParam].fromString('#'+param.color);

            // boostraptoggle switch for the minimum and maximum values
            $( ".ckb-toggled input[type=checkbox]" ).bootstrapToggle();

            // fill form with parameter metadata
            $('#all-my-params-'+windowIdx+' .param-name-'+indexParam).val(param.legend);
            $('#all-my-params-'+windowIdx+' .param-chart-'+indexParam).val(param.chartstyle);
            $('#all-my-params-'+windowIdx+' .param-treatment-'+indexParam).val(param.treatment);
            $('#all-my-params-'+windowIdx+' .param-formule-'+indexParam).val(param.formule);
            $('#all-my-params-'+windowIdx+' .param-min-val-'+indexParam).prop('checked', param.minval).trigger('change');
            $('#all-my-params-'+windowIdx+' .param-max-val-'+indexParam).prop('checked', param.maxval).trigger('change');

            // hide/show chart fields base on window's type
            if($('#window-type-'+windowIdx).val() == 'table')
                $('#all-my-params-'+windowIdx+' .chart-input-'+windowIdx).hide();
            else
                $('#all-my-params-'+windowIdx+' .chart-input-'+windowIdx).show();

            // increase index of parameters by 1
            indexParam++;
        });
    };

    /**
     * Function that retrieves metadata from server in order to dynamically build windows
     * No args needed
     */
    function autoGenerateWindows(){

        // get form element
        var form = $('#add-auto-windows');

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_automatic_macros',
            type: "post",
            dataType: "json",
            data: form.serialize()
        })
        .done(function(result) {

            // check result
            // if OK then fill central container with retrieved data
            // else take care of error
            if(result.res == 'OK'){
                // set title
                $('#settings-form h5').text('Aggiungi un nuovo pannello');

                var macros = result.macros;
                // checl if variable is defined
                if(macros){

                    // parse result and check it at least one window exists
                    windowsArray = JSON.parse(macros);
                    if(windowsArray.length > 0){
                        // loop through all windows
                        // for each macro build an html window to be added to central container
                        windowsArray.forEach(function(windowEl, index){
                            // use settimeout function in order to trasform the procedure in a asynchronous one
                            setTimeout(function(){
                                addNewWindow( windowEl );
                            }, 5);

                            // check if it is the last loop
                            if(index == windowsArray.length-1)
                                // at the end of the process hide preloader
                                $('.inner-preloader').hide();
                        });

                        // show success message
                        swal("Finestre aggiunte.", "Grazie, le finestre richieste sono state aggiunte automaticamente al pannello!", "success");
                        // hide modal -> trigger clean of the form
                        $('#auto-windows').modal('hide');
                        // show final buttons
                        $('#panel-save').show();
                    }
                    else{
                        // at the end of the process hide preloader
                        $('.inner-preloader').hide();
                        // warning message
                        swal("Attenzione", "Nessun parametro trovato con le caratteristiche specificate", "info");
                    }
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante la generazione automatica del pannello", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante la generazione automatica del pannello", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that retrieves metadata of a selected panel and fill central container
     *
     * @param {integer} pageId Panel ID
     */
    function editPanel(pageId){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_get_macros_by_page',
            type: "post",
            dataType: "json",
            data: {
                id: pageId
            },
        })
        .done(function(result) {

            // check result
            // if OK then fill central container
            // else take care of error
            if(result.res == 'OK'){
                // set title
                $('#settings-form h5').text('Modifica pannello');

                var panel = result.macros;
                // check if panel is defined
                if(panel){
                    // fill first form
                    $('#panel-id').val(panel.page_id);
                    $('#panel-name').val(panel.page_name);
                    $('#panel-group').val(panel.page_category);

                    // parse result and check it at least one window exists
                    windowsArray = JSON.parse(panel.macro_object);
                    // loop through all windows
                    // for each macro build an html window to be added to central container
                    windowsArray.forEach(function(windowEl, index){
                        // use settimeout function in order to trasform the procedure in a asynchronous one
                        setTimeout(function(){
                            addNewWindow( windowEl );
                        }, 5);

                        // check if it is the last loop
                        if(index == windowsArray.length-1)
                            // at the end of the process hide preloader
                            $('.inner-preloader').hide();
                    });
                }
                // show final buttons
                $('#panel-save').show();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del pannello", "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del pannello", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that duplicates selected panel
     *
     * @param {integer} pageId Panel ID
     */
    function duplicatePanel(pageId){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_vis_put_page_duplication',
            type: "post",
            dataType: "json",
            data: {
                id: pageId
            },
        })
        .done(function(result) {
            // check result
            // if TRUE then refresh jstree
            // else take care of error
            if(result){
                $('#group-json').jstree(true).refresh(true);
                // success message
                swal("Successo!", "Pannello duplicato correttamente", "success");
            }
            else{
                // error message
                swal("Errore!", "Errore durante la duplicazione del pannello", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante la duplicazione del pannello", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that deletes selected panel
     *
     * @param {integer} pageId Panel ID
     */
    function deletePanel(pageId){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        var jqxhr = $.ajax({
            url: '/str_ava_vis_del_page',
            type: "post",
            dataType: "json",
            data: {
                id: pageId
            },
        })
        .done(function(result) {
            // check result
            // if 1 then refresh jstree
            // if -1 show warninh message
            // else take care of error
            if(result == 1){
                $('#group-json').jstree(true).refresh(true);
                // success message
                swal("Successo!", "Il pannello è stato eliminato con successo", "success");
            }
            else if(result == -1){
                // warning message
                swal("Attenzione", "Il pannello è associato ad un sottogruppo in Validazione. Eliminare prima le relazioni dalla sezione Avanzate > Validazione", "warning");
            }
            else{
                // error message
                swal("Errore!", "Errore durante l'eliminazione del pannello.", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'eliminazione del pannello", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };
});

