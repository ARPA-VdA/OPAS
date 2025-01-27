// GLOBAL VARIABLES
var loop;
var isRunning = false;

/**
 * Document ready
 */
$(document).ready(function() {

    // on close event
    $('body').on('click', '.jq-toast-single', function(e){
        e.preventDefault();

        // get toast element
        var toast = $(this);
        // get notification id stored into toast
        var noid = parseInt($(this).find('.toast-body').data('id'));

        // check if defined
        if(isNaN(noid))
            return;

        // acknowledge all finished notifications
        var jqxhr = $.ajax({
            url: '/str_dataview_put_notification_ack',
            type: "post",
            dataType: "json",
            data: {
                id: noid
            }
        })
        .done(function(result) {
            console.log("Notification acknowledged");
            // hide toast
            toast.slideUp();

            // get user current location
            var loc = window.location.href;
            // check if current page is the download one otherwise redirect to it
            var see = loc.search('str_dataview_download');
            if(see == -1){
                window.location.replace('/str_dataview_download');
            }
        })
        .fail(function(xhr, err) {
            console.log("Errore durante il recupero delle notifiche");
        });
    });

});

/**
 * Function that starts a polling request
 *
 * @param: callback function
 */
function startNotifier(notifierCallback){
    // if it is already running then return
    if(isRunning){
        return;
    }

    console.log('startNotifier');
    // set true running flag
    isRunning = true;

    // polling request function
    var pollingRequest = function(){
        // get uuid from localstorage and check validity
        var uuid = storageGet('user-uuid');
        // if not valid then stop loop and reset localstorage variable
        if(!uuid || uuid == ''){
            stopNotifier();
            return false;
        }

        console.log('pollingRequest');

        // if notifierCallback is defined and is a function, call it
        if(typeof notifierCallback === "function")
            notifierCallback();

        // ajax call in order to retrieve all jobs (finished and pending)
        var jqxhr = $.ajax({
            url: '/str_dataview_get_notifications',
            type: "post",
            dataType: "json",
            data:{
                uuid: uuid
            }
        })
        .done(function(result) {
            console.dir(result);
            // for each finished job show toast with relative message
            $.each(result.notifications, function(idx, el){
                parseServerMessage(el);
            });

            // if there are no more pending job, stop loop and clear storage
            if(result.pending == 0){
                stopNotifier();
            }

        })
        .fail(function(xhr, err) {
            // error message
            console.log("Errore durante il recupero delle notifiche");
        });
    }

    // polling velocity
    var velocity = 30*1000; // in milliseconds -> 30 seconds
    // pollingRequest(); NO otherwise get no record
    // start loop
    loop = setInterval(pollingRequest, velocity);
    // set variable in the local storage
    storageStore('dataview-notifier', true);
}

/**
 * Function that stops the polling request and clear global variables
 * No args needed
 */
function stopNotifier(){
    clearInterval(loop);
    isRunning = false;

    storageRemove('dataview-notifier');
}

/**
 * Function that parse jobs results

 * @param {object} data: job result (json object)
 */
function parseServerMessage(data) {
    var o = JSON.parse(data.djq_result_obj);

    // build html body to show in the new toast
    var text = '<div class="toast-body" data-id="'+data.djq_id+'">';
    text += o.text;
    text += '<br><a href="" class="btn btn-sm btn-danger ack-msg">Non mostrare più <i class="fa-solid fa-check"></i></a>';
    text += '</div>';

    // choose notification message type
    switch(o.type) {
        case 'info':
            $.toast({
                heading: o.head,
                text: text,
                position: 'top-right',
                loaderBg:'#e8bb05',
                icon: 'info',
                hideAfter: 29000,
                showHideTransition: 'fade', // fade, slide or plain
                stack: 6
            });
            break;
        case 'warn':
            $.toast({
                heading: o.head,
                text: text,
                position: 'top-right',
                loaderBg:'#dc5a08',
                icon: 'warning',
                hideAfter: 29000,
                showHideTransition: 'fade', // fade, slide or plain
                stack: 6
            });
            break;
        case 'succ':
            $.toast({
                heading: o.head,
                text: text,
                position: 'top-right',
                loaderBg:'#e8bb05',
                icon: 'success',
                hideAfter: 29000,
                showHideTransition: 'fade', // fade, slide or plain
                stack: 6
            });
            break;
        case 'error':
            $.toast({
                heading: o.head,
                text: text,
                position: 'top-right',
                loaderBg:'#131313',
                icon: 'error',
                hideAfter: 29000,
                showHideTransition: 'fade', // fade, slide or plain
                stack: 6
            });
            break;

        default:
            // code block
    }
}
