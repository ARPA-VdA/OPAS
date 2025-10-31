/**
 * Document ready
 */
$(document).ready(function() {

    var day = moment().subtract(1, 'day').format('YYYY-MM-DD');
    $('#selected-day').text(moment().subtract(1, 'day').format('DD MMMM YYYY'));

    // Daterange pickers initialization
    // https://miamarti.github.io/Material-DateTimePicker/app/
    // https://github.com/miamarti/Material-DateTimePicker
    $('#datepicker').bootstrapMaterialDatePicker({
        maxDate: moment().subtract(1, 'day').format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        cancelText : 'Annulla',
        time: false
    }).on('change', function(e, date) {

        // get the date, skip the one passed, not correct when set manually
        date = $('#datepicker').val();
        // set label
        $('#selected-day').text(date.format('DD MMMM YYYY'));
        // get day for images
        day = moment(date, "DD/MM/YYYY").format('YYYY-MM-DD');
        // load data & image
        loadData(day);
    });
    // set default date
    $('#datepicker').bootstrapMaterialDatePicker('setDate', moment().subtract(1, 'day').format("DD/MM/YYYY"));

    /**
     * Click event on - button
     */ 
    $('#elements').on('click', '#btn-minus', function(e){
        e.preventDefault();

        // get selected date
        var currDate = $('#datepicker').val();
        // create moment object
        var newDate = moment(currDate, "DD/MM/YYYY").subtract(1, 'day');
        // update global variable
        day = newDate.format('YYYY-MM-DD');

        // clear
        $('#datepicker').val('');
        // set new date
        $('#datepicker').bootstrapMaterialDatePicker('setDate', newDate);
        // trigger change in order to refresh data
        $('#datepicker').trigger('change');

        // update label
        $('#selected-day').text(newDate.format('DD MMMM YYYY'));
        // enable + button
        $("#btn-plus").removeClass("as-btn-disabled");
    });

    /**
     * Click event on + button
     */ 
    $('#elements').on('click', '#btn-plus', function(e){
        e.preventDefault();

        // check is button is enable
        if(!$(this).hasClass("as-btn-disabled")){
            
            // get selected date
            var currDate = $('#datepicker').val();
            // add a day
            var newDate = moment(currDate, "DD/MM/YYYY").add(1, 'day');

            // update global variable
            day = newDate.format('YYYY-MM-DD');

            // clear
            $('#datepicker').val('');
            // set new date
            $('#datepicker').bootstrapMaterialDatePicker('setDate', newDate);
            // trigger change in order to refresh data
            $('#datepicker').trigger('change'); 

            // update label
            $('#selected-day').text(newDate.format('DD MMMM YYYY'));

            // if the newDate is equal to yesterday then disable + button
            var yesterday = moment().subtract(1, 'day');
            if (newDate.isSame(yesterday, 'day')){
                $("#btn-plus").addClass("as-btn-disabled");
            }
            else{
                $("#btn-plus").removeClass("as-btn-disabled");
            }
        }

    });

    // first run
    loadData(day);

    // UTILITIES
    /**
     * Function that formats a string, checking if it's null.
     *
     * @param {string} field String provided to format.
     *
     * @return If null then returns string '--';
     *         If not null then returns the string provided before.
     */
    function formatTextField(field) {
        if(field == null)
            return '--';
        else
            return field;
    };

    /**
     * Function that retrieves data from server
     *
     * @param {string} day Selected date
     */
    function loadData(day){

        // reset datatable
        $('#list-table tbody').empty()

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // get data via an ajax call
        var jqxhr = $.ajax({
            url: '/dat_horiba_get_images',
            type: "post",
            dataType: "json",
            data: {
                date: day
            },
        })
        .done(function(result) {

            // check result
            // - if OK then fill table 
            // - else show error message
            if(result.res == 'OK'){

                var images = result.images;
                var indexes = result.images_idx;
                var data = result.data;
                // variable for dinamically building the html
                var html = '';

                // loop through all elements
                // for each element, build a html row to be added to the datable
                data.forEach(function(el,idx){

                    html += '<tr>';
                    html += '    <th>'+el.param_name+'</th>';
                    html += '    <td>'+formatTextField(el.fld1)+' '+el.param_unit+'</td>';
                    html += '    <td>'+formatTextField(el.fld2)+' '+el.param_unit+'</td>';
                    html += '    <td>'+formatTextField(el.fld3)+' '+el.param_unit+'</td>';
                    html += '    <td>'+formatTextField(el.fld4)+' '+el.param_unit+'</td>';
                    html += '</tr>';

                });

                // append new row
                $('#list-table tbody').append(html);
                // create row for images and append it
                html = '<tr class="report-gallery-one" id="img-row">';
                html += '    <th class="align-middle">Immagine</th>';
                html += '    <td>N.d.</td>';
                html += '    <td>N.d.</td>';
                html += '    <td>N.d.</td>';
                html += '    <td>N.d.</td>';
                html += '</tr>';
                $("#list-table tr:eq(1)").after(html);

                // take care of images
                images.forEach(function(el, c){
                    console.dir(el);
                    var i = indexes[c];
                    $('#img-row td:eq('+i+')').html('<a class="clearfix thumb-gallery" href="'+el+'"><img src="'+el+'">');
                });

                // crerate gallery
                $(".report-gallery-one").magnificPopup({
                    delegate: 'a', // the selector for gallery item
                    type: 'image',
                    gallery: {
                        enabled:true
                    }
                });
            }
            else{
                // error message
                swal("Errore!", "Errore durante il recupero dei dati", "error");
            }

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
        })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante il recupero dei dati", "error");
        });
    }
});


