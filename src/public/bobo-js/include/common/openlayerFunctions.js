// preload icons
document.fonts.load('normal 900 32px/1 "Font Awesome 6 Pro"', String.fromCharCode(parseInt('f3c5', 16))).then(console.log('loaded...')); // <i class="fa-solid fa-location-dot"></i>
document.fonts.load('normal 900 32px/1 "Font Awesome 6 Pro"', String.fromCharCode(parseInt('f3b3', 16))).then(console.log('loaded...')); // <i class="fa-solid fa-ghost"></i>
document.fonts.load('normal 900 32px/1 "Font Awesome 6 Pro"', String.fromCharCode(parseInt('f495', 16))).then(console.log('loaded...')); // <i class="fa-solid fa-ghost"></i>
document.fonts.load('normal 900 32px/1 "Font Awesome 6 Pro"', String.fromCharCode(parseInt('f0d1', 16))).then(console.log('loaded...')); // <i class="fa-solid fa-truck"></i>
document.fonts.load('normal 900 32px/1 "Font Awesome 6 Pro"', String.fromCharCode(parseInt('f6e2', 16))).then(console.log('loaded...')); // <i class="fa-solid fa-ghost"></i>

// "\uf34e" mdi-map-marker
// "\uf390" mdi-navigation
// "\uf045" mdi-arrow-down
// "\uf046" mdi-arrow-down-bold

// add projections
proj4.defs(
  'EPSG:23032', // ED50 UTM 32N
  '+proj=utm +zone=32 +ellps=intl ' +
    '+towgs84=-87,-98,-121,0,0,0,0 +units=m +no_defs'
);
proj4.defs(
    'EPSG:3003', // MONTE MARIO
    '+proj=tmerc +lat_0=0 +lon_0=9 +k=0.9996 +x_0=1500000 +y_0=0 +ellps=intl ' +
    '+towgs84=-104.1,-49.1,-9.9,0.971,-2.917,0.714,-11.68 +units=m +no_defs'
);

ol.proj.proj4.register(proj4);

ol.proj.get('EPSG:23032').setExtent([-1206118.71, 4021309.92, 1295389.0, 8051813.28]);
ol.proj.get('EPSG:3003' ).setExtent([1290650.93, 4192956.42, 2226749.10, 5261004.57]);


// Italy bounds
var swLat = 36.137;
var swLong = 6.350;
var neLat = 47.070;
var neLong = 18.435;

// Region extents
var regionsExtents = [];
regionsExtents[0] = [[6.350, 36.137], [18.435, 47.070]]; // 'Italy'
// regionsExtents[1] = [[6.586304, 44.016521], [9.420776, 46.468133]]; // 'Piemonte'
regionsExtents[2] = [[6.475, 45.307], [8.371, 46.111]]; // 'Valle d''Aosta'
// regionsExtents[3] = [[8.470459, 44.645208], [11.425781, 46.611715]]; // 'Lombardia'
regionsExtents[4] = [[10.305176, 45.660127], [12.447510, 47.100045]]; // 'Trentino Alto Adige'
regionsExtents[5] = [[10.656738, 44.902578], [13.095703, 46.634351]]; // 'Veneto'
regionsExtents[6] = [[12.334900, 45.533289], [14.004822, 46.747389]]; // 'Friuli-Venezia Giulia'
regionsExtents[7] = [[7.465210, 43.707594], [10.063477, 44.629573]]; // 'Liguria'
regionsExtents[8] = [[9.217529, 43.739352], [12.799072, 45.089036]]; // 'Emilia Romagna'
regionsExtents[9] = [[9.843750, 42.301690], [12.238770, 44.488668]]; // 'Toscana'
regionsExtents[10] = [[11.958618, 42.330124], [13.265991, 43.620171]]; // 'Umbria'
regionsExtents[11] = [[12.282715, 42.650122], [13.754883, 44.036270]]; // 'Marche'
regionsExtents[12] = [[11.458740, 41.129021], [13.919678, 42.884015]]; // 'Lazio'
regionsExtents[13] = [[13.062744, 41.648288], [14.743652, 42.940339]]; // 'Abruzzo'
// regionsExtents[14] = [[], []]; // 'Molise'
regionsExtents[15] = [[13.831787, 39.977120], [15.699463, 41.557922]]; // 'Campania'
regionsExtents[16] = [[14.963379, 39.774769], [18.489990, 41.910453]]; // 'Puglia'
// regionsExtents[17] = [[], []]; // 'Basilicata'
// regionsExtents[18] = [[], []]; // 'Calabria'
// regionsExtents[19] = [[], []]; // 'Sicilia'
regionsExtents[20] = [[8.085938, 38.822591], [9.821777, 41.310824]]; // 'Sardegna'

// Aosta
var aoNorth = 5066425;
var aoEast = 369397;
//
// var extent;

// var icons = [
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-red.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-def.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-green.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-violet.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-orange.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-azure.png',
//     '/node_modules/openlayers/v5.3.0-dist/icons/marker-icon-yellow.png'
// ];

var fontColors = [
    '#BF8E08',
    '#DC5A08',
    '#023F78',
    '#79A030',
    '#C70302',
    '#A700D0',
    '#E8BC03',
    '#2293B5',
    '#5E3300',
    '#04C6C8',
    '#01651D',
    '#E70660',
    '#B7A0A0',
    '#99AFE8',
    '#942A00',
    '#B4BB00',
    '#D395DE',
    '#450759',
    '#1CCE78',
    '#B40243',
    '#03D4FF',
    '#6A2CAB',
    "#FF0000", // Rosso
    '#DC7C08',
    '#A24567',
    '#708090',
    "#FF69B4",
    "#6495ED",
    "#008080",
    "#FFDAB9",
    "#90EE90",
    "#333333"
];

// INITIALIZATION OF THE MAP

/**
 * Function that creates the map.
 *
 * @param {text} target id of the html container.
 * @param {text} attributions .
 *
 * @return map object
 */
function initMap(target, attributions) {

    console.log('initMap');
    console.log('Region: '+ portal_region);

    var selectedFeature;
    // create first default bounding extent equal to portal region (arriving from server)
    var boundingExtent = ol.extent.boundingExtent( regionsExtents[portal_region] );
    boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

    // create view object
    var view = new ol.View();

    var attributionsFormatted = '';
    if(attributions != null)
        attributionsFormatted = ' - '+attributions;

    // create default baselayers
    var satellite = new ol.layer.Tile({
        name: 'Satellite',
        source: new ol.source.XYZ({
            attributionsCollapsible: true,
            attributions: 'Esri, Maxar, Earthstar Geographics, CNES/Airbus DS, USDA FSA, USGS, Getmapping, Aerogrid, IGN, IGP, and the GIS User Community'+attributionsFormatted,
            url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            maxZoom: 23
        }),
        baseLayer: true,
        visible: false
    });

    var hiking = new ol.layer.Tile({
        name: 'Topografia',
        source: new ol.source.XYZ({
            attributionsCollapsible: true,
            attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors -  <a href="https://opentopomap.org/" target="_blank">OpenTopoMap</a>'+attributionsFormatted,
            url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
            maxZoom: 23
        }),
        baseLayer: true,
        visible: false
    });

    // initialize the map on the "map" div
    var map = new ol.Map({
        target: target,
        layers: [
            new ol.layer.Tile({
                source: new ol.source.OSM({
                    attributionsCollapsible: true,
                    attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors'+attributionsFormatted
                }),
                baseLayer: true,
                name: 'Standard'
            }),
            hiking,
            satellite
        ],
        view: view,
        controls: ol.control.defaults.defaults({attribution: false}).extend(
            [ new ol.control.LayerPopup() ]
        ),
    });

    // fit view to the default extent
    view.fit(boundingExtent, map.getSize());

    /* CONTROLS */
    var fullscreen = new ol.control.FullScreen();
    map.addControl(fullscreen);

    var attribution = new ol.control.Attribution({
        collapsible: true
    });

    map.addControl(attribution);
    /* END CONTROLS */


    /* POPUP */
    var container = document.getElementById('popup'),
        content_element = document.getElementById('popup-content');

    // console.dir($(container).parent().attr('id'));
    // console.log(target);

    // build overlay object if parent id it's equal to the map container
    if($(container).parent().attr('id') == target){
        var overlay = new ol.Overlay({
            id: 'popup',
            element: container,
            // autoPan: true, // disable autofocus on popup
            offset: [0.5, -45.5]
        });

        map.addOverlay(overlay);
        overlay.set('type', 'hover');

        // mouse over event
        map.on('pointermove', function(evt){
            // get nearest feature by pixel
            var feature = map.forEachFeatureAtPixel(evt.pixel,
                function(feature, layer) {
                    return feature;
                }
            );

            // take care of the type of overlay
            // if hover then show a temporary popup with few information
            if( overlay.get('type') == 'hover' ){
                // if feature is not null and it has popup option enable
                // then show popup
                // else hide it and reset selectedFeature variable
                if (feature && feature.get('popup_flag')) {

                    // if selected feaure if different from the previous one then reset its style
                    if(selectedFeature != null && selectedFeature.getId() != feature.getId() ){
                                selectedFeature.setStyle(null);
                    }
                    selectedFeature = feature;
    
                    var geometry = feature.getGeometry();
                    var coord = geometry.getCoordinates();
                    var coord_formatted =  ol.proj.transform(coord, ol.proj.get('EPSG:3857'), ol.proj.get('EPSG:4326'));

                    // show popup with prebuild content
                    var content;
                    if(feature.get('hover') != null)
                       content = feature.get('hover')
                    else{
                        content = '<h4>' + feature.get('name') + '</h4>';
                        content += '<p>';
                        if(feature.get('suspended'))
                            content += '<strong class="text-danger">SOSPESA</strong><br>';
                        // content += '<p><strong>Coordinate </strong>: '+ parseFloat(coord_formatted[1]).toFixed(3) +', '+parseFloat(coord_formatted[0]).toFixed(3)+'</p>';
                        content += '<strong>Rete </strong>: '+ feature.get('network')+'</p>';

                    }
    
                    content_element.innerHTML = content;
                    overlay.setPosition(coord);
    
                    selectedFeature.setStyle(selectedPointStyleFunction);
                    // console.info(feature.getProperties());
                }
                else{
                    overlay.setPosition(undefined);
                    if(selectedFeature != null ){
                        selectedFeature.setStyle(null);
                        selectedFeature = null;
                    }
                }
            }
        });

        // mouse click event
        map.on('click', function(evt){
            // get nearest feature by pixel
            var feature = map.forEachFeatureAtPixel(evt.pixel,
                function(feature, layer) {
                    return feature;
                }
            );

            // if feature is not null and it has popup option enable
            // then show popup
            // else hide it and reset selectedFeature variable
            if (feature && feature.get('popup_flag')) {

                // if selected feaure is not null then reset its style
                if(selectedFeature != null){
                    selectedFeature.setStyle(null);
                    selectedFeature = null;
                }
                selectedFeature = feature;

                var geometry = feature.getGeometry();
                var coord = geometry.getCoordinates();
                var coord_formatted =  ol.proj.transform(coord, ol.proj.get('EPSG:3857'), ol.proj.get('EPSG:4326'));

                // show popup with prebuild content
                var content = feature.get('description');
                content_element.innerHTML = content;
                overlay.setPosition(coord);
                overlay.set('type', 'click');
    
                selectedFeature.setStyle(selectedPointStyleFunction);
            }
            else{
                overlay.setPosition(undefined);
                overlay.set('type', 'hover');
    
                if(selectedFeature != null ){
                    selectedFeature.setStyle(null);
                    selectedFeature = null;
                }
            }
        });
    }
    /* END POPUP */

    // extent = null;
    return map;
}

// STYLE
/**
 * Function that converts hexadecimal color to RGBA
 *
 * @param {text} hex Hexadecimal
 * @param {real} alpha
 *
 * @return rgba code
 */
function hexToRgbA(hex, alpha){
    var c;
    if(/^#([A-Fa-f0-9]{3}){1,2}$/.test(hex)){
        c= hex.substring(1).split('');
        if(c.length== 3){
            c= [c[0], c[0], c[1], c[1], c[2], c[2]];
        }
        c= '0x'+c.join('');
        return 'rgba('+[(c>>16)&255, (c>>8)&255, c&255].join(',')+','+alpha+')';
    }
    throw new Error('Bad Hex');
}

/**
 * Function for the default style marker.
 *
 * @param {obj} feature
 *
 * @return new style object
 */
function defaultStyleFunction(feature){
    return new ol.style.Style({
        text: new ol.style.Text({
            // font: "normal normal normal 36px/1 Material Design Icons",
            font: 'normal 900 32px/1 "Font Awesome 6 Pro"',
            text: String.fromCharCode(parseInt('f3c5', 16)), //mdi-map-marker
            textBaseline: 'bottom',
            fill: new ol.style.Fill({
                color: fontColors[1]
            }),
            stroke: new ol.style.Stroke({
                color: 'white',
                width: 2
            })
        }),
        zIndex: 0
    });
}

/**
 * Function for multiple layer case
 *
 * @param {obj} feature
 *
 * @return new style object
 */
function multiplePointsStyleFunction(feature) {
    var icon = feature.get('icon');
    var size = 32;
    if (icon == 'f0d1' || icon == 'f495')
        size = 28;

    return new ol.style.Style({
        text: new ol.style.Text({
            // font: "normal normal normal "+size+"px/1 Material Design Icons",
            font: 'normal 900 '+size+'px/1 "Font Awesome 6 Pro"',
            text: String.fromCharCode(parseInt(icon, 16)), //mdi-map-marker
            // offsetY: -25,
            textBaseline: 'bottom',
            fill: new ol.style.Fill({
                color: fontColors[feature.get('color') % fontColors.length]
            }),
            stroke: new ol.style.Stroke({
                color: 'white',
                width: 2
            })
        })
    });
}

/**
 * Function for selected feature
 *
 * @param {obj} feature
 *
 * @return new style object
 */
function selectedPointStyleFunction(feature) {

    return new ol.style.Style({
        text: new ol.style.Text({
            font: 'normal 900 38px/1 "Font Awesome 6 Pro"',
            text: String.fromCharCode(parseInt(feature.get('icon'), 16)),
            // offsetY: -25,
            textBaseline: 'bottom',
            fill: new ol.style.Fill({
                color: '#4c5153'
            }),
            stroke: new ol.style.Stroke({
                color: 'white',
                width: 2
            })
        }),
        zIndex: 9999
    });
}

// LAYERS
/**
 * Function that calculates how many baselayers exist
 *
 * @param {obj} map
 *
 * @return number of base layers
 */
function getHowManyBaselayers(map){

    var counter= 0;
    map.getLayers().getArray().forEach(function(layer) {
        // console.dir(layer);
        if( layer.get('baseLayer') ){
            counter++;
        }
    });

    return counter;
}

/**
 * Function that returns a layer by index
 *
 * @param {integer} idx Layer index
 * @param {obj} map
 *
 * @return layer object
 */
function getLayerByIdx(idx, map){
    return map.getLayers().getArray()[idx];
}

/**
 * Function that returns a layer by name
 *
 * @param {text} name Layer name
 * @param {obj} map
 *
 * @return layer object
 */
function getLayerByName(name, map){
    var result;

    map.getLayers().getArray().forEach(function(layer) {

        if( layer.get('name') == name ){
           result = layer;
        }
    });

    return result;
}

/**
 * Function that creates a new layer
 *
 * @param {text} name Layer name
 * @param {integer} id Layer identifier
 * @param {obj} map
 *
 * @return layer object
 */
function createLayer(name, id, map) {

    // var layerStyle =  new ol.style.Style({
    //     text: new ol.style.Text({
    //         font: "normal normal normal 36px/1 Material Design Icons",
    //         text: "\uf34e", //String.fromCharCode(parseInt(el.marker_icon, 16)), //mdi-map-marker
    //         textBaseline: 'bottom',
    //         fill: new ol.style.Fill({
    //             color: fontColors[(map.getLayers().getLength()-3) % fontColors.length]
    //         }),
    //         stroke: new ol.style.Stroke({
    //             color: 'white',
    //             width: 2
    //         }),
    //     }),
    //     zIndex: 0
    // });

    var vectorLayer = new ol.layer.Vector({
        id: id,
        source:new ol.source.Vector({
            features: [ ]
        }),
        style: multiplePointsStyleFunction
    });

    vectorLayer.set('name', name);

    map.addLayer(vectorLayer);

    return vectorLayer;
}

/**
 * Function that removes all layers from map except the baselayers
 *
 * @param {obj} map
 *
 * @return layer object
 */
function removeAllLayers(map){

    var nLayers = map.getLayers().getArray().length;
    var layersArray = map.getLayers().getArray();

    for(var idx = nLayers; idx > 0; idx--){
        // console.log(idx);
        var layer = layersArray[idx-1];
        if( ! layer.get('baseLayer') ){
            layer.getSource().clear();
            map.removeLayer(layer);
        }
    }
}

// OVERLAY
/**
 * Function that reset popup elements
 *
 * @param {obj} map
 */
function resetOverlayPopup(map){

    console.log('resetOverlayPopup');
    var overlay = map.getOverlayById('popup');

    overlay.setPosition(undefined);
    overlay.set('type', 'hover');

    return;
}

// POINT
/**
 * Function that adds new marker to the map
 *
 * @param {obj} el Element to be added with information from the server
 * @param {text} layer Layer name
 * @param {obj} map
 *
 */
function addMapPoint(el, layer, map) {

    var vectorLayer = getLayerByName(layer, map);

    // If Layer does not exist, create it
    if(vectorLayer == null)
        vectorLayer = createLayer(layer, el.marker_layer_id, map);

    var feature = new ol.Feature({
        id: el.marker_id,
        type: el.marker_type,
        name: el.marker_name,
        hover: el.marker_hover,
        description: el.marker_desc,
        network: el.marker_layer,
        logo: el.marker_logo,
        icon: el.marker_icon,
        color:el.marker_layer_id,
        suspended: el.marker_suspended,
        popup_flag: el.marker_flag_popup,
        geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.marker_lon), parseFloat(el.marker_lat)], 'EPSG:4326', 'EPSG:3857'))
    });

    feature.setId(el.marker_id);
    vectorLayer.getSource().addFeature(feature);

    return;
}

/**
 * Function that adds a new draggable marker to the map
 *
 * @param {obj} el Element to be added with information from the server
 * @param {text} layer Layer name
 * @param {obj} map
 *
 * @return layer object
 */
function addDraggablePoint(el, layer, map) {

    var feature = new ol.Feature({
        type: el.marker_type,
        name: el.marker_name,
        description: el.marker_desc,
        popup_flag: el.marker_flag_popup,
        geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.marker_lon), parseFloat(el.marker_lat)], 'EPSG:4326', 'EPSG:3857'))
    });

    feature.setId(el.marker_id);

    var vectorLayer = getLayerByName(layer, map);

    // If Layer does not exist, create it
    if(vectorLayer == null)
        vectorLayer = createLayer(layer, map);

    vectorLayer.getSource().addFeature(feature);

    return;
}

/**
 * Function for fitting map view to available markers
 *
 * @param {obj} map
 */
function zoomToMarkers(map) {

    console.log('zoomToMarkers');
    var newBound = null;
    map.getLayers().getArray().forEach(function(layer) {

        //resetConsole();
        //console.dir(layer);
        //console.log(layer.get('type'));   //-> tile
        //console.log(layer.get('origin')); // -> wms
        //console.log(layer.layer_type);    // might be null for tile layers from geoserver (shapes)

        //if( ! layer.get('baseLayer') && (layer.layer_type && layer.layer_type != 'TileWMS')){
        // @ 2022-12-21 10:31
        if( ! layer.get('baseLayer') && layer.get('type') != 'tile'){
            var myExtent = layer.getSource().getExtent();
            //var myExtent = layer.getExtent();
            if(newBound == null)
                newBound = myExtent;
            else
                ol.extent.extend(newBound, myExtent);
            // if (layer.getSource().getFeatures().length > 0) {
            // }
        }
    });

    if(newBound != null ){
        map.getView().fit(newBound, {
            size: map.getSize(),
            maxZoom: 18,
            padding: [30, 30, 30, 30]
            // constrainResolution: true,
            // duration: 1000,
            // nearest: true
        });

        map.getView().setZoom(map.getView().getZoom()-0.1);
    }

    return;
}

/**
 * Function for fitting map view to Italy
 *
 * @param {obj} map
 */
function zoomToItaly(map) {

    // zoomToMarkers(mapSel);
    var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
    boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

    map.getView().fit(boundingExtent, {
        size: map.getSize(),
        // constrainResolution: true,
        nearest: true
    });
}

/**
 * Function for fitting map view to VDA region
 *
 * @param {obj} map
 */
function zoomToVDA(map) {
    // extent Valle d'Aosta
    var swLat = 45.307;
    var swLong = 6.475;
    var neLat = 46.111;
    var neLong = 8.371;

    // zoomToMarkers(mapSel);
    var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
    boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

    map.getView().fit(boundingExtent, {
        size: map.getSize(),
        // constrainResolution: true,
        nearest: true
    });
}

/**
 * Function for fitting map view to specific region
 *
 * @param {obj} map
 * @param {integer} regId region identifier
 */
function zoomToRegion(map, regId) {

    var boundingExtent;
    if(regionsExtents[regId] != null){
        boundingExtent = ol.extent.boundingExtent(regionsExtents[regId]);
        boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));
    }
    else{
        boundingExtent = ol.extent.boundingExtent(regionsExtents[0]);
        boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));
    }

    map.getView().fit(boundingExtent, {
        size: map.getSize(),
        // constrainResolution: true,
        nearest: true
    });
}

/**
 * Function that calculates coordinates of the cent of the extent
 *
 * @param {obj} Extent
 *
 * @return array of coordinates
 */
function getCenterOfExtent(Extent){
    var X = Extent[0] + (Extent[2]-Extent[0])/2;
    var Y = Extent[1] + (Extent[3]-Extent[1])/2;

    return [X, Y];
}





// CHANGE VIEW
// function flyTo(location, map) {

//     var duration = 2000;
//     var view = map.getView();
//     var zoom = view.getZoom();

//     view.animate({
//         center: location,
//         duration: duration
//     });

//     view.animate({
//         zoom: zoom - 1,
//         duration: duration / 2
//     }, {
//         zoom: zoom,
//         duration: duration / 2
//     });

// }