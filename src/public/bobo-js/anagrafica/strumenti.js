/**
 * Document ready
 */
$(document).ready(function() {

    ////////// -- PRIMO TAB: Tipologie strumenti -- //////////

    //datatable
    $('#instruments-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "pageLength": 25,
        "lengthMenu": [25, 50, 75, 100],
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 0, "asc" ]]
    });


    ////////// -- SECONDO TAB: Operazioni sugli strumenti -- //////////
    $('#hide-tbl').hide();

    // select2 initialization
    $("#instr-type" ).select2({
        placeholder: "Seleziona strumento...",
        // allowClear: true
    });

    //datatable
    var tableOpes = $('#operations-table').DataTable({
        "dom": '<"row"<"col-lg-6 col-sm-4"B><"col-lg-3 col-sm-4"l><"col-lg-3 col-sm-4 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        "pageLength": 20,
        "lengthMenu": [20, 50, 75, 100],
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    // filters change event
    $('#instr-type').on('change', function(e){
        var instr = $("#instr-type").val();
        // console.log("instr-type - change: "+instr);
        if(instr == -1){
            // console.log("instr-type - se è meno 1: "+instr)
            tableOpes.clear();
            // redraw it
            tableOpes.draw();
            $('#hide-tbl').hide();
            $('#tobe-selected').show();
            $('#tobe-selected').html('&nbsp;<strong>Seleziona uno strumento</strong> per vedere le <strong>operazioni</strong>&nbsp;&nbsp;<i class="fa-regular fa-arrow-turn-up" aria-hidden="true"></i>');
            return
        }
        // refresh list of operations
        loadOperations();
    });

    /**
     * Function that retrieves from server the list of all operations linked to a specific instrument typology
     * No args needed
     */
    function loadOperations(){
        var instr = $("#instr-type").val();

        // reset datatable
        if ( tableOpes )
            tableOpes.clear();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get reports created between "dateFrom" and "dateTo"
        var jqxhr = $.ajax({
            url: '/ang_strumenti_get_operations',
            type: "post",
            dataType: "json",
            data: {
                instr  : instr
            },
        })
        .done(function(result) {

            var operations = result.operations;

            // category_id: 1
            // category_name: "Analizzatore SO2"
            // freq_id: 1
            // frequency_db: "7 days"
            // frequency_desc: "Settimanale"
            // frequency_label: "7g"
            // in_op_id: 38
            // instr_type_fullname: null
            // instr_type_id: null
            // op_id: 12
            // operation_category_desc: "Strumento"
            // operation_description: "Controllo corretto funzionamento"

            // check if at least one element exists
            if( operations.length > 0 ){
                // variable for dinamically building the html
                var html= '';
                // loop through all elements
                // for each operation, build a html row to be added to the datable
                $.each(operations, function(index, value) {
                    html += '<tr>';
                    html += '    <td>'+value.op_id+'</td>';
                    html += '    <td class="font-bold">'+value.operation_description+'</td>';
                    html += '    <td>'+value.operation_category_desc+'</td>';
                    html += '    <td>'+value.frequency_desc+'</td>';
                    html += '    <td>'+value.frequency_label+'</td>';
                    html += '    <td></td>';
                    html += '</tr>';
                });

                // add rows to datatable by using html object
                tableOpes.rows.add($( html ));
                // redraw it
                tableOpes.draw();
                // adjust columns size
                tableOpes.columns.adjust();

                $('#hide-tbl').show();
                $('#tobe-selected').hide();
            } else {
                // redraw it
                tableOpes.draw();

                $('#hide-tbl').hide();
                $('#tobe-selected').show();
                $('#tobe-selected').html('Nessuna operazione legata a questo strumento, <strong>prova a selezionarne un altro!</strong>');
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei parametri", "error");
            // redraw it
            tableOpes.draw();
        });
    }
});


