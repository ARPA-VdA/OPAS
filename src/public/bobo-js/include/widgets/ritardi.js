// Document ready
$(document).ready(function() {

    // datatable
    $.fn.DataTable.ext.pager.numbers_length = 5;
    var table = $('#datast-table').DataTable({
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "pagingType": 'simple_numbers',
        "layout": {
            bottomEnd: {
                paging: {
                    buttons: 5,
                    type: 'simple_numbers'
                }
            }
        },
        "responsive": {
            details: {
                type: 'column',
                target: -1
            }
        },
        "ordering": false,
        "autoWidth": true,
        "buttons" : [
            {
                text: '<i class="fa-solid fa-filter"></i> Ultima sett.',
                className: 'btn btn-primary header-button refresh-last-week',
                attr: {
                    'data-toggle': 'tooltip',
                    'data-original-title': 'Stazioni attive o che hanno smesso di comunicare nel corso dell\'ultima settimana'
                }
            },
            {
                text: '<i class="fa-solid fa-arrows-rotate" aria-hidden="true"></i> Tutti',
                className: 'btn btn-default header-button refresh-all',
                attr: {
                    'data-toggle': 'tooltip',
                    'data-original-title': 'Tutte le stazioni'
                }
            },
        ],
        'columnDefs': [
            { responsivePriority: 1, className: 'control', targets: -1 },
            { responsivePriority: 1, targets: 0}, //
            { responsivePriority: 1, targets: 1, width:   '30%', }, //
            { responsivePriority: 3, width: '5px', targets: 2 }, //
            { responsivePriority: 1, targets: 3 }, // width:   '32%',
            { responsivePriority: 2, targets: 4 }, // width:   '18%',
            // { visible: flagVisibleNet, targets: 5 }
        ],
    });


    // load all delays
    loadDelays(1);

    $('#hp-st-late').on('click', '.header-button', function(e){
        e.preventDefault();

        let range;
        if( $(this).hasClass('refresh-all') )
            range = -1;
        else
            range = 1;

        $('.header-button').toggleClass('btn-default btn-primary');
        loadDelays(range);
    });

    /**
     * Function that retrieves the stations that are in delay.
     *
     * @param {integer} range: extraction date range
     */
    function loadDelays(range){
        console.log('loadDelays');

        // reset datatable
        if ( table )
            table.clear();

        // widget preloader
        // show preloader, waiting for the end of the process
        $('#preloader-delays').show();
        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_delays',
            type: "post",
            dataType: "json",
            data: {
                range: range
            }
        })
        .done(function(result) {
            // console.dir(result);
            var delays = result.delays;
            // console.log('delaysssss');
            // console.dir(delays);

            // variable for dynamically build the html
            var html = '';
            // check if the list of delays is larger than 0
            if( delays.length > 0 ){

                // for each delay create a row to attach at the main table
                $.each(delays, function(index, value) {
                    html += '<tr data-id="'+value.station_id+'" class="'+value.station_last_update_class+'">';
                    var home;
                    switch(value.station_last_update_class) {
                        case "late":
                            home = "text-danger";
                            break;
                        case "almost-late":
                            home = "text-primary";
                            break;
                        default:
                            home = "text-muted";
                    }
                    html += '    <td><a class="' + home + '" href="/cnf_stazioni/' + value.station_id + '" target="_blank" data-toggle="tooltip" data-original-title="Vai all\'anagrafica"><i class="fa-regular fa-house-chimney-window"></i></a></td>';
                    html += '    <td class="all"> ' + value.station_name + '</td>';
                    html += '    <td>'+value.province_code+'</td>';
                    html += '    <td class="bobo-nowrap"><span class="txt-'+value.station_last_update_class+'"><i class="mdi mdi-alarm"></i> '+value.station_last_update_formatted+'</span></td>';
                    html += '    <td>'+value.station_last_update_text+'</td>';
                    html += '    <td class="bobo-nowrap">'+value.network_name+'</td>';
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


                // set visibility of network column
                var flagVisibleNet = ( delays[0].network_visible === 1 );
                table.column(5).visible(flagVisibleNet);

                var timer = moment.utc().format('HH:00');
                console.log(timer);
                $('#utc-time').text('ore '+timer);

            }
            else {
                table.draw();
            }

            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-delays').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei ritardi", "error");
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-delays').hide();
        });
    }
});

