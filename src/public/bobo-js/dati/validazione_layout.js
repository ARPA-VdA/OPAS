// LAYOUT VARIABLES
var myLayout;
var centralContainer;
// multiview tab counter
var counter = 0;

var resizeTimer;
/**
 * Document resize event: calculate new dimensions for the main container and resize the layout
 */
$(window).on('resize', function(e) {

    // reset timeout
    clearTimeout(resizeTimer);
    // create new timeout variable
    resizeTimer = setTimeout(function() {
        var el = $('.layoutContainer');
        // calculate new dimensions
        var elTop = el.offset().top+10;
        var cntHeight = $(window).height()-elTop;
        var cntWidth = $(window).width();
        // set the height and the width of the main container
        // update size of layout plugin
        $(".layoutContainer").height(cntHeight);
        $(".layoutContainer").width(cntWidth);
        myLayout.updateSize(cntWidth, cntHeight);
    }, 250);
});

/**
 * Disable default right-click event
 */
$(document).on('contextmenu', function(e){
    return false;
});

/**
 * Document ready.
 */
$(document).ready(function() {

    // if the application is in production mode then disable console functions
    if (app_mode == 'production'){
        console.log = function(){};
        console.dir = function(){};
    }

    // create object with the graphical structure of the application
    var config = {
        settings:{
            // selectionEnabled: true,
            showPopoutIcon: false,
            showMaximiseIcon: false,
            showCloseIcon: false,
            reorderEnabled: false
        },
        content: [{
            type: 'row',
            content:[
                {
                    type: 'column',
                    width: 20,
                    content:[
                        {
                            type: 'component',
                            componentName: 'stationMenu',
                            id: 'stationMenu',
                            title: 'Lista stazioni & dati sospetti',
                            isClosable: false
                        },
                        {
                            type: 'stack',
                            componentName: 'infoContainer',
                            id: 'infoContainer',
                            content:[
                                {
                                    type: 'component',
                                    componentName: 'dataDetail',
                                    title:'Codici validità',
                                    isClosable: false
                                },
                                {
                                    type: 'component',
                                    componentName: 'changesDetail',
                                    title:'Storico modifiche',
                                    isClosable: false
                                }
                            ]
                        },
                    ]
                },
                {
                    type: 'column',
                    width: 60,
                    content:[
                        {
                            type: 'stack',
                            componentName: 'centralContainer',
                            id: 'centralContainer',
                            content:[
                                {
                                    type: 'component',
                                    componentName: 'tableComponent',
                                    componentState: {
                                        id: 0,
                                        stid: null,
                                        prid: null,
                                        grid: null,
                                        fulltable: null,
                                        type: 'table',
                                        conv: null
                                    },
                                    title:'TABELLA',
                                    isClosable: false
                                },
                                {
                                    type: 'component',
                                    componentName: 'multiViewComponent',
                                    componentState: {
                                        id: 1,
                                        type: 'multiview',
                                    },
                                    title:'Dettaglio',
                                    isClosable: true
                                },

                            ]
                        }
                    ]
                },
                {
                    type: 'column',
                    // width: 20,
                    content:[
                        {
                            type: 'component',
                            componentName: 'validityCodes',
                            title: 'Codici validità',
                            isClosable: false
                        },
                        {
                            type: 'component',
                            componentName: 'operationsForm',
                            title:'Operazioni',
                            isClosable: false,
                            height: 20
                        }
                    ]
                }
            ]
        }]
    };

    // update layout's height
    var h = window.innerHeight;
    var el = $('.layoutContainer');
    var elTop = el.offset().top+10;
    $('.layoutContainer').height(h-elTop);
    // initialize GoldenLayout plugin
    myLayout = new GoldenLayout( config, $('.layoutContainer') );

    // LEFT COLUMN
    // register component
    myLayout.registerComponent( 'stationMenu', function( container ){
        // add html elements
        var html = '<h5 class="m-t-20">Reti</h5>';
        html += '<div class="clearfix" id="network-search">';
        html += '    <input type="text" id="input-search" value="">';
        html += '</div>';
        html += '<div id="station-json"></div>';

        container.getElement().html( html );

        container.getElement().addClass( 'station_menu' );
        container.getElement().css( 'overflow', 'auto' );
    });

    // CENTRAL COLUMN
    // register components
    myLayout.registerComponent( 'infoContainer', function( container ){
    });

    myLayout.registerComponent( 'dataDetail', function( container ){
        // add html elements
        container.getElement().append( '<h5 class="m-t-20">Dettaglio dei codici</h5><div id="codes-detail"></div>');
        container.getElement().css( 'overflow', 'auto' );
    });

    myLayout.registerComponent( 'changesDetail', function( container ){
        // add html elements
        container.getElement().append( '<h5 class="m-t-20">Dettaglio delle modifiche</h5><div id="changes-detail"></div>');
        container.getElement().css( 'overflow', 'auto' );
    });

    // COLONNA CENTRALE
    myLayout.registerComponent( 'centralContainer', function( container ){
    });


    myLayout.registerComponent( 'tableComponent', function( container, state ){
        var html= '';
        // main container
        html += '<div id="maintable-container" class="grid" style="height: 100%;"></div>';
        console.log(html);

        container.getElement().append( html);
    });

    myLayout.registerComponent( 'multiViewComponent', function( container, state ){
        // add divs for the multiview tab (1 chart and 1 table)
        var html= '';
        html += '<div id="multiview_chart_'+state.id+'" class="chart"></div>';
        html += '<div id="multiview_grid_'+state.id+'" class="grid"></div>';

        container.getElement().append( html);
    });

    // RIGHT COLUMN
    // register component
    myLayout.registerComponent( 'validityCodes', function( container ){
        // add html div in order to append the list of validity codes
        container.getElement().html( '<h5 class="m-t-20">Codici</h5><div id="codes-list"></div>');
        container.getElement().css( 'overflow', 'auto' );
    });

    myLayout.registerComponent( 'operationsForm', function( container ){

        // add operations form element
        var html = '';
        html += '<h5 class="m-t-20">Operazioni</h5>';
        html += '<div id="operations-form">';
        html += ' <div class="operations">';
        html += '   <span class="valid-operators-offset">';
        html += '       <button type="button" class="btn">+</button>';
        html += '       <button type="button" class="btn">-</button>';
        html += '   </span>';
        html += '   <span class="valid-operators">';
        html += '       <button type="button" class="btn">*</button>';
        html += '       <button type="button" class="btn">/</button>';
        html += '       <button type="button" class="btn">=</button>';
        html += '   </span>';
        html += ' </div>';
        html += ' <input type="number" class="form-control" id="valid-value" placeholder="valore">';
        html += '</div>';
        html += '<div id="operations-buttons">';
        html += '   <button id="update-value-cells" type="button" class="btn btn-primary" data-toggle="tooltip" data-placement="top" title="Aggiorna valori delle celle selezionate">';
        html += '       Esegui';
        html += '   </button>';
        html += '   <button id="reset-operations" type="button" class="btn btn-danger" data-toggle="tooltip" data-placement="top" title="Reset form">';
        html += '       Annulla';
        html += '   </button>';
        html += '</div>';


        container.getElement().html( html );
        container.getElement().css( 'overflow', 'auto' );
    });

    /**
     * componentCreated event, fired every time a new component is created
     */
    myLayout.on('componentCreated', function(component) {

        var stackParent = component.parent;
        var stackIdx = stackParent.config.id;
    });

    /**
     * initialised event, fired only once when layout initialization is finished
     */
    myLayout.on('initialised', function(){
        console.log("Layout caricato");
        // store the central container in a global variable
        centralContainer = myLayout.root.getItemsById('centralContainer')[0];
        // remove multiview tab and start only with main central tab
        centralContainer.removeChild(centralContainer.contentItems[1]);

        centralContainer.element.addClass( 'middle-column' );
        // at the end of the process hide preloader
        $('.preloader').hide();
        // function in validazione_setting.js
        initialiseElements();
    });


    // layout initialization
    myLayout.init();
    // set background color to white
    $(".lm_content").css("background-color", "white");
});

/**
 * Function that adds a new multiview tab to layout and shows the neighborhood of a point (+- 24H)
 *
 * @param {integer} stprid Station-parameter ID.
 * @param {timestamp} date Clicked value's date.
 */
function addMultiView(stprid, date){

    // show preloader, waiting for the end of the process
    $('.preloader').show();
    // ajax call
    var jqxhr = $.ajax({
        url: '/dat_val_get_point_neighborhood',
        type: "post",
        dataType: "json",
        data: {
            date: date,
            stprid: stprid,
            converted: validationOptions.general.convEnabled
        },
    })
    .done(function(result) {

        var stationData = JSON.parse(result.chart_data.station_data);
        // check result
        // if ok and array of values is not empty then initialize a table and a chart
        if(result.res == 'OK' && stationData.meanvalue.length > 0){
            // increase tab's global counter
            counter++;
            console.dir(result);

            // format input date
            var formattedDate = moment(date).format('DD.MM.YY HH.mm');
            // create goldenLayou tab object and add it to central container
            var newItemConfig = {
                type: 'component',
                componentName: 'multiViewComponent',
                componentState: {
                    id: counter,
                    type: 'multiview',
                    stprid: stprid,
                    date: date,
                    conv: validationOptions.general.convEnabled
                },
                title:result.metadata.parameter_name+' ['+formattedDate+']',
                isClosable: true
            };

            centralContainer.addChild(newItemConfig);
            // set background color to white
            $(".lm_content").css("background-color", "white");

            // initialize table and chart plugin (validazione.js)
            createDetailedChart(date, result.chart_data);
            createDetailedTable(date, result);
        }
        else{
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
            // at the end of the process hide preloader
            $('.preloader').hide();
        }
    })
    .fail(function(xhr, err) {
        // error message
        swal("Errore!", "Errore durante il recupero dei dati", "error");
        // at the end of the process hide preloader
        $('.preloader').hide();
    });
}