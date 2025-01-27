var funcRef;

/**
 * Document ready.
 */
$(document).ready(function() {

    // FIRST TAB
    /////////////////////////////////////////////////////////////////////////
{
    $('#tab-staz-data').hide();

    // variable for loadDataByStation function
    var dateTo = moment().add(-1, 'day').format('YYYY-MM-DD 23:00:00');
    var dateFrom = moment(dateTo).subtract(6, 'days').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#show-stats-date').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().add(-1, 'day').subtract(6, 'days'), moment().add(-1, 'day')],
            'Ultimo mese': [moment().add(-1, 'day').subtract(1, 'month'), moment().add(-1, 'day')],
            'Ultimo 2 mesi': [moment().add(-1, 'day').subtract(2, 'months'), moment().add(-1, 'day')],
            'Ultimo 6 mesi': [moment().add(-1, 'day').subtract(6, 'months'), moment().add(-1, 'day')],
            'Ultimo anno': [moment().add(-1, 'day').subtract(1, 'year'), moment().add(-1, 'day')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:00:00');
        // get selected station
        var stid = $('#show-stats-stations').val();
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);
    });

    $("#show-stats-provinces, #show-stats-networks").select2();
    $("#show-stats-stations" ).select2({
        matcher: searchGroupedSelect2
    });

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////
    /**
     * Load stations on province/network filter change.
     */
    $( "#show-stats-provinces, #show-stats-networks" ).on( "change", function(e) {
        e.preventDefault();

        $('#tab-staz-data').hide();
        $('#dynamic-staz-table tbody').empty();

        // if network change then reset province
        if($(this).attr('id') == 'show-stats-networks'){
            $("#show-stats-provinces").val(-1);
        }

        var province = parseInt($("#show-stats-provinces").val());
        var network = parseInt($("#show-stats-networks").val());

        // load list of stations
        loadStations(province, network);
    });

    /**
     * Station filter change event
     */
    $( "#show-stats-stations" ).on( "change", function() {

        var stid = $(this).val();
        // load station data
        loadDataByStation(dateFrom, dateTo, stid);
        // update content body title with the name of selected station
        var stat = $( "#show-stats-stations option:selected" ).text();

        $('#tab-staz-data .subtitle-tabbing strong').text(stat);
    });
    /////////////////////////////////////////////////////////////////////////
    // END CHANGE EVENTS

    // DOWNLOAD
    /////////////////////////////////////////////////////////////////////////
    $('#download-station').on("click",function(e){
        e.preventDefault();

        var stid = parseInt($('#show-stats-stations').val());

        if(stid == -1){
            swal('Attenzione', 'Selezionare almeno una stazione di cui effettuare il download. Impossibile proseguire!', 'warning');
            return;
        }

        $('.inner-preloader').show();

        // download url
        var url = "/stat_ana_validazione_get_csv_data";

        /*http://johnculviner.com/category/jquery-file-download/*/
        // GET per poter eseguire il download da smartphone
        $.fileDownload(url, {
            httpMethod: 'POST',
            data: {
                from: dateFrom,
                to: dateTo,
                stid: stid
            },
            successCallback: function(url) {

                // console.dir(result);
                console.log('csv scaricato ...');
                $('.inner-preloader').hide();

                swal("Perfetto!", "File CSV creato e scaricato con successo. Lo puoi trovare nella cartella dei downloads", "success");

            },
            failCallback: function(responseHtml, url, error) {

                console.log('il file csv non è stato creato oppure errore durante lo scarico.');
                $('.inner-preloader').hide();
                swal("Errore!", "Ops! Qualcosa è andato storto.", "error");
            }
        });

        console.log('End download');

        return false; //this is critical to stop the click event which will trigger a normal file download!
    });
    /////////////////////////////////////////////////////////////////////////
    // END DOWNLOAD

    /**
     * Select option -1 and load all stations.
     */
    $( "#show-stats-networks" ).trigger("change");
    loadLastDownload();
}

    // SECOND TAB
    /////////////////////////////////////////////////////////////////////////
{
    // variable for loadDataByStation function
    var dateToNet = moment().add(-1, 'day').format('YYYY-MM-DD 23:00:00');
    var dateFromNet = moment(dateToNet).subtract(6, 'days').format('YYYY-MM-DD');

    $('#show-stats-networks-all').select2();

    // Daterange picker
    $('#show-stats-date-all').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().add(-1, 'day').subtract(6, 'days'), moment().add(-1, 'day')],
            'Ultimo mese': [moment().add(-1, 'day').subtract(1, 'month'), moment().add(-1, 'day')],
            'Ultimo 2 mesi': [moment().add(-1, 'day').subtract(2, 'months'), moment().add(-1, 'day')],
            'Ultimo 6 mesi': [moment().add(-1, 'day').subtract(6, 'months'), moment().add(-1, 'day')],
            'Ultimo anno': [moment().add(-1, 'day').subtract(1, 'year'), moment().add(-1, 'day')],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFromNet = start.format('YYYY-MM-DD');
        dateToNet = end.format('YYYY-MM-DD 23:00:00');
    });

    // DOWNLOAD
    /////////////////////////////////////////////////////////////////////////
    $('#download-all-stations').on("click",function(e){
        e.preventDefault();

        var netid = parseInt($('#show-stats-networks-all').val());

        if(netid == -1){
            swal('Attenzione', 'Selezionare almeno una rete di cui effettuare il download. Impossibile proseguire!', 'warning');
            return;
        }

        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/stat_ana_validazione_get_network_csv_data',
            type: "post",
            dataType: "json",
            data: {
                from: dateFromNet,
                to: dateToNet,
                net: netid
            }
        })
        .done(function(result) {
            // check result
            // if 1 then show success message and start notifier process
            // else if -1 then process with same arguments already exists, show info message
            if(result == 1){
                swal({
                    title: "Richiesta inviata correttamente!",
                    text: "La tua richiesta è stata inviata correttamente. <br><strong>Riceverai una notifica</strong> quando il tuo CSV è <strong>pronto per essere scaricato</strong>.",
                    type: "info",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok, ho capito",
                    closeOnConfirm: true
                });
                startNotifier( notifierCallback );

            }
            else if(result == -1)
                swal({
                    title: "Attenzione",
                    text: "La richiesta di dati con i parametri selezionati è <strong>già in elaborazione</strong>: attenderne la conclusione per scaricare di dati!",
                    type: "warning",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok",
                    closeOnConfirm: true
                });

            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // show error message
            swal("Errore!", "Ops! Qualcosa è andato storto. Riprovare ad eseguire il download più tardi.", "error");
            $(".inner-preloader").hide();
        });
    });
    /////////////////////////////////////////////////////////////////////////
    // END DOWNLOAD
}

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
            url: '/stat_ana_validazione_get_stations',
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
                $('#show-stats-stations').empty();
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

                    $('#show-stats-provinces').empty();
                    $('#show-stats-provinces').append('<option value="-1">Seleziona provincia...</option>');
                    $('#show-stats-provinces').append(optsProv);
                    $('#show-stats-provinces').append('</optgroup>');

                    $('#show-stats-provinces').val(-1);
                }

                // append options and close last optgroup
                $('#show-stats-stations').append('<option value="-1">Seleziona stazione...</option>');
                $('#show-stats-stations').append(opts);
                $('#show-stats-stations').append('</optgroup>');

                $('#show-stats-stations').val(-1);
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
     * Function that retrieves the data of the calculated statistics of a given station of a given period.
     *
     * @param {integer} dateFrom Period start date.
     * @param {integer} dateTo Period end date.
     * @param {integer} stid Station ID.
     */
    function loadDataByStation(dateFrom, dateTo, stid){
        // reset all table elements (header, body and footer)
        $('#tab-staz-data').hide();
        $('#dynamic-staz-table tbody').empty();

        if(stid == -1)
            return;

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get statistics via an ajax call
        var jqxhr = $.ajax({
            url: '/stat_ana_validazione_get_validation_analysis',
            type: "post",
            dataType: "json",
            data:{
                from: dateFrom,
                to: dateTo,
                stid: stid
            }
        })
        .done(function(result) {

            console.dir(result);

            // check result
            // if OK then fill table with data
            // else show error message
            if(result.res == 'OK'){
                var dataRows = result.data;
                // check if at least one element exists
                if( dataRows.length > 0 ){
                    // variable for dynamically building the html
                    var html = '';
                    // loop through all elements
                    // for each row build a html tr to be added to the table
                    dataRows.forEach(function(el){

                        // parameter not active during the selected period
                        if(el.stats_obj == null)
                            return;

                        var statsObj = JSON.parse(el.stats_obj);
                        // {
                        //   "count_total": 191,
                        //   "count_valid": 189,
                        //   "count_missing": 1,
                        //   "expected_data": 192,
                        //   "count_not_valid": 2,
                        //   "count_valid_codes": [173,0,16,0,0],
                        //   "count_notvalid_codes": [0,0,0,0,0,0,2,0,0]
                        // }

                        // <td>0</td>
                        // <td class="font-bold">112</td>

                        html += '<tr>';
                        html += '    <th>'+el.param_name+'</th>';
                        html += '    <td>'+statsObj.expected_data+'</td>';
                        html += '    <td>'+statsObj.count_missing+'</td>';
                        statsObj.count_notvalid_codes.forEach(function(num){
                            html += '    <td>'+num+'</td>';
                        });
                        html += '    <td>'+statsObj.count_not_valid+'</td>';
                        statsObj.count_valid_codes.forEach(function(num){
                            html += '    <td>'+num+'</td>';
                        });
                        html += '    <td>'+statsObj.count_valid+'</td>';
                        html += '</tr>';
                    });

                    // append html
                    $('#dynamic-staz-table tbody').append(html);
                    // show table
                    $('#tab-staz-data').show();

                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that retrieves user csv downloads for network.
     * No args needed
     */
    function loadLastDownload(){
        console.log('loadLastDownload');

        // ajax call in order to retrieve all downloads (finished and pending)
        var jqxhr = $.ajax({
            url: '/stat_ana_validazione_get_downloads',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);
            // clear container
            $('.downloads-container').empty();

            var html = '';
            // check ajax result
            // if not null and array length greater than 0 then create a list with all requests of the current day
            // else show a default message
            if(result.download != null){

                html += '<div class="list-user-download">';

                var el = result.download;
                // for each request create a <li> element with all info selected by the user
                // var downloads = result.downloads;
                // downloads.forEach(function(el, idx){
                    html += '    <strong>Intervallo date:</strong> '+el.start_date+' - '+el.end_date+'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
                    html += '    <strong>Rete:</strong> '+el.network+'&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;';
                    if(el.download_link){
                        html += '    <a href="'+el.download_link+'" class="btn btn-sm btn-rounded btn-danger"><i class="fa-solid fa-download"></i> CSV tutte stazioni</a>';
                    }
                    else{
                        html += '    <a href="javascript:void(0)" class="btn btn-sm btn-primary btn-rounded btn-disabled">Elaborazione in corso...</a>';
                    }

                // });

                html += '</div>';
            }
            else{
                html += '<span class="download-none text-muted font-italic">Al momento non hai effettuato nessuno scarico dati oppure i tuoi CSV non sono ancora pronti.</span>';
            }

            // append html
            $('.downloads-container').append(html);

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei download", "error");
        });
    }

    funcRef = loadLastDownload;
});

// notifier callback called by the notifier routine
function notifierCallback(){

    funcRef();
}