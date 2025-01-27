/**
 * Document ready
 */
$(document).ready(function() {

// IMPOSTAZIONI PORTALE
{
    // plugin initialization
    $(".cod-active" ).bootstrapToggle();
    // multiselect initialization
    $('#multiselect1').multiselect({
        right: '#validation-params',
        submitAllLeft: false,
        ignoreDisabled: true,
        keepRenderingSort: true,
        search: {
            left: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
            right: '<input type="text" name="q" class="form-control" placeholder="Cerca..." />',
        },
        fireSearch: function(value) {
            return true;
        }
    });

    $('#data-conclusion').bootstrapMaterialDatePicker({
        maxDate: moment().format("DD/MM/YYYY"),
        format: 'DD/MM/YYYY',
        lang : 'it',
        time: false,
        cancelText : 'Annulla'
    });
    // $('#data-conclusion').bootstrapMaterialDatePicker('setDate', moment().format('DD/MM/YYYY'));


    /*
    * change event on bootstrapToggle in table with validation codes
    */
    $('#table-val-codes').on('change', '.cod-active', function(){
        // get element's parent
        var parent = $(this).parent().parent().parent();

        // if checkbox is checked then enable row and show code colour
        // else disable row
        if($(this).is(":checked")){
            // console.log('acceso');
            $(parent).find( ".valid-level" ).removeClass("dis");
            $(parent).find( 'input[name="cod-txt"]' ).attr("disabled", false);
        }else{
            // console.log('spento');
            $(parent).find( ".valid-level" ).addClass("dis");
            $(parent).find( 'input[name="cod-txt"]' ).attr("disabled", true);
        }
    });

    /*
    * click event on "Save" button
    */
    $('#save-code').on('click', function(e){
        e.preventDefault();

        // check validity of all form fields
        var valid = true;
        $('#table-val-codes tr input[name="cod-active"]:checked').each(function(){
            var parent = $(this).parent().parent().parent();
            // get label
            var label = $(parent).find('input[name="cod-txt"]').val();
            if(label.trim() == '')
                valid = false;
        });

        // if form isn't valid then show warning message and return
        if(!valid){
            swal({
                title: "Attenzione",
                text: "Sono presenti dei codici abilitati <strong>privi di un'etichetta</strong>.<br>Completare tutti i campi!",
                type: "info",
                html: true
            });
            return;
        }

        // create array variable
        var codesArray = [];

        // loop through all enabled elements in codes table
        // for each row create an object storing label and code
        $('#table-val-codes tr input[name="cod-active"]:checked').each(function(){

            var parent = $(this).parent().parent().parent();
            // get code value from element id
            var id     = $(parent).find('input[name="cod-txt"]').attr('id');
            var res = id.split('-');
            var cod = parseInt(res[2]);
            // get selected label
            var label = $(parent).find('input[name="cod-txt"]').val();

            // build object
            var obj = {
                label: label.trim(),
                value: cod
            };
            // push object in the array
            codesArray.push(obj);
        });

        // create array variable
        var paramsArray = [];
        // loop through all selected parameters
        // for each parameter build an object with a label and the value of parameter id
        $('#validation-params').find('option').each(function(){
            var obj = {
                label: $(this).text().replace(/ \[.*\]/g, ''),
                value: parseInt($(this).val())
            };
            // push object in the array
            paramsArray.push(obj);
        });

        // create a container object
        var totalObj = {
            codes: codesArray,
            params: paramsArray,
            closure: $('#data-conclusion').val() == '' ? null : moment($('#data-conclusion').val(), 'DD/MM/YYYY').format('YYYY-MM-DD'),
            reset: $('#validation-reset').is(':checked')
        };

        // console.dir(totalObj);

        // ajax call
        var jqxhr = $.ajax({
            url: '/usr_admin_put_validation_options',
            type: "post",
            dataType: "json",
            data: {
                obj: JSON.stringify(totalObj)
            }
        })
        .done(function(result) {
            // check result
            // if TRUE then show success message and trigger change in "other" tab
            // in order to refresh the list of available codes
            if(result){
                swal('Successo!', 'Le impostazioni sono state salvate correttamente', 'success');

                $("#filter-group-other").trigger('change');
            }
        })
        .fail(function(xhr, err) {
            // error message
            swal("Errore!", "Errore durante l'aggiornamento delle impostazioni", "error");
        });
    });

    // disable bootstrap toggle for the first and the last code
    $('#cod-active-1, #cod-active-8').prop('disabled', true );
    // change checked property for the other codes
    $('#cod-active-2, #cod-active-4').prop('checked' , false).trigger('change');

    // load portal options and fill form
    loadPortalOptions();
}

    /**
     * Function that retrieves portal options
     */
    function loadPortalOptions(){
        console.log('ajax');
        var jqxhr = $.ajax({
            url: '/usr_admin_get_portal_options',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            console.dir(result);
            // check result
            // if OK then fill validation form
            if(result.res == 'OK' && result.validation){
                fillValidation(JSON.parse(result.validation));
            }
        })
        .fail(function(xhr, err) {
        });
    }

    /**
     * Function that fill validation form
     *
     * @param {obj} obj Object returned by the ajax call
     */
    function fillValidation(obj){
        console.dir(obj);
        // if object is not defined then exit
        if(obj == null)
            return;

        // if the object containing codes is defined
        // then fill codes table and set checked properties
        // else do nothing
        if(obj.codes != null ){

            var codes = obj.codes;

            var html = '';
            codes.forEach(function(el, idx){
                $('#cod-active-'+el.value).prop('checked', true).trigger('change');
                $('#cod-txt-'+el.value).val(el.label);
            });
        }

        // if the object containing parameters is defined
        // then fill parameters multiselect
        // else do nothing
        if(obj.params != null){
            var params = obj.params;
            var paramsArray = [];
            // create a temporary array with only the parameters id
            params.forEach(function(el){
                paramsArray.push(el.value);
            });
            // select them
            $('#multiselect1').val(paramsArray);
            $('#multiselect1_rightSelected').trigger('click');
        }

        if(obj.closure && obj.closure != ''){
            $('#data-conclusion').bootstrapMaterialDatePicker('setDate', moment(obj.closure).format('DD/MM/YYYY'));
            $('#data-conclusion').val(moment(obj.closure).format('DD/MM/YYYY'));
        }

        $('#validation-reset').prop('checked', obj.reset).trigger('change');
    }
});