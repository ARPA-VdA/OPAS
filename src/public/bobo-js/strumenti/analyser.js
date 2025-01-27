// ANALYZER VARIABLES
// array of charts or tables, one for each open tab
var chart = [];
var table = [];
var multipleCharts = [];
// filtered nodes in right tree
var filtered_obj = [];
// main active macro
// there can be only one active macro
var activeMacro;
// query returned by the server after a data extraction
var query;

/**
 * Document ready
 */
$(document).ready(function() {

    // extend tabulator calculations functions
    // add avg, min and max functions
    Tabulator.extendModule("columnCalcs", "calculations", {
        "avg":function(values, data, calcParams){
            var output = 0,
            count = 0,
            // number of decimals
            precision = typeof calcParams.precision !== "undefined" ? calcParams.precision : 2;

            // if the array of values is not empty
            if (values.length) {
                // calculate the sum of all values taking care of undefined cells
                output = values.reduce(function (sum, value) {
                    var value = Number(value);

                    // if it is not a number, then discard it
                    if( isNaN(value) ){
                        value = 0;
                        count ++;
                    }

                    // if sum is undefined then initialized it with 0
                    var mySum = Number(sum);
                    if( isNaN(mySum) ){
                        mySum = 0;
                        count++;
                    }
                    // return sum
                    return mySum + value;
                });
                // calculate the average by dividing by the number of non-null values
                output = output / ( values.length - count);
                // round result
                output = precision !== false ? output.toFixed(precision) : output;
            }

            // if the result is not a number then return '--'
            // otherwise convert it to string
            if(isNaN(parseFloat(output)))
                return '--'
            else
                return parseFloat(output).toString();
        },
        "max": function(values, data, calcParams) {
            var output = null,
            // number of decimals
            precision = typeof calcParams.precision !== "undefined" ? calcParams.precision : false;
            // loop through all values
            // compare each value with the temporary maximum
            values.forEach(function (value) {
                value = Number(value);
                // take care of null values
                if (! isNaN(value) && (value > output || output === null)) {
                    output = value;
                }
            });
            // return result rounded by the number of decimals
            return output !== null ? precision !== false ? output.toFixed(precision) : output : "";
        },
        "min": function min(values, data, calcParams) {
            var output = null,
            // number of decimals
            precision = typeof calcParams.precision !== "undefined" ? calcParams.precision : false;
            // loop through all values
            // compare each value with the temporary maximum
            values.forEach(function (value) {
                value = Number(value);
                // take care of null values
                if (! isNaN(value) && (value < output || output === null)) {
                    output = value;
                }
            });
            // return result rounded by the number of decimals
            return output !== null ? precision !== false ? output.toFixed(precision) : output : "";
        }
    });

    // DRAG'N'DROP EVENTS for right tree
    $(document)
        // move by holding a tree item
        .on('dnd_move.vakata', function (e, data) {
            // get target of the event
            var t = $(data.event.target);
            // if movement doesn't start from jstree then do nothing
            if(!t.closest('.jstree').length) {

                // RECOVER NODE OBJECT
                if(data.data.jstree && data.data.origin) {
                    var node = data.data.origin.get_node(data.element);
                    // if selected node isn't a statior, a parameter nor a limit then return and do nothing
                    if (node.li_attr.type != 'station' && node.li_attr.type != 'param' && node.li_attr.type != 'limit')
                        return;
                }

                // if the movement is over an available drop area then show a "success" cursor (green tick)
                // otherwise show a "error" cursor (red X)
                if(t.closest('.drop').length || t.closest('.central-drop').length || t.closest('.header-drop').length) {
                    data.helper.find('.jstree-icon').removeClass('jstree-er').addClass('jstree-ok');
                }
                else {
                    data.helper.find('.jstree-icon').removeClass('jstree-ok').addClass('jstree-er');
                }
            }
        })
        // stop movement and drop tree element in permitted areas
        .on('dnd_stop.vakata', function (e, data) {
            // get target of the event
            var t = $(data.event.target);
            // if movement doesn't start from jstree then do nothing
            if(!t.closest('.jstree').length) {
                // if node has been dropped in active macro container
                if(t.closest('.drop').length){

                    // RECOVER NODE OBJECT
                    if(data.data.jstree && data.data.origin) {
                        var node = data.data.origin.get_node(data.element);
                        // console.dir(node);

                        // different action based on the type of dropped element
                        if (node.li_attr.type == 'param'){
                            // write a info message in the log container
                            log('ADD PARAM', 'station_param_id: '+ node.li_attr.stprid +' - Parametro: '+ node.text);
                            // get stpr_id from dragged node
                            var stprid = node.li_attr.stprid;
                            // add parameter and refresh active macro without retrieving new data
                            updateActiveMacro(stprid, false);
                        }
                        else if( node.li_attr.type == 'station' ){
                            // write a info message in the log container
                            log('ADD STATION', 'station_id: '+ node.li_attr.id +' - Stazione: '+ node.text);

                            // load the entire node and loop through each child node
                            $('#ext-json').jstree(true).load_node(node, function(node){
                                // get all children of the node
                                var children = node.children;
                                // loop through all children
                                for(var idx = 0; idx < children.length; idx++){
                                    // get metadata from current looped node
                                    var childId = children[idx];
                                    var childNode = $('#ext-json').jstree(true).get_node(childId);
                                    // check if the node is a normal parameter (not a diagnostic or limit)
                                    if( childNode.li_attr.param_type == null ){
                                        // get stpr_id and add it to active macro
                                        var stprid = childNode.li_attr.stprid;
                                        // refresh active macro without retrieving new data
                                        updateActiveMacro(stprid, false);
                                    }
                                };

                            });
                        }
                        else{
                            return;
                        }

                    }
                }
                // if node has been dropped in central container
                else if (t.closest('.central-drop').length) {

                    // RECOVER NODE OBJECT
                    if(data.data.jstree && data.data.origin) {
                        var node = data.data.origin.get_node(data.element);
                        // console.dir(node);

                        // different action based on the type of dropped element
                        if (node.li_attr.type == 'param'){
                            // write a info message in the log container
                            log('ADD PARAM', 'station_param_id: '+ node.li_attr.stprid +' - Parametro: '+ node.text+'');
                            // get stpr_id from dragged node
                            var stprid = node.li_attr.stprid;
                            // add parameter and refresh active macro retrieving new data
                            updateActiveMacro(stprid, true);
                        }
                        else if( node.li_attr.type == 'station' ){
                            // write a info message in the log container
                            log('ADD STATION', 'station_id: '+ node.li_attr.id +' - Stazione: '+ node.text);

                            // load the entire node and loop through each child node
                            $('#ext-json').jstree(true).load_node(node, function(node){
                                // get all children of the node
                                var children = node.children;
                                // loop through all children
                                for(var idx = 0; idx < children.length; idx++){
                                    // get metadata from current looped node
                                    var childId = children[idx];
                                    var childNode = $('#ext-json').jstree(true).get_node(childId);
                                    // check if the node is a normal parameter (not a diagnostic or limit)
                                    if( childNode.li_attr.param_type == null ){
                                        var stprid = childNode.li_attr.stprid;
                                        // refresh active macro without retrieving new data
                                        updateActiveMacro(stprid, false);
                                    }
                                };


                            });
                        }
                        else{
                            return;
                        }
                    }
                }
                // if node has been dropped in central container's header
                else if (t.closest('.header-drop').length) {
                    // RECOVER NODE OBJECT
                    if(data.data.jstree && data.data.origin) {
                        var node = data.data.origin.get_node(data.element);

                        // allow the operation only if the moved node is a single parameter
                        if (node.li_attr.type != 'param')
                            return;

                        // write a info message in the log container
                        log('NEW TAB', 'station_param_id: '+ node.li_attr.stprid +' - Parametro: '+ node.text+'');
                        // get parameter's stpr_id
                        var stprid = node.li_attr.stprid;
                        // get metadata in order to fill options of the new tab
                        var operator =  $(".valcode-menu .validation-operators .default-val").text();
                        var code = $(".valcode-menu .dropdown-item.default-val").data('id');

                        // global variable: increase tab counter
                        counter++;
                        // goldenlayout tab options
                        var newItemConfig = {
                            type: 'component',
                            componentName: 'chartComponent',
                            componentState: {
                                id: counter,
                                type: 'chart',
                                multiple: false,
                                perYear: false,
                                windrose: false,
                                windroseId: null,
                                macroId: null,
                                elementMacro: {
                                    macro : {
                                        name: 'Nuova macro',
                                        description: 'Macro di partenza',
                                        int_time: 0,
                                        legendx_angle: 0,
                                        label_yaxis: null,
                                        step_yaxis : null,
                                        aggregation: $("#time-period option.def").val(),
                                        percent_data: $("#percent-data").val(),
                                        validity_code: operator+' '+code
                                    },
                                    params: []
                                }
                            },
                            title:'Grafico',
                            isClosable: true
                        };

                        // create the new tab and set it as the active one
                        centralContainer.addChild(newItemConfig);
                        $(".lm_content").css("background-color", "white");
                        var len = centralContainer.contentItems.length;
                        centralContainer.setActiveContentItem(centralContainer.contentItems[len-1]);
                        // refresh active macro retrieving new data
                        updateActiveMacro(stprid, true);
                    }
                }
            }
        });


    // RIGHT TREE
    /**
     * Click event on + Tutti button
     */
    $("#add-searched").on('click', function(e){
        e.preventDefault();
        // loop through all filtered nodes
        $.each(filtered_obj, function(key, node){
            // add parameters to active macro
            if(node.type == 'param'){
                var stprid = node.getAttribute('stprid');
                // refresh active macro without retrieving new data
                updateActiveMacro(stprid, false);
            }

        });
    });

    // MACRO DETAILS BOTTOM RIGHT PANEL
    /**
     * Click event on edit parameter button
     */
    $("#macro-detail" ).on( "click", ".edit-param", function(e) {
        e.preventDefault();

        // get parameter position
        var position = parseInt($(this).data('pos'));

        // open modal "Modifica macro"
        $('#settings-macro').modal('show');
        // show "Parametri" tab
        $('#macro-tab a[href="#macro-parametri"]').tab('show');

        // programatically select clicked parameter based on the position
        $('#macro-param-main option[data-idx="'+position+'"]').prop('selected', true);
        $('#macro-param-main').trigger('change');
    });

    /**
     * Click event on delete parameter button
     */
    $("#macro-detail" ).on( "click", ".del-param", function(e) {
        e.preventDefault();

        // get parameter position
        var position = parseInt($(this).data('pos'));

        // remove parameter from array stored inside the active macro
        activeMacro.params.splice(position, 1);
        // refresh active macro metadata within the interface
        loadActiveMacro();
    });

    // at the end of the process hide preloader
    $('.preloader').hide();
});


///////////////////////////////////////////////////////////////////////////////////
// FUNCTIONS
///////////////////////////////////////////////////////////////////////////////////

// UTILITIES
/**
 * Function for output to the bottom central window
 *
 * @param {string} operation: description of operation
 * @param {string} text: message to be logged
 */
function log(operation, text){

    // get current fulldate
    var date = moment().format('DD-MM-YYYY HH:mm:ss');
    // build html for the message
    var html = '['+date+'] <strong>'+operation+'</strong> '+text+'<br>';
    // append it at the top of container
    $('#log').prepend(html);
}

/**
 * Function that merge two arrays
 *
 * @param {array} array1: First array
 * @param {array} array2: Second array
 *
 * @return merged array
 */
function union(array1, array2) {

    console.log('union');
    // console.dir(array1);
    // console.dir(array2);

    // if one of the two arrays is null then return void
    if ((array1 == null) || (array2==null))
        return void 0;

    // temp variable
    var obj = {};
    // loop through all items of the first array starting from the bottom
    // create a relation key-value where key is a fulldate expressed in seconds
    for (var i = array1.length-1; i >= 0; -- i)
        obj[parseInt(array1[i])/1000] = parseInt(array1[i]);

    // loop through all items of the second array starting from the bottom
    // create a relation key-value where key is a fulldate expressed in seconds
    for (var i = array2.length-1; i >= 0; -- i)
        obj[parseInt(array2[i])/1000] = parseInt(array2[i]);

    // result array
    var res = [];
    // loop through all keys in obj variable
    for (var n in obj)
    {
        // push value inside result array
        if (obj.hasOwnProperty(n))
            res.push(obj[n].toString());
    }
    // the resulting array is composed of an ordered set of microseconds indicating specific dates
    return res;
}

/**
 * Function used to copy a graphic's svg to the clipboard
 *
 * @param {integer} idx: index of the chart
 */
async function copySvgToClipboard(idx){

    //create a canvas for the SVG render
    var canvas = document.createElement('canvas');
    // canvas.width = 600; //set canvas sizes
    // canvas.height = 400;

    //set canvas sizes
    canvas.width = analyserOptions.highstocks.expWidth;
    canvas.height = analyserOptions.highstocks.expHeight;
    //convert SVG to string
    const svg = chart[idx].getSVG().match(/<svg.*<\/svg>/)[0];

    // take care of errors
    try {
        //render SVG inside canvas using the string result retrieved from highcharts method
        const ctx = canvas.getContext('2d');
        const v = await canvg.Canvg.fromString(ctx, svg);
        await v.render();

        // convert the svg into a blob object
        let canvasBlob = await new Promise(resolve => canvas.toBlob(resolve));
        // write it to clipboard
        navigator.clipboard.write([
            new ClipboardItem({
                'image/png': canvasBlob
            })
        ]);

        // show success message
        $.toast({
            heading: 'Successo',
            text: 'Immagine copiata',
            position: 'top-right',
            loaderBg:'#028ea5',
            icon: 'success',
            hideAfter: 3000,
            stack: 6
        });
        // clear canvas object
        canvas.remove();
    }
    catch (error) {
        // error message
        swal('Copia non effettuata!', 'E\' possible che il tuo browser non supporti questa funzionalità', 'warning');
        // clear canvas object
        canvas.remove();
    }
}
// END UTILITIES

/**
 * Function that updates metadata of active macro
 *
 * @param {integer} stprid: new station's parameter to be added to active macro
 * @param {boolean} refresh: flag true if it is necessary to update the graph/table immediately
 */
function updateActiveMacro(stprid, refresh){

    console.log('updateActiveMacro');

    // retrieve parameter metadata from server via an ajax call
    var jqxhr = $.ajax({
        url: '/str_ana_get_param_info',
        type: "post",
        dataType: "json",
        data: {
            stprid: stprid,
            conv: analyserOptions.general.convEnabled
        }
    })
    .done(function(result) {

        // check result
        // if OK then update active macro and retrieve new data if refresh flas is true
        // else show error message
        if(result.res == 'OK'){

            // update active macro by pushing new parameter inside the array
            activeMacro.params.push(result.param);

            // update macro stored inside goldenlayout component
            var activeTabElement = centralContainer.header.activeContentItem;
            activeTabElement.config.componentState.elementMacro = activeMacro;

            // get component metadata
            var componentState = activeTabElement.config.componentState;

            // check if "Chart per year" option is active
            // if true and activeMacro has more than 1 parameter then disable it and force chart refresh
            if(componentState.perYear == true && activeMacro.params.length > 1){
                componentState.perYear = false;
                $('#chart-per-year').prop('checked', false);
                $('.disabled-peryear').prop('disabled', false);

                activeMacro.macro.reload = true;
            }

            // refresh html with new options of active macro
            loadActiveMacro();
            // check refresh flag
            if(refresh){
                // get selected dates
                dateFrom = $("#date-start").val();
                dateTo = $("#date-end").val();

                // check if user selected a valid range
                if( ! validDates(dateFrom, dateTo, 'date-start') ){
                    console.log('Non valido');
                    // show warning message
                    swal('Attenzione!', 'Date inserite non valide', 'warning');
                    return;
                }

                // show preloader, waiting for the end of the process
                $('.preloader').show();

                // check tab type: chart or table
                if(componentState.type == 'chart'){
                    // check if it is a "multiple charts" tab
                    if(componentState.multiple == true){
                        // check if at least one char exists
                        if(multipleCharts[componentState.id] && multipleCharts[componentState.id].length > 0){
                            // loop through all charts contained in the tab and destroy them
                            console.log('Destroy all sync charts');
                            $.each(multipleCharts[componentState.id], function(index, el){
                                el.destroy();
                            });
                            // empty html containers and variables
                            $('#chart_container_'+componentState.id).empty();
                            multipleCharts[componentState.id] = null;
                        }

                        // empty the variable containing the array of charts
                        multipleCharts[componentState.id] = [];
                        // refresh view
                        addMultipleCharts();

                    }
                    // case of chart with timeseries as x axis
                    else if( $('#hide-undefined').data("hidenull") == false && categorizedAggrs.every(function(v) { return activeMacro.macro.aggregation.indexOf(v) == -1; }) ){

                        // if reload field is true
                        // setted true at time-period change
                        if( chart[componentState.id] && activeMacro.macro.reload == true ){
                            // destroy component and reset variable
                            chart[componentState.id].destroy();
                            chart[componentState.id] = null;
                        }

                        // if chart is not initialized then initialize it
                        if( !chart[componentState.id]){
                            console.log("Create chart");
                            createChart();
                        }
                        else{
                            // reset zoom and title
                            chart[componentState.id].zoomOut();
                            chart[componentState.id].setTitle(
                                { text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>' },
                                { text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ) }
                            );
                            // update chart options
                            var options = {
                                yAxis: {
                                    title: {
                                        text: activeMacro.macro.label_yaxis
                                    },
                                    tickInterval: activeMacro.macro.step_yaxis
                                }
                            };
                            chart[componentState.id].update(options);
                            // check if the number of axes set is different from that actually present on the graph
                            if( chart[componentState.id] && chart[componentState.id].yAxis.length != activeMacro.macro.num_yaxis){
                                var plotLinesAndBands = chart[componentState.id].yAxis[0].plotLinesAndBands;
                                // remove plot lines and bands
                                $.each(plotLinesAndBands, function(key, line){
                                    chart[componentState.id].yAxis[0].removePlotLine('band'+key);
                                });

                                // calculate the difference between the number of axes set in the settings and those actually present
                                var diff = activeMacro.macro.num_yaxis - chart[componentState.id].yAxis.length;
                                // if difference is greater than 0, add "diff" axes
                                // othewise remove "diff" axes
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
                                    // remove axes
                                    for(var key = 1; key <= diff; key++){
                                        chart[componentState.id].yAxis[len-key].remove(true);
                                    }

                                    // enable gridline if the number of axes is equal to 1
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
                        // refresh chart
                        addSeriesToChart();
                    }
                    //chart with categorized x axis
                    else{

                        /**
                         * Check type of aggregation: in the following cases "rep_day, rep_week and rep_year" use x labes formatted by server
                         * Otherwise timeseries data -> to be formatted with moment from utc
                         */
                        var labelsFlag = ( categorizedAggrs.every(function(v) { return activeMacro.macro.aggregation.indexOf(v) == -1; }) );

                        // Check if reload field is true
                        // setted true at time-period change
                        if( chart[componentState.id] && activeMacro.macro.reload == true ){
                            // destroy chart and clear variable
                            chart[componentState.id].destroy();
                            chart[componentState.id] = null;
                        }

                        // if chart is null then initialize it
                        if( !chart[componentState.id] ){
                            console.log("Create chart");
                            createChartCategories( labelsFlag );
                        }

                        // categorized labels to be formatted
                        // otherwise labels from server
                        if( labelsFlag ){
                            addSeriesToChartCategories();
                        }
                        else{
                            addSeriesToChartCategoriesFormattedXLabels();
                        }
                    }
                }
                else{
                    // refresh table
                    addSeriesToTable();
                }
            }
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati del nuovo paramentro", "error");
        }

    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati del nuovo paramentro", "error");
    });
}

/**
 * Function that creates a highstock per window, saving object to array
 * No args needed
 */
function createChart(){

    console.log('createChart');
    // write a info message in the log container
    log('NEW', 'Creazione grafico');

    // get options of the active tab
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    /**
     * Initialize chart and store object in the global variable
     * Options take care of settings selected by the user
     */
    chart[componentState.id] = Highcharts.stockChart('chart_container_'+componentState.id, {
        chart: {
            panning: true,
            panKey: 'shift',
            zooming: {
                mouseWheel: false,
                type: $("#change-zoom .sel").data('type')
            },
            spacingLeft: 30,
            spacingRight: 15
        },
        title: {
            text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>',
            useHTML: true,
            style: {
                fontSize: analyserOptions.highstocks.titleFontSize+'px'
            }
        },
        subtitle: {
            text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ),
            style: {
                fontSize: parseInt( analyserOptions.highstocks.titleFontSize * 0.8) +'px'
            }
        },
        exporting: exportinChartOptions, //analyser_setting.js riga 1187
        navigator: {
            enabled: analyserOptions.highstocks.navigatorEnabled,
            xAxis: {
                isInternal: true
            },
            yAxis: {
                isInternal: true
            }
        },
        scrollbar: {
            enabled: false
        },
        rangeSelector: {
            enabled: false
        },
        boost: {
            allowForce: true,
            seriesThreshold: analyserToolOptions.boost_series
        },
        xAxis: {
            lineWidth: 1.5,
            gridLineWidth: 1,
            type:'datetime',
            // minPadding: 0.01,
            // maxPadding: 0.01,
            minPadding: 0,
            maxPadding: 0,
            showFirstLabel: true,
            minorTicks: analyserOptions.highstocks.minorGridEnabled,
            labels: {
                useHtml: true,
                rotation: - analyserOptions.highstocks.labelXangle,
                formatter: function() {
                    // check if user has selected an specific format otherwise use defualt one
                    if( ! analyserOptions.general.dateFormat || analyserOptions.general.dateFormat == 'standard' ){

                        // calculate the difference between min and max dates
                        var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                        // different format based on number of days
                        if (diff > (15*24*3600*1000)){ // 15 days
                            return getFormattedDateHC(this.value, 'basic'); //global.js
                        }
                        else{
                            // this.chart.xAxis[0].labels.rotation = 0;
                            return getFormattedDateHC(this.value, 'basic_timeStartMin');
                        }
                    }
                    else{
                        return getFormattedDateHC(this.value, analyserOptions.general.dateFormat );
                    }
                },
                style: {
                    fontSize: analyserOptions.highstocks.labelFontSize+'px'
                }
            },
            // custom tick positioner function
            tickPositioner: function () {

                if( activeMacro.macro.aggregation == 'mm' || activeMacro.macro.aggregation == 'yy')
                    return undefined;

                var positions = [];
                var tick;
                var increment;
                var nTick = analyserOptions.highstocks.numLabel - 1;
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
        },
        yAxis: {
            // startOnTick: false,
            // endOnTick: false,
            isInternal: false,
            lineWidth: 1.5,
            gridLineWidth: activeMacro.macro.num_yaxis > 1 ? 0 : 1,
            minorTicks: activeMacro.macro.num_yaxis > 1 ? false : analyserOptions.highstocks.minorGridEnabled,
            opposite: false,
            title: {
                text: activeMacro.macro.label_yaxis
            },
            showLastLabel: true,
            labels: {
                formatter: function() {
                    return this.value;
                },
                style: {
                    fontSize: analyserOptions.highstocks.labelFontSize+'px'
                }
            },
            tickInterval: activeMacro.macro.step_yaxis
        },
        credits: {
            text: '© '+footer, //Arriving from DB "portal_css_footer_text"
            href: company_web
        },
        plotOptions: {
            series: {
                boostThreshold: analyserToolOptions.boost_data,
                states: {
                    inactive: {
                        opacity: analyserOptions.highstocks.hoverEventEnabled ? 0.2 : 1,
                    }
                },
                pointPlacement: 'on',
                label: {
                    connectorAllowed: false
                },
                //!!ATTENTION data grouping to speed up rendering
                // https://api.highcharts.com/highstock/plotOptions.series.dataGrouping
                dataGrouping: {
                    enabled: false
                },
                // create specific events that are accessed via certain key combinations
                events: {
                    click: function (e) {
                        if(e.ctrlKey){
                            console.log('X: '+e.point.x);
                            console.log('Y: '+e.point.y);
                            console.log('ID:'+this.options.id);

                            var stprid = parseInt(this.options.id.replace('field_', ''));

                            console.dir(e);
                            var url = '/dat_validazione/'+stprid+'/'+e.point.x;
                            window.open(url, '_blank');
                        }
                    },
                    show: function (e) {
                        activeMacro.params[e.target.index].visible = true;
                    },
                    hide: function (e) {
                        activeMacro.params[e.target.index].visible = false;
                    }
                }
            },
            line: {
                marker: {
                    enabled: false
                }
            },
            areaspline: {
                boostThreshold: 1
            },
            column: {
                grouping: true,
                stacking: null
            }
        },
        legend: {
            enabled: true,
            maxHeight: 75,
            itemStyle: {
                fontSize: analyserOptions.highstocks.legendFontSize+'px'
            }
        },
        tooltip: {
            enabled: analyserOptions.highstocks.tooltipType != 'disabled' ? true : false,
            shared: analyserOptions.highstocks.tooltipType == 'shared' ? true : false,
            // valueDecimals: 2,
            split: false,
            dateTimeLabelFormats: {
                day: '%A %e %b %Y',
                hour: '%A %e %b, %H:%M',
                minute: '%A %e %b, %H:%M',
                second: '%A %e %b, %H:%M:%S',
                week: '%A %e %b %Y',
                year: '%Y'
            }
        },
        annotationsOptions: {
            enabledButtons: false
        },
        navigation: {
            buttonOptions: {
                y: -10
            }
        }
    });

    // initialize tooltip
    $('#chart_container_'+componentState.id+' [data-toggle-second="tooltip"]').tooltip();
    // if number of axes is greater than 1 then add them to chart
    if(activeMacro.macro.num_yaxis > 1){

        var num = activeMacro.macro.num_yaxis - 1;

        for(; num > 0; num --){
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
}

/**
 * Function used to add series for st_pr_id to the chart with options from the macro
 * No args needed
 */
function addSeriesToChart(){

    console.log('addSeriesToChart');

    var dateFromFormatted;
    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var aggregation = activeMacro.macro.aggregation;
    // hide boost info button
    $("#boost-info").hide();

    // different type of format based on time aggregation
    switch(aggregation){

        case 'dd':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');
            break;
        case 'mm':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-01 00:00');
            break;
        case 'yy':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-01-01 00:00');
            break;
        default:
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:00'); //30 min 1h
            break;
    }

    // write a info message in the log container
    log('START', 'Inizio recupero dati...');
    // Get data from db
    var jqxhr = $.ajax({
        url: '/str_ana_get_highcharts_data_bydate',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            hideNulls: $('#hide-undefined').data("hidenull"),
            from: dateFromFormatted,
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'),
            notes: analyserOptions.highstocks.notesEnabled
        }
    })
    .done(function(result) {

        // check result
        if(result.res == 'OK'){
            // write a info message in the log container
            log('SUCCESS!', 'Dati recuperati con successo');
            var data = result.data;
            query = result.query;

            // console.log('RECUPERO DATI');
            // console.dir(data);

            // retrieve general options of the tool and apply them
            if(analyserOptions.highstocks.subtitleEnabled){

                chart[componentState.id].setSubtitle( dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+aggregation+'"]').text()+']');
            }


            // TO BE ACTIVATED
            // if(analyserOptions.highstocks.notesEnabled){
            //     var notes = result.notes;
            //     componentState.notes = notes;

            //     $('#notes').empty();

            //     fillNotes(notes);
            // }

            // get starting point of the series expressed in seconds
            var pointStart = moment(dateFromFormatted).valueOf();

            // remove series from chart
            while( chart[componentState.id].series.length > 0 ) {
                chart[componentState.id].series[0].remove( false );
            }
            // remove all annotations
            var annotations = chart[componentState.id].annotations;
            // console.dir(annotations);
            for (let i = annotations.length - 1; i > -1; --i) {
                chart[componentState.id].removeAnnotation(annotations[i]);
            }
            // refresh chart
            chart[componentState.id].redraw();

            // copies only the values and not the reference
            var params = activeMacro.params.slice();

            // Loop through all series retrieved from server and add them to chart
            $.each(data, function (key, value) {

                // get parameter information for the current looped series
                var param = params[key];

                var legend = param.legend;
                if(analyserOptions.general.treatmentEnabled){

                    var treatmentTxt = $("#treatment a[data-type='"+param.treatment+"']").text();
                    legend += ' - '+treatmentTxt;
                }

                // based on the different type of chart build an object with plot options
                if(param.chartstyle == 'point' || param.chartstyle == 'line_marker'){
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: legend, //value.series_name,
                        type: 'line',
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: (param.chartstyle == 'line_marker') ? param.line_width : 0,
                        marker: {
                            enabled: true,
                            radius: param.line_width * 1.5
                        },
                        data: value.station_param_values,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }
                else{
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: legend, //value.series_name,
                        type: param.chartstyle,
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: param.line_width,
                        data: value.station_param_values,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        marker: {
                            enabled: false,
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }

                // set the title of the Y axis that the series is linked to
                if(param.axis && param.axis != 1){
                    chart[componentState.id].yAxis[param.axis-1].setTitle({
                        text: param.name
                    });
                }

                // add series to chart without redrawing it in order to prevent exponential slowdowns in rendering
                chart[componentState.id].addSeries(options, false);

                // check if it is the last loop
                // if true then redraw chart and if it is boosted then show button for opening boost info
                if(key == params.length-1){
                    chart[componentState.id].redraw();

                    if(chart[componentState.id].boosted){
                        $("#boost-info").show();
                    }
                }
            });

            // write a info message in the log container
            log('END', 'Grafico aggiornato');
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
    });
}

/**
 * Function that creates a chart for each parameter linked to active macro
 * No args needed
 */
function addMultipleCharts(){
    var dateFromFormatted;

    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var aggregation = activeMacro.macro.aggregation;

    // different type of format based on time aggregation
    switch(aggregation){

        case 'dd':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00');
            break;
        case 'mm':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-01 00:00');
            break;
        case 'yy':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-01-01 00:00');
            break;
        default:
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:00'); //30 min 1h
            break;
    }

    /**
     * In order to synchronize tooltips and crosshairs, override the
     * built-in events with handlers defined on the parent element.
     */
    ['mousemove', 'touchmove', 'touchstart'].forEach(function (eventType) {
        document.getElementById('chart_container_'+componentState.id).addEventListener(
            eventType,
            function (e) {
                var myChart,
                    point,
                    i,
                    event;

                for (i = 0; i < multipleCharts[componentState.id].length; i = i + 1) {
                    myChart = multipleCharts[componentState.id][i];
                    // Find coordinates within the chart
                    event = myChart.pointer.normalize(e);
                    // Get the hovered point
                    point = myChart.series[0].searchPoint(event, true);

                    if (point) {
                        point.highlight(e);
                    }
                }
            }
        );
    });

    /**
     * Highlight a point by showing tooltip, setting hover state and draw crosshair
     */
    Highcharts.Point.prototype.highlight = function (event) {
        event = this.series.chart.pointer.normalize(event);
        // Show the hover marker
        this.onMouseOver();
        // Show the tooltip
        this.series.chart.tooltip.refresh(this);
        // Show the crosshair
        this.series.chart.xAxis[0].drawCrosshair(event, this);
    };

    /**
     * Synchronize zooming through the setExtremes event handler.
     */
    function syncExtremes(e) {
        var thisChart = this.chart;

        // Prevent feedback loop
        if (e.trigger !== 'syncExtremes') {

            for (i = 0; i < multipleCharts[componentState.id].length; i = i + 1) {
                var tmpChart = multipleCharts[componentState.id][i];
                // Find coordinates within the chart
                if (tmpChart !== thisChart) {
                    // It is null while updating
                    if (tmpChart.xAxis[0].setExtremes) {
                        tmpChart.xAxis[0].setExtremes(
                            e.min,
                            e.max,
                            undefined,
                            false,
                            { trigger: 'syncExtremes' }
                        );
                    }
                }
            }
        }
    };

    // write a info message in the log container
    log('START', 'Inizio recupero dati...');
    // Get data from db
    var jqxhr = $.ajax({
        url: '/str_ana_get_highcharts_data_bydate',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            hideNulls: $('#hide-undefined').data("hidenull"),
            from: dateFromFormatted,
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
        }
    })
    .done(function(result) {

        if(result.res == 'OK'){
            // write a info message in the log container
            log('SUCCESS!', 'Dati recuperati con successo');
            var data = result.data;
            query = result.query;

            // get start point of the series expressed in seconds
            var pointStart = moment(dateFromFormatted).valueOf();

            // copy only the values and not the variable reference
            var params = activeMacro.params.slice();

            // loop through all retrieved series and create a synchronized chart
            $.each(data, function (key, value) {

                // create a container for the new highcharts
                $('#chart_container_'+componentState.id).addClass('nav-content');
                var chartDiv = document.createElement('div');
                chartDiv.className = 'multiple-chart';
                document.getElementById('chart_container_'+componentState.id).appendChild(chartDiv);

                // get information about linked parameter
                var param = params[key];
                // create the chart taking care of general tool's options
                multipleCharts[componentState.id][key] = Highcharts.chart(chartDiv, {
                    chart:{
                        zooming: {
                            type: 'x'
                        },
                        panning: true,
                        panKey: 'shift'
                    },
                    exporting:{
                        enabled: false
                    },
                    title: {
                        text: param.legend,
                        style: {
                            fontSize: analyserOptions.highstocks.titleFontSize+'px'
                        }
                    },
                    legend: {
                        enabled: false
                    },
                    xAxis: {
                        crosshair: true,
                        lineWidth: 1.5,
                        gridLineWidth: 1,
                        type:'datetime',
                        minPadding: 0.01,
                        maxPadding: 0.01,
                        showFirstLabel: true,
                        minorTicks: analyserOptions.highstocks.minorGridEnabled,
                        labels: {
                            useHtml: true,
                            rotation: - analyserOptions.highstocks.labelXangle,
                            formatter: function() {
                                // check if user has selected an specific format otherwise use defualt one
                                if( ! analyserOptions.general.dateFormat || analyserOptions.general.dateFormat == 'standard' ){

                                    // calculate the difference between min and max dates
                                    var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                                    // different format based on number of days
                                    if (diff > (15*24*3600*1000)){ // 15 giorni
                                        return getFormattedDateHC(this.value, 'basic'); //global.js
                                    }
                                    else{
                                        return getFormattedDateHC(this.value, 'basic_timeStartMin');
                                    }
                                }
                                else{
                                    return getFormattedDateHC(this.value, analyserOptions.general.dateFormat );
                                }
                            },
                            style: {
                                fontSize: analyserOptions.highstocks.labelFontSize+'px'
                            }
                        },
                        events: {
                            setExtremes: syncExtremes
                        },
                        // custom tick positioner function
                        tickPositioner: function () {

                            if( activeMacro.macro.aggregation == 'mm' || activeMacro.macro.aggregation == 'yy')
                                return undefined;

                            var positions = [];
                            var tick;
                            var increment;
                            var nTick = analyserOptions.highstocks.numLabel - 1;
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
                    },
                    yAxis: {
                        // startOnTick: false,
                        // endOnTick: false,
                        isInternal: false,
                        lineWidth: 1.5,
                        opposite: false,
                        title: {
                            text: activeMacro.macro.label_yaxis
                        },
                        showLastLabel: true,
                        labels: {
                            formatter: function() {
                                return this.value;
                            },
                            style: {
                                fontSize: analyserOptions.highstocks.labelFontSize+'px'
                            }
                        },
                        tickInterval: activeMacro.macro.step_yaxis
                    },
                    credits: {
                        text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "OPAS"
                        href: company_web
                    },
                    series: [{
                        data: value.station_param_values,
                        name: param.legend,
                        type: param.chartstyle,
                        color: param.color == 'FFFFFF'? Highcharts.getOptions().colors[key] : '#'+param.color,
                        lineWidth: param.line_width,
                        fillOpacity: 0.3,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        marker: {
                            enabled: false,
                        }
                    }]
                });

                /**
                * Override the reset function, we don't need to hide the tooltips and crosshairs.
                */
                multipleCharts[componentState.id][key].pointer.reset = function () {
                    return undefined;
                };
            });

            // write a info message in the log container
            log('END', 'Grafico aggiornato');
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
    });
}

/**
 * Function that creates a windrose chart
 *
 * @param {integer} stid: Station ID
 */
function createChartWR( stid ) {
    // write a info message in the log container
    log('NEW', 'Creazione grafico');

    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // check if component's type is windrose  otherwise do nothing
    if(componentState.windrose == false)
        return;
    // get station name
    var stationName = $('#ext-json [data-stid="'+stid+'"]').parent().text().trim();
    // get validity metadata
    var operator =  $(".valcode-menu .validation-operators button.sel").text();
    var code =  $(".valcode-menu a.dropdown-item.sel").data("id");
    var validity;

    // build validity check expression
    if(code == null)
        validity = null
    else
        validity = operator+' '+code;

    // retrieve data from db via an ajax call
    $.ajax({
        type : 'POST',
        url  : '/str_ana_get_windrose_data',
        dataType : 'json',
        data: {
            stid: stid,
            from: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:00'),
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'),
            valcode: validity,
            scale: analyserOptions.general.windScale
        },
        // callback handler that will be called on success
        success: function(result, textStatus, jqXHR){
            console.dir(result);
            query = result.query;
            var scale = result.scale;
            var classes = result.classes;
            // console.log('RETURN AJAX wr '+ moment().format('HH:mm:ss'));
            // drawing
            var seriesOptions = [];

            // seriesOptions[0] = {
            //     name: "&lt;= 0.5 m/s",
            //     data: result.json_calma,
            // };


            // build a json with labels and linked ranges of the wind scale selected by the user
            scale.forEach(function (el, idx) {
                if(idx != 0){

                    if(idx != scale.length -1){
                        seriesOptions[idx-1] = {
                            name: el.from+" - "+el.to+" m/s",
                            data: classes[idx],
                        }
                    }
                    else{
                        seriesOptions[idx-1] = {
                            name: "&gt; "+el.from+" m/s",
                            data: classes[idx],
                        }
                    }
                }
            });

            // seriesOptions[0] = {
            //     name: "0.5 - 3 m/s",
            //     data: result.json_debole,
            // };
            // seriesOptions[1] = {
            //     name: "3 - 5 m/s",
            //     data: result.json_moderata,
            // };
            // seriesOptions[2] = {
            //     name: "5 - 10 m/s",
            //     data: result.json_forte,
            // };
            // seriesOptions[3] = {
            //     name: "&gt; 10 m/s",
            //     data: result.json_molto_forte,
            // };
            // seriesOptions[5] = {
            //     name: "Totali",
            //     data: result.json_totale,
            // };

            // Create the chart taking care of tool's settings
            chart[componentState.id] = new Highcharts.Chart('chart_container_'+componentState.id, {
                chart: {
                    polar: true,
                    type: 'column',
                },
                title: {
                    text: stationName+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>',
                    useHTML: true,
                    style: {
                        fontSize: analyserOptions.highstocks.titleFontSize+'px'
                    }
                },
                subtitle: {
                    text:( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' [orario]' : null ),
                    style: {
                        fontSize: parseInt( analyserOptions.highstocks.titleFontSize * 0.8) +'px'
                    }
                },
                exporting: {
                    scale: 1,
                    filename: 'Analyser_'+ moment().format('YYYY-MM-DD_HH:mm'),
                    useHtml: true,
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
                                labels: {
                                    rotation: - analyserOptions.highstocks.labelXangle,
                                    style: {
                                        color: '#000000',
                                        fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                                    }
                                },

                            }
                        },
                        yAxis: {
                            0: {
                                labels: {
                                    style: {
                                        color: '#000000',
                                        fontSize: analyserOptions.highstocks.expLabelFontSize+'px'
                                    }
                                }
                            }
                        },
                        legend:{
                            align: 'right',
                            verticalAlign: 'top',
                            y: 100,
                            layout: 'vertical',
                            itemStyle: {
                                fontSize: analyserOptions.highstocks.expLegendFontSize+'px',
                                fontWeight: 'normal'
                            }
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
                }, //analyser_setting.js riga 1187
                pane: {
                    size: '85%'
                },
                legend: {
                    // reversed: true,
                    title: {
                        text: 'CALMA: '+result.perc_calma+'%'
                    },
                    align: 'right',
                    verticalAlign: 'top',
                    y: 100,
                    layout: 'vertical'
                },
                xAxis: {
                    tickmarkPlacement: 'on',
                    categories: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
                },
                yAxis: {
                    min: 0,
                    endOnTick: false,
                    showLastLabel: true,
                    title: {
                        text: 'Frequenza (%)'
                    },
                    labels: {
                        formatter: function () {
                            return this.value + '%';
                        }
                    },
                    reversedStacks: false
                },
                tooltip: {
                    valueSuffix: '%'
                },
                plotOptions: {
                    series: {
                        /*reversed: true,*/
                        stacking: 'normal',
                        shadow: false,
                        groupPadding: 0,
                        pointPlacement: 'on'
                    }
                },
                credits: {
                    text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "OPAS"
                    href: company_web
                },
                // colors: ['#e98131', '#3e78b2', '#939ba3', '#4c4f53', '#2ce9e7', '#f5ca00', '#f28f43', '#77a1e5', '#c42525', '#a6c96a'],
                series: seriesOptions
            });

            // at the end of the process hide preloader
            $('.preloader').hide();
            // write a info message in the log container
            log('END', 'Grafico creato con successo');
        },
        error: function(jqXHR, textStatus, errorThrown){
            // console.log(
            //     "The following error occured: " + textStatus, errorThrown
            // );
        }
    });
}

/**
 * Function that creates a specific chart with different series per year for the same pollutant
 * No args needed
 */
function createChartPerYear(){
    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var aggregation = activeMacro.macro.aggregation;
    // write a info message in the log container
    log('START', 'Inizio recupero dati...');

    // Get data from db
    var jqxhr = $.ajax({
        url: '/str_ana_get_highcharts_data_per_year',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            from: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'),
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
        }
    })
    .done(function(result) {

        console.dir(result);
        // check result
        // if OK then create a chart for each year included in the data extraction period selected by the user
        if(result.res == 'OK'){
            // write a info message in the log container
            log('SUCCESS!', 'Dati recuperati con successo');
            var data = result.data;
            query = result.query;

            // create chart
            chart[componentState.id] = Highcharts.stockChart('chart_container_'+componentState.id, {
                chart: {
                    panning: true,
                    panKey: 'shift',
                    zooming: {
                        mouseWheel: false,
                        type: $("#change-zoom .sel").data('type')
                    },
                    spacingLeft: 30,
                    spacingRight: 15
                },
                title: {
                    text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>',
                    useHTML: true,
                    style: {
                        fontSize: analyserOptions.highstocks.titleFontSize+'px'
                    }
                },
                subtitle: {
                    text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ),
                    style: {
                        fontSize: parseInt( analyserOptions.highstocks.titleFontSize * 0.8) +'px'
                    }
                },
                exporting: exportinChartOptions, //analyser_setting.js riga 1187
                navigator: {
                    enabled: analyserOptions.highstocks.navigatorEnabled,
                    xAxis: {
                        isInternal: true
                    },
                    yAxis: {
                        isInternal: true
                    }
                },
                scrollbar: {
                    enabled: false
                },
                rangeSelector: {
                    enabled: false
                },
                boost: {
                    allowForce: true,
                    seriesThreshold: analyserToolOptions.boost_series
                },
                xAxis: {
                    lineWidth: 1.5,
                    gridLineWidth: 1,
                    type:'datetime',
                    // minPadding: 0.01,
                    // maxPadding: 0.01,
                    minPadding: 0,
                    maxPadding: 0,
                    showFirstLabel: true,
                    minorTicks: analyserOptions.highstocks.minorGridEnabled,
                    labels: {
                        useHtml: true,
                        rotation: - analyserOptions.highstocks.labelXangle,
                        formatter: function() {
                            // calculate the difference between min and max dates
                            var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                            // different format based on number of days
                            // remove year from label
                            if (diff > (15*24*3600*1000)){ // 15 days
                                return moment.utc(this.value).format('DD/MM'); //global.js
                            }
                            else{
                                // this.chart.xAxis[0].labels.rotation = 0;
                                return moment.utc(this.value).format('DD/MM<br>HH:mm');
                            }
                        },
                        style: {
                            fontSize: analyserOptions.highstocks.labelFontSize+'px'
                        }
                    },
                    // cusom tick positioner function
                    tickPositioner: function () {

                        if( activeMacro.macro.aggregation == 'mm' || activeMacro.macro.aggregation == 'yy')
                            return undefined;

                        var positions = [];
                        var tick;
                        var increment;
                        var nTick = analyserOptions.highstocks.numLabel - 1;
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
                },
                yAxis: {
                    // startOnTick: false,
                    // endOnTick: false,
                    isInternal: false,
                    lineWidth: 1.5,
                    gridLineWidth: activeMacro.macro.num_yaxis > 1 ? 0 : 1,
                    minorTicks: activeMacro.macro.num_yaxis > 1 ? false : analyserOptions.highstocks.minorGridEnabled,
                    opposite: false,
                    title: {
                        text: activeMacro.macro.label_yaxis
                    },
                    showLastLabel: true,
                    labels: {
                        formatter: function() {
                            return this.value;
                        },
                        style: {
                            fontSize: analyserOptions.highstocks.labelFontSize+'px'
                        }
                    },
                    tickInterval: activeMacro.macro.step_yaxis
                },
                credits: {
                    text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                    href: company_web
                },
                plotOptions: {
                    series: {
                        boostThreshold: analyserToolOptions.boost_data,
                        states: {
                            inactive: {
                                opacity: analyserOptions.highstocks.hoverEventEnabled ? 0.2 : 1,
                            }
                        },
                        pointPlacement: 'on',
                        label: {
                            connectorAllowed: false
                        },
                        //!!ATTENZIONE raggruppamento dati per velocizzare rendering
                        // https://api.highcharts.com/highstock/plotOptions.series.dataGrouping
                        dataGrouping: {
                            enabled: false
                        }
                    },
                    line: {
                        marker: {
                            enabled: false
                        }
                    },
                    areaspline: {
                        boostThreshold: 1
                    },
                    column: {
                        grouping: true,
                        stacking: null
                    }
                },
                legend: {
                    enabled: true,
                    maxHeight: 75,
                    itemStyle: {
                        fontSize: analyserOptions.highstocks.legendFontSize+'px'
                    }
                },
                tooltip: {
                    enabled: analyserOptions.highstocks.tooltipType != 'disabled' ? true : false,
                    shared: analyserOptions.highstocks.tooltipType == 'shared' ? true : false,
                    // valueDecimals: 2,
                    split: false,
                    dateTimeLabelFormats: {
                        month: '%B',
                        day: '%A %e %b',
                        hour: '%A %e %b, %H:%M',
                        minute: '%A %e %b, %H:%M',
                        second: '%A %e %b, %H:%M:%S',
                        week: '%A %e %b'
                    }
                },
                annotationsOptions: {
                    enabledButtons: false
                },
                navigation: {
                    buttonOptions: {
                        y: -10
                    }
                }
            });

            // initialize tooltip
            $('#chart_container_'+componentState.id+' [data-toggle-second="tooltip"]').tooltip();

            // copies only the values and not the reference of variable
            var params = activeMacro.params.slice();
            var param = params[0];

            // get starting point of the series
            var pointStart = moment(dateFrom, 'DD/MM/YYYY HH:mm').valueOf();

            // Loop through alla parameters and for each element add series to chart
            $.each(data, function (key, value) {

                // take care of tool's settings
                var legend = param.name +' '+value.year;
                if(analyserOptions.general.treatmentEnabled){

                    var treatmentTxt = $("#treatment a[data-type='"+param.treatment+"']").text();
                    legend += ' - '+treatmentTxt;
                }

                // based on the different type of chart build an object with plot options
                if(param.chartstyle == 'point' || param.chartstyle == 'line_marker'){
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: legend, //value.series_name,
                        type: 'line',
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: (param.chartstyle == 'line_marker') ? param.line_width : 0,
                        marker: {
                            enabled: true,
                            radius: param.line_width * 1.5
                        },
                        data: value.station_param_values,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: true,
                        yAxis: 0
                    };
                }
                else{
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: legend, //value.series_name,
                        type: param.chartstyle,
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: param.line_width,
                        data: value.station_param_values,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        marker: {
                            enabled: false,
                        },
                        visible: true,
                        yAxis: 0
                    };
                }

                // add series to chart without drawing it in order to prevent exponential slowdowns in rendering
                chart[componentState.id].addSeries(options, false);
                // if the current loop is the last one then redraw chart
                if(key == data.length-1){
                    chart[componentState.id].redraw();
                    // if chart is boosted then show button for opening boost info
                    if(chart[componentState.id].boosted){
                        $("#boost-info").show();
                    }
                }
            });

            // write a info message in the log container
            log('END', 'Grafico aggiornato');
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
    });
}

/**
 * Function to create a categorized highchart per window, saving the object in the array
 *
 * @param {boolean} timeFlag indicates if categories are fulldate
 **/
function createChartCategories(timeFlag){

    console.log('createChart');
    // write a info message in the log container
    log('NEW', 'Creazione grafico');

    // get options of the active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // create chart taking care of tool's settings
    chart[componentState.id] = Highcharts.chart('chart_container_'+componentState.id, {
        chart:{
            // zoomType: $("#change-zoom .sel").data('type'),
            zooming: {
                type: $("#change-zoom .sel").data('type')
            },
            spacingLeft: 30,
            spacingRight: 15
        },
        title: {
            text: activeMacro.macro.name+' <a class="edit-titles" data-toggle="modal" data-target="#chart-titles" data-toggle-second="tooltip" data-original-title="Modifica titoli grafico"><i class="fa-solid fa-pencil text-info"></i></a>',
            useHTML: true,
            style: {
                fontSize: analyserOptions.highstocks.titleFontSize+'px'
            }
        },
        subtitle: {
            text: ( analyserOptions.highstocks.subtitleEnabled ? dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+activeMacro.macro.aggregation+'"]').text()+']' : null ),
            style: {
                fontSize: parseInt( analyserOptions.highstocks.titleFontSize * 0.8) +'px'
            }
        },
        exporting: exportinChartOptions, //analyser_setting.js riga 1187
        navigator: {
            enabled: analyserOptions.highstocks.navigatorEnabled,
            xAxis: {
                isInternal: true
            },
            yAxis: {
                isInternal: true
            }
        },
        boost: {
            allowForce: true,
            seriesThreshold: 30
        },
        xAxis: {
            lineWidth: 1.5,
            gridLineWidth: 1,
            type: 'category',
            startOnTick: false,
            endOnTick: false,
            // tickmarkPlacement: 'on',
            categories: [],
            labels: {
                useHtml: true,
                rotation: - analyserOptions.highstocks.labelXangle,
                formatter: function() {
                    // check if categories are fulldate
                    if(timeFlag == true){
                        var categories = this.chart.xAxis[0].categories;
                        // calculate the difference between min and max dates
                        var diff = moment(categories[categories.length-1], 'DD/MM/YYYY HH:mm').valueOf() - moment(categories[0], 'DD-MM-YYYY HH:mm').valueOf();

                        // different format based on number of days
                        if (diff > (5*24*3600*1000)){ // 5 days
                            return moment.utc(this.value, 'DD/MM/YYYY HH:mm').format('DD/MM<br>YYYY'); //global.js
                        }
                        else{
                            // this.chart.xAxis[0].labels.rotation = 0;
                            return moment.utc(this.value, 'DD/MM/YYYY HH:mm').format('DD/MM/YYYY<br>HH:mm');
                        }
                    }
                    else{
                        // else do nothing
                        // keep categories arriving from the server

                        return this.value;
                    }
                },
                style: {
                    fontSize: analyserOptions.highstocks.labelFontSize+'px'
                }
            }
        },
        yAxis: {
            startOnTick: false,
            endOnTick: false,
            isInternal: false,
            lineWidth: 1.5,
            opposite: false,
            title: {
                text: activeMacro.macro.label_yaxis
            },
            labels: {
                formatter: function() {
                    return this.value;
                },
                style: {
                    fontSize: analyserOptions.highstocks.labelFontSize+'px'
                }
            },
            tickInterval: activeMacro.macro.step_yaxis
        },
        credits: {
            text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "OPAS"
            href: company_web
        },
        plotOptions: {
            series: {
                label: {
                    connectorAllowed: false
                },
                states: {
                    inactive: {
                        opacity: analyserOptions.highstocks.hoverEventEnabled ? 0.2 : 1,
                    }
                },
                //!!ATTENTION data grouping to speed up rendering
                events: {
                    show: function (e) {
                        activeMacro.params[e.target.index].visible = true;
                    },
                    hide: function (e) {
                        activeMacro.params[e.target.index].visible = false;
                    }
                }
            },
            line: {
                marker: {
                    enabled: false
                }
            }
        },
        legend: {
            enabled: true,
            itemStyle: {
                fontSize: analyserOptions.highstocks.legendFontSize+'px'
            }
        },
        tooltip: {
            // enabled: false,
            // valueDecimals: 2,
            split: false,
            formatter: function () {
                 // console.dir(this.point);
                 return this.x+'<br/>'+
                 this.series.name +': <b>'+ this.y +'</b><br/>';
            }
        },
        annotationsOptions: {
            enabledButtons: false
        },
        navigation: {
            buttonOptions: {
                y: -10
            }
        }
    });

    // if number of axes is greater than 1 then add them to chart
    if(activeMacro.macro.num_yaxis > 1){

        var num = activeMacro.macro.num_yaxis - 1;

        for(; num > 0; num --){
            // Secondary yAxis
            chart[componentState.id].addAxis({
                startOnTick: false,
                endOnTick: false,
                isInternal: false,
                lineWidth: 1.5,
                opposite: true,
                gridLineWidth : 0
            });
        }
    }
}

/**
 * Function that adds series by st_pr_id to the chart with options derived from the macro
 * No args needed
 */
function addSeriesToChartCategories(){

    var dateFromFormatted;
    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var aggregation = activeMacro.macro.aggregation;

    // different type of format based on time aggregation
    switch(aggregation){

        case 'dd':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD');
            break;
        case 'mm':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-01');
            break;
        case 'yy':
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-01-01');
            break;
        default:
            dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:00'); //30 min
            break;
    }

    // write a info message in the log container
    log('START', 'Inizio recupero dati...');
    // Get data from db
    var jqxhr = $.ajax({
        url: '/str_ana_get_highcharts_data_bydate',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            hideNulls: $('#hide-undefined').data("hidenull"),
            from: dateFromFormatted,
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
        }
    })
    .done(function(result) {

        if(result.res == 'OK'){
            // write a info message in the log container
            log('SUCCESS!', 'Dati recuperati con successo');
            var data = result.data;
            query = result.query;

            // retrieve general options of the tool and apply them
            if(analyserOptions.highstocks.subtitleEnabled){

                chart[componentState.id].setSubtitle( dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+aggregation+'"]').text()+']');
            }

            console.dir(result.data);
            // clean the graph from the existing series
            while( chart[componentState.id].series.length > 0 ) {
                chart[componentState.id].series[0].remove( false );
            }

            chart[componentState.id].redraw();

            // copy only the values and not the reference
            var params = activeMacro.params.slice();
            var xCategories = [];

            // extract the categories, reorder them, eliminate duplicates and store them
            $.each(data, function (key, value) {
                if(params[key].is_limit == 0){
                    console.log('dentro category');
                    var xPoints = value.station_param_values.map(function(tuple) {
                        if(tuple[0] != null)
                            return tuple[0].toString();
                    });

                    if(xPoints.length == 1 && xPoints[0] == null){
                        // nothing to do
                    }
                    else {
                        xCategories = union(xCategories, xPoints);
                    }
                }
            });

            console.dir(xCategories);
            /*format the microseconds in date into the new xxCategories array*/
            var xCategoriesDates = [];
            $.each(xCategories, function( index, value ) {
                xCategoriesDates.push(moment.utc(parseInt(value)).format('DD/MM/YYYY HH:mm'));
            });

            chart[componentState.id].xAxis[0].setCategories(xCategoriesDates);

            // loop through all series data and build a different array
            // to be passed to the highchart
            $.each(data, function (key, value) {

                var param = params[key];
                var xyValues = [];
                var xyObj = {};

                // create an array with index = epoch time and value y
                $.each(value.station_param_values, function(key, point) {
                    if(point[0])
                        xyObj[point[0].toString()] = point[1];
                });

                // create data array to pass to highchart
                // for each category if the data exists push y otherwise push null
                $.each(xCategories, function(key,category){

                    if(xyObj[category]){
                        xyValues.push(xyObj[category]);
                    }
                    else{
                        xyValues.push(null);
                    }
                });

                // build a different options object based on chart style
                // also taking care of other macro settings
                if(param.chartstyle == 'point' || param.chartstyle == 'line_marker'){
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: param.legend, //value.series_name,
                        type: 'line',
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: (param.chartstyle == 'line_marker') ? param.line_width : 0,
                        marker: {
                            enabled: true,
                            radius: param.line_width * 1.5
                        },
                        data: xyValues,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }
                else{
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: param.legend, //value.series_name,
                        type: param.chartstyle,
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: param.line_width,
                        marker: {
                            enabled: false,
                        },
                        data: xyValues,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }

                if(param.axis && param.axis != 1){
                    chart[componentState.id].yAxis[param.axis-1].setTitle({
                        text: param.name
                    });
                }

                chart[componentState.id].addSeries(options, false);

                if(key == params.length-1){
                    chart[componentState.id].redraw();
                }
            });

            // write a info message in the log container
            log('END', 'Grafico aggiornato');
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
    });
}

/**
 * Function that adds series by st_pr_id to the chart with options derived from the macro
 * No args needed
 */
function addSeriesToChartCategoriesFormattedXLabels(){
    // write a info message in the log container
    log('START', 'Inizio recupero dati...');

    var dateFromFormatted;
    // get options of active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;
    var aggregation = activeMacro.macro.aggregation;

    dateFromFormatted = moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD');

    // Get data from db
    var jqxhr = $.ajax({
        url: '/str_ana_get_highcharts_data_bydate',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            from: dateFromFormatted,
            to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm')
        }
    })
    .done(function(result) {

        if(result.res == 'OK'){
            // write a info message in the log container
            log('SUCCESS!', 'Dati recuperati con successo');
            var data = result.data;
            query = result.query;

            // retrieve general options of the tool and apply them
            if(analyserOptions.highstocks.subtitleEnabled){

                chart[componentState.id].setSubtitle( dateFrom+' - '+dateTo+' ['+$('#time-period option[value="'+aggregation+'"]').text()+']');
            }

            // clean up the graph from existing series
            while( chart[componentState.id].series.length > 0 ) {
                chart[componentState.id].series[0].remove( false );
            }

            chart[componentState.id].redraw();

            // copy only the values and not the reference
            var params = activeMacro.params.slice();
            var xCategories = [];

            // extract the categories, reorder them, eliminate duplicates and store them
            $.each(data, function (key, value) {
                if(params[key].is_limit == 0){
                    console.log('dentro category');
                    var xPoints = value.station_param_values.map(function(tuple) {
                        if(tuple[0] != null)
                            return tuple[0].toString();
                    });

                    if(xPoints.length == 1 && xPoints[0] == null){
                        // nothing to do
                    }
                    else {
                        xCategories = xPoints;
                    }
                }
            });

            console.dir(xCategories);

            chart[componentState.id].xAxis[0].setCategories(xCategories);

            // loop through all series data and build a different array
            // to be passed to the highchart
            $.each(data, function (key, value) {

                var param = params[key];
                var xyValues = [];
                var xyObj = {};

                // create an array with index = epoch time and value y
                $.each(value.station_param_values, function(key, point) {
                    if(point[0])
                        xyObj[point[0].toString()] = parseFloat(point[1]);
                });

                // create data array to pass to highchart
                // for each category if the data exists push y otherwise push null
                $.each(xCategories, function(key,category){

                    if(xyObj[category]){
                        xyValues.push(xyObj[category]);
                    }
                    else{
                        xyValues.push(null);
                    }
                });

                // build a different options object based on chart style
                // also taking care of other macro settings
                if(param.chartstyle == 'point' || param.chartstyle == 'line_marker'){
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: param.legend, //value.series_name,
                        type: 'line',
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: (param.chartstyle == 'line_marker') ? param.line_width : 0,
                        marker: {
                            enabled: true,
                            radius: param.line_width * 1.5
                        },
                        data: xyValues,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }
                else{
                    options = {
                        id: 'field_'+value.station_param_id,
                        name: param.legend, //value.series_name,
                        type: param.chartstyle,
                        color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                        lineWidth: param.line_width,
                        marker: {
                            enabled: false,
                        },
                        data: xyValues,
                        tooltip: {
                            valueDecimals: param.decimals
                        },
                        visible: param.visible == null ? true : param.visible,
                        yAxis: param.axis ? (param.axis-1) : 0
                    };
                }

                if(param.axis && param.axis != 1){
                    chart[componentState.id].yAxis[param.axis-1].setTitle({
                        text: param.name
                    });
                }

                // add series to chart without redrawing it in order to prevent exponential slowdowns in rendering
                chart[componentState.id].addSeries(options, false);

                // if the current loop is the last one then redraw chart
                if(key == params.length-1){
                    chart[componentState.id].redraw();
                }
            });

            // write a info message in the log container
            log('END', 'Grafico aggiornato');
        }
        else{
            // error message
            swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();

    })
    .fail(function(xhr, err) {
        // at the end of the process hide preloader
        $('.preloader').hide();
        // error message
        swal("Errore!", "Si è verificato un errore durante il recupero dei dati!", "error");
    });
}

/**
 * Function that adds series by st_pr_id to the table with options derived from the macro
 * No args needed
 */
function addSeriesToTable(){
    // get option of the active component
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // remove filters
    $("#filters-"+componentState.id).parent().remove();

    // if filtersEnabled option is true then build the HTML element in order to add
    // a local form through which to filter the data
    if(analyserOptions.tabulator.filtersEnabled){
        var html = '<div class="container calc-filter">';
        html    += '    <div id="filters-'+componentState.id+'" class="row custom-gutter">';
        html    += '        <div class="col-sm-4">';
        html    += '        <select id="filter-field-'+componentState.id+'" class="form-control">';
        html    += '            <option value="">Seleziona colonna...</option>';
        html    += '        </select>';
        html    += '        </div>';
        html    += '        <div class="col-sm-2">';
        html    += '        <select id="filter-type-'+componentState.id+'" class="form-control">';
        html    += '            <option value="=">=</option>';
        html    += '            <option value="<"><</option>';
        html    += '            <option value="<="><=</option>';
        html    += '            <option value=">">></option>';
        html    += '            <option value=">=">>=</option>';
        html    += '            <option value="!=">!=</option>';
        html    += '        </select>';
        html    += '        </div>';
        html    += '        <div class="col-sm-4">';
        html    += '        <input id="filter-value-'+componentState.id+'" type="text" placeholder="valore per cui filtrare" class="form-control">';
        html    += '        </div>';
        html    += '        <div class="col-sm-2">';
        html    += '        <button id="filter-clear-'+componentState.id+'" class="form-control btn btn-success">Annulla</button>';
        html    += '        </div>';
        html    += '    </div>';
        html    += '</div>';

        // append form above the table
        $("#grid_container_"+componentState.id).parent().prepend(html);

        //Update filters on value change
        document.getElementById("filter-field-"+componentState.id).addEventListener("change", updateFilter.bind(this, componentState.id));
        document.getElementById("filter-type-"+componentState.id).addEventListener("change", updateFilter.bind(this, componentState.id));
        document.getElementById("filter-value-"+componentState.id).addEventListener("keyup", updateFilter.bind(this, componentState.id));

        //Clear filters on "Clear Filters" button click
        document.getElementById("filter-clear-"+componentState.id).addEventListener("click", function(){
            var fieldEl = document.getElementById("filter-field-"+componentState.id);
            var typeEl = document.getElementById("filter-type-"+componentState.id);
            var valueEl = document.getElementById("filter-value-"+componentState.id);

            fieldEl.value = "";
            typeEl.value = "=";
            valueEl.value = "";

            table[componentState.id].clearFilter();
        });
    }

    // console.dir(names);
    var aggregation = activeMacro.macro.aggregation;
    console.log(aggregation);
    var timeFlag = categorizedAggrs.every(function(v) { return aggregation.indexOf(v) == -1; });

    // create an array of objects, one for each column to add to the table
    var columns = [];
    // first column: fulldate
    column_fulldate = {
        title: (timeFlag == true ? "Data" : 'Periodo'),
        field: (timeFlag == true ? "fulldate" : "category"),
        frozen: true,
        formatter:function(cell, formatterParams, onRendered){
            //cell - the cell component
            //formatterParams - parameters set for the column
            //onRendered - function to call when the formatter has been rendered

            // check if it is a column of type datetime
            if( timeFlag == true ){
                // check if user has selected an specific format otherwise use default one
                if( ! analyserOptions.general.dateFormat || analyserOptions.general.dateFormat == 'standard' ){

                        // different format based on selected time aggregation
                    if (aggregation == 'dd' || aggregation == 'mm' || aggregation == 'yy'){ // 5 giorni
                        return getFormattedDateDT(cell.getValue(), 'basic');
                    }
                    else{
                        return getFormattedDateDT(cell.getValue(), 'basic_timeStartMin'); //global.js
                    }
                }
                else{
                    return getFormattedDateDT(cell.getValue(), analyserOptions.general.dateFormat );
                }
            }
            else{
                return cell.getValue();
            }
        },
    };


    columns.push(column_fulldate);

    // loop through all parameters linked to active macro
    // for each element build an option object that represents a column inside the table
    $.each(activeMacro.params, function (data_key, data_value) {

        // var column_name = names.find(x => x.st_pr_id === data_value).column_name;
        var column_name = data_value.column_name;
        // check whether the applied treatment must appear in the header
        if(analyserOptions.general.treatmentEnabled){

            var treatmentTxt = $("#treatment a[data-type='"+data_value.treatment+"']").text();
            column_name = column_name.replace(/<.*>/g, '- '+treatmentTxt+' <br>');
        }

        // console.log(column_name);
        column_obj = {
            title: column_name,
            titleDownload: column_name.replace(/<.*>/g, ""),
            // keyword to map the data arrived from the server with the correct column
            field: 'field_'+data_key,
            headerSort: false,
            accessorDownload: function(value){
                if( ! value || value == '--')
                    return '';
                else
                    return value.replace('.', ',');
            }
        };

        // Check if the "per-column calculations" option is enabled
        // if true format the label with the name of the applied calculation
        if(analyserOptions.tabulator.calcEnabled){
            column_obj.bottomCalc = data_value.treatment;
            column_obj.bottomCalcParams = {
                precision: data_value.decimals
            };
            // aggiungo informazione del trattamento vicino al risultato
            column_obj.bottomCalcFormatter = function(cell, bottomCalcFormatterParams, onRendered){
                var value = cell.getValue();
                if(cell.getValue() == null)
                    value = 'n.d.';

                return $("#treatment a[data-type='"+data_value.treatment+"']").text()+': '+value;
            };
        }

        columns.push(column_obj);

        var htmlOpt= '<option value="field_'+data_key+'">'+column_name.replace(/<.*>/g, "")+'</option>';
        $("#filter-field-"+componentState.id).append(htmlOpt);

        // if flag enabled show validity and data coverage codes
        // only if the number of parameters is lower than 16
        if(analyserOptions.tabulator.codesEnabled && activeMacro.params.length <= 15 && timeFlag == true){

             //if aggregation equal to the minimum aggregation then show validity code
            // else nothing to do
            if(aggregation == $("#time-period option:first").val()){
                column_obj = {
                    title: 'Val',
                    field: 'code_'+data_key,
                    headerSort: false,
                    accessorDownload: function(value){
                        if( ! value || value == '--')
                            return '';
                        else
                            return value.replace('.', ',');
                    }
                };

                columns.push(column_obj);
            }

            // column for to the coverage percentage
            column_obj = {
                title: 'Perc',
                field: 'perc_'+data_key,
                headerSort: false,
                accessorDownload: function(value){
                    if( ! value || value == '--')
                        return '';
                    else
                        return value.replace('.', ',');
                }
            };

            columns.push(column_obj);
        }

    });

    // write a info message in the log container
    log('END', 'Aggiornamento tabella, recupero dati progressivo...');

    // initialize tabulator plugin taking care of tool ooptions
    table[componentState.id] = new Tabulator("#grid_container_"+componentState.id, {
        locale: 'it',
        autoResize:false,

        height:'100%',
        layout:"fitData", //fitColumn
        columns: columns,
        index:"fulldate",
        ajaxURL:"/str_ana_get_tabulator_data",
        ajaxConfig: "post",
        ajaxParams: { from: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'), to: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm'), hideNulls: $('#hide-undefined').data("hidenull"), macro: JSON.stringify(activeMacro)},
        // ajaxProgressiveLoad:"load",
        // ajaxProgressiveLoadDelay: 200,
        ajaxResponse: function(url, params, response){
            //url - the URL of the request
            //params - the parameters passed with the request
            //response - the JSON object returned in the body of the response.
            if( analyserOptions.tabulator.codesEnabled && ( activeMacro.params.length > 15 || timeFlag == false ) )
                swal('Info', 'A causa del numero elevato diparametri o del tipo di aggregazione selezionata, le colonne dei codici sono state disattivate', 'info');

            // at the end of the process hide preloader
            $('.preloader').hide();

            query = response.query;

            console.dir(response.data);
            return response.data; //return the tableData property of a response json object
        },
        pagination: true,
        paginationMode: "local",
        paginationSize: 100,
        paginationSizeSelector:true,
        placeholder:"Nessun dato"
        // ajaxProgressiveLoadScrollMargin:300, //triger next ajax load when scroll bar is 300px or less from the bottom of the table.
    });
    // $('.preloader').hide();
}

/**
 * Function used to filter data according to a specific formula defined by the operator
 *
 * @param {integer} id: Component ID
 */
function updateFilter(id){

    // retrieve selected options from the html elements
    var fieldEl = document.getElementById("filter-field-"+id);
    var typeEl = document.getElementById("filter-type-"+id);
    var valueEl = document.getElementById("filter-value-"+id);

    var filterVal = fieldEl.options[fieldEl.selectedIndex].value;
    var typeVal = typeEl.options[typeEl.selectedIndex].value;

    // console.log(filterVal);
    // console.log(typeVal);
    // console.log(valueEl.value);

    // if selected options are not empty then apply the filter
    // else remove it and reset table visualization
    if(filterVal && valueEl.value != ''){
        table[id].setFilter(filterVal, typeVal, parseFloat(valueEl.value));
    }
    else
        table[id].clearFilter();
}
