// GLOBAL VARIABLES
var gridWidgets;
var widgets;
var formActive;

/**
 * Document ready
 */
$(document).ready(function() {

    gridWidgets =  new Array($('.onerow').length).fill(new Array());
///////////////////////////// HOMEPAGE - ORDINAMENTO WIDGETS /////////////////////////////
{

    // example drag & drop: https://www.w3schools.com/jsref/tryit.asp?filename=tryjsref_ondrag_all
    // When the draggable element enters into droppable, change the border style
    document.addEventListener("dragenter", function(event) {
        if ( event.target.className == "onecol enabled" ) {
            // console.log("sto passando sopra");
            event.target.style.border = "1px solid #dc5a08";
        }
    });

    // When the draggable element leaves the droppable, reset the border style
    document.addEventListener("dragleave", function(event) {
        if ( event.target.className == "onecol enabled" ) {
            event.target.style.border = "1px solid #dedede";
        }
    });

    // when finished dragging the element reset the border style
    document.addEventListener("dragend", function(event) {
        $(".onecol.enabled").css({"border": "1px solid #dedede"});
    });

    /**
     * Click event on X inside widget matrix
     */
    $( "#hp-tab" ).on( "click", ".onecol .tooltip-item i.mdi-close-circle", function() {
        // get html elements
        var element = $(this).parent();
        var elMain = $(this).parent().parent();
        // get widget id stored inside the html element
        var id = $(this).parent().attr('id');
        // container id as row-col
        var idMain = elMain.attr('id');

        // parse id to obtain row and column index
        var indexes = idMain.split('-');
        var row = parseInt(indexes[0].replace("row", "")) - 1;
        var col = parseInt(indexes[1].replace("col", "")) - 1;

        // remove widget and reset container's attributes
        element.remove();
        elMain.attr('ondrop','drop(event)');
        elMain.attr('ondragover','allowDrop(event)');

        // empty global variable
        gridWidgets[row][col] = null;
        // check if the row is empty and re-initialize it
        if(!gridWidgets[row].some(x => x !== null))
            gridWidgets[row] = new Array();

        // rebuild widgets list on left column
        rebuildWidgetList(id);
    });


    /**
     * Click event on "Salva" button
     */
    $( ".save-changes" ).on( "click", "#salva_wgt", function() {
        // store in the global variable option the last sequence of homepage widgets
        // options['gridWidgets'] = gridWidgets;

        // Create a new matrix without empty spaces
        var finalGrid = gridWidgets.filter(x => x.length != 0);

        finalGrid.forEach(function(row, idx){
            finalGrid[idx] = row.filter(x => x !== null);
        });

        // save new configuration with an ajax call
        var jqxhr = $.ajax({
            url: '/usr_options_put_widgets',
            type: "post",
            dataType: "json",
            data: {
                widgets: JSON.stringify(finalGrid)
            }
        })
        .done(function(result) {
            // check result
            if(result)
                swal("Successo", "Modifiche apportate con successo alla tua homepage", "success");
            else
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore", "Questa operazione non è andata a buon fine", "error");
        });
    });

    /**
     * Click event on "Annulla" button
     */
    $( ".save-changes" ).on( "click", "#annulla_wgt", function() {
        console.log("annulla modifiche!");
        // reload page
        location.reload();
    });

    // show preloader, waiting for the end of the process
    $(".inner-preloader").show();
    getWidgetList();
}

///////////////////////////// SHORTCUT ICONS /////////////////////////////
{
    // Switchery - checkbox ON/OFF
    formActive = new Switchery($("#form-active")[0], $("#form-active").data());

    // initialize select 2
    $( "#icons-1, #icons-2, #icons-3, #icons-4" ).select2();

    // CHANGE EVENTS
    /////////////////////////////////////////////////////////////////////////

    /**
     * Change event: change name and icon when selecting the desired page to shortcut.
     */
    $( "#icons-1, #icons-2, #icons-3, #icons-4" ).on('change', function(){

        // get container selector
        var iconDest = $(this).data('dest');
        // get text and icon of selected option
        var icon = $(this).find('option:selected').data('icon');
        var name = $(this).find('option:selected').text();

        // fill linked container with selected text and icon
        $('.'+iconDest).attr('data-original-title', name);
        $('.'+iconDest+' i').attr('class', icon);

    });

    /**
     * Change event: activation of shortcuts menu.
     */
    $('#short-links-tab').on('change', '#form-active', function(e){
        // get new status
        var check = $("#form-active").is(":checked");

        // if active, show shortcut links form
        if(check == true){
            // update tab contents (elements visibility, text and opacity)
            $('#form-shortcut-icons').show("slow");
            $('#form-active-label').html("Questo menu non mi interessa, disattivalo!");
            $('#form-active-label').addClass("text-danger");
            $('#form-active-label').removeClass("text-success");
            $('#short-icons').show("slow");
            jQuery('#change-short-icons').css('opacity', '1');
        }
        else{
            // update tab contents (elements visibility, text and opacity)
            $('#form-active-label').html("Attiva il menu di icone rapide &raquo;");
            $('#form-active-label').addClass("text-success");
            $('#form-active-label').removeClass("text-danger");

            // put empty array to database
            var shortcuts = [];
            // ajax call
            var jqxhr = $.ajax({
                url: '/usr_options_put_shortcuts',
                type: "post",
                dataType: "json",
                data: {
                    shortcuts: JSON.stringify(shortcuts)
                }
            })
            .done(function(result) {
                // check result
                // if TRUE then hide containers and reduce opacity
                if(result){
                    $('#form-shortcut-icons').hide("slow");
                    jQuery('#change-short-icons').css('opacity', '0.4');
                    $('#short-icons').hide("slow");
                }
                else
                // error message
                    swal("Errore", "Questa operazione non è andata a buon fine", "error");
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
            });
        }
    });

    // validate form
    var validator = $('#form-shortcut-icons').validate({ // initialize the plugin
        rules: {
            "icons-one":{
                required: true,
                min: 0
            },
            "icons-two":{
                required: true,
                min: 0
            },
            "icons-three":{
                required: true,
                min: 0
            },
            "icons-four":{
                required: true,
                min: 0
            },
        },
        messages: {
            "icons-one":{
                required: "Selezionare pagina",
                min: "Selezionare pagina"
            },
            "icons-two":{
                required: "Selezionare pagina",
                min: "Selezionare pagina"
            },
            "icons-three":{
                required: "Selezionare pagina",
                min: "Selezionare pagina"
            },
            "icons-four":{
                required: "Selezionare pagina",
                min: "Selezionare pagina"
            },
        },
        ignore: ":hidden:not(.summernote), .note-editable",
        errorPlacement: function ( error, element ) {
            if(element.parent().hasClass('input-group')){
              error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    /**
     * Submit event: save the chosen shortcuts.
     */
    $('#form-shortcut-icons').on('submit', function (e) {
        e.preventDefault();

        // check if form is valid
        if(! $(this ).valid()){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare report", "info");
            return false;
        };

        // create an empty array and store selected pages
        var shortcuts = [];
        shortcuts.push(parseInt($('#icons-1').val()));
        shortcuts.push(parseInt($('#icons-2').val()));
        shortcuts.push(parseInt($('#icons-3').val()));
        shortcuts.push(parseInt($('#icons-4').val()));

        // put array via an ajax call
        var jqxhr = $.ajax({
            url: '/usr_options_put_shortcuts',
            type: "post",
            dataType: "json",
            data: {
                shortcuts: JSON.stringify(shortcuts)
            }
        })
        .done(function(result) {
            // check result
            // if TRUE show a confirm message in order to reload page and build the portal's menu with new shorcuts
            if(result){
                swal({
                    html: true,
                    title: "Successo",
                    text: "Salvataggio avvenuto con successo!<br>Per vedere le modifiche <strong>è necessario ricaricare la pagina</strong>",
                    type: "success",
                    confirmButtonText: "Ricarica",
                    closeOnConfirm: true,
                    showCancelButton: true,
                    cancelButtonText: "Annulla"
                },
                function(isConfirm){
                    if(isConfirm)
                        location.reload();
                });
            }
            else
                // error message
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore", "Questa operazione non è andata a buon fine", "error");
        });

    });

    /**
     * Reset all shortcuts ('Annulla' button).
     */
    $('#cancel-icons').on('click', function(e) {
        e.preventDefault();

        // clear all selects and trigger change
        $('#form-shortcut-icons .clear-select').val(-1);
        $('#form-shortcut-icons .clear-select').trigger('change');
    });
}
});

// GLOBAL FUNCTIONS
    // UTILITIES
    //////////////////////////////////////////////////////////
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

// MAIN
//////////////////////////////////////////////////////////

/**
 * Function that retrieves user settings
 * No args needed
 */
function getUserOptions() {

    // ajax call
    var jqxhr = $.ajax({
        url: '/usr_options_get_options',
        type: "post",
        dataType: "json"
    })
    .done(function(result) {
        // check result
        // if user's options are not empty then fill right matrix
        // else do nothing
        if(result.options != null){

            // parse object
            options = JSON.parse(result.options.option_object);

            // variable for dynamically build the html
            var html = '';

            var userWidgets = options.widgets;
            // check if there is at least one saved widget
            if(userWidgets != null && userWidgets.length > 0 && userWidgets[0].length > 0){
                var n, m;
                // loop through rows and columns in order to fill matrix
                for(n= 0; n < userWidgets.length; n++){

                    gridWidgets[n] = new Array();

                    for(m= 0; m < userWidgets[n].length; m++){

                        // dynamically build div id
                        var elementId = "row"+(n+1)+"-col"+(m+1);
                        var element = document.getElementById(elementId);
                        // check if the user has placed a widget in this position
                        if( document.getElementById(userWidgets[n][m]) != null ){
                            // append widget item inside the div
                            element.appendChild(document.getElementById(userWidgets[n][m]));
                            // add delete X button
                            $("#"+userWidgets[n][m]+" i").toggleClass( "ti-layout-list-thumb-alt mdi mdi-close-circle" );
                            // remove draggable properties from div
                            $("#"+userWidgets[n][m]).attr('draggable', false);
                            $("#"+userWidgets[n][m]).removeAttr( "ondragstart" );

                            // save widget inside the global variable
                            gridWidgets[n][m] = userWidgets[n][m];
                        }
                    }
                }
            }

            var userShorcuts = options.shortcuts;
            // check if there is at least one saved shortcut
            if(userShorcuts != null && userShorcuts.length > 0){
                // loop through user's shortcuts and fill spaces by triggering a change event
                userShorcuts.forEach(function(el, idx){
                    $('#icons-'+(idx+1)).val(el).trigger('change');
                });
            }
            else{
                // disable shortcuts
                setSwitchery(formActive, false);
            }
        }

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero delle opzioni dell'utente", "error");
        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    });
}

// WIDGETS
//////////////////////////////////////////////////////////
/**
 * Function that retrieves the widgets list.
 * No args needed
 */
function getWidgetList() {
    // clean the list
    $( "#widget-list" ).empty();

    // ajax call
    var jqxhr = $.ajax({
        url: '/usr_options_get_widget_list',
        type: "post",
        dataType: "json"
    })
    .done(function(result) {
        console.dir(result);

        // check result
        // if 'OK' then fill the widgets list
        // else error
        if(result.res == 'OK'){

            widgets = result.widgets;

            // variable for dynamically build the html
            var html = '';

            // loop through all widgets
            // for each element build a <li> and append it in the left column
            $.each(widgets, function(index, widget) {
                //console.log(widget);
                html += '<li class="mytooltip tooltip-effect-5 tooltip-draggable">';
                html += '    <span id="'+widget.wdg_id+'" class="tooltip-item" draggable="true" ondragstart="drag(event)">';
                html += '        <i class="ti-layout-list-thumb-alt"></i> <b>'+widget.wdg_name+'</b>';
                html += '    </span>';
                html += '    <span class="tooltip-content clearfix">';
                html += '        <img src="'+widget.wdg_image_url+'" />';
                html += '        <span class="tooltip-text">'+widget.wdg_description+'</span>';
                html += '    </span>';
                html += '</li>';

            });

            // append new content to document body
            $( "#widget-list" ).append(html);

            // at the end of the procedure retrieve the user settings
            getUserOptions();
        }
        else{
            // error message
            swal("Errore!", "Errore durante il recupero dei widget", "error");
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei widget", "error");
    });
}

/**
 * Function that checks if a given position inside the matrix is already filled
 *
 * @param {integer} n Row number.
 * @param {integer} m Column number.
 * @return If exists, the widget; otherwise NULL value
 */
function widgetExists(n, m){
    return (gridWidgets[n] != null && gridWidgets[n][m] != null);
};

/**
 * Function that rebuilds the widget table.
 *
 * @param {integer} id Widget ID.
 */
function rebuildWidgetList(id){

    // loop through all available widgets
    // for each item check if id is the same passed as argument
    // if true then create an item to be added to list on the left column
    $.each(widgets, function(index, widget) {

        if (widget.wdg_id == id){
            console.log("trovato! : "+widget.wdg_id);

            // variable for dynamically build the html
            var html = '';

            html += '<li class="mytooltip tooltip-effect-5 tooltip-draggable">';
            html += '    <span id="'+widget.wdg_id+'" class="tooltip-item" draggable="true" ondragstart="drag(event)">';
            html += '        <i class="ti-layout-list-thumb-alt"></i> <b>'+widget.wdg_name+'</b>';
            html += '    </span>';
            html += '    <span class="tooltip-content clearfix">';
            html += '        <img src="'+widget.wdg_image_url+'" />';
            html += '        <span class="tooltip-text">'+widget.wdg_description+'</span>';
            html += '    </span>';
            html += '</li>';

            // append new content to document body
            $( "#widget-list" ).append(html);
        };
    });
}

/**
 * Function that allows dropping the widget with the mouse.
 *
 * @param {event} ev Event.
 */
function allowDrop(ev) {
    ev.preventDefault();
}

/**
 * Function for dragging widgets.
 *
 * @param {event} ev Event.
 */
function drag(ev) {
    ev.dataTransfer.setData("text", ev.target.id);
}

/**
 * Function for dropping widgets.
 *
 * @param {event} ev Event.
 */
function drop(ev) {
    ev.preventDefault();

    // get dragged element and check if it's a widget item
    var dragged = parseInt(ev.dataTransfer.getData("text"));
    if(! document.getElementById(dragged) || ! document.getElementById(dragged).classList.contains('tooltip-item'))
        return false;

    var target;

    // get the closest div where widget has been dropped
    if( ! $( event.target ).is('div'))
        target = $( event.target ).closest('div');
    else
        target = $( event.target );

    // get div id
    var dropped = target.attr('id');
    // parse id to obtain row and column indexes
    var indexes = dropped.split('-');
    var row = parseInt(indexes[0].replace("row", "")) - 1;
    var col = parseInt(indexes[1].replace("col", "")) - 1;

    console.log(row+" - "+col);

    // if the row is empty then initialize a new array
    if(gridWidgets[row].length == 0){
        gridWidgets[row] = new Array();
    }

    // check if there is another widget in the same position
    if( widgetExists(row,col) ){
        // get widget item and id
        var widget = target.find('span.tooltip-item');
        var id = parseInt(widget.attr('id'));
        // remove item
        widget.remove();
        // refresh widget list in the left column
        rebuildWidgetList(id);
    }
    else{
        // empty slot
    }

    // store dragged widget inside the global variable
    gridWidgets[row][col] = dragged;

    // add item inside div and add X button
    target.get( 0 ).appendChild(document.getElementById(dragged));
    $("#"+dragged+" i").toggleClass( "ti-layout-list-thumb-alt mdi mdi-close-circle" );
    // disable draggable property for the div
    $("#"+dragged).attr('draggable', false);
}