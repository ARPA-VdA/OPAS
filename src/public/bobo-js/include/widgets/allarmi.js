// Document ready.
$(document).ready(function() {
    // load alarms
    loadLastAlarms();

    /**
     * Function that retrieves the stations alarms of the last three days.
     */
    function loadLastAlarms(){
        // widget preloader
        // show preloader, waiting for the end of the process
        $('#preloader-alarms').show();
        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_last_alarms',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // console.dir(result);
            var alarms = result.alarms;
            console.dir(alarms);

            // variable for dynamically build the html
            var html = '';
            // check if the list of alarams is larger than 0
            if( alarms.length > 0 ){

                // for each alarm create a row to attach at the main table
                $.each(alarms, function(index, value) {
                    html += '<tr>';
                    html += '    <td>'+value.station_alarm_fulldate_formatted+'</td>';
                    html += '    <td>'+value.station_name+'</td>';
                    html += '    <td class="bobo-nowrap"><span class="badge '+value.alarm_color+'"><i class="'+value.alarm_icon+'"></i> '+value.alarm_label+'</span></td>';
                    html += '    <td><span class="ico-order">'+value.station_alarm_off+'</span>';
                    if ( value.station_alarm_off == 1)
                        html += '            <i class="icon-check text-info" data-toggle="tooltip" data-original-title="allarme rientrato"></i>';
                    else
                        html += '            <i class="icon-close text-danger" data-toggle="tooltip" data-original-title="allarme NON rientrato"></i>';
                    html += '    </td>';
                    html += '</tr>';
                });
                // append new content to table body
                $('#alarmst-table tbody').append(html);

                // check if there are more than 10 alarms then convert table into datatable
                if(alarms.length > 10){
                    $('#alarmst-table').DataTable({
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
                        buttons: [],
                        searching: false,
                        ordering: false,
                        lengthChange: false,
                        language: {
                            "url": "/bobo-js/italian.json"
                        }
                    });
                }
            }
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-alarms').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli allarmi", "error");
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-alarms').hide();
        });
    }
});