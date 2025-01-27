// original consoles
var _oldConsoleLog;
var _oldConsoleDir;
var _oldConsoleWarn;

/**
 * Document ready
 */
$(document).ready(function() {

    // set the little logo when closing the side menu
    logoTop();
    $(".sidebartoggler").on('click', function () {
        logoTop();
    });

    // set the console log depending on the app mode
    console.log('App mode: ' + app_mode);
    if (app_mode == 'production'){
        // var console = {};
        // store old console
        _oldConsoleLog = console.log;
        _oldConsoleDir = console.dir;
        _oldConsoleWarn = console.warn;
        // redefine new default one
        console.log = function(){};
        console.dir = function(){};
        console.warn = function(){};
    }

    makeTransporter();

    $('.inner-preloader').hide();

    /**
     * This is for the top header part and sidebar part.  - MODIFICA DELLE IMPOSTAZIONI DI BASE DEL TEMPLATE
     */
    var set = function () {
        var topOffset = 45; // template default setting (previous default value = 55 - variation due to footer's css; removed 10px padding: 5 top and 5 bottom)
        var height = ((window.innerHeight > 0) ? window.innerHeight : this.screen.height) - 1;
        height = height - topOffset;
        if (height < 1) height = 1;
        if (height > topOffset) {
            $(".page-wrapper").css("min-height", (height) + "px");
        }
    };
    $(window).ready(set);
    $(window).on("resize", set);

});

/**
 * Set the logo when resizing the browser window.
 */
$( window ).resize(function() {
    logoTop();
});

/**
 * Portal's logo management.
 */
function logoTop(){
    if ($("body").hasClass("mini-sidebar")) {
        $('.navbar-brand b').show();
        $('#short-icons').hide();
    } else {
        $('.navbar-brand b').hide();
        $('#short-icons').show();
    }
}

/**
 * Reset original consoles.
 */
function resetConsole(){
    console.log = _oldConsoleLog;
    console.dir = _oldConsoleDir;
    console.warn = _oldConsoleWarn;
}

/**
 * Preloader.
 */
function makeTransporter() {
    // console.log('makeTrasporter');
    var icons = ["", "-1", "-2", "-3", "-4", "-5", "-6", "-7", "-6",  "-5", "-4", "-3", "-2", "-1", ""];

    var a = $('#transporter');
    a.removeClass();
    a.addClass('fa-duotone fa-transporter fa-stack-1x');

    changeIcon(0, icons);
};

/**
 * Switch image for preloader.
 * 
 * @param {integer} idx 'icons' array index.
 * @param {array}   icons Icons array.
 */
function changeIcon(idx, icons){

    var idxPrev = idx-1;
    if(idx==icons.length){
        idx = 0;
        idxPrev = icons.length-1;
    }
    // console.log('changeIcon');
    // console.log(idx);
    // console.log(icons[idx-1]);
    var a = $('#transporter');

    a.removeClass('fa-transporter'+icons[idxPrev]);
    a.addClass('fa-transporter'+icons[idx]);
    setTimeout(function () {
        ++idx;
        changeIcon(idx,icons);
    }, 400);
};



