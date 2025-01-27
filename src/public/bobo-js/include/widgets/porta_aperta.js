// Document ready
$(document).ready(function() {

    // GLOBAL VARIABLES
    var map;

    // variable for loadOpenDoorAlarms function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(1, 'days').format('YYYY-MM-DD');

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

        //on change event, get alarms within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');
        // reset map
        removeAllLayers(map);
        loadOpenDoorAlarms(dateFrom, dateTo);
    });

    // map initialization
    map = initMap('map',footer);
    // load all open door alarms
    loadOpenDoorAlarms(dateFrom, dateTo);

    /**
     * Function that retrieves the 'Open door' georeferenced alarms of a given period.
     *
     * @param {date} dateFrom Start period date.
     * @param {date} dateTo End period date.
     */
    function loadOpenDoorAlarms(dateFrom, dateTo){
        console.log('ajax');
        // ajax call
        var jqxhr = $.ajax({
            url: '/home_get_open_doors',
            type: "post",
            dataType: "json",
            data:{
                from: dateFrom,
                to: dateTo
            }
        })
        .done(function(result) {
            console.dir(result);
            doorsArray = result.doors;

            // check if result of ajax call is OK
            if( result.res == 'OK' ){

                // check if the list of alarms is larger than 0
                if ( doorsArray.length > 0 ){

                    // for each alarm add a georeferenced pin to the map
                    $.each(doorsArray, function(index, value) {
                        addMapPoint(value, value.marker_layer, map ); // openlayerFunctions.js
                    });

                    // zoom map to see all the alarms together
                    zoomToMarkers(map); // openlayerFunctions.js
                }
                else{
                    zoomToRegion(map, portal_region);
                }
            }
            else{
                // error message
                swal("Errore!", result.message, "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero degli allarmi", "error");

        });
    }
});
