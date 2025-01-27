/**
* Document ready
*/
$(document).ready(function() {
    // GLOBAL VARIABLE
    var table;
    var arrayStations;

    // initialize global bootstrap toggle
    $('#multi-notify input').bootstrapToggle();
    $('#multi-notify').hide();

    //datatable
    table = new DataTable('#stations-notify', {
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "layout": {
            bottomEnd: {
                paging: {
                    boundaryNumbers: true
                }
            }
        },
        // // 'copy', 'csv', 'excel', 'pdf', 'print'
        "lengthMenu": [[10, 25, 50, -1], [10, 25, 50, "Tutte"]],
        "pageLength": 25,
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "columnDefs": [
            {
                orderable: false,
                className: 'dtr-control',
                targets: -1
            },
            {
                orderable: false,
                render: DataTable.render.select(),
                targets:   0
            }
        ],
        "responsive": {
            details: {
                type: 'column',
                target: -1
            }
        },
        "select": {
            style:    'multi',
            selector: 'td:first-child',
            headerCheckbox: 'select-page'
        },
        "order": [[1, "asc"]]

    });


    /**
     * Select and deselect row: datatable events
     */
    $('#stations-notify').on('select.dt deselect.dt', function(){
        var rows;

        setTimeout(function(){
            // get the number of all selected row
            rows = table.rows( { page:'current', selected: true } ).count();

            // if row equal to 0 then hide row with total bootstrapToggle
            // otherwise get the boolean AND result of all selected rows and set total bootstrapToggle
            if (rows == 0){
                $('#multi-notify').hide('slow');
            }
            else{
                var emailTotal = true;
                var telegramTotal = true;

                // loop through all selected rows
                // do boolean AND for email and telegram grants
                table.rows( { page:'current', selected: true } ).every(function() {
                    var row = this;

                    var stid = parseInt($(row.node()).data('id'));
                    if(!arrayStations[stid])
                        return;

                    emailTotal    = emailTotal && arrayStations[stid].email;
                    telegramTotal = telegramTotal && arrayStations[stid].telegram;
                });
                // destroy and re-initialize bootstrapToggle in order to not trigger change event
                $('#multi-notify').find(".email input").prop('checked', emailTotal ).bootstrapToggle('destroy').bootstrapToggle();
                $('#multi-notify').find(".telegram input").prop('checked', telegramTotal ).bootstrapToggle('destroy').bootstrapToggle();

                $('#multi-notify').show('slow');
            }
        }, 100);

    });

    /**
     * Change event on total bootstrapToggle
     */
    $( "#multi-notify" ).on( "change", ".mody-st", function() {

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get type and the new status of the change bootstrapToggle
        var type = $(this).data('notify');
        var status = $(this).prop('checked');

        // loop through all selected rows, get station id and save the new status in the global variable
        table.rows( { page:'current', selected: true } ).every(function() {
            var row = this;

            var stid = parseInt($(row.node()).data('id'));
            // if element doesn't exist skip to next loop
            if(!arrayStations[stid])
                return;

            arrayStations[stid][type] = status;
        });

        // send all changes to server
        updateStationsGrants(-1);
    });

    // first load of all stations grants
    loadStationsGrants();

    /**
     * Function that retreives the stations grants
     * No args needed
     */
    function loadStationsGrants(){

        // reset datatable
        if(table)
            table.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/div_notifiche_get_stations_grants',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            // check result
            // if OK then build rows and append them to datatable
            if(result.res == 'OK'){

                var stations = result.stations;

                // check if at least one element exists
                if(stations && stations.length > 0){
                    // variable for dinamically building the html
                    var html= '';
                    // reset global variable
                    arrayStations = [];
                    // loop through all elements
                    // for each element, build a html row to be added to the datable
                    $.each(stations, function(index, el) {

                        html += '<tr data-id="'+el.station_id+'">';
                        html += '    <td></td>';
                        html += '    <td>'+el.station_id+'</td>';
                        html += '    <td class="font-bold font-italic">'+el.station_name+'</td>';
                        html += '    <td>'+el.st_network_desc+'</td>';
                        html += '    <td>'+el.province_code+'</td>';
                        html += '    <td class="email"><span class="nodisplay">'+el.station_email+'</span><input type="checkbox" class="mody-st" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_email+'></td>';
                        html += '    <td class="telegram"><span class="nodisplay">'+el.station_telegram+'</span><input type="checkbox" class="mody-st" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android" '+el.station_telegram+'></td>';
                        html += '    <td></td>';
                        html += '</tr>';

                        // initialize element of the global variable
                        arrayStations[el.station_id] = {
                            email : ( el.station_email == 'checked' ? true : false ),
                            telegram : ( el.station_telegram == 'checked' ? true : false ),
                        };
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
                        // in order to find all checkbox elements
                        $(row.node())
                            .find('td input[type="checkbox"].mody-st')
                            .bootstrapToggle();
                    });

                    /**
                     * Change event on single row checkbox
                     */
                    $( "#stations-notify" ).on( "change", ".mody-st", function() {
                        // get station id stored in the row
                        var myRow = $(this).parent().parent().parent();
                        var stid = myRow.data("id");

                        console.log(stid);
                        // get checked property for email and telegram notifications
                        arrayStations[stid].email = myRow.find('.email input').prop('checked');
                        arrayStations[stid].telegram = myRow.find('.telegram input').prop('checked');
                        // send new status to server
                        updateStationsGrants(stid);
                    });
                }
                else{
                    // redraw it
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();


        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        });
    }

    /**
     * Function that updates the permissions of all the selected stations or just the modified one
     *
     * @param {integer} stid Station ID; if not provided: all stations.
     */
    function updateStationsGrants(stid){

        var grantsObjArray = [];
        // check stid argument
        // if -1 then more than 1 row has been changed (all the selected ones)
        // otherwise update of a single station
        if(stid == -1){
            // loop through all selected rows
            table.rows( { page:'current', selected: true } ).every(function() {
                var row = this;
                // for each station build an object to be sent to server side
                var stid = parseInt($(row.node()).data('id'));
                // if station does not exist then skip to the next row
                if(!arrayStations[stid])
                    return;

                var grantsObj = {
                    stid : stid,
                    email: arrayStations[stid].email,
                    telegram: arrayStations[stid].telegram
                };

                grantsObjArray.push(grantsObj);
            });
        }
        else{
            // build the single object for the modified station
            var grantsObj = {
                stid : stid,
                email: arrayStations[stid].email,
                telegram: arrayStations[stid].telegram
            };

            grantsObjArray.push(grantsObj);
        }

        // update stations via an ajax call
        var jqxhr = $.ajax({
            url: '/div_notifiche_put_grants',
            type: "post",
            dataType: "json",
            data: {
                grants: JSON.stringify(grantsObjArray)
            },
        })
        .done(function(result) {

            // if result not true or is undefined then show error message
            // otherwise success
            if(! result){
                // error message
               swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
            }
            else{
                // if more then one station has been modified then update all rows and reset selection
                if(stid == -1){
                    // loop through all selected rows
                    table.rows( { page:'current', selected: true } ).every(function() {
                        var row = this;
                        rowEl = $(row.node());

                        // get information for current row
                        var stid = rowEl.data("id");
                        // destroy and re-initialize bootstrapToggle in order to not trigger change event
                        rowEl.find(".email input").prop('checked', arrayStations[stid].email ).bootstrapToggle('destroy').bootstrapToggle();
                        rowEl.find(".telegram input").prop('checked', arrayStations[stid].telegram ).bootstrapToggle('destroy').bootstrapToggle();
                        // deselect current row
                        // row.deselect();
                    });

                    // hack to prevent select-page bug (all rows are selected)
                    table.rows( { selected: true } ).deselect();
                }
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento dei permessi", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }
});