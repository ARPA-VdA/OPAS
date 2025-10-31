/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var campaignsTbl;
    var mainMap;

    var mySwitch;
    var myDropzone
    var mapView = [];

    // resize map when changing tab
    $('.nav').on('click', '.nav-item', function(e){
        e.preventDefault();

        var siid = $(this).data('siid');
        if(siid){
            setTimeout(function(){
                mapView[siid].updateSize();
            }, 200);
        }
    });

    // boostraptoggle
    $( "#search-type" ).bootstrapToggle();

    // variable for loadSites function
    var dateTo = moment().add(6, 'days').format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(2, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker filter
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()],
            'Ultimo mese': [moment().subtract(1, 'month'), moment()],
            'Ultimo 2 mesi': [moment().subtract(2, 'months'), moment()],
            'Ultimo 6 mesi': [moment().subtract(6, 'months'), moment()],
            'Ultimo anno': [moment().subtract(1, 'year'), moment()],
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        // on change event, get sites within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        loadSites(dateFrom, dateTo);
    });

    // datatable first tab
    table = $('#list-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        "columnDefs": [
            {
                // column for + button in small monitors
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // 2 types of search: list of sites or list of allocations
    // for each type there are different descriptions and filters shown/hidden throught .select-place class
    $('.select-place, #active-loc').hide();

    $( "#nets, #provinces").select2();
    // select2 initialization
    $( "#stations" ).select2({
        matcher: searchGroupedSelect2 // function in global.js
    });

    // select2 initialization
    $("#campaigns").select2({
        // attribute that allows to manage options html classes
        templateResult: function (data) {
            // We only really care if there is an element to pull classes from
            if (!data.element) {
                return data.text;
            }

            var $element = $(data.element);

            var $wrapper = $('<span></span>');
            $wrapper.addClass($element[0].className);

            $wrapper.text(data.text);

            return $wrapper;
        }
    });

    $('#search-type').on('change', function(e){
        e.preventDefault();
        var status = $(this).prop('checked'); // true per location, false per sito

        if (status){
            $('.select-place, #active-loc').show();
            $('#active-site').hide();
        }else{
            $('.select-place, #active-loc').hide();
            $('#active-site').show();
        }

        // reload list of elements
        loadSites(dateFrom, dateTo);
    });

    $( "#nets" ).on( "change", function() {
        var net = $(this).val();
        var dest = $(this).data('dest');

        var nets = [];
        nets.push(net);

        // reload roaming stations based on selected networks
        loadRoamingStations(dest, JSON.stringify(nets));
    });

    $( "#nets, #provinces, #stations, #campaigns" ).on( "change", function() {

        // reload list of elements
        loadSites(dateFrom, dateTo);
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retrieve site detail.
     */
    $('#list-table').on('click', '.show-element', function(e){
        e.preventDefault();

        // get site id
        var siteId = parseInt($(this).parent().parent().data("id"));

        // check if the report's detail is already open
        if( $('#site'+siteId).length ) {
            console.log('The site\'s detail is already open');
            $('.customtab a[href="#site' + siteId + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createSiteDetail(siteId);

    });

    /**
     * Edit site.
     */
    $('#list-table').on('click', '.edit-element', function(e){
        e.preventDefault();

        // get site id
        var siteId = parseInt($(this).parent().parent().data("id"));

        // reset form
        clearFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_site_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: siteId
            }
        })
        .done(function(result) {
            console.log('edit site!');

            var site = result.site;
            // json objects to be parsed
            var attachments = JSON.parse(site.site_attachments);
            var locations = JSON.parse(site.site_locations);

            console.dir(site);
            console.dir(attachments);

            /**
             * s.site_id             ,
             * s.site_name           ,
             * s.network_types       ,
             * s.mu_id               ,
             * m.mu_name           AS municipality_name,
             * p.province_id,
             * p.province_name,
             * r.region_id,
             * r.region_name,
             * s.site_locality       ,
             * s.site_altitude       ,
             * s.site_wgs84_lat      ,
             * s.site_wgs84_lon      ,
             * s.site_note
             */

            // populate the fields of "new site" form
            $('#site-id').val(site.site_id);
            $('#site-name').val(site.site_name);
            $('#site-networks').val(site.network_types).trigger('change.select2');;

            // check if site has attachments
            //  - if true then add attachments to the site's detail page
            if(attachments){
                var htmlImages = '';
                var htmlFiles = '<ul>';

                // loop through attachments
                // different items depending on the file type
                $.each(attachments, function(idx, attachment){
                    // check if current looped attachment is an image
                    if(attachment.file_image == true){
                        // image files
                        htmlImages +='    <div class="del-my-img">\n';
                        htmlImages +='      <span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i> </span><a href="'+attachment.file_path+'" class="clearfix thumb-gallery"><img src="'+attachment.file_path+'"></a>\n';
                        htmlImages +='    </div>\n';
                    }
                    else{
                        // other files
                        htmlFiles +='<li><span class="del-attachment-ico" data-attid="'+attachment.file_id+'" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash"></i></span> <a href="'+attachment.file_path+'"><i class="icon-paper-clip"></i> '+attachment.file_name+'</a></li>';
                    }
                });

                htmlFiles += '</ul>';

                $('#img-container').append(htmlImages);
                $('.attachment-files').append(htmlFiles);

                // image gallery
                refreshGalleryBig();
            }

            $('#site-note').val(site.site_note);
            // set province and municipality to data retrieval from the server
            $('#site-region').val(site.region_id).trigger('change', [site.province_id, site.mu_id]);
            $('#site-locality').val(site.site_locality);
            $('#site-latitude').val(site.site_wgs84_lat);
            $('#site-longitude').val(site.site_wgs84_lon);
            $('#site-altitude').val(site.site_altitude);

            // add marker to map and zoom map view
            var layer = getLayerByName('Sito', mainMap);

            var feature = new ol.Feature({
                popup_flag: false,
                geometry: new ol.geom.Point(ol.proj.transform([parseFloat(site.site_wgs84_lon), parseFloat(site.site_wgs84_lat)], 'EPSG:4326', 'EPSG:3857'))
            });

            layer.getSource().clear();
            layer.getSource().addFeature(feature);

            mainMap.getView().fit(feature.getGeometry(), {
                minResolution: 15
            });

            // set button that hides/shows map div
            $('#btn-map-selection').html('<i class="ti-map-alt"></i> nascondi mappa');
            $('#btn-map-selection').removeClass("btn-primary");
            $('#btn-map-selection').addClass("btn-danger");

            // show map div
            $('.map-container').show();
            // hide section "Stanziamento mezzo mobile": only available in insert mode
            $('#hide-edit').hide();
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

            // set tab texts
            $('#new-element .box-title').text('Modifica SITO');
            $('#btn-site-form').html(' <i class="ti-save"></i> Modifica');
            // show tab
            $('.customtab a[href="#new-element"]').tab('show');
            // update map size
            setTimeout(function(){
                mainMap.updateSize();
            }, 5);
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della bombola", "error");
        });
    });

    /**
     * Download site detail.
     */
    $('#list-table').on('click', '.pdf-element', function(e){
        e.preventDefault();
        swal("Report scaricato", "Il report è stato scaricato con successo!", "success");
    });

    /**
     * Delete site.
     *
     * N.B.: only available for sites not yet associated.
     */
    $('#list-table').on('click', '.delete-element', function(e){
        e.preventDefault();

        // get site id
        var siteId = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai per eliminare <strong>definitivamente</strong> il sito",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            html: true,
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            var jqxhr = $.ajax({
                url: '/cnf_campagne_del_site',
                type: "post",
                dataType: "json",
                data: {
                    id: siteId
                }
            })
            .done(function(result) {

                console.dir(result);

                // check result
                //  - if '-1' then it's impossible to delete the site because it's used in other applications
                //  - if '1' then the site is correctly deleted -> clear all fields
                //  - else error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile eliminare il sito perchè sono presenti <strong>DEGLI STANZIAMENTI</strong>",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == 1){
                    swal("Sito eliminato", "Il sito è stata eliminato con successo!", "success");
                    // reload list in order to update all selects html elements
                    loadSites(dateFrom, dateTo);

                    // reset "new site" form and "new location" form
                    clearFields();
                    clearLocationFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della bombola", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione del sito", "error");
            });

        });

    });

    /**
     * Edit campaign.
     *
     * N.B.: only available for active allocations.
     */
    $('#list-table').on('click', '.edit-loc-el', function(e){
        e.preventDefault();

        // get station-site relation id
        var stsiid = parseInt($(this).parent().parent().data("stsiid"));

        // reset location form fields
        clearLocationFields();

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_location_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: stsiid
            }
        })
        .done(function(result) {
            console.log('edit location!');

            var location = result.location;
            console.dir(location);
            // stsi_id
            // station_id
            // station_override_id
            // site_id
            // stsi_startup_date
            // stsi_dismiss_date
            // stsi_note
            // camp_id

            // populate form
            // it's not possible to change site and roaming station
            $('#loc-site').prop('disabled', true);
            $('#loc-lab').prop('disabled', true);

            $('#loc-id').val(stsiid);
            $('#loc-site').val(location.site_id).trigger('change', location.station_id);
            $('#loc-campaign').val( (location.camp_id ? location.camp_id : -1) );

            $('#loc-start-date').val('');
            $('#loc-start-date').bootstrapMaterialDatePicker('setDate', moment(location.stsi_startup_date).format('DD/MM/YYYY HH:mm'));
            $('#loc-start-date').trigger('change');

            $('#loc-start-date').bootstrapMaterialDatePicker('setMinDate', moment('2000-01-01 00:00'));

            $('#loc-end-date').val('');
            if(location.stsi_dismiss_date != 'infinity')
                $('#loc-end-date').bootstrapMaterialDatePicker('setDate', moment(location.stsi_dismiss_date).format('DD/MM/YYYY HH:mm'));

            $('#loc-end-date').bootstrapMaterialDatePicker('setMinDate', moment(location.stsi_startup_date) );

            $('#loc-ext-id').val(location.station_ext_id);
            $('#loc-notes').val(location.stsi_note);
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // set tab texts
            $('#new-location .box-title').text('Modifica stanziamento');
            $('#loc-insert').html(' <i class="ti-save"></i> Modifica');
            // show tab
            $('.customtab a[href="#new-location"]').tab('show');
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio dello stanziamento", "error");
        });
    });

    /**
     * Close location.
     *
     * N.B.: only available for active allocations.
     */
    $('#list-table').on('click', '.close-loc-el', function(e){
        e.preventDefault();

        // get location id
        var stsiid = parseInt($(this).parent().parent().data("stsiid"));

        // show confirm message
        swal({
            title: "Chiudi location",
            text: "Sei proprio sicuro di voler chiudere questa location?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, chiudi",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // close the selected location
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_campagne_put_location_closure',
                type: "post",
                dataType: "json",
                data: {
                    id: stsiid
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, clear fields and load location list
                //  - if false then error
                if(result){
                    swal("Location chiusa", "La location è stata chiusa con successo!", "success");
                    // reload lists in order to update all select html elements
                    loadSites(dateFrom, dateTo);

                    // reset location form fields
                    clearLocationFields();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante la chiusura della location", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante la chiusura della location", "error");
            });

        });
    });

    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM SITES FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // hide map container and 'Stanziamento mezzo mobile' div
    $('.map-container').hide();
    $('.hide-loc').hide();

    $("#add-location-fields").hide();

    $("#site-networks, #site-region, #site-district, #main-loc-lab" ).select2();

    // START Dropzone //
    var url = "/cnf_campagne_put_site";

    myDropzone = initDropzoneFiles(url);
    // END Dropzone //

    /**
     * Main map initialization.
     */
    mainMap = initMap('map-selection', footer);
    var layer = createLayer('Sito', 0, mainMap);
    layer.setStyle(defaultStyleFunction);

    // START TRANSLATE
    var translate = new ol.interaction.Translate();
    mainMap.addInteraction(translate);
    translate.on('translateend', function (evt) {

        // transform coordinates from EPSG:3857 to WGS84
        var coords_WGS84 = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:4326'));
        // populate lat lon form fields
        var lon = parseFloat(coords_WGS84[0]).toFixed(6);
        var lat = parseFloat(coords_WGS84[1]).toFixed(6);
        $("#site-latitude").val(lat);
        $("#site-longitude").val(lon);
        // get municipality containing these coordinates
        loadMunicipality(lon, lat);
    });
    // END TRANSLATE

    /**
     * Creation of the marker at mouse click on the mainMap.
     */
    mainMap.on("click", function (evt) {
        console.log("click mainMap");

        var coord = evt.coordinate;

        var layer = getLayerByName('Sito', mainMap);

        var feature = new ol.Feature({
            popup_flag: false,
            geometry: new ol.geom.Point([parseFloat(coord[0]), parseFloat(coord[1])])
        });

        layer.getSource().clear();
        layer.getSource().addFeature(feature);
        // transform coordinates from EPSG:3857 to WGS84
        var coords_WGS84 = ol.proj.transform(evt.coordinate, 'EPSG:3857', ol.proj.get('EPSG:4326'));
        // populate lat lon form fields
        var lon = parseFloat(coords_WGS84[0]).toFixed(6);
        var lat = parseFloat(coords_WGS84[1]).toFixed(6);
        $("#site-latitude").val(lat);
        $("#site-longitude").val(lon);
        // get municipality containing these coordinates
        loadMunicipality(lon, lat);
    });

    /**
     * New site network selection.
     */
    $( "#site-networks" ).on( "change", function() {
        var nets = $(this).val();
        var dest = $(this).data('dest');

        // if there are selected networks
        if(nets.length > 0){
            // reload roaming stations based on selected networks
            loadRoamingStations(dest, JSON.stringify(nets));
        }
        else{
            // reset select html element
            $('#'+dest).empty();
            $('#'+dest).append('<option value="-1">Seleziona laboratorio...</option>');
        }

    });

    $('#btn-map-selection').on('click', function(e) {
        e.preventDefault();

        if( $('.map-container').is(':visible') ){
            $('#btn-map-selection').html('<i class="ti-map-alt"></i> scegli da mappa');
            $('#btn-map-selection').removeClass("btn-danger");
            $('#btn-map-selection').addClass("btn-primary");
        }
        else{
            $('#btn-map-selection').html('<i class="ti-map-alt"></i> nascondi mappa');
            $('#btn-map-selection').removeClass("btn-primary");
            $('#btn-map-selection').addClass("btn-danger");
        }

        $('.map-container').toggle('slow');

        setTimeout(function(){
            mainMap.updateSize();
            zoomToItaly(mainMap);
        }, 200);
    });

    $( "#site-region").on( "change", function(e, prid, muid) {
        var reid = $(this).val();
        // reload provinces based on selected region
        loadProvinces(reid, prid, muid);
    });

    $( "#site-prov").on( "change", function(e, muid) {
        var prid = $(this).val();
        // reload municipalities based on selected province
        loadMunicipalities(prid, muid);
    });

    /**
     * Switchery initialization.
     */
    mySwitch = new Switchery($("#add-location")[0], $("#add-location").data());

    $("#add-location").on( "change", function() {
        var ckb = mySwitch.isChecked();
        if (ckb){
            $("#add-location-fields").show();
        }else{
            $("#add-location-fields").hide();
        }
    });

    /**
     * Calendars initialization.
     */
    $('#main-loc-start-date, #main-loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date as start time picker value
        $('#main-loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#main-loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#main-loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#main-loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#main-loc-end-date').val('');
    });

    /**
     * Red trash icon on attachment elements.
     *
     * N.B.: only available in edit mode.
     */
    $('.tab-content').on('click', '.del-attachment-ico', function(e){

        e.preventDefault();

        console.log('click');

        // get attachment id
        var id = $(this).data("attid");

        // show confirm message
        swal({
            title: "Stai per eliminare un allegato",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_campagne_del_attachment',
                type: "post",
                dataType: "json",
                data: {
                    id: id
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, remove the selected attachment
                //  - if false then error
                if(result){
                    $("span[data-attid='"+id+"']").parent().remove();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione dell'allegato", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione dell'allegato", "error");
            });

        });
    });

    /**
     * Validate form.
     */
    var validator = $('#site-form').validate({ // initialize the plugin
        rules: {
            "site-name" : {
                required: true
            },
            "site-networks":{
                required: true,
                allowEmpty: false
            },
            "site-district" : {
                required: true,
                min: 1
            },
            "site-locality" : {
                required: true
            },
            "site-latitude" : {
                required: true,
                dotSeparator: true
            },
            "site-longitude" : {
                required: true,
                dotSeparator: true
            },
            "site-altitude" : {
                regex: '^[0-9]{0,4}$'
            },
            "main-loc-lab":{
                required:  function (element) {
                    if(mySwitch.isChecked()){return true;}else{return false;}
                },
                min: function (element) {
                    if(mySwitch.isChecked()){return 0;}else{return -1;}
                },
            },
            "main-loc-start-date":{
                required:  function (element) {
                    if(mySwitch.isChecked()){return true;}else{return false;}
                },
            },
        },
        messages: {
            "site-name" : {
                required: "Inserire nome sito"
            },
            "site-networks":{
                required: "Inserire almeno una rete",
                allowEmpty: "Inserire almeno una rete"
            },
            "site-district" : {
                required: "Inserire comune",
                min: "Inserire comune"
            },
            "site-locality" : {
                required: "Inserire località"
            },
            "site-latitude" : {
                required: "Inserire WGS84 latitudine"
            },
            "site-longitude" : {
                required: "Inserire WGS84 longitudine",
            },
            "site-altitude" : {
                regex: 'Inserire numero intero maggiore di 0'
            },
            "main-loc-lab":{
                required: "Selezionare lab. mobile",
                min: "Selezionare lab. mobile"
            },
            "main-loc-start-date" : {
                required: "Inserire data inizio"
            },
        },
        ignore: "",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * Function called when using Dropzone submit.
     */
    myDropzone.on("sendingmultiple", function(files, xhr, formData) {

        var form = $('#site-form');
        // add "new site" form fields into dropzone submit oject
        var formValues = form.serializeArray();
        $.each(formValues, function(index, input){
            formData.append(input.name, input.value);
        });
    });

    /**
     * Function called at the Dropzone submit return.
     */
    myDropzone.on("successmultiple", function(files, response) {
        var id   = $("#site-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        // otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // check result
        //  - if '-1' then it's impossible to allocate the lab because it's used in other applications
        //  - if '1' then success, reload the list in the first tab, show the table and reset form
        //  - else error
        if(response == -1){
            swal({
                title: "Attenzione!",
                text: "Impossibile stanziare il laboratorio nel periodo selezionato, perchè il laboratorio è <strong>GIÀ STANZIATO</strong> in un altro sito.<br>Modificare le date dello stanziamento",
                type: "warning",
                html: true
            });

        }
        else if(response == 1){
            console.log('Success');
            swal("Successo", msg_ok, "success");

            // site list update
            loadSites(dateFrom, dateTo);
            // show first tab
            $('.customtab a[href="#list"]').tab('show');
            // reset "new site" form
            clearFields();
        }
        else{
            swal("Errore", msg_err, "error");
            // marks dropzone items as unsent in order to be able to re-send them later
            $.each(files, function(index, file) {
                file.previewElement.classList.add("dz-error");
                file.status = Dropzone.QUEUED
            });
        }
        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    });

    /**
     * Submit site new/edit form.
     */
    $('#site-form').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Sito non salvato!", "info");
            return false;
        };

        var form = $("#site-form");
        var id   = $("#site-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // Check if attachments exist:
        // if exists     -> use the dropzone submit function and add fields of the form to the submission
        // if not exist  -> normal form submit
        if (myDropzone.getQueuedFiles().length > 0) {
            console.log(myDropzone.getQueuedFiles().length);
            // dropzone submit
            myDropzone.processQueue();
        }
        else {
         console.log("Invio normale");

            // ajax call
            $.ajax({
                url: '/cnf_campagne_put_site',
                type: 'post',
                dataType: "json",
                data: form.serialize()
            }).done(function(result) {
                console.dir(result);
                // check result
                //  - if '-1' then it's impossible to allocate the lab because it's used in other applications
                //  - if '-2' then it's impossible to allocate the lab in to the location because it's name is already used
                //  - if '1' then success, reload the list in the first tab, show the table and reset form
                //  - else error
                if(result == -1){
                    swal({
                        title: "Attenzione!",
                        text: "Impossibile stanziare il laboratorio nel periodo selezionato perché <strong>GIÀ STANZIATO</strong> in un altro sito.<br>Modificare le date dello stanziamento",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == -2){
                    swal({
                        title: "Attenzione!",
                        text: "É <strong>GIÀ PRESENTE</strong> un sito col nome inserito. Modificare il nome oppure utilizzare il sito esistente.",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == 1){
                    console.log('Success');
                    swal("Successo", msg_ok, "success");

                    // reload site
                    loadSites(dateFrom, dateTo);
                    // show first tab
                    $('.customtab a[href="#list"]').tab('show');
                    // reset "new site" form
                    clearFields();
                }
                else{
                    // error message
                    swal("Errore!", msg_err, "error");
                }
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
            })
            .fail(function(xhr, err) {
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // error message
                swal("Errore!", msg_err, "error");

            });
        }
    });

    /**
     * Cancel button.
     */
    $('#cancel-site-form').on('click', function(e) {
        e.preventDefault();
        // show first tab
        $('.customtab a[href="#list"]').tab('show');
        // reset "new site" form
        clearFields();
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM SITES FUNCTIONS

    // FORM LOCATIONS FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    $("#loc-site, #loc-lab" ).select2();

    /**
     * Calendars initialization.
     */
    $('#loc-start-date, #loc-end-date').bootstrapMaterialDatePicker({
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(e, date) { // change event

        console.log('cambio ora');
        // for the end time picker, set min date as start time picker value
        $('#loc-end-date').bootstrapMaterialDatePicker('setMinDate', $('#loc-start-date').val() );

        // check if start time is same or after end time
        if( moment($('#loc-start-date').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter( moment($('#loc-end-date').val(), 'DD/MM/YYYY HH:mm') ))
            // if true then reset end time
            $('#loc-end-date').val('');
    });

    $('#loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
    $('#loc-start-date').trigger('change');

    /**
     * New location site selection.
     */
    $("#loc-site" ).on('change', function(e, stid){
        var siid = parseInt($(this).val());

        // if there is a selected site
        if(siid != -1){
            // reload roaming stations based on networks to which the site is associated
            loadRoamingStations('loc-lab', JSON.stringify( $('#loc-site option:selected').data('nets') ), stid);
            // show form
            $('.hide-loc').show('slow');
        }
        else{
            // reset station select html element and hide form
            $('#loc-lab').empty();
            $('#loc-lab').append('<option value="-1">Seleziona laboratorio...</option>');
            $('.hide-loc').hide('slow');
        }
    });

    $("#loc-lab" ).on('change', function(e){

        var mindate = $('option:selected', this).data('mindate');
        $('#loc-start-date').bootstrapMaterialDatePicker('setMinDate', moment(mindate) );
    });

    /**
     * Validate form.
     */
    var validator = $('#loc-form').validate({ // initialize the plugin
        rules: {
            "loc-site" : {
                required: true,
                min: 1
            },
            "loc-lab" : {
                required: true,
                min: 1
            },
            "loc-start-date" : {
                required: true
            },
        },
        messages: {
            "loc-site" : {
                required: "Selezionare sito",
                min: "Selezionare sito"
            },
            "loc-lab" : {
                required: "Selezionare laboratorio",
                min: "Selezionare laboratorio"
            },
            "loc-start-date" : {
                required: "Inserire data/ora inizio"
            },
        },
        ignore: "",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * New location's form submission.
     */
    $('#loc-form').on('submit', function (e) {
        e.preventDefault();

        // check if all form fields are valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare questo elemento", "info");
            return false;
        };

        var form = $("#loc-form");
        var id   = $("#loc-id").val();

        // different messages based on the type of action (insert or update)
        // if the id is setted then is an update
        //  otherwise is an insert
        if(id){
            msg_ok = 'La modifica è stata salvata correttamente';
            msg_err = 'Si è verificato un errore durante la modifica';
        }
        else{
            msg_ok  = 'Il salvataggio è avvenuto correttamente';
            msg_err = 'Si è verificato un errore durante il salvataggio';
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        $.ajax({
            url: '/cnf_campagne_put_location',
            type: 'post',
            dataType: "json",
            data: form.serialize()
        }).done(function(result) {
            console.dir(result);
            // check result
            //  - if '-1' then it's impossible to allocate the lab because it's already used in another site
            //  - if '1' then success, reload the list in the first tab, show the table and reset form
            //  - else error
            if(result == -1){
                swal({
                    title: "Attenzione!",
                    text: "Impossibile stanziare il laboratorio nel periodo selezionato perchè <strong>GIÀ STANZIATO</strong> in un altro sito.<br>Modificare le date dello stanziamento",
                    type: "warning",
                    html: true
                });
            }
            else if(result == 1){
                console.log('Success');
                swal("Successo", msg_ok, "success");

                // reload sites list
                loadSites(dateFrom, dateTo);
                // show first tab
                $('.customtab a[href="#list"]').tab('show');
                // reset "new location" form
                clearLocationFields();
            }
            else{
                // error message
                swal("Errore!", msg_err, "error");
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", msg_err, "error");

        });
    });

    /**
     * Cancel button.
     */
    $('#loc-cancel').on('click', function(e) {
        e.preventDefault();

        // show first tab
        $('.customtab a[href="#list"]').tab('show');
        // reset "new location" form
        clearLocationFields();
    });

    // END FORM LOCATIONS FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // MODAL CAMPAIGNS FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // initialize select2 at modal "show" event to manage placeholders (it is cut otherwise)
    $('#modal-campaigns').on('shown.bs.modal', function(){

        $('#camp-networks').select2({
            placeholder: "Selezionare reti di appartenenza..."
        });
    });

    /**
     * Reset form fields at modal "hide" event.
     */
    $('#modal-campaigns').on('hide.bs.modal', function(e){
        // reset modal form
        $('.form-title').text('Aggiungi campagna');
        $('#btn-add-campaign').html('<i class="ti-save-alt"></i> Aggiungi');
        // reset input type text
        $('#new-campaign input').val('');
        // reset select 2
        $('#camp-networks').val([]).trigger('change');
        // reset validate plugin
        $('#new-campaign').validate().resetForm(); // reset form error
    });

    /**
     * Datatable initialization
     */
    campaignsTbl = $('#campaigns-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [],
        "autoWidth": false,
        "columnDefs": [
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "asc" ]]
    });

    /**
     * Edit campaign element.
     */
    $('#campaigns-table').on('click', '.edit-camp', function(e){
        e.preventDefault();

        // set modal form texts
        $('.form-title').text('Modifica campagna');
        $('#btn-add-campaign').html('<i class="ti-save-alt"></i> Modifica');

        // get data from tr item and populate form
        var id = parseInt($(this).parent().parent().data("id"));
        var nets = $(this).parent().parent().data("nets");

        var name = $(this).parent().parent().find('td:nth-child(2)').text();

        $('#camp-id').val(id);
        $('#camp-name').val(name);
        $('#camp-networks').val(nets).trigger('change');
    });

    /**
     * Disable / Enable element.
     */
    $('#campaigns-table').on('click', '.disable-camp, .enable-camp', function(e){
        e.preventDefault();
        var row = $(this).parent().parent();

        // get campaign site id
        var id = parseInt(row.data("id"));

        // check if the action enables or disables item
        var actionStr = 'disabilit';
        var newStatus = false;
        if( row.hasClass('not-active') ){
            actionStr = 'abilit';
            newStatus = true;
        }

        // show confirm message
        swal({
            title: "Stai per "+actionStr+"are la campagna",
            text: "Sei proprio sicuro di voler proseguire?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // enable/disable the selected campaign
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_campagne_put_campaign_status',
                type: "post",
                dataType: "json",
                data: {
                    id: id,
                    status: newStatus
                }
            })
            .done(function(result) {
                // check result
                //  - if true then success, reload campaigns list
                //  - if false then error
                if(result){
                    swal("Successo", "La campagna è stata "+actionStr+"ata con successo!", "success");
                    loadCampaigns();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante la  "+actionStr+"azione della campagna", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante la  "+actionStr+"azione della campagna", "error");
            });

        });
    });

    /**
     * Delete element.
     *
     * N.B.: only available for campaigns not yet associated.
     */
    $('#campaigns-table').on('click', '.delete-camp', function(e){
        e.preventDefault();

        // get campaign site id
        var id = parseInt($(this).parent().parent().data("id"));

        // show confirm message
        swal({
            title: "Stai per eliminare la campagna",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected item
            // ajax call
            var jqxhr = $.ajax({
                url: '/cnf_campagne_del_campaign',
                type: "post",
                dataType: "json",
                data: {
                    id: id
                }
            })
            .done(function(result) {
                console.dir(result);

                // check result
                //  - if res is 'OK' then success, remove element from table and reset modal form
                //  - else error
                if(result.res == 'OK'){
                    swal("Campagna eliminata", "La campagna è stata eliminata con successo!", "success");
                    // remove element from table
                    campaignsTbl.row($("tr[data-id='"+id+"']")).remove().draw();

                    // reset modal form
                    $('.form-title').text('Aggiungi campagna');
                    $('#btn-add-campaign').html('<i class="ti-save-alt"></i> Aggiungi');
                    // reset input type text
                    $('#new-campaign input').val('');
                    // reset select 2
                    $('#camp-networks').val([]).trigger('change');
                    // reset validate plugin
                    $('#new-campaign').validate().resetForm(); // reset form error
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della campagna", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'eliminazione della campagna", "error");
            });
        });
    });

    /**
     * Validate form.
     */
    var validatorCamp = $('#new-campaign').validate({ // initialize the plugin
        rules: {
            "camp-name" : {
                required: true,
            },
            "camp-networks": {
                required: true,
                allowEmpty: false
            }
        },
        messages: {
            "camp-name" : {
                required: "Inserire nome campagna"
            },
            "camp-networks":{
                required: "Inserire almeno una rete",
                allowEmpty: "Inserire almeno una rete"
            }
        },
        ignore: "",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * Modal form submit.
     */
    $('#new-campaign').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare questo elemento", "info");
            return false;
        };

        var form = $("#new-campaign");
        var id   = $("#camp-id").val();
        var msg_err = 'Si è verificato un errore durante il salvataggio';
        var msg_ok  = 'La campagna è stata salvata correttamente';

        // ajax call
        $.ajax({
            type: 'post',
            url: '/cnf_campagne_put_campaign',
            data: form.serialize()
        }).done(function(result) {
            // check result
                //  - if true then success, reload the campaign list, reset modal form
                //  - if false then error
            if(result == true){
                swal("Successo", msg_ok, "success");

                // reload campaign list
                loadCampaigns();

                // reset modal form
                $('.form-title').text('Aggiungi campagna');
                $('#btn-add-campaign').html('<i class="ti-save-alt"></i> Aggiungi');
                // reset input type text
                $('#new-campaign input').val('');
                // reset select 2
                $('#camp-networks').val([]).trigger('change');
                // reset validate plugin
                $('#new-campaign').validate().resetForm(); // reset form error


            }
            else{
                // error message
                swal("Errore!", msg_err, "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", msg_err, "error");

        });
    });

    /**
     * Cancel button.
     */
    $('#dismiss-camp').on('click', function(e) {
        e.preventDefault();

        // reset modal form
        $('.form-title').text('Aggiungi campagna');
        $('#btn-add-campaign').html('<i class="ti-save-alt"></i> Aggiungi');
        // reset input type text
        $('#new-campaign input').val('');
        // reset select 2
        $('#camp-networks').val([]).trigger('change');
        // reset validate plugin
        $('#new-campaign').validate().resetForm();
    });

    // END MODAL CATEGORIES FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // VIEW SITES FUNCTIONS
    /////////////////////////////////////////////////////////////////////

     /**
      * Close site detail.
      */
     $('.card-body').on('click', '.close-detail', function(e){
        e.preventDefault();

        var close = $(this).data("close");
        console.log(close);

        // close tab and show first tab
        setTimeout(function(){
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#list"]').tab('show');
        }, 1);
    });

    // END VIEW SITES FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Trigger change event in order to load sites.
     */
    $( "#nets" ).trigger('change');

    // load campaigns
    loadCampaigns();

    // ! FUNCTIONS !

    // UTILITIES

    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null, the string '--';
     *         If not, the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    }

    /**
     * Function that sets the Switchery element.
     *
     * @param {html_element} switchElement HTML Switchery element.
     * @param {boolean} checkedBool Boolean value provided by the user.
     */
    function setSwitchery(switchElement, checkedBool) {
        if((checkedBool && !switchElement.isChecked()) || (!checkedBool && switchElement.isChecked())) {
            switchElement.setPosition(true);
            switchElement.handleOnchange(true);
        }
    }

    /**
     * Function that refreshes the gallery item.
     * no args needed
     */
    function refreshGalleryBig(){
        console.log("Refresh gallery BIG");
        $('.attachment-gallery-big').each(function() { // the containers for all your galleries
            $(this).magnificPopup({
                delegate: 'a', // the selector for gallery item
                type: 'image',
                gallery: {
                  enabled:true
                }
            });
        });
    }

    // END UTILITIES

    /**
     * Function resetting "new site" form.
     * no args needed
     */
    function clearFields(){
        // reset input type
        $('#site-form .clear-input').val("");
        // reset select
        $('#site-form .clear-select').val(-1);
        // reset select 2
        $('#site-region, #site-district').trigger('change.select2');
        // reset select 2
        $('#site-networks').val([]).trigger('change');

        // reset attachments
        myDropzone.removeAllFiles(true);
        $('#img-container').empty();
        $('.attachment-files').empty();

        // reset map
        var indexLayer = getHowManyBaselayers(mainMap);
        var layer = getLayerByIdx(indexLayer, mainMap);
        layer.getSource().clear();

        // zoom map to Italy
        zoomToItaly(mainMap);

        // reset map div container and the associated button
        $('#btn-map-selection').html('<i class="ti-map-alt"></i> scegli da mappa');
        $('#btn-map-selection').removeClass("btn-danger");
        $('#btn-map-selection').addClass("btn-primary");
        $('.map-container').hide();

        // manage Switchery
        setSwitchery(mySwitch, false);
        $("#add-location-fields").hide();

        $('#hide-edit').show();
        // reset tab texts
        $('#new-element .box-title').text('Inserisci nuovo SITO');
        $('#btn-site-form').html(' <i class="ti-save"></i> Inserisci');

        // reset validator
        $('#site-form').validate().resetForm(); // reset form error
    };

    /**
     * Function resetting "new location" form.
     * no args needed
     */
    function clearLocationFields(){
        $('.hide-loc').hide();

        // reset tab texts
        $('#new-location .box-title').text('Inserisci nuovo stanziamento');
        $('#loc-insert').html('<i class="icon-location-pin"></i> Inserisci');

        // reset fields
        $('#loc-form .clear-select').val(-1).trigger('change');

        $('#loc-site').prop('disabled', false);
        $('#loc-lab').prop('disabled', false);

        $('#loc-id').val('');
        $('#loc-start-date').val('');
        $('#loc-start-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY HH:mm'));
        $('#loc-start-date').trigger('change');
        $('#loc-end-date').val('');
        $('#loc-ext-id').val('');
        $('#loc-notes').val('');

        // reset validator
        $('#loc-form').validate().resetForm(); // reset form error
    };

    /**
     * Function that retrieves the roaming stations of a given set of networks.
     *
     * @param {string}  dest Name of the html data attribute.
     * @param {integer} nets Network IDs.
     * @param {integer} stid Station ID (available only in edit mode).
     */
    function loadRoamingStations(dest, nets, stid){
        console.dir(nets);
        console.log(dest);

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_roaming_stations_bynets',
            type: "post",
            dataType: "json",
            data: {
                nets: nets
            },
        })
        .done(function(result) {

            console.dir(result);
            // check if result is 'OK'
            if(result.res == 'OK'){
                $('#'+dest).empty();
                var stations = result.stations;
                // variable for dinamically building the select html
                var opts = '';
                var net;
                // create option items for "dest" select
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

                    if(dest == 'stations')
                        station.station_class = '';

                    opts += '<option '+station.station_class+' value="'+ station.station_id+'" data-mindate="'+station.last_dismiss_date+'">'+station.station_name+'</option>';
                });
                // append options
                $('#'+dest).append('<option value="-1">Seleziona laboratorio...</option>');
                $('#'+dest).append(opts);

                // if exists, set station
                if(stid){
                    $('#'+dest).val(stid).trigger('change.select2');
                }
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
     * Function that retrieves the provinces.
     *
     * @param {integer} reid Region ID.
     * @param {integer} prid Province ID (only available in edit mode).
     * @param {integer} muid Municipality ID (only available in edit mode and passed to loadMunicipalities() function through province change event).
     */
    function loadProvinces(reid, prid, muid){

        console.log('loadProvinces: '+reid);

        // reset select
        $("#site-prov").empty();
        $('#site-prov').append('<option value="-1">Seleziona provincia...</option>');

        // check if region is selected
        if( reid == null){
            // if not selected then reset province
            $("#site-prov").val(-1);
            return;
        }

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_provinces',
            type: "post",
            dataType: "json",
            data: {
                region: reid
            },
        })
        .done(function(result) {
            // check if result is 'OK'
            if(result.res == 'OK'){
                var provinces = result.provinces;
                // create option items for "#site-prov" select
                var opts = '';
                // loop through all elements
                // for each province, build a html option to be added to the select
                $.each(provinces, function(index, prov){
                    opts += '<option value="'+ prov.province_id+'">'+prov.province_name+'</option>';
                });
                // append options
                $('#site-prov').append(opts);
                // if exists, set province
                if(prid)
                    $("#site-prov").val(prid).trigger('change', muid); // passing municipality id
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle province", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle province", "error");

        });
    }

    /**
     * Function that retrieves the municipalities.
     *
     * @param {integer} prid Province ID.
     * @param {integer} muid Municipality ID (only available in edit mode).
     */
    function loadMunicipalities(prid, muid){

        console.log('loadMunicipalities: '+prid);

        // reset select
        $("#site-district").empty();
        $('#site-district').append('<option value="-1">Seleziona comune...</option>');

        // check if municipality is selected
        if(prid == null){
            // if not selected then reset municipality
            $('#site-district').append('<option value="0">Sconosciuto</option>');
            $('#site-district').val(municipality == null ? -1 : 0 );
            return;
        }

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_municipalities',
            type: "post",
            dataType: "json",
            data: {
                province: prid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                var municipalities = result.municipalities;
                // create option items for "#site-district" select
                var opts = '';
                // loop through all elements
                // for each municipality, build a html option to be added to the select
                $.each(municipalities, function(index, mu){
                    opts += '<option value="'+ mu.mu_id+'">'+mu.mu_name+'</option>';
                });
                // append options
                $('#site-district').append(opts);
                // if exists, set municipality
                if(muid)
                    $("#site-district").val(muid);
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei comuni", "error");
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei comuni", "error");

        });
    }

    /**
     * Function called at click/translateend events on main map.
     *
     * @param {real} lon Longitude WGS84.
     * @param {real} lat Latitude WGS84.
     */
    function loadMunicipality(lon, lat){
        // recover region, province and municipality passing lat and lot to postgis db
        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_municipality_by_coords',
            type: "post",
            dataType: "json",
            data: {
                lon: lon,
                lat: lat
            },
        })
        .done(function(result) {
            console.dir(result);
            // check result
            // if res is 'OK' then, if municipality is retrieved, trigger change event
            if(result.res == 'OK'){
                var municipality = result.municipality;

                if(municipality)
                    $('#site-region').val(municipality.region_id).trigger('change', [municipality.province_id, municipality.mu_id]);
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei comuni", "error");
        });
    }

    /**
     * Function that retrieves the sites of a given allocation period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     */
    function loadSites(from, to){
        // 2 types of search: list of sites or list of allocations
        var type = $('#search-type').prop('checked');
        var net  = $("#nets").val(); // networks (array)
        var prov = $("#provinces").val(); // province id
        var stid = $("#stations").val(); // station id
        var camp = $("#campaigns").val(); // campaign id

        // reset datatable
        if ( table )
            table.clear();

        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_sites',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: from,
                to: to,
                net: net,
                prov: prov,
                stid: stid,
                camp: camp
            }
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadSites');

            // check if result is 'OK'
            if(result.res == 'OK'){
                // hide/show table columns based on search type
                if (type){ // STANZIAMENTO
                    table.column(4).visible(true); // dal
                    table.column(5).visible(true); // al
                    table.column(6).visible(true); // campagna
                    table.column(8).visible(false); // note

                    $(table.column(3).header()).text('Mezzo');
                    $(table.column(3).footer()).text('Mezzo');

                    table.order( [ 4, 'desc' ] );
                }else{ // SITI
                    table.column(4).visible(false); // dal
                    table.column(5).visible(false); // al
                    table.column(6).visible(false); // campagna
                    table.column(8).visible(true);  // note

                    $(table.column(3).header()).text('Mezzi stanziati');
                    $(table.column(3).footer()).text('Mezzi stanziati');

                    table.order( [ 1, 'asc' ] );
                }

                var sites = result.sites;
                var html = '';

                // build tr elements
                if( sites.length > 0 ){
                    // loop through sites
                    $.each(sites, function(index, value) {
                        /**
                         * site_id
                         * site_name
                         * network_types
                         * network_names
                         * mu_id
                         * province_code
                         * site_locality
                         * stsi_id
                         * lab
                         * lab_start
                         * lab_end
                         * site_note
                        */

                        html += '<tr data-id="'+value.site_id+'" data-stsiid="'+value.stsi_id+'">';
                        html += '    <td class="bobo-nowrap icons-little">';
                        html += '        <a href="javascript:void(0)" class="show-element" data-toggle="tooltip" data-original-title="Visualizza sito"> <i class="ti-zoom-in text-info"></i> </a>';
                        // if user has permission to edit
                        if(update_grant)
                            html += '        <a href="javascript:void(0)" class="edit-element" data-toggle="tooltip" data-original-title="Modifica sito"> <i class="icon-pencil text-info"></i> </a>';
                        html += '        <a href="javascript:void(0)" class="pdf-element" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';
                        html += '        <br>';
                        // if user has permission to edit
                        // only available for "Stanziamento" search
                        if(update_grant){

                            // buttons available only if allocation still open
                            if(value.stsi_id != null && (moment(value.lab_end, 'DD/MM/YYYY HH:mm').isAfter(moment()) || value.lab_end == 'infinito')) {

                                html += '        <a href="javascript:void(0)" class="edit-loc-el" data-toggle="tooltip" data-original-title="Modifica stanziamento"> <i class="icon-location-pin text-success"></i> </a>';
                                html += '        <a href="javascript:void(0)" class="close-loc-el" data-toggle="tooltip" data-original-title="Chiudi stanziamento"> <i class="icon-close text-success"></i> </a>';
                            }
                        }
                        // if user has permission to delete
                        // only available for sites not yet associated
                        if(delete_grant && value.site_linked == false)
                            html += '        <a href="javascript:void(0)" class="delete-element" data-toggle="tooltip" data-original-title="Elimina tutto"> <i class="icon-trash text-danger"></i> </a>';
                        html += '    </td>';
                        html += '    <td>'+value.site_name+'</td>';
                        html += '    <td>'+value.province_code+'</td>';
                        html += '    <td>'+( value.lab.length > 0 ? value.lab.join(', ') : '<i class="icon-close text-danger"></i>')+'</td>';
                        html += '    <td>'+( !type ? '--' : getFormattedDateDT(value.lab_start, 'basic_timeStartMin') )+'</td>';
                        html += '    <td>'+value.lab_end+'</td>';
                        html += '    <td>'+formatTextField(value.lab_campaign)+'</td>';
                        html += '    <td>'+value.network_names.join(', ')+'</td>';
                        html += '    <td>'+formatTextField(value.site_note)+'</td>';
                        html += '    <td></td>';
                        html += '</tr>';
                    });

                    // add rows to datatable by using html object and redraw it
                    table.rows.add($( html ));
                    table.draw();
                    table.columns.adjust();

                    table.rows({page: 'all'}).every(function() { // the containers for all your galleries
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else {
                    table.draw();
                }

                // update loc-site select in "new site" form
                var locations = result.locations;
                var htmlOpt= '';

                $('#loc-site').empty();
                $('#loc-site').append('<option value="-1">Seleziona sito...</option>');
                if( locations.length > 0 ){

                    var htmlOpt = '';
                    $.each(locations, function(index2, value2) {
                        htmlOpt += '<option value="'+value2.site_id+'" data-nets="'+JSON.stringify(value2.network_types)+'">'+value2.site_name+' ('+value2.province_code+')</option>';
                    });

                    $('#loc-site').append(htmlOpt);
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei siti", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei siti", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that retrieves all the campaigns.
     * no args needed
     */
    function loadCampaigns(){
        // reset datatable
        if ( campaignsTbl )
            campaignsTbl.clear();

        $('.inner-preloader').show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_campaigns',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            console.dir(result);
            console.log('loadCampaigns');

            // check if result is 'OK'
            if(result.res == 'OK'){

                var campaigns = result.campaigns;
                var html = '';
                var htmlFilter = '';
                var htmlOpt = '';

                // reset all select elements containing campaigns
                $('#campaigns, #main-loc-campaign, #loc-campaign').empty();
                $('#campaigns, #main-loc-campaign, #loc-campaign').append('<option value="-1">Seleziona campagna...</option>');
                if( campaigns.length > 0 ){
                    /**
                     * camp_id
                     * camp_name
                     * network_types
                     * network_names
                     * camp_active
                     */

                    // loop through campaigns
                    // create option and tr items
                    $.each(campaigns, function(index, value) {

                        var classOption = '';
                        if(value.camp_active == false)
                            classOption = 'not-active';

                        html += '<tr class="'+classOption+'" data-id="'+value.camp_id+'" data-nets="'+JSON.stringify(value.network_types)+'">';
                        html += '    <td class="bobo-nowrap icons-little">';
                        if(update_grant){
                            html += '        <a href="javascript:void(0)" class="edit-camp" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                            if(value.camp_active == true)
                                html += '        <a href="javascript:void(0)" class="disable-camp" data-toggle="tooltip" data-original-title="Disabilita"> <i class="fa-light fa-power-off  text-primary"></i> </a>';
                            else
                                html += '        <a href="javascript:void(0)" class="enable-camp" data-toggle="tooltip" data-original-title="Riabilita"> <i class="fa-light fa-power-off text-success"></i> </a>';
                        }
                        if(delete_grant && value.camp_linked == false)
                            html += '        <a href="javascript:void(0)" class="delete-camp" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                        html += '    </td>';
                        html += '    <td>'+value.camp_name+'</td>';
                        html += '    <td>'+value.network_names.join(', ')+'</td>';
                        html += '</tr>';

                        htmlOpt += '<option '+value.camp_class+' value="'+value.camp_id+'">'+value.camp_name+'</option>';

                        htmlFilter += '<option class="'+classOption+'" value="'+value.camp_id+'">'+value.camp_name+'</option>';
                    });

                    // add rows to datatable in campaign modal by using html object and redraw it
                    campaignsTbl.rows.add($( html ));
                    campaignsTbl.draw();
                    // disabled because table is in a modal
                    // campaignsTbl.columns.adjust();

                    campaignsTbl.rows({page: 'all'}).every(function() { // the containers for all your galleries
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });

                    // append options
                    $('#campaigns').append(htmlFilter);
                    $('#main-loc-campaign, #loc-campaign').append(htmlOpt);
                }
                else
                    campaignsTbl.draw();
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle campagne", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero delle campagne", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    }

    /**
     * Function that builds the site detail.
     *
     * @param {integer} siteId Site ID.
     */
    function createSiteDetail(siteId){
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_campagne_get_site_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: siteId
            },
        })
        .done(function(result) {
            console.log('show site!');

            var site = result.site;
            // json objects to be parsed
            var attachments = JSON.parse(site.site_attachments);
            var locations = JSON.parse(site.site_locations);

            console.dir(site);
            console.dir(attachments);
            console.dir(locations);

            // create nav link
            var html = '<li class="nav-item" data-siid="'+siteId+'"> <a class="nav-link" data-toggle="tab" href="#site'+siteId+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">Sito '+site.site_name+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-detail" data-close="site'+siteId+'"></i></a></li>';
            $('.nav').append(html);

            html = '';

            /**
             * s.site_id             ,
             * s.site_name           ,
             * s.network_types       ,
             * s.mu_id               ,
             * m.mu_name           AS municipality_name,
             * p.province_id,
             * p.province_name,
             * r.region_id,
             * r.region_name,
             * s.site_locality       ,
             * s.site_altitude       ,
             * s.site_wgs84_lat      ,
             * s.site_wgs84_lon      ,
             * s.site_note
             */

            // build site detail html
            html += '<div class="tab-pane p-20" id="site'+siteId+'" role="tabpanel">\n';
            html += '    <div class="form-body panel-report-view">\n';
            html += '        <h4 class="box-title">Sito: <strong>'+site.site_name+'</strong></h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Reti di appartenenza</label>\n';
            html += '            <div class="col-4 view-param">'+site.network_names.join(', ')+'</div>\n';
            html += '            <label for="" class="control-label col-2 col-form-label">Note sito</label>\n';
            html += '            <div class="col-4 view-param">'+formatTextField(site.site_note)+'</div>\n';
            html += '        </div>\n';
            html += '        <h4 class="box-title m-t-20">Coordinate geografiche</h4>\n';
            html += '        <hr class="m-t-0 m-b-20">\n';
            html += '        <div class="form-group row">\n';
            html += '            <div class="col-md-6">\n';
            html += '                <div class="form-group row">\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">Regione</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.region_name+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">Provincia</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.province_name+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">Comune</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.municipality_name+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">Località</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.site_locality+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">WGS84 latitudine</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.site_wgs84_lat+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">WGS84 longitudine</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+site.site_wgs84_lon+'</div>\n';
            html += '                    <label for="" class="control-label col-sm-6 col-lg-3 col-form-label">Quota</label>\n';
            html += '                    <div class="col-sm-6 m-b-10 col-lg-3 view-param">'+formatTextField(site.site_altitude)+' m.s.l.m.</div>\n';
            html += '                </div>\n';
            html += '            </div>\n';
            html += '            <div class="col-md-6">\n';
            html += '                <div id="map-view-'+siteId+'" class="mini-map" tabindex="0"></div>\n';
            html += '            </div>\n';
            html += '        </div>\n';

            // check if there are stations allocated in this site
            if(locations && locations.length > 0){
                /**
                 * location_id
                 * location_name
                 * location_start
                 * location_end
                 * location_note
                 */
                var actualLabs = [];
                var htmlOld = '';

                // loop on location and prepare content depending on whether the station is still allocated or not
                $.each(locations, function(idx, location){

                    var htmlActual = '';

                    // still allocated
                    if (location.stsi_dismiss_date == 'infinity' || moment(location.stsi_dismiss_date).isSameOrAfter(moment()) ){
                        var actualLab = location;
                        var flagActualLoc = true;

                        htmlActual += '        <div class="form-group row">\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">Mezzo</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+actualLab.location_name+'</div>\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">Campagna</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+formatTextField(actualLab.camp_name)+'</div>\n';
                        htmlActual += '        </div>\n';
                        htmlActual += '        <div class="form-group row">\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">Data/ora inizio</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+getFormattedDateDT(actualLab.location_start, 'basic_timeStartMin')+'</div>\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">Data/ora fine</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+actualLab.location_end+'</div>\n';
                        htmlActual += '        </div>\n';
                        htmlActual += '        <div class="form-group row">\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">ID esterno</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+actualLab.location_ext_id+'</div>\n';
                        htmlActual += '            <label for="" class="control-label col-2 col-form-label">Note location</label>\n';
                        htmlActual += '            <div class="col-4 view-param">'+formatTextField(actualLab.location_note)+'</div>\n';
                        htmlActual += '        </div>\n';

                        actualLabs.push(htmlActual);
                    }
                    else{ // old allocations

                        htmlOld += '                <tr data-id="'+location.location_id+'">\n';
                        htmlOld += '                    <td>'+location.location_name+'</td>\n';
                        htmlOld += '                    <td>'+getFormattedDateDT(location.location_start, 'basic_timeStartMin')+'</td>\n';
                        htmlOld += '                    <td>'+location.location_end+'</td>\n';
                        htmlOld += '                    <td>'+location.location_ext_id+'</td>\n';
                        htmlOld += '                    <td>'+formatTextField(location.camp_name)+'</td>\n';
                        htmlOld += '                    <td>'+location.location_note+'</td>\n';
                        htmlOld += '                </tr>\n';
                    }
                });

                // if there are stations still allocated, add title
                if(actualLabs.length > 0){
                    html += '        <h4 class="box-title m-t-30"><strong>Mezzi attualmente</strong> stanziati in questa location</h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += actualLabs.join('        <hr class="m-t-0 m-b-20">\n');
                }

                // if there are old allocation, add table and initialize it
                if(htmlOld != ''){
                    html += '        <h4 class="box-title m-t-20"><strong>Storico dei mezzi</strong> stanziati in questa location</h4>\n';
                    html += '        <hr class="m-t-0 m-b-20">\n';
                    html += '        <table id="pos-table-'+siteId+'" class="display responsive table table-hover table-striped tbl-va-center table-compressed" cellspacing="0" width="100%">\n';
                    html += '            <thead>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Mezzo</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>ID esterno</th>\n';
                    html += '                    <th>Campagna</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </thead>\n';
                    html += '            <tbody>\n';
                    html += htmlOld;
                    html += '            </tbody>\n';
                    html += '            <tfoot>\n';
                    html += '                <tr>\n';
                    html += '                    <th class="bobo-nowrap">Mezzo</th>\n';
                    html += '                    <th class="bobo-nowrap">Data inizio</th>\n';
                    html += '                    <th>Data fine</th>\n';
                    html += '                    <th>ID esterno</th>\n';
                    html += '                    <th>Campagna</th>\n';
                    html += '                    <th>Note</th>\n';
                    html += '                </tr>\n';
                    html += '            </tfoot>\n';
                    html += '        </table>\n';
                }
            }

            // check if there are attachments
            if(attachments != null){
                html += '        <h4 class="box-title m-t-30">Allegati</strong></h4>\n';
                html += '        <hr class="m-t-0 m-b-20">\n';
                html += '        <div class="form-group row">\n';
                html += '            <label for="" class="control-label col-2 col-form-label">File caricati</label>\n';
                html += '            <div class="col-10 view-param">\n';

                var htmlImages = '';
                var htmlFiles = '';

                htmlImages +='        <div class="form-group row attachment-gallery-big">\n';
                htmlImages +='            <div class="col-10 offset-lg-2">\n';

                // loop through attachments
                // different items depending on the file type
                $.each(attachments, function(idx, attachment){

                    // image files
                    if(attachment.file_image == true){
                        htmlImages +='<a href="'+attachment.file_path+'" class="clearfix thumb-gallery-lg"><img src="'+attachment.file_path+'"></a>\n';
                    }
                    else{ // other files
                        htmlFiles +='<a href="'+attachment.file_path+'" target="_blank"><i class="ti-download text-info"></i> '+attachment.file_name+'</a><br>\n';
                    }
                });

                htmlImages +='            </div>\n';
                htmlImages +='        </div>\n'; // closure

                html += htmlFiles;

                html += '            </div>\n';
                html += '        </div>\n'; //closure
                html += htmlImages;
            }

            // final button
            html += '        <hr class="m-t-30">\n';
            html += '        <div class="form-group row">\n';
            html += '            <div class="col-12">\n';
            html += '                <button type="button" class="btn btn-primary close-detail" data-close="site'+siteId+'"> <i class="icon-close"></i> Chiudi elemento</button>\n';
            html += '            </div>\n';
            html += '        </div>\n';
            html += '    </div>\n';
            html += '</div>\n';

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            $('.tab-content').append(html);

            // gallery for image attachments
            refreshGalleryBig();

            // init detail map with marker on site coordinates
            initMapView(siteId, footer);
            var layer = createLayer('Location', 0, mapView[siteId]);

            layer.setStyle(defaultStyleFunction);
            var feature = new ol.Feature({
                popup_flag: false,
                geometry: new ol.geom.Point(ol.proj.transform([parseFloat(site.site_wgs84_lon), parseFloat(site.site_wgs84_lat)], 'EPSG:4326', 'EPSG:3857'))
            });

            layer.getSource().addFeature(feature);

            mapView[siteId].getView().fit(feature.getGeometry(), {
                minResolution: 15
            });

            // init datatable if html element exists
            if($('#pos-table-'+siteId).length > 0){

                $('#pos-table-'+siteId).DataTable({
                    "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
                    // 'copy', 'csv', 'excel', 'pdf', 'print'
                    "buttons": [
                        'csv',
                        'pdf',
                        {
                            "extend": 'print',
                            "text"  : 'STAMPA'
                        }
                    ],
                    "order": [[ 1, "desc" ]]
                });
            }

            // show detail tabl
            $('.customtab a[href="#site'+siteId+'"]').tab('show');

            // manage resize map
            if(mapView[siteId]){
                setTimeout(function(){
                    // console.log(rpid);
                    mapView[siteId].updateSize();
                }, 100);
            }


        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della bombola", "error");
        });
    }

    /**
     * OpenStreetMap initialization function (detail map)
     *
     * @param {integer} id Map ID.
     * @param {string}  attributions Copyright attributions.
     */
    function initMapView(id, attributions) {

        console.log('initMap');

        var selectedFeature;
        // set Italy map bounds
        var boundingExtent = ol.extent.boundingExtent([[swLong, swLat], [neLong, neLat]]);
        boundingExtent = ol.proj.transformExtent(boundingExtent, ol.proj.get('EPSG:4326'), ol.proj.get('EPSG:3857'));

        var view = new ol.View();

        // create layer 'Satellite'
        var satellite = new ol.layer.Tile({
            name: 'Satellite',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                url: 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                maxZoom: 23,
                attributions: 'Esri, Maxar, Earthstar Geographics, CNES/Airbus DS, USDA FSA, USGS, Getmapping, Aerogrid, IGN, IGP, and the GIS User Community - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // create layer 'Topografia'
        var hiking = new ol.layer.Tile({
            name: 'Topografia',
            source: new ol.source.XYZ({
                attributionsCollapsible: true,
                // url: 'http://maps.refuges.info/hiking/{z}/{x}/{y}.png',
                url: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
                maxZoom: 23,
                attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors -  <a href="https://opentopomap.org/" target="_blank">OpenTopoMap</a> - '+attributions
            }),
            baseLayer: true,
            visible: false
        });

        // initialize the map on the "map-view-XX" div
        // in the cylinder detail tab
        mapView[id] = new ol.Map({
            target: 'map-view-'+id,
            layers: [
                new ol.layer.Tile({
                    source: new ol.source.OSM({
                        attributions: '© <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors - '+attributions
                    }),
                    baseLayer: true,
                    name: 'Standard'
                }),
                hiking,
                satellite
            ],
            view: view,
            controls: ol.control.defaults.defaults({attribution: false})
        });

        view.fit(boundingExtent, mapView[id].getSize());

        /* CONTROLS */
        var fullscreen = new ol.control.FullScreen();
        mapView[id].addControl(fullscreen);

        // check if map attributions are not defined
        if(attributions != undefined ){
            // add attributions to the map
            var attribution = new ol.control.Attribution({
                collapsible: true
            });

            mapView[id].addControl(attribution);
        }

        return;
    };
});