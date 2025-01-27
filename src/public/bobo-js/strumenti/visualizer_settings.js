// GLOBAL VARIABLES
var visualizerToolOptions; // tool general options
var visualizerOptions; // user options
var exportinChartOptions;

// array of active macros (one for each box)
var arrayMacros;

var dateFrom;
var dateTo;
var dirtyDates = false;

/**
 * Document ready
 */
$(document).ready(function() {

    // hide tools preloader
    $('.preloader').hide();
    // initialize all selec2 elements
    $(".select2").select2();
    // initialize all tooltips
    $('[data-toggle="tooltip"]').tooltip();

    // reflow visualizer container
    resizeWindowsV();

    // for mobile viewport, button in order to reduce the top menu
    $('#no-slide').on( 'click', '.can-close-me', function () {
        // toggle classes and visibility in order to hide/show more options
        $( ".analyser-buttons .close-me" ).toggle();
        $('#no-slide .can-close-me i').toggleClass("fa-chevron-down fa-chevron-up");
        // reflow visualizer container
        resizeWindowsV();
    });

    // on resize event, reflow visualizer container
    $( window ).resize(function() {
        // reflow visualizer container
        resizeWindowsV();
    });

    //!! FIRST MENU
{
    // !!MENU >> STRUMENTI

    // change events on font size for export aims of the chart
    // check if selected size is between 5 and 15 otherwise correct it
    $("#exp-chart-title-font, #exp-chart-label-font, #exp-chart-legend-font").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 15 ? 15 : val && val < 5 ? 5 : val;
    });

    // change events on font size for graphic aims of the chart
    // check if selected size is between 5 and 30 otherwise correct it
    $("#chart-title-font, #chart-label-font, #chart-legend-font").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 1);
        this.value = val > 30 ? 30 : val && val < 5 ? 5 : val;
    });

    // change events on inclination of the labels for graphic aims of the chart
    // check if selected inclination is lower than 90 otherwise correct it
    $("#label-x-axis").on("change", function() {
        var val = Math.abs(parseInt(this.value, 10) || 0);
        this.value = val > 90 ? 90 : val;
    });

    // click event on reset button
    $("#reset-settings").on("click", function(e){
         e.preventDefault();
         // IMPOSTAZIONI DI DEFAULT

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

            // object with default options
            visualizerOptions = {
                general: {
                    // nome serie
                    treatmentEnabled: false
                },
                tabulator: {
                    codesEnabled: true
                },
                highstocks: {
                    legendEnabled: true,
                    minorGridEnabled: false,
                    hoverEventEnabled: true,
                    tooltipType: 'standard',
                    labelXangle: 0,
                    titleFontSize: 16,
                    labelFontSize: 11,
                    legendFontSize: 10,
                    // layout immagine esportata
                    expWidth: 600,
                    expHeight: 400,
                    expTitleFontSize: 16,
                    expLabelFontSize: 11,
                    expLegendFontSize: 10
                },
                filter: {
                   altitude: 0
                }
            };
            // call function in order to fill form with default options
            setOptions();

        });
    });

    // click event on apply button
    $("#apply-settings").on("click", function(e){
        e.preventDefault();
        // call function in order to apply selected options
        applyOptions();
        // at the end show success message
        swal("Successo!", "Nuove impostazioni applicate con successo. Saranno visibili alla creazione di nuovi/e grafici/tabelle", "success");
    });

    // click event on save button
    $("#save-settings").on("click", function(e){
        e.preventDefault();
        // show preloader, waiting for the end of the process
        $('.preloader').show();
        // apply options
        applyOptions();
        // save changes to database
        saveOptions();
    });
    // END MENU >> STRUMENTI

    // !!MENU >> DATI

    // initialize inputmask
    $("#percent-data").inputmask('numeric',{min:0, max:100, allowMinus: false});

    // click on confirm button
    $("#percent-data-confirm").on('click', function(e){

        e.preventDefault();
        // if field is empty then set default value to 75%
        if( $("#percent-data").val() == '' )
            $("#percent-data").val(75);

        // loop through all active macros and set new value of percent data
        arrayMacros.forEach(function(macro, macroIdx){

            macro.macro.percent_data = $("#percent-data").val();
            // update macro visible metadata
            putMacroToPanel(macroIdx, true);
        });

        // set text with new value and hide modal
        $('#copertura').text($("#percent-data").val()+'%');
        $('#dati-copertura').modal("hide");
    });

    // click on default percent values
    $(".percent-data-value").on('click', function(e){
        e.preventDefault();
        // retrieve value and set the input
        var value = parseFloat($(this).data('val'));
        $("#percent-data").val(value);
        // trigger confirm
        $("#percent-data-confirm").trigger('click');
    });
    // END MENU >> DATI

    // !!MENU >> VALIDITA

    // prevent the dropdown of the validity code selection from closing after the click
    $('#validity-codes .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // click on validity menu element
    // selection or deselection action on a operator button
    $(".valcode-menu .validation-operators button").on('click', function(e){
        e.preventDefault();

        // get previous selected operator
        var previousOperator = $(".valcode-menu .validation-operators button.sel").text();
        // if it's equal to = and new operator is different from previous one and selected codes are more than 1
        // then reset all codes and select the default one
        if( previousOperator == '=' && $(this).text() != previousOperator && $(".valcode-menu a.dropdown-item.sel").length > 1){

            // loop though all selected codes
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){
                // remove class and icon
                $(this).removeClass('sel');
                $(this).find('i').remove();
            });

            // select default value by class default-val
            $(".valcode-menu a.dropdown-item.default-val").addClass('sel');
            $(".valcode-menu a.dropdown-item.default-val").append(' <i class="mdi mdi-check text-danger"></i>');
        }

        // remove class sel to previous operator and select the new one
        $(".valcode-menu .validation-operators button").removeClass('sel');
        $(this).addClass('sel');

        // get operator text
        var operator =  $(".valcode-menu .validation-operators button.sel").text();
        var validity;

        // if Tutti i dati then code is null
        // else loop through all selected codes (class sel) and build an array
        if($(".valcode-menu a.dropdown-item.sel").length == 1 && $(".valcode-menu a.dropdown-item.sel").data('id') == null)
            validity = null
        else{

            validity = [];
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){

                validityStr = operator+' '+$(this).data("id");
                validity.push(validityStr);
            });
        }

        // loop through all active macros
        // foreach of them set new validity filter and update visible metadata
        arrayMacros.forEach(function(macro, macroIdx){

            macro.macro.validity_code = (validity ? validity.join(', ') : validity);
            putMacroToPanel(macroIdx, true);
        });
    });

    // click on validity menu element
    // selection or deselection action on a validity code
    $(".valcode-menu a.dropdown-item").on('click', function(e){

        e.preventDefault();
        // retreive selected operator by class "sel"
        var operator =  $(".valcode-menu .validation-operators button.sel").text();

        // if operator = and the user has not selected Tutti i dati
        // in this case the user can select more than 1 validity code
        if( operator == '=' && $(this).data("id") != null ){

            // remove icon and class to all validity code options
            $('.valcode-menu a.dropdown-item').not('[data-id]').removeClass('sel');
            $('.valcode-menu a.dropdown-item').not('[data-id]').find('i').remove();

            // if it has sel class I'm deactivating it...
            // check that at least one code remains selected otherwise block it
            if( $(this).hasClass('sel') && $(".valcode-menu a.dropdown-item.sel").length == 1 ){
                return false;
            }

            // add/remove class sel
            $(this).toggleClass('sel');
            // add/remove icon
            if( $(this).find('i').length != 0)
                $(this).find('i').remove();
            else
                $(this).append(' <i class="mdi mdi-check text-danger"></i>');
        }
        else{
            // remove icon and class to all validity code options
            $(".valcode-menu a.dropdown-item").removeClass('sel');
            $(".valcode-menu a.dropdown-item").find('i').remove();
            // add icon and class to selected option
            $(this).addClass('sel');
            $(this).append(' <i class="mdi mdi-check text-danger"></i>');
        }

        // get selected code
        var code = $(this).data("id");
        var validity;

        // if Tutti i dati then code is null
        // else loop through all selected codes (class sel) and build an array
        if(code == null)
            validity = null;
        else{

            validity = [];
            $(".valcode-menu a.dropdown-item.sel").each(function(idx){

                validityStr = operator+' '+$(this).data("id");
                validity.push(validityStr);
            });
        }

        // loop through all active macros
        // foreach of them set new validity filter and update visible metadata
        arrayMacros.forEach(function(macro, macroIdx){

            macro.macro.validity_code = (validity ? validity.join(', ') : validity);
            putMacroToPanel(macroIdx, true);
        });

    });
    //  END MENU >> VALIDITA
}

    //!! SECOND MENU
{
    // prevent the dropdown of the start date selection from closing after the click
    $('#start-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // prevent the dropdown of the end date selection from closing after the click
    $('#end-date-btns .dropdown-menu').on({
        "click":function(e){
            e.stopPropagation();
        }
    });

    // change event of categories select
    $("#group-categories").on('change', function(e){
        // get selected category
        var catId = parseInt($(this).val());
        // refresh panels list
        getPagesByCategory(catId);

    });

    // change event of panels select
    $("#group-pages").on('change', function(e){

        // retrieve panel id
        var pgId = parseInt($(this).val());
        // if no one has been selected then reset visualizer container
        // else set header and footer titles and load selected panel
        if(pgId == -1)
            resetPage(true);
        else{
            var pgName = $("#group-pages option:selected").text();

            $('#main-vis-title span').text(pgName);
            $('#main-vis-footer span').text(pgName);
            getMacrosByPage(pgId);
        }
    });

    // CLICK EVENTS
    // DATES INPUT

    // click on date options
    // set start date as today
    $("#start-date-today").on('click', function(e){
        e.preventDefault();
        // set global variable
        dateFrom = moment().utc().format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // set start date as first day of the current month
    $("#start-date-curr-fdm").on('click', function(e){
        e.preventDefault();
        // set global variable
        dateFrom = moment().format('01/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // set start date as first day of the current year
    $("#start-date-curr-fdy").on('click', function(e){
        e.preventDefault();
        // set global variable
        dateFrom = moment().format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // set start date as first day of the selected month
    $("#start-date-fdm").on('click', function(e){
        e.preventDefault();
        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/MM/YYYY 00:00'); // global.js
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start');
    });

    // click on date options
    // set start date as first day of the selected year
    $("#start-date-fdy").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('01/01/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // decrease start date day by 1
    $("#start-date-pd").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // decrease start date month by 1
    $("#start-date-pm").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // decrease start date year by 1
    $("#start-date-pa").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // increase start date day by 1
    $("#start-date-nd").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // increase start date month by 1
    $("#start-date-nm").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // increase start date year by 1
    $("#start-date-na").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateFrom = moment(dateFrom, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 00:00');
        $("#date-start").inputmask("setvalue", dateFrom);
        // validate dates
        validDates(dateFrom, $("#date-end").val(), 'date-start'); // global.js
    });

    // click on date options
    // set end date as today
    $("#end-date-today").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment().utc().format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // set end date as the start one
    $("#end-date-copy").on('click', function(e){
        e.preventDefault();

        // set global variable
        var t = moment(dateFrom, 'DD/MM/YYYY HH:mm');

        if(t.isSame(moment(), 'day'))
            dateTo = moment().utc().format('DD/MM/YYYY HH:00');
        else
            dateTo = t.format('DD/MM/YYYY 23:59');

        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // set end date as the last day of the year
    $("#end-date-ldy").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').format('31/12/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // set end date as the last day of the month
    $("#end-date-ldm").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').endOf('month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // decrease end date day by 1
    $("#end-date-pd").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // decrease end date month by 1
    $("#end-date-pm").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // decrease end date year by 1
    $("#end-date-pa").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(-1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // increase end date day by 1
    $("#end-date-nd").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'day').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // increase end date month by 1
    $("#end-date-nm").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'month').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // click on date options
    // increase end date year by 1
    $("#end-date-na").on('click', function(e){
        e.preventDefault();

        // set global variable
        dateTo = moment(dateTo, 'DD/MM/YYYY HH:mm').add(+1, 'years').format('DD/MM/YYYY 23:59');
        $("#date-end").inputmask("setvalue", dateTo);
        // validate dates
        validDates($("#date-start").val(), dateTo, 'date-end'); // global.js
    });

    // change event on aggegations select
    $("#time-period").on("change", function(e){
        e.preventDefault();

        // loop through all active macros and update the aggregation
        arrayMacros.forEach(function(macro, macroIdx){
            macro.macro.aggregation = $('#time-period').val();
            // refresh visible metdata
            putMacroToPanel(macroIdx, true);
        });
    });

    // LOAD DATA WITH SELECTED OPTIONS
    // click on Aggiorna button
    $("#update-data").on("click",function(e){
        e.preventDefault();

        // set first flag
        var first = true;
        // get selected dates
        dateFrom = $("#date-start").val();
        dateTo = $("#date-end").val();

        // check if are valid
        if( ! validDates(dateFrom, dateTo, 'date-start') ){
            console.log('Non valido');
            swal('Attenzione!', 'Date inserite non valide', 'warning');
            return;
        }

        // loop through all active macros
        arrayMacros.forEach(function(macro, macroIdx){
            // if first loop then
            // show preloader, waiting for the end of the process
            if(first){
                $('.preloader').show();
                first = false;
            }

            // use setTimeout function in order to refresh panel asynchronously
            setTimeout(function(){
                // if first load of panel (dirtyDates == false) and macro has default range of days selected
                // simulate click on 4th panel button in order to load data in a specific daterange
                if(!dirtyDates && macro.macro.days && macro.macro.days != ''){
                    $('#vis_window_'+macroIdx+' .select-days').val(macro.macro.days);
                    $('#vis_window_'+macroIdx+' .change-days').trigger('click');
                }
                // otherwise reset days option and remove classes on 4th button
                else{
                    macro.macro.days = '';
                    $('#vis_window_'+macroIdx+' .select-days').val('').trigger('change');
                    $('#vis_window_'+macroIdx+' .show-calendar').removeClass('sel');
                    // refresh chart
                    refreshChart(macroIdx);
                }

                // check if it is the last loop
                if(macroIdx == arrayMacros.length-1){
                    // set dirtyDates to true
                    // from now all Aggiorna action should take dates from input at the top of the tool
                    dirtyDates = true;
                }
            }, 10);


        });
    });

    // UPDATE CHARTS TYPE
    // click on Tipo grafico button
    $("#typechart a").on("click", function(e){
        e.preventDefault();
        // get selected type
        var type = $(this).data('type');
        // show preloader, waiting for the end of the process
        $('.preloader').show();

        // use setTimeout function in order to refresh panel asynchronously
        setTimeout(function(){
            // update charts type
            updateTypeChart(type);
        }, 10);
    });

    $("#treatment a").on("click", function(e){
        e.preventDefault();

        // get selected type
        var type = $(this).data('type');
        console.log(type);

        // loop through all active macros and foreach of it loop through all parameters
        // set the new treatment type
        arrayMacros.forEach(function(macro, macroIdx){

            macro.params.forEach(function (param, key) {
                param.treatment = type;
            });
        });
        // trigger click on Aggiorna button
        $("#update-data").trigger('click');
    });
} // END SECOND MENU

    //!! PANEL BUTTONS
{
    // click event on Apri fullscreen button
    $('#main-vis-windows').on( 'click', '.to-fullscreen', function(e){
        e.preventDefault();
        // get box index
        var macroIdx = parseInt($(this).parent().siblings('.chart-bar').data('idx'));
        // get box element
        var box = $(this).parent().parent();
        // add class fullscreen, modify icon and class of clicked button
        $(box).addClass('fullscreen');
        $(this).html('<i class="icon-size-actual"></i>');
        $(this).toggleClass('to-fullscreen not-fullscreen');

        // dynamically resize chart based on device viewport
        charts[macroIdx].setSize(
            null,
            window.visualViewport.height - 100, // 26px header, 30px footer, 65px legend
            false
        );

        // update chart options
        var options = {
            chart: {
                marginBottom: 120
            },
            legend: {
                height: 90,
                maxHeight: 95,
                itemWidth: 300,
                itemStyle: {
                    fontSize: (visualizerOptions.highstocks.legendFontSize+2)+'px',
                    width: 280
                }
            }
        };
        charts[macroIdx].update(options, false);
        // redraw chart
        charts[macroIdx].redraw();

        // loop through all legend items
        charts[macroIdx].legend.allItems.forEach(function(item){

            // overwrite click event
            Highcharts.addEvent(
                item.legendItem.group.element,
                'click',
                function(e) {
                    // Check if the control key was down when the mouse event was fired.
                    // if true then hide all series except the one clicked
                    if(e.ctrlKey == true){
                        charts[macroIdx].series.forEach(function(series){
                            series.hide();
                        });
                        item.show();
                    }
                }.bind(this)
            );
        });
    });

    // click event on Chiudi fullscreen button
    $('#main-vis-windows').on( 'click', '.not-fullscreen', function(e){
        e.preventDefault();
        // get box index
        var macroIdx = parseInt($(this).parent().siblings('.chart-bar').data('idx'));
        // remove class fullscreen, modify icon and class of clicked button
        $(this).parent().parent().removeClass('fullscreen');
        $(this).html('<i class="icon-size-fullscreen"></i>');
        $(this).toggleClass('not-fullscreen to-fullscreen');

        // dynamically resize chart to fixed height
        charts[macroIdx].setSize(
            null,
            350,
            false
        );
        // update options
        var options = {
            chart: {
                marginBottom: 95
            },
            legend: {
                height: 60,
                maxHeight: 65,
                itemWidth: 180,
                itemStyle: {
                    fontSize: (visualizerOptions.highstocks.legendFontSize)+'px',
                    width: 150,
                }
            }
        };
        charts[macroIdx].update(options, false);
        // redraw chart
        charts[macroIdx].redraw();

        // loop through all legend items
        charts[macroIdx].legend.allItems.forEach(function(item){

            // overwrite click event
            Highcharts.addEvent(
                item.legendItem.group.element,
                'click',
                function(e) {
                    // Check if the control key was down when the mouse event was fired.
                    // if true then hide all series except the one clicked
                    if(e.ctrlKey == true){
                        charts[macroIdx].series.forEach(function(series){
                            series.hide();
                        });
                        item.show();
                    }
                }.bind(this)
            );
        });
    });

    // click event on Visualizza grafico
    $('#main-vis-windows').on( 'click', '.show-chart', function () {
        // check if it is already selected
        var isSelect = $(this).hasClass("sel");
        if(isSelect == false){
            // show div with chart
            $(this).parent().siblings( ".chart" ).show();
            // hide div with table
            $(this).parent().siblings( ".html-table" ).hide();
            // add class sel to this button and remove it from table button
            $(this).addClass("sel");
            $(this).siblings( ".show-table" ).removeClass("sel");
        }

    });

    // click event on Visualizza tabella
    $('#main-vis-windows').on( 'click', '.show-table', function () {
        // check if it is already selected
        var isSelect = $(this).hasClass("sel");
        if(isSelect == false){
            // show div with table
            $(this).parent().siblings( ".html-table" ).show();
            // hide div with table
            $(this).parent().siblings( ".chart" ).hide();
            // add class sel to this button and remove it from chart button
            $(this).addClass("sel");
            $(this).siblings( ".show-chart" ).removeClass("sel");
        }
    });

    // click event on Tutti i dati
    $('#main-vis-windows').on( 'click', '.show-all', function () {
        // add/remove class sel
        $(this).toggleClass("sel");
        // check if it has been selected
        var isSelect = $(this).hasClass("sel");
        // get box index
        var macroIdx = parseInt($(this).parent().data('idx'));

        // check if "periodo temporale" is setted
        var numDays = $(this).siblings('.ctn-calendar').find('.select-days').val();
        if(numDays == '')
            numDays = null;

        // check if option has been selected
        // if true then set validity to null (= Tutti i dati)
        // else get validity from the validity menu
        var validity;
        if(isSelect){
            validity = null;
        }
        else{
            // get selected operator and code by class sel
            var operator =  $(".valcode-menu .validation-operators button.sel").text();
            var code =  $(".valcode-menu a.dropdown-item.sel").data("id");

            if(code == null)
                validity = null
            else
                validity = operator+' '+code;

            if(code == null)
                validity = null
            else
                validity = operator+' '+code;
        }
        // set validity for the current macro
        arrayMacros[macroIdx].macro.validity_code = validity;
        // refresh visible metadata
        putMacroToPanel(macroIdx, true);
        // refresh chart
        refreshChart(macroIdx, numDays);
    });

    // click event on Periodo temporale button
    $('#main-vis-windows').on( 'click', '.show-calendar', function () {

        // var isSelect = $(this).hasClass("sel");
        // if(isSelect == false){
        //     $(".show-calendar").removeClass("sel");
        //     $(".ctn-calendar").hide();
        // }

        // show/hide sub-menu with calendar options
        $(this).siblings( ".ctn-calendar" ).toggle();
        // add class sel to button
        $(this).addClass("sel");

        // get number of days to be showed
        var numDays = $(this).siblings( ".ctn-calendar" ).find('.select-days').val();
        // if number of days is empty and the sub-menu is hidden then remove class sel
        if(numDays == '' && $(this).siblings( ".ctn-calendar" ).is(':hidden'))
            $(this).removeClass("sel");
    });

    // click event on calendar options
    $('#main-vis-windows').on( 'click', '.change-days', function () {
        // get number of days to show
        var numDays = $(this).siblings('.select-days').val();
        // get box index
        var macroIdx = parseInt($(this).parent().parent().data('idx'));

        // if number of days is empty
        // then refresh chart taking dates from default menu fields
        // else refresh chart extracting data for the selected days
        if(numDays == ''){
            refreshChart(macroIdx);
            // remove class sel from main button
            $(this).parent().siblings(".show-calendar").removeClass("sel");
        }
        else{
            refreshChart(macroIdx, numDays);
            // add class sel to main button
            $(this).parent().siblings(".show-calendar").addClass("sel");
        }

        // hide sub-menu
        $(this).parent().hide();
    });

    // clieck event on Chiudi periodo temporale button (X)
    $('#main-vis-windows').on( 'click', '.ctn-calendar span.ctn-close-info', function () {
        // hide sub-menu
        $(this).parent().hide();
        // get selected number of days
        var numDays = $(this).siblings('.select-days').val();
        // if it is empty then remove sel class from main button
        if(numDays == '')
            $(this).parent().siblings('.show-calendar').removeClass("sel");
    });

    // click event on Opzioni grafico button
    $('#main-vis-windows').on( 'click', '.show-type', function () {

        // check if it is already selected
        var isSelect = $(this).hasClass("sel");
        if(isSelect == false){
            // remove class sel and hide sub-menu
            $(".show-type").removeClass("sel");
            $(".ctn-type").hide();
        }

        // show/hide sub-menu and toggle class sel on button
        $(this).siblings( ".ctn-type" ).toggle();
        $(this).toggleClass("sel");
    });

    // click event on VAI button in order to change chart type
    $('#main-vis-windows').on( 'click', '.change-chart', function () {
        // hide sub-menu
        $(this).parent().parent().hide();
        // remove class sel from Opzioni grafico button
        $(this).parent().parent().siblings(".show-type").removeClass("sel");

        // get box index
        var macroIdx = parseInt($(this).parent().parent().parent().data('idx'));

        // getsibling select element value
        var type = $(this).siblings(".select-chart").val();
        // if type not empty
        if(type != ''){
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // use setTimeout function in order to refresh panel asynchronously
            setTimeout(function(){
                // update panel chart type
                updateTypeChart(type, macroIdx)
            }, 10);
        }
    });

    // clieck event on Chiudi opzioni grafico button (X)
    $('#main-vis-windows').on( 'click', '.ctn-type span.ctn-close-info', function () {
        // hide sub-menu
        $(this).parent().hide();
        // remove sel class from main button
        $(this).parent().siblings(".show-type").removeClass("sel");
    });

    // Click event on 6th button of the window
    $('#main-vis-windows').on( 'click', '.toggle-series', function (e) {
        e.preventDefault();

        // get action stored in button element
        var action = $(this).data('action');
        // based on the type of the action, modify icon and action data attribute
        if(action == 'show'){
            $(this).data('action', 'hide');
            $(this).html('<i class="fa-light fa-eye-slash"></i>');
        }
        else{
            $(this).data('action', 'show');
            $(this).html('<i class="fa-light fa-eye"></i>');
        }

        // retrieve macro idx stored in the window element
        var macroIdx = parseInt($(this).parent().data('idx'));
        // loop through all chart series and hide/show them
        charts[macroIdx].series.forEach(function(item){

            if(action == 'show')
                item.show();
            else
                item.hide();
        });
    });

    // click event on Scarica grafico button
    $('#main-vis-windows').on( 'click', '.show-dwl-chart', function(e){
        e.preventDefault();

        // get box index
        var macroIdx = parseInt($(this).parent().data('idx'));
        // download the image
        charts[macroIdx].exportChartLocal({type: 'image/png'});
    });

    // click event on Scarica CSV button
    $('#main-vis-windows').on( 'click', '.show-dwl-csv', function(e){
        e.preventDefault();

        // get box index
        var macroIdx = parseInt($(this).parent().data('idx'));
        // download CSV file
        charts[macroIdx].downloadCSV();
    });

    // click event on Informazioni button
    $('#main-vis-windows').on( 'click', '.show-info', function () {

        // check if it is already selected
        var isSelect = $(this).hasClass("sel");
        if(isSelect == false){
            // remove class sel
            $(".show-info").removeClass("sel");
            // hide metadata container
            $(".ctn-info").hide();
        }

        // show/hide metadata container
        $(this).siblings( ".ctn-info" ).toggle();
        // toggle class sel
        $(this).toggleClass("sel");
    });

    // click event on Chiudi informazioni button (X)
    $('#main-vis-windows').on( 'click', '.ctn-info span.ctn-close-info', function () {
        // hide metadata container
        $(this).parent().parent().hide();
        // remove sel class from main button
        $(this).parent().parent().siblings(".show-info").removeClass("sel");
    });
} // !! END TAB BUTTONS

    // first initializtion
    initialiseElements();
    // load all options and fill form
    loadOptions();
    // load all panels
    getPagesByCategory(-1);


    // UTILITIES
    ////////////////////////////////////////////////////////////
    /**
     * Function that resizes the height of the main bars to adapt the parameters windows
     * No args needed
     */
    function resizeWindowsV(){
        var pu = ($( "#no-slide" ).height())+12;
        $( "#main-vis-windows" ).css( "padding-top", pu+"px" );
    }

    /**
     * Function that initializes all plugins and other elements of Visualizer
     * No args needed
     */
    function initialiseElements(){

        // initialize tooltips
        $('[data-toggle="tooltip"]').tooltip();
        $('[data-toggle-second="tooltip"]').tooltip();

        // range = $('#macro-param-charline').rangeslider({
        //     polyfill: false
        // });

        // var dateFrom = moment().add('-180','days').format('YYYY-MM-DD HH:00');
        // var dateTo = moment().format('YYYY-MM-DD HH:00');

        // initialize inputmask for start date
        $("#date-start").inputmask({
            alias: "datetime",
            mask: "99/99/9999 99:99",
            insertMode: false,
            "oncomplete": function(){
                dateFrom = $("#date-start").val();
                console.log(dateFrom);
            }
        }).on('keyup', function(){
            // on keyup check dates validity
            validDates($("#date-start").val(), $("#date-end").val(), 'date-start'); // global.js
        });

        // check if the variable arriving from server is defined
        // if true then set global variable with specific date
        // otherwise set the default one (7 days)
        if(fromVal && fromVal != '')
            dateFrom = moment(fromVal*1000).format('DD/MM/YYYY HH:00');
        else
            dateFrom = moment().utc().add('-7','days').format('DD/MM/YYYY HH:00');

        // set start date
        $("#date-start").inputmask("setvalue", dateFrom);

        // initialize inputmask for end date
        $("#date-end").inputmask( {
            alias: "datetime",
            mask: "99/99/9999 99:99",
            insertMode: false,
            oncomplete: function(){
                dateTo = $("#date-end").val();
                console.log(dateTo);
            }
        }).on('keyup', function(){
            // on keyup check dates validity
            validDates($("#date-start").val(), $("#date-end").val(), 'date-end'); // global.js
        });

        // check if the variable arriving from server is defined
        // if true then set global variable with specific date
        // otherwise set the default one (today)
        if(toVal && toVal != '')
            dateTo = moment(toVal*1000).format('DD/MM/YYYY HH:59');
        else
            dateTo = moment().utc().format('DD/MM/YYYY HH:59');

        // set end date
        $("#date-end").inputmask("setvalue", dateTo);

        // // multiple selection select
        // catGroups = $(".select2").select2();
    }

    /**
     * Function that loads all global and user options
     * No args needed
     */
    function loadOptions(){

        // get options via an ajax call
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/str_vis_get_visualizer_user_options',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // set global variable
            visualizerToolOptions = result.gen_opt;

            // get user options
            var options = result.user_opt;
            // if options are not defined
            // then take default options
            if( options == null){
                // IMPOSTAZIONI DI DEFAULT
                visualizerOptions = {
                    general: {
                        numberWindows : 4,
                        treatmentEnabled: false
                    },
                    tabulator: {
                        codesEnabled: true
                    },
                    highstocks: {
                        legendEnabled: true,
                        minorGridEnabled: false,
                        hoverEventEnabled: true,
                        tooltipType: 'standard',
                        labelXangle: 0,
                        titleFontSize: 16,
                        labelFontSize: 11,
                        legendFontSize: 10,
                        // layout immagine esportata
                        expWidth: 600,
                        expHeight: 400,
                        expTitleFontSize: 16,
                        expLabelFontSize: 11,
                        expLegendFontSize: 10
                    },
                    filter: {
                       altitude: 0
                    }
                };
            }
            else{
                // IMPOSTAZIONI DA DB CON CONTROLLO PRESENZA CAMPI ALTRIMENTI DEFAULT
                visualizerOptions = {
                    general: {
                        numberWindows: options.general.numberWindows == null ? 4 : options.general.numberWindows,
                        treatmentEnabled: options.general.treatmentEnabled == null ? false : options.general.treatmentEnabled
                    },
                    tabulator: {
                        codesEnabled: options.tabulator == null || options.tabulator.codesEnabled == null ? true : options.tabulator.codesEnabled
                    },
                    highstocks: {
                        legendEnabled: options.highstocks.legendEnabled == null ? true : options.highstocks.legendEnabled,
                        minorGridEnabled: options.highstocks.minorGridEnabled == null ? false : options.highstocks.minorGridEnabled,
                        hoverEventEnabled: options.highstocks.hoverEventEnabled == null ? true : options.highstocks.hoverEventEnabled,
                        tooltipType: options.highstocks.tooltipType == null ? 'standard' : options.highstocks.tooltipType,
                        labelXangle: options.highstocks.labelXangle == null ? 0 : options.highstocks.labelXangle,

                        titleFontSize: options.highstocks.titleFontSize == null ? 16 : options.highstocks.titleFontSize,
                        labelFontSize: options.highstocks.labelFontSize == null ? 11 : options.highstocks.labelFontSize,
                        legendFontSize: options.highstocks.legendFontSize == null ? 10 : options.highstocks.legendFontSize,
                        // layout immagine esportata
                        expWidth: options.highstocks.expWidth == null ? 600 : options.highstocks.expWidth,
                        expHeight: options.highstocks.expHeight == null ? 400 : options.highstocks.expHeight,
                        expTitleFontSize: options.highstocks.expTitleFontSize == null ? 10 : options.highstocks.expTitleFontSize,
                        expLabelFontSize: options.highstocks.expLabelFontSize == null ? 6 : options.highstocks.expLabelFontSize,
                        expLegendFontSize: options.highstocks.expLegendFontSize == null ? 5 : options.highstocks.expLegendFontSize
                    },
                    filter: {
                       altitude: options.filter.altitude == null ? 0 : options.filter.altitude
                    }
                };
            }

            // fill form with options
            setOptions();
            // build exporting options object (for highchart initialization)
            exportinChartOptions = {
                scale: 1,
                filename: 'Visualizer_'+ moment().format('YYYY-MM-DD_HH:mm'),
                useHtml: true,
                sourceWidth: visualizerOptions.highstocks.expWidth,
                sourceHeight: visualizerOptions.highstocks.expHeight,
                chartOptions: {
                    title: {
                        style: {
                            fontSize: visualizerOptions.highstocks.expTitleFontSize+'px'
                        }
                    },
                    xAxis:{
                        0: {
                            lineColor: '#000000',
                            lineWidth: 1,
                            minorTicks: true,
                            labels: {
                                rotation: - visualizerOptions.highstocks.labelXangle,
                                style: {
                                    color: '#000000',
                                    fontSize: visualizerOptions.highstocks.expLabelFontSize+'px'
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
                                    fontSize: visualizerOptions.highstocks.expLabelFontSize+'px'
                                }
                            }
                        }
                    },
                    legend:{
                        align: 'center',
                        width: '100%',
                        itemDistance: 50,
                        itemStyle: {
                            fontSize: visualizerOptions.highstocks.expLegendFontSize+'px',
                            fontWeight: 'normal'
                        },
                        margin: 2
                    }
                }
            };

            // check if variable from server is defined
            // if true then load selected panel
            // otherwise hide preloader at the of the process
            if(pgid != null && pgid != '')
                getMacrosByPage(pgid);
            else
                $('.preloader').hide();
        })
        .fail(function(xhr, err) {
            // take care of errors
            swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");
            // hide preloader at the of the process
            $('.preloader').hide();
        });
    }

    /**
     * Function that fills options form
     * No args needed
     */
    function setOptions(){
        // generali
        $("#visible-treatment").attr("checked", visualizerOptions.general.treatmentEnabled);
        $("#number-windows").val(visualizerOptions.general.numberWindows);

        // grafici
        $("#chart-legend").attr("checked", visualizerOptions.highstocks.legendEnabled);
        $("#chart-nav").attr("checked", visualizerOptions.highstocks.navigatorEnabled);
        $("#chart-label-x-angle").val(visualizerOptions.highstocks.labelXangle);
        $("#chart-minor-grid").attr("checked", visualizerOptions.highstocks.minorGridEnabled);
        $("#chart-hover-event").attr("checked", visualizerOptions.highstocks.hoverEventEnabled);
        $("#chart-tooltip-type").val(visualizerOptions.highstocks.tooltipType);
        $("#chart-title-font").val(visualizerOptions.highstocks.titleFontSize);
        $("#chart-label-font").val(visualizerOptions.highstocks.labelFontSize);
        $("#chart-legend-font").val(visualizerOptions.highstocks.legendFontSize);

        $("#exp-chart-width").val(visualizerOptions.highstocks.expWidth);
        $("#exp-chart-height").val(visualizerOptions.highstocks.expHeight);
        $("#exp-chart-title-font").val(visualizerOptions.highstocks.expTitleFontSize);
        $("#exp-chart-label-font").val(visualizerOptions.highstocks.expLabelFontSize);
        $("#exp-chart-legend-font").val(visualizerOptions.highstocks.expLegendFontSize);

        // tabelle
        $("#table-codes").attr("checked", visualizerOptions.tabulator.codesEnabled);
    }

    /**
     * Function that update global variable visualizerOptions and applies changes
     * No args needed
     */
    function applyOptions(){

        // get options from the form and build an object
        visualizerOptions = {
            general: {
                numberWindows: parseInt($("#number-windows").val()),
                treatmentEnabled: $("#visible-treatment").is(":checked")
            },
            tabulator: {
                codesEnabled: $("#table-codes").is(":checked")
            },
            highstocks: {
                legendEnabled: $("#chart-legend").is(":checked"),
                minorGridEnabled: $("#chart-minor-grid").is(":checked"),
                hoverEventEnabled: $("#chart-hover-event").is(":checked"),
                tooltipType: $("#chart-tooltip-type").val(),
                labelXangle: parseInt($("#chart-label-x-angle").val()),

                titleFontSize: parseInt($("#chart-title-font").val()),
                labelFontSize: parseInt($("#chart-label-font").val()),
                legendFontSize: parseInt($("#chart-legend-font").val()),
                // layout immagine esportata
                expWidth: parseInt($("#exp-chart-width").val()),
                expHeight: parseInt($("#exp-chart-height").val()),
                expTitleFontSize: parseInt($("#exp-chart-title-font").val()),
                expLabelFontSize: parseInt($("#exp-chart-label-font").val()),
                expLegendFontSize: parseInt($("#exp-chart-legend-font").val())
            },
            filter: {
                altitudeFilter: 0
            }
        };

        // if there is an active panel then refresh it with new options
        if(arrayMacros != null){
            // trigger click on Aggiorna button
            $("#update-data").trigger('click');
        }
    }

    /**
     * Function that save user otpions in the database and applies them
     * No args needed
     */
    function saveOptions(){

        // save options in the database via an ajax call
        var jqxhr = $.ajax({
            url: '/str_vis_put_visualizer_user_options',
            type: "post",
            dataType: "json",
            data: {
                options: JSON.stringify(visualizerOptions)
            }
        })
        .done(function(result) {

            // check the result
            // if true show success message otherwise take care of error
            if(result){
                swal("Successo!", "Le impostazioni sono state salvate con successo", "success");
            }
            else{
                swal("Errore!", "Errore durante il salvataggio delle impostazioni", "error");
            }
            // hide preloader at the end of the process
            $('.preloader').hide();

        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il recupero delle impostazioni dell'utente", "error");
            // hide preloader at the end of the process
            $('.preloader').hide();

        });
    }

    /**
     * Function that loads all panels linked to the selected category
     *
     * @param {integer} catid Category ID
     */
    function getPagesByCategory(catid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_vis_get_pages_by_cat',
            type: "post",
            dataType: "json",
            data: {
                id: catid
            },
        })
        .done(function(result) {
            // empty panel select and append the first default option
            $('#group-pages').empty();
            $('#group-pages').append('<option value="-1">Macro...</option>');

            // check ajax resul
            // if OK then fill panel select with all passible options
            if(result.res == 'OK'){
                var pages = result.pages;
                var group;
                // variable for dinamycally build options
                var html = '';

                // loop through all retrieved pages
                // for each element build an option, taking care of different categories
                pages.forEach(function(page){
                    if (group == null){
                        html += '<optgroup label="'+page.category_name+'">';
                        html += '<option value="'+page.page_id+'">'+page.page_name+'</option>';
                    }
                    else{
                        if (group == page.category_id){
                            html += '<option value="'+page.page_id+'">'+page.page_name+'</option>';
                        }
                        else {
                            html += '</optgroup>';
                            html += '<optgroup label="'+page.category_name+'">';
                            html += '<option value="'+page.page_id+'">'+page.page_name+'</option>';
                        }
                    }
                    group = page.category_id;
                });

                html += '</optgroup>';
                // append new html to select
                $('#group-pages').append(html);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei pannelli", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei pannelli", "error");
        });
    }

    /**
     * Function that loads all metadata of selected panel and initialize the central container
     *
     * @param {integer} pg_id Panel ID
     */
    function getMacrosByPage(pg_id){

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_vis_get_macros_by_page',
            type: "post",
            dataType: "json",
            data: {
                id: pg_id
            },
        })
        .done(function(result) {

            // console.log('return getMacrosByPage');
            // check result
            // if OK then update global variables and modify Visualizer's main container
            if(result.res == 'OK'){

                // udate global variables
                var activePageMacro = result.macros;
                arrayMacros = null;
                arrayMacros = JSON.parse(activePageMacro.macro_object);

                // check if at least one macro exists
                // if true then build all boxes
                // otherwise reset central container
                if( arrayMacros && arrayMacros.length > 0 ){
                    loadActivePage();
                }
                else{
                    resetPage(true);
                    // hide preloader at the end of the process
                    $('.preloader').hide();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del dettaglio della pagina", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della pagina", "error");
        });
    }

    /**
     * Function that builds a box for each macro of active panel
     * No args needed
     */
    function loadActivePage(){

        // reset central container
        resetPage(false);

        // variable for dynamically build html
        var html= '';
        // loop through all macros
        // for each element build a box with specific index and with all buttons
        arrayMacros.forEach(function(macro, macroIdx){

            // chec macro type
            var elType = 'chart';
            if(macro.macro.type == 'table')
                elType= 'table';

            html += '<div class="col-xl-4 col-lg-6 col-sm-12">';
            html += '    <div class="vis-windows" id="vis_window_'+macroIdx+'" data-type="'+elType+'">';
            html += '        <h4>'+macro.macro.name+' <a href="#" class="to-fullscreen" data-original-title="Apri fullscreen" data-placement="top" data-toggle="tooltip"><i class="icon-size-fullscreen"></i></a></h4>';
            html += '        <div class="chart data-content" id="chart_container_'+macroIdx+'">';
            html += '        </div>';
            html += '        <div class="html-table data-content">';
            html += '            <table class="table table-striped table-hover" id="html_table_container_'+macroIdx+'">';
            html += '            </table>';
            html += '        </div>';
            html += '        <div class="chart-bar data-bar" data-idx="'+macroIdx+'">';
            html += '            <span class="show-chart sel" data-original-title="Formato grafico" data-placement="top" data-toggle="tooltip"><i class="ti-stats-up"></i></span>';
            html += '            <span class="show-table" data-original-title="Formato tabella" data-placement="top" data-toggle="tooltip"><i class="ti-layout-grid3"></i></span>';
            // html += '            <span class="show-formule" data-original-title="Applica formula" data-placement="top" data-toggle="tooltip"><i class="ti-wand"></i></span>';
            html += '            <span class="show-all" data-original-title="Tutti i dati (anche NON validati)" data-placement="top" data-toggle="tooltip"><i class="ti-alert"></i></span>';
            html += '            <span class="show-calendar" data-original-title="Modifica periodo temporale" data-placement="top" data-toggle="tooltip"><i class="ti-calendar"></i></span>';
            html += '            <div class="ctn-calendar">';
            html += '                <span class="ctn-close-info"><i class="ti-close"></i></span>';
            html += '                <h5>Arco temporale:</h5>';
            html += '                <select class="select-days">';
            html += '                    <option value="">Seleziona...</option>';
            html += '                    <option value="1 d">1 giorno</option>';
            html += '                    <option value="2 d">2 giorni</option>';
            html += '                    <option value="4 d">4 giorni</option>';
            html += '                    <option value="8 d">8 giorni</option>';
            html += '                    <option value="16 d">16 giorni</option>';
            html += '                    <option value="1 M">1 mese</option>';
            html += '                    <option value="2 M">2 mesi</option>';
            html += '                    <option value="3 M">3 mesi</option>';
            html += '                </select>';
            html += '                <input class="btn btn-inverse btn-xs change-days" type="button" value="vai">';
            html += '            </div>';
            html += '            <span class="show-type" data-original-title="Opzioni grafico" data-placement="top" data-toggle="tooltip"><i class="ti-pie-chart"></i></span>';
            html += '            <div class="ctn-type">';
            html += '                <span class="ctn-close-info"><i class="ti-close"></i></span>';
            html += '                <h5>Opzioni grafico:</h5>';
            html += '                <div class="type-chart">';
            html += '                    <select class="select-chart">';
            html += '                        <option value="">Seleziona...</option>';
            html += '                        <option value="line">Linea</option>';
            html += '                        <option value="line_marker">Linea con punti</option>';
            html += '                        <option value="point">Punti</option>';
            html += '                        <option value="column">Barre</option>';
            html += '                        <option value="area">Area</option>';
            html += '                    </select>';
            html += '                    <input class="btn btn-inverse btn-xs change-chart" type="button" value="vai">';
            html += '                </div>';
            html += '            </div>';
            html += '            <span class="toggle-series" data-original-title="Abilita/disabilita tutte le serie" data-placement="top" data-toggle="tooltip" data-action="hide"><i class="fa-light fa-eye-slash"></i></span>';
            html += '            <span class="show-dwl-chart" data-original-title="Scarica grafico" data-placement="top" data-toggle="tooltip"><i class="ti-image"></i></span>';
            html += '            <span class="show-dwl-csv" data-original-title="Scarica CSV" data-placement="top" data-toggle="tooltip"><i class="icon-doc"></i></span>';
            html += '            <span class="show-info" data-original-title="Informazioni" data-placement="top" data-toggle="tooltip"><i class="ti-info"></i></span>';
            html += '            <div class="ctn-info">';
            // build html with macro's metadata
            html += putMacroToPanel(macroIdx, false);
            html += '            </div>';
            html += '        </div>';
            html += '    </div>';
            html += '</div>';

        });

        // append new html to central container
        $('#main-container').append(html);
        // reset all options of the boxes
        $('.vis-windows[data-type="chart"] .html-table').hide();
        $('.vis-windows[data-type="table"] .chart').hide();
        $('.ctn-calendar').hide();
        $('.ctn-type').hide();
        $('.ctn-info').hide();

        // initialize tooltip
        $('[data-toggle="tooltip"]').tooltip();
        // trigger click on "Visualizza grafico" button
        $('.vis-windows[data-type="table"] .show-table').trigger('click');

        // reset flag for the first load in order to take care of default days of visibility
        dirtyDates = false;
        // trigger click on Aggiorna button
        $('#update-data').trigger('click');
    }

    /**
     * Function that builds html with macro's metdata
     *
     * @param {integer} macroIdx Macro index
     * @param {boolean} reset Flag that defines if the Info container must be resetted
     *
     * @return if reset is false then returns HTML with macro metadata (in case of panel initialization)
     */
    function putMacroToPanel(macroIdx, reset){

        // get current macro
        var currMacro = arrayMacros[macroIdx];
        // get general option object
        var macro = currMacro.macro;
        // get array of parameters objects
        var params = currMacro.params;

        // get selected aggregation
        var aggregation = $('#time-period option[value="'+macro.aggregation+'"]').text();

        // retreive macro's options and initialize support variables
        var labelY = macro.label_yaxis;
        if(labelY == null)
            labelY = '';

        var validity = macro.validity_code;
        if( macro.validity_code == null){
            validity = 'tutti i dati';
        }

        var type = 'Grafico';
        if(macro.type == 'table')
            type = 'Tabella';

        // variable for dynamically build html
        var html = '';
        html += '<h5>';
        html += '    <i class="icon-info"></i> Informazioni';
        html += '    <span class="ctn-close-info"><i class="ti-close"></i></span>';
        html += '</h5>';
        html += '<table class="table table-striped table-hover tbl-general-data">';
        html += '   <tbody>';
        html += '       <tr>';
        html += '           <th>Nome:</th>';
        html += '           <td>'+macro.name+'</td>';
        html += '       </tr>';
        html += '       <tr>';
        html += '           <th>Tipo visualizzazione:</th>';
        html += '           <td>'+type+'</td>';
        html += '       </tr>';
        html += '       <tr>';
        html += '           <th>Aggregazione:</th>';
        html += '           <td>'+aggregation+'</td>';
        html += '       </tr>';
        html += '       <tr>';
        html += '           <th>Percentuale dati:</th>';
        html += '           <td>'+macro.percent_data+'%</td>';
        html += '       </tr>';
        html += '       <tr>';
        html += '           <th>Codice validità:</th>';
        html += '           <td>'+validity+'</td>';
        html += '       </tr>';
        html += '       <tr>';
        html += '           <th>Etichetta asseY:</th>';
        html += '           <td>'+labelY+'</td>';
        html += '       </tr>';
        html += '   </tbody>';
        html += '</table>';

        // check if at least one parameter exists and build accordions
        if(params != null){

            html +='<div class="all-params">';
            html +='<h5 class="title-params"><i class="ti-exchange-vertical"></i> Parametri ['+params.length+']</h5>';
            html +='<div id="inner-accordion-panel-'+macroIdx+'" class="inner-accordion-panel-'+macroIdx+' inner-accordion-panel">';
            html +='<div class="card mb-0">';

            $.each(params, function(key, param){
                // console.dir(params);
                html +='<div class="param-buttons">';
                html +='    <div class="card-header collapsed" data-toggle="collapse" href="#collapse-panel-'+macroIdx+'-'+key+'">';
                html +='        <a class="card-title">'+param.legend+'</a>';
                html +='    </div>';
                html +='</div>';

                html +='<div id="collapse-panel-'+macroIdx+'-'+key+'" class="card-body collapse" data-parent="#inner-accordion-panel-'+macroIdx+'">';
                html +='<table class="table table-striped table-hover tbl-specific-data">';
                html +='   <tbody>';
                html +='    <tr><th>Nome:</th><td>'+param.name+'</td></tr>';
                html +='    <tr><th>Formula:</th><td>'+param.formule+'</td></tr>';
                if(param.decimals){
                    html +='    <tr><th>Decimali:</th><td>'+param.decimals+'</td></tr>';
                }
                html +='   </tbody>';
                html +='</table>';
                html +='</div>';

            });

            html +='</div>';
            html +='</div>';
            html +='</div>';
            html +='</div>';
        }

        // if reset flag is true
        // then empty box Informazioni container and append new html
        // else return html (panel initialization)
        if(reset == true){
            $('#vis_window_'+macroIdx+' .ctn-info').empty();
            $('#vis_window_'+macroIdx+' .ctn-info').append(html);
        }
        else
            return html;
    }

    /**
     * Function that reset Visualizer main container and global variables
     *
     * @param {boolean} resetParam if true then resets global variables
     */
    function resetPage(resetParam){

        $('#main-container').empty();
        // check reset flag
        if(resetParam){
            arrayMacros = null;
            // reset titles
            $('#main-vis-title span').text('nessuna selezionata');
            $('#main-vis-footer span').text('nessuna selezionata');
        }
        // empty charts array
        charts = [];
        // empty tables
        $('.html-table table').empty();
    }

    /**
     * Function that updates the type of the chart for all linked series
     *
     * @param {text} seriesType the new chart type
     * @param {integer nullable} macroIdx Macro index, if null update all macros
     */
    function updateTypeChart(seriesType, macroIdx){

        var options;
        // build different options object based on selected type
        if(seriesType == 'point' || seriesType == 'line_marker'){
            options = {
                type: 'line',
                lineWidth: (seriesType == 'line_marker') ? 2 : 0,
                marker: {
                    enabled: true,
                    radius: 2.5
                }
            };
        }
        else{
            options = {
                type: seriesType,
                lineWidth: 2,
                marker: {
                    enabled: false,
                }
            };

        }

        // check if macro index is defined
        // if true then update only the selected one
        // else update all panel's macros
        if(macroIdx != null){
            var macro = arrayMacros[macroIdx];
            var series = charts[macroIdx].series;

            // loop through all macro's parameters
            // for each param object set the new type
            $.each(macro.params, function (key, param) {
                param.chartstyle = seriesType;
                // if linked series has data then update the type option without redrawing it
                if( series[key].xData && series[key].xData.length > 0){
                    series[key].update(options, false);
                }
            });

            // redraw chart all at once
            charts[macroIdx].redraw();
            // hide preloader at the end of the process
            $('.preloader').hide();

        }
        else{
            // loop through all charts
            // for each element loop through all parameters and update them without redrawing the chart
            $.each(charts, function (key, chart) {

                var series = chart.series;
                var macro = arrayMacros[key];

                // loop through all macro's parameters
                // for each param object set the new type
                $.each(macro.params, function (innerKey, param) {
                    param.chartstyle = seriesType;
                    // if linked series has data then update the type option without redrawing it
                    if( series[innerKey] && series[innerKey].xData && series[innerKey].xData.length > 0){
                        series[innerKey].update(options, false);
                    }
                });

                // redraw chart all at once
                chart.redraw();

                // check if it is the last loop
                if(key == charts.length -1)
                    // hide preloader at the end of the process
                    $('.preloader').hide();
            });
        }
    }
});



