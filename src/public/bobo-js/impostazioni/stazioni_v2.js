/**
 * Document ready
 */
$(document).ready(function() {

    // GLOBAL VARIABLES
    var table;
    var mainMap;

    var mapView = [];
    var mySwitchActive;
    var mySwitchSuspended;
    var mySwitchWebservice;
    var mySwitchSuspended;
    var mySwitchPublished;
    var mySwitchRealtime;

    // show "Nuova" tab only if user has insert grants
    if(insert_grant)
        $('#hidden-tab').show();
    else
        $('#hidden-tab').hide();

    // plugins initialization
    $("#provinces, #networks").select2();

    //datatable
    table = $('#table-stations').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        pageLength: 25,
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text"  : 'STAMPA'
            }
        ],
        order: [[ 1, "asc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        },
        columnDefs: [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "width": "55px", "targets": 0 } ]
    });


    // !!CHANGE EVENTS
    /**
     * Change event on filters
     */
    $("#networks, #provinces, #status").on("change", function (e) {
        e.preventDefault();

        // if user selected a specific network then reset pronvinces
        if($(this).attr('id') == 'networks'){
            $("#provinces").val(-1);
        }
        // load stations
        loadStations();
    });

    // TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////
    /**
     * Retreive station detail.
     */
    $('#table-stations').on('click', '.show-el', function(e){
        e.preventDefault();

        // get station id stored in tr
        var stid = parseInt($(this).parent().parent().data("id"));

        // check if the station's detail is already open
        if( $('#st'+stid).length ) {
            console.log('The station\'s detail is already open');
            $('.customtab a[href="#st' + stid + '"]').tab('show');
            return;
        }

        // build html detail and open new tab
        createStationDetail(stid);
    });

    /**
     * Edit station.
     */
    $('#table-stations').on('click', '.edit-el', function(e){
        e.preventDefault();
        // show "Modifica" tab
        $('#hidden-tab').show();

        // get station id stored in tr
        var stid = parseInt($(this).parent().parent().data("id"));
        // retrieve data from db and fill form
        fillEditForm(stid);
    });

    /**
     * Delete station
     */
    $('#table-stations').on('click', '.delete-el', function(e){
        e.preventDefault();
        console.log('elimina elemento');

        var stid = parseInt($(this).parent().parent().data("id"));

        // html to inject into the swal
        var txt = '';
        txt += 'Non sarà possibile eliminare la stazione se sono presenti degli elementi associati (parametri, strumenti, ... ).<br>';
        txt += '<strong>Tutti i dati saranno persi definitivamente!</strong><br><br>';
        txt += 'Sei proprio sicuro di voler proseguire all\'eliminazione?<br>';
        txt += '<input type="checkbox" id="delete-confirm" name="delete-confirm" /> <label for="delete-confirm">Confermo</label>';

        // show confirm message
        swal({
            title: "Stai per eliminare la stazione",
            text: txt,
            type: "warning",
            html: true,
            showCancelButton: true,
            confirmButtonText: "Prosegui",
            closeOnConfirm: false,
            showLoaderOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {

            // if Annulla then return
            if (isConfirm === false) return false;
            // if checkbox not checked then show validation error
            if (! $('#delete-confirm').is(':checked') ) {
                swal.showInputError("E' necessario confermare l'eliminazione");
                return false;
            }

            // delete the selected report
            var jqxhr = $.ajax({
                url: '/cnf_stazioni_del_station',
                type: "post",
                dataType: "json",
                data: {
                    id: stid
                }
            })
            .done(function(result) {

                // check result
                // if 1 then remove station and clear form
                // else if -1 then there are linked elements
                // else if -2 then there are data in station's table
                // else generic error
                if(result == 1){
                    swal("Stazione eliminata", "L'elemento è stato eliminato con successo!", "success");
                    // remove row from table
                    table.row($("tr[data-id='"+stid+"']")).remove().draw();
                    clearFields();
                }
                else if(result == -1){
                    swal({
                        title: "Attenzione",
                        text: "Non è stato possibile eliminare la stazione<br>Sono presenti degli <strong>elementi associati alla stessa</strong>!",
                        type: "warning",
                        html: true
                    });
                }
                else if(result == -2){
                    swal({
                        title: "Attenzione",
                        text: "Non è stato possibile eliminare la stazione<br>Sono presenti dei <strong>dati nella relativa tabella</strong>!",
                        type: "warning",
                        html: true
                    });
                }
                else{
                    swal("Errore!", "Errore durante l'eliminazione della stazione", "error");
                }

            })
            .fail(function(xhr, err) {
                // show error message
                swal("Errore!", "Errore durante l\'eliminazione della stazione", "error");
            });
        });
    });

    /**
     * Download station PDF
     */
    $('#table-stations').on('click', '.pdf-el', function(e){
        e.preventDefault();

        console.log('scarica pdf');
    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS


    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // hide map container and second part of form (visible in edit case)
    $('.map-container, .hidden-part').hide();

    // plugins initialization
    $( "#station-schemadb, #station-network, #station-region, #station-province, #station-municipality").select2();

    mySwitchActive = new Switchery($("#station-active")[0], $("#station-active").data());
    mySwitchSuspended = new Switchery($("#station-suspended")[0], $("#station-suspended").data());
    mySwitchPublished = new Switchery($("#station-published")[0], $("#station-published").data());
    mySwitchStationExport = new Switchery($("#station-export-active")[0], $("#station-export-active").data());
    mySwitchWebservice = new Switchery($("#station-ws-active")[0], $("#station-ws-active").data());
    mySwitchRealtime = new Switchery($("#station-realtime")[0], $("#station-realtime").data());

    // date picker
    $('#station-startup-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(1, "month"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
        // autoclose: true,
        // todayHighlight: true
    });
    $('#station-startup-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));

    // date picker
    $('#station-dismiss-date').bootstrapMaterialDatePicker({
        maxDate: moment().add(1, "month"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
        // autoclose: true,
        // todayHighlight: true
    });
    $("#station-dismiss-date").prop("disabled", true);

    /**
     * Main map initialization.
     */
    mainMap = initMap('map-selection', footer);
    var layer = createLayer('Stazione', 0, mainMap);
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
        $("#station-wgs84-lat").val(lat);
        $("#station-wgs84-lon").val(lon);
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

        var layer = getLayerByName('Stazione', mainMap);

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
        $("#station-wgs84-lat").val(lat);
        $("#station-wgs84-lon").val(lon);
        // get municipality containing these coordinates
        loadMunicipality(lon, lat);
    });

    /**
     * Click event on "Scegli da mappa" button
     */
    $('#btn-map-selection').on('click', function(e) {
        e.preventDefault();

        // base on map container visibility
        // take care of html elements style
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
        // zoom to italy
        setTimeout(function(){
            mainMap.updateSize();
            zoomToRegion(mainMap, portal_region);
        }, 200);
    });

    // CHANGE EVENTs
    $('#station-name, #station-province').on('change', function(e){
        // check if it is an "insert" action
        if( isNaN( parseInt($('#station-id').val()) ) && parseInt( $("#station-province").val() ) != -1 )
            createTableName();
    });

    // Change event of regions select
    $( "#station-region").on( "change", function(e, prid, muid) {
        var reid = $(this).val();
        // reload provinces based on selected region
        loadProvinces(reid, prid, muid);
    });

    // Change event of provinces select
    $( "#station-province").on( "change", function(e, muid) {
        var prid = $(this).val();
        // reload municipalities based on selected province
        loadMunicipalities(prid, muid);
    });

    // Change event of station active switch
    $( "#station-active").on("change", function(){

        // take care of dismiss date field
        var check = $("#station-active").is(":checked");
        if(check){
            $("#station-dismiss-date").prop("disabled", true);
            $("#station-dismiss-date").val("");
        }
        else{
            $("#station-dismiss-date").prop("disabled", false);
            $("#station-dismiss-date").val("");
            $("#station-dismiss-date").bootstrapMaterialDatePicker("setDate", moment().format('DD/MM/YYYY'));
        }
    });

    // validate form
    validator = $('#station-form').validate({ // initialize the plugin
        rules: {
            "station-name": {
                required: true,
                maxlength: function(){
                    if( isNaN( parseInt( $('#station-id').val())) )
                        return 25;
                    else
                        return 100;
                }
            },
            "station-headerfile": {
                required: true
            },
            "station-tabledb": {
                required: true
            },
            "station-schemadb": {
                required: true,
            },
            "station-headerfile": {
                required: true
            },
            "station-roaming": {
                min: 0
            },
            "station-startup-date": {
                required: true,
                validDate: true
            },
            "station-dismiss-date": {
                required: function(element){
                    return ! $("#station-active").is(':checked');
                },
                validDate: true
            },
            "station-municipality": {
                required: true,
                min: 0
            },
            "station-network": {
                required: true,
                min: 0
            },
            "station-wgs84-lat": {
                required: true,
                dotSeparator: true
            },
            "station-wgs84-lon": {
                required: true,
                dotSeparator: true
            },
            "station-altitude": {
                regex: '^[0-9]{0,4}$'
            },
            "station-shortname": {
                required: true
            },
            "station-typology": {
                min: 0
            }
        },
        messages: {
            "station-name": {
                required: "Inserire nome",
                maxlength: jQuery.validator.format("Inserire al massimo {0} caratteri")
            },
            "station-headerfile": {
                required: "Inserire header file"
            },
            "station-tabledb": {
                required: "Inserire tabella database"
            },
            "station-schemadb": {
                required: "Selezionare schema database",
            },
            "station-headerfile": {
                required: "Inserire header file",
            },
            "station-roaming": {
                min: "Selezionare una categoria"
            },
            "station-startup-date": {
                required: "Inserire data di attivazione"
            },
            "station-dismiss-date": {
                required: "inserire data di dismissione"
            },
            "station-region": {
                required: "Selezionare regione",
                min: "Selezionare regione"
            },
            "station-province": {
                required: "Selezionare provincia",
                min: "Selezionare provincia"
            },
            "station-municipality": {
                required: "Selezionare comune",
                min: "Selezionare comune"
            },
            "station-network": {
                required: "Selezionare rete",
                min: "Selezionare rete"
            },
            "station-wgs84-lat": {
                required: "Inserire latitudine",
                regex: "Formato coordinata non valido: max 6 decimali, separatore . [es. 45.741704]"
            },
            "station-wgs84-lon": {
                required: "Inserire longitudine",
                regex: "Formato coordinata non valido: max 6 decimali, separatore . [es. 7.322683]"
            },
            "station-altitude": {
                regex: "Formato non valido"
            },
            "station-shortname": {
                required: "Inserire nome breve"
            },
            "station-typology": {
                min: "Selezionare un tipo di stazione"
            }
        },
        ignore: ":disabled,:hidden",
        errorPlacement: function ( error, element ) {

            if(element.parent().hasClass('input-group')){
                error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        }
    });

    /**
     * Submit event
     */
    $('#station-form').on('submit', function (e) {
        e.preventDefault();

        // sanity check
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Modifiche non salvate!", "info");
            return false;
        };

        var id = parseInt($("#station-id").val());

        // serialize form into an array and push custom variables
        var form = $("#station-form").serializeArray();
        // push station table
        form.push({ name: "station-tabledb", value: $('#station-tabledb').val() });

        // insert action
        if(isNaN(id)){
        // push station header file
        form.push({ name: "station-headerfile", value: $('#station-headerfile').val() });
        }

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        $.ajax({
            type: 'post',
            url: '/cnf_stazioni_put_station',
            data: form
        }).done(function(result) {

            // check result
            // if 1 then show success message and refresh main list: in case of insert action show the hidden part of the form and fill it
            // if -1 then there is another station with the same combination of schema and table
            // else take care of error
            if(result > 0){
                // edit action
                if(! isNaN(id)){
                    // show success message
                    $.toast({
                        heading: 'Successo',
                        text: 'Stazione modificata correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                    // at the end of the process hide preloader
                    $('.inner-preloader').hide();
                }
                else{ // insert action
                    // show success message
                    $.toast({
                        heading: 'Successo',
                        text: 'Stazione inserita correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                    // fill form by passing the returned station id
                    fillEditForm(result);

                    // ! preloader hidden by fillEditForm function !
                }

                // refresh main list
                $('#provinces').trigger('change');
            }
            else if (result == -1){
                // warning message
                swal({
                    title: "Attenzione!",
                    text: "Esiste un'altra stazione con gli <strong>stessi valori di SCHEMA e TABELLA database</strong>.<br> Modificare il nome della stazione!",
                    type: "warning",
                    html: true
                });
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
            else if (result == -2){
                // warning message
                swal({
                    title: "Attenzione!",
                    text: "I dati sono stati salvati correttamente, ma si è verificato un errore inaspettato durante la creazione delle tabelle su database.<br><br><strong>Contattare gli amministratori di sistema.</strong>",
                    type: "error",
                    confirmButtonText: "Ho capito",
                    html: true
                });
                // refresh main list
                $('#provinces').trigger('change');
                // clear field and close form
                $('#station-cancel').trigger('click');
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
            else{
                swal("Errore!", 'Errore durante il salvataggio dei dati!', "error");
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            }
        })
        .fail(function(xhr, err) {
            swal("Errore!", 'Errore durante il salvataggio dei dati!', "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    /**
     * Click event on "Annulla" button
     */
    $('#station-cancel').on("click", function(e){
        e.preventDefault();
        // reset form
        clearFields();
        // show main stations list
        $('.customtab a[href="#list"]').tab('show');
        // hide Nuovo tab if user hasn't insert grant
        if(!insert_grant)
            $('#hidden-tab').hide();

    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    /**
     * Click event on "Chiudi" buttons
     */
    $('.card-body').on('click', '.close-detail', function(e){
        e.preventDefault();
        // get "element" to be closed
        var close = $(this).data("close");
        console.log(close);

        setTimeout(function(){
            // remove element and show first tab
            $('.customtab a[href="#' + close + '"]').remove();
            $('.tab-content #'+close).remove();
            $('.customtab a[href="#list"]').tab('show');
        }, 1);
    });

    // first load of provinces and stations
    $("#networks").trigger("change"); // select option -1
    // if stid from server is not null then show station detail
    if (stid != null && ! isNaN(stid) ) {
        createStationDetail(stid);
    }


    // UTILITIES FUNCTION

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
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null then returns string '--';
     *         If not null then returns the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    };

    /**
     * Function that checks a boolean value and adds the html icon.
     *
     * @param {boolean} field Boolean value provided to format.
     *
     * @return If true, the 'V' icon;
     *         If false, the 'X' icon;
     */

    function formatFlagField(field) {
        if(field == true)
            return '<i class="fa-solid fa-check text-success"></i>&nbsp;Si';
        else
            return '<i class="fa-solid fa-xmark text-danger"></i>&nbsp;No';
    }

    // END UTILITIES

    /**
     * Function that resets fields of the form
     * No args needed
     */
    function clearFields(){
        // manage input type text
        $('.clear-input').val("");
        // manage select
        $('.clear-select').val(-1).trigger('change');

        // manage Switchery
        setSwitchery(mySwitchActive         , true);
        setSwitchery(mySwitchStationExport  , false);
        setSwitchery(mySwitchSuspended      , false);
        setSwitchery(mySwitchPublished      , false);
        setSwitchery(mySwitchRealtime       , false);
        setSwitchery(mySwitchWebservice     , false);

        $('#station-schemadb').val('').trigger('change');
        $('#station-schemadb').prop('disabled', false);

        $('#station-headerfile').prop('disabled', true);

        $('#station-startup-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));
        $("#station-dismiss-date").prop("disabled", true);

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
        $('.hidden-part  ').hide();

        // reset form texts
        $('#inner-new-station').text('Nuova');
        $('#new-element .box-title').html('Inserisci nuova <strong>STAZIONE</strong>');
        // reset validate plugin
        $('#station-form').validate().resetForm(); // reset form error
    };

    /**
     * Function that creates table from inserted name and province
     * No args needed
     */
    function createTableName(){

        var code = $("#station-province option:selected").data('code').toLowerCase();
        var stationName = $('#station-name').val().toLowerCase();
        stationName = stationName.replace(/[^a-zA-Z0-9 ]/g, '').replace(/\s+/g, ' ').trim();

        var tableName = stationName.replace(/\s/g, '_');
        tableName = code+'_'+tableName;

        $('#station-tabledb').val(tableName);
        $('#station-headerfile').val(tableName);
    };

    /**
     * Function that retrieves all stations
     * No args needed
     */
    function loadStations(){

        var prid = parseInt($("#provinces").val());
        var netid = parseInt($("#networks").val());
        var status = parseInt($("#status").val());

        // clear table
        if(table)
            table.clear();

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_stations',
            type: "post",
            dataType: "json",
            data: {
                netid: netid,
                prid: prid,
                status: status
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then fill province filter and main table with retrieved data
            if(result.res == 'OK'){

                // reset "province" filter
                if(prid == -1){
                    $('#provinces').empty();
                    $('#provinces').append('<option value="-1">Seleziona provincia...</option>');
                }

                var stations = result.stations;
                // perform the distinct of the provinces
                // exclude null values
                var provinces = stations.filter((value, index, self) =>
                    index === self.findIndex((t) => (
                        t.province_id === value.province_id && t.province_id != null
                    ))
                );
                // order them by region name and province name
                provinces.sort((a, b) => a.region_name.localeCompare(b.region_name) || a.province_name.localeCompare(b.province_name));

                // variable for dinamically building the html
                var opts = '';
                var rows = '';
                var net;

                var optsProv = '';
                var reg;
                var prov;

                if(stations.length > 0){
                    // loop through all elements
                    // for each station, build a html option to be added to the select
                    $.each(stations, function(index, value){

                        var isActive = '';
                        if (value.station_active == false){
                            isActive = "not-active "
                        }else{
                            isActive = '';
                        }

                        rows += '<tr class="'+isActive+'" data-id="'+value.station_id+'">';
                        rows += '    <td class="bobo-nowrap icons-little">';
                        rows += '        <a href="javascript:void(0)" class="show-el" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                        if(update_grant)
                            rows += '        <a href="javascript:void(0)" class="edit-el" data-toggle="tooltip" data-original-title="Modifica"> <i class="icon-pencil text-info"></i> </a>';
                        if(delete_grant)    
                        rows += '        <a href="javascript:void(0)" class="delete-el" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';

                        if (value.station_active){
                            rows += '        <br>';
                            rows += '        <a href="/str_mapper/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Sinottico di Mapper"><i class="fa-regular fa-circle-location-arrow text-success"></i></a>';
                            rows += '        <a href="/dat_istantanei/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Dati istantanei"><i class="fa-regular fa-calendar-clock text-success"></i></a>';
                            rows += '        <a href="/cnf_parametri/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Parametri di stazione"><i class="fa-solid fa-signal-stream text-success"></i></a>';
                        }
                        // rows += '        <a href="javascript:void(0)" class="pdf-el" data-toggle="tooltip" data-original-title="Scarica PDF"> <i class="ti-download text-danger"></i> </a>';
                        rows += '    </td>';
                        rows += '    <td>'+value.station_id+'</td>';
                        rows += '    <td>'+value.station_name+'</td>';
                        rows += '    <td>'+value.station_network_type_name+'</td>';
                        rows += '    <td>'+value.province_code+'</td>';
                        rows += '    <td>'+value.mu_name+'</td>';
                        rows += '    <td>'+value.station_locality+'</td>';
                        rows += '    <td>'+getFormattedDateDT(value.station_startup_date, 'basic')+'</td>';
                        rows += '    <td class="hidden-lbl-icon">';
                        if (value.station_published)
                            rows += '        <i class="fa-solid fa-circle-check text-success" data-toggle="tooltip" data-original-title="Stazione Pubblica" aria-hidden="true"></i>&nbsp;<span>Si</span>';
                        rows += '    </td>';

                        if(value.station_active == true){
                            if(value.station_suspended == true){
                                rows += '   <td class="hidden-lbl-icon"><i class="fa-solid fa-circle-ellipsis text-muted" data-toggle="tooltip" data-original-title="Stazione sospesa"></i>&nbsp;<span>sospesa</span></td>';
                            }else{
                                rows += '   <td class="hidden-lbl-icon"><i class="fa-solid fa-circle-check text-info" data-toggle="tooltip" data-original-title="Stazione attiva"></i>&nbsp;<span>attiva</span></td>';
                            }
                        }else{
                            rows += '    <td class="hidden-lbl-icon"><i class="fa-solid fa-circle-xmark text-danger" data-toggle="tooltip" data-original-title="Stazione non attiva"></i>&nbsp;<span>non attiva</span></td>';
                        }

                        // rows += '    <td class="hidden-lbl-icon">';
                        // if (value.station_active){
                        //     rows += '        <a class="text-warning" href="/str_mapper/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Sinottico di Mapper"><i class="fa-solid fa-circle-location-arrow"></i></a>';
                        //     rows += '        <a class="text-primary" href="/cnf_parametri/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Parametri di stazione"><i class="fa-solid fa-signal-stream"></i></a>';
                        //     rows += '        <a class="text-info" href="/dat_istantanei/'+value.station_id+'" target="_blank" data-toggle="tooltip" data-original-title="Dati istantanei"><i class="fa-solid fa-calendar-clock"></i></a>';
                        // }
                        // rows += '    </td>';
                        rows += '    <td></td>';
                        rows += '</tr>';

                    });

                    // check prid value
                    //     - if equal to -1 then, loadStations called by a network change
                    //     -> reset select and fill it again with filtered provinces
                    if(prid == -1){
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


                        $('#provinces').append(optsProv);
                        $('#provinces').append('</optgroup>');

                        $('#provinces').val(-1);
                    }


                    // add rows to datatable by using html object and redraw it
                    table.rows.add($( rows ));
                    table.draw();
                    table.columns.adjust();

                    // initializes the tooltips of all lines
                    // loop through each table row contained in all pages (not only the visible one )
                    table.rows({page: 'all'}).every(function() {
                        var row = this;
                        // get all tr node and transform it into a jquery items
                        // in order to find all tooltip elements
                        $(row.node())
                            .find('[data-toggle="tooltip"]')
                            .tooltip();
                    });
                }
                else{
                    table.draw();
                }
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero delle stazioni", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
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
        $("#station-province").empty();
        $('#station-province').append('<option value="-1">Seleziona provincia...</option>');

        // check if region is selected
        if( reid == null){
            // if not selected then reset province
            $("#station-province").val(-1);
            return;
        }

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_provinces',
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
                console.dir(provinces);

                // create option items for "#station-province" select
                var opts = '';
                // loop through all elements
                // for each province, build a html option to be added to the select
                $.each(provinces, function(index, prov){
                    opts += '<option data-code="'+ prov.province_code +'" value="'+ prov.province_id+'">'+prov.province_name+'</option>';
                });
                // append options
                $('#station-province').append(opts);
                // if exists, set province
                if(prid)
                    $("#station-province").val(prid).trigger('change', muid); // passing municipality id
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
        $("#station-municipality").empty();
        $('#station-municipality').append('<option value="-1">Seleziona comune...</option>');

        // check if municipality is selected
        if(prid == null){
            // if not selected then reset municipality
            $('#station-municipality').val(-1);
            return;
        }

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_municipalities',
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
                // create option items for "#station-municipality" select
                var opts = '';
                // loop through all elements
                // for each municipality, build a html option to be added to the select
                $.each(municipalities, function(index, mu){
                    opts += '<option value="'+ mu.mu_id+'">'+mu.mu_name+'</option>';
                });
                // append options
                $('#station-municipality').append(opts);
                // if exists, set municipality
                if(muid)
                    $("#station-municipality").val(muid);
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
            url: '/cnf_stazioni_get_municipality_by_coords',
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
                    $('#station-region').val(municipality.region_id).trigger('change', [municipality.province_id, municipality.mu_id]);
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero dei comuni", "error");
        });
    }

    /**
     * Function that retrives station metadata and builds html detail
     *
     * @param {integer} stid Station ID.
     */
    function createStationDetail(stid){
        console.log('createStationDetail: '+stid);

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // ajax call
        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_station_by_id',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {

            console.dir(result);

            // check result
            // if OK then, if user has grants, then build html detail
            // otherwise show error message
            if(result.res == 'OK'){

                var grants = result.grants;
                if(result.grants == null){
                    swal('Attenzione!', 'Non si possiedono i permessi necessari per visualizzare questa stazione', 'warning');
                    return;
                }

                var el = result.station;

                // add link for the new tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#st'+stid+'" role="tab"><span class="hidden-sm-up"><i class="fa-sharp fa-light fa-book-open-cover"></i></span> <span class="hidden-xs-down">'+el.station_name+'</span>&nbsp;&nbsp;<i class="fa fa-times text-danger close-detail" data-close="st'+stid+'"></i></a></li>';
                $('.nav').append(html);

                // variable for dinamically building the html
                var html = '';

                // after variable reset, build station detail
                html += '<div class="tab-pane p-10 p-t-15 tbl-v-centered" id="st'+stid+'" role="tabpanel">';
                html += '    <h3 class="text-primary title-main-view">Stazione di: <strong>'+el.station_name+'</strong></h3>';
                html += '    <div class="row">';
                html += '        <div class="col-xl-4 m-b-15">';
                html += '            <a href="'+result.image+'" class="image-popup-vertical-fit img-gallery"><img src="'+result.image+'" class="img-fluid" alt="'+el.station_name+'"></a>';
                html += '        </div>';
                html += '        <div class="col-xl-8">';
                html += '            <table class="table table-striped table-compressed main-tit">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="4"><i class="icon-info"></i> Iniziali</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>ID stazione</th>';
                html += '                        <td>'+stid+'</td>';
                html += '                        <th>Rete</th>';
                html += '                        <td>'+el.station_network_type_name+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Header file</th>';
                html += '                        <td>'+formatTextField(el.station_file_header)+'</td>';
                html += '                        <th>Schema e tabella DB</th>';
                html += '                        <td>'+el.station_fulltable+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>';
                html += '                            Categoria';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                            <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                            <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Le categorie sono: '+roamingTypes+'</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+el.station_roaming_type_desc+'</td>';
                html += '                        <th></th>';
                html += '                        <td></td>';
                html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '            <table class="table table-striped table-compressed main-tit">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="4"><i class="icon-directions"></i> Geografiche</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>Località</th>';
                html += '                        <td>'+formatTextField(el.station_locality)+'</td>';
                html += '                        <th>Comune</th>';
                html += '                        <td>'+el.mu_name+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Provincia</th>';
                html += '                        <td>'+el.province_name+'</td>';
                html += '                        <th>Regione</th>';
                html += '                        <td>'+el.region_name+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Latitudine WGS84</th>';
                html += '                        <td>'+formatTextField(el.station_lat_wgs84)+' °N</td>';
                html += '                        <th>Longitudine WGS84</th>';
                html += '                        <td>'+formatTextField(el.station_lon_wgs84)+' °N</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Quota</th>';
                html += '                        <td>'+formatTextField(el.station_altitude)+' m s.l.m.</td>';
                html += '                        <th>Zona</th>';
                html += '                        <td>'+formatTextField(el.station_zone)+'</td>';
                html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '            <table class="table table-striped table-compressed main-tit">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="4"><i class="icon-settings"></i> Generali</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>Staz. attiva</th>';
                html += '                        <td>'+formatFlagField(el.station_active)+'</td>';
                html += '                        <th>';
                html += '                            Stazione sospesa';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Se sospesa, viene esclusa da tutti gli script di gestione del sistema.</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+formatFlagField(el.station_suspended)+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Attiva dal</th>';
                html += '                        <td>'+formatTextField(el.station_startup_date)+'</td>';
                html += '                        <th>Dismessa il</th>';
                html += '                        <td>'+formatTextField(el.station_dismiss_date)+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>';
                html += '                            ID telecontrollo';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Da utilizzare su applicativi di telecontrollo (es. Anydesk, Teamviewer, Supremo, Vnc Viewer).</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+formatTextField(el.station_remote_ctrl)+'</td>';
                html += '                        <th>';
                html += '                            ID esterno';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Id stazione esposto dall\'API e usato per la mappatura con i sistemi interni di ciascuna ARPA</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+formatTextField(el.station_external_id)+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Real-time attivo</th>';
                html += '                        <td colspan="3">'+formatFlagField(el.station_real_time)+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Note</th>';
                html += '                        <td colspan="3">'+formatTextField(el.station_note)+'</td>';
                html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '        </div>';
                html += '    </div>';
                html += '    <h6 class="title-stat m-b-20"><i class="ti-ruler-pencil"></i> Impostazioni <strong>avanzate stazione</strong></h6>';
                html += '    <div class="row">';
                html += '        <div class="col-xl-8">';
                html += '            <table class="table table-striped table-compressed main-tit" id="table-extra-info">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="6"><i class="icon-plus"></i> Maggiori informazioni</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>Nome breve</th>';
                html += '                        <td>'+formatTextField(el.station_shortname)+'</td>';
                html += '                        <th>Nome intero</th>';
                html += '                        <td>'+formatTextField(el.station_longname)+'</td>';
                html += '                        <th>';
                html += '                            Tipo stazione';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Le tipologie sono: '+typologies+'</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+el.station_typology_desc+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>';
                html += '                            Tipo misurazione';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Le tipologie sono: '+measuresTypes+'</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+el.station_measure_type_desc+'</td>';
                html += '                        <th>';
                html += '                            Cadenza misurazione';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Le tipologie sono: '+measuresCadences+'</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+el.station_cadence_type_desc+'</td>';
                html += '                    </tr>';
                // html += '                    <tr>';
                // html += '                        <th>Codice nazionale</th>';
                // html += '                        <td colspan="5">--</td>';
                // html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '            <table class="table table-striped table-compressed main-tit" id="table-import">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="2"><i aria-hidden="true" class="fa-light fa-file-import"></i> Varie Import</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>Codice web service</th>';
                html += '                        <td style="width: 40%;">'+formatTextField(el.station_import_ws_id)+'</td>';
                html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '            <table class="table table-striped table-compressed main-tit" id="table-export">';
                html += '                <thead>';
                html += '                    <tr>';
                html += '                        <th colspan="4"><i aria-hidden="true" class="fa-light fa-file-export"></i> Varie Export</th>';
                html += '                    </tr>';
                html += '                </thead>';
                html += '                <tbody>';
                html += '                    <tr>';
                html += '                        <th>Stazione pubblica</th>';
                html += '                        <td>'+formatFlagField(el.station_published)+'</td>';
                html += '                        <th></th>';
                html += '                        <td></td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Export attivo</th>';
                html += '                        <td>'+formatFlagField(el.station_export_active)+'</td>';
                html += '                        <th>';
                html += '                            Export ID';
                html += '                            <a class="mytooltip" href="javascript:void(0)">';
                html += '                                <i class="fa-regular fa-circle-info text-info"></i>';
                html += '                                <span class="tooltip-content5"><span class="tooltip-text3"><span class="tooltip-inner2">Id stazione usato per l\'export di file CSV o estensioni personalizzate</span></span></span>';
                html += '                            </a>';
                html += '                        </th>';
                html += '                        <td>'+formatTextField(el.station_export_id)+'</td>';
                html += '                    </tr>';
                html += '                    <tr>';
                html += '                        <th>Webservice attivo</th>';
                html += '                        <td>'+formatFlagField(el.station_ws_active)+'</td>';
                html += '                        <th>Nome per webservice</th>';
                html += '                        <td style="width: 20%;">'+formatTextField(el.station_ws_name)+'</td>';
                html += '                    </tr>';
                html += '                </tbody>';
                html += '            </table>';
                html += '        </div>';
                html += '        <div class="col-xl-4 m-b-20">';
                html += '            <div id="map-'+stid+'" class="medium-map" tabindex="0"></div>';
                html += '            <div class="m-t-5 font-16"><a class="" href="/str_mapper/'+stid+'" target="_blank"><i class="fa-solid fa-circle-location-arrow text-success" aria-hidden="true"></i> Vai al sinottico di Mapper</a></div>';
                html += '        </div>';
                html += '    </div>';
                html += '    <hr class="m-t-0">';
                html += '    <div class="form-group row">';
                html += '        <div class="col-12">';
                html += '            <button type="button" class="btn btn-primary close-detail" data-close="st'+stid+'"> <i class="icon-close"></i> Chiudi elemento</button>';
                html += '            <a class="btn btn-secondary" href="/cnf_parametri/'+stid+'" target="_blank" data-toggle="tooltip" data-original-title="Parametri di stazione"><i class="fa-solid fa-signal-stream"></i> Parametri</a>';
                html += '            <a class="btn btn-secondary" href="/dat_istantanei/'+stid+'" target="_blank" data-toggle="tooltip" data-original-title="Dati istantanei"><i class="fa-regular fa-calendar-clock"></i> Istantanei</a>';
                html += '        </div>';
                html += '    </div>';
                html += '</div>';

                // at the end of the process hide preloader
                $(".inner-preloader").hide();

                // append html
                $('.tab-content').append(html);

                mapView[stid] = initMap('map-'+stid, footer);

                // MAP STUFF
                var layer = createLayer('Stazione', 0, mapView[stid]);

                layer.setStyle(defaultStyleFunction);
                if(el.station_lat_wgs84 != '--' && el.station_lon_wgs84 != '--'){
                    var feature = new ol.Feature({
                        popup_flag: false,
                        geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.station_lon_wgs84), parseFloat(el.station_lat_wgs84)], 'EPSG:4326', 'EPSG:3857'))
                    });

                    layer.getSource().addFeature(feature);

                    mapView[stid].getView().fit(feature.getGeometry(), {
                        minResolution: 15
                    });
                }

                // show the detail tab
                $('.customtab a[href="#st'+stid+'"]').tab('show');

                // manage resize map
                if(mapView[stid]){
                    setTimeout(function(){
                        // console.log(rpid);
                        mapView[stid].updateSize();
                    }, 100);
                }

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero della stazione", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero della stazione", "error");
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    }

    /**
     * Function that retrives station metadata and fills edit form
     *
     * @param {integer} stid Station ID.
     */
    function fillEditForm(stid){
        // reset form
        clearFields();
        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get station detail via an ajax call
        var jqxhr = $.ajax({
            url: '/cnf_stazioni_get_station_by_id',
            type: "post",
            dataType: "json",
            data: {
                stid: stid
            },
        })
        .done(function(result) {
            console.log('edit station!');
            console.dir(result);

            if(result.res == 'OK'){
                var el = result.station;

                $('.hidden-part').show();

                // INIZIALI
                $("#station-id").val(stid);
                $("#station-name").val(el.station_name);
                $('#station-headerfile').val(el.station_file_header);
                $('#station-headerfile').prop('disabled', false);
                $('#station-schemadb').val(el.station_schema).trigger('change');
                $('#station-schemadb').prop('disabled', true);

                $('#station-tabledb').val(el.station_table);

                $("#station-roaming").val(el.station_roaming_type_id);

                // DATI GEOGRAFICI
                // set province and municipality to data retrieval from the server
                $('#station-region').val(el.region_id).trigger('change', [el.province_id, el.mu_id]);

                $("#station-locality").val(el.station_locality);
                $("#station-wgs84-lat").val(el.station_lat_wgs84);
                $("#station-wgs84-lon").val(el.station_lon_wgs84);
                $("#station-altitude").val(el.station_altitude);
                $("#station-zone").val(el.station_zone);

                // add marker to map and zoom map view
                var layer = getLayerByName('Stazione', mainMap);

                var feature = new ol.Feature({
                    popup_flag: false,
                    geometry: new ol.geom.Point(ol.proj.transform([parseFloat(el.station_lon_wgs84), parseFloat(el.station_lat_wgs84)], 'EPSG:4326', 'EPSG:3857'))
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

                // GENERALI
                setSwitchery(mySwitchActive, el.station_active);
                setSwitchery(mySwitchSuspended, el.station_suspended);
                setSwitchery(mySwitchRealtime, el.station_real_time);

                $("#station-startup-date").val("");
                $("#station-startup-date").bootstrapMaterialDatePicker('setDate', moment(el.station_startup_date, "DD-MM-YYYY HH:mm"));

                if( el.station_active == true){
                    $("#station-dismiss-date").prop("disabled", true);
                    $("#station-dismiss-date").val("");
                }
                else{
                    $("#station-dismiss-date").prop("disabled", false);
                    $("#station-dismiss-date").val("");
                    $("#station-dismiss-date").bootstrapMaterialDatePicker('setDate', moment(el.station_dismiss_date, "DD-MM-YYYY HH:mm"));
                }

                $("#station-visible-id").val(stid);
                $("#station-control-id").val(el.station_remote_ctrl);
                $("#station-extra-id").val(el.station_external_id);
                $("#station-note").val(el.station_note);

                // MAGGIORI INFORMAZIONI
                $("#station-shortname").val(el.station_shortname);
                $("#station-longname").val(el.station_longname);
                $("#station-typology").val(el.station_typology_id);
                $("#station-measure").val(el.station_measure_type_id);
                $("#station-cadence").val(el.station_cadence_type_id);


                // VARIE IMPORT
                $("#station-import-id").val(el.station_import_ws_id);
                // VARIE EXPORT
                setSwitchery(mySwitchPublished, el.station_published);
                setSwitchery(mySwitchStationExport, el.station_export_active);
                $("#station-export-id").val(el.station_export_id);
                setSwitchery(mySwitchWebservice, el.station_ws_active);
                $("#station-ws-name").val(el.station_ws_name);

                $("#station-network").val(el.station_network_type_id).trigger('change.select2');
                // $("#station-metadata-note").val(el.station_metadata_note);
                // $("#station-national-code").val(el.station_national_code);


                // modify 'Nuovo' text in 'Modifica'
                $('#inner-new-station').text('Modifica');
                $('#new-element .box-title').text('Modifica stazione');

                // show form tab
                $('.customtab a[href="#new-element"]').tab('show');
                 // update map size
                setTimeout(function(){
                    mainMap.updateSize();
                }, 5);
            }
            else{
               // error message
                swal("Errore!", "Errore durante il recupero del dettaglio della stazione", "error");
            }

            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero del dettaglio della stazione", "error");
        });
    }
});

