/**
 * Document ready
 */
$(document).ready(function () {

    var emails;
    var access_logs;

    /////// START TAB: Manutenzione del portale ///////

    // plugin initialization
    $("#maintenance-active").bootstrapToggle();

    $('#maintenance-start, #maintenance-end').bootstrapMaterialDatePicker({
        minDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang: 'it',
        cancelText: 'Annulla'
    }).on('change', function () {

        // programatically enable toggle
        if ($(this).val() != '')
            $("#maintenance-active").prop('checked', true).trigger('change');

        if ($(this).attr('id') == 'maintenance-start') {
            // for the end time picker, set min date as start time picker value
            $('#maintenance-end').bootstrapMaterialDatePicker('setMinDate', $('#maintenance-start').val());
        }

        // check if start time is same or after end time
        if (moment($('#maintenance-start').val(), 'DD/MM/YYYY HH:mm').isSameOrAfter(moment($('#maintenance-end').val(), 'DD/MM/YYYY HH:mm')))
            // if true then reset end time
            $('#maintenance-end').val('');
    })

    /**
     * Click event on "Salva manutenzione" button
     */
    $('#maintenance-form').on('submit', function (e) {
        e.preventDefault();

        // create a container object
        var totalObj = {
            maintenance: $("#maintenance-active").is(':checked'), // 18 feb 2025 h 15:30
            maintenance_start: $("#maintenance-start").val(),
            maintenance_end: $("#maintenance-end").val()
        };

        // ajax call
        var jqxhr = $.ajax({
            url: '/usr_sysadmin_put_options',
            type: "post",
            dataType: "json",
            data: {
                obj: JSON.stringify(totalObj)
            }
        })
            .done(function (result) {
                // check result
                // if TRUE then show success message and reset form
                if (result) {
                    swal("Impostazioni salvate", "Le impostazioni sono state correttamente salvate", "success");

                    loadOptions();
                }
            })
            .fail(function (xhr, err) {
                // error message
                swal("Errore!", "Errore durante il salvataggio del messaggio", "error");
            });
    });

    /**
     * Click event on "Annulla" button
     */
    $('#cancel-maintenance').on('click', function (e) {
        e.preventDefault();

        // reset form
        $('#maintenance-active').prop('checked', false).trigger('change');
        $('#maintenance-start, #maintenance-end').val('');
    });

    /**
     * Click event on "Elimina manutenzione" button
     */
    $('.maintenance-info').on('click', '#del-maintenance', function (e) {
        e.preventDefault();

        // confirm message in order to continue in maintenance deleting
        swal({
            title: "Eliminazione manutenzione",
            text: "Sei sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // create a container object
            var totalObj = {
                maintenance: false,
                maintenance_start: null,
                maintenance_end: null
            };

            // ajax call
            var jqxhr = $.ajax({
                url: '/usr_sysadmin_put_options',
                type: "post",
                dataType: "json",
                data: {
                    obj: JSON.stringify(totalObj)
                }
            })
                .done(function (result) {
                    // check result
                    // if TRUE then show success message and reset form
                    if (result) {
                        swal("Manutenzione eliminata", "La manutenzione è stata correttamente eliminata", "success");

                        $('#maintenance-active').prop('checked', false).trigger('change');
                        $('#maintenance-start, #maintenance-end').val('');
                        $('.maintenance-info').empty();
                    }
                })
                .fail(function (xhr, err) {
                    // error message
                    swal("Errore!", "Errore durante l'eliminazione della manutenzione", "error");
                });

        });
    });

    // fill page with data from server
    loadOptions();

    /////// END TAB: Manutenzione del portale ///////

    /////// START TAB: Email Gateway ///////

    // variable for loadEmail function
    var dateTo = moment().endOf('day').format('YYYY-MM-DD 23:59');
    var dateFrom = moment().startOf('day').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#email-tab .input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Oggi': [moment(), moment()],
            'Ieri': [moment().subtract(1, 'days'), moment().subtract(1, 'days')],
            'Ultimi 3 giorni': [moment().subtract(2, 'days'), moment()],
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function (start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');

        $('.view-mail').hide();
        $('.no-mail').show();

        // refresh reports list in the first tab
        loadEmails();
    });

    $('.view-mail').hide();

    // datatable
    var tblEmail = $('#email-table').DataTable({
        "responsive": {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets: -1
            },
            {
                orderable: false,
                targets: [0, 2, 3, 4, 5, 6]
            },
        ],
        "order": [[1, "desc"]],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: []
        // "ordering": false
    });

    /**
     * Click event on show detail button
     */
    $('#email-tab').on('click', '.show-item', function (e) {
        e.preventDefault();

        const id = parseInt($(this).parent().parent().data('id'));

        loadEmailDetail(id);
    });

    /**
     * Click event on close detail button
     */
    $('#email-tab').on('click', '#close-email', function (e) {
        e.preventDefault();
        $('.view-mail').hide();
        $('.no-mail').show();
    });

    // first load
    loadEmails();

    /////// END TAB: Email Gateway ///////

    /////// START TAB: Access log ///////

    // variable for loadAccessLogs function
    var dateTo_al = moment().endOf('day').format('YYYY-MM-DD 23:59');
    var dateFrom_al = moment().startOf('day').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start_al = moment(dateFrom).format("DD/MM/YYYY");
    var end_al = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker
    $('#access-log-tab .input-daterange-datepicker').daterangepicker({
        startDate: start_al,
        endDate: end_al,
        maxDate: end_al,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        ranges: {
            'Oggi': [moment(), moment()],
            'Ieri': [moment().subtract(1, 'days'), moment().subtract(1, 'days')],
            'Ultimi 3 giorni': [moment().subtract(2, 'days'), moment()],
            'Ultimi 7 giorni': [moment().subtract(6, 'days'), moment()]
        },
        alwaysShowCalendars: true,
        locale: dateRangePickerSettings.locale
    }, function (start, end, label) {

        //on change event, get reports within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom_al = start.format('YYYY-MM-DD');
        dateTo_al = end.format('YYYY-MM-DD 23:59:59');

        $('.view-access-log').hide();
        $('.no-access-log').show();

        // refresh logs list in the first tab
        loadAccessLogs();
    });

    $('.view-access-log').hide();

    // datatable
    var tblAccessLog = $('#access-log-table').DataTable({
        "responsive": {
            details: {
                type: 'column',
                target: -1
            }
        },
        "columnDefs": [
            {
                className: 'dtr-control',
                orderable: false,
                targets: -1
            },
            {
                orderable: false,
                targets: [0, 2, 3, 5, 6]
            },
        ],
        "order": [[1, "desc"]],
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        buttons: []
        // "ordering": false
    });

    /**
     * Click event on show detail button
     */
    $('#access-log-tab').on('click', '.show-item', function (e) {
        e.preventDefault();

        const id = parseInt($(this).parent().parent().data('id'));

        loadAccessLogDetail(id);
    });

    /**
     * Click event on close detail button
     */
    $('.view-access-log').on('click', '#close-log', function(e) {
        e.preventDefault();
        
        $('.view-access-log').hide();
        $('.no-access-log').show();
    });

    // first load
    loadAccessLogs();

    /////// END TAB: Access log ///////

    /**
     * Function that retrieves system admin options
     * No args needed
     */
    function loadOptions() {

        // reset page's contents
        $('#maintenance-active').prop('checked', false).trigger('change');
        $('#maintenance-start, #maintenance-end').val('');
        $('.maintenance-info').empty();

        // get data from database
        var jqxhr = $.ajax({
            url: '/usr_sysadmin_get_options',
            type: "post",
            dataType: "json"
        })
            .done(function (result) {
                // check result
                // if OK then fill message form
                if (result.res == 'OK') {

                    // metadata stored inside the 'general_options' table with a jsonb object
                    let obj = JSON.parse(result.opt);
                    let html = '';

                    console.dir(obj);

                    // check if object is not empty
                    if (Object.keys(obj).length !== 0) {
                        // fill form with options set by system admin
                        $("#maintenance-active").prop('checked', obj.maintenance).trigger('change');
                        $("#maintenance-start").val(obj.maintenance_start);
                        $("#maintenance-end").val(obj.maintenance_end);

                        // if maintenance is true then show a recap message
                        if (obj.maintenance == true) {
                            html += '<div class="light-bg">';
                            html += '    <h4 class="text-info"><strong>Attenzione!</strong> Hai programmato una manutenzione del portale</h4>';
                            html += '    <hr class="m-t-0 m-b-20">';
                            html += '    <h5 class="m-t-10 text-primary"><i class="fa-solid fa-square-check text-success"></i> Sistema <strong>in manutenzione</strong></h5>';
                            html += '    <div class="m-t-10">Data/ora inizio: <strong>' + (obj.maintenance_start ? obj.maintenance_start : 'non specificata') + '</strong></div>';
                            html += '    <div class="m-t-10">Data/ora fine: <strong>' + (obj.maintenance_end ? obj.maintenance_end : 'non specificata') + '</strong></div>';
                            html += '    <div class="m-t-10 text-grey font-italic"><strong>N.B.:</strong> puoi aggiungere una sola manutenzione per volta, se ne aggiungi un\'altra verrà sovrascritta.</div>';
                            html += '    <div class="m-t-20 m-b-10">';
                            html += '        <button type="button" class="btn btn-danger btn-sm" name="del-maintenance" id="del-maintenance"><i class="fa-solid fa-trash-xmark"></i> Elimina manutenzione</button>';
                            html += '    </div>';
                            html += '</div>';

                            $('.maintenance-info').html(html);
                        }
                    }
                }
            })
            .fail(function (xhr, err) {
            });
    }

    /**
     * Function that retrieves system emails
     * No args needed
     */
    function loadEmails() {
        // reset datatable
        if (tblEmail)
            tblEmail.clear();
        $(".inner-preloader").show();
        // get data from database
        var jqxhr = $.ajax({
            url: '/usr_sysadmin_get_system_emails',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom,
                to: dateTo
            }
        })
            .done(function (result) {
                // check result
                // if OK then fill message form
                if (result.res == 'OK') {

                    // metadata stored inside a global variable
                    let html = '';
                    emails = result.emails;

                    // check if there is at least one email
                    if (emails.length >= 0) {
                        // loop through emails and build a tr element
                        $.each(emails, function (idx, el) {

                            html += '<tr data-id="' + el.id + '">';
                            html += '    <td>';
                            html += '        <a href="javascript:void(0)" class="show-item" data-toggle="tooltip" data-original-title="Visualizza email"> <i class="fa-light fa-magnifying-glass-plus text-info"></i> </a>';
                            html += '    </td>';
                            html += '    <td>' + el.id + '</td>';
                            html += '    <td>' + el.recipients + '</td>';
                            html += '    <td class="font-bold">' + el.subject + '</td>';
                            html += '    <td>' + el.formatted_status + '</td>';
                            html += '    <td>' + el.formatted_sent_time + '</td>';
                            if (el.sent_tries > 0)
                                html += '    <td class="text-center font-bigger ' + el.formatted_sent_tries + '"><i class="fa-solid fa-circle-' + el.sent_tries + '"></i></td>';
                            else
                                html += '    <td class="text-center font-bigger">-</td>';
                            html += '    <td></td>';
                            html += '</tr>';
                        });

                        // add rows to datatable by using html object
                        tblEmail.rows.add($(html));
                        // redraw it
                        tblEmail.draw();
                        // adjust columns size
                        tblEmail.columns.adjust();

                        // initializes the tooltips of all lines
                        // loop through each table row contained in all pages (not only the visible one )
                        tblEmail.rows({ page: 'all' }).every(function () {
                            var row = this;
                            // get all tr node and transform it into a jquery items
                            // in order to find all tooltip elements
                            $(row.node())
                                .find('[data-toggle="tooltip"]')
                                .tooltip();
                        });

                    } else {
                        // redraw it
                        tblEmail.draw();
                    }
                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }
                else {
                    swal('Errore!', 'Si è verificato un errore durante il recupero delle email', 'error');
                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }
            })
            .fail(function (xhr, err) {
                swal('Errore!', 'Si è verificato un errore durante il recupero delle email', 'error');
            });
    }

    /**
     * Function that builds email's detail
     *
     * @param {integer} id Email ID
     */
    function loadEmailDetail(id) {
        // retrieve email object from global variable
        const email = emails.filter(e => e.id == id)[0];

        // reset html container
        $('.view-mail').empty();

        // dynamically build email's detail
        let html = '';
        html += '<h5 class="text-info m-t-15">Visualizza email inserita nel gateway il <strong>' + email.formatted_insert_time + '</strong> </h5>';
        html += '<hr class="m-t-10">';
        html += '<div class="row m-b-5">';
        html += '    <div class="col-md-4">';
        html += '        <strong>ID:</strong> ' + email.id;
        html += '    </div>';
        html += '    <div class="col-md-8">';
        html += '        <strong>Mailer:</strong> ' + email.app;
        html += '    </div>';
        html += '</div>';
        html += '<div class="row m-b-5">';
        html += '    <div class="col-md-4">';
        html += '        <strong>Tentativi:</strong> ';
        if (email.sent_tries > 0)
            html += '<i class="font-bigger ' + email.formatted_sent_tries + ' fa-solid fa-circle-' + email.sent_tries + '"></i>';
        else
            html += '--';
        html += '    </div>';
        html += '    <div class="col-md-8">';
        html += '        <strong>Data invio:</strong> ' + email.formatted_sent_time;
        html += '    </div>';
        html += '</div>';
        html += '<div class="row m-b-5">';
        html += '    <div class="col-md-4">';
        html += '        <strong>Stato:</strong> ' + email.formatted_status;
        html += '    </div>';
        html += '    <div class="col-md-8">';
        html += '        <strong>Destinatari:</strong> ' + email.recipients;
        html += '    </div>';
        html += '</div>';
        html += '<h5 class="divider-title m-t-10 m-b-10"><i class="fa-solid fa-pen-to-square"></i> Oggetto: <strong>' + email.subject + '</strong></h5>';
        html += '<div class="email-content">';
        html += email.body;
        html += '</div>';
        html += '<hr class="m-t-10">';
        html += '<button type="button" class="btn btn-danger" id="close-email"> <i class="fa-solid fa-xmark"></i> Chiudi email</button>';

        // append the new content and show the container
        $('.view-mail').append(html);
        $('.view-mail').show();
        // hide the placeholder
        $('.no-mail').hide();
    }

    /**
     * Function that retrieves system access logs
     * No args needed
     */
    function loadAccessLogs() {
        // reset datatable
        if (tblAccessLog)
            tblAccessLog.clear();
        $(".inner-preloader").show();
        // get data from database
        var jqxhr = $.ajax({
            url: '/usr_sysadmin_get_system_access_logs',
            type: "post",
            dataType: "json",
            data: {
                from: dateFrom_al,
                to: dateTo_al
            }
        })
            .done(function (result) {
                // check result
                // if OK then fill message form
                if (result.res == 'OK') {

                    // metadata stored inside a global variable
                    let html = '';
                    access_logs = result.access_logs;

                    // check if there is at least one access log
                    if (access_logs.length >= 0) {
                        // loop through access logs and build a tr element
                        $.each(access_logs, function (idx, el) {

                            html += '<tr data-id="' + el.log_id + '">';
                            html += '    <td>';
                            html += '        <a href="javascript:void(0)" class="show-item" data-toggle="tooltip" data-original-title="Visualizza accesso"> <i class="fa-light fa-magnifying-glass-plus text-info"></i> </a>';
                            html += '    </td>';
                            html += '    <td>' + el.log_id + '</td>';
                            html += '    <td>' + el.log_email + '</td>';
                            html += '    <td>' + el.user_fullname + '</td>';
                            html += '    <td>' + el.formatted_result + '</td>';
                            html += '    <td>' + el.formatted_insert_time + '</td>';
                            html += '    <td></td>';
                            html += '</tr>';
                        });

                        // add rows to datatable by using html objectf
                        tblAccessLog.rows.add($(html));
                        // redraw it
                        tblAccessLog.draw();
                        // adjust columns size
                        tblAccessLog.columns.adjust();

                        // initializes the tooltips of all lines
                        // loop through each table row contained in all pages (not only the visible one )
                        tblAccessLog.rows({ page: 'all' }).every(function () {
                            var row = this;
                            // get all tr node and transform it into a jquery items
                            // in order to find all tooltip elements
                            $(row.node())
                                .find('[data-toggle="tooltip"]')
                                .tooltip();
                        });

                    } else {
                        // redraw it
                        tblAccessLog.draw();
                    }
                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }
                else {
                    swal('Errore!', 'Si è verificato un errore durante il recupero degli accessi', 'error');
                    // at the end of the process hide preloader
                    $(".inner-preloader").hide();
                }
            })
            .fail(function (xhr, err) {
                swal('Errore!', 'Si è verificato un errore durante il recuperodegli accessi', 'error');
            });
    }

    /**
     * Function that builds access log's detail
     *
     * @param {integer} id Access log ID
     */
    function loadAccessLogDetail(id) {

        // retrieve access log object from global variable
        const access_log = access_logs.filter(e => e.log_id == id)[0];
        // reset html container
        $('.view-access-log').empty();
        // initialize json editor plugin
        var container = $('.view-access-log');
        var options = {
            mode: 'view',
            modes: [],
            search: false,
            indentation: 4,
            name: 'Headers accesso',
            navigationBar: false,
            language: 'it',
            languages: jsonEditorlang
        };
        // show access log header in JSON container
        var resultEditor = new JSONEditor(container[0], options);
        resultEditor.set(JSON.parse(access_log.log_headers));
        resultEditor.expandAll();
        $('.view-access-log').show();
        // hide the placeholder
        $('.no-access-log').hide();

        // @devs: aggiunto fisicamente pulsante chiudi
        var closeButton = $('<div class="mt-2"><hr><button type="button" class="btn btn-danger" id="close-log"><i class="fa-solid fa-xmark"></i> Chiudi log</button></div>');
        container.append(closeButton);

    }


    $(document).on('click', '[data-toggle="tooltip"]', function () {
        $(this).tooltip('hide');
    });

});
