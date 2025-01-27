// GLOBAL VARIABLES
var maintable;
var chart = [];
var table = [];

var station_grants;

// SELECTING STUFF
var isMouseDown = false;
var firstCell;
var selectedCells = [];

// OTHER STUFF
var clipboardEnabled = false;
var rightClickCell;
var modifiedCells = [];

document.body.style.MozUserSelect="none"

$(document)
.mousedown(function(e){
    // $(".tabulator-cell").removeClass('cell-selected');
    // if event is a single-click
    if(e.which === 1){
        isMouseDown = true;
    }
})
.mouseup(function () {
    // reset variables of the selection
    isMouseDown = false;
    firstCell = null;
});

// LOCAL FUNCTIONS
/////////////////////////////////////////////////////////////////////////

/**
 * Function that manages filters of the maintable
 */
function updateFilter(){

    // console.log('updateFilter '+id);
    var fieldEl = document.getElementById("filter-field");
    var typeEl = document.getElementById("filter-type");
    var valueEl = document.getElementById("filter-value");

    var filterVal = fieldEl.options[fieldEl.selectedIndex].value;
    var typeVal = typeEl.options[typeEl.selectedIndex].value;
    // filter cells by selected operation
    // otherwise reset table visualization
    if(filterVal && valueEl.value != ''){
        maintable.setFilter(filterVal, typeVal, parseFloat(valueEl.value));
    }
    else
        maintable.clearFilter();
}

/**
 * Function that retrieves the modification history of the clicked cell
 *
 * @param {object} cell table's clicked cell
 */
function getValidationHistory(cell){
    // reset left-bottom div
    $("#codes-detail").empty();
    $("#changes-detail").empty();

    // get metadata stored in the column definition
    var definition = cell.getColumn().getDefinition().editorParams;
    // get row date
    var date = cell.getRow().getCells()[0].getValue();
    var tableid = definition.tableid;
    var fulltable = definition.table;
    var stprid = definition.id;

    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_get_validation_codes_bycell',
        type: "post",
        dataType: "json",
        data: {
            table: fulltable,
            date: date,
            id: tableid,
            stprid: stprid
        }
    })
    .done(function(result) {

        // check result
        // - if OK then build html with information retrieved from the database
        // - else error message
        if(result.res == 'OK'){
            // variable for dynamically build the html
            var html = '';

            // cell codes and modifications history
            var codes = result.codes;
            var dataChanges = result.history;
            console.dir(dataChanges);

            // codes from the periphery
            if(codes.periphery_codes.length > 0){
                html += '<h6>Validazione da periferia</h6>';
                html += '<ul class="val-history">';
                codes.periphery_codes.forEach(function(code) {
                    html += '<li><i class="'+code[1]+' '+code[2]+'"></i>&nbsp;'+code[0]+'</li>';
                });
                html += '</ul>';
            }

            // codes from automatic validation
            html += '<h6>Validazione automatica</h6>';
            html += '<ul class="val-history">';
            codes.auto_codes.forEach(function(code) {
                html += '<li><i class="'+code[1]+' '+code[2]+'"></i>&nbsp;'+code[0]+'</li>';
            });
            html += '</ul>';

            // codes from the operator
            html += '<h6>Validazione da operatore</h6>';
            html += '<ul class="val-history">';
            codes.user_codes.forEach(function(code) {
                html += '<li><span class="'+code[1]+'"></span>'+code[0]+'</li>';
            });
            html += '</ul>';

            // final validation codes
            html += '<h6>Validazione finale</h6>';
            html += '<ul class="val-history">';
            codes.final_codes.forEach(function(code) {
                html += '<li><i class="'+code[1]+' '+code[2]+'"></i>&nbsp;'+code[0]+'</li>';
            });
            html += '</ul>';

            // update_fulldate: "2022-04-04 07:30:37.011139"
            // update_fulldate_formatted: "04/04/2022 09:30"
            // update_new: "{\"p\": -64, \"v\": 5.70}"
            // update_note: null
            // update_old: "{\"p\": 0, \"v\": 5.7}"
            // update_user: 4
            // user_fullname: "Utente TEST"

            // get metadata from column definition
            var unit = definition.unit;
            var decimals = definition.decimals;

            // variable for dynamically build the html
            var htmlChanges = '';
            // check that at least one modification exists
            if (dataChanges.length != 0){
                // build table with the state of the cell before and after the modification
                htmlChanges += '<div class="people-val">';

                htmlChanges += '<table class="table table-hover table-bordered">';
                htmlChanges += '    <tr>';
                htmlChanges += '        <th rowspan="2">Data</th>';
                htmlChanges += '        <th rowspan="2">Utente</th>';
                htmlChanges += '        <th colspan="2" class="text-center">Val. ['+unit+']</th>';
                htmlChanges += '        <th colspan="2" class="text-center">Cod.</th>';
                htmlChanges += '        <th colspan="2" class="text-center">CodF.</th>';
                htmlChanges += '    </tr>';
                htmlChanges += '    <tr>';
                htmlChanges += '        <th class="text-right cell-bg-grey">Prima</th>';
                htmlChanges += '        <th class="text-right">Dopo</th>';
                htmlChanges += '        <th class="text-right cell-bg-grey">Prima</th>';
                htmlChanges += '        <th class="text-right">Dopo</th>';
                htmlChanges += '        <th class="text-right cell-bg-grey">Prima</th>';
                htmlChanges += '        <th class="text-right">Dopo</th>';
                htmlChanges += '    </tr>';
                dataChanges.forEach(function(change) {
                    var oldStatus = JSON.parse(change.update_old);
                    var newStatus = JSON.parse(change.update_new);

                    htmlChanges += '    <tr>';
                    htmlChanges += '        <td>'+change.update_fulldate_formatted+'</td>';
                    htmlChanges += '        <td>'+change.user_fullname+'</td>';

                    var conv = change.param_conv ;

                    if(validationOptions.general.convEnabled){

                        var oldValue = (oldStatus.v*conv);
                        // manage NaN case: tipically for insert action there is no old value
                        if( isNaN(oldValue) )
                            oldValue = '--';
                        else
                            oldValue = oldValue.toFixed(decimals);

                        htmlChanges += '        <td class="text-right cell-bg-grey">'+oldValue+'</td>';
                        htmlChanges += '        <td class="text-right">'+(newStatus.v*conv).toFixed(decimals)+'</td>';
                    }
                    else{
                        var oldValue = oldStatus.v;
                        // manage NaN case: tipically for insert action there is no old value
                        if( isNaN(oldValue) )
                            oldValue = '--';
                        else
                            oldValue = oldValue.toFixed(decimals);

                        htmlChanges += '        <td class="text-right cell-bg-grey">'+oldValue+'</td>';
                        htmlChanges += '        <td class="text-right">'+newStatus.v.toFixed(decimals)+'</td>';
                    }
                    htmlChanges += '        <td class="text-right cell-bg-grey">'+oldStatus.p+'</td>';
                    htmlChanges += '        <td class="text-right">'+newStatus.p+'</td>';
                    htmlChanges += '        <td class="text-right cell-bg-grey">'+oldStatus.f+'</td>';
                    htmlChanges += '        <td class="text-right">'+newStatus.f+'</td>';
                    htmlChanges += '    </tr>';


                });
                htmlChanges += '</table>';
                htmlChanges += '</div>';
            };

            $("#changes-detail").append(htmlChanges);
        }
        else{
            // codes from the periphery
            html += '<h6>Validazione da periferia</h6>';
            html += '<p class="no-codes-val">Nessun codice presente</p>';

            // codes from automatic validation
            html += '<h6>Validazione automatica</h6>';
            html += '<p class="no-codes-val">Nessun codice presente</p>';

            // codes from the operator
            html += '<h6>Validazione da operatore</h6>';
            html += '<p class="no-codes-val">Nessun codice presente</p>';

            // final validation codes
            html += '<h6>Validazione finale</h6>';
            html += '<p class="no-codes-val">Nessun codice presente</p>';
        }
        // append html of the codes in the correct tab
        $("#codes-detail").append(html);

    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei dati", "error");
    });
}

/**
 * Function which selects the cells over which the mouse passes with the left button pressed
 *
 * @param {object} cell1 first cell
 * @param {object} cell2 last cell
 * @param {object} tbl table
 */
function selectCells(cell1, cell2, tbl){
    // reset selected cell
    for(var i = 0; i< selectedCells.length; i++){
        selectedCells[i].getElement().classList.remove('cell-selected');
        setClasses(selectedCells[i]);
    }
    selectedCells = [];

    // retrieve active rows and page index
    var rows = tbl.getRows('active');
    var page = tbl.getPage()-1;
    var pageLength = tbl.getPageSize();

    // get X,Y coordinates of first and last cells
    cell1_X = cell1.getColumn().getDefinition().formatterParams.position;
    cell1_Y = cell1.getRow().getPosition()+(page*pageLength)-1;
    // cell1_Y = cell1.getRow().getPosition(); //1

    cell2_X = cell2.getColumn().getDefinition().formatterParams.position;
    cell2_Y = cell2.getRow().getPosition()+(page*pageLength)-1;
    // cell2_Y = cell2.getRow().getPosition(); //8

    // build different "while" condition depending on whether cell1_y is greater than or less than cell2_Y
    var start_Y = cell1_Y;
    var operatorY;
    if(cell1_Y > cell2_Y)
        operatorY = start_Y +' >= '+ cell2_Y ;
    else
        operatorY = start_Y +' <= '+ cell2_Y ;

    while( eval(operatorY) ){
        // get row's cells
        var cells = rows[start_Y].getCells();

        var start_X = cell1_X;
        // build different "while" condition depending on whether cell1_X is greater than or less than cell2_X
        var operatorX;
        if(cell1_X > cell2_X)
            operatorX = start_X +' >= '+ cell2_X ;
        else
            operatorX = start_X +' <= '+ cell2_X ;

        while( eval(operatorX) ){
            // select [start_X , start_Y] cell and add "selected" class
            cells[start_X+1].getElement().classList.add('cell-selected');
            setClasses(cells[start_X+1]);
            // push selected cell into global array
            selectedCells.push(cells[start_X+1]);

            // increase or decrease X pointer depending on whether cell1_X is greater than or less than cell2_X
            // update "while" condition with new pointer value
            if(cell1_X > cell2_X){
                start_X--;
                operatorX = start_X +' >= '+ cell2_X ;
            }
            else{
                start_X++;
                operatorX = start_X +' <= '+ cell2_X ;
            }
        }

        // increase or decrease Y pointer depending on whether cell1_Y is greater than or less than cell2_Y
        // update "while" condition with new pointer value
        if(cell1_Y > cell2_Y){
            start_Y--;
            operatorY = start_Y +' >= '+ cell2_Y ;
        }
        else{
            start_Y++;
            operatorY = start_Y +' <= '+ cell2_Y ;
        }
    }
}

/**
 * Function that initialize tabulator plugin with metadata retrieved from database
 *
 * @param {object} result from database
 */
function createTable(result){

    centralContainer.contentItems[0].container.getState().conv = validationOptions.general.convEnabled;

    var columns = [];
    var alarms = [];

    $("#filters").parent().remove();
    // if filter option is enable then add html row with filters
    if(validationOptions.tabulator.filtersEnabled){
        var html = '<div class="container calc-filter">';
        html    += '    <div id="filters" class="row custom-gutter">';
        html    += '        <div class="col-sm-4">';
        html    += '        <select id="filter-field" class="form-control">';
        html    += '            <option value="">Seleziona colonna...</option>';
        html    += '        </select>';
        html    += '        </div>';
        html    += '        <div class="col-sm-2">';
        html    += '        <select id="filter-type" class="form-control">';
        html    += '            <option value="=">=</option>';
        html    += '            <option value="<"><</option>';
        html    += '            <option value="<="><=</option>';
        html    += '            <option value=">">></option>';
        html    += '            <option value=">=">>=</option>';
        html    += '            <option value="!=">!=</option>';
        html    += '        </select>';
        html    += '        </div>';
        html    += '        <div class="col-sm-4">';
        html    += '        <input id="filter-value" type="text" placeholder="valore per cui filtrare" class="form-control">';
        html    += '        </div>';
        html    += '        <div class="col-sm-2">';
        html    += '        <button id="filter-clear" class="form-control btn btn-success">Annulla</button>';
        html    += '        </div>';
        html    += '    </div>';
        html    += '</div>';

        $('#maintable-container').parent().prepend(html);

        // Update filters on value change
        document.getElementById("filter-field").addEventListener("change", updateFilter);
        document.getElementById("filter-type").addEventListener("change", updateFilter);
        document.getElementById("filter-value").addEventListener("keyup", updateFilter);

        // Clear filters on "Clear Filters" button click
        document.getElementById("filter-clear").addEventListener("click", function(){
            var fieldEl = document.getElementById("filter-field");
            var typeEl = document.getElementById("filter-type");
            var valueEl = document.getElementById("filter-value");

            fieldEl.value = "";
            typeEl.value = "=";
            valueEl.value = "";

            maintable.clearFilter();
        });
    }

    // if array of alarms is not empty then build an customized array
    // where indexes are unix dates and values are the labels of the alarms
    if(result.alarms){
        result.alarms.forEach(function(value, index){
            alarms[moment(value.sa_fulldate).unix()] = value.sa_labels;
        });
    }

    // build object for the first column containing data dates
    column_fulldate = {
        title: "Data",
        field: "fulldate",
        minWidth: 150,
        frozen: true,
        headerTooltip:false,
        formatter:function(cell, formatterParams, onRendered){
            //cell - the cell component
            //formatterParams - parameters set for the column
            //onRendered - function to call when the formatter has been rendered
            onRendered(function(){
                setTimeout(function(){
                    // initialize tooltip plugin
                    $('[data-toggle-table="tooltip"]').tooltip();
                }, 10);

            });

            var index = moment(cell.getValue()).unix();
            var icon = '';
            // if there alarms for current date then add tooltip attributes
            if(alarms[index]){
                var element = cell.getElement();
                element.classList.add('cell-alarm');
                element.setAttribute('data-toggle-table', 'tooltip');
                element.setAttribute('data-html', 'true');
                element.setAttribute('data-original-title', alarms[index].join('<br>'));

                icon = '<i class="ti-signal valid-alarm"></i> ';
            }
            // return formatted cell
            return icon+getFormattedDateDT(cell.getValue(), 'basic_timeStartMin'); //global.js
        }
    };

    // push first column to columns array
    columns.push(column_fulldate);

    // loop through alla parameters
    // for each parameter build a column of the table
    $.each(result.params, function (data_key, data_value) {

        var column_name = data_value.column_name;

        column_obj = {
            title: column_name,
            field: 'field_'+data_key,
            headerSort: false,
            editor: 'number',
            editorParams: {
                // default
                step: Math.pow(10, -data_value.parameter_decimals),
                // additional
                id: data_value.station_param_id,
                tableid: data_value.station_param_table_id,
                table: data_value.station_fulltable,
                // conv: data_value.parameter_conv,
                unit: data_value.unit,
                decimals: data_value.parameter_decimals,
                insertGrant: data_value.station_insert,
                updateGrant: data_value.station_update
            },
            editable:false,
            formatterParams: {
                position: data_key,

            },
            formatter:function(cell, formatterParams, onRendered){
                //cell - the cell component
                //formatterParams - parameters set for the column
                //onRendered - function to call when the formatter has been rendered
                var position = formatterParams.position;
                var cellClasses  = cell.getRow().getData()["class_"+position]; //from DB

                cellClasses = cellClasses.split(' ');
                // add classes arrived from db to cell element
                cellClasses.forEach(function(cellClass) {
                    cell.getElement().classList.add(cellClass);
                });
                //return the contents of the cell;
                return cell.getValue();
            },
            formatterClipboard: function(cell, formatterParams, onRendered){
                // if value is equal to -- then returns an empty string
                return cell.getValue() == '--' ? '' : cell.getValue();
            },
            // format values entered via clipboard or manually
            mutatorEditParams: {
                decimals: data_value.parameter_decimals
            },
            mutatorClipboard: function(value, data, type, params, column){
                return (value == '' || value == '\r') ? '--' : value;
            },
            mutatorEdit : function(value, data, type, params, cell){
                var val = parseFloat(value);
                if(isNaN(val))
                    return '--';
                else
                    return val;
                    // return val.toFixed(params.decimals);
            },
            // click event
            cellClick:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled)
                    return;
                // if single click then select current cell and get value's modification history
                if (e.detail == 1) {

                    for(var i = 0; i< selectedCells.length; i++){
                        selectedCells[i].getElement().classList.remove('cell-selected');
                        setClasses(selectedCells[i]);
                    }
                    selectedCells = [];

                    cell.getElement().classList.add('cell-selected');
                    setClasses(cell);
                    // select cell
                    selectedCells.push(cell);

                    // get cell validation history
                    getValidationHistory(cell);
                }
            },
            // mouse move event
            cellMouseMove:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled == true || $('.tabulator-editing').length > 0 )
                    return;

                var cellDate = cell.getRow().getCells()[0].getValue();
                // check if value date is before closure date (portal options)
                // - if true then select do nothing
                // - else continue
                if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                    return;
                }

                // if mouse's left button is pressed then set variables of the selection action
                if(isMouseDown){
                    // if first cell is empty then the current one is the first
                    if(firstCell == null){
                        // reset left-bottom box
                        $("#codes-detail").empty();
                        $("#changes-detail").empty();
                        firstCell = cell;
                    }
                    // store current cell as last one of the selection
                    var lastCell = cell;
                    // select cells
                    selectCells(firstCell, lastCell, firstCell.getTable());
                    // show button
                    $("#deselect-cells").show();
                }
            },
            // double click event
            cellDblClick:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled == true)
                    return;

                var cellDate = cell.getRow().getCells()[0].getValue();
                // check if value date is before closure date (portal options)
                // - if true then select do nothing
                // - else continue
                if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                    return;
                }

                // if it is a double click action then enable edit cell
                if(e.detail == 2){
                    // data not present in the database => insert action
                    if(cell.getValue() == '--'){
                        if( insert_grant && data_value.station_insert && !cell.getElement().classList.contains('tabulator-editing')){
                            cell.edit(true);
                        }
                    } // data present in the database => update action
                    else{
                        if( update_grant && data_value.station_update && !cell.getElement().classList.contains('tabulator-editing')){
                            cell.edit(true);
                        }
                    }
                }

            },
            // right click event
            cellContext:function(e, cell){

                // get metadata stored in the column definition
                var column = cell.getColumn();
                var cells = cell.getRow().getCells();

                var stprid = column.getDefinition().editorParams.id;
                var date = cells[0].getValue();
                // store clicked cell
                rightClickCell = cell;
                // add multiview tab - validazione_layout.js
                addMultiView(stprid, date);
            }
        };

        // push object in the columns array
        columns.push(column_obj);

        // add column to table's filter
        var htmlOpt= '<option value="field_'+data_key+'">'+column_name.replace(/<.*>/g, "")+'</option>';
        $("#filter-field").append(htmlOpt);
    });

    // get number of displayed days
    var numberDays = moment(dateTo, 'DD/MM/YYYY HH:mm').diff(moment(dateFrom, 'DD/MM/YYYY HH:mm'), 'days');

    // if maintable already initialized
    // then reset tabulator and add new columns and new data
    if(maintable != null){
        maintable.clearData();
        maintable.setColumns( columns );
        maintable.setData(result.data).then(function(){
            // at the end of the process hide preloader
            $('.preloader').hide();
        });
        // maintable.on('renderComplete', function(){
        //     maintable.setData(result.data);
        //     $('.preloader').hide();
        // });
    }
    // otherwise initialize tabulator
    else{
        maintable = new Tabulator("#maintable-container", {
            locale: 'it',
            autoResize:false,
            keybindings:{
                "copyToClipboard" : false
            },
            // debugEventsInternal:["edit-success"],
            // debugInvalidOptions: false,
            // renderVerticalBuffer:100,
            // tooltipGenerationMode:"hover",
            height:'100%',
            data: result.data,
            layout:"fitData", //fitColumn
            columns: columns,
            index:"fulldate",
            pagination: !clipboardEnabled, //true,
            paginationMode: "local",
            paginationSize: (result.data.length/(numberDays+1)),
            paginationSizeSelector:true,
            history:true,
            clipboard:true,
            clipboardCopyStyled:false,
            clipboardPasteAction: function(rowsData){
                // if clipboard not enabled then disable paste event
                if(! clipboardEnabled)
                    return;

                var res = false;
                modifiedCells = [];
                // reset all selected cells - validazione_setting.js
                $("#deselect-cells").trigger("click");

                // for each row in clipboard
                // retrieve the corresponding row to be replaced in the maintable
                rowsData.forEach(function(el, idx){
                    if(el.fulldate && el.fulldate != ""){

                        // check if value date is before closure date (portal options)
                        // - if true then select do nothing
                        // - else continue
                        if(closureDate && moment(el.fulldate, 'DD/MM/YYYY HH:mm').isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                            return;
                        }

                        // retrive row by fulldate
                        var row = maintable.getRow(moment(el.fulldate, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD HH:mm:ss'));

                        // if row exists then replace values
                        if(row){
                            // get row cells and for each of them replace old value with the new one from clipboard
                            var cells = row.getCells();

                            if(cells.length == Object.keys(el).length ){
                                cells.forEach(function(cell, idx2){

                                    res = true;
                                    // replace only cells containing pollutants value
                                    if(cell.getField() != 'fulldate'){

                                        // format value by removing \r and by replacing comma with dot separator
                                        var val = el[cell.getField()].replace('\r', '');
                                        val = val.replace(',', '.');

                                        // update value and trigger mutatorEdit method
                                        cell.setValue( val, true );
                                        // if old value not equal to the new one
                                        // then build an obj to be sent to the server in order to save changes
                                        // moreover, select cell to manage its classes
                                        if(cell.getValue() != cell.getOldValue()){
                                            var definition = cell.getColumn().getDefinition().editorParams;
                                            var cellObj = {
                                                table: definition.table,
                                                tableid : definition.tableid,
                                                stprid: definition.id,
                                                // if oldValue equal to '--' it's an insert action, else it's an update
                                                // pick the correct user permission based on action type
                                                grant: ( cell.getOldValue() == '--' ? definition.insertGrant : definition.updateGrant ),
                                                date : cell.getRow().getCells()[0].getValue(),
                                                code : 1, //ricostruito
                                                value: cell.getValue(),
                                                oldvalue: cell.getOldValue(),
                                                dirty: 1,
                                                // conv : definition.conv,
                                                decimals: definition.decimals
                                            };

                                            modifiedCells.push(cellObj);
                                            selectedCells.push(cell);

                                            cell.getElement().classList.add('cell-modified');
                                            setClasses(cell);
                                        }
                                    }
                                });
                            }
                        }
                    }
                });

                // if no row is found
                // then error message
                if(!res){
                    swal({
                        title: "Nessuna riga è stata copiata!",
                        text: "E' possibile che le righe selezionate <strong>non siano presenti</strong> o che <strong>il numero di colonne copiate sia diverso</strong> da quelle presenti",
                        type: "error",
                        html: true,
                        closeOnConfirm: true
                    });
                }
                else{
                    $.toast({
                        heading: 'Informazione',
                        text: 'I dati sono stati incollati correttamente',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 10000,
                        showHideTransition: 'slide', // fade, slide or plain
                        stack: 2
                    });
                }

                return;
            },
            placeholder:"Nessun dato"
        });

        maintable.on('cellEdited', function(cell){

            // take cares of "cancel" actions on data
            // restore precedent value and do nothing
            if(cell.getValue() == '--'){
                cell.restoreOldValue();
                cell.clearEdited();
                cell.getElement().classList.remove('tabulator-editing');
                return;
            }

            // if cell has been edited then build an object to be sent to server
            if(cell.getValue() != cell.getOldValue() && cell.isEdited()){
                console.log("cellEdited");

                $("#undo-edit").show();
                var definition = cell.getColumn().getDefinition().editorParams;
                var cellElement = {
                    table: definition.table,
                    tableid : definition.tableid,
                    stprid: definition.id,
                    grant: ( cell.getOldValue() == '--' ? definition.insertGrant : definition.updateGrant ),
                    date : cell.getRow().getCells()[0].getValue(),
                    code : 1, //ricostruito
                    value: cell.getValue(),
                    oldvalue: cell.getOldValue(),
                    dirty: 1,
                    // conv : definition.conv,
                    decimals: definition.decimals
                };
                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // save into db changes applied by the event
                updateCells([cellElement]);
            }

            // disable editing for the current cell
            cell.clearEdited();
            cell.getElement().classList.remove('tabulator-editing');
        });

        // event triggered when active rows are copied in the clipboard
        maintable.on("clipboardCopied", function(clipboard){
            //clipboard - the string that has been copied into the clipboard
            $.toast({
                heading: 'Informazione',
                text: 'I dati della tabella sono stati copiati correttamente',
                position: 'top-right',
                loaderBg:'#e8bb05',
                icon: 'success',
                hideAfter: 10000,
                showHideTransition: 'slide', // fade, slide or plain
                stack: 2
            });
        });

        // event error during paste on clipboard
        maintable.on("clipboardPasteError", function(clipboard){
            //clipboard - the string that has been copied into the clipboard

            // if clipboard not enabled then disable paste event
            if(! clipboardEnabled)
                return;

            // show error message
            $.toast({
                heading: 'Errore',
                text: 'Si è verificato un errore durante l\'inserimento dei dati',
                position: 'top-right',
                loaderBg:'#131313',
                icon: 'error',
                hideAfter: 10000,
                showHideTransition: 'slide', // fade, slide or plain
                stack: 2
            });
        });

        // undo action event
        maintable.on('historyUndo', function(action, component, data){
            //action - the action that has been undone
            //component - the Component object afected by the action (colud be a row or cell component)
            //data - the data being changed

            // if last action is a cell modification then sets the old values and saves them in the database
            if(action == 'cellEdit'){
                //component is a cell
                // data structure
                    // {
                    //     oldValue:"", //the original value of the cell
                    //     newValue:"", //the nev value of the cell
                    // }
                var definition = component.getColumn().getDefinition();
                var cellElement = {
                    table: definition.table,
                    tableid : definition.tableid,
                    stprid: definition.id,
                    grant: 1,
                    date : component.getRow().getCells()[0].getValue(),
                    code : null,
                    value: component.getValue(),
                    dirty: 1,
                    // conv : definition.conv,
                    decimals: definition.decimals
                };
                // show preloader, waiting for the end of the process
                $('.preloader').show();
                // save into db changes applied by the event
                updateCells([cellElement]);
            }
        });

        // on change page, deselect all cells
        maintable.on('pageLoaded', function(){

            // if clipboard enabled then disable pageLoaded event
            if(clipboardEnabled)
                return;

            $("#deselect-cells").trigger('click');
        });

        // at the end of table rendering hide preloader
        maintable.on('tableBuilt', function(){
            // at the end of the process hide preloader
            $('.preloader').hide();
        });
    }
}

/**
 * Function that initialize highcharts plugin for the righ-clicked cell
 *
 * @param {timestamp} datetime of the clicked cell
 * @param {object} data result from database
 */
function createDetailedChart(datetime, data){

    // get current active tab
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    var converted = componentState.conv;
    // parse station data
    var stationData = JSON.parse(data.station_data);

    // initialize highcharts plugin with stations's metadata
    chart[componentState.id] = Highcharts.stockChart('multiview_chart_'+componentState.id, {
        title: {
            text: data.station_name+' - '+data.parameter_fullname,
            style: {
                fontSize: validationOptions.highstocks.titleFontSize+'px'
            }
        },
        exporting: {
            filename: 'Validazione_'+ moment().format('YYYY-MM-DD_HH:mm'),
            useHtml: true,
            chartOptions: {
                navigator: {
                    enabled: false
                },
                title: {
                    style: {
                        fontSize: validationOptions.highstocks.expTitleFontSize+'px'
                    }
                },
                xAxis:{
                    0: {
                        labels: {
                            rotation: - validationOptions.highstocks.labelXangle,
                            style: {
                                fontSize: validationOptions.highstocks.expLabelFontSize+'px'
                            }
                        }
                    }
                },
                yAxis: {
                    0: {
                        title: {
                            enabled : false
                        },
                        labels: {
                            style: {
                                fontSize: validationOptions.highstocks.expLabelFontSize+'px'
                            }
                        }
                    }
                },
                legend:{
                    align: 'center',
                    width: '100%',
                    itemDistance: 50,
                    itemStyle: {
                        fontSize: validationOptions.highstocks.expLegendFontSize+'px'
                    },
                    margin: 2
                }
            },
            buttons: {
                contextButton: {
                    menuItems: ["viewFullscreen", "printChart"]
                }
            }
        },
        navigator: {
            enabled: validationOptions.highstocks.navigatorEnabled,
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
        xAxis: {
            lineWidth: 3,
            gridLineWidth: 1,
            type:'datetime',
            labels: {
                useHtml: true,
                rotation: - validationOptions.highstocks.labelXangle,
                formatter: function() {
                    // return Highcharts.dateFormat('%d-%m-%Y', moment(this.value));
                    var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                    if (diff > (15*24*3600*1000)){ // 5 giorni
                        return getFormattedDateHC(this.value, 'basic'); //global.js
                    }
                    else{
                        // this.chart.xAxis[0].labels.rotation = 0;
                        return getFormattedDateHC(this.value, 'basic_timeStartMin');
                    }
                },
                style: {
                    fontSize: validationOptions.highstocks.labelFontSize+'px'
                }
            }
        },
        yAxis: {
            isInternal: false,
            lineWidth: 3,
            gridLineWidth: validationOptions.highstocks.numberYaxis > 1 ? 0 : 1,
            opposite: false,
            title: {
                text: converted ? data.parameter_unit_conv : data.parameter_unit
            },
            labels: {
                formatter: function() {
                    return this.value;
                },
                style: {
                    fontSize: validationOptions.highstocks.labelFontSize+'px'
                }
            }
        },
        credits: {
            text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
            href: company_web
        },
        plotOptions: {
            series: {
                allowPointSelect: true,
                point: {
                    events: {
                        select: function(){
                            console.log('select');
                            var date = this.x;
                            var datetime = moment.utc(date).format('YYYY-MM-DD HH:mm:ss');
                            console.log(datetime);

                            // reset selected cell
                            for(var i = 0; i< selectedCells.length; i++){
                                selectedCells[i].getElement().classList.remove('cell-selected');
                                setClasses(selectedCells[i]);
                            }
                            selectedCells = [];

                            if(table[componentState.id]){
                                var row = table[componentState.id].getRow(datetime);

                                table[componentState.id].scrollToRow(datetime, 'middle', true);
                                row.getElement().classList.add('row-highlighted');

                                var cell = row.getCells()[1];

                                // select cell
                                cell.getElement().classList.add('cell-selected');
                                setClasses(cell);
                                selectedCells.push(cell);
                            }
                        },
                        unselect: function(){
                            console.log('unselect');
                            var date = this.x;
                            var datetime = moment.utc(date).format('YYYY-MM-DD HH:mm:ss');
                            console.log(datetime);

                            if(table[componentState.id]){
                                var oldRow = table[componentState.id].getRow(datetime);

                                oldRow.getElement().classList.remove('row-highlighted');
                            }
                        }
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
                    enabled: true,
                    radius: 1,
                    symbol: 'circle',
                    states: {
                        select: {
                            enabled: true,
                            fillColor: '#028ea5',
                            lineWidth: 2,
                            radius: 5
                        }
                    }
                }
            }
        },
        legend: {
            enabled: true,
            itemStyle: {
                fontSize: validationOptions.highstocks.legendFontSize+'px'
            }
        },
        tooltip: {
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
        series: [
            {
                name: data.parameter_name,
                data: stationData.meanvalue,
                color: '#028ea5',
                lineWidth: 3,
                tooltip: {
                    valueDecimals: data.parameter_decimals
                },
                zIndex: 999
            }
        ]
    });

    // add min and max series if not null
    if(stationData.minvalue != null){
        chart[componentState.id].addSeries({
                name: 'Min',
                data: stationData.minvalue,
                color: '#656565',
                dashStyle: 'ShortDash',
                visible: true,
                zIndex: 1
            });
    }

    if(stationData.maxvalue != null){
        chart[componentState.id].addSeries({
            name: 'Max',
            data: stationData.maxvalue,
            color: '#b50435',
            dashStyle: 'ShortDash',
            visible: true,
            zIndex: 1
        });
    }

    // Highlight the selected point
    chart[componentState.id].series[0].data[parseInt(stationData.meanvalue.length / 2)].select(true);
    // at the end of the process hide preloader
    $('.preloader').hide();
}

/**
 * Function that initialize highcharts plugin for the righ-clicked cell
 *
 * @param {timestamp} datetime of the clicked cell
 * @param {object} result from database
 */
function createDetailedTable(datetime, result){
    // get active tab
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    var metadata = result.metadata;
    var data = result.table_data;
    // parse station object
    var stationData = JSON.parse(result.chart_data.station_data);

    var unit = componentState.conv ? metadata.parameter_unit_conv : metadata.parameter_unit;
    // build columns objects for tabulator initialization
    columns = [
        {
            title: "Data",
            field: "fulldate",
            frozen: true,
            formatter:function(cell, formatterParams, onRendered){
                //cell - the cell component
                //formatterParams - parameters set for the column
                //onRendered - function to call when the formatter has been rendered
                return getFormattedDateDT(cell.getValue(), 'basic_timeStartMin'); //global.js
            },
        },
        {
            field: 'value',
            headerSort: false,
            editor: 'number',
            editorParams: {
                // default
                step: Math.pow(10, -metadata.parameter_decimals),
                // additional
                id: metadata.stpr_id,
                tableid: metadata.stpr_table_id,
                table: metadata.station_fulltable,
                // conv: metadata.parameter_conv,
                unit: unit,
                decimals: metadata.parameter_decimals,
                insertGrant: metadata.station_insert,
                updateGrant: metadata.station_update,
                title: metadata.parameter_name+' ['+unit+']',
            },
            editable:false,
            formatterParams: {
                position: null
            },
            formatter:function(cell, formatterParams, onRendered){
                //cell - the cell component
                //formatterParams - parameters set for the column
                //onRendered - function to call when the formatter has been rendered
                var cellClasses  = cell.getRow().getData()["class"]; //from DB

                cellClasses = cellClasses.split(' ');

                cellClasses.forEach(function(cellClass) {
                    cell.getElement().classList.add(cellClass);
                });

                return cell.getValue(); //return the contents of the cell;
            },
            mutatorEditParams: {
                decimals: metadata.parameter_decimals
            },
            mutatorEdit : function(value, data, type, params, cell){
                var val = parseFloat(value);
                if(isNaN(val))
                    return '--';
                else
                    return val.toFixed(params.decimals);
            },
            cellClick:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled)
                    return;

                // reset selected cell
                for(var i = 0; i< selectedCells.length; i++){
                    selectedCells[i].getElement().classList.remove('cell-selected');
                    setClasses(selectedCells[i]);
                }
                selectedCells = [];

                // select cell
                cell.getElement().classList.add('cell-selected');
                setClasses(cell);
                selectedCells.push(cell);

                var date = moment.utc(cell.getRow().getCells()[0].getValue()).valueOf();
                // highlight point on chart
                chart[componentState.id].series[0].data.forEach(function(point, idx){
                    if (point.x == date ){
                        chart[componentState.id].series[0].data[idx].select(true);
                    }
                });

                // get cell validation history
                getValidationHistory(cell);
            },
            cellMouseMove:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled == true || $('.tabulator-editing').length > 0 )
                    return;

                var cellDate = cell.getRow().getCells()[0].getValue();
                // check if value date is before closure date (portal options)
                // - if true then select do nothing
                // - else continue
                if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                    return;
                }

                // if mouse's left button is pressed then set variables of the selection action
                if(isMouseDown){
                    // if first cell is empty then the current one is the first
                    if(firstCell == null){
                        // reset left-bottom box
                        $("#codes-detail").empty();
                        $("#changes-detail").empty();
                        firstCell = cell;
                    }
                    // store current cell as last one of the selection
                    var lastCell = cell;
                    // select cells
                    selectCells(firstCell, lastCell, firstCell.getTable());
                    // show button
                    $("#deselect-cells").show();
                }
            },
            cellDblClick:function(e, cell){
                // if clipboard is enabled then disable all other events
                if(clipboardEnabled)
                    return;

                var cellDate = cell.getRow().getCells()[0].getValue();
                // check if value date is before closure date (portal options)
                // - if true then select do nothing
                // - else continue
                if(closureDate && moment(cellDate).isBefore(moment(closureDate, 'DD/MM/YYYY'))){
                    return;
                }

                if(e.detail == 2){
                    // data not present in the database => insert action
                    if(cell.getValue() == '--'){
                        if( insert_grant && metadata.station_insert && !cell.getElement().classList.contains('tabulator-editing')){
                            cell.edit(true);
                        }
                    } // data present in the database => update action
                    else{
                        if( update_grant && metadata.station_update && !cell.getElement().classList.contains('tabulator-editing')){
                            cell.edit(true);
                        }
                    }
                }
            }
        }
    ];

    // if min max series not null then add columns
    if(stationData.minvalue != null){
        columns.push(
            {
                title: 'Min',
                field: 'min',
                headerSort: false
            }
        );
    }


    if(stationData.maxvalue != null){
        columns.push(
            {
                title: 'Max',
                field: 'max',
                headerSort: false
            }
        );
    }


    table[componentState.id] = new Tabulator('#multiview_grid_'+componentState.id, {
        // data: result.data,
        height:'100%',
        debugInvalidOptions: false,
        keybindings:{
            "copyToClipboard" : false
        },
        columns: columns,
        index:"fulldate",
        layout:"fitColumns", //fitColumns
        placeholder:"Nessun dato",
        rowFormatter:function(row){
            var fulldate = row.getData()["fulldate"];

            if(fulldate == datetime){
                row.getElement().classList.add('row-highlighted');
            }
        }
    });

    // at the end of table construction, add data and scroll view to right-clicked data
    table[componentState.id].on('tableBuilt', function(){
        table[componentState.id].setData(data);
        console.log(datetime);
        table[componentState.id].getRow(datetime).scrollTo();
        // at the end of the process hide preloader
        $('.preloader').hide();
    });

    table[componentState.id].on('cellEdited', function(cell){
        // take cares of "cancel" actions on data
        // restore precedent value and do nothing
        if(cell.getValue() == '--'){
            cell.restoreOldValue();
            cell.clearEdited();
            cell.getElement().classList.remove('tabulator-editing');
            return;
        }
        // if cell has been edited then build an object to be sent to server
        if(cell.getValue() != cell.getOldValue() && cell.isEdited()){
            console.log("cellEdited");

            $("#undo-edit").show();
            var definition = cell.getColumn().getDefinition().editorParams;
            var cellElement = {
                table: definition.table,
                tableid : definition.tableid,
                stprid: definition.id,
                grant: ( cell.getOldValue() == '--' ? definition.insertGrant : definition.updateGrant ),
                date : cell.getRow().getCells()[0].getValue(),
                code : 1, //ricostruito
                value: cell.getValue(),
                oldvalue: cell.getOldValue(),
                dirty: 1,
                // conv : definition.conv,
                decimals: definition.decimals
            };
            // show preloader, waiting for the end of the process
            $('.preloader').show();
            // save into db changes applied by the event
            updateCells([cellElement]);
        }
        // disable editing for the current cell
        cell.clearEdited();
        cell.getElement().classList.remove('tabulator-editing');
    });
}
/////////////////////////////////////////////////////////////////////////
// END LOCAL FUNCTIONS

// GLOBAL FUNCTIONS
/////////////////////////////////////////////////////////////////////////
/**
 * Function that loads all data for the selected station in a given period
 *
 * @param {integer} st_id station id
 */
function loadStationData(st_id){
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_get_all_params_data_table',
        type: "post",
        dataType: "json",
        data: {
            dateFrom: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00') ,
            dateTo: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 23:59'),
            id: st_id,
            converted: validationOptions.general.convEnabled
        },
    })
    .done(function(result) {
        // check result
        // if OK and at least one parameter exists  then create table with retrieved data
        if(result.res == 'OK' && result.params.length > 0){

            station_grants = result.grants;
            console.log(result.title);

            centralContainer.getActiveContentItem().setTitle(result.title);
            // if user has update grant not only page but also for the station
            // then enable all functionalities otherwise disable them
            if(!update_grant || !station_grants.station_update){
                $('#validate-daily').prop('disabled', true);
                $('#reset-code').prop('disabled', true);
                $('#update-value-cells').prop('disabled', true);
                $('#val-clipboard').prop('disabled', true);
            }
            else{
                $('#validate-daily').prop('disabled', false);
                $('#reset-code').prop('disabled', false);
                $('#update-value-cells').prop('disabled', false);
                $('#val-clipboard').prop('disabled', false);
            }
            // initialize tabulator
            createTable(result);
        }
        else{
            // info message
            swal("Info", "La stazione non presenta dati", "info");
            // at the end of the process hide preloader
            $('.preloader').hide();
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}

/**
 * Function that loads all data for the selected parameter in a given period
 *
 * @param {integer} pr_id parameter id
 * @param {integer} gr_id validation group id
 */
function loadParameterData(pr_id, gr_id){
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_get_all_stations_data_table',
        type: "post",
        dataType: "json",
        data: {
            dateFrom: moment(dateFrom, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 00:00') ,
            dateTo: moment(dateTo, 'DD/MM/YYYY HH:mm').format('YYYY-MM-DD 23:59'),
            id: pr_id,
            grid: gr_id,
            converted: validationOptions.general.convEnabled
        },
    })
    .done(function(result) {
        // check result
        // if OK and at least one parameter exists  then create table with retrieved data
        if(result.res == 'OK' && result.params.length > 0){
            console.dir(result);

            centralContainer.getActiveContentItem().setTitle(result.title);
            station_grants = null;
            // if user has update grant on page
            // then enable all functionalities otherwise disable them
            if(!update_grant){
                $('#validate-daily').prop('disabled', true);
                $('#reset-code').prop('disabled', true);
                $('#update-value-cells').prop('disabled', true);
                $('#val-clipboard').prop('disabled', true);
            }
            else{
                $('#validate-daily').prop('disabled', false);
                $('#reset-code').prop('disabled', false);
                $('#update-value-cells').prop('disabled', false);
                $('#val-clipboard').prop('disabled', false);
            }

            // initialize tabulator
            createTable(result);
        }
        else{
            // info message
            swal("Info", "Non sono presenti dati per questo parametro", "info");
            // at the end of the process hide preloader
            $('.preloader').hide();
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}

/**
 * Function that set classes for a given cell
 *
 * @param {object} cell
 */
function setClasses(cell){

    // get cell position and retrieve classes from cell
    var position = cell.getColumn().getDefinition().formatterParams.position;
    var classField;
    if(position == null)
        classField = 'class';
    else
        classField = 'class_'+position;
    // set classes in hidden columns (used by the formatter functions) of the tabulator object
    cell.getRow().getData()[classField] = cell.getElement().classList.value;
}

/**
 * Function that build objects for the updated cells by a mathematical operation
 *
 * @param {string} operation
 */
function updateSelectedCellsByOperations(operation){
    var cellArray = [];
    var checkGrant = 0;
    // loop through all selected cells
    // for each cell modify value by a given operation and build the object to be sent to the server
    selectedCells.forEach(function(cell) {

        var decimals = cell.getColumn().getDefinition().editorParams.decimals;

        var value;
        // manage replacement case
        if(operation.indexOf('=') > -1){
            var newValue = parseFloat(operation.replace('=', ''));
            console.log(newValue);
            value = newValue;
        }
        else{
            var finalOperation = cell.getValue()+operation;
            value = parseFloat(eval(finalOperation).toFixed(decimals));
        }

        var definition = cell.getColumn().getDefinition().editorParams;
        var cellElement = {
            table: definition.table,
            tableid : definition.tableid,
            stprid: definition.id, // stprid
            grant: definition.updateGrant,
            date : cell.getRow().getCells()[0].getValue(),
            code : 1, // ricostruito
            value: value,
            oldvalue: cell.getValue(),
            dirty: 1,
            // conv : definition.conv,
            decimals: definition.decimals
        };
        // variable to control user grants
        checkGrant = checkGrant || definition.updateGrant;
        cellArray.push(cellElement);
    });

    // check user's grants
    // if false then show warning message and return from event
    if(!checkGrant){
        swal('Azione non consentita', 'Il tuo account non ha i permessi sufficienti per eseguire questa operazione sulla stazione selezionata!', 'warning');
        return false;
    }
    // show preloader, waiting for the end of the process
    $('.preloader').show();
    // save into db changes applied by the event
    updateCells(cellArray);
}

/**
 * Function that build objects for the updated cells by a mathematical operation
 *
 * @param {array} cellArray array of cells to be updated
 * @param {boolean} clipboardSave boolean that indicates if function has been called by a clipboard save
 */
function updateCells(cellArray, clipboardSave){
    // get active tab
    var activeTabElement = centralContainer.header.activeContentItem;
    var componentState = activeTabElement.config.componentState;

    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_put_cells',
        type: "post",
        dataType: "json",
        data: {
            converted: componentState.conv,
            cells: JSON.stringify(cellArray)
        }
    })
    .done(function(result) {
        // check result
        if(result){

            // in order to prevent error
            // check if it's a clipboardSave action
            // then do not format cells DOM elements and reload data instead
            if(clipboardSave != true){
                // loop through all selected cells
                // for each element take care of classes
                selectedCells.forEach(function(cell, index) {

                     //only if user has insert or edit permission
                    if( cellArray[index].grant == 1 ){
                        var value = cellArray[index].value;
                        var cellClass;
                        if(cellArray[index].code > 0)
                            cellClass = 'cell-valid';
                        else if(cellArray[index].code == -1 )
                            cellClass = 'cell-auto';
                        else if(cellArray[index].code == -2 || cellArray[index].code == -3)
                            cellClass = 'cell-auto-invalid';
                        else
                            cellClass = 'cell-invalid';

                        cell.setValue(value.toString(), false);
                        cell.getElement().classList.remove('cell-valid', 'cell-invalid', 'cell-auto', 'cell-auto-invalid', 'tabulator-editing');
                        // global variable setted by the portal admin
                        if(resetFVC){
                            cell.getElement().classList.remove('cell-checked-1', 'cell-checked-2', 'cell-checked-4', 'cell-checked-8');
                        }
                        cell.getElement().classList.add(cellClass);
                        cell.getElement().classList.add('cell-modified');
                        // set classes
                        setClasses(cell);
                    }
                });
                // reset all selected cells - validazione_setting.js
                $("#deselect-cells").trigger("click");
            }
            else{
                // reload data - validazione_setting.js
                $('#update-data').trigger('click');
            }
        }
        else{
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        }

        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}

/**
 * Function that update cells final validity code to 1
 *
 * @param {timestamp} from start date
 * @param {timestamp} to end date
 * @param {array} cellArray array of cells to be updated
 */
function checkCells(from, to, cellArray){
    // show preloader, waiting for the end of the process
    $('.preloader').show();
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_put_check_cells',
        type: "post",
        dataType: "json",
        data: {
            from: from,
            to: to,
            cells: JSON.stringify(cellArray)
        }
    })
    .done(function(result) {
        // check result
        // - if true then refresh layout
        // - else error message
        if(result){
            // refresh jstree
            $('#station-json').jstree(true).refresh_node("9999");
            // reload data - validazione_setting.js
            $("#update-data").trigger("click");
            // success message
            swal("Successo!", "Dati validati con successo. Aggiornamento dei dati in corso...", "success");
        }
        else{
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        }
        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}

/**
 * Function that resets validity codes for a given array of cells
 *
 * @param {array} cellArray array of cells to be updated
 */
function resetCellsCode(cellArray){
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_put_reset_cells',
        type: "post",
        dataType: "json",
        data: {
            cells: JSON.stringify(cellArray)
        }
    })
    .done(function(result) {
        // check result
        // - if true then reset classes of the selected cells
        // - else show error message
        if(result){
            // lopp through all selected cells
            // for each cell take care of classes
            selectedCells.forEach(function(cell, index) {
                // only if user has editing permission
                if(cellArray[index].grant == 1){
                    var cellClass;

                    cell.getElement().classList.remove('cell-valid', 'cell-invalid', 'cell-auto', 'cell-auto-invalid');
                    cell.getElement().classList.add('cell-default');
                    cell.getElement().classList.add('cell-modified');
                    // update classes
                    setClasses(cell);
                }
            });
            // reset all selected cells - validazione_setting.js
            $("#deselect-cells").trigger("click");
        }
        else{
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        }
        // at the end of the process hide preloader
        $('.preloader').hide();
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante l'aggiornamento dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}
/////////////////////////////////////////////////////////////////////////
// END GLOBAL FUNCTIONS

