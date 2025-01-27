/**
 * Document ready
 */
$(document).ready(function() {
    // GLOBAL VARIABLES
    var calendar;
    var prevYearButton;
    var nextYearButton;
    var currentViewYear = moment().year();

    var calibChart;


    // var date = moment();
    // var d = date.getDate();
    // var m = date.getMonth();
    // var y = date.getFullYear();

    // plugins initialization
    // calendar
    var calendarEl = document.getElementById('planning-calendar');
    calendar = new FullCalendar.Calendar( calendarEl, {
        themeSystem: 'bootstrap',
        initialView: 'dayGridMonth',
        locale: 'it',
        customButtons: {
            today: {
                text: 'Oggi',
                click: function(){
                    // on click update view and go to today date
                    var momentStart = moment();
                    currentViewYear = momentStart.year();

                    calendar.gotoDate(momentStart.format('YYYY-MM-DD'));
                    // update text in buttons with previous and following year
                    prevYearButton.innerHTML = currentViewYear - 1;
                    nextYearButton.innerHTML = currentViewYear + 1;
                }
            },
            prev: {
                click: function(){
                    // on click update view and go to previous month
                    var momentStart = moment(calendar.view.currentStart);
                    var newStartView = momentStart.add(-1, 'month');
                    currentViewYear = momentStart.year();

                    calendar.gotoDate(momentStart.format('YYYY-MM-DD'));
                    // update text in buttons with previous and following year
                    prevYearButton.innerHTML = currentViewYear - 1;
                    nextYearButton.innerHTML = currentViewYear + 1;
                }
            },
            next: {
                click: function() {
                    // on click update view and go to following month
                    var momentStart = moment(calendar.view.currentStart);
                    var newStartView = momentStart.add(+1, 'month');
                    currentViewYear = momentStart.year();

                    calendar.gotoDate(momentStart.format('YYYY-MM-DD'));
                    // update text in buttons with previous and following year
                    prevYearButton.innerHTML = currentViewYear - 1;
                    nextYearButton.innerHTML = currentViewYear + 1;
                }
            },
            myPrevYear: {
                text: currentViewYear -1,
                click: function() {
                    // on click update view and go to previous year
                    var momentStart = moment(calendar.view.currentStart);
                    var newStartView = momentStart.add(-1, 'year');
                    currentViewYear = currentViewYear - 1;

                    calendar.gotoDate(momentStart.format('YYYY-MM-DD'));
                    // update text in buttons with previous and following year
                    prevYearButton.innerHTML = currentViewYear - 1;
                    nextYearButton.innerHTML = currentViewYear + 1;
                }
            },
            myNextYear: {
                text: currentViewYear +1,
                click: function() {
                    // on click update view and go to following year
                    var momentStart = moment(calendar.view.currentStart);
                    var newStartView = momentStart.add(+1, 'year');
                    currentViewYear = currentViewYear + 1;

                    calendar.gotoDate(momentStart.format('YYYY-MM-DD'));
                    // update text in buttons with previous and following year
                    prevYearButton.innerHTML = currentViewYear - 1;
                    nextYearButton.innerHTML = currentViewYear + 1;
                }
            },
        },
        headerToolbar: {
            left:   'today prev,next',
            center: 'title',
            right:  'myPrevYear,myNextYear'
        },
        fixedWeekCount: false,
        dayMaxEventRows: true,
        // dayMaxEvents: 5, // allow "more" link when too many events
        datesSet: function (arg) {
            var view = arg.view;
            console.log('view');
            // show preloader, waiting for the end of the process
            $('.inner-preloader').show();

            // get first and last date of calendar view
            var viewStart = moment(view.activeStart);
            var viewEnd = moment(view.activeEnd);
            console.log('Start:' + viewStart.format('YYYY-MM-DD'));
            console.log('End:' + viewEnd.format('YYYY-MM-DD'));

            // retrieve events in visualized date range
            var jqxhr = $.ajax({
                url: '/calendario_get_events',
                type: "post",
                data: {
                    from: viewStart.format('YYYY-MM-DD'),
                    to: viewEnd.format('YYYY-MM-DD')
                }
            })
            .done(function(result) {
                console.log( "success" );
                // reset calendar
                calendar.removeAllEvents();

                // store events in variables
                var tickets = result.tickets;
                var autoCalibs = result.auto_calibs;
                var repCalibs = result.rep_calibs;
                var repMain = result.rep_mains;
                var repInsp = result.rep_inspections;

                // check if there is at least one ticket
                // then create events objects and add them to calendar
                if(tickets && tickets.length > 0)
                    createTicketsEvents(tickets);

                // check if there is at least one auto calibration
                // then create events objects and add them to calendar
                if(autoCalibs && autoCalibs.length > 0)
                    createAutoCalibsEvents(autoCalibs);

                // check if there is at least one report calibration
                // then create events objects and add them to calendar
                if(repCalibs && repCalibs.length > 0)
                    createRepCalibsEvents(repCalibs);

                // check if there is at least one report maintenance
                // then create events objects and add them to calendar
                if(repMain && repMain.length > 0)
                    createRepMainEvents(repMain);

                // check if there is at least one report inspection
                // then create events objects and add them to calendar
                if(repInsp && repInsp.length > 0)
                    createRepInspEvents(repInsp);

                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            })
            .fail(function(xhr, err) {
                console.log( "error" );
                // at the end of the process hide preloader
                $('.inner-preloader').hide();
            });
        },
        eventContent: function(eventInfo) {
            // display event title arrived from server
            return { html: eventInfo.event.title }
        },
        // click on the event
        eventClick:  function(info) {
            // retrieved clicked event
            var event = info.event;
            // get event day
            var day = moment(event.start).format('DD MMMM YYYY');
            // get more properties
            var extendedProps = event.extendedProps;

            // do different things based on event type
            switch(extendedProps.type){
                case 'ticket':
                case 'rep':
                    $('#full-ticket .modal-title').html(event.title+' del <strong>'+day.toUpperCase()+'</strong>');
                    $('#full-ticket .modal-body').html(extendedProps.description);

                    $('#full-ticket').modal();
                    break;
                case 'auto-calib':
                    {
                        // show preloader, waiting for the end of the process
                        $('.inner-preloader').show();
                        // reset table and chart
                        $('#events-chart').hide();
                        if(tableCalendar)
                            tableCalendar.clear();

                        if(calibChart)
                            calibChart.destroy();
                        // set modal title
                        $('#title-calib-auto strong').text(moment(event.start).format('DD MMMM YYYY').toUpperCase());
                        // retrieve auto calibrations for the clicked day
                        var jqxhr = $.ajax({
                            url: '/dat_tarature_aut_get_events_list',
                            type: "post",
                            data: {
                                date: moment(event.start).format('YYYY/MM/DD')
                            }
                        })
                        .done(function(result) {
                            var html= '';
                            console.dir(result);
                            // check result
                            if (result.res = 'OK'){
                                $('#full-auto-calib').modal();

                                $('#events-list').show();
                                // loop through all elements
                                // for each calibration, build a html row to be added to the table
                                $.each(result.events, function(index, value) {

                                    html += '<tr role="row">';
                                    html += '    <td><a href="#'+value.calibration_id+'" class="show-chart" data-original-title="Visualizza grafico" data-toggle="tooltip"><i class="mdi mdi-chart-areaspline text-info"></i></a></td>';
                                    html += '    <td>'+value.calibration_time+'</td>';
                                    html += '    <td>'+value.station_name+'</td>';
                                    html += '    <td>'+value.param_name+'</td>';
                                    html += '</tr>';

                                });

                                // add rows to datatable by using html object
                                tableCalendar.rows.add($( html ));
                                // redraw it
                                tableCalendar.draw();
                                // adjust columns size
                                tableCalendar.columns.adjust();
                            }
                            else{
                                // redraw it
                                tableCalendar.draw();
                                // error message
                                swal('Errore', 'Errore durante il recupero dei dati', 'error');
                            }

                            // re-initialize tooltip plugin
                            $('[data-toggle="tooltip"]').tooltip();
                            // at the end of the process hide preloader
                            $('.inner-preloader').hide();
                        })
                        .fail(function(xhr, err) {
                            tableCalendar.draw();
                            swal('Errore', 'Errore durante il recupero dei dati', 'error');
                            // at the end of the process hide preloader
                            $('.inner-preloader').hide();
                        });
                        break;
                    }
                default:
                    break;
            }
        }
    });

    calendar.render();

    // store html element of year's buttons
    prevYearButton = document.querySelector('.fc-myPrevYear-button');
    nextYearButton = document.querySelector('.fc-myNextYear-button');

    // datatable inside modal "MODAL DETTAGLIO TARATURA AUTOMATICA "
    $.fn.DataTable.ext.pager.numbers_length = 5;
    var tableCalendar = $('#daily-table').DataTable({
        // "dom": "Bfrtip",
        "dom": '<"row"<"col-6" B><"col-6 text-right"fr>>t<"row m-t-10"<"col-lg-12 col-sm-12 text-right"p>>',
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "pagingType": 'simple_numbers',
        "layout": {
            bottomEnd: {
                paging: {
                    buttons: 5,
                    type: 'simple_numbers'
                }
            }
        },
        "buttons": [],
        "bInfo": false,
        "columnDefs": [
            { "orderable": false, "targets": 0 }
        ],
        "order": [[ 1, "asc" ]]
    });

    // click on the single automatic calibration to view the graph
    $("#events-list").on( "click", "a", function(e) {
        e.preventDefault();

        // get time and calibration id
        var href = $(this).attr('href');
        var time = $(this).parent().next().text();
        var calibId = href.substring(1, href.length);

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        console.log(calibId);
        // retrieve data by an ajax call
        var jqxhr = $.ajax({
            url: '/dat_tarature_aut_get_chart',
            type: "post",
            data: {
                id: calibId
            }
        })
        .done(function(result) {
            console.dir(result);
            // check result
            if(result.res == 'OK'){
                // store data from server in local variables
                var metadata = result.metadata;
                var nParams = metadata.length;
                var data = result.data;

                // different type of charts based on number of pollutants
                if(nParams == 1){
                    createChart(metadata, data);
                }
                else{
                    createNCharts(metadata, data);
                }

                // set titles
                $('#events-chart strong:nth-child(1)').text(metadata[0].station_name);
                $('#events-chart strong:nth-child(2)').text(time);
                // show chart container
                $('#events-chart').show();
            }
            else{
                // error message
                swal('Errore', 'Errore durante il recupero dei dati', 'error');
            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();

        })
        .fail(function(xhr, err) {
            // error message
            swal('Errore', 'Errore durante il recupero dei dati', 'error');
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        });
    });

    // FUNCTIONS

    /**
     * Function that creates events for tickets and adds them to calendar.
     *
     * @param {array} tickets array of object.
     */
    function createTicketsEvents(tickets){
        // different type of events based on tickets type
        var corTickets   = [];
        var progTickets  = [];
        var otherTickets = [];

        // event date equal to ticket expiration
        var day = tickets[0].tk_expiry_date;

        // create a temporary variable where to store "PROGRAMMATI" tickets of the same day
        var tempArray = [];
        // loop through all ticket
        // for each ticket, build a specific event object and push it in the correct array
        tickets.forEach(function(ticket, indexTicket) {

            // create event object
            var event = {};

            // if the day changes or it's the end of the loop
            // create the cumulative event of the "PROGRAMMATI" tickets if present
            if(tempArray.length > 0 && day != ticket.tk_expiry_date){
                event.title = tempArray.length +' ticket <strong>PROGRAMMATI</strong>';
                event.allDay = 'false'; // this should be date object
                event.type = 'ticket';

                event.description = '<p>Elenco dei ticket programmati del giorno: <br>';
                event.description += '<ul>';
                // foreach ticket create a li element
                tempArray.forEach(function(el, idx) {
                    var liTxt = '    <strong><i class="'+el.tc_class+'"></i> '+el.recipient_comp_name.toUpperCase()+' '+el.tc_desc+'</strong>: ' +el.station_name;

                    if(el.equipment_name != '--')
                        liTxt += ' - '+ el.equipment_name;

                    if(el.tk_status == 'closed'){
                        liTxt = '<s>'+liTxt+'</s> <span class="cal-little text-danger"><i class="mdi mdi-alert-octagram"></i> chiuso il '+ moment(el.tk_status_date).format('DD MMMM YYYY [alle] HH:mm')+'</span>';
                    }

                    event.description += '<li>';
                    event.description += liTxt;
                    event.description += '</li>';
                });

                event.description += '</ul></p>';
                event.start = day;
                // push cumulative event in the array
                progTickets.push(event);

                // reset of the variables
                tempArray = [];
                event = {};
            }

            /*
            * check ticket type
            *   1   Correttivo
            *   2   Programmato
            *   3   Evolutivo
            *   4   Generale
            */
            if(ticket.tt_id == 2){
                // push in temporary variable
                tempArray.push(ticket);
                day = ticket.tk_expiry_date;

            }
            else{
                // create a single event with information retrieved from the server
                event.id = ticket.tk_id;
                event.title = '<strong><i class="'+ticket.tc_class+'"></i> '+ticket.recipient_comp_name.toUpperCase()+' '+ticket.tc_desc+'</strong>: ' +ticket.station_name;
                if(ticket.tk_status == 'closed'){
                     event.title = '<s>'+ event.title+'</s>';
                }
                event.allDay = 'false'; // this should be date object
                event.type = 'ticket';

                event.description = '<h5 class="text-info">Creato il <strong>'+ticket.tk_opening_date+'</strong></h5>';
                event.description += '<table class="table-compressed tbl-details"><tr><th>Aperto da:</th><td>'+ticket.us_fullname+'</td></tr>';
                event.description += '<tr><th>Titolo:</th><td>'+ticket.tk_title+'</td></tr>';
                event.description += '<tr><th>Oggetto:</th><td>'+ticket.equipment_name+'</td></tr>';
                event.description += '<tr><th>Scadenza:</th><td>'+moment(ticket.tk_expiry_date).format('DD MMMM YYYY')+'</td></tr>';
                // event.description += '<tr><th>Frequenza:</th><td>'+ticket.tf_desc+'</td></tr>';
                event.description += '<tr><th>Nota:</th><td>'+ticket.tk_opening_note+'</td></tr></table>';

                // check ticket status
                if(ticket.tk_status == 'closed'){
                    event.description += '<hr class="hr-dashed m-b-10">';
                    event.description += '<p class="text-danger"><i class="mdi mdi-alert-octagram"></i> <strong>Chiuso il</strong> '+moment(ticket.tk_status_date).format('DD MMMM YYYY [alle] HH:mm')+'</p>';
                    event.start = ticket.tk_status_date;
                }
                else
                    event.start = ticket.tk_expiry_date;
                // console.dir(event);

                // if "Correttivo" then push it in a specific array
                // otherwise push it in a collective array
                if(ticket.tt_id == 1){
                    // console.log('Push Correttivo');
                    corTickets.push(event);
                }
                else{
                    // console.log('Push Altro');
                    otherTickets.push(event);
                }
            }
        });

        // if it's the end of the loop
        // create the cumulative event of the "PROGRAMMATI" tickets if present
        if(tempArray.length > 0){
            event = {};
            event.title = tempArray.length +' ticket <strong>PROGRAMMATI</strong>';
            event.allDay = 'false'; // this should be date object
            event.type = 'ticket';


            event.description = '<p>Elenco dei ticket programmati del giorno: <br>';
            event.description += '<ul>';
            // for each ticket create a li element
            tempArray.forEach(function(el, idx) {
                var liTxt = '    <strong><i class="'+el.tc_class+'"></i> '+el.recipient_comp_name.toUpperCase()+' '+el.tc_desc+'</strong>: ' +el.station_name;

                if(el.equipment_name != '--')
                    liTxt += ' - '+ el.equipment_name;

                if(el.tk_status == 'closed'){
                    liTxt = '<s>'+liTxt+'</s>  <span class="cal-little text-danger"><i class="mdi mdi-alert-octagram"></i> chiuso il '+moment(el.tk_status_date).format('DD MMMM YYYY [alle] HH:mm')+'</span>';
                }

                event.description += '<li>';
                event.description += liTxt;
                event.description += '</li>';
            });

            event.description += '</ul></p>';
            event.start = day;
            // push cumulative event in the array
            progTickets.push(event);
        }

        // create different events sources for calendar
        // with specific colors
        var progSource = {
            events: progTickets,
            color: '#2293b5',
            borderColor: '#2293b5'
        };

        var corSource = {
            events: corTickets,
            color: '#dc5a08',
            borderColor: '#dc5a08'
        };

        var otherSource= {
            events: otherTickets,
            color: '#79a030',
            borderColor: '#79a030'
        };

        // add sources to calendar
        calendar.addEventSource(progSource);
        calendar.addEventSource(corSource);
        calendar.addEventSource(otherSource);
    };

    /**
     * Function that creates events for automatic calibrations and adds them to calendar.
     *
     * @param {array} calibs array of object.
     */
    function createAutoCalibsEvents(calibs){
        // create array variable
        var autoCalibrations = [];

        // loop through all calibrations
        // for each calibration, build a specific event object and push it in the array
        calibs.forEach(function(calib, index) {
            var event = {};
            event.title = calib.events_num +' tarature <strong>AUTOMATICHE</strong>';
            event.start = calib.events_date; // this should be date object
            event.allDay = 'false'; // this should be date object
            event.type = 'auto-calib';

            // console.dir(calib);
            autoCalibrations.push(event);
        });

        // create source for calendar with specific colors
        var autoSource= {
            events: autoCalibrations,
            // display: 'list-item',
            color: '#e8bb06',
            borderColor: '#e8bb06',
            className: 'dot-event'
        };

        // add source to calendar
        calendar.addEventSource(autoSource);
    };

    /**
     * Function that creates events for calibration reports and adds them to calendar.
     *
     * @param {array} reports array of object.
     */
    function createRepCalibsEvents(reports){
        // create array variable
        var repCalibrations = [];

        // temporary variable in order to build a cumulative event
        var tempArray = [];
        // get first calibration fulldate
        var day = reports[0].calib_fulldate;
        // loop through all calibrations
        // for each day, build a cumulative event object and push it in the array
        reports.forEach(function(report, idxRep) {

            var event = {};

            // if the current day is different from previous one
            // build the cumulative event
            if( day != report.calib_fulldate){

                event.title = tempArray.length +' report <strong>TARATURE</strong>';
                event.allDay = 'false'; // this should be date object
                event.type = 'rep';

                event.description = '<p>Elenco delle tarature del giorno: <br>';
                event.description += '<ul>';

                // for each stored report build a html li element
                // and add it to the list
                tempArray.forEach(function(el, idx) {
                    var desc = '<li>';
                    desc += '    <strong>['+el.calib_hour+'] '+el.station_name+' - '+el.instr_type_fullname+'</strong>: ' +el.user_fullname+' ('+el.company_name.toUpperCase()+')';
                    desc += '    <a href="/rep_qa_tarature/'+el.calib_id+'" target="_blank"><span class="badge badge-orange"><i class="ti-new-window"></i> dettaglio</span></a>';
                    desc += '</li>';

                    event.description += desc;
                });

                event.description += '</ul></p>';
                event.start = day;
                // push cumulative event in the array
                repCalibrations.push(event);

                // reset of variables
                tempArray = [];
                day = report.calib_fulldate;
                event = {};
            }

            // push report in temporary variable
            tempArray.push(report);

        });

        // at the end of the loop if temporary variable it's not empty
        // then build last cumulative event
        if( tempArray.length != 0){
            event = {};
            event.title = tempArray.length +' report <strong>TARATURE</strong>';
            event.allDay = 'false'; // this should be date object
            event.type = 'rep';

            event.description = '<p>Elenco delle tarature del giorno: <br>';
            event.description += '<ul>';

            // for each stored report build a html li element
            // and add it to the list
            tempArray.forEach(function(el, idx) {
                var desc = '<li>';
                desc += '    <strong>['+el.calib_hour+'] '+el.station_name+' - '+el.instr_type_fullname+'</strong>: ' +el.user_fullname+' ('+el.company_name.toUpperCase()+')';
                desc += '    <a href="/rep_qa_tarature/'+el.calib_id+'" target="_blank"><span class="badge badge-orange"><i class="ti-new-window"></i> dettaglio</span></a>';
                desc += '</li>';

                event.description += desc;
            });

            event.description += '</ul></p>';
            event.start = day;
            // push cumulative event in the array
            repCalibrations.push(event);
        }
        // create source for calendar with specific color
        var repSource= {
            events: repCalibrations,
            color: '#c70000',
            borderColor: '#c70000'
        };
        // add source to calendar
        calendar.addEventSource(repSource);
    };

    /**
     * Function that creates events for maintenance reports and adds them to calendar.
     *
     * @param {array} reports array of object.
     */
    function createRepMainEvents(reports){
        // create array variable
        var repMaintenances = [];

        // temporary variable in order to build a cumulative event
        var tempArray = [];
        // get the first maintenance fulldate
        var day = reports[0].maintenance_fulldate;
        // loop through all maintenances
        // for each day, build a cumulative event object and push it in the array
        reports.forEach(function(report, idxRep) {

            var event = {};
            // if the current day is different from previous one
            // build the cumulative event
            if( day != report.maintenance_fulldate ){
                event.title = tempArray.length +' report <strong>MANUTENZIONE</strong>';
                event.allDay = 'false'; // this should be date object
                event.type = 'rep';


                event.description = '<p>Elenco delle manutenzioni del giorno: <br>';
                event.description += '<ul>';

                // for each stored report build a html li element
                // and add it to the list
                tempArray.forEach(function(el, idx) {
                    var desc = '<li>';
                    desc += '    <strong>['+el.maintenance_hour+'] '+el.station_name+'</strong>: ' +el.user_fullname+' ('+el.company_name.toUpperCase()+')';

                    if(el.maintenance_calib_flag == true)
                        desc += ' <span class="badge badge-info"><i class="mdi mdi-attachment"></i> calibrazione </span>';

                    desc += '    <a href="/rep_qa_manutenzioni/'+el.ma_id+'" target="_blank"><span class="badge badge-orange"><i class="ti-new-window"></i> dettaglio</span></a>';
                    desc += '</li>';

                    event.description += desc;
                });

                event.description += '</ul></p>';
                event.start = day;

                // push cumulative event in the array
                repMaintenances.push(event);

                // reset of variables
                tempArray = [];
                day = report.maintenance_fulldate;
                event = {};
            }

            // push report in the temporary array
            tempArray.push(report);
        });

        // at the end of the loop if temporary variable it's not empty
        // then build last cumulative event
        if( tempArray.length != 0){
            event = {};
            event.title = tempArray.length +' report <strong>MANUTENZIONE</strong>';
            event.allDay = 'false'; // this should be date object
            event.type = 'rep';


            event.description = '<p>Elenco delle manutenzioni del giorno: <br>';
            event.description += '<ul>';

            // for each stored report build a html li element
            // and add it to the list
            tempArray.forEach(function(el, idx) {
                var desc = '<li>';
                desc += '    <strong>['+el.maintenance_hour+'] '+el.station_name+'</strong>: ' +el.user_fullname+' ('+el.company_name.toUpperCase()+')';

                if(el.maintenance_calib_flag == true)
                    desc += ' <span class="badge badge-info"><i class="mdi mdi-attachment"></i> calibrazione </span>';

                desc += '    <a href="/rep_qa_manutenzioni/'+el.ma_id+'" target="_blank"><span class="badge badge-orange"><i class="ti-new-window"></i> dettaglio</span></a>';
                desc += '</li>';

                event.description += desc;
            });

            event.description += '</ul></p>';
            event.start = day;
            // push cumulative event in the array
            repMaintenances.push(event);
        }

        // create source for calendar with specific color
        var repSource= {
            events: repMaintenances,
            color: '#c70000',
            borderColor: '#c70000'
        };

        // add source to calendar
        calendar.addEventSource(repSource);
    };

    /**
     * Function that creates events for inspection reports and adds them to calendar.
     *
     * @param {array} reports array of object.
     */
    function createRepInspEvents(reports){
        // create array variable
        var repInspections = [];

        // loop through all inspections
        // for each report build an event object and push it in the array
        reports.forEach(function(report, idxRep) {

            var event = {};

            event.title ='<i class="ti-location-pin"></i> Sopralluogo: <strong>'+report.municipality_format+'</strong>';
            event.allDay = 'false'; // this should be date object
            event.type = 'rep';

            var operators = '--';
            if(report.operators_name.length > 0)
                operators = report.operators_name.join(', ');

            event.description = '<h5 class="text-info">Creato il '+report.insp_fulldate_format+'</h5>';
            event.description += '<table class="table-compressed tbl-details"><tr><th>Creato da:</th><td>'+report.us_fullname+'</td></tr>';
            event.description += '<tr><th>Comune:</th><td>'+report.municipality_format+'</td></tr>';
            event.description += '<tr><th>Località:</th><td>'+report.insp_locality+'</td></tr>';
            event.description += '<tr><th>Partecipanti:</th><td>'+operators+'</td></tr>';
            event.description += '<tr><th>Nota:</th><td>'+report.insp_note+'</td></tr></table>';

            event.start = report.insp_fulldate;
            // push event in the array
            repInspections.push(event);

        });

        // create source for calendar with specific color
        var repSource= {
            events: repInspections,
            color: '#cb0b8f',
            borderColor: '#cb0b8f'
        };
        // add source to calendar
        calendar.addEventSource(repSource);
    };

    /**
     * Function that creates events for inspection reports and adds them to calendar.
     *
     * @param {array} metadata object with information of the pollutant.
     * @param {array} data array with pollutant data.
     */
    function createChart(metadata, data) {
        console.log('createChart');

        var step;
        var oldStep;
        var annotationPoints = [];

        // dynamically create data series
        var series = [];
        // loop through all data
        $.each(data, function (key, rec) {
            // get time in milliseconds
            var dtime = moment.utc(rec.calibration_date_time).valueOf();

            // build point (x, y) where:
            // x is the time in milliseconds
            // y is the value
            var dpoint = [dtime, parseFloat(rec.measure_value)];
            // push it in the series
            series.push(dpoint);

            // add annotations for the different steps of calibration
            // ZERO
            // SPAN
            // PURGE
            step = rec.calibration_step;
            // if current step not equal to the previous one
            // then create a new label
            if (oldStep != step){
                oldStep = step;
                var annotation = {
                    point :
                    {
                        x: dpoint[0],
                        y: dpoint[1],
                        xAxis: 0,
                        yAxis: 0
                    },
                    text : step
                };

                annotationPoints.push(annotation);
            }
        });

        annotationPoints[0].align = 'left';
        annotationPoints[1].align = 'right';

        // drawing single calibration chart
        calibChart = Highcharts.chart('chart-container', {
            credits: {
                enabled: false
            },
            title: {
                text: 'Grafico di '+ metadata[0].param_name
            },
            chart: {
                zoomType: 'x'
            },
            annotations: [{
                draggable: '',
                labelOptions: {
                    backgroundColor: 'rgba(255,255,255,0.5)',
                    shape: 'connector',
                },
                labels: annotationPoints
            }],
            xAxis: {
                title:'Time',
                type:'datetime',
                // ...
                labels: {
                    formatter: function() {
                        return Highcharts.dateFormat('%H:%M', moment(this.value));
                    }
                }
            },
            yAxis: { // Primary yAxis
                title: {
                    text: metadata[0].param_unit
                }
            },
            tooltip: {
                formatter: function() {
                    return '<span style="font-size: 10px">' +
                    Highcharts.dateFormat('%a, %e %b %Y. %H:%M', moment(this.x))
                    + '</span><br/>' + '<span style="color:' + this.series.color
                    + '">\u25CF</span> ' + this.series.name + ': <b>'
                    + this.y  + '</b><br/>';
                },
                yDecimals: 2,
                crosshairs: true,
            },
            plotOptions: {
                series: {
                    connectNulls: true,
                    color: '#2293b5',
                    marker: {
                        enabled: false
                    }
                }
            },
            series: [{
                name: metadata[0].param_name,
                data: series,
            }],
            exporting: {
                buttons: {
                    contextButton: {
                        menuItems: ['downloadJPEG', 'downloadCSV']
                    }
                }
            }
        });

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    };

    /**
     * Function that creates events for inspection reports and adds them to calendar.
     *
     * @param {array} metadata array with information of the pollutants.
     * @param {array} data array with pollutants data.
     */
    function createNCharts(metadata, data) {
        console.log('createNCharts');

        if(data && data.length > 0){
            var id = data[0].measure_id;
            var count = 0;

            var step;
            var oldStep;
            var series = [];
            var annotationPoints = [];
            var startPoint;

            // dynamically create N series
            series[0] = [];
            // loop through all data
            $.each(data, function (key, rec) {
                // get time in milliseconds
                var dtime = moment.utc(rec.calibration_date_time).valueOf();

                // build point (x, y) where:
                // x is the time in milliseconds
                // y is the value
                var dpoint = [dtime, parseFloat(rec.measure_value)];

                // if current measure id equal to previous one
                // then add point to the same series
                // else increase counter, initialize new series and push point in the new array
                if(rec.measure_id == id){

                    series[count].push(dpoint);
                    // add annotations only to the first series
                    if(count == 0){

                        // add annotations for the different steps of calibration
                        // ZERO
                        // SPAN
                        // PURGE
                        step = rec.calibration_step;
                        // if current step not equal to the previous one
                        // then create a new label
                        if (oldStep != step){
                            oldStep = step;
                            var annotation = {
                                point :
                                {
                                    x: dpoint[0],
                                    y: dpoint[1],
                                    xAxis: 0,
                                    yAxis: 0
                                },
                                text : step
                            };

                            annotationPoints.push(annotation);
                        }
                    }
                }
                else{
                    count++;
                    series[count] = [];

                    id = rec.measure_id;
                    series[count].push(dpoint);
                }
            });

            annotationPoints[0].align = 'left';
            annotationPoints[1].align = 'right';

            // drawing multiple calibrations chart
            calibChart = Highcharts.chart('chart-container', {
                credits: {
                    enabled: false
                },
                title: {
                    text: 'Grafico combinato'
                },
                chart: {
                    zoomType: 'x'
                },
                annotations: [{
                    draggable: '',
                    labelOptions: {
                        backgroundColor: 'rgba(255,255,255,0.5)',
                        shape: 'connector',
                    },
                    labels: annotationPoints
                }],
                xAxis: {
                    title:'Time',
                    type:'datetime',
                    labels: {
                        formatter: function() {
                            return Highcharts.dateFormat('%H:%M', moment(this.value));
                        }
                    }
                },
                yAxis: { // Primary yAxis
                    title: {
                            text: metadata[0].param_unit
                    }
                },
                tooltip: {
                    formatter: function() {
                        return '<span style="font-size: 10px">' +
                        Highcharts.dateFormat('%a, %e %b %Y. %H:%M', moment(this.x))
                        + '</span><br/>' + '<span style="color:' + this.series.color
                        + '">\u25CF</span> ' + this.series.name + ': <b>'
                        + this.y  + '</b><br/>';
                    },
                    yDecimals: 2,
                    crosshairs: true
                },
                plotOptions: {
                    series: {
                        connectNulls: true,
                        //cursor: 'pointer',
                        marker: {
                            enabled: false
                        }
                    }

                },
                exporting: {
                    buttons: {
                        contextButton: {
                            menuItems: ['downloadJPEG', 'downloadCSV']
                        }
                    }
                }
            });

            var colors = ['#79a030', '#dc5a08', '#e8bb06', '#2293b5', '#cb0b8f'];
            $.each(series, function (idx, el) {
                var options = {
                    name: metadata[idx].param_name,
                    data: series[idx],
                    color: colors[idx]
                };

                calibChart.addSeries(options, false);
                if(idx == series.length-1)
                    calibChart.redraw();
            });
        }
        else{
            swal('Attenzione', 'Nessun dato trovato!', 'warning');
        }

        // at the end of the process hide preloader
        $(".inner-preloader").hide();
    };
});
