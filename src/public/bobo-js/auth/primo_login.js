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

    /**
     * Hide preloader.
     */
    $(".preloader").fadeOut();

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
     * Change password form metadata validation.
     */
    var validator = $('#change-pass-form').validate({ // initialize the plugin
        errorPlacement: function(error, element) {
            if(element.parent('.input-group').length) {
                error.insertAfter(element.parent());
            } else {
                error.insertAfter(element);
            }
        },
        rules: {
            "new_password": {
                required: true,
                validPwd : true
            },
            "second_password": {
                equalTo: "#new_password"
            }
        },
        messages: {
            "new_password": {
                required: "Devi introdurre una password",
            },
            "second_password": {
                equalTo: "La password deve essere uguale alla precedente"
            }
        },
        ignore: ""
    });

});