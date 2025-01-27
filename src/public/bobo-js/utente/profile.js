/**
 * Document ready
 */
$(document).ready(function() {

    /**
     * Hide "Recover password" and display "Login" form again.
     */
    $(".toggle-password").click(function() {

        $(this).find("i").toggleClass("fa-eye fa-eye-slash");
        var input = $($(this).attr("toggle"));
        if (input.attr("type") == "password") {
            input.attr("type", "text");
        } else {
            input.attr("type", "password");
        }
    });

    // INITIALISTATION
    /////////////////////////////////////////////////////////////////////////

    // GLOBAL VARIABLES
    var myDropzone;
    var validator;
    var validatorPwd;

    /**
     * System route to update user data.
     */
    var url = "/usr_profile_put_user";

    // START Dropzone //

    /**
     * Dropzone object initialistation with all his features.
     */
    myDropzone = new Dropzone(".dropzone", {
        url: url,
        paramName: "file", // The name of the file param that gets transferred. Defaults to file
        uploadMultiple : false, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
        maxFiles: 1,
        acceptedFiles: "image/*",
        maxFilesize: 50, // MB
        addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
        clickable: true, // If true, the dropzone element itself will be clickable
        autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
        dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui una foto',
        dictResponseError: 'Caricamento fallito!',
        dictRemoveFile: 'Rimuovi file',
        dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
        dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti.',
        dictCancelUpload: 'Annulla caricamento',
        dictUploadCanceled: 'Il caricamento è stato annullato.',
        dictFileTooBig: 'La dimensione del file è superiore ai 15 MB.',
        dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
        // success: function(file, msg){},
        error: function(file, error) {
            swal("Errore", "Si è verificato un errore", "error");
        },
        maxfilesexceeded: function(file) {
            swal("Errore", "Hai raggiunto il massimo numero di file consentiti.", "error");
            this.removeFile(file);
        }
    });

    /**
     * Function called when using Dropzone submit.
     *
     * @param {object} file      Callback variable.
     * @param {object} xhr       Callback variable.
     * @param {object} formData  Object containing data to submit.
     */
    myDropzone.on("sending", function(file, xhr, formData) {

        var form = $('#form_user_mod');
        if (! form.valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Report non salvato!", "info");
            return false;
        };

        var formValues = form.serializeArray();
        $.each(formValues, function(index, input){
            formData.append(input.name, input.value);
        });
    });

    /**
     * Function called on Dropzone submit successfull return.
     *
     * @param {object}  file      Callback variable.
     * @param {boolean} response  Value indicating whether the submission was successful or not.
     */
    myDropzone.on("success", function(file, response) {

        var msgOk = 'L\'utente è stato modificato correttamente';
        var msgErr = 'Si è verificato un errore durante la modifica dell\'utente';

        if(response == true){
            swal("Successo", msgOk, "success");
            clearFields();
            fillUserProfile();
            $('.profile-tab a[href="#prof"]').tab('show');

        }
        else{
            swal("Errore!", msgErr, "error");
            file.previewElement.classList.add("dz-error");
            file.status = Dropzone.QUEUED;
        }
    });

    // END Dropzone //

    // FORM FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * User edit form validation checking required and email fields.
     */
    validator = $('#form_user_mod').validate({ // initialize the plugin
        rules: {
            "mod-user-name" : {
                required: true
            },
            "mod-user-surname" : {
                required: true
            },
            "mod-user-mobile":{
                regex: '^([+][0-9]{2}(\-|\\s)?)?[0-9]{1,10}$'
            },
            "mod-user-email" : {
                required: true,
                email: true
            }
        },
        messages: {
            "mod-user-name" : {
                required: "Nome utente obbligatorio"
            },
            "mod-user-surname" : {
                required: "Cognome utente obbligatorio"
            },
            "mod-user-mobile":{
                regex: "Inserire un numero di cellulare valido (+39 XXX)"
            },
            "mod-user-email" : {
                required: "Email utente obbligatorio",
                email: "Inserire email valida"
            }
        },
        ignore: "",
    });

    // https://stackoverflow.com/a/21456918
    // Minimum eight characters, at least one letter and one number:
    // "^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d]{8,}$"
    // Minimum eight characters, at least one letter, one number and one special character:
    // "^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$"
    // Minimum eight characters, at least one uppercase letter, one lowercase letter and one number:
    // "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)[a-zA-Z\d]{8,}$"
    // Minimum eight characters, at least one uppercase letter, one lowercase letter, one number and one special character:
    // "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$"
    // Minimum eight and maximum 10 characters, at least one uppercase letter, one lowercase letter, one number and one special character:
    // "^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,10}$"

    /**
     * Validation method: check field by regular expression.
     *
     * @param {string}       value User insert value.
     * @param {html_element} element HTML element containig the value.
     * @param {boolean}      flag Boolean value indicating if the field has to be a valid password.
     *
     * @return If TRUE, the value;
     *         If FALSE, the alert message.
     */
    $.validator.addMethod(
        "validPwd",
        function(value, element, flag) {
            var re = new RegExp(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/);
            return this.optional(element) || re.test(value);
        },
        "Inserire una password valida (min. 8 caratteri, almeno una lettera maiuscola e minuscola, almeno un numero e un carattere speciale tra @$!%*?& )"
    );

    /**
     * Password edit form validation checking required and equals fields.
     */
    validatorPwd = $('#form_pwd_mod').validate({
        errorPlacement: function(error, element) {
            if(element.parent('.input-group').length) {
                error.insertAfter(element.parent());
            } else {
                error.insertAfter(element);
            }
        },
        rules: {
            "mod-password": {
                required: true,
                validPwd : true
            },
            "mod-repeat-password": {
                equalTo: "#mod-password"
            }
        },
        messages: {
            "mod-password": {
                required: "Devi introdurre una password"
            },
            "mod-repeat-password": {
                equalTo: "La password deve essere uguale alla precedente"
            }
        },
        ignore: ""
    });

    /**
     * Submit the user data modification form.
     */
    $('#form_user_mod').on('submit', function (e) {
        var form = $("#form_user_mod");
        var msgErr = 'Si è verificato un errore durante la modifica dell\'utente';
        var msgOk = 'L\'utente è stato modificato correttamente';

        // check images presence:
        // yes  -> use of Dropzone's submit function and append form fields
        // no   -> use of default submit function
        if (myDropzone.getQueuedFiles().length > 0) {
            myDropzone.processQueue();
        }
        else {

            console.log("Invio normale");
            if (! $(this).valid() ){
                swal("Attenzione", "Sono presenti dei campi obbligatori non compilati", "info");
                return false;
            };

            $.ajax({
                type: 'post',
                url: '/usr_profile_put_user',
                data: form.serialize()
            }).done(function(result) {

                if(result){
                    swal("Successo", msgOk, "success");
                    clearFields();
                    fillUserProfile();
                    $('.profile-tab a[href="#prof"]').tab('show');
                }
                else
                    swal("Errore!", msgErr, "error");

            })
            .fail(function(xhr, err) {
                swal("Errore!", msgErr, "error");

            });
        }

        e.preventDefault();

    });

    /**
     * Submit the password modification form.
     */
    $('#form_pwd_mod').on('submit', function (e) {
        var form = $("#form_pwd_mod");
        var id = $("#mod-pwd-id").val();

        var msgErr = 'Si è verificato un errore durante la modifica della password!';
        var msgOk = 'La password è stata modificata correttamente, inseriscila al prossimo accesso.';

        console.log("Invio normale");
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi obbligatori non compilati", "info");
            return false;
        };

        $.ajax({
            type: 'post',
            url: '/usr_profile_put_password',
            data: form.serialize()
        }).done(function(result) {

            if(result){
                swal("Successo", msgOk, "success");
                clearFields();
                fillUserProfile();
                $('.profile-tab a[href="#prof"]').tab('show');
            }
            else
                swal("Errore!", msgErr, "error");

        })
        .fail(function(xhr, err) {
            swal("Errore!", msgErr, "error");

        });

        e.preventDefault();

    });

    /**
     * Cancel user changes (by clicking the 'Annulla' button) and show again the first page tab
     */
    $('#profile').on('click', '#cancel-user-profile, #cancel-user-pwd', function(e){
        e.preventDefault();

        clearFields();
        fillUserProfile();
        $('.profile-tab a[href="#prof"]').tab('show');
    });

    /////////////////////////////////////////////////////////////////////
    // END FORM FUNCTIONS

    clearFields();
    fillUserProfile();

    // FUNCTIONS
    /////////////////////////////////////////////////////////////////////

    /**
     * Function that clear all form's fields.
     */
    function clearFields(){
        $('.clear-txt').html('');
        $('.clear-form').val('');

        validator.resetForm(); // reset form error (USER)
        validatorPwd.resetForm(); // reset form error (PASSWORD)
    }

    /**
     * Function that get user informations and fill the form.
     */
    function fillUserProfile(){

        console.log('ajax');
        var jqxhr = $.ajax({
            url: 'usr_profile_get_user_byid',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            console.dir(result);
            var user = result.user;
            var company = result.comp;

            $('#mod-user-id').val(user.user_id);
            $('#mod-pwd-id').val(user.user_id);

            $('.view-name').html(user.user_name);
            $('#mod-user-name').val(user.user_name);

            $('.view-secondname').html(user.user_second_name);
            $('#mod-user-secondname').val(user.user_second_name);

            $('.view-surname').html(user.user_surname);
            $('#mod-user-surname').val(user.user_surname);

            $('.view-role').html(user.user_role);
            $('#mod-user-role').val(user.user_role);

            $('.view-smartphone').html(user.user_mobile);
            $('#mod-user-mobile').val(user.user_mobile);

            $('.view-phone').html(user.user_phone);
            $('#mod-user-phone').val(user.user_phone);

            $('.view-email').html(user.user_email);
            $('#mod-user-email').val(user.user_email);

            $('.view-img-profile').html('<img src="'+user.user_avatar_thumb+'" class="img-circle" />');
            $('.view-img-company').html('<img src="'+company.comp_logo+'" />');

            $('.view-session').html(user.user_expiration_time_text);
            $('#mod-user-session').val(user.user_expiration_time);

            $('.view-company').html(company.comp_name);
            $('.view-company-address').html(company.comp_address);
            $('.view-company-phone').html(company.comp_phone);
            $('.view-company-site').html('<a href="'+company.comp_web+'" target="_blank">'+company.comp_web+'</a>');
            $('.view-company-email').html(company.comp_email);
            $('.view-company-description').html(company.comp_desc);
        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il recupero del dettaglio dell'utente", "error");
        });
    }


});

