// LAYOUT VARIABLES
var myLayout;
var centralContainer;
// goldenlayout tabs counter
var counter = 1;

/**
 * Window resize event
 */
$(window).on('resize', function(e) {
    var resizeTimer;

    // reset timeout
    clearTimeout(resizeTimer);
    // set timeout in order to update layout size after 10ms of a resize event
    resizeTimer = setTimeout(function() {
        var el = $('.layoutContainer');
        // calculate top element height
        var elTop = el.offset().top+10;
        // get window dimensions taking care of top element height
        var cntHeight = $(window).height()-elTop;
        var cntWidth = $(window).width();
        // resize html element
        $(".layoutContainer").height(cntHeight);
        $(".layoutContainer").width(cntWidth);
        // update golden layout plugin
        myLayout.updateSize(cntWidth, cntHeight);
    }, 10);
});

/**
 * Document ready
 */
$(document).ready(function() {

    console.log('App mode: ' + app_mode);
    // in production disable console's messages
    if (app_mode == 'production'){
        // var console = {};
        console.log = function(){};
        console.dir = function(){};
    }

    // build json object with goldenlayout options
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
                            componentName: 'macroMenu',
                            title: 'Lista delle macro',
                            isClosable: false
                        },
                        {
                            type: 'component',
                            componentName: 'activeOptionsContainer',
                            title:'Informazioni',
                            height: 30,
                            isClosable: false
                        }
                    ]
                },
                {
                    type: 'column',
                    width: 60,
                    isClosable: false,
                    content:[
                        {
                            type: 'stack',
                            componentName: 'centralContainer',
                            id: 'centralContainer',
                            isClosable: false,
                            content:[
                                {
                                    type: 'component',
                                    componentName: 'chartComponent',
                                    componentState: {
                                        id: 0,
                                        type: 'chart',
                                        multiple: false,
                                        perYear: false,
                                        windrose: false,
                                        windroseId: null,
                                        macroId: null,
                                        notes: null,
                                        elementMacro: {
                                            macro : {
                                                name: 'Nuova macro',
                                                description: 'Macro di partenza',
                                                int_time: 0,
                                                legendx_angle: 0,
                                                label_yaxis: null,
                                                num_yaxis: 1,
                                                aggregation: $("#time-period option.def").val(),
                                                percent_data: $("#percent-data").val(),
                                                validity_code: '<= 4'
                                            },
                                            params: []
                                        }
                                    },
                                    title:'Grafico',
                                    isClosable: false
                                },
                                {
                                    type: 'component',
                                    componentName: 'tableComponent',
                                    componentState: {
                                        id: 1,
                                        type: 'table',
                                        macroId: null,
                                        elementMacro: {
                                            macro : {
                                                name: 'Nuova macro',
                                                description: 'Macro di partenza',
                                                int_time: 0,
                                                legendx_angle: 0,
                                                label_yaxis: null,
                                                num_yaxis: 1,
                                                aggregation: $("#time-period option.def").val(),
                                                percent_data: $("#percent-data").val(),
                                                validity_code: '<= 4'
                                            },
                                            params: []
                                        }
                                    },
                                    title:'Tabella',
                                    isClosable: false
                                }
                            ]
                        },
                        {
                            type: 'stack',
                            componentName: 'moreInfoContainer',
                            id: 'moreInfoContainer',
                            isClosable: false,
                            height: 20,
                            content:[
                                {
                                    type: 'component',
                                    componentName: 'logContainer',
                                    id: 'logContainer',
                                    title:'Log',
                                    isClosable: true
                                },
                                {
                                    type: 'component',
                                    componentName: 'notesContainer',
                                    id: 'notesContainer',
                                    title:'Note',
                                    isClosable: true
                                }
                            ]
                        }
                    ]
                },
                {
                    type: 'column',
                    width: 20,
                    content:[
                        {
                            type: 'component',
                            componentName: 'stationMenu',
                            id: 'stationMenu',
                            title: 'Lista delle stazioni',
                            isClosable: false
                        },
                        {
                            type: 'component',
                            componentName: 'activeMacroContainer',
                            title:'Macro attiva',
                            isClosable: false
                        },
                    ]
                }
            ]
        }]
    };

    var h = window.innerHeight;
    // calculate top element height
    var el = $('.layoutContainer');
    var elTop = el.offset().top+10;
    // resize html element taking care of top element height
    $('.layoutContainer').height(h-elTop);

    // initialize goldenlayout plugin
    myLayout = new GoldenLayout( config, $('.layoutContainer') );

    // EVENTS
    //////////////////////////////////////////

    // LEFT COLUMN
    // initialization of div at the top left of the window
    myLayout.registerComponent( 'macroMenu', function( container ){
        // add specific html and classes
        container.getElement().html( '<h5 class="m-t-20">Macro</h5><div id="macro-json"></div>');
        container.getElement().addClass( 'macro_menu' );
        container.getElement().css( 'overflow', 'auto' );
    });

    // initialization of div at the bottom left of the window
    myLayout.registerComponent( 'activeOptionsContainer', function( container ){
        // add specific html and classes
        var html = '<h5 class="subtitle-cat">Impostazioni attive</h5>';
        html += '<table class="table table-striped tbl-analyser">';
        html += '    <tbody>';
        html += '    </tbody>';
        html += '</table>';
        container.getElement().append( html );
        // container.getElement().addClass( 'macro_menu' );
        container.getElement().css( 'overflow', 'auto' );
    });

    // CENTRAL COLUMN
    // initialization of main central container
    myLayout.registerComponent( 'centralContainer', function( container ){
    });

    // initialization of first "chart" tab inside the central container
    myLayout.registerComponent( 'chartComponent', function( container, state ){
        // add specific html
        var html= '';
        html += '<div id="chart_container_'+state.id+'" class="chart central-drop"></div>';
        container.getElement().append( html);
    });

    // initialization of first "table" tab inside the central container
    myLayout.registerComponent( 'tableComponent', function( container, state ){
        // add specific html
        var html= '';
        html += '<div id="grid_container_'+state.id+'" class="grid table-striped central-drop" style="height: 100%;"></div>';
        console.log(html);
        container.getElement().append( html);
    });

    // initialization of container at bottom center of the window
    myLayout.registerComponent( 'moreInfoContainer', function( container ){
    });

    // initialization of "log" tab inside the "more-info" container
    myLayout.registerComponent( 'logContainer', function( container ){
        // add specific html
        container.getElement().html( '<div id="log"></div>');
        container.getElement().css( 'overflow', 'auto' );

    });

    // initialization of "notes" tab inside the "more-info" container
    myLayout.registerComponent( 'notesContainer', function( container ){
        // add specific html
        container.getElement().html( '<div><table class="table table-striped table-hover" id="notes"></table></div>');
        container.getElement().css( 'overflow', 'auto' );
    });

    // COLUMN ON THE RIGHT
    // initialization of div at the top right of the window
    myLayout.registerComponent( 'stationMenu', function( container ){
        // add specific html and classes
        var html = '<h5 class="m-t-20">Reti</h5>';
        html += '<div class="clearfix" id="network-search">';
        html += '    <input type="text" id="input-search" value="">';
        html += '    <button id="add-searched" class="btn btn-info btn-sm" data-toggle="tooltip" data-placement="top" title="" data-original-title="Aggiungi tutti gli elementi ricercati"><i class="icon-plus"></i> tutti</button>';
        html += '</div>';
        html += '<div id="ext-json"></div>';

        container.getElement().html( html );

        container.getElement().addClass( 'station_menu' );
        container.getElement().css( 'overflow', 'auto' );
    });

    // initialization of div at the bottom right of the window
    myLayout.registerComponent( 'activeMacroContainer', function( container ){
        // add specific html and classes
        container.getElement().append( '<div class="drop" id="macro-detail"><span class="drop-placeholder"><i class="icon-frame"></i> Trascina un parametro</span></div>');
        container.getElement().css( 'overflow', 'auto' );
    });

    /**
     * Plugin "initialised" event
     */
    myLayout.on('initialised', function(){
        console.log("Layout caricato");

        // initialize global variable
        centralContainer = myLayout.root.getItemsById('centralContainer')[0];
        centralContainer.header.element.addClass('header-drop');

        // initialize all inner plugins only after the goldenlayout plugin is completed
        // called only once after entering the page
        initializeElements(); //analyser_settings.js
    });

    /**
     * "Created" event of any component
     */
    myLayout.on('componentCreated',function(component) {

        // check if component is a "table" or a "chart" tab
        if(component.componentName == 'tableComponent' || component.componentName == 'chartComponent'){
            // get resize event of the main container
            component.container.on('resize',function() {
                // get active tab in the central container
                var activeTabElement = centralContainer.header.activeContentItem;
                // get object with tab metadata
                var componentState = activeTabElement.config.componentState;
                console.log("Resize");

                // resize highcharts plugin
                if (componentState.type == 'chart') {
                    // different behaviors depending on whether the chart is single or multiple
                    if( componentState.multiple == false && chart[componentState.id]){
                        console.log("Chart resize");
                        //trigger full rerender including all data and rows
                        chart[componentState.id].reflow();
                    }
                    else if( componentState.multiple == true && multipleCharts[componentState.id]){
                        console.log("Multiple chart resize");
                        // loop through all charts
                        // for each highchart plugin trigger full rerender including all data and rows
                         $.each(multipleCharts[componentState.id], function(index, el){
                            el.reflow();
                        });
                    }
                }
            });
        }
    });
    //////////////////////////////////////////
    // END EVENTS

    // Main initialization
    myLayout.init();
    // Set background as white
    $(".lm_content").css("background-color", "white");

});

