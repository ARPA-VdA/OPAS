$(document).ready(function() {
    // create new instance of MapSelector
    var m = new MapSelector();

    // add intercations
    // TRANSLATE
    var translate = new ol.interaction.Translate();
    m.map.addInteraction(translate);
    translate.on('translateend', function (evt) {

        var coords_UTM = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:23032'));
        var coords_WGS84 = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:4326'));

        m.coordsUTM = coords_UTM;
        // from [lon,lat] to [lat,lon]
        m.coordsWGS84 = coords_WGS84.reverse();
    });
    // TRANSLATE END

    // CLICK
    m.map.on("click", function (evt) {
        // get coordinates at click point
        var coords = evt.coordinate;

        var feature = new ol.Feature({
            popup_flag: false,
            geometry: new ol.geom.Point([parseFloat(coords[0]), parseFloat(coords[1])])
        });
        // clear layer
        m.layer.getSource().clear();
        m.layer.getSource().addFeature(feature);
        // transform coordinates in WGS84 and UTM projectios
        var coords_UTM = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:23032'));
        var coords_WGS84 = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:4326'));

        m.coordsUTM = coords_UTM;
        // from [lon,lat] to [lat,lon]
        m.coordsWGS84 = coords_WGS84.reverse();
    });
    // CLICK END

    // bootstrap "shown" event
    $('#map-modal').on('shown.bs.modal', function (e) {

        m.refreshMap();
    });

    // bootstrap "hidden" event
    $('#map-modal').on('hidden.bs.modal', function (e) {

        m.clearMap(true);
    });

    // click event on modal button "ED50"
    $('#map-modal').on('click', '#map-submit-utm', function (e) {
        e.preventDefault();

        // fill fields with coordinates
        $('#'+m.fields[0]).val(parseInt(m.coordsUTM[0])).trigger('change');
        $('#'+m.fields[1]).val(parseInt(m.coordsUTM[1])).trigger('change');
        // hide modal
        $('#map-modal').modal('hide');
    });

    // click event on modal button "WGS84"
    $('#map-modal').on('click', '#map-submit-wgs', function (e) {
        e.preventDefault();

        // fill fields with coordinates
        $('#'+m.fields[0]).val(m.coordsWGS84[0].toFixed(6)).trigger('change');
        $('#'+m.fields[1]).val(m.coordsWGS84[1].toFixed(6)).trigger('change');
        // hide modal
        $('#map-modal').modal('hide');
    });

    // click event on button for opening the modal
    $('#main-wrapper').on('click', '.open-map-selector', function(e){
        e.preventDefault();
        // retrieve form fields
        m.fields = $(this).data('fields');

        // check if not empty
        if($('#'+m.fields[0]).val() != '' && $('#'+m.fields[1]).val() != ''){
            var coord1 = parseFloat($('#'+m.fields[0]).val());
            var coord2 = parseFloat($('#'+m.fields[1]).val());

            var coords;
            // check if coordinates are in WGS projection
            if( m.checkWGSBounds(coord1, coord2) )
                coords = [coord2, coord1];
            else
                coords = ol.proj.transform([parseInt(coord1), parseInt(coord2)], ol.proj.get('EPSG:23032'), 'EPSG:4326');

            m.addPointOnMap(coords);
        }
    });
});

/**
* MapSelector constructor
* The MapSelector component allows you to create a single object for selecting coordinates from an Openlayer map.
* In order to use the MapSelector it is necessary to include the javascript file /bobo-js/include/common/mapSelector.js in the html page
* and to add a button for opening the modal from which select the coordinates
* The button MUST have the following characteristics:
* - "open-map-selector" class
* - attribute data-target="#map-modal"
* - data-fields attribute with the array of ids of the fields to be filled in e.g. data-fields='["id_field1", "id_field2"]'
*
* The component takes care of:
* - adding the modal's html to the document body;
* - creating the map and managing the click and translate events of a point;
* - filling in the fields with the coordinates in the selected projection
 */
function MapSelector(){
    // add modal html to the document body
    this.addHtmlModal();
    // create map
    // initMap "\public\bobo-js\openlayerFunctions.js"
    this.map = initMap('map-selector', footer);

    // creation of the 'Punto' layer of the map
    // createLayer "\public\bobo-js\openlayerFunctions.js"
    this.layer = createLayer('Punto', 1, this.map);
    this.layer.setStyle(defaultStyleFunction);
    this.layer.setZIndex(999);

    // creation of variables
    this.coordsUTM   = [];
    this.coordsWGS84 = [];
    this.fields = [];

    // retrieve user's position coordinates, if the device is mobile
    this.getMobileLocation();
}

/**
* Add modal html to document body
 */
MapSelector.prototype.addHtmlModal = function(){

    var html = '';
    html += '<!-- MODAL SELECT COORDINATE -->';
    html += '<div class="modal fade" id="map-modal" tabindex="-1" role="dialog" aria-labelledby="map-picker" aria-hidden="true">';
    html += '    <div class="modal-dialog modal-dialog-centered modal-lg" role="document">';
    html += '        <div class="modal-content">';
    html += '            <div class="modal-header">';
    html += '                <h5 class="modal-title text-primary"><i class="far fa-cabinet-filing"></i> Seleziona COORDINATE</h5>';
    html += '                <button type="button" class="close" data-dismiss="modal" aria-label="Close">';
    html += '                    <span aria-hidden="true">&times;</span>';
    html += '                </button>';
    html += '            </div>';
    html += '            <div class="modal-body">';
    html += '                <form class="form form-medium" id="item-form" name="item-form">';
    html += '                    <div class="row">';
    html += '                        <div class="col-md-12">';
    html += '                            <div id="map-selector" class="mini-map map-legend-scrolling" tabindex="0"></div>';
    html += '                        </div>';
    html += '                    </div>';
    html += '                </form>';
    html += '            </div>';
    html += '            <div class="modal-footer">';
    // html += '                <button type="button" class="btn btn-danger" id="map-submit-utm"><i class="fa-sharp fa-solid fa-circle-plus"></i> ED50</button>';
    html += '                <button type="button" class="btn btn-info" id="map-submit-wgs"><i class="fa-sharp fa-solid fa-circle-plus"></i> Inserisci coordinate</button>';
    html += '                <button type="button" class="btn btn-link text-danger" data-dismiss="modal" id="map-cancel"><i class="ti-close"></i> Chiudi</button>';
    html += '            </div>';
    html += '        </div>';
    html += '    </div>';
    html += '</div>';

    $('#main-wrapper').append(html);
}

/**
* Check if the device is mobile and retrieve WGS84 coordinates
* It works only if user gives the geolocation permission to browser
 */
MapSelector.prototype.getMobileLocation = function() {

    if (/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent) && navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(
            this.setPositionOnMap,
            function(e){
                console.dir(e);
            }
        );
    }
    else {
        console.log( "Device not mobile and geolocation is not supported by this browser.");
    }
}

/**
* Add users's position to the map
 */
MapSelector.prototype.setPositionOnMap = function(position) {

    // check if coordinates are into Italy bounds
    if( this.checkWGSBounds(position.coords.latitude, position.coords.longitude) ){

        var coords = [parseFloat(position.coords.longitude), parseFloat(position.coords.latitude)];
        var feature = new ol.Feature({
            popup_flag: false,
            geometry: new ol.geom.Point(ol.proj.transform(coords, 'EPSG:4326', 'EPSG:3857'))
        });

        this.layer.getSource().addFeature(feature);

        // transform coordinates in UTM projectios
        var coords_UTM = ol.proj.transform(coords, 'EPSG:4326', ol.proj.get('EPSG:23032'));
        m.coordsUTM = coords_UTM;
        // from [lon,lat] to [lat,lon]
        m.coordsWGS84 = coords.reverse();
    }
}

/**
* Function that checks if coordinates are into Italy bounds (WGS84)
 */
MapSelector.prototype.checkWGSBounds = function(lat, lon) {
    // Italy display limit coordinates
    // Italy bounds
    const swLat = 36.137;
    const swLong = 6.350;
    const neLat = 47.070;
    const neLong = 18.435;

    return (( lat >= swLat && lat <= neLat ) && ( lon >= swLong && lon <= neLong));
}

/**
* Add point to the map: coordinates are in WGS84 projection
* @param coords: Array of coordinates (longitude, latitude)
 */
MapSelector.prototype.addPointOnMap = function(coords) {

    var feature = new ol.Feature({
        popup_flag: false,
        geometry: new ol.geom.Point(ol.proj.transform(coords, 'EPSG:4326', 'EPSG:3857'))
    });
    // clear layer source (only one marker at time)
    this.layer.getSource().clear();
    this.layer.getSource().addFeature(feature);

    // transform coordinates in UTM projectios
    var coords_UTM = ol.proj.transform(coords, 'EPSG:4326', ol.proj.get('EPSG:23032'));
    this.map.coordsUTM = coords_UTM;

    // from [lon,lat] to [lat,lon]
    this.map.coordsWGS84 = coords.reverse();
}

/**
* Refresh map view
* Usually called at modal "shown" event (bootstrap) in order to refresh the view
 */
MapSelector.prototype.refreshMap = function() {

    this.map.updateSize();
    // zoom view to vda
    zoomToRegion(this.map, portal_region);
}

/**
 * Function that resets map and all variables of the object instance
 */
MapSelector.prototype.clearMap = function() {

    this.layer.getSource().clear();

    zoomToRegion(this.map, portal_region);

    this.coordsUTM   = [];
    this.coordsWGS84 = [];
    this.fields = [];

    // retrieve user position if possibile
    this.getMobileLocation();
}


