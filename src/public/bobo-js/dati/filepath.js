/**
 * Document ready.
 */
$(document).ready(function() {

    $("#networks" ).select2();

    // datatable initialization
    var table = $('#filepath-table').DataTable({
        "dom": '<"row"<"col-6"l><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 50,
        lengthMenu: [[25, 50, 75, 100, -1], [25, 50, 75, 100, "Tutti"]],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: [ ],
        order: [[ 2, "desc" ]],
        columnDefs: [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { className: "bobo-nowrap", "targets": [ 2 ] }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }

    });

    // FILTERS
    /////////////////////////////////////////////////////////////////////////

    /**
     * Change event: network filter
     */
    $( "#networks" ).on( "change", function() {
        // get values
        const netid = $( "#networks" ).val();

        // load filtered files
        loadFilepath(netid);
        
        if (netid == -1){
            $('#change-net').text('Tutte le reti');
        }else{
            const text = $('#networks option:selected').text();
            $('#change-net').text(text);
        }

    });

    // select option -1 and load all stations and all files
    $( "#refresh" ).on( "click", function() {
        $( "#networks" ).trigger("change");
    });

    //  first load
    $( "#networks" ).trigger("change");

    // FUNCTIONS
    /////////////////////////////////////////////////////////////////////////

    /**
     * Function that retrieves the location of peripheral files for the selected network
     *
     * @param {numeric} network Selected network id.
     */
    function loadFilepath(network){

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // reset datatable - clear the fields
        if ( table )
            table.clear();

        // get files between "dateFrom" and "dateTo" by selected province and station (ajax call)
        var jqxhr = $.ajax({
            url: '/dat_filepath_get_files',
            type: "post",
            dataType: "json",
            data: {
                net : network
            },
        })
        .done(function(result) {
            console.dir(result);

            // variable that contains the files data
            var files = result.files;
            console.dir(files);

            // variable for dynamically build the html
            var html= '';

            // check if the list of files is larger than 0
            if( files.length > 0 ){

                $.each(files, function(index, value) {
                    html +='<tr>';
                    html +='    <td>'+value.file_name+'</td>';
                    html +='    <td>'+value.data_type_format+'</td>';
                    html +='    <td class="font-bold">'+value.file_date_format+'</td>';
                    html +='    <td>'+value.station_name+'</td>';
                    html +='    <td>'+value.file_location_format+'</td>';
                    html +='    <td></td>';
                    html +='</tr>';
                });

                // });

                // add rows to table and draw it
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

            } else {
                // empty table
                table.draw();
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei files", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        });

    }

});