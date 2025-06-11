/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var table;

    // variable for loadMessages function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(1, 'months').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#date-range').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get messages within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        // refresh messages list in the first tab
        loadMessages(dateFrom, dateTo);
    });

    //datatable
    table = $('#message-table').DataTable({
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-6 col-sm-6"i><"col-lg-6 col-sm-6 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets:   -1
            },
            { "orderable": false, "targets": 0 }
            // { "type": "datetime", "targets": 1 }
        ],
        "order": [[ 1, "desc" ]],
        responsive: {
            details: {
                type: 'column',
                target: -1
            }
        }
    });

    // change event of a filter
    $('.telegram-page').on('change', '#filter-channels', function(e){
        e.preventDefault();

        // refresh messages list in the first tab
        loadMessages(dateFrom, dateTo);
    });

    //TABLE FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Retreive message detail.
     */
    $('#message-table').on('click', '.show_message', function(e){

        e.preventDefault();

        // get message id stored in table tr element
        var msgid = parseFloat($(this).parent().parent().data("id"));

        //check if the message's detail is already open
        if( $('#msg'+msgid).length ) {
            console.log('The message\'s detail is already open');
            $('.nav-tabs a[href="#msg'+msgid+'"]').tab('show');
            return;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();

        // get message data via an ajax call
        var jqxhr = $.ajax({
            url: '/div_tel_get_selected_message',
            type: "post",
            dataType: "json",
            data: {
                id: msgid
            },
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then build html
            if(result.res == 'OK'){

                // app: "Bollettiono TDG"
                // chat: "@meteovda"
                // document: "https://cf.regione.vda.it/allegati/bollettini/tdg/TorGeants_Sector3_2019-09-08.pdf"
                // document_caption: ""
                // id: 20
                // message: null
                // parse_mode: null
                // photo: null
                // photo_caption: null
                // sent_date: "2019-09-08"
                // sent_time: "2019-09-08 10:38:11.118203"
                // sent_time_format: "2019-09-08 10:38"
                // status: 1
                // telegram_type: "Document"

                // build the Telegram message
                var msg = result.msg;
                var mex;

                // take care of different types of message
                if(msg.message){
                    mex = msg.message;
                }else if (msg.document) {
                    mex = '<a href="'+msg.document+'" target="_blank">'+msg.document+'</a>';
                }else if (msg.photo){
                    mex = '<a href="'+msg.photo+'" target="_blank">'+msg.photo+'</a>';
                };

                // add link for the new tab
                var html = '<li class="nav-item"> <a class="nav-link" data-toggle="tab" href="#msg'+msg.id+'" role="tab"><span class="hidden-sm-up"><i class="fa-regular fa-memo-pad"></i></span> <span class="hidden-xs-down">'+msg.chat+' '+msg.insert_date+'</span>&nbsp&nbsp<i class="fa fa-times text-danger close_tab" data-close="msg'+msg.id+'"></i></a> </li>';
                // append new content to tabs list
                $('.nav-tabs').append(html);

                // variable for dynamically build the html
                var html = '';
                html +='<div class="tab-pane p-20" id="msg'+msg.id+'" role="tabpanel">\n';
                html +='    <div class="form-body panel-report-view">\n';

                html +='        <h4 class="box-title">Messaggio Telegram inviato</h4>\n';
                html +='        <hr class="m-t-0 m-b-20">\n';
                html +='        <div class="form-group row">\n';
                html +='            <div class="col-12">\n';
                html +='                <div class="form-group row">\n';
                html +='                    <label for="" class="control-label col-2 col-form-label">Data creazione</label>\n';
                html +='                    <div class="col-4 view-param">'+msg.insert_time_format+'</div>\n';
                html +='                    <label for="" class="control-label col-2 col-form-label"><i class="mdi mdi-telegram"></i> Canale</label>\n';
                html +='                    <div class="col-4 view-param text-'+msg.tc_color+'">'+msg.chat+'</div>\n';
                html +='                </div>\n';
                html +='            </div>\n';
                html +='            <div class="col-12">\n';
                html +='                <div class="form-group row">\n';
                html +='                    <label for="" class="control-label col-2 col-form-label">Tipo</label>\n';
                html +='                    <div class="col-4 view-param">'+msg.telegram_type+'</div>\n';
                html +='                    <label for="" class="control-label col-2 col-form-label">Inviato</label>\n';
                html +='                    <div class="col-4 view-param">'+msg.icon+'</div>\n';
                html +='                </div>\n';
                html +='            </div>\n';
                html +='        </div>\n';

                // check if there is any caption to add
                if (msg.caption){
                    html +='        <div class="form-group row">\n';
                    html +='            <label for="" class="control-label col-2 col-form-label">Didascalia</label>\n';
                    html +='            <div class="col-10">'+msg.caption+'</div>\n';
                    html +='        </div>\n';
                }

                html +='        <div class="form-group row">\n';
                html +='            <label for="" class="control-label col-2 col-form-label">Messaggio</label>\n';
                html +='            <div class="col-10">'+mex+'</div>\n';
                html +='        </div>\n';
                html +='        <hr class="m-t-0 m-b-10">\n';
                html +='        <div class="form-actions">\n';
                html +='            <div class="row">\n';
                html +='                <div class="col-md-6">\n';
                html +='                    <div class="row">\n';
                html +='                        <div class="col-md-offset-3 col-md-9">\n';
                html +='                            <button type="button" class="btn btn-secondary message-close-view"  data-close="msg'+msg.id+'">Chiudi</button>\n';
                html +='                        </div>\n';
                html +='                    </div>\n';
                html +='                </div>\n';
                html +='                <div class="col-md-6"> </div>\n';
                html +='            </div>\n';
                html +='        </div>\n';

                html +='    </div>\n';
                html +='</div>\n';

                // append new content
                $('#tab-list').append(html);
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // show new tab
                $('.nav-tabs a[href="#msg' + msg.id + '"]').tab('show');
            }
            else{
                // at the end of the process hide preloader
                $(".inner-preloader").hide();
                // error message
                swal("Errore!", "Errore durante il recupero dettaglio del messaggio", "error");
            }

        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dettaglio del messaggio", "error");
        });
    });

    /**
     * Delete message
     */
    $('#message-table').on('click', '.delete_message', function(e){

        e.preventDefault();

        // get message id stored in table tr element
        var msgid = parseFloat($(this).parent().parent().data("id"));

        // confirm message in order to continue in message deleting
        swal({
            title: "Stai per eliminare il messaggio Telegram",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete the selected message
            var jqxhr = $.ajax({
                url: '/div_tel_del_selected_message',
                type: "post",
                dataType: "json",
                data: {
                    id: msgid
                }
            })
            .done(function(result) {

                // check result
                //  - if 'true' then the message is correctly deleted -> remove it from table
                //  - else error
                if(result == true){

                    // delete row from datatable without reloading the whole list and refresh it
                    swal("Messaggio eliminato", "Il messaggio Telegram è stato eliminato con successo!", "success");
                    table.row($("tr[data-id='"+msgid+"']")).remove().draw();
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione del messaggio", "error");
                }

            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l\'eliminazione del messaggio", "error");
            });

        });
    });
    /////////////////////////////////////////////////////////////////////
    // END TABLE FUNCTIONS

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    // SUBMIT REGION
    /**
     * Validate form.
     */
    var validator = $('#form_telegram_new').validate({ // initialize the plugin
        rules: {
            "select-channel" : {
                required: true,
                // min: 0
            },
            "message-channel" : {
                required: true
            }
        },
        messages: {
            "select-channel" : {
                min: "Selezionare un canale"
            },
            "message-channel" : {
                required: "Inserire un messaggio"
            }
        },
        ignore: "",
    });

    /**
     * Submit button.
     */
    $('.telegram-page').on('click', '#invia-msg', function(e){
        e.preventDefault();

        // check if all form fields are valid
        if (! $('#form_telegram_new').valid() ){
            swal("Attenzione", "Inserire tutti i campi obbligatori per inviare un messaggio", "info");
            return false;
        };

        // retrieve data to be sent to server
        var ch = $('#select-channel').val();
        var chTxt =$( "#select-channel option:selected" ).text();
        var msg = $('#message-channel').val();
        console.log("msg: "+msg);

        // swal({
        //     title: "Conferma invio messaggio al canale "+chTxt,
        //     text: "Inserisci la password:",
        //     type: "input",
        //     showCancelButton: true,
        //     closeOnConfirm: false,
        //     animation: "slide-from-top",
        //     inputPlaceholder: "password",
        //     cancelButtonText: "Annulla"
        // },
        // function(inputValue){

        // confirm message before send it
        swal({
            title: "Stai per inviare un messaggio",
            text: "Sei proprio sicuro di voler proseguire all'invio?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Sono sicuro",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        },
        function(result){

            // if (! inputValue || inputValue != "1234") {
            //     swal("Errore", "Password errata!", "error");
            //     return;
            // }

            // if not confirmed then stop the submit and return to form
            if( ! result ){
                console.log('Azione annullata');
                return;
            }

            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();
            // ajax call
            var jqxhr = $.ajax({
                url: '/div_tel_put_message',
                type: "post",
                dataType: "json",
                data: {
                    msg: msg,
                    ch : ch
                }
            })
            .done(function(result) {

                // at the end of the process hide preloader
                $('.inner-preloader').hide();

                // check result
                // if 'true' then ask to user if send another message
                // else error
                if(result == true){

                    // confirm message
                    swal({
                        title: "Messaggio inviato con successo!",
                        text: "Vuoi inviare il messaggio ad altri canali?",
                        type: "success",
                        showCancelButton: true,
                        confirmButtonText: "Si, grazie",
                        closeOnConfirm: true,
                        cancelButtonText: "No, ho finito"
                    },
                    function(isConfirm){
                        // if not confirmed then clear form fields and return to main tab
                        if (!isConfirm) {
                            $('.nav-tabs a[href="#msg-list"]').tab('show');
                            $('#message-channel').val("");
                        }

                        // refresh the list of messages in the first table
                        loadMessages(dateFrom, dateTo);
                        // reset filter
                        $('#select-channel').val(-1);
                    });
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'invio del messaggio", "error");
                }

            })
            .fail(function(xhr, err) {
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
                // error message
                swal("Errore!", "Errore durante l\'invio del messaggio", "error");
            });

        });
    });

    /**
     * Cancel button.
     */
    $('.telegram-page').on('click', '#annulla-msg', function(e){
        e.preventDefault();

        // clear form fields
        $('#message-channel').val('');
        $('#select-channel').val(-1);

        // show main tab
        setTimeout(function(){
            $('.nav-tabs a[href="#msg-list"]').tab('show');
        }, 1);

    });
    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    // TAB FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Close view report.
     */
    $('.telegram-page').on('click', '.close_tab, .message-close-view', function(e){
        e.preventDefault();
        // get "element" to be closed
        var close = $(this).data("close");
        console.log(close);

        // remove the single tab (from list and group) and show the tab with the list
        setTimeout(function(){
            $('.nav-tabs a[href="#' + close + '"]').remove();
            $('#tab-list #'+close).remove();
            $('.nav-tabs a[href="#msg-list"]').tab('show');

        }, 1);
    });

    /////////////////////////////////////////////////////////////////////
    //END TAB FUNCTIONS

    // get data in order to fill the datatable
    loadMessages(dateFrom, dateTo);

    /**
     * Function that retrieves messages of a given period.
     *
     * @param {date} from Start period datetime.
     * @param {date} to End period datetime.
     *
     */
    function loadMessages(from, to){

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get selected channel
        var channel = $("#filter-channels").val();

        // reset datatable
        if ( table )
            table.clear();

        // get messages created between "dateFrom" and "dateTo"
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/div_tel_get_messages',
            type: "post",
            dataType: "json",
            data: {
                from: from,
                to: to,
                ch: channel
            },
        })
        .done(function(result) {
            var messages = result.messages;

            // check if at least one element exists
            if( messages.length > 0 ){
                // variable for dynamically build the html
                var html= '';
                // loop through all elements
                // for each message, build a html row to be added to the datable
                $.each(messages, function(idx, el) {

                    // take care of different types of message
                    var msg;
                    if(el.message){
                        msg = el.message_short;
                    }
                    else if (el.document) {
                        msg = '<a href="'+el.document+'" target="_blank">'+el.document+'</a>';
                    }
                    else if (el.photo){
                        msg = '<a href="'+el.photo+'" target="_blank">'+el.photo+'</a>';
                    };

                    html += '<tr data-id="'+el.id+'">';
                    html += '    <td class="bobo-nowrap">';
                    html += '        <a href="javascript:void(0)" class="show_message" data-toggle="tooltip" data-original-title="Visualizza"> <i class="ti-zoom-in text-info"></i> </a>';
                    // if user has delete grant
                    // not only for the page but also for the channel
                    if(delete_grant && el.channel_delete){
                        html += '        <a href="javascript:void(0)" class="delete_message" data-toggle="tooltip" data-original-title="Elimina"> <i class="icon-trash text-danger"></i> </a>';
                    }
                    html += '    </td>';
                    html += '    <td class="bobo-nowrap">'+getFormattedDateDT(el.insert_time_format, 'basic_timeStartMin')+'</td>';
                    html += '    <td class="text-'+el.tc_color+'">'+el.chat+'</td>';
                    html += '    <td>'+el.tag+'</td>';
                    html += '    <td>'+el.telegram_type+'</td>';
                    html += '    <td>'+msg+'</td>';
                    html += '    <td class="bobo-nowrap">'+el.icon_status+'</td>';
                    html += '    <td></td>';
                    html += '</tr>';

                });

                // add rows to datatable by using html object
                table.rows.add($( html ));
                // redraw it
                table.draw();
                // adjust columns size
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
                // redraw it
                table.draw();
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei messaggi telegram", "error");

        });
    }
});
