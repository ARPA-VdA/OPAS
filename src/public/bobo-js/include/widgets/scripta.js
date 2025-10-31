/**
 * Document ready
 */
$(document).ready(function() {
    
    /**
     * Click event on button "Esegui SCRIPTA"
     */
    $('#homepage').on('click', '#scripta-run', function(e){
        e.preventDefault();

        // confirm message in order to continue with the script
        swal({
            title: "Esecuzione del programma SCRIPTA",
            text: "Sei sicuro di voler proseguire in questa operazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, ESEGUI",
            cancelButtonText: "Annulla",
            closeOnConfirm: false,
            showLoaderOnConfirm: true
        }, function () {
            // reset textarea
            $('textarea#scripta-log').empty();
            // run scripta script
            $.ajax({
                url: '/custom_vda_scripta',
                type: "get",
                dataType: "json"
            })
            .done(function(result) {
                // check result
                if(result){
                    // success message
                    swal("Esecuzione SCRIPTA", "L'esecuzione del programma è andato a buon fine, leggi il log dello script nel box qui sotto", "success");
                    // add log
                    $('textarea#scripta-log').append(result.content);
                }
                else{
                    // error message
                    swal("Errore!", "Errore durante l'esecuzione dello script", "error");
                }
            })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Errore durante l'esecuzione dello script", "error");
            });
        });
    });
});