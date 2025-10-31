// ANALYSER VARIABLES
var analyserToolOptions; // tool options
var analyserOptions; // user options
var exportinChartOptions; // highchats export options

var dateFrom;
var dateTo;

var validator;
var range;

const categorizedAggrs = ['rep_day', 'rep_week', 'rep_year'];

// disabble auto call highlightjs
hljs.initHighlighting.called = false;

/**
 * Document ready
 */
$(document).ready(function() {

    // !!FIRST MENU
{
    // !!MENU >> STRUMENTI
    /**
     * Change events for highcharts plugin options (font size...) -> Sanity checks
     */
    $("#exp-chart-title-font, #exp-chart-label-font, #exp-chart-legend-font").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 30 ? 30 : val && val < 5 ? 5 : val;
    });
    $("#chart-title-font, #chart-label-font, #chart-legend-font").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 30 ? 30 : val && val < 5 ? 5 : val;
    });
    $("#label-x-axis").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 0);
        this.value = val > 90 ? 90 : val;
    });

    /**
     * Click event on "Reset Impostazioni"
     */
    $("#reset-settings").on("click", function(e){
         e.preventDefault();
         // show confirm message
         swal({
            title: "Resetta le impostazioni",
            text: "Sei sicuro di voler resettare le impostazioni a quelle di default?",
            type: "warning",
            showCancelButton: true,
            confirmButtonClass: "btn-danger",
            confirmButtonText: "Si, conferma",
            cancelButtonText: "Annulla",
            closeOnConfirm: true
        },
        function(){

            // default settings
            analyserOptions = {
                general: {
                    // lista stazioni
                    stidEnabled: false,
                    altitudeEnabled: true,
                    allocationsEnabled: true,
                    limitsValueEnabled: true,
                    // lista macro
                    paramsEnabled: false,
                    // formato data
                    dateFormat: 'standard',
                    // estrazione dati
                    convEnabled: true,
                    // nome serie
                    treatmentEnabled: false,
                    windScale: 1 // default
                },
                tabulator: {
                    minmaxEnabled: false,
                    codesEnabled: true,
                    percEnabled: false,
                    filtersEnabled: false,
                    calcEnabled: false
                },
                highstocks: {
                    minmaxEnabled: false,
                    // notesEnabled: false,
                    // layout grafico online
                    subtitleEnabled: true,
                    navigatorEnabled: false,
                    // numberYaxis: 1,
                    minorGridEnabled: false,
                    hoverEventEnabled: true,
                    tooltipType: 'standard',
                    labelXangle: 0,
                    titleFontSize: 16,
                    labelFontSize: 11,
                    legendFontSize: 10,
                    numLabel: 15,
                    // layout immagine esportata
                    expWidth: 600,
                    expHeight: 400,
                    expTitleFontSize: 16,
                    expLabelFontSize: 11,
                    expLegendFontSize: 10,
                    expNumLabel: 8
                },
                filter: {
                   altitude: 0
                }
            };
            // reset form with new settings
            setOptions();

        });
    });

    /**
     * Click event on "Applica in locale"
     */
    $("#apply-settings").on("click", function(e){
        e.preventDefault();
        // apply options and show success message
        applyOptions();
        swal("Successo!", "Nuove impostazioni applicate con successo. Saranno visibili alla creazione di nuovi/e grafici/tabelle", "success");
    });

    /**
     * Click event on "Salva nel DB"
     */
    $("#save-settings").on("click", function(e){
        e.preventDefault();
        // apply options
        applyOptions();
        // save changes to database
        saveOptions();
    });

    /**
     * Click event on "Carica albero completo"
     */
    $('#all-tree').click(function(e){
        e.preventDefault();
        // show confirm message
        swal({
            title: "Albero Stazioni",
            text: "Sei sicuro di voler caricare l'albero completo delle stazioni?",
            showCancelButton: true,
            closeOnConfirm: true,
            confirmButtonText: "Si, carica!",
            cancelButtonText: "Annulla",
        }, function () {

            // load all nodes of the json tree plugin
            $('#ext-json').jstree().load_all();
        });
    });
    // END MENU >> STRUMENTI

    // !!MENU >> DATI

    // initialize inputmask plugin
    $("#percent-data").inputmask('numeric',{min:0, max:100, allowMinus: false});

    /**
     * Click event on "Conferma" button inside the "Modifica % copertura" modal
     */
    $("#percent-data-confirm").on('click', function(e){
        e.preventDefault();

        // if % is empty set the default value equal to 75%
        if( $("#percent-data").val() == '' )
            $("#percent-data").val(75);

        // update activeMacro with new %
        activeMacro.macro.percent_data = $("#percent-data").val();
        // refresh tool's content with active macro metadata
        loadActiveMacro();
        // update tool contents
        $('#copertura').text($("#percent-data").val()+'%');
        // hide modal
        $('#dati-copertura').modal("hide");
    });

    /**
     * Click event on buttons inside the "Modifica % copertura" modal
     */
    $(".percent-data-value").on('click', function(e){
        e.preventDefault();
        // get button's value
        var value = parseFloat($(this).data('val'));
        // set input value
        $("#percent-data").val(value);
        // trigger "Conferma" event
        $("#percent-data-confirm").trigger('click');
    });

    /**
     * Click event on "Non definiti" options
     */
    $('#hide-undefined').click(function(e){
        e.preventDefault();
        // get value BEFORE the modification
        var now = $(this).data("hidenull");
        // get options from the active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // if now value is true then new value is false => show nulls
        // else new value is false => hide nulls and create a categorized chart
        if (now == true){
            // show confirm message
            swal({
                title: "Visualizza dati non definiti",
                text: "Sei sicuro di voler visualizzare i dati non definiti (null)?",
                type: "warning",
                showCancelButton: true,
                confirmButtonClass: "btn-danger",
                confirmButtonText: "Si, visualizza",
                cancelButtonText: "Annulla",
                closeOnConfirm: false
            },
            function(){
                // update tool's contents
                $('#hide-undefined').data("hidenull", false);
                $('#hide-undefined').html('Non definiti <em>(null)</em> : <strong>visualizzati</strong>');

                // if the active component is of type chart and the chart has already been initialized
                // then destroy it and reset the global variable
                // check that it is a chart tab and the chart is initialized
                if(componentState.type == 'chart' && chart[componentState.id]){
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }
                // trigger click on button "Aggiorna"
                $("#update-data").trigger('click');
                // show success message
                swal("Fatto!", "Ora potrai visualizzare i dati non definiti (null)", "success");
            });

        }
        else{
            // show confirm message
            swal({
                title: "NASCONDI dati non definiti",
                text: "Sei sicuro di voler nascondere i dati non definiti (null)?",
                type: "warning",
                showCancelButton: true,
                confirmButtonClass: "btn-danger",
                confirmButtonText: "Si, nascondi",
                cancelButtonText: "Annulla",
                closeOnConfirm: false
            },
            function(){
                $('#hide-undefined').data("hidenull", true);
                $('#hide-undefined').html('Non definiti <em>(null)</em> : <strong>nascosti <i class="mdi mdi-check text-danger"></i></strong>');
                // if the active component is of type chart and the chart has already been initialized
                // then destroy it and reset the global variable
                if(componentState.type == 'chart' && chart[componentState.id]){
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }
                // trigger click on button "Aggiorna"
                $("#update-data").trigger('click');

                swal("Fatto!", "Ora i dati non definiti (null) vengono nascosti", "success");
            });
        }
    });
    // END MENU >> DATI

    // !!MENU >> VALIDITA
    /**
     * Click event on validity codes sub-menu
     */
    $(".valcode-menu a.dropdown-item").on('click', function(e){
        e.preventDefault();
        // get selected operator
        var operator =  $(".valcode-menu .validation-operators button.sel").text();

        // if operator is = and you have not selected All data
        if( operator == '=' && $(this).data("id") != null ){
            // reset selections contents (class and icon)
            $('.valcode-menu a.dropdown-item').not('[data-id]').removeClass('sel');
            $('.valcode-menu a.dropdown-item').not('[data-id]').find('i').remove();

            // if it has class sel, user is deactivating it...
            // check that at least one item remains selected otherwise block it
            if( $(this).hasClass('sel') && $(".valcode-menu a.dropdown-item.sel").length == 1 ){
                return false;
            }

            // toggle class sel
            $(this).toggleClass('sel');
            // take care of check icon
            if( $(this).find('i').length != 0)
                $(this).find('i').remove();
            else
                $(this).append(' <i class="mdi mdi-check text-danger"></i>');
        }
        else{

            // reset selections contents (class and icon)
            $(".valcode-menu a.dropdown-item").removeClass('sel');
            $(".valcode-menu a.dropdown-item").find('i').remove();
            // add class sel and check icon
            $(this).addClass('sel');
            $(this).append(' <i class="mdi mdi-check text-danger"></i>');
        }

        // get selected code
        var code = $(this).data("id");
        var validity;

        // create the validity filter based on selected operator and code
        if(code == null)
            validity = null;
        else{

            validity = [];
            // loop through all selected codes and for each item build a filter
            // to be pushed inside an array
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){

                validityStr = operator+' '+$(this).data("id");
                validity.push(validityStr);
            });
        }

        // get active component options
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // if the component is not of type windorse
        // then update active macro and refresh tool contents
        if(componentState.windrose != true){
            activeMacro.macro.validity_code = (validity ? validity.join(', ') : validity);
            // refresh tool's content with active macro metadata
            loadActiveMacro();
        }
    });

    /**
     * Click event on validity codes sub-menu
     */
    $(".valcode-menu .validation-operators button").on('click', function(e){
        e.preventDefault();

        // get previous selected operator
        var previousOperator = $(".valcode-menu .validation-operators button.sel").text();
        // if it is equal to = and the new one is different from the previous one and there is at least one code selected
        if( previousOperator == '=' && $(this).text() != previousOperator && $(".valcode-menu a.dropdown-item.sel").length > 1){

            // remove selection elements (classes and icons)
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){
                $(this).removeClass('sel');
                $(this).find('i').remove();
            });

            // select default code
            $(".valcode-menu a.dropdown-item.default-val").addClass('sel');
            $(".valcode-menu a.dropdown-item.default-val").append(' <i class="mdi mdi-check text-danger"></i>');
        }

        // update sel class adding it to the clicked button
        $(".valcode-menu .validation-operators button").removeClass('sel');
        $(this).addClass('sel');

        var operator =  $(".valcode-menu .validation-operators button.sel").text();
        var validity;

        // create the validity filter based on selected operator and code
        if($(".valcode-menu a.dropdown-item.sel").length == 1 && $(".valcode-menu a.dropdown-item.sel").data('id') == null)
            validity = null
        else{

            validity = [];
            // loop through all selected codes and for each item build a filter
            // to be pushed inside an array
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){

                validityStr = operator+' '+$(this).data("id");
                validity.push(validityStr);
            });
        }
        // get active component options
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;
        // if the component is not of type windorse
        // then update active macro and refresh tool contents
        if(componentState.windrose != true){
            activeMacro.macro.validity_code = validity.join(', ');
            // refresh tool's content with active macro metadata
            loadActiveMacro();
        }
    });
    //  END MENU >> VALIDITA


    // !!MENU >> MACRO

    // START CATEGORIES
    /**
     * Hide modal event
     */
    $('#category-macro').on('hidden.bs.modal', function(e){
        e.preventDefault();
        // reset categories form
        $('#new-cat-id').val("");
        $('#new-cat-name').val("");
        $('#new-cat-public').prop('checked', false);

        $('#new-cat-groups').val([]);
        $('#new-cat-groups').trigger('change');
        $('#new-cat-groups').prop('disabled', false);
    });

    /**
     * Click event on "Modifica categoria" button
     */
    $("#categories-table").on('click', '.edit_category', function(e){
        e.preventDefault();

        // get category id stored inside the row element
        var catid = $(this).parent().parent().data('id');
        console.log(catid);

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ana_get_category_byid',
            type: "post",
            dataType: "json",
            data: {
                id: catid
            }
        })
        .done(function(result) {
            // check result
            // if OK then fill form with retrived metadata
            // else show error message
            if(result.res == 'OK'){
                var category = result.category;

                $('#new-cat-id').val(category.category_id);
                $('#new-cat-name').val(category.category_name);
                $('#new-cat-public').prop('checked', category.category_public);
                $('#new-cat-public').trigger('change');

                $('#new-cat-groups').val(category.category_groups);
                $('#new-cat-groups').trigger('change');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio della categoria", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della categoria", "error");
        });
    });

    /**
     * Click event on "Elimina categoria" button
     */
    $("#categories-table").on('click', '.delete_category', function(e){
        e.preventDefault();

        // get category id stored inside the row element
        var catid = $(this).parent().parent().data('id');
        console.log(catid);

        // show confirm message
        swal({
            title: "Elimina categoria",
            text: "Sei sicuro di voler eliminare la categoria? Saranno eliminate anche tutte le macro ad essa associata!",
            type: "warning",
            showCancelButton: true,
            confirmButtonClass: "btn-danger",
            confirmButtonText: "Si, elimina",
            cancelButtonText: "Annulla",
            closeOnConfirm: false
        },
        function(){
            // delete category via an ajax call
            $.ajax({
                type: 'post',
                url: '/str_ana_del_category',
                data: {
                    id: catid
                }
            }).done(function(result) {
                // check result
                // if TRUE then success and reload categories list
                // else show error messaeg
                if(result){
                    swal("Successo", "Categoria eliminata con successo", "success");
                    loadCategories();
                    // refresh json
                    $('#macro-json').jstree(true).refresh(true);
                }
                else
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della categoria", "error");

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione della categoria", "error");
            });
        });
    });

    /**
     * Change event on "Pubblica" switch
     */
    $("#new-cat-public").on("change", function(e){
        e.preventDefault();
        // get old state
        var state = $(this).prop('checked')

        // if checked then empty select2 of groups and disable it
        // else enable it
        if(state){
            $('#new-cat-groups').val([]);
            $('#new-cat-groups').trigger('change');
            $('#new-cat-groups').prop("disabled", true);
        }
        else{
            $('#new-cat-groups').prop("disabled", false);
        }
    });

    /**
     * Submit event
     */
    $('#new-category').on('submit', function (e) {
        e.preventDefault();

        // get form element
        var form = $("#new-category");
        // get id stored in the form
        var id = $("#new-cat-id").val();
        var msg_err;
        var msg_ok;

        // different type of messages based on id value
        // if id is null then it's an insert action else it's an update
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

        // put data via an ajax call
        $.ajax({
            type: 'post',
            url: '/str_ana_put_category',
            data: form.serialize()
        }).done(function(result) {

            // check result
            // if OK then clean form's fields and refresh categories
            if(result.res == 'OK'){
                swal("Successo", msg_ok, "success");
                loadCategories();

                $('#new-cat-id').val("");
                $('#new-cat-name').val("");
                $('#new-cat-public').prop('checked', false);

                $('#new-cat-groups').val([]);
                $('#new-cat-groups').trigger('change');
                $('#new-cat-groups').prop('disabled', false);

                $('#macro-json').jstree(true).refresh(true);
            }
            else
                // error message
                swal("Errore!", msg_err, "error");

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiunta ", "error");
        });
    });
    // END CATEGORIES

    // START MACRO

    // HIDE / SHOW FIELDS IN MACRO FORM
    // destroy and hide multiple validity select2
    // visible only if the selected operator is equal to =
    $("#multiple-validity-code").select2('destroy');
    $("#multiple-validity-code").attr('style','display: none');
    // hide moving average field
    $("#hide-moving-average").hide();
    // hide parameter container
    $('#macro-param-details').hide();

    /**
     * Show modal event
     */
    $('#settings-macro').on('shown.bs.modal', function () {
        // resize select2 on modal open event
        if( $("#macro-validity-operator").val() == '='){
            $("#multiple-validity-code").select2('destroy');
            $("#multiple-validity-code").select2();
        }
    });

    /**
     * Hide modal event
     */
    $('#settings-macro').on('hidden.bs.modal', function(e){
        e.preventDefault();

        // clear parameter form
        clearParamsMacro();
        // set tab "Generali" as the active one
        $('#macro-tab a[href="#macro-generali"]').trigger('click');
    });

    /**
     * Click event on "Aggiungi carattere" button
     */
    $("#add-cr-1").on('click', function(e){
        e.preventDefault();
        // update input value for y axis label
        $('#macro-label-yaxis').val($('#macro-label-yaxis').val() + 'μ');
    });

    /**
     * Click event on "Aggiungi carattere" button
     */
    $("#add-cr-2").on('click', function(e){
        e.preventDefault();
        // update input value for y axis label
        $('#macro-label-yaxis').val($('#macro-label-yaxis').val() + '²');
    });

    /**
     * Click event on "Aggiungi carattere" button
     */
    $("#add-cr-3").on('click', function(e){
        e.preventDefault();
        // update input value for y axis label
        $('#macro-label-yaxis').val($('#macro-label-yaxis').val() + '³');
    });

    /**
     * Click event on "Applica in locale" button
     */
    $("#apply-macro").on('click', function(e){
        e.preventDefault();

        // update fileds of active macro with data selected inside the form
        activeMacro.macro.name = $("#macro-name").val();
        activeMacro.macro.description = $("#macro-desc").val();

        // get active component object
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        if(activeMacro.macro.aggregation != $("#macro-aggregation").val())
            activeMacro.macro.reload = true;

        activeMacro.macro.aggregation = $("#macro-aggregation").val();
        activeMacro.macro.percent_data = $("#macro-valid-data").val();

        var validity;
        var operator = $("#macro-validity-operator").val();
        console.log(operator);
        // multiple codes
        if(operator == '='){
            var codes = $("#multiple-validity-code:visible").val();
            codes.forEach(function(el, idx){
                codes[idx] = '= '+el;
            });
            validity = codes.join(', ');
        }
        else{
            console.log('single code');
            console.log($("#single-validity-code").val());
            if( $("#single-validity-code").val() == "" ){
                validity = null;
            }
            else{
                validity = $("#macro-validity-operator").val()+' '+$("#single-validity-code").val();
            }
        }

        activeMacro.macro.validity_code = validity;

        activeMacro.macro.label_yaxis = $("#macro-label-yaxis").val();
        activeMacro.macro.step_yaxis = ( $("#macro-label-y-step").val() != '' ? parseFloat($("#macro-label-y-step").val()) : null );
        // check that it is a chart tab and the chart is initialized
        if( componentState.type == 'chart' && chart[componentState.id] ){
            chart[componentState.id].setTitle(
                { text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>' }
            );

            var options = {
                yAxis: {
                    title: {
                        text: activeMacro.macro.label_yaxis
                    },
                    tickInterval: activeMacro.macro.step_yaxis
                }
            };
            chart[componentState.id].update(options);

        }

        activeMacro.macro.num_yaxis = parseInt($("#macro-num-yaxis").val());

        var param_idx = $('#macro-param-main option:selected').data('idx');
        if (param_idx != null ){
            activeMacro.params[param_idx].name = $("#macro-param-name").val();
            activeMacro.params[param_idx].legend = $("#macro-param-legend").val();
            activeMacro.params[param_idx].formule = $("#macro-param-formule").val();
            activeMacro.params[param_idx].decimals = $("#macro-param-decimal").val();
            activeMacro.params[param_idx].treatment = $("#macro-param-treatment").val();
            if($("#macro-param-treatment").val() == 'sldavg'){
                activeMacro.params[param_idx].window = $("#macro-param-moving-window").val();
            }
            activeMacro.params[param_idx].minval = $('#macro-param-min').is(':checked');
            activeMacro.params[param_idx].maxval = $('#macro-param-max').is(':checked');
            activeMacro.params[param_idx].chartstyle = $("#macro-param-chartype").val();
            activeMacro.params[param_idx].color = $("#macro-param-chartcolor").val().slice(1);
            activeMacro.params[param_idx].line_width = parseInt($("#macro-param-charline").val());
            activeMacro.params[param_idx].axis = parseInt($("#macro-param-axis").val());
        }

        // refresh tool's content with active macro metadata
        loadActiveMacro();

        // check if the number of axes set is different from that actually present on the chart
        if( chart[componentState.id] && activeMacro.macro.num_yaxis != chart[componentState.id].yAxis.length){
            var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
            // remove all bands plot lines
            $.each(plotLinesAndBands, function(key, line){
                chart[componentState.id].yAxis[0].removePlotLine('band'+key);
            });
            // take care of y axis
            addYaxis();
        }

        // this case is triggered only when user click edit button near a parameter inside the active macro container (bottom right)
        if(param_idx != null)
            $('#macro-param-main option[data-idx="'+param_idx+'"]').prop('selected', true);

        // trigger click on button "Aggiorna"
        $("#update-data").trigger('click');
    });

    /**
     * Click event on "Salva nel DB" button
     */
    $(".save-macro").on('click', function(e){
        e.preventDefault();

        // write a info message in the log container
        log('SAVE', 'Salvataggio macro...');

        if( $('#macro-category').val() == -1 ){
            // warning message
            swal("Attenzione!", "E' necessario associare la macro ad una categoria (Modifica macro -> Categoria)", "info");
            return;
        }

        // trigger click on button "Applica" in order to apply updates to active macro
        $("#apply-macro").trigger('click');

        // retrieve macro id stored inside the active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var mcid = activeTabElement.config.componentState.macroId;

        // save macro via an ajax call
        var jqxhr = $.ajax({
            url: '/str_ana_put_macro',
            type: "post",
            dataType: "json",
            data: {
                mcid : mcid,
                mccat: $('#macro-category').val(),
                macro: JSON.stringify(activeMacro)
            }
        })
        .done(function(result) {

            // check result
            // if ok the show success message and refresh json tree plugin
            if (result.res == 'OK'){
                activeTabElement.config.componentState.macroId = result.macro_id;

                // write a info message in the log container
                log('SAVE', 'Salvataggio avvenuto con successo');
                // success message
                swal("Successo!", "Macro salvata correttamente", "success");
                $('#macro-json').jstree(true).refresh(true);
            }

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Tutto andato male", "error");
        });
    });

    /**
     * Click event on "Elimina parametro" button
     */
    $("#macro-param-details").on('click', ".del-param", function(e){
        e.preventDefault();
        console.log('click');
        // get parameter index inside the array in order to remove it from active macro
        var position = $('#macro-param-main option:selected').data('idx');

        // update active macro parameters
        activeMacro.params.splice(position, 1);
        // clear parameter form
        clearParamsMacro();
        // refresh tool's content with active macro metadata
        loadActiveMacro();
    });

    /**
     * Change event on "Cod. Validità" fields
     */
    $("#macro-validity-operator").on("change", function(e){
        e.preventDefault();
        // check selected operator
        // if it's equal to = then allow to pick multiple codes to do an OR operation
        if( $(this).val() == "="){
            // hide starnd select
            $('#single-validity-code').hide();

            // show select2 select with multiple attribute
            // pre-select default codes
            var optionDef = $("#multiple-validity-code option.default-val").val();
            $("#multiple-validity-code").attr('style', '');
            // initialize select2 plugin
            $("#multiple-validity-code").select2();
            $("#multiple-validity-code").val([optionDef]).trigger('change.select2')
        }
        else{
            // show standard select
            var optionDef = $("#single-validity-code option.default-val").val();
            $('#single-validity-code').show();
            // pre-select default option
            $('#single-validity-code').val(optionDef);

            // Checking if select2 plugin is initialized
            if($("#multiple-validity-code").hasClass("select2-hidden-accessible") ){
                // destroy and hide it
                $("#multiple-validity-code").select2('destroy');
                $("#multiple-validity-code").attr('style','display: none');
            }
        }
    });

    /**
     * Change event on "Cod. Validità" fields
     */
    $("#single-validity-code").on("change", function(e){
        e.preventDefault();
        // if "Tutti i dati" has been selected then disable operator field
        // otherwise enable it and pre-select default operator
        if( $(this).val() == ""){
            $("#macro-validity-operator").prop("disabled", true);
        }
        else{
            $("#macro-validity-operator").prop("disabled", false);
            $("#macro-validity-operator .default-val").prop("selected", true);
        }
    });

    /**
     * Change event on "Numero assi Y" field
     */
    $("#macro-num-yaxis").on("change", function(e){
        var nAxis = parseInt($(this).val());

        // loop through all active macro parameters
        // for each element check if linked Y axis index is greater than the number of axes associated with the macro
        $.each(activeMacro.params, function(key, param){
            // if true then reset parameter axis and link it to the first one
            if(param.axis > nAxis)
                param.axis = 1;
        });

        /**
         * if number of axes is greater than 1 then enable parameter "Asse" field
         * and upadte the maximum selectable value
         * else disable "Asse" field and set the value to 1
         */
        if(nAxis > 1){
            $("#macro-param-axis").prop('disabled', false);
            $("#macro-param-axis").attr('max', nAxis);
        }
        else{
            $("#macro-param-axis").prop('disabled', true);
            $("#macro-param-axis").attr('max', 1);
            $("#macro-param-axis").val(1);
        }
    });

    /**
     * Change event on "Parametro" field
     */
    $("#macro-param-main").on("change", function(e){
        e.preventDefault();

        // check value of selected parameter
        // if -1 then reset form and hide it
        // else fill it with metadata from active macro object
        if($(this).val() != -1){
            var params = activeMacro.params;
            // get parameter position
            var paramIdx = $('#macro-param-main option:selected').data('idx');
            // retrieve parameter by index from active macro object
            var paramObj = params[paramIdx];

            console.dir(paramObj);

            // "name":"Nivometro",
            //  "color":65280,
            //  "marks":false,
            //  "thick":1,
            //  "legend":"Chamois - Lac de Lou - 2020 Nivometro [cm]",
            //  "formule":"y=x",
            //  "decimals":1,
            //  "st_pr_id":669,
            //  "treatment":0,
            //  "chartstyle":0,
            //  "lowerlimit":null,
            //  "upperlimit":null,
            //  "column_name":"Nivometro [cm] </br>Chamois - Lac de Lou",
            //  "custom_axis":false

            // fill form with parameter's metadata
            $("#macro-param-details h5 span").text(paramObj.name+' di '+paramObj.station);
            $("#macro-param-name").val(paramObj.name);
            $("#macro-param-legend").val(paramObj.legend);
            $("#macro-param-formule").val(paramObj.formule);
            $("#macro-param-decimal").val(paramObj.decimals);
            $("#macro-param-treatment").val(paramObj.treatment).trigger('change');
            $('#macro-param-moving-window').val(paramObj.window == null ? 8 : paramObj.window);
            $('#macro-param-min').prop("checked", ( paramObj.minval == null ? false : paramObj.minval) );
            $('#macro-param-max').prop("checked", ( paramObj.maxval == null ? false : paramObj.maxval) );
            $("#macro-param-chartype").val(paramObj.chartstyle);
            $("#macro-param-axis").val(paramObj.axis ? paramObj.axis : 1);

            document.querySelector('#macro-param-chartcolor').jscolor.fromString('#'+paramObj.color);

            // take care of slider
            range.val(paramObj.line_width).change();
            range.rangeslider('update', true);

            // show form
            $('#macro-param-details').show();
        }
        else{
            // hide form
            $('#macro-param-details').hide();
        }
    });

    /**
     * Change event on "Trattamento" field
     */
    $("#macro-param-treatment").on('change', function(e){
        e.preventDefault();
        // check selected value
        // if it is "Media mobile" then show "FIenstra media mobile"
        // else hide it
        var type = $(this).val();
        if (type == 'sldavg'){
            $("#hide-moving-average").show('slow');
        }else{
            $("#hide-moving-average").hide('slow');
        }
    });
    // END MENU >> MACRO
}// END FIRST MENU

    // !!SECOND MENU
{
    // CLICK EVENTS

    // Prevent the dropdown of the start date selection from closing after the click
    $('#start-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // Prevent the end date selection dropdown from closing after the click
    $('#end-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // Prevent the dropdown of validity codes from closing after the click
    $('#validity-codes .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // DATES INPUT

    /**
     * Click event on "Oggi"
     */
    $("#start-date-today").on('click', function(e){
        e.preventDefault();

        console.log("start-date-today");
        // retrieve dates
        dateFrom = moment().utc().format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');

    });

    /**
     * Click event on "Primo gg mese"
     */
    $("#start-date-fdm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdm");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "Primo gg anno"
     */
    $("#start-date-fdy").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdy");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "Primo gg mese corrente"
     */
    $("#start-date-curr-fdm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdm");
        // retrieve dates
        dateFrom = moment().format('01/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "Primo gg anno corrente"
     */
    $("#start-date-curr-fdy").on('click', function(e){
        e.preventDefault();

        console.log("start-date-fdy");
        // retrieve dates
        dateFrom = moment().format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "- GG"
     */
    $("#start-date-pd").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pa");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "- MM"
     */
    $("#start-date-pm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pm");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "- YY"
     */
    $("#start-date-pa").on('click', function(e){
        e.preventDefault();

        console.log("start-date-pa");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "+ DD"
     */
    $("#start-date-nd").on('click', function(e){
        e.preventDefault();

        console.log("start-date-nd");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "+ MM"
     */
    $("#start-date-nm").on('click', function(e){
        e.preventDefault();

        console.log("start-date-nm");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "+ YY"
     */
    $("#start-date-na").on('click', function(e){
        e.preventDefault();

        console.log("start-date-na");
        // retrieve dates
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    /**
     * Click event on "Oggi"
     */
    $("#end-date-today").on('click', function(e){
        e.preventDefault();

        console.log("end-date-today");
        // retrieve dates
        dateTo = moment().utc().format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "Copia data inizio"
     */
    $("#end-date-copy").on('click', function(e){
        e.preventDefault();

        console.log("end-date-copy");
        var t = moment(dateFrom, 'DD/MM/YYYY HH:mm');

        // check if start date is equal than today
        // if true then set as max hour as now
        // else set 23:59
        if(t.isSame(moment(), 'day'))
            dateTo = moment().utc().format('DD/MM/YYYY HH:59');
        else
            dateTo = t.format('DD/MM/YYYY 23:59');

        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "Ultimo GG mese"
     */
    $("#end-date-ldm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-ldm");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').endOf('month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "Ultimo GG anno"
     */
    $("#end-date-ldy").on('click', function(e){
        e.preventDefault();

        console.log("end-date-ldy");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').format('31/12/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "- GG"
     */
    $("#end-date-pd").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pa");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "- MM"
     */
    $("#end-date-pm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pm");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "- YY"
     */
    $("#end-date-pa").on('click', function(e){
        e.preventDefault();

        console.log("end-date-pa");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "+ GG"
     */
    $("#end-date-nd").on('click', function(e){
        e.preventDefault();

        console.log("end-date-nd");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "+ MM"
     */
    $("#end-date-nm").on('click', function(e){
        e.preventDefault();

        console.log("end-date-nm");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Click event on "+ YY"
     */
    $("#end-date-na").on('click', function(e){
        e.preventDefault();

        console.log("end-date-na");
        // retrieve dates
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // refresh node with MM allocations
        $('#ext-json').jstree(true).refresh_node("-9999");

        // check range validity -> include/common/global.js
        // - correct format of dates
        // - end date equal or greater than start date
        // - start date and end date not in the future
        validDates($("#date-start").val(), dateTo, 'date-end');
    });

    /**
     * Change event on aggregation field
     */
    $("#time-period").on("change", function(e){
        e.preventDefault();
        // update active macro and set variable in order to force the refresh of contents
        activeMacro.macro.aggregation = $(this).val();
        activeMacro.macro.reload = true;
        // refresh tool's content with active macro metadata
        loadActiveMacro();
    });

    // LOAD DATA WITH SELECTED OPTIONS
    /**
     * Click event on "Aggiorna" button
     */
    $("#update-data").on("click",function(e){

        e.preventDefault();

        // get dates range
        dateFrom = $("#date-start").val();
        dateTo = $("#date-end").val();

        // check if dates are valid else return and do nothing
        if( ! validDates(dateFrom, dateTo, 'date-start') ){
            // warning message
            swal('Attenzione!', 'Date inserite non valide', 'warning');
            return;
        }

        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // loadActiveMacro();

        // if activeMacro has no parameters and it isn't a windrose
        // then reset chart or table and return from event
        if (componentState.windrose != true && activeMacro.params.length == 0){
            swal('Info', 'Nessun parametro selezionato!', 'info');
            console.log('Nessun parametro selezionato!');

            // destroy chart or table if it was already created
            if(componentState.type == 'chart' && componentState.multiple == false){
                if(chart[componentState.id]){
                    console.log('Destroy chart');
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }
            }
            else{
                if(table[componentState.id]){
                    console.log('Destroy table');
                    table[componentState.id].destroy();
                    table[componentState.id].clearData();
                    table[componentState.id] = null;
                }
            }
            return;
        }
        // var params = activeMacro.params;

        // if there is at least 1 parameter then continue...
        // 2 cases: chart or table visualization
        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // if the active tab is of type chart
        if(componentState.type == 'chart'){

            // windrose case
            // unique case where activeMacro can be empty
            if(componentState.windrose == true){
                // always destroy chart and reload data
                if( chart[componentState.id] ){
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }
                // create windrose chart
                createChartWR(componentState.windroseId);
            }
            // per year
            // activeMacro with max 1 parameter
            else if( componentState.perYear == true ){
                // always destroy chart and reload data
                if( chart[componentState.id] ){
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }
                // create chart per year
                createChartPerYear();
            }
            // case of one chart per macro's parameter
            else if( componentState.multiple == true ){

                // if multiple charts have already been created then loop on the global variable that holds them
                if(multipleCharts[componentState.id] && multipleCharts[componentState.id].length > 0){

                    // for each element, destroy it and reset global variable
                    $.each(multipleCharts[componentState.id], function(index, el){
                        el.destroy();
                    });
                    $('#chart_container_'+componentState.id).empty();
                    multipleCharts[componentState.id] = null;
                }

                // initialize array in the global variable
                multipleCharts[componentState.id] = [];
                // create multiple charts
                addMultipleCharts();
            }
            // check if option "VIsualizza null" is enable and selected aggregation is not of type "categorized chart"
            // case: chart with x-axis datetime
            else if( $('#hide-undefined').data("hidenull") == false && categorizedAggrs.every(function(v) { return activeMacro.macro.aggregation.indexOf(v) == -1; }) ){

                // if chart already created
                // AND the settings are different from the chart status OR if reload field is true
                if(
                    chart[componentState.id] &&
                    ( analyserOptions.highstocks.navigatorEnabled != chart[componentState.id].options.navigator.enabled || activeMacro.macro.reload == true )
                ){

                    console.log('navigatore abilitato');
                    console.log('destroy e settaggio num axis');
                    // destroy chart
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }

                // If the navigator is activated AND
                // if the active macro has the number of axes > 1
                // - bring the number of axes to 1
                // - associate all parameters with axis 1
                if(analyserOptions.highstocks.navigatorEnabled && activeMacro.macro.num_yaxis > 1){
                    // warning message
                    swal('Navigatore abilitato!', 'Non è possibile avere più di un asse Y: gli assi aggiuntivi sono stati disabilitati', 'info');
                    activeMacro.macro.num_yaxis = 1;
                    activeMacro.params.forEach(function(param){
                        param.axis = 1;
                    });
                    // refresh tool's content with active macro metadata
                    loadActiveMacro();
                }

                // if chart is null then initialize it
                if( !chart[componentState.id] ){
                    console.log("Create chart");
                    createChart();
                }
                else{
                    // update chart options
                    chart[componentState.id].zoomOut();
                    chart[componentState.id].setTitle(
                        { text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>' },
                        { text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ) }
                    );
                    var options = {
                        yAxis: {
                            title: {
                                text: activeMacro.macro.label_yaxis
                            },
                            tickInterval: activeMacro.macro.step_yaxis
                        }
                    };
                    chart[componentState.id].update(options);

                    // must take into consideration the navigator axis if active
                    var navigatorAxis = 0;
                    if(chart[componentState.id] && chart[componentState.id].options.navigator.enabled )
                        navigatorAxis = 1;

                    // check if the number of axes set is different from that actually present on the chart
                    if( chart[componentState.id] && chart[componentState.id].yAxis.length != (activeMacro.macro.num_yaxis + navigatorAxis)){
                        var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
                        // remove all bands plot lines
                        $.each(plotLinesAndBands, function(key, line){
                            chart[componentState.id].yAxis[0].removePlotLine('band'+key);
                        });

                        var diff = activeMacro.macro.num_yaxis - chart[componentState.id].yAxis.length + navigatorAxis;
                        // I need to add |diff| axes
                        if(diff > 0){

                            for(; diff > 0; diff --){
                                chart[componentState.id].addAxis({ // Secondary yAxis
                                    startOnTick: false,
                                    endOnTick: false,
                                    isInternal: false,
                                    lineWidth: 1.5,
                                    opposite: true,
                                    gridLineWidth : 0
                                });
                            }
                        }
                        // I need to remove |diff| axes
                        else{

                            diff = diff*(-1); //lo riporto positivo
                            var len = chart[componentState.id].yAxis.length;
                            for(var key = 1; key <= diff; key++){
                                chart[componentState.id].yAxis[len-key].remove(true);
                            }

                            // reactivate grid
                            if(activeMacro.macro.num_yaxis == 1){
                                var options = {
                                    yAxis:  {
                                        gridLineWidth : 1
                                    }
                                };
                                chart[componentState.id].update(options);
                            }
                        }
                    }
                }
                // add parameters series to chart
                addSeriesToChart();
            }
            // chart with categorized x axis
            else{

                // if chart already created
                // AND the settings are different from the chart status OR if reload field is true
                if(
                    chart[componentState.id] &&
                    ( analyserOptions.highstocks.navigatorEnabled != chart[componentState.id].options.navigator.enabled || activeMacro.macro.reload == true )
                ){

                    console.log('navigatore abilitato');
                    console.log('destroy e settaggio num axis');
                    // destroy chart and reset global variable
                    chart[componentState.id].destroy();
                    chart[componentState.id] = null;
                }

                // If the navigator is activated AND
                // if the active macro has the number of axes > 1
                // - bring the number of aces to 1
                // - associate all parameters with axis 1
                if(analyserOptions.highstocks.navigatorEnabled && activeMacro.macro.num_yaxis > 1){
                    swal('Navigatore abilitato!', 'Non è possibile avere più di un asse Y: gli assi aggiuntivi sono stati disabilitati', 'info');
                    activeMacro.macro.num_yaxis = 1;
                    activeMacro.params.forEach(function(param){
                        param.axis = 1;
                    });
                    // refresh tool's content with active macro metadata
                    loadActiveMacro();
                }

                /**
                 * Check type of aggregation: in the following cases "rep_day, rep_week and rep_year" use x labes formatted by server
                 * Otherwise timeseries data -> to be formatted with moment from utc
                 */
                var labelsFlag = ( categorizedAggrs.every(function(v) { return activeMacro.macro.aggregation.indexOf(v) == -1; }) );
                if( !chart[componentState.id] ){
                    console.log("Create chart");
                    // create categorized chart
                    createChartCategories( labelsFlag );
                }
                else{
                    // reset chart options
                    chart[componentState.id].zoomOut();
                    chart[componentState.id].setTitle(
                        { text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>' },
                        { text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ) }
                    );
                    var options = {
                        yAxis: {
                            title: {
                                text: activeMacro.macro.label_yaxis
                            },
                            tickInterval: activeMacro.macro.step_yaxis
                        }
                    };
                    chart[componentState.id].update(options);

                    // must take into account the navigator axis if active
                    var navigatorAxis = 0;
                    if(chart[componentState.id] && chart[componentState.id].options.navigator.enabled )
                        navigatorAxis = 1;

                    // check if the number of axes set is different from that actually present on the chart
                    if( chart[componentState.id] && chart[componentState.id].yAxis.length != (activeMacro.macro.num_yaxis + navigatorAxis)){
                        var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
                        // remove all bands plot lines
                        $.each(plotLinesAndBands, function(key, line){
                            chart[componentState.id].yAxis[0].removePlotLine('band'+key);
                        });

                        var diff = activeMacro.macro.num_yaxis - chart[componentState.id].yAxis.length + navigatorAxis;
                        // I need to add |diff| aces
                        if(diff > 0){

                            for(; diff > 0; diff --){
                                chart[componentState.id].addAxis({ // Secondary yAxis
                                    startOnTick: false,
                                    endOnTick: false,
                                    isInternal: false,
                                    lineWidth: 1.5,
                                    opposite: true,
                                    gridLineWidth : 0
                                });
                            }
                        }
                        // I need to remove |diff| aces
                        else{

                            diff = diff*(-1); //lo riporto positivo
                            var len = chart[componentState.id].yAxis.length;
                            for(var key = 1; key <= diff; key++){
                                chart[componentState.id].yAxis[len-key].remove(true);
                            }

                            // reactivate grid
                            if(activeMacro.macro.num_yaxis == 1){
                                var options = {
                                    yAxis:  {
                                        gridLineWidth : 1
                                    }
                                };
                                chart[componentState.id].update(options);
                            }
                        }
                    }
                }

                // check if the x-axis labels come from server
                // or are to be calculated
                if( labelsFlag ){
                    addSeriesToChartCategories();
                }
                else{
                    addSeriesToChartCategoriesFormattedXLabels();
                }
            }
        }
        else{
            // add series to table
            addSeriesToTable();
        }
    });

    /**
     * Click event on "Tipo grafico" option
     */
    $("#typechart a").on("click", function(e){
        e.preventDefault();
        // get selected option
        var type = $(this).data('type');
        // apply updates
        updateTypeChart(type);
    });

    /**
     * Click event on "Trattameto" option
     */
    $("#treatment a").on("click", function(e){
        e.preventDefault();

        // get selected option
        var type = $(this).data('type');
        console.log(type);

        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // loop through all parameters of the active macro
        // for each element update options
        $.each(activeMacro.params, function (key, param) {
            param.treatment = type;
            if(type == 'sldavg'){
                param.window = 8;
            }
        });

        // refresh tool's content with active macro metadata
        loadActiveMacro();
        // trigger click on button "Aggiorna"
        $("#update-data").trigger('click');
    });

    /**
     * Click event on "+ Grafico" button
     */
    $("#add-tab-chart").on('click', function(e){
        e.preventDefault();

        // global variable: increase tab counter
        counter++;

        // new component object
        var newItemConfig = {
            type: 'component',
            componentName: 'chartComponent',
            componentState: {
                id: counter,
                type: 'chart',
                multiple: false,
                windrose: false,
                windroseId: null,
                macroId: null,
                elementMacro: JSON.parse(JSON.stringify(activeMacro))
            },
            title:'Grafico',
            isClosable: true
        };

        // add child to goldenlayout plugin
        centralContainer.addChild(newItemConfig);
        $(".lm_content").css("background-color", "white");
    });

    /**
     * Click event on "+ Tabella" button
     */
    $("#add-tab-table").on('click', function(e){
        e.preventDefault();

        // global variable: increase tab counter
        counter++;
        // new component object
        var newItemConfig = {
            type: 'component',
            componentName: 'tableComponent',
            componentState: {
                id: counter,
                type: 'table',
                macroId: null,
                elementMacro: JSON.parse(JSON.stringify(activeMacro))
            },
            title:'Tabella',
            isClosable: true
        };

        // add child to goldenlayout plugin
        centralContainer.addChild(newItemConfig);
        $(".lm_content").css("background-color", "white");
    });

    /**
     * Click event on "Reset tab attivo" option
     */
    $("#reset-active-tab").on('click', function(e){
        e.preventDefault();

        console.log("CLICK!");
        // get active component object and reset it
        var activeContentItem = centralContainer.header.activeContentItem;
        resetTab(activeContentItem);

        activeMacro = activeContentItem.config.componentState.elementMacro;
        // refresh tool's content with active macro metadata
        loadActiveMacro();
    });

    /**
     * Click event on "Reset tutto" option
     */
    $("#reset-all-tabs").on('click', function(e){
        e.preventDefault();
        console.log("CLICK!");

        resetAllTabs();
    });

    // Cod
    // https://highlightjs.org/usage/
    $("#jq-code").on("click", function(e){
        e.preventDefault();
        // console.dir(query);

        // clean up query, remove heading spaces
        var items = [];
        if(query){
            var data = query.split("\n");
            $.each(data, function(i, item) {
                items.push(item.replace(/^\s{12}/g,''));
            });
            var fquery = items.join("\n");
        }

        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        if(componentState.windrose == true)
            hljs.highlightBlock($("#last-macro").html('Nessuna macro presente').get(0));
        else
            // https://highlightjs.readthedocs.io/en/latest/api.html#highlightblock-block
            hljs.highlightBlock($("#last-macro").html(JSON.stringify(activeMacro, null, 4)).get(0));

        hljs.highlightBlock($("#last-query").html(fquery).get(0));
    });
}// END SECOND MENU

    // !!THIRD MENU
{
    /**
     * Click event on ">> Cambia" button
     */
    $("#update-yaxis").on("click", function(e){
        e.preventDefault();
        // get new y axis range
        var min = $("#range-min").val() == '' ? null : parseFloat($("#range-min").val());
        var max = $("#range-max").val() == '' ? null : parseFloat($("#range-max").val());
        // update chart
        updateYaxisZoom(min, max)
    });

    /**
     * Click event on "Scala vento" button
     */
    $("#add-wind-scale").on("click", function(e){
        e.preventDefault();
        console.log('addWindScale');

        // check if navigatos is enabled
        // if true then return and do nothing
        if(analyserOptions.highstocks.navigatorEnabled){
            // warning message
            swal('Info', 'Non è possibile aggiungere un asse con il navigatore attivo: disabilitarlo', 'info');
            return;
        }

        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // check if chart plugin is initialized
        if( chart[componentState.id] ){
            // check the number of y Axes
            var diff = 1  - chart[componentState.id].yAxis.length;
            // if diff is lower than 0 then remove all additional axes
            if(diff < 0){
                // make diff a positive number
                diff = diff*(-1);
                var len = chart[componentState.id].yAxis.length;
                // loop through all y axes object and remove them
                for(var key = 1; key <= diff; key++){
                    chart[componentState.id].yAxis[len-key].remove(true);
                }
                // reactivate grid
                if(activeMacro.macro.num_yaxis == 1){
                    var options = {
                        yAxis:  {
                            gridLineWidth : 1
                        }
                    };
                    // update chart options
                    chart[componentState.id].update(options);
                }
            }

            // remove all old plot lines
            var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
            $.each(plotLinesAndBands, function(key, line){
                chart[componentState.id].yAxis[0].removePlotLine('band'+key);
            });
            // add new bands
            addPlotBands();

            // set macro number of axes
            activeMacro.macro.num_yaxis = 2;
            // refresh tool's content with active macro metadata
            loadActiveMacro();
        }
    });

    /**
     * Click event on "Asse Y" option
     */
    $("#update-num-yaxis a").on("click", function(e){
        e.preventDefault();
        console.log('numYaxis');

        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // retrieve selected otpion's type
        var type = $(this).data("type");
        // 2 different cases: single or multi
        if(type == 'single'){
            var num = parseInt($(this).data("num"));
            // if select num is greater than 1  and navigator is enabled then return and do nothing
            if(num > 1 && chart[componentState.id] && chart[componentState.id].options.navigator.enabled ){
                // warning message
                swal('Navigatore attivo!', 'Non è possibile aggiungere un asse con il navigatore attivo: disabilitarlo', 'info');
                return;
            }

            // upda macro metadata
            activeMacro.macro.num_yaxis = num;
            // loop through all active macro's parameters
            // for each element if index of linked axis is greater than the number of macro axes
            // then reset it to 1
            $.each(activeMacro.params, function(key, param){
                if(param.axis > num)
                    param.axis = 1;
            });

            // refresh tool's content with active macro metadata
            loadActiveMacro();
            // check if the number of axes set is different from that actually present on the chart
            if( chart[componentState.id] && num != chart[componentState.id].yAxis.length){
                var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
                // remove all bands plot lines
                $.each(plotLinesAndBands, function(key, line){
                    chart[componentState.id].yAxis[0].removePlotLine('band'+key);
                });
                // take care of y axis
                addYaxis();
            }
        }
        else if(type == 'multi'){
            console.log('Chart multiplo');
            // global variable: increase tab counter
            counter++;

            // create new component object
            var newItemConfig = {
                type: 'component',
                componentName: 'chartComponent',
                componentState: {
                    id: counter,
                    type: 'chart',
                    multiple: true,
                    windrose: false,
                    windroseId: null,
                    macroId: null,
                    elementMacro: JSON.parse(JSON.stringify(activeMacro))
                },
                title:'Grafico multiplo',
                isClosable: true
            };

            // add tab to goldenlayout plugin
            centralContainer.addChild(newItemConfig);
            $(".lm_content").css("background-color", "white");
            $('#chart_container_'+counter).addClass("nav-content");

            // trigger click on button "Aggiorna"
            $("#update-data").trigger('click');
        }
    });

    /**
     * Click event on "Nota" button
     */
    $('#add-note').click(function(e){
        e.preventDefault();
        // show a swal in order to insert a text
        var swal_note = swal({
            title: "Aggiungi nota",
            text: "Scrivi il testo della nota:",
            type: "input",
            showCancelButton: true,
            closeOnConfirm: false,
            confirmButtonText: "Inserisci",
            cancelButtonText: "Annulla",
            inputPlaceholder: "Nota..."
        }, function (inputValue) {
            if (inputValue === false) return false;
            if (inputValue === "") {
                swal.showInputError("Il campo è obbligatorio!");
                return false
            }
            // add inseted text as a chart note
            if( addChartAnnotation(inputValue) == 1 ){
                swal.close();
            }
            else{
                // warning message
                swal('Attenzione', 'Nessun grafico inizializzato...la nota non è stata aggiunta!', 'info');
            }

        });
    });

    /**
     * Click event on "Linea" button
     */
    $('#add-line').click(function(e){
        e.preventDefault();
        // show a swal in order to insert a value for a horizontal axis
        swal({
            title: "Aggiungi linea",
            text: "Devi inserire un numero:",
            type: "input",
            inputType: "number",
            showCancelButton: true,
            closeOnConfirm: false,
            confirmButtonText: "Inserisci",
            cancelButtonText: "Annulla",
            inputPlaceholder: "Numero..."
        }, function (inputValue) {
            if (inputValue === false) return false;
            if (inputValue === "") {
                swal.showInputError("Il campo è obbligatorio!");
                return false
            }
            // add a horizontal line to chart
            if( addHorizontalLine(parseFloat(inputValue)) == 1 ){
                swal.close();
            }
            else{
                // warning message
                swal('Attenzione', 'Nessun grafico inizializzato...l\'asse non è stato aggiunto!', 'info');
            }

        });
    });

    /**
     * Click event on delete button
     */
    $('#clear-chart').click(function(e){
        e.preventDefault();
        // confirm message
        swal({
            title: "Pulisci il grafico",
            text: "Sei sicuro di voler eliminare le note e gli assi dal grafico?",
            type: "warning",
            showCancelButton: true,
            confirmButtonClass: "btn-danger",
            confirmButtonText: "Si, elimina",
            cancelButtonText: "Annulla",
            closeOnConfirm: false
        },
        function(){
            // remove all notes and lines from chart
            clearChart();
            swal.close();

        });
    });

    /**
     * Click event on "Zoom" option
     */
    $("#change-zoom a").on("click", function(e){
        e.preventDefault();

        // take care of class sel (remove from old element and add it to new one)
        $("#change-zoom a").removeClass('sel');
        $(this).addClass('sel');
        // get selected zoom type
        var type = $(this).data("type");
        $("#icon-zoom").removeClass();

        // check type and update chart options
        // update main button's icon
        switch(type) {
            case 'xy':
                console.log('ZOOM X Y');
                $("#icon-zoom").addClass("fal fa-arrows-up-down-left-right");
                updateZoomType(type);
                break;
            case 'x':
                console.log('ZOOM X');
                $("#icon-zoom").addClass("fal fa-arrows-left-right");
                updateZoomType(type);
                break;
            case 'y':
                console.log('ZOOM Y');
                $("#icon-zoom").addClass("fal fa-arrows-up-down");
                updateZoomType(type);
                break;
        }
    });

    /**
     * Change event on "Grafico per anno" checkbox
     */
    $('#chart-per-year').on('change', function(){
        console.log('cambio per-year');
        // check if active macro has more than 1 linked parameter
        // if true then return and do nothing
        if(activeMacro.params.length > 1){
            $(this).prop('checked', false);

            // warning message
            swal({
                title: "Attenzione",
                text: "La funzione è disponibile per <strong>un solo parametro alla volta</strong>.",
                type: 'info',
                html: true
            });
            return;
        }

        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // check new value
        // if it is checked then the user has enabled it
        // otherwise user has disabled it
        if( $(this).is(':checked')){
            // update component options
            componentState.perYear = true;
            // set starting date as the first day of the year
            dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/01/YYYY 00:00');
            $("#date-start").inputmask("setvalue", dateFrom);
            // disable all buttons not clickable for multiple charts tab
            $('.disabled-peryear').prop('disabled', true);
        }
        else{
            // update options
            componentState.perYear = false;
            activeMacro.macro.reload = true;
            // enable all butoons
            $('.disabled-peryear').prop('disabled', false);
        }

        // trigger click on button "Aggiorna"
        $('#update-data').trigger('click');
    });

    /**
     * Click event on "Download grafico" button
     */
    $("#download-image").on("click", function(e){
        e.preventDefault();
        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        console.dir(componentState);
        // user highchart method to download the image of the chart
        if(componentState.type == 'chart'){
            chart[componentState.id].exportChartLocal({type: 'image/png'});
        }
    });

    /**
     * Click event on "Download CSV" option
     */
    $("#download-csv").on("click", function(e){
        e.preventDefault();
        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        console.dir(componentState);
        // use tabulator or highchart method to download csv file
        if(componentState.type == 'table'){
            table[componentState.id].download("csv", 'Analyser_'+ moment().format('YYYY-MM-DD_HH:mm')+".csv", {delimiter:";"});
        }
        else{
            chart[componentState.id].downloadCSV();
        }
    });

    /**
     * Click event on "Download da server" option
     */
    $('#download-from-server').on("click",function(e){
        e.preventDefault();

        // get dates range
        dateFrom = $("#date-start").val();
        dateTo = $("#date-end").val();
        // check dates validity
        if( ! validDates(dateFrom, dateTo, 'date-start') ){
            swal('Attenzione!', 'Date inserite non valide', 'warning');
            return;
        }

        // // loadActiveMacro();

        // if active macro has no parameters then return and do nothing
        if ( activeMacro.params.length == 0 ){
            // warning message
            swal('Info', 'Nessun parametro selezionato!', 'info');
            console.log('Nessun parametro selezionato!');
            return;
        }

        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // download url
        var url = "/str_ana_get_csv_data";

        /*http://johnculviner.com/category/jquery-file-download/*/
        // GET to be able to download from a smartphone
        $.fileDownload(url, {
            httpMethod: 'POST',
            data: {
                from: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'),
                to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'),
                hideNulls: $('#hide-undefined').data("hidenull"),
                macro: JSON.stringify(activeMacro)
            },
            successCallback: function(url) {

                // console.dir(result);
                console.log('csv scaricato ...');
                // at the end of the process hide preloader
                $('.preloader').hide();
                // success message
                swal("Perfetto!", "Dati scaricati in un pacchetto .zip. Per accedere ai file decomprimere la cartella", "success");

            },
            failCallback: function(responseHtml, url, error) {

                console.log('il file csv non è stato creato oppure errore durante lo scarico.');
                // at the end of the process hide preloader
                $('.preloader').hide();
                // error message
                swal("Errore!", "Ops! Qualcosa è andato storto.", "error");
            }
        });

        console.log('End download');
        //this is critical to stop the click event which will trigger a normal file download!
        return false;
    });
}// END THIRD MENU

    /**
     * Click event on edit button near the chart's title
     */
    $(".layoutContainer").on('click', '.edit-titles', function(e){
        console.log("CLICK!");
        e.preventDefault();
        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // check that it is a chart tab and the chart is initialized
        if( componentState.type == 'chart' && chart[componentState.id] ){
            // fill form inside the modal
            var title = chart[componentState.id].options.title.text;
            title = title.replace( /(<([^>]+)>)/ig, '');
            $('#chart-temp-title').val(title.trim());
            $('#chart-temp-subtitle').val(chart[componentState.id].options.subtitle.text);
        }
    });

    /**
     * Click event on "Applica" button inside the modal
     */
    $("#apply-chart-titles").on('click', function(e){
        console.log("CLICK!");
        e.preventDefault();

        // get form values
        var title = $('#chart-temp-title').val();
        var subtitle = $('#chart-temp-subtitle').val();
        // get active component
        var activeTabElement = centralContainer.header.activeContentItem;
        var componentState = activeTabElement.config.componentState;

        // check that it is a chart tab and the chart is initialized
        if( componentState.type == 'chart' && chart[componentState.id] ){
            // update chart title
            chart[componentState.id].setTitle(
                    { text: ( title +' <a data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>' ) },
                    { text: ( subtitle == "" ? null : subtitle ) }
                );
            // initialize tooltip
            $('#chart_container_'+componentState.id+' [data-toggle-second="tooltip"]').tooltip();
        }
    });

    /**
     * Click event on windrose button inside json tree on the right
     */
    $("#ext-json").on('click', ".windrose", function(e){
        e.preventDefault();

        // global variable: increase tab counter
        counter++;
        // get station id stored inside the element
        var stid = $(this).data('stid');
        console.log(stid);
        // create a new component object
        var newItemConfig = {
            type: 'component',
            componentName: 'chartComponent',
            componentState: {
                id: counter,
                type: 'chart',
                windrose: true,
                windroseId: stid,
                macroId: null,
                elementMacro: null
            },
            title:'Rosa dei venti',
            isClosable: true
        };

        // add child tab to goldenlayout plugin
        centralContainer.addChild(newItemConfig);
        $(".lm_content").css("background-color", "white");

        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // create windorse chart for the selected station
        createChartWR(stid);
    });

    // first load of user options
    loadOptions();
    // first load of macro categories
    loadCategories();
});

/**
 * Function used to retrieve the metadata about a specific macro from database
 *
 * @param {number} macroId: Macro Id
 */
function getMacroById(macroId){

    // ajax call
    var jqxhr = $.ajax({
        url: '/str_ana_get_macro_metadata',
        type: "post",
        dataType: "json",
        data: {
            id: macroId
        },
    })
    .done(function(result) {
        // check result
        // if OK then success
        if(result.res == 'OK'){
            console.dir(result);

            activeMacro = result.macro;
            // update aggregation option
            $('#time-period').val(activeMacro.macro.aggregation);

            // get active component
            var activeTabElement = centralContainer.header.activeContentItem;
            var componentState = activeTabElement.config.componentState;
            // set component options and store the retrieved macro
            componentState.macroId = macroId;
            componentState.elementMacro = activeMacro;
            $('#macro-category').val(result.category);

            // refresh tool's content with active macro metadata
            loadActiveMacro();
            // write a info message in the log container
            log('SUCCESS!', 'Recupero dati macro fine');
        }
        else{
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della macro", "error");
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero del dettaglio della macro", "error");
    });
}

/**
* Function that updates tool's contents with metadata of the active macro
* - refresh window at bottom right with macro info
* - refresh form, pre-populated fields, edit macro
*
* No args needed
*/
function loadActiveMacro(){

    // get active macro and its parameters
    var macro = activeMacro.macro;
    // copy only the values and not the reference
    var params = activeMacro.params.slice();

    // variables for dynamically build html
    var html_info;
    var html_params;
    var html_select_params;

    console.dir(activeMacro);

    // clear container
    $("#macro-detail").empty();
    // check if it is a new macro and there are no associated parameters yet
    if(macro.name == 'Nuova macro' && (params == null || params.length == 0)){

        // set default options and clear bottom right pane
        var html ='<span class="drop-placeholder"><i class="icon-frame"></i> Trascina un parametro</span>';
        $("#macro-detail").append(html);
        $(".update-macro").text("Nuova macro");
        $("#settings-macro-title").text("Nuova macro");
        macro.percent_data = $("#percent-data").val();
        macro.aggregation = $("#time-period").val();
        var operator =  $(".valcode-menu .validation-operators button.sel").text();
        // var code =  $(".valcode-menu a.dropdown-item.sel").data("id");
        var validity;
        var validityArrayStr = [];

        if($(".valcode-menu a.dropdown-item.sel").length == 1 && $(".valcode-menu a.dropdown-item.sel").data('id') == null){
            validity = null;
            validityArrayStr.push('tutti i dati');
        }
        else{

            validity = [];
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){

                validityStr = operator+' '+$(this).data("id");
                validityArrayStr.push(operator+' '+ $(this).text());
                validity.push(validityStr);
            });
        }

        macro.validity_code = validity.join(', ');

        // populate the active settings pane
        $('.tbl-analyser tbody').empty();
        var html_tbl = '';
        html_tbl += '        <tr>';
        html_tbl += '            <th>Copertura dati:</th>';
        html_tbl += '            <td>'+macro.percent_data+'%</td>';
        html_tbl += '        </tr>';
        html_tbl += '        <tr>';
        html_tbl += '            <th>Validità:</th>';
        html_tbl += '            <td>'+validityArrayStr.join('<br>')+'</td>';
        html_tbl += '        </tr>';

        $('.tbl-analyser tbody').append(html_tbl);
        // clear macro form
        clearAllMacro();
        return;
    }

    // update tool's titles and contents
    $(".update-macro").text("Modifica macro");
    $("#settings-macro-title").text("Modifica macro");

    $('#percent-data').val(macro.percent_data);
    $('#copertura').text(macro.percent_data+'%');

    var aggregation = $('#time-period option[value="'+macro.aggregation+'"]').text();
    $('#time-period').val(macro.aggregation);

    var validity;
    var validityArrayStr = [];
    var operator;
    var code;

    if( macro.validity_code == null){
        validity = 'tutti i dati';
        code = "";
        $(".valcode-menu a.sel").removeClass("sel");
        $(".valcode-menu a.dropdown-item").find('i').remove();

        $(".valcode-menu a:contains('Tutti i dati')").addClass("sel");
        $(".valcode-menu a:contains('Tutti i dati')").append(' <i class="mdi mdi-check text-danger"></i>');

        $("#macro-validity-operator").prop("disabled", true);

        validityArrayStr.push(validity);
    }
    else{
        validityArray = macro.validity_code;
        $(".valcode-menu .sel").removeClass("sel");
        $(".valcode-menu a.dropdown-item").find('i').remove();
        validityArray = validityArray.split(', ');

        $.each(validityArray, function(idx, el){
            var res = el.split(" ");
            operator = res[0];
            code = res[1];

            console.log(operator+' '+code);

            // :contains('"+operator+"')"
            $(".valcode-menu button").filter(
                            function (){
                                return $( this ).text() === operator;
                            }
            ).addClass("sel");
            $(".valcode-menu a[data-id='"+code+"']").addClass("sel");
            $(".valcode-menu a[data-id='"+code+"']").append(' <i class="mdi mdi-check text-danger"></i>');

            $("#macro-validity-operator").prop("disabled", false);

            validityArrayStr.push(operator+' '+ $(".valcode-menu a[data-id='"+code+"']").text());
        });

        validity = macro.validity_code;
    }

    var labelY = macro.label_yaxis;
    if(labelY == null)
        labelY = '';

    var stepY =  macro.step_yaxis;
    if(stepY == null)
        stepY = '';

    if(macro.num_yaxis == null)
        macro.num_yaxis = 1;

    // create html for the container in the bottom right of layout
    html_info = '<h5>Macro</h5>';
    html_info +='<table class="table table-striped">';
    html_info +='   <tbody>';
    html_info +='       <tr><th>Nome:</th><td>'+macro.name+'</td></tr>';
    html_info +='       <tr><th>Descrizione:</th><td>'+macro.description+'</td></tr>';
    html_info +='       <tr><th>Aggregazione:</th><td>'+aggregation+'</td></tr>';
    html_info +='       <tr><th>Percentuale dati:</th><td>'+macro.percent_data+'%</td></tr>';
    html_info +='       <tr><th>Codice validità:</th><td>'+validity+'</td></tr>';
    html_info +='       <tr><th>Etichetta asse Y:</th><td>'+labelY+'</td></tr>';
    html_info +='       <tr><th>Step asse Y:</th><td>'+stepY+'</td></tr>';
    html_info +='       <tr><th>Numero assi:</th><td>'+macro.num_yaxis+'</td></tr>';
    html_info +='   </tbody>';
    html_info +='</table>';

    $("#macro-detail").append(html_info);

    // populate the active settings pane
    $('.tbl-analyser tbody').empty();
    var html_tbl = '';
    html_tbl += '        <tr>';
    html_tbl += '            <th>Copertura dati:</th>';
    html_tbl += '            <td>'+macro.percent_data+'%</td>';
    html_tbl += '        </tr>';
    html_tbl += '        <tr>';
    html_tbl += '            <th>Validità:</th>';
    html_tbl += '            <td>'+validityArrayStr.join('<br>')+'</td>';
    html_tbl += '        </tr>';

    $('.tbl-analyser tbody').append(html_tbl);

    // populate the mask for editing the macro
    $("#macro-name").val(macro.name);
    $("#macro-desc").val(macro.description);
    $("#macro-aggregation").val(macro.aggregation);
    $("#macro-valid-data").val(macro.percent_data);

    operator = $(".valcode-menu .validation-operators button.sel").text();
    //in order to hide and show corret select
    $("#macro-validity-operator").val(operator).trigger('change');
    if(operator == '='){
        codes = validity.split(', ');
        codes.forEach(function(el, idx){
            codes[idx] = parseInt(el.replace('= ', ''));
        });
        $('#multiple-validity-code').val(codes).trigger('change.select2');
    }
    else{
        if( macro.validity_code == null)
            code= '';
        else
            code = parseInt(validity.replace(operator, ''));

        $("#single-validity-code").val(code);
        // .macro-validity-code:visible
    }

    $("#macro-label-yaxis").val(macro.label_yaxis);
    $("#macro-label-y-step").val(macro.step_yaxis);
    $("#macro-num-yaxis").val(macro.num_yaxis).trigger('change');

    // if params not null build html in order to populate:
    // - active macro container (bottom right view)
    // - active macro modal (select)
    if(params != null){

        html_select_params = '<option value="-1" selected>Seleziona...</option>';

        html_params = '<h5>Parametri ['+params.length+']</h5>';
        html_params +='<div id="accordion" class="accordion">';
        html_params +='<div class="card mb-0">';

        $.each(params, function(key, param){
            // console.dir(params);
            html_params +='<div class="param-buttons">';
            // action for edit and del-param in analyser.js
            html_params +='    <i data-pos="'+key+'" class="ti-pencil text-info edit-param"></i>';
            html_params +='    <i data-pos="'+key+'" class="ti-trash text-danger del-param"></i>';
            html_params +='    <div class="card-header collapsed" data-toggle="collapse" href="#collapse'+key+'">';
            html_params +='        <a class="card-title">'+param.legend+'</a>';
            html_params +='    </div>';
            html_params +='</div>';

            //html_params +='<h6>'+param.legend+'</h6>';
            html_params +='<div id="collapse'+key+'" class="card-body collapse" data-parent="#accordion">';
            html_params +='<table class="table">';
            html_params +='   <tbody>';
            html_params +='    <tr><th>Nome:</th><td>'+param.name+'</td></tr>';
            html_params +='    <tr><th>Formula:</th><td>'+param.formule+'</td></tr>';
            html_params +='    <tr><th>Conversione:</th><td>'+(param.converted ? 'si' : 'no')+'</td></tr>';
            if(param.decimals){
                html_params +='    <tr><th>Decimali:</th><td>'+param.decimals+'</td></tr>';
            }
            var treatmentTxt = $("#treatment a[data-type='"+param.treatment+"']").text();
            if(param.treatment == 'sldavg'){
                treatmentTxt += ' ['+param.window+'h]';
            }
            html_params +='    <tr><th>Trattamento:</th><td>'+treatmentTxt+'</td></tr>';
            html_params +='   </tbody>';
            html_params +='</table>';
            html_params +='</div>';

            html_select_params += '<option data-idx="'+key+'" value="'+param.st_pr_id+'">'+param.name+' ( '+param.station+' )</option>'
        });

        html_params +='</div>';
        html_params +='</div>';

        $("#macro-detail").append(html_params);

        $("#macro-param-main").empty();
        $("#macro-param-main").append(html_select_params);
    }
}


/**
* Function that retrieves user's options
* No args needed
*/
function loadOptions(){

    // get options via an ajax call
    console.log('ajax');
    var jqxhr = $.ajax({
        url: '/str_ana_get_analyser_options',
        type: "post",
        dataType: "json"
    })
    .done(function(result) {
        console.dir(result);

        // store general tool options inside a global variable
        analyserToolOptions = result.gen_opt;

        var options = result.user_opt;
        // if user's options are empty then set default options
        if( options == null){
            // IMPOSTAZIONI DI DEFAULT
            analyserOptions = {
                general: {
                    // lista stazioni
                    stidEnabled: false,
                    altitudeEnabled: true,
                    allocationsEnabled: true,
                    limitsValueEnabled: true,
                    // lista parametri
                    paramsEnabled: false,
                    // formato data
                    dateFormat: 'standard',
                    // estrazione dati
                    convEnabled: true,
                    // nome serie
                    treatmentEnabled: false,
                    windScale: 1 // default
                },
                tabulator: {
                    minmaxEnabled: false,
                    codesEnabled: true,
                    percEnabled: false,
                    filtersEnabled: false,
                    calcEnabled: false
                },
                highstocks: {
                    minmaxEnabled: false,
                    // notesEnabled: false,
                    // layout grafico online
                    subtitleEnabled: true,
                    navigatorEnabled: false,
                    labelXangle: 0,
                    minorGridEnabled: false,
                    hoverEventEnabled: true,
                    tooltipType: 'standard',
                    titleFontSize: 16,
                    labelFontSize: 11,
                    legendFontSize: 10,
                    numLabel: 15,
                    // layout immagine esportata
                    expWidth: 600,
                    expHeight: 400,
                    expTitleFontSize: 16,
                    expLabelFontSize: 11,
                    expLegendFontSize: 10,
                    expNumLabel: 8
                },
                filter: {
                   altitude: 0
                }
            };

        }
        // else fill the global variables taking care of null fields
        else{
            // IMPOSTAZIONI DA DB CON CONTROLLO PRESENZA CAMPI ALTRIMENTI DEFAULT
            analyserOptions = {
                general: {
                    // lista stazioni
                    stidEnabled:  options.general.stidEnabled == null ? false : options.general.stidEnabled,
                    altitudeEnabled: options.general.altitudeEnabled == null ? true : options.general.altitudeEnabled,
                    allocationsEnabled: options.general.allocationsEnabled == null ? true : options.general.allocationsEnabled,
                    limitsValueEnabled: options.general.limitsValueEnabled == null ? true : options.general.limitsValueEnabled,
                    // lista macro
                    paramsEnabled: options.general.paramsEnabled == null ? false : options.general.paramsEnabled,
                    // formato data
                    dateFormat: options.general.dateFormat == null ? 'standard' : options.general.dateFormat,
                    // estrazione dati
                    convEnabled: options.general.convEnabled == null ? true : options.general.convEnabled,
                    treatmentEnabled: options.general.treatmentEnabled == null ? false : options.general.treatmentEnabled,
                    windScale: options.general.windScale == null ? 1 : options.general.windScale// default
                },
                tabulator: {
                    minmaxEnabled: options.tabulator == null || options.tabulator.minmaxEnabled == null ? false : options.tabulator.minmaxEnabled,
                    codesEnabled: options.tabulator == null || options.tabulator.codesEnabled == null ? true : options.tabulator.codesEnabled,
                    percEnabled: options.tabulator == null || options.tabulator.percEnabled == null ? false : options.tabulator.percEnabled,
                    filtersEnabled: options.tabulator == null || options.tabulator.filtersEnabled == null ? false : options.tabulator.filtersEnabled,
                    calcEnabled: options.tabulator == null || options.tabulator.calcEnabled == null ? false : options.tabulator.calcEnabled
                },
                highstocks: {
                    minmaxEnabled: options.highstocks.minmaxEnabled == null ? false : options.highstocks.minmaxEnabled,
                    // notesEnabled: options.highstocks.notesEnabled == null ? false : options.highstocks.notesEnabled,
                    // layout grafico online
                    subtitleEnabled: options.highstocks.subtitleEnabled == null ? true : options.highstocks.subtitleEnabled,
                    navigatorEnabled: options.highstocks.navigatorEnabled == null ? false : options.highstocks.navigatorEnabled,
                    // numberYaxis: options.highstocks.numberYaxis == null ? 1 : options.highstocks.numberYaxis,
                    labelXangle: options.highstocks.labelXangle == null ? 0 : options.highstocks.labelXangle,
                    minorGridEnabled: options.highstocks.minorGridEnabled == null ? false : options.highstocks.minorGridEnabled,
                    hoverEventEnabled: options.highstocks.hoverEventEnabled == null ? true : options.highstocks.hoverEventEnabled,
                    tooltipType: options.highstocks.tooltipType == null ? 'standard' : options.highstocks.tooltipType,
                    titleFontSize: options.highstocks.titleFontSize == null ? 16 : options.highstocks.titleFontSize,
                    labelFontSize: options.highstocks.labelFontSize == null ? 11 : options.highstocks.labelFontSize,
                    legendFontSize: options.highstocks.legendFontSize == null ? 10 : options.highstocks.legendFontSize,
                    numLabel: options.highstocks.numLabel == null ? 15 : options.highstocks.numLabel,
                    // layout immagine esportata
                    expWidth: options.highstocks.expWidth == null ? 600 : options.highstocks.expWidth,
                    expHeight: options.highstocks.expHeight == null ? 400 : options.highstocks.expHeight,
                    expTitleFontSize: options.highstocks.expTitleFontSize == null ? 10 : options.highstocks.expTitleFontSize,
                    expLabelFontSize: options.highstocks.expLabelFontSize == null ? 6 : options.highstocks.expLabelFontSize,
                    expLegendFontSize: options.highstocks.expLegendFontSize == null ? 5 : options.highstocks.expLegendFontSize,
                    expNumLabel: options.highstocks.expNumLabel == null ? 8 : options.highstocks.expNumLabel,
                },
                filter: {
                   altitude: options.filter.altitude == null ? 0 : options.filter.altitude
                }
            };
        }

        // set global exporting options for chart plugin
        exportinChartOptions = {
            scale: 1,
            filename: 'Analyser_'+ moment().format('YYYY-MM-DD_HH:mm'),
            useHtml: true,
            csv: {
                // This function is called for each column header.
                columnHeaderFormatter: function (item, key) {
                    if ( item instanceof Highcharts.Axis ) {
                        return 'Data';
                    }
                    else
                        return false;
                },
            },
            sourceWidth: analyserOptions.highstocks.expWidth,
            sourceHeight: analyserOptions.highstocks.expHeight,
            chartOptions: {
                navigator: {
                    enabled: false
                },
                title: {
                    style: {
                        fontSize: analyserOptions.highstocks.expTitleFontSize+'px'
                    }
                },
                subtitle: {
                    style: {
                        fontSize: parseInt( analyserOptions.highstocks.expTitleFontSize * 0.8) +'px'
                    }
                },
                xAxis:{
                    0: {
                        lineColor: '#000000',
                        lineWidth: 1,
                        minorTicks: true,
                        labels: {
                            rotation: - analyserOptions.highstocks.labelXangle,
                            style: {
                                color: '#000000',
                                fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                            }
                        },
                        tickPositioner: function () {

                            if( activeMacro.macro.aggregation == 'mm' || activeMacro.macro.aggregation == 'yy')
                                return undefined;

                            var positions = [];
                            var tick;
                            var increment;
                            var nTick = analyserOptions.highstocks.expNumLabel - 1;
                            var nData;

                            if (this.userMax != null && this.userMin != null) {
                                nData = (this.userMax - this.userMin) / this.closestPointRange;

                                if (nData == 0)
                                    return;
                                else if(nData < nTick)
                                    nTick = nData;

                                var remainderMin = this.userMin % this.closestPointRange;
                                var myUserMin = this.userMin - remainderMin;

                                tick = Math.floor(myUserMin);
                                increment = (this.userMax - myUserMin) / nTick;
                                var remainder = increment % this.closestPointRange;

                                increment = increment - remainder;

                                for (tick; tick - increment <= this.userMax; tick += increment) {

                                    positions.push(tick);
                                }
                                return positions;
                            }

                            if (this.dataMax !== null && this.dataMin !== null) {
                                nData = (this.dataMax - this.dataMin) / this.closestPointRange;

                                if (nData == 0)
                                    return;
                                else if(nData < nTick)
                                    nTick = nData;

                                tick = Math.floor(this.dataMin);
                                increment = (this.dataMax - this.dataMin) / nTick;
                                var remainder = increment % this.closestPointRange;

                                increment = increment - remainder;

                                for (tick; tick - increment <= this.dataMax; tick += increment) {
                                    positions.push(tick);
                                }
                            }
                            return positions;
                        }
                    }
                },
                yAxis: {
                    0: {
                        lineColor: '#000000',
                        lineWidth: 1,
                        minorTicks: true,
                        title: {
                            enabled : false
                        },
                        showLastLabel: true,
                        labels: {
                            style: {
                                color: '#000000',
                                fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                            }
                        }
                    }
                },
                legend:{
                    align: 'center',
                    width: '100%',
                    itemDistance: 50,
                    itemStyle: {
                        fontSize: analyserOptions.highstocks.expLegendFontSize+'px',
                        fontWeight: 'normal'
                    },
                    margin: 2
                }
            },
            buttons: {
                contextButton: {
                    menuItems: [
                        "viewFullscreen",
                        "printChart",
                        "separator",
                        {
                           "text": 'Copia PNG [solo <strong>Chrome/Safari</strong>]',
                            onclick: function () {
                                var activeTabElement = centralContainer.header.activeContentItem;
                                var componentState = activeTabElement.config.componentState;

                                return copySvgToClipboard( componentState.id  );
                            }
                        }
                    ]
                }
            }
        };

        // fill options form with retrieved metadata
        setOptions();
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");

    });
}

/**
 * Function for retrieving the categories visible to the user
 * No args needed
 */
function loadCategories(){

    console.log('loadcategories');
    // ajax call
    var jqxhr = $.ajax({
        url: '/str_ana_get_categories',
        type: "post",
        dataType: "json",
    })
    .done(function(result) {
        if(result.res == 'OK'){
            console.dir(result);

            categories_list = result.categories_list;
            // variables for dynamically build html
            var html_macro = '<option value="-1">Seleziona categoria appartenenza...</option>';
            var html_table = '';

            $('#categories-table tbody').empty();
            $('#macro-category').empty();

            // loop through all categories
            // for each element build an option and a row to be added to the table
            $.each(categories_list, function(key, category){

                html_macro += '<option value="'+category.category_id+'">'+category.category_name+'</option>';

                html_table += '<tr data-id="'+category.category_id+'">';
                html_table += '   <td scope="row">';
                if(update_grant){
                    html_table += '       <a href="javascript:void(0)" class="edit_category" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i></a>';
                }
                if(delete_grant){
                    html_table += '       <a href="javascript:void(0)" class="delete_category" data-toggle="tooltip" data-original-title="Elimina"> <i class="ti-trash text-danger"></i></a>';
                }
                html_table += '   </td>';
                html_table += '   <td>'+category.category_name+'</td>';
                if(category.category_public){
                    html_table += '   <td><i class="ti-check-box text-primary"></i></td>';
                }
                else{
                    html_table += '   <td></td>';
                }
                html_table += '   <td>'+category.category_groups_name.join(', ')+'</td>';
                html_table += '</tr>';
            });

            // append html
            $('#macro-category').append(html_macro);
            $('#categories-table tbody').append(html_table);
            // initialize tooltip
            $('[data-toggle="tooltip"]').tooltip();

        }
        else{
            // error message
            swal("Errore!", "Errore durante il recupero delle categorie", "error");
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero delle categorie", "error");
    });
}

/**
 * Function that builds the right-click menu for the station json tree
 *
 * @param {object} node: Clicked node
 *
 * @return {object} sub-menu
 */
function customMenuStation(node){

    // return sub menu only for leaves nodes
    if ( node.parents.length > 1 ) {
        return false;
    }

    // var returnCallback = function(){
    //                 console.log('Finito');
    //                 $('#ext-json').jstree().close_all();
    //                 $('.preloader').hide();
    //                 swal("Successo!", "Caricamento avvenuto con successo", "success");
    //             };
    // The default set of all items
    var items = {
        renameItem: { // The "rename" menu item
            label: "Espandi nodo",
            action: function (){
                // $('.preloader').show();
                $('#ext-json').jstree().load_all(node);
            }
        }
    };

    return items;
}

/**
 * Function that builds the right-click menu for the macro json tree
 *
 * @param {object} node: Clicked node
 *
 * @return {object} sub-menu
 */
function customMenu(node){

    // return sub-menu only for macro nodes
    if ( node.parents.length < 2 ) {
        return false;
    }

    var items = {
        addItem: { // The "add" menu item
            label: "Nuova tabella",
            action: function (){
                // write a info message in the log container
                log("CLICK!", "Nuova tabella");
                // create a new table tab and duplicate the clicked macro
                var macroId = $(node)[0].li_attr.id;
                getMacroById(macroId);
                $('#add-tab-table').trigger('click');
                setTimeout(function(){
                    // trigger click on button "Aggiorna"
                    $("#update-data").trigger('click');
                }, 100);

            }
        },
        renameItem: { // The "rename" menu item
            label: "Nuovo grafico",
            action: function (){
                // write a info message in the log container
                log("CLICK!", "Nuovo grafico");
                // create a new table tab and duplicate the clicked macro
                var macroId = $(node)[0].li_attr.id;
                getMacroById(macroId);
                $('#add-tab-chart').trigger('click');
                setTimeout(function(){
                    // trigger click on button "Aggiorna"
                    $("#update-data").trigger('click');
                }, 100);
            }
        },
        macroItem: {
            separator_before: true,
            label: "Macro",
            submenu: {
                editItem: { // The "edit" menu item
                    label: "Modifica",
                    "_disabled": ! update_grant,
                    action: function (){
                        // write a info message in the log container
                        log("CLICK!", "Modifica macro");
                        // get macro's id stored inside the element and retrieve metadata from db
                        console.log($(node)[0].li_attr.id);
                        var macroId = $(node)[0].li_attr.id;
                        getMacroById(macroId);
                        // trigger click on button "Modifica Macro"
                        $('.update-macro').trigger('click');
                    }
                },
                copyItem: { // The "duplicate" menu item
                    label: "Duplica",
                    "_disabled": ! update_grant,
                    action: function (){
                        // get macro's id stored inside the element
                        var macroId = $(node)[0].li_attr.id;
                        // show preloader, waiting for the end of the process
                        $('.preloader').show();
                        // duplicate macro by an ajax call
                        var jqxhr = $.ajax({
                            url: '/str_ana_put_macro_duplication',
                            type: "post",
                            dataType: "json",
                            data: {
                                id: macroId
                            },
                        })
                        .done(function(result) {
                            // check result
                            // if true refresh json tree
                            // else error
                            if(result == true){
                                $('#macro-json').jstree(true).refresh(true);

                                // success message
                                swal("Successo!", "Macro duplicata correttamente", "success");
                                // write a info message in the log container
                                log('SUCCESS!', 'La macro è stata duplicata correttamente');
                            }
                            else{
                                // error message
                                swal("Errore!", "Errore durante la duplicazione della macro", "error");
                            }
                            // at the end of the process hide preloader
                            $('.preloader').hide();
                        })
                        .fail(function(xhr, err) {
                            // error message
                            swal("Errore!", "Errore durante la duplicazione della macro", "error");
                            // at the end of the process hide preloader
                            $('.preloader').hide();
                        });
                    }
                },
                deleteItem: {
                    label: "Elimina",
                    "_disabled": ! delete_grant,
                    action: function (){
                        // write a info message in the log container
                        log("CLICK!", "Modifica macro");

                        console.log($(node)[0].li_attr.id);
                        // get macro's id stored inside the element
                        var macroId = $(node)[0].li_attr.id;
                        // confirm message
                        swal({
                            title: "Stai per eliminare la macro",
                            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
                            type: "warning",
                            showCancelButton: true,
                            confirmButtonText: "Sono sicuro",
                            closeOnConfirm: false,
                            cancelButtonText: "Annulla"
                        }, function () {
                            // delet macro via an ajax call
                            var jqxhr = $.ajax({
                                url: 'str_ana_del_macro',
                                type: "post",
                                dataType: "json",
                                data: {
                                    mcid: macroId
                                },
                            })
                            .done(function(result) {
                                // check result
                                // if true then reresh json tree
                                // else error
                                if(result){
                                    console.dir(result);
                                    // success message
                                    swal("Successo!", "La macro è stata eliminata con successo", "success");
                                    // write a info message in the log container
                                    log('SUCCESS!', 'La macro è stata eliminata con successo');
                                    $('#macro-json').jstree(true).refresh(true);
                                    // reset active tab
                                    $('#reset-active-tab').trigger('click');
                                }
                                else{
                                    // error message
                                    swal("Errore!", "Errore durante l'eliminazione della macro", "error");
                                }
                            })
                            .fail(function(xhr, err) {
                                // error message
                                swal("Errore!", "Errore durante l'eliminazione della macro", "error");
                            });

                        });
                    }
                }
            }
        }
    };

    if ($(node).hasClass("folder")) {
        // Delete the "delete" menu item
        delete items.deleteItem;
    }

    // return sub-menu
    return items;
}

/**
* Function called for the initialization of all analyzer elements
* Called when golden-layout initialization is complete (analyser_layout.js)
*
* No args needed
*/
function initializeElements(){

    // initialize tooltips
    $('[data-toggle="tooltip"]').tooltip();
    $('[data-toggle-second="tooltip"]').tooltip();
    // hide boost button
    $("#boost-info").hide();
    // initialize slider
    range = $('#macro-param-charline').rangeslider({
        polyfill: false
    });

    // initialize validator for new category form
    validator = $('#new-category').validate({ // initialize the plugin
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
                required: "Inserire il nome della categoria"
            },
            "new-cat-groups" : {
                required: "Inserire i gruppi"
            }
        },
        ignore: "",
        errorPlacement: function(error, element) {

                error.insertAfter(element);
        }
    });

    // multiple selection select
    $(".select2").select2();

    var activeTabElement = centralContainer.header.activeContentItem;
    var activeTabElementMacro = activeTabElement.config.componentState.elementMacro;
    activeMacro = activeTabElementMacro;
    // refresh tool's content with active macro metadata
    loadActiveMacro();

    // ON TAB CHANGED, UPDATE ACTIVE MACRO AND INFO DETAIL
    centralContainer.on( 'activeContentItemChanged', function( activeContentItem ){
        console.log('Tab changed: load tab macro');
        // get active component and its linked macro
        var componentState = activeContentItem.config.componentState;
        activeMacro = componentState.elementMacro;
        // reset usability of buttons
        $(".disabled-table").prop("disabled", false);
        $(".disabled-table-opacity").css("opacity", "1");
        $(".disabled-windrose").prop("disabled", false);
        $(".disabled-windrose-opacity").css("opacity", "1");
        $(".disabled-multi").prop("disabled", false);
        $(".disabled-multi-opacity").css("opacity", "1");
        $(".disabled-peryear").prop('disabled', false);

        $('#chart-per-year').prop('checked', false);

        // hide / show elements
        $(".hide-windrose").show();
        $('#notes').empty();
        $("#boost-info").hide();

        // check component type
        // standard chart case
        if(componentState.type == 'chart' && componentState.windrose == false){

            // if it's a multi chart tab or a perYear chart then disable specific buttons
            if(componentState.multiple == true){
                $(".disabled-multi").prop("disabled", true);
                $(".disabled-multi-opacity").css("opacity", "0.5");
            }
            else if(componentState.perYear == true){
                $('#chart-per-year').prop('checked', true);
                $(".disabled-peryear").prop('disabled', true);
            }
            // classic non-multiple chart, add notes if present
            else if(componentState.notes != null){
                fillNotes(componentState.notes);
            }

            // if chart is initialized and it is boosted then show button
            if(chart[componentState.id] && chart[componentState.id].boosted){
                $("#boost-info").show();
            }
            // refresh tool's content with active macro metadata
            loadActiveMacro();
        }
        // windrose case
        else if(componentState.type == 'chart' && componentState.windrose == true){
            // reset bottom right pane
            var html ='<span class="drop-placeholder"><i class="icon-frame"></i> Trascina un parametro</span>';
            $("#macro-detail").empty();
            $("#macro-detail").append(html);
            $(".update-macro").text("Nuova macro");
            $("#settings-macro-title").text("Nuova macro");
            // clear macro form
            clearAllMacro();

            // disable specific button
            $(".disabled-windrose").prop("disabled", true);
            $(".disabled-windrose-opacity").css("opacity", "0.5");
            $(".hide-windrose").hide();
        }
        // table case
        else{
            // refresh tool's content with active macro metadata
            loadActiveMacro();
            // disable specific buttons
            $(".disabled-table").prop("disabled", true);
            $(".disabled-table-opacity").css("opacity", "0.5");

            // check if table is already initialized
            if (table[componentState.id]){
                //trigger full rerender including all data and rows
                table[componentState.id].redraw(true);
            }
        }
    });

    // initialize inputmask
    $("#date-start").inputmask({
        alias: "datetime",
        mask: "99/99/9999 99:99",
        insertMode: false,
        "oncomplete": function(){
            dateFrom = $("#date-start").val();
            console.log(dateFrom);
        }
    }).on('keyup', function(){
        // at change event, check for dates validity
        if( validDates($("#date-start").val(), $("#date-end").val(), 'date-start') )
            $('#ext-json').jstree(true).refresh_node("-9999");
    });

    dateFrom = moment().utc().add('-7','days').format('DD/MM/YYYY 00:00');
    $("#date-start").inputmask("setvalue", dateFrom);

    $("#date-end").inputmask( {
        alias: "datetime",
        mask: "99/99/9999 99:99",
        insertMode: false,
        oncomplete: function(){
            dateTo = $("#date-end").val();
            console.log(dateTo);
        }
    }).on('keyup', function(){
        // at change event, check for dates validity
        if( validDates($("#date-start").val(), $("#date-end").val(), 'date-end') )
            $('#ext-json').jstree(true).refresh_node("-9999");
    });

    dateTo = moment().utc().format('DD/MM/YYYY 23:59');
    $("#date-end").inputmask("setvalue", dateTo);

    // right json tree
    $('#ext-json').jstree({
        'core' : {
            // 'check_callback': true,
            'data' : {
                url: function (node) {

                    var url = "";
                    console.log('NODE.id: '+ node.id);

                    // different routes depending on the node level
                    if (node.id === '#')
                    {
                        url = "/str_ana_get_analyser_groups";
                    }
                    else
                    {
                        switch (node.li_attr.type) {
                            case 'group':
                                url = "/str_ana_get_group_stations";
                                break;
                            case 'group-limits':
                                url = "/str_ana_get_limits";
                                break;
                            case 'station':
                                url = "/str_ana_get_station_params";
                                break;
                            case 'param':
                                url = "/str_ana_get_params_type";
                                break;
                            case 'sites':
                                url = "/str_ana_get_allocations";
                                break;
                            case 'site_params':
                                url = "/str_ana_get_allocation_params";
                                break;
                            case 'site_params_type':
                                url = "/str_ana_get_allocation_params_type";
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
                    // different data sent to server depending on the node level
                    if( node.id === "#"){
                        return {"options": JSON.stringify(analyserOptions)};
                    }
                    else if( node.li_attr.type === 'sites' ){
                        var from = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');
                        var to = moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 23:59');
                        return {"nodeid": node.id, "id": node.li_attr.id, "from": from, "to": to};
                    }
                    else{

                        return {"nodeid": node.id, "id": node.li_attr.id, "type": node.li_attr.param_type, "options": JSON.stringify(analyserOptions)};
                    }

                }
            }
        },
        'plugins' : ["dnd", "search", "contextmenu"],
        'search' : {
            // ajax
            show_only_matches: true,
            show_only_matches_children: true
        },
        'contextmenu': {items: customMenuStation},

    });

    // SEARCH PLUGIN FOR JSTREE
    var to = false;
    // keyup event on search box
    $('#input-search').keyup(function () {
        if(to) { clearTimeout(to); }
        to = setTimeout(function () {
            var v = $('#input-search').val();
            $('#ext-json').jstree(true).search(v);
        }, 250);
    });
    // load node event
    $('#ext-json').on("load_node.jstree", function(e, data){

        console.log('node loaded');
        // initialize tooltip
        $('[data-toggle="tooltip"]').tooltip();
    });

    // load all nodes event
    $('#ext-json').on("load_all.jstree", function(e, data){
        console.log('Finito');
        // success message
        swal("Successo!", "Caricamento avvenuto con successo", "success");
    });

    // search event
    $('#ext-json').on("search.jstree", function(e, data){
        // return diltered nodes
        filtered_obj = data.nodes;
    });

    // click event on tree node
    $('#ext-json').on("changed.jstree", function (e, data) {

        // if a node has been clicked then continue
        if(data.selected.length) {
            var text;
            var node = data.instance.get_node(data.selected[0]);
            console.dir(node);
            // show log message
            // different message based on node type
            if(node.li_attr.type == 'station' || node.li_attr.type == 'site_params'){
                var stationName = node.text.replace(/<span .*<\/span>/g, '');
                text = ' -> '+node.li_attr.table+', <strong>station_id:</strong> '+node.li_attr.id;
                // write a info message in the log container
                log(stationName, text);
            }
            else if(node.li_attr.type == 'param'){
                var parent = data.instance.get_node(node.parent);
                // if it is a parameter grouped by type then go up one more level to the station
                if(parent.li_attr.type != 'station' && parent.li_attr.type != 'site_params'){
                    parent = data.instance.get_node(parent.parent);
                }
                text = ' -> '+parent.li_attr.table+', <strong>station_id:</strong> '+parent.li_attr.id+', <strong>stpr_id:</strong> '+node.li_attr.stprid+', <strong>param_id:</strong> '+ node.li_attr.prid +', <strong>stpr_table_id:</strong> '+node.li_attr.tbid;
                // write a info message in the log container
                log(node.text, text);
            }
        }
    });

    // left tree
    $('#macro-json').jstree({
        'core' : {
            // 'check_callback': true,
            'data' : {
                url: function (node) {

                    var url = "";
                    console.log('NODE.id: '+ node.id);

                    // different routes depending on the node level
                    if (node.id === '#')
                    {
                        url = "str_ana_get_groups";
                    }
                    else
                    {
                        switch (node.li_attr.type) {
                            case 'group':
                                url = "str_ana_get_group_macros";
                                break;
                            case 'macro':
                                url = "str_ana_get_macro_params";
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
                    // different data sent to server depending on the node level
                    if( node.id === "#"){
                        return;
                    }
                    else{

                        return {"nodeid": node.id, "id": node.li_attr.id, "options": JSON.stringify(analyserOptions)};
                    }

                }
            }
        },
        'plugins' : [ "contextmenu" ],
        'contextmenu': {items: customMenu}
    });
    // .on('show_contextmenu.jstree', function(e, reference, element) {

    //     if ( reference.node.parents.length < 2 ) {
    //         $('.vakata-context').remove();
    //     };
    // });

    // click event on json tree
    $('#macro-json').on("changed.jstree", function (e, data) {

        var event;

        if(data.event)
            event = data.event.originalEvent;

        // check if a node has been clicked
        if(data.node) {
            var node = data.node;

            // check if the node is a macro and it is a left click
            if(node.li_attr.type == 'macro' && event && event.which == 1){
                // get macro id stored insider the node
                var macroId = node.li_attr.id;
                var text = node.text +' -> mc_id: '+node.li_attr.id;
                // write a info message in the log container
                log('CLICK!', text);
                log('START', 'Recupero dati macro in corso...');
                // retrieve metada from server
                getMacroById(macroId)
            }
        }
    });
}

/**
 * Function that fills user's options form
 * No args needed
 */
function setOptions(){

    // generali
    // lista stazioni
    $("#visible-stid").prop("checked", analyserOptions.general.stidEnabled);
    $("#visible-altitude").prop("checked", analyserOptions.general.altitudeEnabled);
    $("#visible-allocations").prop('checked', analyserOptions.general.allocationsEnabled);
    $("#visible-limit-value").prop("checked", analyserOptions.general.limitsValueEnabled);
    // lista macro
    $("#visible-params").prop("checked", analyserOptions.general.paramsEnabled);
    // formato data
    $("#date-format").val(analyserOptions.general.dateFormat);
    // estrazione dati
    $("#data-converted").prop("checked", analyserOptions.general.convEnabled);
    $("#visible-treatment").prop("checked", analyserOptions.general.treatmentEnabled);
    $("#wind-scale").val(analyserOptions.general.windScale);

    // grafici
    // $("#chart-notes").attr("checked", analyserOptions.highstocks.notesEnabled);
    $("#chart-minmax").prop("checked", analyserOptions.highstocks.minmaxEnabled);
    $("#chart-subtitle").prop("checked", analyserOptions.highstocks.subtitleEnabled);
    $("#chart-nav").prop("checked", analyserOptions.highstocks.navigatorEnabled);
    $("#chart-label-x-angle").val(analyserOptions.highstocks.labelXangle);
    $("#chart-minor-grid").prop("checked", analyserOptions.highstocks.minorGridEnabled);
    $("#chart-hover-event").prop("checked", analyserOptions.highstocks.hoverEventEnabled);
    $("#chart-tooltip-type").val(analyserOptions.highstocks.tooltipType);
    $("#chart-title-font").val(analyserOptions.highstocks.titleFontSize);
    $("#chart-label-font").val(analyserOptions.highstocks.labelFontSize);
    $("#chart-legend-font").val(analyserOptions.highstocks.legendFontSize);
    $("#chart-num-label").val(analyserOptions.highstocks.numLabel);

    $("#exp-chart-width").val(analyserOptions.highstocks.expWidth);
    $("#exp-chart-height").val(analyserOptions.highstocks.expHeight);
    $("#exp-chart-title-font").val(analyserOptions.highstocks.expTitleFontSize);
    $("#exp-chart-label-font").val(analyserOptions.highstocks.expLabelFontSize);
    $("#exp-chart-legend-font").val(analyserOptions.highstocks.expLegendFontSize);
    $("#exp-chart-num-label").val(analyserOptions.highstocks.expNumLabel);

    // tabelle
    $("#table-minmax").prop("checked", analyserOptions.tabulator.minmaxEnabled);
    $("#table-codes").prop("checked", analyserOptions.tabulator.codesEnabled);
    $("#table-perc").prop("checked", analyserOptions.tabulator.percEnabled);
    $("#table-filters").prop("checked", analyserOptions.tabulator.filtersEnabled);
    $("#table-calc").prop("checked", analyserOptions.tabulator.calcEnabled);

      // $("#chart-group-data").attr("checked", analyserOptions.highstocks.dataGrouping.enabled);
}

/**
 * Function that fills user's options global variable with data inserted inside the form
 * and applies updates
 *
 * No args needed
 */
function applyOptions(){

    analyserOptions = {
        general: {
            // lista stazioni
            stidEnabled: $("#visible-stid").is(":checked"),
            altitudeEnabled: $("#visible-altitude").is(":checked"),
            allocationsEnabled: $("#visible-allocations").is(":checked"),
            limitsValueEnabled: $("#visible-limit-value").is(":checked"),
            // lista macro
            paramsEnabled: $("#visible-params").is(":checked"),
            // formato data
            dateFormat: $("#date-format").val(),
            // estrazione dati
            convEnabled: $("#data-converted").is(":checked"),
            treatmentEnabled: $("#visible-treatment").is(":checked"),
            windScale: parseInt($("#wind-scale").val())
        },
        tabulator: {
            minmaxEnabled: $("#table-minmax").is(":checked"),
            codesEnabled: $("#table-codes").is(":checked"),
            percEnabled: $("#table-perc").is(":checked"),
            filtersEnabled: $("#table-filters").is(":checked"),
            calcEnabled: $("#table-calc").is(":checked")
        },
        highstocks: {
            // notesEnabled: $("#chart-notes").is(":checked"),
            minmaxEnabled: $('#chart-minmax').is(":checked"),
            subtitleEnabled: $("#chart-subtitle").is(":checked"),
            navigatorEnabled: $("#chart-nav").is(":checked"),
            labelXangle: parseInt($("#chart-label-x-angle").val()),
            minorGridEnabled: $("#chart-minor-grid").is(":checked"),
            hoverEventEnabled: $("#chart-hover-event").is(":checked"),
            tooltipType: $("#chart-tooltip-type").val(),
            titleFontSize: parseInt($("#chart-title-font").val()),
            labelFontSize: parseInt($("#chart-label-font").val()),
            legendFontSize: parseInt($("#chart-legend-font").val()),
            numLabel: parseInt($("#chart-num-label").val()),
            // layout immagine esportata
            expWidth: parseInt($("#exp-chart-width").val()),
            expHeight: parseInt($("#exp-chart-height").val()),
            expTitleFontSize: parseInt($("#exp-chart-title-font").val()),
            expLabelFontSize: parseInt($("#exp-chart-label-font").val()),
            expLegendFontSize: parseInt($("#exp-chart-legend-font").val()),
            expNumLabel: parseInt($("#exp-chart-num-label").val()),
        },
        filter: {
            altitudeFilter: 0
        }
    };

    // refresh json trees
    $('#ext-json').jstree(true).refresh();
    $('#macro-json').jstree(true).refresh();

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    var aggr = (activeMacro != null) ? activeMacro.macro.aggregation : $('#time-period').val();

    // check that it is a chart tab and the chart is initialized
    if( componentState.type == 'chart' && chart[componentState.id] ){
        // create new options object in order to update highchart
        var options = {
            title: {
                style: {
                    fontSize: parseInt($("#chart-title-font").val())+'px'
                }
            },
            subtitle: {
                text: ( $("#chart-subtitle").is(":checked") ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+aggr+'"]').text()+']' : null ),
                style: {
                    fontSize: parseInt($("#chart-title-font").val() * 0.8)+'px'
                }
            },
            xAxis: {
                minorTicks: $("#chart-minor-grid").is(":checked"),
                labels: {
                    rotation: - parseInt($("#chart-label-x-angle").val()),
                    style: {
                        fontSize: parseInt($("#chart-label-font").val())+'px'
                    }
                },
                formatter: function() {

                    if( $("#date-format").val() == 'standard' ){

                        // return Highcharts.dateFormat('%d-%m-%Y', moment(this.value));
                        var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                        if (diff > (15*24*3600*1000)){ // 5 giorni
                            return getFormattedDateHC(this.value, 'basic'); //global.js
                        }
                        else{
                            // this.chart.xAxis[0].labels.rotation = 0;
                            return getFormattedDateHC(this.value, 'basic_timeStartMin');
                        }
                    }
                    else{
                        return getFormattedDateHC(this.value, $("#date-format").val() );
                    }
                }
            },
            yAxis: {
                minorTicks: ( activeMacro != null && activeMacro.macro.num_yaxis > 1 ) ? false : $("#chart-minor-grid").is(":checked"),
                labels: {
                    style: {
                        fontSize: parseInt($("#chart-label-font").val())+'px'
                    }
                },
                tickInterval: analyserOptions.highstocks.labelYstep
            },
            legend: {
                itemStyle: {
                    fontSize: parseInt($("#chart-legend-font").val())+'px'
                }
            },
            tooltip: {
                enabled: $("#chart-tooltip-type").val() != 'disabled' ? true : false,
                shared: $("#chart-tooltip-type").val() == 'shared' ? true : false,
            },
            plotOptions: {
                series: {
                    states: {
                        inactive: {
                            opacity:  $("#chart-hover-event").is(":checked") ? 0.2 : 1,
                        }
                    }
                }
            },
            exporting: {
                sourceWidth: analyserOptions.highstocks.expWidth,
                sourceHeight: analyserOptions.highstocks.expHeight,
                chartOptions: {
                    title: {
                        style: {
                            fontSize: analyserOptions.highstocks.expTitleFontSize+'px'
                        }
                    },
                    subtitle: {
                        style: {
                            fontSize: parseInt( analyserOptions.highstocks.expTitleFontSize * 0.8) +'px'
                        }
                    },
                    xAxis:{
                        0: {
                            lineColor: '#000000',
                            lineWidth: 1,
                            minorTicks: true,
                            labels: {
                                rotation: - analyserOptions.highstocks.labelXangle,
                                style: {
                                    color: '#000000',
                                    fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                                }
                            }
                        }
                    },
                    yAxis: {
                        0: {
                            lineColor: '#000000',
                            lineWidth: 1,
                            minorTicks: true,
                            title: {
                                enabled : false
                            },
                            showLastLabel: true,
                            labels: {
                                style: {
                                    color: '#000000',
                                    fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                                }
                            }
                        }
                    },
                    legend:{
                        align: 'center',
                        width: '100%',
                        itemDistance: 50,
                        itemStyle: {
                            fontSize: analyserOptions.highstocks.expLegendFontSize+'px',
                            fontWeight: 'normal'
                        },
                        margin: 2
                    }
                }
            }
        };

        chart[componentState.id].update(options);
    }

    // if active macro is not null or tab is of windrose type
    if(activeMacro != null || componentState.windrose == true){
        // trigger click on button "Aggiorna"
        $("#update-data").trigger('click');
    }
    // swal("Successo!", "Nuove impostazioni applicate con successo. Saranno visibili alla creazione di nuovi/e grafici/tabelle", "success");
    return;
}

/**
 * Function that saves user's options in the DB
 * No args needed
 */
function saveOptions(){

    console.log('saveOptions');
    // send options via an ajax call
    var jqxhr = $.ajax({
        url: '/str_ana_put_analyser_user_options',
        type: "post",
        dataType: "json",
        data: {
            options: JSON.stringify(analyserOptions)
        }
    })
    .done(function(result) {
        console.dir(result);
        // check result
        if(result){
            // success message
            swal("Successo!", "Le impostazioni sono state salvate con successo", "success");
        }
        else{
            // error message
            swal("Errore!", "Errore durante il salvataggio delle impostazioni", "error");
        }

    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");

    });
}

/**
 * Function that fill bottom central pane with notes retrieved from server
 *
 * @param {array} notes: Array of notes
 */
function fillNotes(notes){

    // variable for dynamically build the html
    var htmlNotes = '<tbody>';
    // loop through all notes
    // for each element build a row to be added to the main table
    $.each(notes, function (idx, note) {
        htmlNotes += '<tr class="note-row" data-id="'+note.note_id+'" data-stprid="'+note.stpr_id+'">';
        htmlNotes += '    <td><strong>'+moment(note.note_fulldate).format('DD-MM-YYYY HH:mm')+'</strong></td>'
        htmlNotes += '    <td>'+note.station_name+'</td>';
        htmlNotes += '    <td>'+note.note_title+'</td>';
        htmlNotes += '    <td>'+note.note_instr_value+'</td>';
        htmlNotes += '</tr>';
    });

    // append notes
    htmlNotes += '</tbody>';
    $('#notes').html(htmlNotes);
}

/**
 * Function that clears all macro fields
 * No args needed
 */
function clearAllMacro(){

    var html_select_params = '<option value="-1">Seleziona...</option>';
    $("#macro-param-main").empty();
    $("#macro-param-main").append(html_select_params);

    // clear parameter form
    clearParamsMacro();
    $('#main-macro-form .clear-macro').val('');
    $('#main-macro-form select.clear-macro').val(-1);
    // reset fields with default value
    $('#macro-aggregation option:first').prop('selected', true);
    $('#macro-valid-data').val(75);
    $("#macro-validity-operator").prop("disabled", false);
    $('#macro-validity-operator option.default-val').prop('selected', true);
    $('#macro-validity-operator').trigger('change');
    $('#macro-num-yaxis').val(1);
}

/**
 * Function that clears all parameter fields
 * No args needed
 */
function clearParamsMacro(){

    // reset all fields with default value
    $('#macro-param-main').val(-1);
    $('#macro-param-details').hide();
    $('#macro-param-details .clear-macro').val('');

    $('#macro-param-min').prop("checked", false);
    $('#macro-param-max').prop("checked", false);

    $('#macro-param-moving-window').val(8);
    range.val(0.2).change();
    range.rangeslider('update', true);
    $('#macro-param-chartcolor').val("#FFFFFF");
    $('#macro-param-chartcolor').css('background-color', "#FFFFFF");
}

/**
 * Function that resets active tab
 *
 * @param {object} contentItem: active component object
 */
function resetTab(contentItem){

    // get default values for validity
    var operator =  $(".valcode-menu .validation-operators .default-val").text();
    var code = $(".valcode-menu .dropdown-item.default-val").data('id');

    console.log('resetActiveTab')
    var tabElement = contentItem;
    // reset macro info stored inside the component
    tabElement.config.componentState.macroId = null;
    tabElement.config.componentState.elementMacro = {
                                                    macro : {
                                                        name: 'Nuova macro',
                                                        description: 'Macro di partenza',
                                                        int_time: 0,
                                                        legendx_angle: 0,
                                                        label_yaxis: null,
                                                        step_yaxis: null,
                                                        aggregation: $("#time-period option.def").val(),
                                                        percent_data: $("#percent-data").val(),
                                                        validity_code: operator+' '+code,
                                                        reload: false
                                                    },
                                                    params: []
                                                };

    var componentState = tabElement.config.componentState;
    console.dir(componentState);
    // check if it is a tab of type "standard chart"
    if(componentState.type == 'chart' && componentState.multiple == false){

        // reset notes and destroy chart
        tabElement.config.componentState.notes = null;
        if(chart[componentState.id]){
            console.log('Destroy chart');
            chart[componentState.id].destroy();
            chart[componentState.id] = null;
        }
        // clear html container
        $('#chart_container_'+componentState.id).empty();
    }
    // check if it is a tab of type "multiple charts"
    else if(componentState.type == 'chart' && componentState.multiple == true){
        if(multipleCharts[componentState.id] && multipleCharts[componentState.id].length > 0){
            // destroy all charts
            console.log('Destroy all sync charts');
            $.each(multipleCharts[componentState.id], function(index, el){
                el.destroy();
            });
            // clear html container
            $('#chart_container_'+componentState.id).empty();
            multipleCharts[componentState.id] = null;
        }
    }
    // table case
    else{
        // destroy table and clear variable
        if(table[componentState.id]){
            console.log('Destroy table');
            table[componentState.id].destroy();
            table[componentState.id].clearData();
            table[componentState.id] = null;
        }
    }
}

/**
 * Function that resets all tabs
 * No args needed
 */
function resetAllTabs(){

    // get the number of tabs inside the central container
    var tabs = centralContainer.header.tabs;
    var index = tabs.length-1;

    // starting from the last tab
    // call function reset tab
    for(; index >= 0; index--) {

        var tab = tabs[index];
        resetTab(tab.contentItem);
        var componentState = tab.contentItem.config.componentState;

        // remove all tabs except the first 2
        if(componentState.id != 0 && componentState.id != 1){
            centralContainer.removeChild( tab.contentItem );
        }
    };

    // get default values for validity
    var operator =  $(".valcode-menu .validation-operators .default-val").text();
    var code = $(".valcode-menu .dropdown-item.default-val").data('id');
    //  create new empty macro
    activeMacro = {
        macro : {
            name: 'Nuova macro',
            description: 'Macro di partenza',
            int_time: 0,
            legendx_angle: 0,
            label_yaxis: null,
            step_yaxis: null,
            aggregation: $("#time-period option.def").val(),
            percent_data: $("#percent-data").val(),
            validity_code: null
        },
        params: []
    };

    // refresh tool's content with active macro metadata
    loadActiveMacro();

    // resets all contents
    $('#notes').empty();
    $('#time-period').val($("#time-period option.def").val());
    $('#percent-data').val(75);
    $('#copertura').text('75%');
    $('.valcode-menu .default-val').trigger('click');

    // reset global variables
    counter = 1;
    chart = [];
    table = [];
    return;
}

/**
 * Function that changes chart's series type
 *
 * @param {string} seriesType: New series type
 */
function updateTypeChart(seriesType){

    console.log('updateTypeChart');

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var options;

    // if it is a table tab or chart is not initialized then return and do nothing
    if( componentState.type != 'chart' || !chart[componentState.id] ){
        return;
    }

    // get chart series
    var series = chart[componentState.id].series;
    // loop through all series
    // for each element update plot type
    $.each(series, function (key, el) {
        console.log(el.options.id);
        var param;
        if(componentState.perYear == true)
            param = activeMacro.params[0];
        else if(el.options.macroIdx != null){
            param = activeMacro.params[el.options.macroIdx];
        }
        else 
            return true;

        param.chartstyle = seriesType;
        // create a different option object based on the new plot type
        if(seriesType == 'point' || seriesType == 'line_marker'){
            options = {
                type: 'line',
                lineWidth: (seriesType == 'line_marker') ? param.line_width : 0,
                marker: {
                    enabled: true,
                    radius: param.line_width*1.5
                }
            };
        }
        else{
            options = {
                type: seriesType,
                lineWidth: param.line_width,
                marker: {
                    enabled: false,
                }
            };
        }

        // update series without redrawing it
        if( el.points && el.points.length > 0){
            el.update(options);
        }
    });

    // redraw chart
    chart[componentState.id].redraw();
}

// funzione per modificare zoom asse Y
/**
 * Function that updates visible range of Y axis
 *
 * @param {number} min: Min value
 * @param {number} max: Max value
 */
function updateYaxisZoom(min, max){
    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    console.log(componentState.type);

    // if it is a table tab or chart is not initialized then return and do nothing
    if( componentState.type != 'chart' || !chart[componentState.id] ){
        return;
    }

    // update y axis extremes
    chart[componentState.id].yAxis[0].setExtremes(min, max);
}

/**
 * Function that updates chart zoom type
 *
 * @param {string} type: New type -> x, y or xy
 */
function updateZoomType(type){

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    console.log(componentState.type);

    // if it is a table tab or chart is not initialized then return and do nothing
    if( componentState.type != 'chart' || !chart[componentState.id] ){
        return;
    }

    // create an option object
    var options =  {
                chart: {
                    // zoomType: type
                    zooming: {
                        type: type
                    }
                }
            };

    // loop through all initialized charts and update them
    chart.forEach(function(el, idx){

        if(el)
            el.update(options,false);
    });
}

/**
 * Function used for updating the number of y axes of active chart
 * No args needed
 */
function addYaxis(){

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    console.log(componentState.type);

    // if it is a table tab or chart is not initialized then return and do nothing
    if( componentState.type != 'chart' || !chart[componentState.id] ){
        return;
    }

    // remove gridline
    var options = {
        yAxis:  {
            gridLineWidth : 0
        }
    };
    chart[componentState.id].update(options);

    // if navigator is enable there is one more axis to take into account
    var navigatorAxis = 0;
    if(chart[componentState.id].options.navigator.enabled )
        navigatorAxis = 1;

    // calculate the difference between the number of axes defined in the macro and those present in the graph
    var diff = (activeMacro.macro.num_yaxis + navigatorAxis) - chart[componentState.id].yAxis.length;

    // if diff is greater than 0 then i need to add |diff| axes
    // else i need to remove |diff| axes
    if(diff > 0){

        for(; diff > 0; diff --){
            // add axis
            chart[componentState.id].addAxis({ // Secondary yAxis
                startOnTick: false,
                endOnTick: false,
                isInternal: false,
                lineWidth: 1.5,
                opposite: true,
                gridLineWidth : 0
            });
        }
    }
    else{

        // make it positive
        diff = diff*(-1);
        var len = chart[componentState.id].yAxis.length;
        for(var key = 1; key <= diff; key++){
            chart[componentState.id].yAxis[len-key].remove(true);
        }

        // if the number of axes is equal to 1
        // enable gridline
        if(activeMacro.macro.num_yaxis == 1){
            var options = {
                yAxis:  {
                    gridLineWidth : 1
                }
            };
            chart[componentState.id].update(options);
        }
    }
    // trigger click on button "Aggiorna"
    $("#update-data").trigger('click');
}

/**
 * Function that adds to the active chart a temporary horizontal line with a specific value
 *
 * @param {number} lineValue: Line value
 *
 * @return true or false (as 1 and 0) based on the result of the operation
 */
function addHorizontalLine(lineValue){

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // if chart is not initialized then retunr and do nothing
    if( !chart[componentState.id] ){
        return 0;
    }

    var id = 0;
    // check if there are other plot lines
    // if true set the starting index as the number of all lines
    if( chart[componentState.id].yAxis[0].plotLinesAndBands){
        id = chart[componentState.id].yAxis[0].plotLinesAndBands.length;
    }

    // create option object
    var lineOption = {
        // className:undefined
        // label:{
        //      text:
        // }
        id: 'line'+id,
        color: 'red',
        dashStyle: 'ShortDot',
        value: lineValue,
        width:2
    };

    // add plot line
    chart[componentState.id].yAxis[0].addPlotLine(lineOption);
    return 1;
}

/**
 * Function that adds to the active chart a temporary note
 *
 * @param {string} note: Text of the note
 *
 * @return true or false (as 1 and 0) based on the result of the operation
 */
function addChartAnnotation(note){
    // get active components
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // if chart is not initialized then return and do nothing
    if( !chart[componentState.id] ){
        return 0;
    }

    var id = 0;
    // check if there are other annotations
    // if true set as the starting point the annotations number
    if( chart[componentState.id].annotations ){
        id = chart[componentState.id].annotations.length;
    }

    // create option object
    var options = {
        id: 'ann'+id,
        draggable: 'xy',
        labels: [{
            point: {
                x: 50,
                y: 50
            },
            style: {
                fontSize: '14px'
            },
            shape: 'rect',
            text: note
        }]
    };

    // add annotation
    chart[componentState.id].addAnnotation(options);
    return 1;
}

/**
 * Function that adds plot bands to the active chart
 * No args needed
 *
 * @return true or false (as 1 and 0) based on the result of the operation
 */
function addPlotBands(){
    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // if chart is not initialized then return and do nothing
    if( !chart[componentState.id] ){
        return 0;
    }

    // show preloader, waiting for the end of the process
    $('.preloader').show();
    // get bands ranges via an ajax call
    var jqxhr = $.ajax({
        url: '/str_ana_get_wind_scale',
        type: "post",
        dataType: "json",
        data: {
            scaleid : analyserOptions.general.windScale
        }
    })
    .done(function(result) {
        console.dir(result);

        // parse result
        var plotBands = JSON.parse(result.scale.ws_obj);

        // no more used
        // var max = 0;
        // // loop through all chart series and get max value
        // chart[componentState.id].series.forEach(function(el, idx){

        //     if(el.dataMax > max )
        //         max = el.dataMax;
        // });

        // variable for building bands ranges
        var positions = [];
        var htmlLabels = [];

        // loop through all plotbands retrieved from DB
        // for each element build an option object
        plotBands.forEach(function(el, idx){
            var plotBand = {
                id: 'band'+idx,
                from: el.from,
                to: el.to,
                color: idx % 2 == 0 ? 'rgba(68, 170, 213, 0.1)' : 'rgba(0, 0, 0, 0)',
                // outerRadius: '120%',
                // label: {
                //     text: '<strong>'+el.name+'</strong>',
                //     useHtml : true,
                //     textAlign: 'left',
                //     align: 'right',
                //     x: -20,
                //     style: {
                //         opacity: (idx < 3 && max > 28.4) ? 0 : 1
                //     }
                // }
            };

            // push labels and starting point of plot bands
            positions.push(el.from);
            htmlLabels.push(el.from+' <strong>'+el.name+'</strong>');
            // if current loop is the last one then push the end position of last band
            if(idx == plotBands.length-1)
                positions.push(el.to);

            // add band to chart
            chart[componentState.id].yAxis[0].addPlotBand(plotBand);
        });

        console.dir(htmlLabels);

        // add an additional Y axys with labels and values previously stored inside variables
        chart[componentState.id].addAxis({ // Secondary yAxis
            isInternal: false,
            lineWidth: 1.5,
            opposite: true,
            gridLineWidth : 0,
            linkedTo: 0,
            title: {
                text: result.scale.ws_name,
                align: 'high',
                offset: 0,
                rotation: 0,
                y: -10,
                x: 5
            },
            labels:{
                useHtml : true,
                formatter: function(){

                    var value = this.value;
                    var obj = plotBands.find( function(o){
                        return parseFloat(o.from) === parseFloat(value);
                    });

                    if(obj)
                        return obj.from+' - <strong>'+obj.name+'</strong>';
                    else
                        null;

                }
            },
            tickPositions: positions
        });

        // chart[componentState.id].options.chart.spacingRight = 60;
        // chart[componentState.id].isDirtyBox = true;

        // refresh chart
        chart[componentState.id].redraw();
        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Errore durante il recupero dei valori della scala vento", "error");
    });

    return 1;
}

/**
 * Function that clears active chart from annotations and temporary lines
 * No args needed
 */
function clearChart(){

    // get active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // if chart is not initialized then return and do nothing
    if( !chart[componentState.id] ){
        return;
    }

    // loop through all lines and bands and remove them
    var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
    $.each(plotLinesAndBands, function(key, line){
        chart[componentState.id].yAxis[0].removePlotLine('line'+key);
    });

    var annotations = chart[componentState.id].annotations;
    // loop through all annotations and remove them
    for (let i = annotations.length - 1; i > -1; --i) {
        chart[componentState.id].removeAnnotation(annotations[i]);
    }

    // redraw chart
    chart[componentState.id].redraw();
}