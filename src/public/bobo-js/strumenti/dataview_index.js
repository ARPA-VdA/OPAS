/**
 * Document ready
 */
$( document ).ready(function() {

    // GLOBAl VARIABLES
    // map
    var map;
    var mapLegend;
    var legend;

    // popup
    var container = document.getElementById('popup'),
        content_element = document.getElementById('popup-content');

    var selectedFeature;
    var numBaseLayers;

    var table;
    var firstDraw = true;

    console.log('App mode: ' + app_mode);

    // disable console messages
    if (app_mode == 'production'){
        // var console = {};
        console.log = function(){};
        console.dir = function(){};
    }

    // set title
    $('#bottom-double strong').html('Tutte le stazioni');

    // INITIALIZATIONS //
    // on draw event
    // triggered every time the table is re-drawn
    table = $('#table-stations').on('draw.dt', function(){

        // check if it's the first draw
        if(firstDraw){

            firstDraw = false;

            // manage windows size
            hgt = $( "#page-stations" ).innerHeight();
            $(".map-full").css("height", hgt);

            // MAP STUFF

            // Italy extext
            var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
            boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

            var view = new ol.View();
            var hiking = new ol.layer.Tile({
                name: 'Topografia',
                source: new ol.source.XYZ({
                    attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors -  <a href="https://opentopomap.org/" target="_blank">OpenTopoMap</a>',
                    // url: 'http://maps.refuges.info/hiking/{z}/{x}/{y}.png',
                    url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                    maxZoom: 23

                }),
                baseLayer: true,
                visible: false
            });

            // initialize map on the "map" div
            map = new ol.Map({
                target: 'map',
                layers: [
                    new ol.layer.Tile({
                        source: new ol.source.OSM(),
                        baseLayer: true,
                        name: 'Standard'
                    }),
                    hiking
                ],
                view: view,
                controls: ol.control.defaults.defaults({attribution: false}).extend(
                    [  new ol.control.LayerPopup() ]
                )
            });

            // fit map to the extent
            view.fit(boundingExtent, map.getSize());

            /* CONTROLS */
            var fullscreen = new ol.control.FullScreen();
            map.addControl(fullscreen);

            var attribution = new ol.control.Attribution({
                collapsible: true,
                collapsed: true
            });

            map.addControl(attribution);
            /* END CONTROLS */


            /* POPUP */
            var container = document.getElementById('popup'),
                content_element = document.getElementById('popup-content');

            // create an overlay to manage the popup
            var overlay = new ol.Overlay({
                id: 'popup',
                element: container,
                // autoPan: true, // disable autofocus on popup
                offset: [0.5, -45.5]
            });

            map.addOverlay(overlay);
            overlay.set('type', 'hover');

            // add more layers
            var indicatorLayer = new ol.layer.Tile({
                name: 'Indicatori',
                source: new ol.source.StadiaMaps({
                    layer: 'stamen_toner_lite',
                    apiKey: '2d06aa11-fa8c-40ad-afaf-e62558f4914f'
                }),
                baseLayer: true,
                visible: false
            });

            var vectorLayer = new ol.layer.Vector({
                source:new ol.source.Vector({
                    features: [ ]
                })
            });
            vectorLayer.set('name', 'Stazioni');

            // add layers to map
            map.addLayer(indicatorLayer);
            map.addLayer(vectorLayer);

            // Define a new legend
            mapLegend = new ol.legend.Legend({
                title: 'Legenda',
                textStyle: new ol.style.Text({
                    font: 'bold 12px sans-serif',
                }),
                titleStyle: new ol.style.Text({
                    font: 'bold 18px sans-serif',
                }),
                margin: 1,
                size: [35, 25]
            })

            // add legend to map
            var ctrlLegend = new ol.control.Legend({
                legend: mapLegend,
                // margin: 5,
                collapsed: false
            });
            map.addControl(ctrlLegend);

            // add a fixed label to the legend (always present)
            mapLegend.addItem({
                id: 0,
                // margin: 5,
                title: 'Non disponibile',
                typeGeom: 'Point',
                style: new ol.style.Style({
                    image: new ol.style.Circle({
                        radius: 8,
                        fill: new ol.style.Fill({color: '#7F7F7F'}),
                        stroke: new ol.style.Stroke({color: '#000', width: 1}),
                    })
                })
            });
            // });

            map.getView().fit(boundingExtent, map.getSize());

            // handle mouse events in order to show/hide different kind of popup
            map.on('pointermove', function(e){
                e.preventDefault();

                // get nearest (by pixel) feature
                var feature = map.forEachFeatureAtPixel(e.pixel,
                    function(feature, layer) {
                        return feature;
                    }
                );

                var overlay = map.getOverlayById('popup');

                // if the overlay is set on "hover" and there's a feature then show a specific popup with less info
                if( overlay.get('type') == 'hover' ){
                    // feature is defined
                    if (feature) {

                        // reset selected feature if not null
                        // selected feature has is own style different from all others style
                        // if the feature is the same of the one selected then don't reset the style in order to prevent flickering
                        if(selectedFeature != null && selectedFeature.getId() != feature.getId() ){
                            selectedFeature.setStyle(null);
                        }

                        // get metadata stored inside feature object
                        var geometry = feature.getGeometry();
                        var value = feature.get('param_value');
                        var coord = geometry.getCoordinates();
                        var coord_formatted =  ol.proj.transform(coord, ol.proj.get('EPSG:3857'), ol.proj.get('EPSG:4326'));

                        // create popup content
                        var content = '<h4>' + feature.get('name') + '</h4>';
                        if(value != null){
                            if(value != 'n.d.')
                                content += '<p><strong>Valore selezionato</strong>: '+ parseFloat(value) +' '+ feature.get('param_unit')+'</p>';
                            else
                                content += '<p><strong>Valore selezionato</strong>: '+ value +' '+ feature.get('param_unit')+'</p>';
                        }
                        else
                            content += '<p><strong>Coordinate </strong>: '+ parseFloat(coord_formatted[1]).toFixed(3) +', '+parseFloat(coord_formatted[0]).toFixed(3)+'</p>';

                        if(feature.get('logo') != null)
                            content += '<img src="'+feature.get('logo')+'" height="25"></img>';

                        // append description to popup container
                        content_element.innerHTML = content;
                        // store focused feature in the global variable
                        selectedFeature = feature;

                        // set popup position and marker style based on visualization type (live/indicatori)
                        var data = $('input[name=radio_data]:checked').val();
                        if(data == 'indicatori'){
                            var radius = map.getView().getZoom()*2.5;
                            overlay.setOffset([0.5, -radius/2]);
                            overlay.setPosition(coord);
                            // set specific style
                            selectedFeature.setStyle(selectedIndicatorStyleFunction);
                        }
                        else{
                            overlay.setOffset([0.5, -45.5]);
                            overlay.setPosition(coord);
                            // set specific style
                            selectedFeature.setStyle(selectedPointStyleFunction);
                        }
                    }
                    else{
                        // reset overlay
                        overlay.setPosition(undefined);
                        // reset selected feature if not null
                        // selected feature has is own style different from all others style
                        if(selectedFeature != null){
                            selectedFeature.setStyle(null);
                            selectedFeature = null;
                        }

                    }
                }
            });

            // handle mouse events in order to show/hide different kind of popup
            map.on('click', function(e){
                e.preventDefault();
                console.log('click!');
                // get nearest (by pixel) feature
                var feature = map.forEachFeatureAtPixel(e.pixel,
                    function(feature, layer) {
                        return feature;
                    }
                );
                // get overlay object
                var overlay = map.getOverlayById('popup');

                // if feature is not null
                if (feature) {

                    // reset selected feature if not null
                    // selected feature has is own style different from all others style
                    if(selectedFeature != null){
                        selectedFeature.setStyle(null);
                        selectedFeature = null;
                    }

                    // get coordinates from the feature's geometry
                    var geometry = feature.getGeometry();
                    var coord = geometry.getCoordinates();
                    var coord_formatted =  ol.proj.transform(coord, ol.proj.get('EPSG:3857'), ol.proj.get('EPSG:4326'));

                    // retrieve metadata stored inside the feature object
                    var content = feature.get('description');
                    console.log(content);
                    content_element.innerHTML = content;
                    // change type of overlay and block the "hover" popup
                    overlay.set('type', 'click');

                    selectedFeature = feature;

                    // set popup position and marker style based on visualization type (live/indicatori)
                    var data = $('input[name=radio_data]:checked').val();
                    if(data == 'indicatori'){
                        var radius = map.getView().getZoom()*2.5;
                        overlay.setOffset([0.5, -radius/2]);
                        overlay.setPosition(coord);
                        // set specific style
                        selectedFeature.setStyle(selectedIndicatorStyleFunction);
                    }
                    else{
                        overlay.setOffset([0.5, -45.5]);
                        overlay.setPosition(coord);
                        // set specific style
                        selectedFeature.setStyle(selectedPointStyleFunction);
                    }
                }
                else{
                    // reset type of overlay and newly allow "hover" popup
                    overlay.setPosition(undefined);
                    overlay.set('type', 'hover');
                    // reset selected feature if not null
                    // selected feature has is own style different from all others style
                    if(selectedFeature != null){
                        selectedFeature.setStyle(null);
                        selectedFeature = null;
                    }
                }
            });
            /* END POPUP */

            // END MAP STUFF

            // check how many labels of different kind exists
            // based on number of labels in live and indicator sections, dynamically set radio button and load data
            if(live_params_length > 0){
                // take care of radio button and visibility of elements
                $('#radio_data_live').prop('checked', true);
                $("#hover-bottom-indicatori").hide();
                $("#hover-bottom").show();
                $(".ol-legend").hide();
                // load live data of the first available parameter
                loadStationsData($('#hover-bottom .active').data('param'), $('#hover-bottom .active').data('aggr'));
            }
            else if(ind_params_length > 0){
                // take care of radio button and visibility of elements
                $('#radio_data_indicator').prop('checked', true);
                $("#hover-bottom-indicatori").show();
                $("#hover-bottom").hide();
                $(".ol-legend").show();
                // load indicator data of the first available parameter
                loadStationsIndicators($('#hover-bottom-indicatori .active').data('param'), $('#hover-bottom-indicatori .active').data('stat'));
            }
            else{
                // take care of radio button and visibility of elements
                $('#radio_data_stations').prop('checked', true);
                $("#hover-bottom-indicatori").hide();
                $("#hover-bottom").hide();
                $(".ol-legend").hide();
                // load stations
                loadStations();
            }

            // check information from URL
            setTimeout(function(){
                // if there is the identifier of a region and it exists then zoom to its stations
                // otherwise zoom to all available markers
                if(regURL != null && $('#select-region option[value="'+regURL+'"]').length > 0){
                    $('#select-region').val(regURL).trigger('change');
                }
                else{
                    zoomToMarkers(map);
                }

            }, 100);

            // get number of base layers on the map
            numBaseLayers = getHowManyBaselayers(map);

        }
    // initiliaze datable plugin
    }).DataTable({
        responsive: true,
        "language": {
            "url": "/bobo-js/italian.json"
        },
        "paging": true,
        "pageLength": 13,
        // "order": [[ 1, "asc" ]],
        "columnDefs": [{
            "targets": [ 0 ],
            "visible": logged ? true: false // visible only if the user is logged
        }],
        "lengthChange": false,
        "info": false
    });

    // initialize datatable plugin for parameters
    var tableParam = $('#table-parameters').DataTable({
        responsive: true,
        "language": {
            "url": "/bobo-js/italian.json"
        },
        "paging": true,
        "pageLength": 15,
        "ordering": false,
        "columnDefs": [
            {
                "targets": 0,
                "defaultContent": "",
                "className": "select-checkbox"
            },
            {
                "targets": 1 ,
                "visible": logged ? true: false
            }
        ],
        "select": {
            "style": "multi",
            "selector": "td:first-child"
        },
        "lengthChange": false,
        "info": false
    });
    // END INITIALIZATIONS

    // TOP BAR
    /**
     * Change event on radio button at the top of the map
     */
    $( "#map-hover" ).on( "change", "input[name=radio_data]", function(e) {
        e.preventDefault();

        // get selected type of visualization
        var data = $('input[name=radio_data]:checked').val();
        console.log(data);
        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();

        // get map overlay
        var overlay = map.getOverlayById('popup');
        // reset popup and selected feature in order to prevent zombie items
        if( overlay.get('type') != 'hover' ){
            overlay.setPosition(undefined);
            overlay.set('type', 'hover');
        }

        // reset selected feature if not null
        // selected feature has is own style different from all others style
        if(selectedFeature != null){
            selectedFeature.setStyle(null);
            selectedFeature = null;
        }

        // reset legend
        resetLegend();

        // load data/stations based on selected visualization
        if (data == "dati"){
            // show / hide live / "indicatori" containers
            $("#hover-bottom").show();
            $("#hover-bottom-indicatori").hide();
            $(".ol-legend").hide();
            // reset popup
            resetOverlayPopup(map);
            // load data based on selected parameters
            loadStationsData($('#hover-bottom .active').data('param'));
        }
        else if(data== "indicatori"){
            // show / hide live / "indicatori" containers
            $("#hover-bottom-indicatori").show();
            $(".ol-legend").show();
            $("#hover-bottom").hide();
            // reset popup
            resetOverlayPopup(map);
            // load data based on selected parameters
            loadStationsIndicators($('#hover-bottom-indicatori .active').data('param'), $('#hover-bottom-indicatori .active').data('stat'));
        }
        else{
            $("#hover-bottom-indicatori").hide();
            $("#hover-bottom").hide();
            $(".ol-legend").hide();

            // get selected parameters and reload stations that contain them
            var paramIdArray = [];
            tableParam.rows( {'selected': true} ).every( function ( rowIdx, tableLoop, rowLoop ) {
                var data = this.data();
                paramIdArray.push(parseInt(data[1]));
            });
            loadStations(paramIdArray);
        }
    });

    /**
     * Click event on parameters buttons at the top of the map
     * Switch parameter in live visualization
     */
    $("#hover-bottom").on('click', '.nav-link', function(e){
        e.preventDefault();

        // remove active class from previous active parameter and add it to newer one
        $('#hover-bottom .active').removeClass('active');
        $(this).addClass('active');

        // get id and aggregation
        var param_id = $(this).data('param');
        var param_aggr = $(this).data('aggr')

        // reset popup and selected feature in order to prevent zombie items
        var overlay = map.getOverlayById('popup');

        if( overlay.get('type') != 'hover' ){
            overlay.setPosition(undefined);
            overlay.set('type', 'hover');
        }

        // reset selected feature if not null
        // selected feature has is own style different from all others style
        if(selectedFeature != null){
            selectedFeature.setStyle(null);
            selectedFeature = null;
        }

        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();
        // load data based on selected parameters
        loadStationsData(param_id, param_aggr);
    });

    /**
     * Click event on parameters buttons at the top of the map
     * Switch parameter in "indicatori" visualization
     */
    $("#hover-bottom-indicatori").on('click', '.nav-link', function(e){
        e.preventDefault();

        // remove active class from previous active parameter and add it to newer one
        $('#hover-bottom-indicatori .active').removeClass('active');
        $(this).addClass('active');

        // get id and statistic
        var param_id = $(this).data('param');
        var stat_id = $(this).data('stat');

        // reset popup and selected feature in order to prevent zombie items
        var overlay = map.getOverlayById('popup');

        if( overlay.get('type') != 'hover' ){
            overlay.setPosition(undefined);
            overlay.set('type', 'hover');
        }

        // reset selected feature if not null
        // selected feature has is own style different from all others style
        if(selectedFeature != null){
            selectedFeature.setStyle(null);
            selectedFeature = null;
        }

        // reset legend
        resetLegend();
        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();
        // load data based on selected parameters
        loadStationsIndicators(param_id, stat_id);
    });
    // END TOP BAR

    // RIGHT COLUMN
    /**
     * Click event on >> button to show/hide lateral menu
     */
    $("#page-stations mark").click(function(e) {
        e.preventDefault();

        // toggle class for lateral menu
        $( "#page-stations" ).toggleClass( "to-right" );
        // resize map
        map.updateSize();

        // if here is a selected region zoom to it
        // otherwise zoom to all points
        var regid = parseInt($('#select-region').val());
        if(regid != -1 ){
            zoomToRegion(map, regid);
        }
        else{
            zoomToMarkers(map);
        }
    });

    /**
     * Change event on filters of lateral menu
     */
    $('#select-region, #select-prov').on('change', function(){
        // get selected region
        var regid = parseInt($('#select-region').val());
        // zoom to it if not null
        // else zoom to all markers
        if(regid != -1 ){
            zoomToRegion(map, regid);
        }
        else{
            zoomToMarkers(map);
        }

        // reload stations filtered by region and province
        loadStationsList();
    });

    /**
     * Mouseenter event on table rows
     */
    $('#table-stations').on('mouseenter', 'tr', function(e){
        e.preventDefault();

        if($(this).data("id")== null)
            return;

        // get overlay item
        var overlay = map.getOverlayById('popup');
        // if type of overlay is hover
        if(overlay.get('type') == 'hover'){

            // reset selected feature if not null
            // selected feature has is own style different from all others style
            if(selectedFeature != null){
                overlay.setPosition(undefined);
                selectedFeature.setStyle(null);
                selectedFeature = null;
            }

            var layer;
            // get visualization type
            var data = $('input[name=radio_data]:checked').val();
            if(data == 'stazioni'){
                // if there are checked parameters
                if( tableParam.rows( {'selected': true} ).count() > 0){
                    console.log('by name');
                    // get layer name stored in the last td of the row
                    var layerName = $(this).find('td:last').text();
                    // get layer by name
                    layer = getLayerByName(layerName, map);
                }
                else{
                    console.log('by index');
                    // get idx layer stored in the row + offset numBaseLayers
                    var idx = parseInt($(this).data("idx")) + numBaseLayers;
                    // get layer by idx
                    layer = getLayerByIdx( idx, map );
                }

            }
            else{
                // get layer by idx
                layer = getLayerByIdx( numBaseLayers, map);
            }

            var featureToSelect;
            // if a layer exists then get feature by id
            if(layer)
                featureToSelect = layer.getSource().getFeatureById(parseInt($(this).data("id")));

            // if feature exists
            if(featureToSelect){
                // save feature
                selectedFeature = featureToSelect;

                // get feature coordinates
                var geometry = featureToSelect.getGeometry();
                var value = featureToSelect.get('param_value');
                var coord = geometry.getCoordinates();
                var coord_formatted =  ol.proj.transform(coord, ol.proj.get('EPSG:3857'), ol.proj.get('EPSG:4326'));

                // create popup content
                var content = '<h4>' + featureToSelect.get('name') + '</h4>';
                if(value != null){
                    if(value != 'n.d.')
                        content += '<p><strong>Valore selezionato</strong>: '+ parseFloat(value) +' '+ featureToSelect.get('param_unit')+'</p>';
                    else
                        content += '<p><strong>Valore selezionato</strong>: '+ value  +' '+ featureToSelect.get('param_unit')+'</p>';
                }
                else
                    content += '<p><strong>Coordinate </strong>: '+ parseFloat(coord_formatted[1]).toFixed(3) +', '+parseFloat(coord_formatted[0]).toFixed(3)+'</p>';

                if(featureToSelect.get('logo') != null)
                    content += '<img src="'+featureToSelect.get('logo')+'" height="25"></img>';

                content_element.innerHTML = content;

                // set popup position and marker style based on visualization type (live/indicatori)
                var data = $('input[name=radio_data]:checked').val();
                if(data == 'indicatori'){
                    var radius = map.getView().getZoom()*2.5;
                    overlay.setOffset([0.5, -radius/2]);
                    overlay.setPosition(coord);
                    // set specific style
                    selectedFeature.setStyle(selectedIndicatorStyleFunction);
                }
                else{
                    overlay.setOffset([0.5, -45.5]);
                    overlay.setPosition(coord);
                    // set specific style
                    selectedFeature.setStyle(selectedPointStyleFunction);
                }

            }
        }

    });

    /**
     * Click event on "Parametri" tab to open the list of parameters on the right
     */
    $("#params-tab").on("click", function(e){
        e.preventDefault();
        // adjust columns size
        tableParam.columns.adjust().draw();
        // switch to "Stazioni" visualization
        $("#radio_data_stations").trigger('click');
    });

    /**
     * Select event on tableParam
     */
    tableParam.on( 'select', function ( e, dt, type, indexes ) {

        // reset array of selected parameters
        var paramIdArray = [];
        // loop through rows and push in the array only selected parameters
        tableParam.rows( {'selected': true} ).every( function ( rowIdx, tableLoop, rowLoop ) {
            var data = this.data();
            paramIdArray.push(parseInt(data[1]));
        });

        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();
        // reload stations that contain all selected parameters
        loadStations(paramIdArray);

    });

    /**
     * Deselect event on tableParam
     */
    tableParam.on( 'deselect', function ( e, dt, type, indexes ) {

        // reset array of selected parameters
        var paramIdArray = [];
        // loop through rows and push in array only selected parameters
        tableParam.rows( {'selected': true} ).every( function ( rowIdx, tableLoop, rowLoop ) {
            var data = this.data();
            paramIdArray.push(parseInt(data[1]));
        });

        // show preloader, waiting for the end of the process
        $("#dataview-preloader").show();
        // reload stations that contain all selected parameters
        loadStations(paramIdArray);
    });
    // END RIGHT COLUMN


    // get screen orientation
    var supportsOrientationChange = "onorientationchange" in window,
        orientationEvent = supportsOrientationChange ? "orientationchange" : "resize";

    // add listener to catch change orientation events
    window.addEventListener(orientationEvent, function() {
        // table.draw();
        setTimeout(
            function(){
                // resize map view
                map.updateSize();
                // get selected region
                var regid = parseInt($('#select-region').val());
                // if it exists then zoom to region
                // else zoom to all markers
                if(regid != -1 ){
                    zoomToRegion(map, regid);
                }
                else{
                    zoomToMarkers(map);
                }
            },
        20);

    }, false);

    /**
     * Style function for selected marker
     *
     * @param {object} Map feature
     *
     * @return {object} Map style
     */
    function selectedIndicatorStyleFunction(feature){
        var coef = 1.5;

        var zoom = map.getView().getZoom();
        var color = getColor(feature.get('param_value'));
        color = ol.color.asArray(color);
        color = color.slice();
        color[3] = 1;

        return new ol.style.Style({
            image: new ol.style.Circle({
                radius: zoom * coef,
                fill: new ol.style.Fill({color: color}),
                stroke: new ol.style.Stroke({color: '#FFF', width: 2}),
            }),
            zIndex: 1
        });
    }

    /**
     * Style function for default marker in live mode
     *
     * @param {object} Map feature
     *
     * @return {object} Map style
     */
    function pointStyleFunction(feature) {

        var coef = 1.7;

        if(isPortrait()){
            coef = 2.0;
        }

        var zoom = map.getView().getZoom();
        var size = zoom * coef; // arbitrary value
        var align = 'center';
        var baseline = 'middle';
        // var size = '15';
        var height = '1';
        var offsetX = 0; //parseInt('0', 10);
        var offsetY = -(zoom+5); //parseInt('-13', 10);
        var weight = 'bold';
        var rotation = parseFloat('0');
        var font = weight + ' ' + size + 'px Arial';
        var fillColor = '#000';
        var outlineColor = '#fff';
        var outlineWidth = 4;

        return new ol.style.Style({
            image: new ol.style.Circle({
                radius: zoom * 0.45,
                fill: new ol.style.Fill({color: '#f87b00'}),
                stroke: new ol.style.Stroke({color: '#FFF', width: 2}),
                scale: (1 /  window.devicePixelRatio)
            }),
            text: new ol.style.Text({
                textAlign: 'center',
                textBaseline: 'middle',
                placement: 'point',
                font: font,
                text: feature.get('param_value'),
                fill: new ol.style.Fill({color: '#000'}),
                stroke: new ol.style.Stroke({color: '#fff', width: 7}),
                offsetX: offsetX,
                offsetY: offsetY,
                rotation: 0
            })
        });
    }

    /**
     * Style function for wind marker in live mode
     *
     * @param {object} Map feature
     *
     * @return {Array} Array of map styles
     */
    function windStyleFunction(feature) {

        var coef = 1.7;
        if(isPortrait()){
            coef = 2;
        }

        var zoom = map.getView().getZoom();
        var size = zoom * coef; // arbitrary value
        var align = 'center';
        var baseline = 'middle';
        // var size = '15';
        var height = '1';
        var offsetX = 0; //parseInt('0', 10);
        var offsetY = -(zoom+10); //parseInt('-13', 10);
        var weight = 'bold';
        var rotation = parseFloat('0');
        var font = weight + ' ' + size + 'px Arial';
        var fillColor = '#000';
        var outlineColor = '#fff';
        var outlineWidth = 7;

        var img_src;
        if(feature.get('param_dir') != null ){
            img_src='/node_modules/openlayers/v5.3.0-dist/icons/arrow-wind.png';
        }
        else{
            img_src='/node_modules/openlayers/v5.3.0-dist/icons/arrow-wind-empty.png';
        }

        // push different styles
        // - one for the arrow icon
        // - one for the text
        var styleArray = [];
        styleArray.push(
            new ol.style.Style({
                text: new ol.style.Text({
                    font: 'normal 900 24px/1 "Font Awesome 6 Pro"',
                    text: String.fromCharCode(parseInt('f063', 16)), // f063
                    rotation: feature.get('param_dir') * 0.01745,
                    fill: new ol.style.Fill({
                        color: '#000000'
                        // color: fontColors[(map.getLayers().getLength()-3) % fontColors.length]
                    }),
                    stroke: new ol.style.Stroke({
                        color: 'white',
                        width: 3
                    })
                })
            })
        );

        styleArray.push(
            new ol.style.Style({
                text: new ol.style.Text({
                    textAlign: 'center',
                    textBaseline: 'middle',
                    placement: 'point',
                    font: font,
                    text: feature.get('param_value'),
                    fill: new ol.style.Fill({color: '#000'}),
                    stroke: new ol.style.Stroke({color: '#fff', width: 7}),
                    offsetX: offsetX,
                    offsetY: offsetY,
                    rotation: 0
                })
            })
        );

        return styleArray;
    }

    /**
     * Style function for default marker in "indicatori" mode
     *
     * @param {object} Map feature
     *
     * @return {object} Map style
     */
    function indicatorStyleFunction(feature) {

        var coef = 1;

        var zoom = map.getView().getZoom();
        var color = getColor(feature.get('param_value'));
        color = ol.color.asArray(color);
        color = color.slice();
        color[3] = 1;

        return new ol.style.Style({
            image: new ol.style.Circle({
                radius: zoom * coef,
                fill: new ol.style.Fill({color: color}),
                stroke: new ol.style.Stroke({color: '#FFF', width: 2}),
            })
        });
    }

    /**
     * Function that load stations LIST
     * No args needed
     */
    function loadStationsList(){
        console.log('ajax');

        // clear rable
        if(table)
            table.clear();

        // get region and province id to filter stations
        var regid = parseInt($('#select-region').val());
        var provid = parseInt($('#select-prov').val());

        // get data via an ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_stations_list',
            type: "post",
            dataType: "json",
            data: {
                regid: regid,
                provid: provid
            }
        })
        .done(function(result) {
            // check result
            // if OK then fill main table with retrieved data
            if( result.res == 'OK' ){

                var stations = result.stations;
                // check if there is at least one station
                if ( stations.length > 0 ){
                    // variable for dinamically building the html
                    var html = '';
                    // loop through all elements
                    // for each station create the html row to be added on the datatable
                    $.each(stations, function(index, value) {

                        html += '<tr data-id="'+value.station_id+'" data-idx="'+value.layer_order+'">';
                        html += '    <td><a href="/str_dataview_station/'+value.station_id+'">'+value.station_id+'</a></td>';
                        html += '    <td><a href="/str_dataview_station/'+value.station_id+'">'+value.station_name+'</a></td>';
                        html += '    <td>'+value.province_code+'</td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object and redraw it
                    table.rows.add($( html ));
                    // adjust columns size
                    table.columns.adjust();
                }

                // refresh table
                table.draw();
            }
            else{
                // refresh table
                table.draw();
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
     * Function that loads stations LIVE data
     *
     * @param {integer} prid: Parameter ID
     * @param {text} aggr: Time aggregation
     */
    function loadStationsData(prid, aggr){
        console.log('ajax');

        // reset visibility of layers
        var baseLayer = getLayerByName('Standard', map);
        if(! baseLayer.getVisible()){
            baseLayer.setVisible(true);

            baseLayer = getLayerByName('Indicatori', map);
            baseLayer.setVisible(false);
            baseLayer = getLayerByName('Topografia', map);
            baseLayer.setVisible(false);
        }

        // remove all layers and add a new one
        removeAllLayers(map);
        var vectorLayer = new ol.layer.Vector({
            source:new ol.source.Vector({
                features: [ ]
            })
        });
        vectorLayer.set('name', 'Stazioni');
        map.addLayer(vectorLayer);

        // set different style based on selected parameters
        if (prid == 10) // wind
            vectorLayer.setStyle(windStyleFunction);
        else
            vectorLayer.setStyle(pointStyleFunction);

        // get data via an ajx call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_map_last_data',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                aggr: aggr
            }
        })
        .done(function(result) {
            // check result
            // if OK then fill map with retrieved data
            if( result.res == 'OK' ){

                var stations = result.stations;

                // check if at least one station exists
                if ( stations.length > 0 ){

                    // loop through all elements
                    // for each station create the feature to be added on the map
                    $.each(stations, function(index, value) {

                        var feature = new ol.Feature({
                            geometry: new ol.geom.Point(ol.proj.transform([parseFloat(value.marker_lon), parseFloat(value.marker_lat)], 'EPSG:4326', 'EPSG:3857')),
                            type: value.marker_type,
                            name: value.marker_name,
                            description: value.marker_desc,
                            logo: value.marker_logo,
                            icon: value.marker_icon,
                            fill: new ol.style.Fill({color: '#f87b00'}),
                            stroke: new ol.style.Stroke({color: '#FFF', width: 3}),
                            param_value: value.marker_value,
                            param_dir: value.marker_dir,
                            param_unit: value.marker_unit,
                            popup_flag: value.marker_flag_popup
                        });

                        // set marker id for search and filtering purposes
                        feature.setId(value.marker_id);

                        vectorLayer.getSource().addFeature(feature);
                    });
                    // setTimeout(function(){
                    //     // zoom to markers at the end of loop
                    //     zoomToMarkers(map);
                    // }, 50);
                }

                // at the end of the process hide preloader
                $("#dataview-preloader").hide();
            }
            else{
                // at the end of the process hide preloader
                $("#dataview-preloader").hide();
                // error message
                swal("Errore!", result.message, "error");
            }
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that loads stations INDICATORI data
     *
     * @param {integer} prid: Parameter ID
     * @param {text} stat: Statistic type
     */
    function loadStationsIndicators(prid, stat){
        console.log('ajax');

        // reset visibility of layers
        var baseLayer = getLayerByName('Indicatori', map);
        if(! baseLayer.getVisible()){
            baseLayer.setVisible(true);

            baseLayer = getLayerByName('Standard', map);
            baseLayer.setVisible(false);
            baseLayer = getLayerByName('Topografia', map);
            baseLayer.setVisible(false);
        }

        // remove all layers and add a new one
        removeAllLayers(map);
        var vectorLayer = new ol.layer.Vector({
            source:new ol.source.Vector({
                features: [ ]
            })
        });
        // set layer name
        vectorLayer.set('name', 'Stazioni');
        map.addLayer(vectorLayer);

        // set layer style
        vectorLayer.setStyle(indicatorStyleFunction);

        // retrieve data via an ajax call
        var jqxhr = $.ajax({
            url: '/str_dataview_get_map_indicators',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                stat: stat
            }
        })
        .done(function(result) {

            // check result
            // if OK then fill map with retrieved data
            if( result.res == 'OK' ){

                var stations = result.stations;
                legend = result.legend;

                // get parameter name from clicked button
                var param = $('#hover-bottom-indicatori .active span').text();
                // format string
                param = param.substring(0, 5);
                param = param.trim().replace('.', '');
                param = param.toLowerCase();

                // lopp through all elements and dynamically create legend
                $.each(legend, function(index, el) {

                    // formattin text
                    var chk_lower = el.legend_lower ? ' ['+ param+' '+ el.legend_lower : ' [';
                    var chk_upper = el.legend_upper ? param+' '+ el.legend_upper+']' : ']';

                    var separator = '';
                    if (el.legend_lower && el.legend_upper)
                        separator = ' e ';

                    var rangeString = chk_lower+separator+chk_upper;

                    el.legend_desc;
                    var legendDesc;
                    if(el.legend_desc && el.legend_desc != '')
                        legendDesc = el.legend_desc+' '+rangeString.trim();
                    else
                        legendDesc = rangeString.trim();

                    legendDesc = legendDesc.replace('==', '= ');
                    legendDesc = legendDesc.replace('<=', '≤ ');
                    legendDesc = legendDesc.replace('>=', '≥ ');
                    legendDesc = legendDesc.replace('<', '< ');
                    legendDesc = legendDesc.replace('>', '> ');

                    // add new label to legend
                    mapLegend.addItem({
                        title: legendDesc,
                        typeGeom: 'Point',
                        style: new ol.style.Style({
                            image: new ol.style.Circle({
                                radius: 8,
                                fill: new ol.style.Fill({color: el.legend_color}),
                                stroke: new ol.style.Stroke({color: '#000', width: 1}),
                            })
                        })
                    });
                });

                // check if at least one station exists
                if ( stations.length > 0 ){

                    // loop through all stations
                    // for each element create a feature to be added on the map
                    $.each(stations, function(index, value) {

                        var feature = new ol.Feature({
                            geometry: new ol.geom.Point(ol.proj.transform([parseFloat(value.marker_lon), parseFloat(value.marker_lat)], 'EPSG:4326', 'EPSG:3857')),
                            type: value.marker_type,
                            id: value.marker_id,
                            name: value.marker_name,
                            logo: value.marker_logo,
                            description: value.marker_desc,
                            param_value: value.marker_value,
                            param_dir: value.marker_dir,
                            param_unit: value.marker_unit,
                            // param_color: getColor(value.marker_value),
                            popup_flag: value.marker_flag_popup
                        });

                        // set marker id for search and filtering purposes
                        feature.setId(value.marker_id);

                        vectorLayer.getSource().addFeature(feature);
                    });

                    // setTimeout(function(){
                    //     // zoom to markers at the end of loop
                    //     zoomToMarkers(map);
                    // }, 50);

                }
            }
            else{
                // error message
                swal("Errore!", result.message, "error");
            }

            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that loads all stations that acquire the selected parameters
     *
     * @param {array} arrayParams: array of selected parameters
     */
    function loadStations(arrayParams){

        // reset visibility of layers
        var baseLayer = getLayerByName('Standard', map);
        if(! baseLayer.getVisible()){
            baseLayer.setVisible(true);

            baseLayer = getLayerByName('Indicatori', map);
            baseLayer.setVisible(false);
            baseLayer = getLayerByName('Topografia', map);
            baseLayer.setVisible(false);
        }

        // remove all layers from the map
        removeAllLayers(map);

        // get stations via an ajax call
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/str_dataview_get_map_stations',
            type: "post",
            dataType: "json",
            data: {
                params: JSON.stringify(arrayParams)
            }
        })
        .done(function(result) {
            var stations = result.stations;
            // check result
            // if OK then fill map with retrieved data
            if( result.res == 'OK' ){
                // check if at least one station exists
                if ( stations.length > 0 ){
                    // for each station create a feature to be added on the map
                    $.each(stations, function(index, value) {
                        addMapPoint(value, value.marker_layer, map );
                    });
                }

                // at the end of loop zoom to markers
                setTimeout(function(){
                    // get selected region
                    var regid = parseInt($('#select-region').val());
                    // if it exists then zoom to region
                    // else zoom to all visible markers
                    if(regid != -1 ){
                        zoomToRegion(map, regid);
                    }
                    else{
                        zoomToMarkers(map);
                    }
                }, 50);
            }
            else{
                // error message
                swal("Errore!", result.message, "error");
            }

            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $("#dataview-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero delle stazioni", "error");

        });
    }

    /**
     * Function that returns the color based on marker value: used for INDICATORI view
     *
     * @param {text} value: Marker value
     *
     * @return {text} color: Hexadecimal color
     */
    function getColor(value){

        // set default color
        var color = '#7F7F7F';

        // check value
        // if null then return default color
        // else return a specific one
        if(value == 'n.d.'){
            return color;
        }
        else{

            // the value is compared with legend ranges
            // when the value respects the legend range then return the corresponding color
            legend.forEach(function(el, index){

                // build lower and upper range rules
                var chk_lower = el.legend_lower ? value +' '+ el.legend_lower : 'true';
                var chk_upper = el.legend_upper ? value +' '+ el.legend_upper : 'true';

                if(eval(chk_lower) && eval(chk_upper)){
                    color =  el.legend_color;
                }

            });
        }

        return color;
    }

    /**
     * Function that clears the map legend
     * No args needed
     */
    function resetLegend(){
        // get the number of items inside the map legend
        var legendLen = mapLegend.getItems().getLength();

        // start from the last item and loop up to the first one (excluded)
        // for each item, remove it from the legend array
        for(i = 1; i < legendLen; i++){
            mapLegend.getItems().pop();
        }
        return;
    }

});
