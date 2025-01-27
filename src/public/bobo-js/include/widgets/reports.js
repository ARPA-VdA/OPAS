// Document ready
$(document).ready(function() {
    loadReports();

    /**
     * Function that retrieves last reports (calibrations and maintenances) created by portal users.
     * No args needed
     */
    function loadReports(){
        // widget preloader
        // show preloader, waiting for the end of the process
        $('#preloader-reports').show();
        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_last_reports',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // console.dir(result);
            var reports = result.reports;
            console.dir(reports);

            // clear report table
            $('#reports-tbl').empty();

            // variable for dynamically build the html
            var html= '';

            // check if the list of reports is larger than 0
            if( reports.length > 0 ){

                // for each report create a row to attach to the main table
                $.each(reports, function(index, value) {
                    html +='<tr class="tbl-top">';
                    html +='    <td class="bobo-nowrap operators" rowspan="2">';
                    html +='        <img src="'+value.user_avatar_thumb+'">';
                    html +='    </td>';
                    var root = '';
                    if(value.report_type == "Manutenzione"){
                        root = '/rep_qa_manutenzioni/'+value.id;
                    }else{
                        root = '/rep_qa_tarature/'+value.id;
                    }
                    html +='    <td><strong>'+value.user_fullname+' - <a href="'+root+'" target="_blank">'+value.report_type+'</a> in:</strong> '+value.station_name+'</td>';
                    html +='    <td class="text-info text-right">'+value.report_ts_formatted+'</td>';
                    html +='</tr>';
                    html +='<tr class="tbl-bottom">';
                    html +='    <td colspan="2">'+value.report_desc+'</td>';
                    html +='</tr>';
                });
                // append result to table
                $('#reports-tbl').append(html);
            }
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-reports').hide();

            // id: 43
            // report_desc: "<strong>478540 - Tecora SENTINEL PM - Sentinel:</strong> Carico filtri<br><strong>478540 - Tecora SENTINEL PM - Sentinel:</strong> Prelievo filtri<br><strong>Note:</strong> --"
            // report_diff: "13 days 19:45:24.111932"
            // report_diff_formatted: "13gg fa"
            // report_fulldate: "2022-02-23 15:45:00"
            // report_type: "Manutenzione"
            // station_name: "Parco Santa Chiara (TN)"
            // user_avatar_thumb: "/bobo-img/default/avatar/ava-admin.png"
            // user_fullname: "Elisa Malloci"

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei report", "error");
            // widget preloader
            // at the end of the process hide preloader
            $('#preloader-reports').hide();
        });
    }
});

