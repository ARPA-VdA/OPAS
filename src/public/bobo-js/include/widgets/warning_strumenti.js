// Document ready
$(document).ready(function() {
    // GLOBAL VARIABLES
    var warningTable;

    /**
     * Change event: warning type selection
     */
    $('#warnings select').on('change', function(){

        var instrType = parseInt($(this).val());
        if(isNaN(instrType))
            // hide widget preloader
            $('#preloader-warnings').hide();
        else
            // load all warnings
            loadWarnings(instrType);

    });

    // when page is loaded, force the selection of the first option
    $('#warnings select option:first').prop('selected', true);
    $('#warnings select').trigger('change');

    /**
     * Function that retrieves all instrument warnings of a given type.
     *
     * @param {integer} type instrument type ID.
     */
    function loadWarnings(type){

        console.log('loadWarnings');
        // destroy datatable if exists
        if(warningTable){
            warningTable.destroy();
            warningTable = null;
        }
        // clear table
        $('#instrument-table tbody').empty();

        // widget preloader
        // show preloader, waiting for the end of the process
        $('#preloader-warnings').show();

        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_last_warnings',
            type: "post",
            dataType: "json",
            data: {
                type: type
            }
        })
        .done(function(result) {
            // variable for dynamically build the html
            var html = '';
            var warns = result.warns;

            // SWAM section
            if(type == 1){
                console.log('swam');
                // check if the list of swam warnings is larger than 0
                if( warns.length > 0 ){

                    // swam alarm counter
                    var counter = 0;

                    // for each report create a row to attach at the main table
                    $.each(warns, function(index, value) {
                        // check for warning id, in case of "stato campionamento" increment counter
                        // values: Stato campionamento 5040 | 5090 | 5140
                        if(value.sw_id == 5040)
                            counter++;
                        // build html body
                        html += '<tr '+value.sw_class+'>';
                        html += '    <td>'+value.sw_fulldate_formatted+'</td>';
                        html += '    <td>'+value.province_code+'</td>';
                        html += '    <td>'+value.station_name+' [linea '+value.sw_line+']</td>';
                        html += '    <td class="text-center">';
                        html += '        <span class="badge badge-orange">'+value.sw_num+'</span>';
                        html += '    </td>';
                        html += '</tr>';
                    });

                    // append result to table
                    $('#instrument-table tbody').append(html);

                    // if warns count greater than 10 then convert table into datatable
                    if(warns.length > 10){
                        warningTable = $('#instrument-table').DataTable({
                            // dom: "Bfrtip",
                            pageLength: 10,
                            pagingType: 'simple_numbers',
                            layout: {
                                bottomEnd: {
                                    paging: {
                                        buttons: 5,
                                        type: 'simple_numbers'
                                    }
                                }
                            },
                            // 'copy', 'csv', 'excel', 'pdf', 'print'
                            searching: false,
                            ordering: false,
                            lengthChange: false,
                            buttons: []
                        });
                    }
                    // table header (with warnings)
                    $('#warnings h5').html('<strong>FAI Swam:</strong> tot <strong>'+counter+'</strong> allarmi su <strong>'+warns.length+'</strong> warning nelle ultime 24h');
                }
                else{
                    // table header (no warnings)
                    $('#warnings h5').html('<strong>FAI Swam:</strong> nessun warning nelle ultime 24h');
                }
            }
            else{
                // TECORA section
                if(type == 2){
                    console.log('tecora');
                    // table header
                    $('#warnings h5').html('<strong>Tecora Skypost</strong> ultimi 10 warning');
                }
                // DERENDA section
                else if(type == 3){
                    console.log('derenda');
                    // table header
                    $('#warnings h5').html('<strong>COMDE Derenda</strong> ultimi 10 warning');
                }
                // ENVEA section
                else if(type == 4){
                    console.log('envea');
                    // table header
                    $('#warnings h5').html('<strong>Envea MP101M</strong> ultimi 10 warning');
                }
                // METONE section
                else if(type == 5){
                    console.log('met one');
                    // table header
                    $('#warnings h5').html('<strong>MetOne BC1054</strong> ultimi 10 warning');
                }
                // FIDAS section
                else if(type == 6){
                    console.log('fidas');
                    // table header
                    $('#warnings h5').html('<strong>Palas FIDAS200</strong> ultimi 10 warning');
                }
                // Teledyne API section
                else if(type == 7){
                    console.log('teledyne');
                    // table header
                    $('#warnings h5').html('<strong>Teledyne API</strong> ultimi 10 warning');
                }
                // DEFAULT section
                else{
                    // table header
                    $('#warnings h5').html('<strong>Strumento</strong> ultimi 10 warning');
                }
                // reset variable
                var html = '';
                // check if the list of warnings is larger than 0
                if( warns.length > 0 ){
                    $.each(warns, function(index, value) {

                        html += '<tr>';
                        html += '    <td>'+value.fulldate_formatted+'</td>';
                        html += '    <td>'+value.province_code+'</td>';
                        html += '    <td>'+value.station_name+'</td>';
                        html += '    <td class="text-center">';
                        html += '        <span class="badge badge-orange">'+value.num+'</span>';
                        html += '    </td>';
                        html += '</tr>';
                    });
                    // append result to table
                    $('#instrument-table tbody').append(html);
                }
            }

            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-warnings').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei warnings", "error");
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-warnings').hide();
        });
    }
});
