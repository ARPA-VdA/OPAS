// VISUALIZER VARIABLES
var charts = [];

/**
 * Document ready
 */
$(document).ready(function() {
    // on Highcharts load
    (function(H) {
        // define new actions for scrool event
        H.wrap(H.Legend.prototype, 'scroll', function(proceed) {
            // call default function by passing incoming arguments
            proceed.apply(this, Array.prototype.slice.call(arguments, 1));

            // get chart object
            var chart = this.chart;
            // translate legend SVGelement
            if(chart.legend)
                chart.legend.contentGroup.attr({
                    translateY: 25
                });
            // move the navigation button to the right of the legend
            this.nav.attr({
                translateY: 35,
                translateX: chart.containerBox.width - 60
                // translateX: chart.containerWidth - 60
            });
        });
    }(Highcharts));
});

/**
 * Function that initialize Highcharts plugin for a specific macro
 *
 * @param {integer} macroIdx Macro index
 */
function createChart(macroIdx){

    // get macro object from active macros array
    var activeMacro = arrayMacros[macroIdx];
    // if chart already exists then destroy it and reset variable
    if(charts[macroIdx]){
        charts[macroIdx].destroy();
        charts[macroIdx] = null;
    }

    // initialize chart by setting user options
    charts[macroIdx] = Highcharts.chart('chart_container_'+macroIdx, {
        chart: {
            height: '350px',
            marginBottom: 95,
            zooming: {
                type: 'xy',
                mouseWheel:{
                    enabled:false
                }
            }
        },
        title:{
            text: null
        },
        subtitle: {
            text: activeMacro.macro.description == "" ? null : activeMacro.macro.description
        },
        exporting: exportinChartOptions,
        boost: {
            allowForce: true,
            seriesThreshold: visualizerToolOptions.boost_series
        },
        xAxis: {
            lineWidth: 1.5,
            gridLineWidth: 1,
            startOnTick: false,
            minPadding: 0,
            type:'datetime',
            labels: {
                useHtml: true,
                rotation: - visualizerOptions.highstocks.labelXangle,
                formatter: function() {
                    // return Highcharts.dateFormat('%d-%m-%Y', moment(this.value));
                    var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                    if (diff > (5*24*3600*1000)){ // 5 giorni
                        return getFormattedDateHC(this.value, 'basic'); //global.js
                    }
                    else{
                        // this.chart.xAxis[0].labels.rotation = 0;
                        return getFormattedDateHC(this.value, 'basic_timeStartMin');
                    }
                },
                style: {
                    fontSize: visualizerOptions.highstocks.labelFontSize+'px'
                }
            }
        },
        yAxis: {
            softMin: activeMacro.macro.Yaxys_min,
            softMax: activeMacro.macro.Yaxys_max,
            isInternal: false,
            lineWidth: 1.5,
            gridLineWidth: activeMacro.macro.num_yaxis > 1 ? 0 : 1,
            minorTicks: activeMacro.macro.num_yaxis > 1 ? false : visualizerOptions.highstocks.minorGridEnabled,
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
                    fontSize: visualizerOptions.highstocks.labelFontSize+'px'
                }
            }
        },
        credits: {
            enabled: false,
            // text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
            // href: company_web
        },
        plotOptions: {
            series: {
                boostThreshold: visualizerToolOptions.boost_data,
                states: {
                    inactive: {
                        opacity: visualizerOptions.highstocks.hoverEventEnabled ? 0.2 : 1,
                    }
                },
                label: {
                    connectorAllowed: false
                },
                //!!ATTENZIONE raggruppamento dati per velocizzare rendering
                // https://api.highcharts.com/highstock/plotOptions.series.dataGrouping
                dataGrouping: {
                    enabled: false
                },
                marker: {
                    enabled: false
                },
                // events:{
                //     legendItemClick: function(e){
                //         if(e.ctrlKey == true){
                //             console.log('CONTROL KEY');
                //             return false;
                //         }
                //         else{
                //             return true;
                //         }
                //     }
                // }
                events: {
                    click: function (e) {
                        if(e.ctrlKey){
                            console.log('X: '+e.point.x);
                            console.log('Y: '+e.point.y);
                            console.log('ID:'+this.options.id);

                            var stprid = parseInt(this.options.id.replace('field_', ''));

                            // console.dir(e);
                            var url = '/dat_validazione/'+stprid+'/'+e.point.x;
                            window.open(url, '_blank');
                        }
                    }
                }
            },
            column: {
                grouping: true,
            }
        },
        legend: {
            y: 20,
            height: 60,
            maxHeight: 65,
            align: 'left',
            // alignColumns: false,
            width: '97%',
            itemWidth: 180,
            itemDistance: 30,
            itemHoverStyle: {
                color: '#006aa9'
            },
            itemStyle: {
                color: '#000000',
                fontWeight: 'bold',
                fontSize: visualizerOptions.highstocks.legendFontSize+'px',
                width: 150,
                textOverflow: 'ellipsis'
            }
        },
        tooltip: {
            enabled: visualizerOptions.highstocks.tooltipType != 'disabled' ? true : false,
            shared: visualizerOptions.highstocks.tooltipType == 'shared' ? true : false,
            // enabled: false,
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
                enabled: false
            }
        }
    });

    console.log("END createChart "+ macroIdx);
}

/**
 * Function that adds series by stpr_id to the chart and takes care of options of the macro
 *
 * @param {integer} macroIdx Macro index
 * @param {text nullable} numDays default number of days to be showed
 */
function refreshChart(macroIdx, numDays){

    // get macro object from active macros array
    var activeMacro = arrayMacros[macroIdx];

    console.log("refreshChart "+ macroIdx);
    // console.dir(activeMacro);

    // reset table container
    $('#html_table_container_'+macroIdx).empty();
    // destroy and create the chart
    createChart(macroIdx);

    // variables for formated dates
    var dateFromFormatted;
    var dateToFormatted;

    // check if numDays is null
    // if true then use dates form default inputs
    // else calculate start and end dates based on numDays
    if(numDays == null){
        // change dates format based on selected aggregation
        var aggregation = activeMacro.macro.aggregation;

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

        dateToFormatted = moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm');
    }
    else{
        // split string in order to get number of days to be showed
        var res = numDays.split(' ');
        var num = parseInt(res[0]);
        var period = res[1];

        dateFromFormatted = moment().utc().subtract(num, period).format('YYYY-MM-DD HH:00');
        dateToFormatted   = moment().utc().format('YYYY-MM-DD HH:59');
    }

    // console.log(dateFromFormatted);
    // console.log(dateToFormatted);

    // show Highcharts default preloader
    charts[macroIdx].showLoading();
    // Get data via an ajax calll
    var jqxhr = $.ajax({
        url: '/str_vis_get_highcharts_data_bydate',
        type: "post",
        dataType: "json",
        data: {
            macro: JSON.stringify(activeMacro),
            from: dateFromFormatted,
            to: dateToFormatted
        }
    })
    .done(function(result) {

        // check result
        // if OK then build html table and add series to the chart
        // else show error message
        if(result.res == 'OK'){

            var data = result.data;
            // use slice for a Shallow copy in order to prevent modifications on original array
            var params = activeMacro.params.slice();

            // create html of the table and append it
            var html = fillHtmlTable(macroIdx, data);
            $('#html_table_container_'+macroIdx).html(html);

            // loop through all data objects
            // for each object add series to chart
            $.each(data, function (key, value) {

                // get nth macro's parameter object
                var param = params[key];

                // take care of macro options
                var legend = param.legend;
                if(visualizerOptions.general.treatmentEnabled){

                    var treatmentTxt = $("#treatment a[data-type='"+param.treatment+"']").text();
                    legend += ' - '+treatmentTxt;
                }

                var options = {
                    id: 'field_'+value.station_param_id,
                    name: legend, //value.series_name,
                    color: param.color == 'FFFFFF'? undefined : '#'+param.color,
                    data: value.station_param_values,
                    tooltip: {
                        valueDecimals: param.decimals
                    }
                };

                // create min and max series objects
                var max = {
                    id: 'max_'+value.station_param_id,
                    name: 'Max',
                    color: '#cf5d36',
                    data: value.station_max_values,
                };

                var min = {
                    id: 'min_'+value.station_param_id,
                    name: 'Min',
                    color: '#4cad58',
                    data: value.station_min_values,
                };

                // take care of parameter options
                // add series to chart without redrawing it
                if(param.chartstyle == 'point' || param.chartstyle == 'line_marker'){

                    options.type     = 'line';
                    options.lineWidth= (param.chartstyle == 'line_marker') ? 2 : 0;
                    options.marker   = {
                                    enabled: true,
                                    radius: 2.5
                                };

                    charts[macroIdx].addSeries(options, false);

                    if(param.maxval){
                        max.type     = 'line';
                        max.lineWidth= 0;
                        max.marker   = {
                                        enabled: true,
                                        radius: 2
                                    };
                        charts[macroIdx].addSeries(max, false);
                    }

                    if(param.minval){
                        min.type     = 'line';
                        min.lineWidth= 0;
                        min.marker   = {
                                        enabled: true,
                                        radius: 2
                                    };
                        charts[macroIdx].addSeries(min, false);
                    }
                }
                else{ //line, column, area

                    options.type     = param.chartstyle;
                    options.lineWidth= 2;
                    options.marker   = {
                            enabled: false
                        };

                    charts[macroIdx].addSeries(options, false);

                    if(param.maxval){
                        max.dashStyle = 'ShortDash';

                        charts[macroIdx].addSeries(max, false);
                    }

                    if(param.minval){
                        min.dashStyle = 'ShortDash';

                        charts[macroIdx].addSeries(min, false);
                    }
                }

                // check it is the last loop
                if(key == params.length-1){

                    // chart[stackId][macroIdx].yAxis[0].setExtremes(activeMacro.macro.Yaxys_min, activeMacro.macro.Yaxys_max, false);

                    // redraw chart all at once
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
                                        // series.hide();
                                        series.setVisible(false, false);
                                    });
                                    // redraw chart all at once
                                    charts[macroIdx].redraw();
                                    item.show();
                                }
                                // else if(e.ctrlKey == true){
                                //     charts[macroIdx].series.forEach(function(series){
                                //         // series.hide();
                                //         series.setVisible(true, false);
                                //     });
                                //     // redraw chart all at once
                                //     charts[macroIdx].redraw();
                                //     item.show();
                                // }
                            }.bind(this)
                        );
                    });

                    charts[macroIdx].hideLoading();
                }
            });

            // MIN AND MAX
            // check if user has setted a min or max axys
            // if true then add plotlines to the chart
            if ( activeMacro.macro.min != null ) {
                var min = {
                    color: '#f1d700',
                    width:2,
                    value: activeMacro.macro.min,
                    dashStyle: 'LongDashDot'
                };
                charts[macroIdx].yAxis[0].addPlotLine(min);
            }

            if ( activeMacro.macro.max != null) {
                var max = {
                    color: '#ae312d',
                    width:2,
                    value: activeMacro.macro.max,
                    dashStyle: 'LongDashDot'
                };
                charts[macroIdx].yAxis[0].addPlotLine(max);
            }

            // hide preloader at the end of the process
            $('.preloader').hide();
        }
        else{
            // hide preloader at the end of the process
            $('.preloader').hide();
            // error message
            swal("Errore!", "Tutto andato male", "error");
        }
    })
    .fail(function(xhr, err) {
        // hide preloader at the end of the process
        $('.preloader').hide();
        // error message
        swal("Errore!", "Tutto andato male", "error");
    });
}

/**
 * Function that builds a html table
 *
 * @param {integer} macroIdx Macro index
 * @param {array} paramsData Array for parameters data
 *
 * @return the new HTML created
 */
function fillHtmlTable(macroIdx, paramsData){

    // initialize the variable for the header
    var htmlTh = '<tr><th scope="col">Data</th>';
    // create an empty array that for each row will hold the concatenation of td elements
    // ATTENTION! the creation of the html is vertically oriented
    // that's why we need an array variable as a support in order to build table rows
    var htmlTd = [];

    // loop through all parameters
    // for each element build the header taking care of min and max series
    $.each(paramsData, function (paramKey, param) {

        htmlTh += '<th scope="col">'+arrayMacros[macroIdx].params[paramKey].column_name+'</th>';
        if(arrayMacros[macroIdx].params[paramKey].minval == true)
            htmlTh += '<th scope="col">Min</th>';

        if(arrayMacros[macroIdx].params[paramKey].maxval == true)
            htmlTh += '<th scope="col">Max</th>';

        // loop through all data (array of [x,y] values)
        // for each couple of data build a td element
        $.each(param.station_param_values, function(tdKey, value){

            // if the array element is still empty
            // then add the row's first td with the date
            if(htmlTd[tdKey] == null)
                htmlTd[tdKey] = '<tr><td>'+getFormattedDateDT(value[0], 'basic_timeStartMin')+'</td>';

            htmlTd[tdKey] += '<td>'+ (value[1] != null ? value[1] : '--') +'</td>';

            // take care of min and max series
            if(arrayMacros[macroIdx].params[paramKey].minval == true)
                htmlTd[tdKey] += '<td>'+ (param.station_min_values[tdKey][1] != null ? param.station_min_values[tdKey][1] : '--') +'</td>';

            if(arrayMacros[macroIdx].params[paramKey].maxval == true)
                htmlTd[tdKey] += '<td>'+ (param.station_max_values[tdKey][1] != null ? param.station_max_values[tdKey][1] : '--') +'</td>';
        });

    });

    // close header row
    // htmlTh += '</tr>';

    // create global html variable and build the thead element
    var html = '<thead>';
    // append created header and close the row
    html += htmlTh +'</tr>';
    // close thead elemend and open the tbody
    html += '</thead>';
    html += '<tbody>';
    // loop through all rows and append them to table
    $.each(htmlTd, function(idx, td){
        // close row
        html += td +'</tr>';
    });
    // close tbody
    html += '</tbody>';

    // return the new html
    return html;
}