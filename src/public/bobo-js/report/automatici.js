/**
 * Document ready
 */
$(document).ready(function() {

    ///////////// TAB SIRAL /////////////
    var siralResults;

    // date picker initialization
    $('#siral-date').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        time: false,
        cancelText : 'Annulla'
    });
    // setting "today" as default date
    $('#siral-date').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));

    // json editor initialization
    var container = document.getElementById('jsoneditor-result');
    var options = {
        mode: 'view',
        modes: [],
        search: false,
        indentation: 4,
        name: 'Risultato',
        navigationBar: false,
        language: 'it',
        languages: jsonEditorlang
    };
    var resultEditor = new JSONEditor(container, options);

    /**
     * Change event on datepicker event
     */
    $('#siral-date').on('change', function(e){

        // get new selected date
        var from = moment( $(this).val(), 'DD/MM/YYYY').format('YYYY-MM-DD');
        // refresh metadata
        loadWsStatus('siral', from);
    });

    /**
     * Click event on "Aggiorna" button to update data table by selected date
     */
    $('#siral-table').on('click', '.view-result', function(e){
        e.preventDefault();

        // get row ID stored inside the html
        var counter = parseInt($(this).parent().parent().data('id'));
        // expand json result inside the modal
        resultEditor.set(JSON.parse(siralResults[counter]));
        resultEditor.expandAll();
    });

    /**
     * Click event on "Aggiorna" button to update data table by selected date
     */
    $('#siral-update').on('click', function (e) {
        e.preventDefault();

        // get selected date
        var from = moment($("#siral-date").val(), 'DD/MM/YYYY').format('YYYY-MM-DD');
        // refresh data
        loadWsStatus('siral', from);
    });

    // trigger chane in order
    $('#siral-date').trigger('change');

    ///////////// TAB AER NOSTRUM /////////////

    // variable for loadWsStatus function
    var dateTo = moment().format('YYYY-MM-DD 23:59:59');
    var dateFrom = moment(dateTo).subtract(1, 'week').format('YYYY-MM-DD');

    // variable for datepicker plugin (different format)
    var start = moment(dateFrom).format("DD/MM/YYYY");
    var end = moment(dateTo).format("DD/MM/YYYY");

    // Daterange picker initialization
    $('.input-daterange-datepicker').daterangepicker({
        startDate: start,
        endDate: end,
        maxDate: end,
        buttonClasses: ['btn', 'btn-sm'],
        applyClass: 'btn-danger',
        cancelClass: 'btn-inverse',
        locale: dateRangePickerSettings.locale
    }, function(start, end, label) {

        //on change event, get status within new daterange
        console.log(start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD'), label);
        dateFrom = start.format('YYYY-MM-DD');
        dateTo = end.format('YYYY-MM-DD 23:59:59');
        // refresh data
        loadWsStatus('aer', dateFrom, dateTo);
    });

    // load webservice status
    loadWsStatus('aer', dateFrom, dateTo);

    /**
     * Function that retrieves Webservice status of a given type
     *
     * @param {text} type: webservice type
     * @param {date} from: Start of range
     * @param {date} to: End of range
     */
    function loadWsStatus(type, from, to){

        // reset tab taking care of request type
        switch(type){
            case 'siral':
                siralResults = [];
                $('#siral-table tbody').empty();
                break;
            case 'aer':
                $('#aer-nostrum-table tbody').empty();
                break;
            default:
                break;
        }

        // show preloader, waiting for the end of the process
        $(".inner-preloader").show();
        // get metadata from server via ajax call
        var jqxhr = $.ajax({
            url: '/rep_automatici_get_ws_status',
            type: "post",
            dataType: "json",
            data: {
                type: type,
                from: from,
                to: to
            },
        })
        .done(function(result) {

            // check result
            // if OK then fill tab with retrieved metadata
            if(result.res == 'OK'){

                var status = result.status;
                // check if there is at least one result
                if( status.length > 0 ){
                    // variable for dinamically building the html
                    var html= '';
                    // different rows based on results type
                    switch(type){
                        case 'siral':
                            // loop through all elements
                            // for each status, build a html row to be added to the datable
                            $.each(status, function(index, el) {
                                html += '<tr data-id="'+el.counter+'">';
                                html += '    <td class="bobo-nowrap">'+el.execution_ts_format+'</td>';
                                html += '    <td>'+el.command+'</td>';
                                html += el.formatted_result
                                html += '    <td>'+el.mode+'</td>';
                                html += '    <td>'+el.formatted_sending_res+'</td>';
                                html += '    <td>'+el.formatted_process_res+'</td>';
                                html += '</tr>';

                                siralResults[el.counter] = el.process_res;
                            });
                            // append html to table
                            $('#siral-table tbody').append(html);
                            break;
                        case 'aer':
                            // loop through all elements
                            // for each status, build a html row to be added to the datable
                            $.each(status, function(index, el) {
                                html += '<tr>';
                                html += '    <td>'+el.date_result+'</td>';

                                var results = JSON.parse(el.obj_results);

                                $.each(results, function(index, res) {
                                    html += res.formatted_result;
                                });

                                html += '</tr>';
                            });
                            // append html to table
                            $('#aer-nostrum-table tbody').append(html);
                            break;
                        default:
                            break;
                    }
                }

                // re-initialize tooltip plugin
                $('[data-toggle-second="tooltip"]').tooltip();

            }
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $(".inner-preloader").hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }
});

