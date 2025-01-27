/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;
    var columns;

    // variable for loadReport function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(3, 'days').format('YYYY-MM-DD');

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
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        var stid = $( "#stations" ).val();
        if( stid != -1){
            $('.inner-preloader').show();
            loadData(dateFrom, dateTo, stid);
        }
    });

    $(".diag").hide();

    $("#provinces, #networks" ).select2();
    // select2 initialization
    $( "#stations" ).select2({
        matcher: searchGroupedSelect2
    });

    /**
     * Load diagnostics data on station filter change.
     */
    $( "#stations" ).on("change", function(e){
        e.preventDefault();

        var stid = $(this).val();
        var stname = $(this).find('option:selected').text();

        // check if station is selected
        //  - if not -1 then get station name and show the relative diagnostics
        //  - if -1 then destory table and clear data
        if(stid != -1){
            $("#sel-station").html(stname);
            $(".diag").show();
        }
        else{
            $(".diag").hide();
            $("#sel-station").html("");
            table.destroy();
            table.clearData();
            return;
        }
        console.log('loadData');

        $('.inner-preloader').show();
        loadData(dateFrom, dateTo, stid);
    });

    /**
     * Load stations on province/network filter change.
     */
    $( "#provinces, #networks" ).on( "change", function(e) {
        e.preventDefault();

        // if network change then reset province
        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }

        var province = parseInt($("#provinces").val());
        var network = parseInt($("#networks").val());

        // load list of stations
        loadStations(province, network);
    });

    /**
     * Select option -1 and load all stations.
     */
    $( "#networks" ).trigger("change"); //

    /**
     * Download the diagnostics table in .csv format.
     */
    $( "#download-csv" ).on('click', function(e){

        var fileName = 'diags_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY-MM-DD")+'_'+moment(dateTo).format("YYYY-MM-DD")+'.csv';
        table.download("csv", fileName, {}, "all");
        e.preventDefault();
    });

    /**
     * Download the diagnostics table in .xlsx format.
     */
    $( "#download-xlsx" ).on('click', function(e){

        var fileName = 'diags_'+$( "#stations" ).find('option:selected').text()+'_'+moment(dateFrom).format("YYYY-MM-DD")+'_'+moment(dateTo).format("YYYY-MM-DD")+'.xlsx';
        table.download("xlsx", fileName, {sheetName:"Diagnostici"});
        e.preventDefault();
    });

    /**
     * Function that retrieves the stations of a given network of a given province.
     *
     * @param {integer} province Province ID.
     * @param {integer} network Network ID.
     */
    function loadStations(province, network){

        console.log('loadStations: '+province+' '+network);

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_diagnostici_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: province,
                net: network
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            //  - if res is 'OK' then success, reload the station list
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                $('#stations').empty();
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
                if(province == -1){
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

                // append options and close last optgroup
                $('#stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#stations').append(opts);
                $('#stations').append('</optgroup>');

                $('#stations').val(-1);
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
    }

    /**
     * Function that retrieves the diagnostics's data of a given station of a given period.
     *
     * @param {date}    dateFrom Start period datetime.
     * @param {date}    dateTo End period datetime.
     * @param {integer} stid Station ID.
     */
    function loadData(dateFrom, dateTo, stid){

        // ajax call
        var jqxhr = $.ajax({
            url: '/dat_diagnostici_get_diags_data',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo,
                stid: stid
            },
        })
        .done(function(result) {
            // check result
            //  - if res is 'OK' then success, create the diagnostics table
            //  - if res is not 'OK' then error
            if(result.res == 'OK'){
                console.dir(result);
                createTable(result);
            }
            // swal("Successo!", "I dati sono stati recuperati correttamente", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that builds the diagnostics table.
     *
     * @param {object} result Data query results.
     */
    function createTable(result){

        columns = [];
        // set the first column of the table: fulldate (dd/mm/yyyy hh:mm)
        column_fulldate = {
            title: "Data",
            // align:"left",
            field: "fulldate",
            frozen: true,
            formatter:function(cell, formatterParams, onRendered){
                // cell - the cell component
                // formatterParams - parameters set for the column
                // onRendered - function to call when the formatter has been rendered
                return getFormattedDateDT(cell.getValue(), 'basic_timeStartMin'); // global.js
            },
        };
        columns.push(column_fulldate);

        var extColumn = null;
        var oldInstr;

        $.each(result.diags, function (data_key, data_value) {

            // console.log('Colonna esterna: '+ data_value.diag_instr_id);

            // check if the current looped diagnostic is associated to a different instrument then the previous one
            //  - if true then set a new outter column for the new instrument
            //  - if false set the diagnostic under the current instrument column
            if(oldInstr != data_value.diag_instr_id){

                if(extColumn != null)
                    columns.push(extColumn);

                oldInstr = data_value.diag_instr_id;
                extColumn = {
                    title: data_value.diag_instr_id,
                    hozAlign:"center",
                    columns: []
                };

                var innerColumn = {
                    title: data_value.diag_name,
                    field: 'value_'+data_value.diag_id,
                    headerSort: false,
                    hozAlign:"center",
                    formatterParams: {
                        diagId: data_value.diag_id,
                        parentName : data_value.diag_instr_id,
                        nextParentName : ( result.diags[data_key + 1 ] ? result.diags[data_key + 1 ].diag_instr_id : null)
                    },
                    formatter: function(cell, formatterParams, onRendered){

                        var diagId = formatterParams.diagId;
                        var cellClass = cell.getRow().getData()['class_'+diagId];

                        if(cellClass != null)
                            cell.getElement().classList.add(cellClass);

                        // if( formatterParams.parentName != formatterParams.nextParentName)
                        //     cell.getElement().classList.add('last-cell-group');

                        return cell.getValue();
                    }
                };

                extColumn.columns.push(innerColumn);
            }
            else{

                var innerColumn = {
                    title: data_value.diag_name,
                    field: 'value_'+data_value.diag_id,
                    headerSort: false,
                    hozAlign:"center",
                    formatterParams: {
                        diagId: data_value.diag_id,
                        parentName : data_value.diag_instr_id,
                        nextParentName : ( result.diags[data_key + 1 ] ? result.diags[data_key + 1 ].diag_instr_id : null)
                    },
                    formatter: function(cell, formatterParams, onRendered){

                        var diagId = formatterParams.diagId;
                        var cellClass = cell.getRow().getData()['class_'+diagId];
                        if(cellClass != null)
                            cell.getElement().classList.add(cellClass);

                        // if( formatterParams.parentName != formatterParams.nextParentName)
                        //     cell.getElement().classList.add('last-cell-group');

                        return cell.getValue();
                    }
                };

                extColumn.columns.push(innerColumn);
            }
        });

        // append last item
        if(extColumn != null)
            columns.push(extColumn);

        console.log('Oggetto colonne')
        console.dir(columns);

        table = new Tabulator("#diag-table", {
            locale: 'it',
            height:'100%',
            data: result.data,
            layout:"fitData", // fitColumn
            columns: columns,
            columnHeaderVertAlign:"bottom",
            index:"fulldate",
            pagination: true,
            paginationMode: "local",
            paginationSize: 24,
            paginationSizeSelector:true,
            placeholder:"Nessun dato"
        });

        table.on('tableBuilt', function(){
            $('.inner-preloader').hide();
        });
        // locale: 'it',
        // autoResize:false,
        // // debugEventsInternal:["table-redrawing", "table-redraw", "table-resized"],
        // // debugInvalidOptions: false,
        // // renderVerticalBuffer:100,
        // // tooltipGenerationMode:"hover",
        // height:'100%',
        // data: result.data,
        // layout:"fitData", //fitColumn
        // columns: columns,
        // index:"fulldate",
        // pagination: true,
        // paginationMode: "local",
        // paginationSize: (result.data.length/(numberDays+1)),
        // paginationSizeSelector:true,
        // history:true,
        //         placeholder:"Nessun dato"

        // table.setLocale("it-it");
        // table.setData(result.data);
        // table.redraw(true);
        // $('.inner-preloader').hide();
    }
});


