$(document).ready(function() {
    // GLOBAL VARIABLES
    var myDropzone;

    // widget links
    // https://api.jqueryui.com/sortable/
    $( "#sortable" ).sortable({
        update: function( event, ui ) {
            updateUserLinks(false);
        }
    });
    $( "#sortable" ).disableSelection();

    $( window ).resize(function() {
        console.log("window resize");
        resizeHomepage();
    });

    $('#link-url').select2({
        tags: true,
        createTag: function (params) {
            var term = $.trim(params.term);

            if (term === '') {
              return null;
            }

            console.log(term);
            return {
              id: '',
              text: term,
              newTag: true
            }
        }
    });

    $('#link-url').on('change', function(e){

        var name = $(this).find('option:selected').data('name');
        if( name != null){
            $('#link-ttl').val(name);
            $('#link-ttl').prop('disabled', true);
        }
        else{
            $('#link-ttl').val('');
            $('#link-ttl').prop('disabled', false);
        }
    });

    $('.bobo-sortable li>a>i').hide();
    $('.bobo-sortable-img li>a>i').hide();
    $('#add-my-link').hide();

    $('.link-top').on('click', '.bobo-sortable a>i', function(e){
        e.preventDefault();
        var el = $(this).parent().parent();

        swal({
            title: "Eliminare il link",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            el.remove();
            updateUserLinks(false);
            swal("Link eliminato", "Il link è stato eliminato con successo!", "success");
        });
    });

    $('.link-bottom').on('click', '.bobo-sortable-img a>i', function(e){
        e.preventDefault();
        var el = $(this).parent().parent();

        swal({
            title: "Eliminare il banner",
            text: "Sei proprio sicuro di voler proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Si, elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {

            swal("Banner eliminato", "Il banner è stato eliminato con successo!", "success");
            el.remove();

        });
    });

    $('.link-top').on('mouseenter', '.bobo-sortable a', function(e){
        e.preventDefault();
        $(this).children().show();
    });

    $('.link-top').on('mouseleave', '.bobo-sortable a', function(e){
        e.preventDefault();
        $('.bobo-sortable li>a>i').hide();
    });

    $('.link-bottom').on('mouseenter', '.bobo-sortable-img a', function(e){
        e.preventDefault();
        $(this).children().show();
    });

    $('.link-bottom').on('mouseleave', '.bobo-sortable-img a', function(e){
        e.preventDefault();
        $('.bobo-sortable-img li>a>i').hide();
    });

    $('.card').on('click', '.add-link', function(e){
        e.preventDefault();

        $('#add-my-link').show();
    });

    $('.card').on('click', '#cancel-link-form', function(e){
        e.preventDefault();

        clearFields();
        $('#add-my-link').hide();
    });

    $('.ckb-banner').bootstrapToggle();

    $('#add-my-banner').hide();

    // change visibilità
    $(".ckb-banner" ).on( "change", function() {
        var status = $(".ckb-banner" ).prop('checked');
        // console.log(status);
        if (status == true){
            $('#add-my-banner').show();
        }else{
            $('#add-my-banner').hide();
        }
    });

    // Inizializzazione Dropzone //
    // var url = "/test_cambiami"; // @todo: aggiungere l'URL!!!!!!!

    // myDropzone = initDropzone(url);
    // // funzione chiamata quando si utilizza il submit di dropzone
    // myDropzone.on("sendingmultiple", function(files, xhr, formData) {

    //     var form = $('#form_report_new');
    //     if (! form.valid() ){
    //         swal("Attenzione", "Sono presenti dei campi incompleti. Report non salvato!", "info");
    //         return false;
    //     };

    //     var formValues = form.serializeArray();
    //     $.each(formValues, function(index, input){
    //         formData.append(input.name, input.value);
    //     });
    // });
    // // funzione chiamata al ritorno del submit di dropzone
    // myDropzone.on("successmultiple", function(files, response) {
    //     var id   = $("#rp-id").val();

    //     if(id){
    //         msg_ok = 'La modifica è stata correttamente salvata';
    //         msg_err = 'Si è verificato un errore durante la modifica';
    //     }
    //     else{
    //         msg_ok  = 'Il salvataggio è avvenuto correttamente';
    //         msg_err = 'Si è verificato un errore durante il salvataggio';
    //     }

    //     $(".inner-preloader").hide();

    //     if(response == true){
    //         console.log('Success');
    //         swal("Successo", msg_ok, "success");
    //         loadReports(dateFrom, dateTo);
    //         $('.customtab a[href="#report-list"]').tab('show');
    //         clearFields();
    //     }
    //     else{
    //         swal("Errore", msg_err, "error");
    //         $.each(files, function(index, file) {
    //             file.previewElement.classList.add("dz-error");
    //             file.status = Dropzone.QUEUED
    //         });
    //     }
    // });
    // END Dropzone //

    // validate form
    var validator = $('#add-my-link').validate({ // initialize the plugin
        rules: {
            "link-ttl" : {
                required: true
            },
            "link-url" : {
                min: 0
            }
        },
        messages: {
            "link-ttl" : {
                required: "Inserire nome del link"
            },
            "link-url" : {
                min: "Inserire l'url del link",
            },
        },
        ignore: "",
        errorPlacement: function ( error, element ) {
            if(element.parent().hasClass('input-group')){
                error.insertAfter( element.siblings() );
            }else{
                error.insertAfter( element );
            }
        },
    });

    $('#add-my-link').on('submit', function (e) {
        e.preventDefault();
        if (! $(this).valid() ){
            swal("Attenzione", "Sono presenti dei campi incompleti. Impossibile salvare link", "info");
            return false;
        };

        if( $('#link-url').val() != ''){

            var id = $('#link-url').val();
            var name = $('#link-url option:selected').data('name');
            var url = $('#link-url option:selected').text();
            var html = '<li data-id="'+id+'"><i class="ti-move"></i> <a href="'+url+'" target="_blank">'+name+' <i class="ti-trash text-danger del-link"></i></a></li>';

            $('#sortable').append(html);

            updateUserLinks(true);
            clearFields();
            $('#add-my-link').hide();
        }
        else{
            var url = $('#link-url option:selected').text();
            var name = $('#link-ttl').val();

            $('#preloader-links').show();
            var jqxhr = $.ajax({
                url: '/home_put_link',
                type: "post",
                dataType: "json",
                data: {
                    url: url,
                    name: name
                }
            })
            .done(function(result) {
                if(result.res == 'OK'){

                    var id = result.id;
                    var html = '<li data-id="'+id+'"><i class="ti-move"></i> <a href="'+url+'" target="_blank">'+name+' <i class="ti-trash text-danger"></i></a></li>';
                    $('#sortable').append(html);

                    updateUserLinks(true);
                    clearFields();
                    $('#add-my-link').hide();
                    loadLinks();
                }
                else{
                    swal("Errore!", "Errore durante il salvataggio del link", "error");
                    $('#preloader-links').hide();
                }

            })
            .fail(function(xhr, err) {
                swal("Errore!", "Errore durante il salvataggio del link", "error");
                $('#preloader-links').hide();
            });
        }
    });

    resizeHomepage();

    loadUserLinks();
    loadLinks();
    clearFields();

    // siccome non so quanto larghi saranno i widget dell'homepage non posso usare le css mediaquery
    // quindi faccio i resize da jquery sulla base delle dimensioni dei div esterni in pixel
    function resizeHomepage(){
        var mainW = $( ".link-top" ).width();
        // console.log(mainW);
        if (mainW < 432){
            // console.log("modifica link");
            $(".bobo-sortable li").css({"width": "100%", "margin-left": "0"});
        }else{
            $(".bobo-sortable li").css({"width": "49%", "margin-left": "2%"});
        }
        if (mainW < 350){
            // console.log("modifica img");
            $(".bobo-sortable-img li").css({"width": "100%", "margin-left": "0"});
        }else{
            $(".bobo-sortable-img li").css({"width": "calc(50% - 2px)", "margin-left": "2px"});
        }
    }

    function clearFields(){

        $('#link-ttl').val("");
        $('#link-ttl').prop('disabled', false);
        $('#link-url').val(-1).trigger('change');
        // myDropzone.removeAllFiles(true);
    }

    function loadUserLinks(){
        $('#preloader-links').show();

        var jqxhr = $.ajax({
            url: '/home_get_user_links',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {
            // console.dir(result);
            var links = result.user_links;
            console.dir(links);

            var html= '';
            var htmlBadge = '';
            // check if the list of swam warnings is larger than 0
            if( links.length > 0 ){
                // for each report create a row to attach at the main table
                $.each(links, function(index, value) {

                    // BADGE
                    if(value.link_image_url != null){
                        htmlBadge += '<li><a href="'+value.link_url+'" target="_blank" alt="'+value.link_name+'"><img src="'+value.link_image_url+'" class="img-fluid"></a></li>';
                    }
                    else{
                        html += '<li data-id="'+value.link_id+'" data-pos="'+value.link_pos+'"><i class="ti-move"></i>';
                        html += '    <a href="'+value.link_url+'" target="_blank">'+value.link_name;
                        if( value.link_default == 0)
                            html += '        <i class="ti-trash text-danger"></i>';
                        html += '    </a>';
                        html += '</li>';
                    }
                });

                $('#sortable-img').append(htmlBadge);
                $('#sortable').append(html);
            }

            $('#preloader-links').hide();
        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il recupero dei link", "error");
            $('#preloader-links').hide();
        });
    }

    function loadLinks(){

        $('#link-url').empty();
        var jqxhr = $.ajax({
            url: '/home_get_links',
            type: "post",
            dataType: "json"
        })
        .done(function(result) {

            if(result.res == 'OK'){
                var links = result.links;
                var html = '<option value="-1" selected="selected">Seleziona o aggiungi link...</option>';

                $.each(links, function(idx, link){
                    html += '<option value="'+link.link_id+'" data-name="'+link.link_name+'">'+link.link_url+'</option>';
                });

                $('#link-url').append(html);
            }
            else{
                swal("Errore!", "Errore durante il recupero dei link", "error");
            }

        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il recupero dei link", "error");
        });
    }

    function updateUserLinks(flagNew){

        var linkArray = [];

        $('#sortable li').each(function(idx){

            var obj = {};
            obj.link_id = parseInt($(this).data('id'));
            obj.pos = idx+1;
            linkArray.push(obj);
        });

        var jqxhr = $.ajax({
            url: '/home_put_user_links',
            type: "post",
            dataType: "json",
            data: {
                links : JSON.stringify(linkArray)
            }
        })
        .done(function(result) {
            if(result){

                if(flagNew)
                    swal("Successo!", "Il link è stato aggiunto con successo", "success");
            }
            else{
                swal("Errore!", "Errore durante il salvataggio dei link associati all'utente", "error");
            }

            $('#preloader-links').hide();
        })
        .fail(function(xhr, err) {
            swal("Errore!", "Errore durante il salvataggio dei link associati all'utente", "error");
            $('#preloader-links').hide();
        });
    }
});