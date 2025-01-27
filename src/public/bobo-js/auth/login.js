/**
 * Document ready
 */
$(document).ready(function() {

    $(".preloader").fadeOut();
    $('[data-toggle="tooltip"]').tooltip();

    /**
     * Display "Recover password" form.
     */
    $('#to-recover').on("click", function() {
        $("#login-form").slideUp();
        $("#recover-form").fadeIn();
    });

    /**
     * Hide "Recover password" and display "Login" form again.
     */
    $('#back-login').on("click", function() {
        $("#recover-form").fadeOut();
        $("#login-form").slideDown();
    });

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
     * 'Login' form metadata validation.
     */
    var validator = $('#login-form').validate({ // initialize the plugin
        rules: {
            "login_mail": {
                required: true
            },
            "login_password": {
                required: true
            }
        },
        messages: {
            "login_mail": {
                required: "Devi introdurre un indirizzo email",
            },
            "login_password": {
                required: "Devi introdurre una password"
            }
        },
        ignore: ""
    });

    /**
     * Password validation.
     */
    var validatorGetPwd = $('#recover-form').validate({ // initialize the plugin
        rules: {
            "recover_email": {
                required: true
            }
        },
        messages: {
            "recover_email": {
                required: "Devi introdurre un indirizzo email",
            }
        },
        ignore: ""
    });

});