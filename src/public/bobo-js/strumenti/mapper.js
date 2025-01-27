/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var stationsArray = [];
    var chart = [];
    var windChart = [];
    var chartRT = [];

    var map;
    var mapZoom;

    // resize map when changing tab
    $('.nav').on('click', '.nav-item', function(e){
        e.preventDefault();

        if($(this).attr('id') == 'tab-map'){
            setTimeout(function(){
                map.updateSize();
                map.getView().setZoom(mapZoom);
            }, 10);
        }
    });

    // Initialize select2
    $("#stations").select2({
        placeholder: " Cerca stazioni...",
        allowClear: true,
        matcher: searchGroupedSelect2
    });

    // initialize map with global function
    map = initMap('map',footer);

    $("#provinces").select2();

    // FILTERS
    ////////////////////////////////////////////////////////////
    // filter provinces change event
    $( "#provinces" ).on( "change", function() {
        var prid = $(this).val();
        // empty stations and trigger change
        $("#stations").val([]);
        $("#stations").trigger('change');

        // reload stations linked to selected province
        fillStations(prid);
    });

    // click event on update map button
    $('#update-map').on('click', function(e){
        e.preventDefault();

        // manage popup
        map.dispatchEvent({
            type: 'click',
            pixel: [0, 0],
        });

        // get values
        var stationsIds = [];
        var prid = parseInt($('#provinces').val());
        var stationsSel = $("#stations").select2('data');

        // console.log(prid);
        // console.log(stationsSel.length);

        // check if at least one province or one station has been selected
        // otherwise reset map
        if(prid == -1 && stationsSel.length == 0){
            resetMap();
        }
        else{
            // if only the province has been selected
            // then push all linked stations id in the array variable
            // else push only selected ones
            if(prid != -1 && stationsSel.length == 0){
                // loop through all stations
                // for each station add its id to array
                $("#stations option").each(function(index, opt){
                    stationsIds.push(parseInt(opt.value));
                });
            }
            else{
                $.each(stationsSel, function(index, value) {
                    // add station id to array
                    stationsIds.push(parseInt(value.id));
                });
            }

            // filter stations using station id array build before
            filterStationsByStid(stationsIds);
        }
    });

    // click event on reset map button
    $('#reset-map').on('click', function(e){
        e.preventDefault();

        // manage popup, remove it
        map.dispatchEvent({
            type: 'click',
            pixel: [0, 0],
        });

        // reset provinces filter
        $('#provinces').val(-1).trigger('change');

        // reset stations filter
        $("#stations").val([]);
        $("#stations").trigger('change');

        // reset map
        resetMap();
    });
    ////////////////////////////////////////////////////////////
    // END FILTERS

    // LEGEND EVENTS
    ////////////////////////////////////////////////////////////
    // click event on legend above the map
    $("#legend-map").on("click", "a", function(e){
        e.preventDefault();

        // get layer name
        var layerName = $(this).data("name");
        // check if it is the "reset all" button
        // otherwise it is a nomal layer
        if(layerName == 'reset-all'){
            // if it has class toggle-active then it's a "disable all" action
            // else it's a "enable all" action
            if( $(this).hasClass("toggle-active") ){
                // loop through all layers except the "reset all" one
                $('#legend-map a[data-name != "reset-all"]').each(function(){
                    // if layer is active then disable it
                    if( $(this).hasClass("layer-active") ){
                        // get layer name
                        var otherLayerName = $(this).data("name");
                        console.log('Disattivo: '+otherLayerName);

                        // find it in the openlayer legend menu and trigger click
                        $('.ol-layerswitcher-popup li').filter(
                            function (){
                                return $( this ).text() === otherLayerName;
                            }
                        ).trigger('click');
                    }
                });
                // at the end of the process, modify icon and text of reset-all button
                $(this).find('em').html('<i class="mdi mdi-checkbox-marked-circle" style=""></i> Seleziona tutti');
            }
            else{
                // loop through all layers except the "reset all" one
                $('#legend-map a[data-name != "reset-all"]').each(function(){
                    // if layer is NOT active then enable it
                    if( ! $(this).hasClass("layer-active") ){
                        // get layer name
                        var otherLayerName = $(this).data("name");

                        // find it in the openlayer legend menu and trigger click
                        $('.ol-layerswitcher-popup li').filter(
                            function (){
                                return $( this ).text() === otherLayerName;
                            }
                        ).trigger('click');
                    }
                });
                // at the end of the process, modify icon and text of reset-all button
                $(this).find('em').html('<i class="mdi mdi-close-octagon" style=""></i> Deseleziona tutti');
            }

            // add/remove class toggle-active
            $(this).toggleClass("toggle-active");
        }
        else{
            // find it in the openlayer legend menu and trigger click
            $('.ol-layerswitcher-popup li').filter(
                function (){
                    return $( this ).text() === layerName;
                }
            ).trigger('click');
        }
    });

    // click event on legend inside the map
    $("#map").on("click", ".ol-layerswitcher-popup li", function(e){
        // trigger a click event on map (coordinates 0,0) in order to reset popup
        map.dispatchEvent({
            type: 'click',
            pixel: [0, 0],
        });

        // get layer name
        var layerName = $(this).text();
        // get legend option element and retrieve its classes
        var element = $('#legend-map a[data-name="'+layerName+'"]');
        var myClass = element.attr("class");
        // if attribute class is empty then it's a "enable layer" action
        // else it's a "disable layer" action
        if(myClass == ""){
            // add class active and modify icon
            element.addClass("layer-active");
            element.find("i").removeClass("mdi-checkbox-blank-circle-outline");
            element.find("i").addClass("mdi-checkbox-blank-circle");
        }else{
            // eremove class active and modify icon
            element.removeClass("layer-active");
            element.find("i").addClass("mdi-checkbox-blank-circle-outline");
            element.find("i").removeClass("mdi-checkbox-blank-circle");
        }

        var newBound = null;
        // loop through all layers and calculate the new extent's bounds
        $('#legend-map a[data-name != "reset-all"]').each(function(){
            // consider only active layers
            if( $(this).hasClass("layer-active") ){
                // get layers by name
                var otherLayerName = $(this).data("name");
                var layer = getLayerByName(otherLayerName, map); // openlayerFunctions.js

                // get layer extent and update the stored one
                var myExtent = layer.getSource().getExtent();
                if(newBound == null)
                    newBound = myExtent;
                else
                    ol.extent.extend(newBound, myExtent);
            }
        });

        // if new bounds not null then fit map view
        if(newBound != null ){
            map.getView().fit(newBound, {
                size: map.getSize(),
                maxZoom: 18,
                padding: [30, 30, 30, 30]
            });
        }
        else{
            // TODO da modificare: zoom sulla regione di riferimento, se non specificata sull'Italia
            var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
            boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

            map.getView().fit(boundingExtent, map.getSize());
        }
    });
    ////////////////////////////////////////////////////////////
    // END LEGEND EVENTS

    // POPUP EVENTS
    ////////////////////////////////////////////////////////////
    // open tab 'ANAGRAFICA'
    $('#popup-content').on('click', '.show_ana', function(e){
        e.preventDefault();

        // retrieve station id stored in the html element
        var id = parseInt($(this).data("id"));
        var el_name = $(this).parent().parent().children("h4").text();

        // check if the station's detail is already open
        if( $('#ana_'+id).length ) {
            console.log('The tab is already open');
            $('.customtab a[href="#ana_'+ id +'"]').tab('show');
            return;
        }

        // store zoom
        mapZoom = map.getView().getZoom();
        // ajax call
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/str_map_get_info_station',
            type: "post",
            dataType: "json",
            data: {
                id: id
            },
        })
        .done(function(result) {
            console.dir(result);

            // get data
            var station = result.station;
            var image = result.image;

            // create nav-link
            var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#ana_'+id+'" role="tab"><span class="hidden-sm-up"><i class="fas fa-cabinet-filing"></i></span> <span class="hidden-xs-down"><strong>A</strong>: '+el_name+'</span>&nbsp&nbsp<i class="fa fa-times close_tab text-danger" data-close="ana_'+id+'"></i></a> </li>';

            // append new content to tabs list
            $('.nav-tabs').append(html);

            // create html detail
            html  ='<div class="tab-pane p-20" id="ana_'+id+'" role="tabpanel">\n';
            html +='    <div class="form-body panel-element-view">\n';
            html +='            <h4 class="box-title">Anagrafica - <strong>Staz. '+station.station_name+'</strong> ('+station.province_name+')</h4>\n';
            html +='        <div class="row">\n';

            html +='            <div class="col-lg-4 col-md-3">\n';
            html +='                    <img alt="image" class="img-responsive" src="'+image+'">\n';
            html +='            </div>\n';
            html +='            <div class="col-lg-8 col-md-9 data-stations">\n';
            html +='                <div class="row">\n';
            html +='                    <div class="col-lg-12 col-md-12 table-responsive">\n';
            html +='                        <table class="table table-striped">\n';
            html +='                            <thead>\n';
            html +='                                <tr>\n';
            html +='                                    <th class="intest">Proprietà</th>\n';
            html +='                                    <th>Valore</th>\n';
            html +='                                    <th class="intest">Proprietà</th>\n';
            html +='                                    <th>Valore</th>\n';
            html +='                                </tr>\n';
            html +='                            </thead>\n';
            html +='                            <tbody>\n';
            html +='                                <tr><td class="intest">Id</td><td>'+station.station_id+'</td>\n';
            html +='                                    <td class="intest">Attivo</td><td>'+station.station_active+'</td></tr>\n';
            html +='                                <tr><td class="intest">Nome</td><td>'+station.station_name+'</td>\n';
            html +='                                    <td class="intest">Nome esteso</td><td>'+station.station_longname+'</td></tr>\n';
            html +='                                <tr><td class="intest">Schema</td><td>'+station.station_schema+'</td>\n';
            html +='                                    <td class="intest">Tabella</td><td>'+station.station_table+'</td></tr>\n';
            html +='                                <tr><td class="intest">Tipologia</td><td>'+station.station_typology_desc+'</td>\n';
            html +='                                    <td class="intest">Data attivazione</td><td>'+station.station_startup_date+'</td></tr>\n';
            html +='                                <tr><td class="intest">Descrizione</td><td>'+station.station_roaming_type_desc+'</td>\n';
            html +='                                    <td class="intest"></td><td></td></tr>\n';
            html +='                                <tr><td class="intest">&nbsp</td><td>&nbsp</td>\n';
            html +='                                    <td class="intest">&nbsp</td><td>&nbsp</td></tr>\n';
            html +='                                <tr><td class="intest">Località</td><td>'+station.station_locality+'</td>\n';
            html +='                                    <td class="intest">Zona</td><td>'+station.station_zone+'</td></tr>\n';
            html +='                                <tr><td class="intest">Bacino</td><td>'+station.station_basin+'</td>\n';
            html +='                                    <td class="intest">Comunità</td><td>'+station.station_community+'</td></tr>\n';
            html +='                                <tr><td class="intest">Comune</td><td>'+station.mu_name+'</td>\n';
            html +='                                    <td class="intest">Provincia</td><td>'+station.province_name+'</td></tr>\n';
            html +='                                <tr><td class="intest">Regione</td><td>'+station.region_name+'</td>\n';
            html +='                                    <td class="intest">Rete</td><td>'+station.station_network_type_desc+'</td></tr>\n';
            html +='                                <tr><td class="intest">Lat WGS84</td><td>'+station.station_lat_wgs84+'</td>\n';
            html +='                                    <td class="intest">Lon WGS84</td><td>'+station.station_lon_wgs84+'</td></tr>\n';
            html +='                                <tr><td class="intest">UTM N°</td><td>'+station.station_north_utm+'</td>\n';
            html +='                                    <td class="intest">UTM E°</td><td>'+station.station_east_utm+'</td></tr>\n';
            html +='                                <tr><td class="intest">Quota</td><td>'+station.station_altitude+'</td>\n';
            html +='                                    </tr>\n';
            html +='                                <tr><td class="intest">Note</td><td>'+station.station_note+'</td>\n';
            html +='                                    <td class="intest"></td><td></td></tr>\n';
            html +='                            <tbody>\n';
            html +='                        </table>\n';
            html +='                    </div>\n';

            // html +='                    <div class="col-lg-6 col-md-12">\n';
            // html +='                        <p><strong>Id</strong>: '+station.station_id+'</p>\n';
            // html +='                        <p><strong>Nome</strong>: '+station.station_name+'</p>\n';
            // html +='                        <p><strong>Nome esteso</strong>: '+station.station_longname+'</p>\n';
            // html +='                        <p><strong>Schema</strong>: '+station.station_schema+'</p>\n';
            // html +='                        <p><strong>Tabella</strong>: '+station.station_table+'</p>\n';
            // html +='                        <p><strong>Attivo</strong>: '+station.station_active+'</p>\n';
            // html +='                        <p><strong>Note</strong>: '+station.station_note+'</p>\n';
            // html +='                        <p><strong>Data attivazione</strong>: '+station.station_startup_date+'</p>\n';
            // html +='                    </div>\n';
            // html +='                    <div class="col-lg-6 col-md-12">\n';
            // html +='                        <p><strong>Località</strong>: '+station.station_locality+'</p>\n';
            // html +='                        <p><strong>Zona</strong>: '+station.station_zone+'</p>\n';
            // html +='                        <p><strong>Bacino</strong>: '+station.station_basin+'</p>\n';
            // html +='                        <p><strong>Comunità</strong>: '+station.station_community+'</p>\n';
            // html +='                        <p><strong>Comune</strong>: '+station.mu_name+'</p>\n';
            // html +='                        <p><strong>Provincia</strong>: '+station.province_name+'</p>\n';
            // html +='                        <p><strong>Regione</strong>: '+station.region_name+'</p>\n';
            // html +='                        <p><strong>Tipologia</strong>: '+station.station_typology_desc+'</p>\n';
            // html +='                    </div>\n';
            // html +='                    <div class="col-lg-6 col-md-12">\n';
            // html +='                        <p><strong>UTM N°</strong>: '+station.station_north_utm+'</p>\n';
            // html +='                        <p><strong>UTM E°</strong>: '+station.station_east_utm+'</p>\n';
            // html +='                        <p><strong>Quota</strong>: '+station.station_altitude+'</p>\n';
            // html +='                        <p><strong>Lat WGS84</strong>: '+station.station_lat_wgs84+'</p>\n';
            // html +='                        <p><strong>Lon WGS84</strong>: '+station.station_lon_wgs84+'</p>\n';
            // html +='                        <p><strong>Rete</strong>: '+station.station_network_type_desc+'</p>\n';
            // html +='                        <p><strong>Descrizione</strong>: '+station.station_roaming_type_desc+'</p>\n';
            // html +='                    </div>\n';

            html +='                </div>\n';
            html +='            </div>\n';

            html +='        </div>\n';
            html +='    </div>\n';
            html +='</div>\n';

            // append new content to tabs list
            $('.tab-content').append(html);

            // show new tab
            $('.customtab a[href="#ana_'+ id +'"]').tab('show');

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della stazione", "error");
        });
    });

    // open tab 'SINOTTICO'
    $('#popup-content').on('click', '.show_syn', function(e){
        e.preventDefault();

        console.log('click');

        // retrieve station id stored in the html element
        var id = parseInt($(this).data("id"));

        // check if the synoptic tab is already open
        if( $('#syn_'+id).length ) {
            console.log('The tab is already open');
            $('.customtab a[href="#syn_'+ id +'"]').tab('show');
            return;
        }

        // store zoom
        mapZoom = map.getView().getZoom();
        // load station synoptic tab
        loadSynoptic(id);
    });

    // open tab 'REAL TIME'
    $('#popup-content').on('click', '.show_rt', function(e){
        e.preventDefault();

        console.log('click');

        // retrieve station id stored in the html element
        var id = parseInt($(this).data("id"));

        // check if the realtime tab is already open
        if( $('#rt_'+id).length ) {
            console.log('The tab is already open');
            $('.customtab a[href="#rt_'+ id +'"]').tab('show');
            return;
        }

        // store zoom
        mapZoom = map.getView().getZoom();
        // load station realtime tab
        loadRealTime(id);
    });
    ////////////////////////////////////////////////////////////
    // END POPUP EVENTS

    // close tab
    $('.card-body').on('click', '.close_tab', function(e){
        e.preventDefault();

        var close = $(this).data("close");
        console.log(close);

        // remove the single tab (from list and group) and show the main tab
        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#map_container"]').tab('show');

            map.updateSize();
            map.getView().setZoom(mapZoom);
        }, 1);
    });

    // select option -1 and load all stations
    $( "#provinces" ).trigger("change");
    // load stations and fill the map
    loadStations();

    // check if variable stid arriving from the server is not null
    // then automatically load the station synoptic
    if(stid != null && stid != '')
        loadSynoptic(stid);

    // UTILITIES
    ////////////////////////////////////////////////////////////
    /**
     * Function that manages null values.
     *
     * @param {value} value Value to check and format
     * @returns Formatted value
     */
    function formatVal(value){
        return (value == null) ? 'N.A.' : value;
    }

    /**
     * Function that manages station alarm icons.
     *
     * @param {*} stationAlarm
     * @param {*} measureAlarm
     * @returns HTML code for alarm icon
     */
    function formatAlarmIcons(stationAlarm, measureAlarm){
        // console.log('formatAlarmIcons');
        var alarms = [];

        // if station alarm is defined and not equal to 0
        // then break down the value into powers of two to get the alarms
        // and push them into an array
        if(stationAlarm && stationAlarm != 0){
            for(counter = 10; counter >= 0; counter--){
                var binPower = Math.pow(2, counter);

                if( parseInt(stationAlarm / binPower) == 1 ){

                    stationAlarm = stationAlarm % binPower;
                    alarms.push(binPower);
                }
            }
        }

        // if measure alarm is defined and not equal to 0
        // then break down the value into powers of two to get the alarms
        // and push them into an array
        if(measureAlarm && measureAlarm != 0){
            for(counter = 10; counter >= 0; counter--){
                var binPower = Math.pow(2, counter);

                if( parseInt(measureAlarm / binPower) == 1 ){

                    measureAlarm = measureAlarm % binPower;
                    alarms.push(binPower);
                }
            }
        }

        // console.dir(alarms);

        // variable for dynamically build the html
        var icons = '';

        // loop through all alarms
        // for each of them build a different icon
        $.each(alarms, function(index, alarm){
            // --  alarm stazione
            // 1   SOFTWARE_ERROR          Errore generico software                                                    fas fa-desktop
            // 2   SYSTEM_RESTART          Riavvio del sistema                                                         fas fa-power-off
            // 4   LOW_DISK_SPACE          Spazio insufficiente su disco                                               far fa-disc-drive

            // --  code parametro
            // 32  MAINT_ORDINARY          manutenzione ordinaria                                                      fas fa-dolly
            // 64  MAINT_EXTRA_ORD         manutenzione straordinaria                                                  fas fa-dolly-flatbed
            // 16  CALIBRATION             misure valide acquisite durante verifica di taratura (almeno 75%)           fas fa-heart-rate
            // 256 INTRUMENT_ERROR         Errori Strumento                                                            fas fa-tools

            // switch case for alarm type
            switch (alarm) {
                case 1:
                    icons += '<i class="fas fa-desktop text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="errore generico software"></i>';
                break;
                case 2:
                    icons += '<i class="fas fa-power-off text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="riavvio del sistema"></i>';
                break;
                case 4:
                    icons += '<i class="far fa-disc-drive text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="spazio insufficiente su disco"></i>';
                break;
                case 16:
                    icons += '<i class="fas fa-heart-rate text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="misure valide acquisite durante verifica di taratura"></i>';
                break;
                case 32:
                    icons += '<i class="fas fa-dolly text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="manutenzione ordinaria"></i>';
                break;
                case 64:
                    icons += '<i class="fas fa-dolly-flatbed text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="manutenzione straordinaria"></i>';
                break;
                case 256:
                    icons += '<i class="fas fa-tools text-danger float-right m-l-5" data-toggle="tooltip" data-original-title="errori strumento"></i>';
                break;
                default:
                break;
            }

        });

        return icons;
    }

    /**
     * Function to copy element to clipboard.
     *
     * @param {element} element Element
     */
    function copyToClipboard(element){
        // create a temporary input
        var $temp = $("<input>");
        // append it to document body
        $("body").append($temp);
        // set the input value with the text of the element to be copied
        $temp.val($(element).text()).select();
        // execute system command "copy"
        document.execCommand("copy");
        // remove temporary input
        $temp.remove();

        // show success message
        $.toast({
            heading: 'Info',
            text: 'Testo copiato',
            position: 'top-right',
            loaderBg:'#ff6849',
            icon: 'info',
            hideAfter: 3000,
            stack: 6
        });
    }

    /**
     * Function to copy SVG image to clipboard.
     *
     * @param {idx} idx SVG image id
     */
    async function copySvgToClipboard(idx){
        // create a canvas for the SVG render
        var canvas = document.createElement('canvas');
        // set canvas sizes
        canvas.width = 600;
        canvas.height = 400;
        // convert SVG to string
        const svg = chart[idx].getSVG().match(/<svg.*<\/svg>/)[0];

        try {
            // render SVG inside a temporary canvas
            const ctx = canvas.getContext('2d');
            const v = await canvg.Canvg.fromString(ctx, svg);
            await v.render();

            // retrive canvas blob and copy it to clipboard
            let canvasBlob = await new Promise(resolve => canvas.toBlob(resolve));
            navigator.clipboard.write([
                new ClipboardItem({
                    'image/png': canvasBlob
                })
            ]);

            // show success message
            $.toast({
                heading: 'Info',
                text: 'Immagine copiata',
                position: 'top-right',
                loaderBg:'#ff6849',
                icon: 'info',
                hideAfter: 3000,
                stack: 6
            });
            // remove temporary canvas
            canvas.remove();
        }
        catch (error) {
            // error message
            swal('Copia non effettuata!', 'E\' possible che il tuo browser non supporti questa funzionalità', 'warning');
            // remove temporary canvas
            canvas.remove();
        }
    }
    // END UTILITIES
    ////////////////////////////////////////////////////////////

    // TAB "MAP" FUNCTIONS
    ////////////////////////////////////////////////////////////
    /**
     * Function that retrieves the stations of a given province.
     *
     * @param {integer} prid Province ID.
     */
    function fillStations(prid){
        $('#stations').empty();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_stations',
            type: "post",
            dataType: "json",
            data: {
                prid: prid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){

                var stations = result.stations;

                // variable for dynamically building the html
                var opts = '';
                var net;
                var stations_id = [];

                // loop through all elements
                // for each station, build a html option to be added to the select
                $.each(stations, function(index, station){
                    stations_id.push(station.station_id);
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

                // append options
                $('#stations').append(opts);
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
     * Function that retrieves all active stations and adds marker on the map.
     */
    function loadStations(){
        console.log('ajax');

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_map_stations',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);

            // get station array
            stationsArray = result.stations;

            // check result
            // if OK then build html
            if( result.res == 'OK' ){

                // reset legend map
                $('#legend-map').empty();

                // add first button "Deseleziona/Seleziona tutti"
                html = '<span class="col-legend">';
                html += '    <a class="layer-active toggle-active font-weight-bold" href="#" data-name="reset-all">';
                html += '        <em><i class="mdi mdi-close-octagon" style=""></i> Deseleziona tutti</em>';
                html += '    </a>';
                html += '</span>';

                // append new content
                $('#legend-map').append(html);

                // check if at least one station exists
                if ( stationsArray.length > 0 ){
                    // add a pin on the map for each looped station
                    $.each(stationsArray, function(index, value) {
                        addMapPoint(value, value.marker_layer, map ); // openlayerFunctions.js
                    });

                    // loop through all map layers except the baselayer
                    // for each of it create a new label for the map legend
                    map.getLayers().getArray().forEach(function(layer, index) {
                        // console.dir(layer);
                        if( ! layer.get('baseLayer') ){
                            var color = fontColors[layer.get('id') % fontColors.length];

                            html  = '<span class="col-legend">';
                            html += '    <a class="layer-active" href="#" data-name="'+layer.get('name')+'">';
                            html += '        <i class="mdi mdi-checkbox-blank-circle" style="color:'+color+';"></i> '+layer.get('name');
                            html += '    </a>';
                            html += '</span>';

                            // append new content
                            $('#legend-map').append(html);
                        }
                    });

                    zoomToMarkers(map); // openlayerFunctions.js
                    mapZoom = map.getView().getZoom();

                }
            }
            else{
                // error message
                swal("Errore!", result.message, "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");
        });
    }

    /**
     * Function to filter stations using station id array.
     *
     * @param {array} stationsIds Station IDs array.
     */
    function filterStationsByStid(stationsIds){
        var coordinates = [];

        // loop through all stations visible on the map
        // for each station if the id doesn't exist in the stationsIds variable
        // then hide it else show it
        stationsArray.forEach(function(station, index){
            if (stationsIds.filter(function(stid) { return stid === station.marker_id; }).length <= 0 ) {
                // get layer by name
                var layer = getLayerByName(station.marker_layer, map); // openlayerFunctions.js
                // get layer feature by id
                var featureToHide = layer.getSource().getFeatureById(station.marker_id);
                // set an empty style in order to hide marker
                featureToHide.setStyle(new ol.style.Style({}));
            }
            else{
                // get layer by name
                var layer = getLayerByName(station.marker_layer, map);
                // get layer feature by id
                var featureToShow = layer.getSource().getFeatureById(station.marker_id);
                // reset style to the default one in order to show marker
                featureToShow.setStyle(null);

                // push marker coordinates
                coordinates.push(featureToShow.getGeometry().getCoordinates());
            }
        });

        // fit map view to visible markers
        var newBound = ol.extent.boundingExtent(coordinates);

        if(newBound != null ){
            map.getView().fit(newBound, {
                size: map.getSize(),
                maxZoom: 18,
                padding: [30, 30, 30, 30]
            });
            mapZoom = map.getView().getZoom();
        }
    }

    /**
     * Function to reset the map.
     */
    function resetMap(){
        var coordinates = [];

        // loop through all available stations
        stationsArray.forEach(function(station, index){
            // get station layer by name
            var layer = getLayerByName(station.marker_layer, map);
            // get feature layer by station id
            var featureToShow = layer.getSource().getFeatureById(station.marker_id);
            // reset feature style to the default one in order to show the marker
            featureToShow.setStyle(null);
            // push visible marker's coordinates
            coordinates.push(featureToShow.getGeometry().getCoordinates());
        });

        // fit map view to visible markers
        var newBound = ol.extent.boundingExtent(coordinates);

        if(newBound != null ){
            map.getView().fit(newBound, {
                size: map.getSize(),
                maxZoom: 18,
                padding: [30, 30, 30, 30]
            });
            mapZoom = map.getView().getZoom();
        }
    }
    // END TAB "MAP" FUNCTIONS
    ////////////////////////////////////////////////////////////

    // TAB "SYNOPTIC" FUNCTIONS
    ////////////////////////////////////////////////////////////
    /**
     * Function that loads station's synoptic tab.
     *
     * @param {integer} id Station ID.
     */
    function loadSynoptic(id){
        console.log('ajax');

        // ATTENZIONE ora in stazione gmt-1, ma dati targati con ora di inizio quindi come se fosse utc
        var to = moment.utc();
        console.log(to.format('YYYY-MM-DD HH:00:00'));

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_data_station',
            type: "post",
            dataType: "json",
            data: {
                id: id,
                from: moment().add('-7', 'days').format('YYYY-MM-DD 00:00:00'),
                to: to.format('YYYY-MM-DD HH:00:00'),
                conv: false
            },
        })
        .done(function(result) {
            // console.dir(result);
            // var el_name = $(this).parent().parent().children("h4").text();

            // check that at least one value exists
            if(result.data.length > 0 ){
                // get station name
                var el_name = result.data[0].station_name;

                // create nav-link
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#syn_'+id+'" role="tab"><span class="hidden-sm-up"><i class="fas fa-chart-area"></i></span> <span class="hidden-xs-down"><strong>S</strong>: '+el_name+'</span>&nbsp&nbsp<i class="fa fa-times text-danger close_tab" data-close="syn_'+id+'"></i></a> </li>';

                // append new content to tabs list
                $('.nav-tabs').append(html);

                // create main tab-content
                html  ='<div class="tab-pane p-20" id="syn_'+id+'" role="tabpanel">\n';
                html +='    <div class="form-body panel-element-view">\n';
                html +='        <h4 class="box-title">Sinottico - <strong>Staz. '+el_name+'</strong></h4>\n';
                html +='        <div class="row m-b-20">';
                html +='            <label class="col-2 col-form-label text-right font-bold">Periodo temporale</label>\n';
                html +='            <div class="input-group col-md-3">';
                html +='                <input id="daterange_'+id+'" class="form-control input-daterange-datepicker" type="text" name="daterange" value="" />';
                html +='                <div class="input-group-append">';
                html +='                    <span class="input-group-text"><i class="mdi mdi-calendar-multiple"></i></span>';
                html +='                </div>';
                html +='            </div>';
                html +='            <div class="col-md-4">\n';
                html +='                <strong>Conversione dati</strong>&nbsp;&nbsp;\n';
                html +='                <input type="checkbox" class="form-control input-showconv" name="showconv" id="showconv_'+id+'" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android">\n';
                // html +='            </div>\n';
                // html +='            <div class="col-md-2">\n';
                html +='                &nbsp;&nbsp;&nbsp;&nbsp;<strong>Tutti dati</strong>&nbsp;&nbsp;\n';
                html +='                <input type="checkbox" class="form-control input-showall" name="showall" id="showall_'+id+'" data-onstyle="success" data-offstyle="danger" data-on="SI" data-off="NO" data-size="sm" data-style="android">\n';
                html +='            </div>\n';
                html +='            <div class="text-right col-md-3">';
                html +='                <button type="button" class="btn btn-info" id="refresh_'+id+'"><i class="icon-refresh"></i> Aggiorna con dati attuali</button>';
                html +='            </div>';
                html +='        </div>';
                html +='        <div class="row chart-mapper">\n';
                html +='        </div>\n';
                html +='    </div>\n';
                html +='</div>\n';

                // append new content to tabs list
                $('.tab-content').append(html);

                // switch to tab
                $('.customtab a[href="#syn_'+ id +'"]').tab('show');

                var values = result.data;

                // variable for datepicker plugin (different format)
                var start = moment().subtract('6', 'days').format('DD/MM/YYYY');
                var end = moment().format('DD/MM/YYYY HH:59:59');

                // Daterange picker
                $('#daterange_'+id).daterangepicker({
                    startDate: start,
                    endDate: end,
                    maxDate: end,
                    buttonClasses: ['btn', 'btn-sm'],
                    applyClass: 'btn-danger',
                    cancelClass: 'btn-inverse',
                    // showOnFocus: false,
                    ranges: {
                        'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
                        'Ultimi 14 giorni': [moment().subtract(13, 'days'), moment()],
                        'Ultimo mese': [moment().subtract(1, 'month'), moment()],
                        'Ultimi 6 mesi': [moment().subtract(6, 'months'), moment()],
                        'Ultimo anno': [moment().subtract(1, 'year'), moment()],
                        'Ultimi 2 anni': [moment().subtract(2, 'year'), moment()]
                    },
                    alwaysShowCalendars: true,
                    locale: dateRangePickerSettings.locale
                }, function(start, end, label) {

                    var elementId = this.element[0].id;
                    var id = elementId.match(/(\d+)/g);
                    id = parseInt(id[0]);

                    // on change event, update charts with new daterange
                    console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'));
                    var dateFrom = start.format('YYYY-MM-DD 00:00:00');
                    var dateTo;

                    // if the end date is equal to today
                    // then set hour equal to the current
                    // else set it at the end of the day '23:59:59'
                    if( end.isSame(moment(), 'day') ){
                        dateTo = moment.utc();
                        dateTo = dateTo.format('YYYY-MM-DD HH:00:00');
                    }
                    else
                        dateTo = end.format('YYYY-MM-DD 23:59:59');

                    console.log(dateTo);

                    // conversion is checked
                    var conv = $('#showconv_'+id).is(':checked');
                    // all data is checked
                    var all  = $('#showall_'+id).is(':checked');

                    // show preloader, waiting for the end of the process
                    $(".inner-preloader").show();

                    // get data within new daterange
                    refreshData(id, dateFrom, dateTo, conv, all);

                    // if there is a windrose then destroy and refresh it
                    if( $('#chart_wind_'+id).length != 0 )
                        createChartWR(id, dateFrom, dateTo);
                });

                // plugin initialization
                $('#showconv_'+id).bootstrapToggle();
                $('#showall_'+id).bootstrapToggle();

                // on conversion change event
                $('.tab-content').on('change', '#showconv_'+id, function(){
                    // get station id from element id
                    var elementId = $(this).attr('id');
                    var id = elementId.match(/(\d+)/g);
                    id = parseInt(id[0]);

                    // get daterange object
                    var drp = $('#daterange_'+id).data('daterangepicker');
                    console.dir(drp);

                    var dateFrom = drp.startDate.format('YYYY-MM-DD 00:00:00');
                    var dateTo;

                    // if the end date is equal to today
                    // then set hour equal to the current
                    // else set it at the end of the day '23:59:59'
                    if( drp.endDate.isSame(moment(), 'day') ){
                        dateTo = moment.utc();
                        dateTo = dateTo.format('YYYY-MM-DD HH:00:00');
                    }
                    else
                        dateTo = drp.endDate.format('YYYY-MM-DD 23:59:59');

                    // conversion is checked
                    var conv = $(this).is(':checked');
                    // all data is checked
                    var all  = $('#showall_'+id).is(':checked');

                    // show preloader, waiting for the end of the process
                    $(".inner-preloader").show();

                    // get data within new daterange
                    refreshData(id, dateFrom, dateTo, conv, all);

                    // if there is a windrose then destroy and refresh it
                    if( $('#chart_wind_'+id).length != 0 )
                        createChartWR(id, dateFrom, dateTo);

                });

                // on all data change event
                $('.tab-content').on('change', '#showall_'+id, function(){
                    // get station id from element id
                    var elementId = $(this).attr('id');
                    var id = elementId.match(/(\d+)/g);
                    id = parseInt(id[0]);

                    // get daterange object
                    var drp = $('#daterange_'+id).data('daterangepicker');
                    console.dir(drp);

                    var dateFrom = drp.startDate.format('YYYY-MM-DD 00:00:00');
                    var dateTo;

                    // if the end date is equal to today
                    // then set hour equal to the current
                    // else set it at the end of the day '23:59:59'
                    if( drp.endDate.isSame(moment(), 'day') ){
                        dateTo = moment.utc();
                        dateTo = dateTo.format('YYYY-MM-DD HH:00:00');
                    }
                    else
                        dateTo = drp.endDate.format('YYYY-MM-DD 23:59:59');

                    // conversion is checked
                    var conv = $('#showconv_'+id).is(':checked');
                    // all data is checked
                    var all  = $(this).is(':checked');

                    // show preloader, waiting for the end of the process
                    $(".inner-preloader").show();

                    // get data within new daterange
                    refreshData(id, dateFrom, dateTo, conv, all);

                    // if there is a windrose then destroy and refresh it
                    if( $('#chart_wind_'+id).length != 0 )
                        createChartWR(id, dateFrom, dateTo);

                });

                // click event un update button
                $('.tab-content').on('click', '#refresh_'+id, function(e){
                    e.preventDefault();
                    console.log('refresh');
                    // get station id from element id
                    var elementId = $(this).attr('id');
                    var id = elementId.match(/(\d+)/g);
                    id = parseInt(id[0]);

                    // get daterange object
                    var drp = $('#daterange_'+id).data('daterangepicker');
                    console.dir(drp);

                    var dateFrom = drp.startDate.format('YYYY-MM-DD 00:00:00');
                    var dateTo;

                    // if the end date is equal to today
                    // then set hour equal to the current
                    // else set it at the end of the day '23:59:59'
                    if( drp.endDate.isSame(moment(), 'day') ){
                        dateTo = moment.utc();
                        dateTo = dateTo.format('YYYY-MM-DD HH:00:00');
                    }
                    else
                        dateTo = drp.endDate.format('YYYY-MM-DD 23:59:59');

                    // conversion is checked
                    var conv = $('#showconv_'+id).is(':checked');
                    // all data is checked
                    var all  = $('#showall_'+id).is(':checked');

                    console.log(dateTo);

                    // show preloader, waiting for the end of the process
                    $(".inner-preloader").show();

                    // get data within new daterange
                    refreshData(id, dateFrom, dateTo, conv, all);

                    // if there is a windrose then destroy and refresh it
                    if( $('#chart_wind_'+id).length != 0 )
                        createChartWR(id, dateFrom, dateTo);
                });

                var flag_wind = false;

                // create chart container for each data series and initialize the chart plugin
                $.each(values, function(index, value){
                    var html ='<div class="col-sm-6" id="chart_'+value.station_param_id+'"></div>\n';
                    $('#syn_'+id+' .chart-mapper').append(html);
                    // set timeout in order to create charts asynchronously
                    setTimeout(function(){
                        createChart(value);
                    }, 10);

                    if(value.parameter_windv || value.parameter_windd ){
                        flag_wind = true;
                    }
                });

                // if there is wind series then build a wind-rose chart
                if(flag_wind){
                    var htmlWind ='<div class="col-sm-6" id="chart_wind_'+id+'"></div>\n';
                    $('#syn_'+id+' .chart-mapper').append(htmlWind);
                    createChartWR(id,  moment().add('-7', 'days').format('YYYY-MM-DD 00:00:00'), moment().format('YYYY-MM-DD HH:59:59'));
                }
            }
            else{
                // error message
                swal("Attenzione!", "Nessun parametro associato alla stazione", "warning");
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
     * Function that creates Highcharts chart for a given parameter.
     *
     * @param {object} value Parameter object.
     */
    function createChart(value){
        // --------- DEFAULT OPTIONS ---------- //
        var chart_title = value.parameter_name;
        var chart_type = 'line';
        // ------------------------------------ //

        if(value.parameter_unit != ''){
            chart_title = value.parameter_name + ' ['+value.parameter_unit+']';
        }

        if(value.station_param_measure_type_id == 3 || value.parameter_treatment == 'sum'){ //on demand, random o somme
            chart_type = 'column';
        }

        if(value.station_param_cadence_min != null){
            chart_pointInterval = value.station_param_cadence_min*60*1000;
        }

        var stationData = JSON.parse(value.station_data);

        // if(value.station_param_values.length > 0 )
        //     chart_pointStart = value.station_param_values[0][0];

        chart[value.station_param_id] = Highcharts.chart('chart_'+value.station_param_id, {
            // OPZIONI DEL CHART //
            chart: {
                height: 400,
                zooming: {
                    mouseWheel:{
                        enabled:false
                    }
                }
            },
            exporting: {
                filename: value.parameter_name,
                buttons: {
                    contextButton: {
                        // add custom buttons and information
                        menuItems: [
                            "viewFullscreen",
                            "printChart",
                            "separator",
                            "downloadCSV",
                            "downloadPNG",
                            "downloadSVG",
                            "separator",
                            {
                               "text": 'Copia PNG [solo <strong>Chrome</strong>]',
                                onclick: function () {
                                    return copySvgToClipboard( value.station_param_id  );
                                }
                            },
                            "separator",
                            {
                               "text": 'Tabella: <strong id="tbl-'+value.station_param_id+'">'+ value.station_fulltable + '</strong>',
                                onclick: function () {
                                    copyToClipboard('#tbl-'+value.station_param_id );
                                }
                            }, {
                               "text": 'Id: <strong id="tbl-id-'+value.station_param_id+'">'+ value.station_param_table_id +'</strong>',
                                onclick: function () {
                                    copyToClipboard( '#tbl-id-'+value.station_param_id  );
                                }
                            }, {
                               "text": 'Param id: <strong id="param-id-'+value.station_param_id+'">'+ value.station_param_id + '</strong>',
                                onclick: function () {
                                    copyToClipboard( '#param-id-'+value.station_param_id  );
                                }
                            }
                        ]
                    }
                }
            },

            // -- DISABILITATE TUTTE -- //
            title: {
                text: chart_title
            },
            xAxis: {
                title:'Data',
                type:'datetime',
                ordinal: false,
                labels: {
                    // step: 2,
                    useHtml: true,
                    formatter: function() {
                        var diff = this.chart.xAxis[0].max - this.chart.xAxis[0].min;
                        if (diff > (5*24*3600*1000)){ // 5 giorni
                            return getFormattedDateHC(this.value, 'basic'); //global.js
                        }
                        else{
                            return getFormattedDateHC(this.value, 'basic_timeStartMin');
                        }
                    }

                }
            },
            yAxis: {
                title: {
                    text: value.parameter_unit != '' ? value.parameter_unit : null
                }
            },
            credits: {
                text: '© '+footer, //Arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                href: company_web
            },
            plotOptions: {
                series: {
                    dataGrouping:{
                        enabled: false
                    },
                    label: {
                        connectorAllowed: false
                    }
                },
                line: {
                    marker: {
                        enabled: value.station_param_cadence_min <= 60 ? false : true,
                        radius: 2.5
                    }
                }
            },
            tooltip: {
                valueDecimals: value.parameter_decimals,
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
            responsive: {
                rules: [{
                    condition: {
                        maxWidth: 500
                    }
                }]
            }
        });

        // creaet main series
        var mean = {
            name: value.parameter_name,
            data: stationData.meanvalue,
            type: chart_type,
            lineWidth: 2,
            zIndex: 99
        };
        // add series to the chart without redrawing it
        chart[value.station_param_id].addSeries(mean, false);

        if(value.parameter_treatment != 'sum'){
            // console.log('stationData');
            // console.dir(stationData);

            // add min values series with specific options if not null
            if(stationData.minvalue != null && value.parameter_type_id != 14 && value.station_param_cadence_min <= 60){
                var min = {
                    id: 'min',
                    name: 'Min',
                    data: stationData.minvalue,
                    type: 'line',
                    dashStyle : 'ShortDash',
                    color: '#4cad58',
                    lineWidth: 1.5,
                    zIndex: 1
                };
                // add series to the chart without redrawing it
                chart[value.station_param_id].addSeries(min, false);
            }

            // add max values series with specific options if not null
            if(stationData.maxvalue != null && value.parameter_type_id != 14 && value.station_param_cadence_min <= 60){
                var max = {
                    id: 'max',
                    name: 'Max',
                    data: stationData.maxvalue,
                    type: 'line',
                    dashStyle : 'ShortDash',
                    color: '#cf5d36',
                    lineWidth: 1.5,
                    zIndex: 1
                };
                // add series to the chart without redrawing it
                chart[value.station_param_id].addSeries(max, false);

            }
        }
        else{
            // if pluviometro add series Cumulata (arriving from db)
            var cumul_series = {
                id: 'cum',
                name: 'Cumulata',
                type: 'line',
                data: value.station_data_cum,
                color: '#cf5d36',
                zIndex: 100
            };
            // add series to the chart without redrawing it
            chart[value.station_param_id].addSeries(cumul_series, false);
        }

        // redraw chart all at once
        chart[value.station_param_id].redraw();
    }

    // create chart windrose
    /**
     * Function that creates Highcharts wind rose chart for a given station on
     * a given period of time.
     *
     * @param {integer} st_id Station ID.
     * @param {date} dateFrom Start period datetime.
     * @param {date} dateTo End period datetime.
     */
    function createChartWR(st_id, dateFrom, dateTo) {
        // if already initialized then destroy it
        if(windChart[st_id]){
            windChart[st_id].destroy();
            windChart[st_id] = null;
        }

        // ajax call
        $.ajax({
            type : 'POST',
            url  : '/str_map_get_windrose_data',
            dataType : 'json',
            data: {
                id : st_id,
                from: dateFrom,
                to: dateTo
            }
        })
        .done(function(result) {
            console.dir(result);
            // console.log('RETURN AJAX wr '+ moment().format('HH:mm:ss'));
            // drawing
            var seriesOptions = [];

            // build series based on wind velocity value

            // seriesOptions[0] = {
            //     name: "&lt;= 0.5 m/s",
            //     data: result.json_calma,
            // };
            seriesOptions[0] = {
                name: "0.5 - 3 m/s",
                data: result.json_debole,
            };
            seriesOptions[1] = {
                name: "3 - 5 m/s",
                data: result.json_moderata,
            };
            seriesOptions[2] = {
                name: "5 - 10 m/s",
                data: result.json_forte,
            };
            seriesOptions[3] = {
                name: "&gt; 10 m/s",
                data: result.json_molto_forte,
            };
            // seriesOptions[5] = {
            //     name: "Totali",
            //     data: result.json_totale,
            // };

            // create the chart
            windChart[st_id] = new Highcharts.Chart('chart_wind_'+st_id, {
                chart: {
                    polar: true,
                    type: 'column',
                    zooming: {
                        mouseWheel:{
                            enabled:false
                        }
                    }
                    // events: {
                    //     load: function () {
                    //         if(this.options.chart.forExport) {
                    //             this.renderer
                    //                 .image('/bobo-img/cf/loghi/little-cf.png', 10, 5, 100, 20)
                    //                 .add();
                    //         }
                    //     }
                    // }
                },
                exporting: {
                    filename: 'Rosa dei venti',
                    buttons: {
                        contextButton: {
                            menuItems: [
                                "viewFullscreen",
                                "printChart",
                                "separator",
                                "downloadCSV",
                                "downloadPNG"
                            ]
                        }
                    }
                },
                title: {
                    text: 'Rosa dei venti'
                },
                pane: {
                    size: '85%'
                },
                legend: {
                    // reversed: true,
                    title: {
                        text: 'CALMA: '+result.perc_calma+'%'
                    },
                    align: 'right',
                    verticalAlign: 'top',
                    y: 100,
                    layout: 'vertical'
                },
                xAxis: {
                    tickmarkPlacement: 'on',
                    categories: ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW']
                },
                yAxis: {
                    min: 0,
                    endOnTick: false,
                    showLastLabel: true,
                    title: {
                        text: 'Frequenza (%)'
                    },
                    labels: {
                        formatter: function () {
                            return this.value + '%';
                        }
                    },
                    reversedStacks: false
                },
                tooltip: {
                    valueSuffix: '%'
                },
                plotOptions: {
                    series: {
                        /*reversed: true,*/
                        stacking: 'normal',
                        shadow: false,
                        groupPadding: 0,
                        pointPlacement: 'on'
                    }
                },
                credits: {
                    text: '© '+footer, // arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                    href: company_web
                },
                colors: ['#e98131', '#3e78b2', '#939ba3', '#4c4f53', '#2ce9e7', '#f5ca00', '#f28f43', '#77a1e5', '#c42525', '#a6c96a'],
                series: seriesOptions
            });
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");
        });
    }

    /**
     * Function that retrieves data of a given station in a given time
     * period and refreshes the charts.
     *
     * @param {integer} id Station ID.
     * @param {date} dateFrom Start period datetime.
     * @param {date} dateTo End period datetime.
     * @param {boolean} conv Boolean value that indicates if data have to be converted.
     * @param {boolean} all Boolean value that indicates if ajax must retrieve all data or only valid ones.
     */
    function refreshData(id, dateFrom, dateTo, conv, all){
        console.log("refreshData");
        console.log(conv);

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_data_station',
            type: "post",
            dataType: "json",
            data: {
                id: id,
                from: dateFrom,
                to: dateTo,
                conv: conv,
                all: all
            },
        })
        .done(function(result) {
            // console.dir(result);
            var values = result.data;

            // loop through retrieved values and build the chart
            $.each(values, function(index, value){
                // parse json data
                var stationData = JSON.parse(value.station_data);

                // set timeout in order to do action asynchronously
                setTimeout(function(){
                    // update main series without redrawing chart
                    chart[value.station_param_id].series[0].update({
                        data: stationData.meanvalue
                    }, false); //true

                    if(value.parameter_treatment != 'sum'){

                        // update min series if not null without redrawing chart
                        if(stationData.minvalue != null && value.parameter_type_id != 14 && value.station_param_cadence_min <= 60 ){
                            chart[value.station_param_id].get('min').update({
                                data: stationData.minvalue
                            }, false); //true

                        }

                        // update max series if not null without redrawing chart
                        if(stationData.maxvalue != null && value.parameter_type_id != 14 && value.station_param_cadence_min <= 60 ){
                            chart[value.station_param_id].get('max').update({
                                data: stationData.maxvalue
                            }, false); //true
                        }
                    }
                    else{
                        // if pluviometro add series Cumulata (arriving from db)
                        chart[value.station_param_id].get('cum').update({
                            data: value.station_data_cum
                        }, false); //true
                    }

                    // refresh chart texts and options
                    var options;
                    var chartTitle = value.parameter_name;
                    // check conversion flag
                    if(conv == true){
                        if(value.parameter_unit_conv != '')
                            chartTitle = value.parameter_name + ' ['+value.parameter_unit_conv+']';

                        chart[value.station_param_id].setTitle({ text: chartTitle }, null, false);
                        options = {
                            yAxis: {
                                title: {
                                    text: value.parameter_unit_conv
                                }
                            }
                        };
                    }
                    else{
                        if(value.parameter_unit != '')
                            chartTitle = value.parameter_name + ' ['+value.parameter_unit+']';

                        chart[value.station_param_id].setTitle({ text: chartTitle }, null, false);
                        options = {
                            yAxis: {
                                title: {
                                    text: value.parameter_unit
                                }
                            }
                        };
                    }

                    // update chart options without redrawing it
                    chart[value.station_param_id].update(options, false);
                    // redraw chart all at once
                    chart[value.station_param_id].redraw();
                }, 10);
            });

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
    // END TAB "SYNOPTIC" FUNCTIONS
    ////////////////////////////////////////////////////////////

    // TAB "REAL TIME" FUNCTIONS
    ////////////////////////////////////////////////////////////
    /**
     * Function that loads station's realtime data tab.
     *
     * @param {integer} id Station ID.
     */
    function loadRealTime(id){
        console.log('ajax');

        // get current fulldate -1 minute
        var dateTo = moment().tz('Etc/GMT-1');
        dateTo.add('-1', 'minutes');

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_inst_data_station',
            type: "post",
            dataType: "json",
            data: {
                id: id,
                to: dateTo.format('YYYY-MM-DD HH:mm:00')
            },
        })
        .done(function(result) {
            console.dir(result);

            // check if at least one value exists
            if(result.data.length > 0 ){
                // get station name
                var el_name = result.data[0].station_name;

                // create nav-link
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#rt_'+id+'" role="tab"><span class="hidden-sm-up"><i class="fas fa-chart-line"></i></span> <span class="hidden-xs-down"><strong>RT</strong>: '+el_name+'</span>&nbsp&nbsp<i class="fa fa-times text-danger close_tab" data-close="rt_'+id+'"></i></a> </li>';

                // append new content to tabs list
                $('.nav-tabs').append(html);

                // variable for dynamically build the html
                var html = '';

                html += '<div class="tab-pane p-20" id="rt_'+id+'" role="tabpanel">';
                html += '    <h4 class="box-title m-b-10">Dati real time - <strong>Staz. '+el_name+'</strong>';
                html += '    <a href="/dat_istantanei/'+id+'" class="btn btn-info btn-sm m-b-10 pull-right" target="_blank"><i class="fad fa-asterisk"></i> Ulteriori dettagli &raquo;</a></h4>';
                html += '    <h6 class="text-muted-sec">Data ultimo dato ricevuto il <strong id="realtime-date-'+id+'">14/01/2022 14:04</strong></h6>';
                html += '    <div class="progress m-b-15">';
                html += '        <div class="progress-bar bg-warning wow animated progress-animated" style="width: 0%; height:3px;" role="progressbar" id="progressbar-'+id+'"> <span class="sr-only">Percentuale di completamento</span> </div>';
                html += '    </div>';
                html += '    <div class="row">';
                html += '        <div class="col-lg-12">';
                html += '            <div class="row realtime-main-content" id="realtime-content-'+id+'">';

                var values = result.data;
                var groupId;

                // for each series of data create a cumulative chart container based on instrument
                $.each(values, function(index, value){
                    // instrument_name: "Teledyne API 200E [ECO004] "
                    // parameter_id: 30
                    // parameter_name: "NOx"
                    // parameter_unit: "ppb"
                    // station_data: [...]
                    // station_name: "Laboratorio Mobile"
                    // station_param_id: 17
                    // station_param_table_id: 51
                    // stpr_group_id: 1

                    // parse json data
                    var stationData = JSON.parse(value.station_data);
                    // get data length
                    var dataLen = stationData.meanvalue.length -1;
                    // check if series is measured by a different instrument fromthe previous one
                    if(value.stpr_group_id != groupId){
                        // if it is not the first loop, close the previous box
                        if(index != 0){
                            html += '                            </p>';
                            html += '                            <div class="chart-morris-real" id="rt-chart-'+groupId+'">';
                            html += '                            </div>';
                            html += '                        </div>';
                            html += '                    </div>';
                            html += '                </div>';
                        }

                        // store new instrument group id
                        groupId = value.stpr_group_id;

                        // open new box
                        html += '                <div class="col-lg-4">';
                        html += '                    <div class="card">';
                        html += '                        <div class="card-body">';
                        html += '                            <h5 class="card-title text-info rt-title-'+groupId+'">';
                        html += value.instrument_name;
                        html += formatAlarmIcons(stationData.station_alarms[dataLen][1], stationData.measure_alarms[dataLen][1]);
                        html += '                            </h5>';
                        html += '                            <p>'+value.parameter_shortname+': <strong class="val-'+value.station_param_id+'">'+formatVal(stationData.meanvalue[dataLen][1])+' '+value.parameter_unit+'</strong>';
                    }
                    else{
                        html += '                            &nbsp;&nbsp;-&nbsp;&nbsp;'+value.parameter_shortname+': <strong class="val-'+value.station_param_id+'">'+formatVal(stationData.meanvalue[dataLen][1])+' '+value.parameter_unit+'</strong>';
                    }
                });

                html += '                            </p>';
                html += '                            <div class="chart-morris-real" id="rt-chart-'+groupId+'" style="height:400px">';
                html += '                            </div>';
                html += '                        </div>';
                html += '                    </div>';
                html += '                </div>';
                html += '            </div>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                // append new content to tabs list
                $('.tab-content').append(html);
                $('#realtime-date-'+id).text(dateTo.format('DD/MM/YYYY HH:mm'));

                // switch to tab
                $('.customtab a[href="#rt_'+ id +'"]').tab('show');
                $('[data-toggle="tooltip"]').tooltip();

                groupId = values[0].stpr_group_id;
                var unit = values[0].parameter_unit;
                var series = [];

                // for each series of data create a cumulative chart object based on instrument
                $.each(values, function(index, value){
                    // group id different from the previous one, initialize the chart with all the series of the group
                    if(value.stpr_group_id != groupId){

                        createChartRT(groupId, unit, series);
                        // store new group id and parameter unit
                        // reset series array
                        groupId = value.stpr_group_id;
                        unit = value.parameter_unit;
                        series = [];
                    }

                    // parse json data
                    var stationData = JSON.parse(value.station_data);
                    // push series measured by the same instrument in a array
                    series.push({
                        id: 'series-'+value.station_param_id,
                        name: value.parameter_shortname,
                        data: stationData.meanvalue
                    });
                });

                // initialize last chart
                createChartRT(groupId, unit, series);

                // refresh chart every minute
                // 60000 milliseconds
                setInterval( function(){
                    refreshChartRT(id);
                }, 60000);

                // refresh progress bar
                setProgressBar(id, 1);
            }
            else{
                // error message
                swal({
                    title: "Attenzione",
                    text: '<p>Non è possibile visualizzare i dati in realtime.<br>Controllare nell\'anagrafica che:<ul style="text-align:left;"><li>siano presenti <strong>parametri associati alla stazione;</strong></li><li>ci siano <strong>strumenti associati ai parametri</strong> della stazione;</li><li><strong>il real time sia attivo</strong> per la stazione corrente.</li></ul></p>',
                    type: "info",
                    html: true,
                    showCancelButton: false,
                    confirmButtonText: "Ok, ho capito",
                    closeOnConfirm: true
                });
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
     * Function that sets the progression bar present in the realtime data
     * tab of a given station.
     *
     * @param {integer} id Station ID.
     * @param {integer} counter Counter variable.
     */
    function setProgressBar(id, counter){
        // calculate % based on number of seconds elapsed
        var perc = (counter/60)*100;
        // refresh progress bar
        document.getElementById('progressbar-'+id).style.width = perc+'%';
        // if counter equal to 1 minutes then reset it
        // else increase it
        if( counter == 60 )
            counter = 1;
        else
            counter++;

        // call function every second
        // 1000 milliseconds
        setTimeout(function(){
            setProgressBar(id, counter);
        }, 1000);
    }

    /**
     * Function that creates Highcharts realtime data chart of a
     * given set of parameters.
     *
     * @param {integer} groupId Parameter group ID.
     * @param {string} unit Measure unit.
     * @param {array} seriesArray Data array.
     */
    function createChartRT(groupId, unit, seriesArray){
        console.log('Create chart RT: '+ groupId);
        // console.dir(series);

        var options = {
            chart: {
                height: 400
            },
            title: {
                text: null
            },
            exporting: {
                enabled: false
            },
            xAxis: {
                title:'Data',
                type:'datetime',
                ordinal: false,
                labels: {
                    // step: 2,
                    useHtml: true,
                    formatter: function() {
                        return getFormattedDateHC(this.value, 'basic_timeStartMin');
                    }
                }
            },
            yAxis: {
                title: {
                    text: unit
                }
            },
            credits: {
                text: '© '+footer, // arriving from DB "portal_css_footer_text", default "Bobo Cloud"
                href: company_web
            },
            plotOptions: {
                series: {
                    dataGrouping:{
                        enabled: false
                    },
                    label: {
                        connectorAllowed: false
                    }
                },
                line: {
                    marker: {
                        enabled: false
                    }
                }
            },
            tooltip: {
                enabled: true,
                shared: true,
                // valueDecimals: 2,
                // valueDecimals: value.parameter_decimals,
                split: false,
                dateTimeLabelFormats: {
                    day: '%A %e %b %Y',
                    hour: '%A %e %b, %H:%M',
                    minute: '%A %e %b, %H:%M',
                    second: '%A %e %b, %H:%M:%S',
                    week: '%A %e %b %Y',
                    year: '%Y'
                }
            }
        };

        chartRT[groupId] = Highcharts.chart('rt-chart-'+groupId, options);

        // loop through all series and add them to char without redrawing it
        $.each(seriesArray, function(index, series){
            chartRT[groupId].addSeries(series, false);
        });
        // redraw chart all at once
        chartRT[groupId].redraw();
    }

    /**
     * Function that retrieves realtime data of a given station and refreshes the charts.
     *
     * @param {integer} id Station ID.
     */
    function refreshChartRT(id){
        console.log('refreshChartRT');

        // get current fulldate -1 minute
        var dateTo = moment().tz('Etc/GMT-1');
        dateTo.add('-1', 'minutes');
        $('#realtime-date-'+id).text(dateTo.format('DD/MM/YYYY HH:mm'));
        // console.log(id);
        // console.log(dateTo.format('YYYY-MM-DD HH:mm:00'));

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_map_get_inst_data_station',
            type: "post",
            dataType: "json",
            data: {
                id: id,
                to: dateTo.format('YYYY-MM-DD HH:mm:00')
            },
        })
        .done(function(result) {
            var values = result.data;

            // loop through all series
            $.each(values, function(index, value){

                // get instrument group id
                var groupId = value.stpr_group_id;
                // console.log(groupId);
                // console.log('series-'+value.station_param_id);

                // parse json data
                var stationData = JSON.parse(value.station_data);
                // get number of data
                var len = stationData.meanvalue.length;
                // get last point of series
                var point = stationData.meanvalue[len-1];

                // console.log(point);

                // get chart series by stprid and add the last point
                var series = chartRT[groupId].get('series-'+value.station_param_id);
                series.addPoint(point, true, true);

                // refresh alarms
                $('.val-'+value.station_param_id).text(formatVal(point[1])+' '+value.parameter_unit);
                var title = value.instrument_name;
                title += formatAlarmIcons(stationData.station_alarms[len-1][1], stationData.measure_alarms[len-1][1]);
                // console.log(title);
                $('.rt-title-'+groupId).empty();
                $('.rt-title-'+groupId).html( title );

                // refresh tooltip plugin
                $('[data-toggle="tooltip"]').tooltip();
            });

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }
    // END TAB "REAL TIME" FUNCTIONS
    ////////////////////////////////////////////////////////////
});
