/**
 * Document ready
 */
$(document).ready(function() {

    // disable the final saving of the panel until all the pieces are completed
    $("#subgroup-add").prop("disabled",true);

    // initialize left json tree
    initializeLeftTree();

    // boostraptoggle
    $( "#subgroup-public" ).bootstrapToggle();

    // initialize select2 plugin
    $("#subgroup-groups").select2();
    $("#networks, #provinces").select2();

    // initialize multiselect plugin
    $('#multiselect').multiselect({
        right: '#subgroup-stat',
        submitAllLeft: false,
        ignoreDisabled: true,
        keepRenderingSort: true,
        search: {
            left: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
            right: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
        },
        // move station from left to right
        afterMoveToRight: function($left, $right, $options) {
            var statLng = $right.find('option').length;
            // enable/disable submit button depending on the presence or absence of selected stations
            if (statLng != 0) {
                $("#subgroup-add").prop("disabled",false);
            }else{
                $("#subgroup-add").prop("disabled",true);
            }

            return true;
        },
        // move station from right to left
        afterMoveToLeft: function($left, $right, $options) {
            var statLng = $right.find('option').length;
            // enable/disable submit button depending on the presence or absence of selected stations
            if (statLng != 0) {
                $("#subgroup-add").prop("disabled",false);
            }else{
                $("#subgroup-add").prop("disabled",true);
            }

            return true;
        },
        fireSearch: function(value) {
            return true;
        }
    });

    /**
     * Change event of bootstrap toggle element
     */
    $("#subgroup-public").on("change", function(e){
        e.preventDefault();
        // get new status
        var state = $(this).prop('checked')

        // if the subgroup becomes public disable the association of user groups
        if(state){
            // reset select2
            $("#subgroup-groups").val([]);
            // trigger change
            $("#subgroup-groups").trigger('change');
            $('#subgroup-groups').prop("disabled", true);
        }
        else{
            $('#subgroup-groups').prop("disabled", false);
        }
    });

    /**
     * Filters change event
     */
    $("#networks, #provinces").on('change', function(){

        // load stations list linked to selected pronvice and networks
        loadStationsByNetworks();
    });

    // initialize the plugin to validate form
    $('#subgroup-config').validate({
        rules: {
            "subgroup-name" : {
                required: true
            },
            "subgroup-groups" :{
                required: ! $("#subgroup-public").prop('checked')
            }
        },
        messages: {
            "subgroup-name" : {
                required: "Inserire nome sottogruppo"
            },
            "subgroup-groups" :{
                required: "Inserire gruppi"
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
     * Submit event
     */
    $('#subgroup-config').on('submit', function (e) {
        e.preventDefault();

        // check if the form is valid otherwise do nothing
        if (! $(this).valid() ){
            // warning message
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile generare questo elemento", "info");
            return false;
        };

        // find stations in right column of multiselect and set "selected" property to TRUE
        $('#subgroup-stat').find('option').prop('selected', true);

        // get form element
        var form = $('#subgroup-config');
        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // put new data to server
        var jqxhr = $.ajax({
            url: '/str_ava_ana_put_subgroup',
            type: "post",
            dataType: "json",
            data: form.serialize()
        })
        .done(function(result) {

            // chech result
            // if TRUE then refresh left tree, clear form and show success message
            // else show error message
            if(result){

                // refresh json tree
                $('#group-json').jstree(true).refresh(true);
                // clear form
                clearAll();

                swal('Successo!', 'Il sottogruppo è stato salvato correttamente!', 'success');
            }
            else{
                // error message
                swal("Errore!", "Errore durante il salvataggio", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il salvataggio", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    });

    /**
     * Click event on "Annulla" button
     */
    $('#subgroup-cancel').on('click', function(e){
        e.preventDefault();

        // check "dirty" field
        var empty = $('#subgroup-fill').val();

        // if not empty then show warning message before clear form's fields
        if (empty != ''){
            swal({
                title: "Attenzione, sottogruppo già inizializzato",
                text: "Sei proprio sicuro di voler proseguire? in caso affermativo tutte le modifiche verranno perse.",
                type: "warning",
                showCancelButton: true,
                confirmButtonText: "Si, sono sicuro",
                closeOnConfirm: true,
                cancelButtonText: "Annulla"
            }, function () {

                // success message
                swal("Sottogruppo non salvato", "Il sottogruppo non è stato modificato!", "success");
                // clear form
                clearAll();
                // reset validation
                $('#subgroup-config').validate().resetForm();
            });
        }
        else{
            // clear form
            clearAll();
        }
    });

    // trigger first load of all stations
    $('#provinces').trigger('change');

    /**
     * Function that clean multiselect plugin after stations list reload
     *
     * @param {text} left: Left column selector
     * @param {text} right: Right column selector
     */
    function cleanMultiselect(left, right){
        // loop through all options in the right column
        $(right).find('option').each(function(index, rightOption) {
            // if current option is linked to a group
            // build the group selector
            if ($(rightOption).parent().prop('tagName') == 'OPTGROUP') {
                var optgroupSelector = 'optgroup[label="' + $(rightOption).parent().attr('label') + '"]';
                $(left).find(optgroupSelector + ' option[value="' + rightOption.value + '"]').each(function(index, leftOption) {
                    // remove right option from left column
                    leftOption.remove();
                });
                // if group is empty then remove from left column
                $(left).find(optgroupSelector).removeIfEmpty();
            } else {
                // look for moved option in the left column and remove it
                var $option = $(left).find('option[value="' + rightOption.value + '"]');
                $option.remove();
            }
        });
    }

    /**
     * Function that clear all form's fields
     * No args needed
     */
    function clearAll() {

        // clear input field
        $('input.clear-field').val('');
        // reset bootstrap toggle
        $('#subgroup-public').prop('checked', false).trigger('change');

        // take care of select2
        $("#subgroup-groups").val([]).trigger('change');

        $('#provinces').val(-1);
        $("#networks").val([]).trigger('change');

        // move all selected stations in the left column
        $( '#multiselect_leftAll' ).trigger("click");

        // disable save button
        $("#subgroup-add").prop("disabled",true);

        // reset text
        $('#settings-form h2').text('Aggiungi sottogruppo stazioni');
        $('#settings-form h3').text('Crea un nuovo sottogruppo');
    }

    /**
     * Function that builds the json tree submenu
     *
     * @param {object} node: clicked node element
     *
     * @return {object} menu
     */
    function customMenu(node){

        // if it's a leaf node don't open any menus
        if ( node.parents.length != 1 ) {
            return false;
        }

        var items = {
            // edit button
            editItem: {
                label: "Modifica sottogruppo",
                "_disabled": ! update_grant,
                action: function (){

                    // set form text
                    $('#settings-form h2').text('Modifica sottogruppo stazioni');
                    $('#settings-form h3').text('Aggiorna sottogruppo selezionato: '+$(node)[0].text);

                    // get dirty flag
                    var empty = $('#subgroup-fill').val();
                    // get group id stored inside the node element
                    var subgroup = $(node)[0].li_attr.id;
                    // if the structure has already been initialized, ask for confirmation
                    if (empty != ''){
                        swal({
                            title: "Attenzione, sottogruppo già generato",
                            text: "Sei proprio sicuro di voler proseguire con la modifica di un altro sottogruppo? in caso affermativo tutto quanto compilato finora verrà eliminato.",
                            type: "warning",
                            showCancelButton: true,
                            confirmButtonText: "Si, rigenera",
                            closeOnConfirm: true,
                            cancelButtonText: "Annulla"
                        }, function () {

                            // clear form
                            clearAll();
                            // retrieve data from db and fill form
                            editSubgroup(subgroup);
                        });
                    }
                    else{
                        // retrieve data from db and fill form
                        editSubgroup(subgroup);
                    }
                }
            },
            deleteItem: {
                // delete button
                label: "Elimina sottogruppo",
                "_disabled": ! delete_grant,
                action: function (){

                    // get group id stored inside the node element
                    var subgroup = $(node)[0].li_attr.id;
                    // ask for confirmation
                    swal({
                        title: "Attenzione!",
                        text: "Sei proprio sicuro di voler proseguire con l'eliminazione del sottogruppo?",
                        type: "warning",
                        showCancelButton: true,
                        confirmButtonText: "Si, elimina",
                        closeOnConfirm: true,
                        cancelButtonText: "Annulla"
                    }, function (isConfirm) {
                        // get dirty flag
                        var empty = $('#subgroup-fill').val();

                        // if user confirm
                        if(isConfirm){
                            // delete group
                            deleteSubgroup(subgroup);

                            // if the same subgroup displayed in the form has been deleted then clean form itself
                            if (empty != '' && subgroup == parseInt($('#subgroup-id').val())){
                                clearAll();
                            }
                        }
                        return;
                    });
                }
            }
        };

        // return menu object
        return items;
    };

    /**
     * Function that initialize json tree
     * No args needed
     */
    function initializeLeftTree(){

        $('#group-json').jstree({
            'core' : {
                // 'check_callback': true,
                'data' : {
                    url: function (node) {

                        var url = "";
                        console.log('NODE.id: '+ node.id);

                        // in order to retrieve recursively data from db
                        // create a different url based on node's level
                        if (node.id === '#')
                        {
                            url = "/str_ava_ana_get_analyser_groups";
                        }
                        else
                        {
                            switch (node.li_attr.type) {
                                case 'group':
                                    url = "/str_ava_ana_get_group_stations";
                                    break;
                                default:
                                    break;
                            }
                        }

                        console.log(url);
                        return url;
                    },
                    // 'type': "get",
                    'contentType': "application/json",
                    'dataType': 'JSON',
                    // in order to retrieve recursively data from db
                    // create a different object data to be sent to server based on node's level
                    data: function (node) {

                        if( node.id === "#"){
                            return;
                        }
                        else{
                            return {"nodeid": node.id, "id": node.li_attr.id};
                        }
                    }
                }
            },
            'plugins' : ["search", "contextmenu"],
            'search' : {
                // ajax
                show_only_matches: true,
                show_only_matches_children: true
            },
            'contextmenu': {items: customMenu}
        });

        // SEARCH PLUGIN FOR JSTREE
        var to = false;
        // keyup event on json tree search box
        $('#input-search').keyup(function () {
            // search nodes
            if(to) { clearTimeout(to); }
            to = setTimeout(function () {
                var v = $('#input-search').val();
                $('#group-json').jstree(true).search(v);
            }, 250);
        });

        // end search event
        $('#group-json').on("search.jstree", function(e, data){
            // returns filtered nodes
            filtered_obj = data.nodes;
        });
    };

    /**
     * Function that retrieves the stations of given networks and province.
     * No args needed
     */
    function loadStationsByNetworks(){
        // get selected elements
        var nets = $("#networks").val();
        var prid = $("#provinces").val();

        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_ana_get_stations_bynets',
            type: "post",
            dataType: "json",
            data: {
                prid: prid,
                nets: JSON.stringify(nets)
            },
        })
        .done(function(result) {

            console.dir(result);

            // check if result is 'OK'
            if(result.res == 'OK'){
                var stations = result.stations;

                // variable for dinamically building the html
                var opts = '';
                var net;
                var lastNet;

                // loop through all elements
                // for each station, build a html option to be added to the multiselect
                $.each(stations, function(index, station){
                    // check if the current looped station is associated to a different network then the previous one
                    //  - if true then set a new optgroup for the new network
                    if(lastNet != station.station_network_type_desc){

                        // close previous group
                        if(index != 0)
                            opts += '</optgroup>';

                        // open new group
                        opts += '<optgroup label="'+station.station_network_type_desc+'">';
                        lastNet = station.station_network_type_desc;
                    }
                    opts += '<option value="'+ station.station_id+'">'+station.station_name+'</option>';

                    // if it is last loop then close group
                    if(index == stations.length -1)
                        opts += '</optgroup>';
                });

                // clear multiselect
                $('#multiselect').empty();
                // append options and refresh plugin
                $('#multiselect').append(opts);
                $('#multiselect').multiselect();
                // clean multiselect
                cleanMultiselect('#multiselect', '#subgroup-stat');
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
    };

    /**
     * Function that retrieves the selected group and fill form's fields
     *
     * @param {integer} subgroup_id: Group ID
     */
    function editSubgroup(subgroup_id){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_ana_get_subgroup_by_id',
            type: "post",
            dataType: "json",
            data: {
                id: subgroup_id
            },
        })
        .done(function(result) {

            console.dir(result);
            // chekc result
            // if OK then fill form's fields
            // else show an error message
            if(result.res == 'OK'){
                var subgroup = result.subgroup;

                // set dirty flag
                $('#subgroup-fill').val(1);
                // fill fields with retrieved data
                $('#subgroup-id').val(subgroup.tree_id);
                $('#subgroup-name').val(subgroup.tree_name);

                $('#subgroup-public').prop('checked', subgroup.tree_public).trigger('change');

                // take care of select2
                $("#subgroup-groups").val(subgroup.groups_id).trigger('change');

                // select stations and move them to the right column
                $('#multiselect').val(subgroup.stations_id);
                $('#multiselect_rightSelected').trigger('click');

            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero del sottogruppo", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante il recupero del sottogruppo", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };

    /**
     * Function that deletes the selected group
     *
     * @param {integer} subgroup_id: Group ID
     */
    function deleteSubgroup(subgroup_id){

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();
        // ajax call
        var jqxhr = $.ajax({
            url: '/str_ava_ana_del_subgroup',
            type: "post",
            dataType: "json",
            data: {
                id: subgroup_id
            },
        })
        .done(function(result) {

            // check result
            if(result){
                // refresh json tree
                $('#group-json').jstree(true).refresh(true);
                // success message
                swal("Successo!", "Il sottogruppo è stato eliminato con successo", "success");
            }
            else{
                // error message
                swal("Errore!", "Errore durante l'eliminazione del sottogruppo", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'eliminazione del sottogruppo", "error");
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        });
    };
});


