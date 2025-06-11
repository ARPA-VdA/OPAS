/**
 * Document ready
 */
$(document).ready(function() {
    // plugin initialization
    $("#maintenance-active" ).bootstrapToggle();

    $('#maintenance-start, #maintenance-end').bootstrapMaterialDatePicker({
        minDate: moment().format("DD/MM/YYYY HH:mm"),
        format: 'DD/MM/YYYY HH:mm',
        lang : 'it',
        cancelText : 'Annulla'
    }).on('change', function(){

        // programatically enable toggle
        if($(this).val() != '')
            $("#maintenance-active").prop('checked', true).trigger('change');

        if ($(this).attr('id') == 'maintenance-start'){
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
    $('#cancel-maintenance').on('click', function(e) {
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
                if ( Object.keys(obj).length !== 0 ) {
                    // fill form with options set by system admin
                    $("#maintenance-active").prop('checked', obj.maintenance).trigger('change');
                    $("#maintenance-start").val(obj.maintenance_start);
                    $("#maintenance-end").val(obj.maintenance_end);

                    // if maintenance is true then show a recap message
                    if (obj.maintenance == true ){
                        html += '<div class="light-bg">';
                        html += '    <h4 class="text-info"><strong>Attenzione!</strong> Hai programmato una manutenzione del portale</h4>';
                        html += '    <hr class="m-t-0 m-b-20">';
                        html += '    <h5 class="m-t-10 text-primary"><i class="fa-solid fa-square-check text-success"></i> Sistema <strong>in manutenzione</strong></h5>';
                        html += '    <div class="m-t-10">Data/ora inizio: <strong>' + ( obj.maintenance_start ? obj.maintenance_start : 'non specificata' ) +'</strong></div>';
                        html += '    <div class="m-t-10">Data/ora fine: <strong>' + (obj.maintenance_end ? obj.maintenance_end : 'non specificata') +'</strong></div>';
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

});
