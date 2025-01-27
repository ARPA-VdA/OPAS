var lastId,
    topMenu,
    topMenuHeight,
    // All list items
    menuItems,
    // Anchors corresponding to menu items
    scrollItems;

$(document).ready(function() {

    // This is for the sticky sidebar
    $(".stickyside").stick_in_parent({
        offset_top: 100
    });
    $('.stickyside').on("click", "a", function() {
        $('html, body').animate({
            scrollTop: $($(this).attr('href')).offset().top - 100
        }, 500);
        return false;
    });
    // This is auto select left sidebar
    // Cache selectors
    // Cache selectors
    topMenu = $(".stickyside");
    topMenuHeight = topMenu.outerHeight();
    // All list items
    menuItems = topMenu.find("a");
    // Anchors corresponding to menu items
    scrollItems = menuItems.map(function() {
        var item = $($(this).attr("href"));
        if (item.length) {
            return item;
        }
    });

    // Bind click handler to menu items

    // Bind to scroll
    $(window).scroll(function() {
        // Get container scroll position
        var fromTop = $(this).scrollTop() + topMenuHeight + 10;

        // Get id of current scroll item
        var cur = scrollItems.map(function() {
            if ($(this).offset().top < fromTop)
                return this;
        });
        // Get the id of the current element
        cur = cur[cur.length - 1];
        var id = cur && cur.length ? cur[0].id : "";

        if (lastId !== id) {
            lastId = id;
            // Set/remove active class
            menuItems
                .removeClass("active")
                .filter("[href='#" + id + "']").addClass("active");
        }
    });

    // For select 2
    $(".select2").select2();

    // get of selected argument and all arguments related to the same page
    $( "#questions" ).on( "change", "#select-arg", function() {

        $('#faq-title').empty();
        $('#top-menu').empty();
        $('#args-container').empty();

        console.log("Change of option");
        var arg_id = $(this).val();

        if (arg_id != -1){

            var jqxhr = $.ajax({
                url: 'faq_get_argument',
                type: "post",
                dataType: "json",
                data: {
                    id: arg_id,
                    tech: flag_tech
                },
            })
            .done(function(result) {
                // console.dir(result);
                var html = result.selected_page_args[0].faq_page_name;
                if( insert_grant ){
                    html +=' <a href="#" class="add-notes" data-toggle="tooltip"><i class="mdi mdi-comment-plus-outline" data-original-title="Aggiungi nota" data-toggle="modal" data-target="#responsive-modal"></i></a>';
                }

                $('#faq-title').append(html);

                // build left menu with results
                fillLeftMenu(result.selected_page_args, arg_id);
                // build right descriptions
                fillRightDesc(result.selected_page_args);

                $('html, body').animate({
                    scrollTop: $('#'+arg_id).offset().top - 100
                }, 500);

                resetParameters();

            })
            .fail(function(xhr, err) {
                alert("Errore durante il recupero degli argomenti");
            });
        }
    });

    // click of search button by keyword
    $( "#search-keyword" ).click(function(e) {
        e.preventDefault();  //stop the browser from following
        searchKey();
    });

    $("#input-keyword").on('keypress', function(e) {
        if ( e.which == 13 ) {
            e.preventDefault();
            searchKey();
        }
    });

    // INSERT
    $('#new-faq-form').on('submit', function (e) {
        if ($(this).valid()){

            var faq_page = $("#new-faq-page").val();
            var faq_title = $("#new-faq-title").val();
            // var faq_text = $("#new-faq-text").val();
            var faq_text = document.getElementById("new-faq-text").innerHTML;

            console.log(faq_page );
            console.log(faq_title);
            console.log(faq_text );
            console.log(flag_tech );

            // edit argument
            var jqxhr = $.ajax({
                url: 'faq_put_argument',
                type: "post",
                dataType: "json",
                data: {
                    page_id: faq_page,
                    title: faq_title,
                    text: faq_text,
                    tech: flag_tech
                },
            })
            .done(function(result) {

                if(result){
                    $( "#responsive-modal" ).modal("hide");
                    swal({
                        title: "Successo",
                        text: "Faq inserita con successo!",
                        type: "success"
                     },
                     function(isConfirm){
                        location.reload();
                     });

                }
                else{
                    swal("Errore", "Questa operazione non è andata a buon fine", "error");
                }

            })
            .fail(function(xhr, err) {
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
            });
        }
        e.preventDefault();

    });

    $('#new-page-form').on('submit', function (e) {
        if ($(this).valid()){

            var page_title = $("#new-page-title").val();
            console.log(page_title);

            // edit argument
            var jqxhr = $.ajax({
                url: 'faq_put_page',
                type: "post",
                dataType: "json",
                data: {
                    title: page_title,
                    tech: flag_tech
                },
            })
            .done(function(result) {

                if(result){
                    $( "#page-modal" ).modal("hide");
                    swal({
                        title: "Successo",
                        text: "Argomento inserito con successo!",
                        type: "success"
                     },
                     function(isConfirm){
                        location.reload();
                     });

                }
                else{
                    swal("Errore", "Questa operazione non è andata a buon fine", "error");
                }

            })
            .fail(function(xhr, err) {
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
            });
        }
        e.preventDefault();

    });

    $( "#responsive-modal" ).on( "click", "#new-faq-cancel", function(e) {
        e.preventDefault();
        $('#new-faq-page').val(-1);
        $('#new-faq-title, #new-faq-text').val("");
    });

    $( "#page-modal" ).on( "click", "#new-page-cancel", function(e) {
        e.preventDefault();
        $('#new-page-title').val("");
    });

    $("#new-faq-form").validate({
        rules: {
            "new-faq-page": {
                required: true,
                min: 1
            },
            "new-faq-title": {
                required: true
            },
            "new-faq-text": {
                required: true,
            }
        },
        messages: {
            "new-faq-page": {
                min: "Selezionare un argomento"
            },
            "new-faq-title": {
                required: "Inserire un titolo",
            },
            "new-faq-text": {
                required: "Inserire testo faq",
            }
        },
        ignore: "",
    });

    $("#new-page-form").validate({
        rules: {
            "new-page-title": {
                required: true
            }
        },
        messages: {
            "new-page-title": {
                required: "Inserire un nuovo argomento",
            }
        },
        ignore: "",
    });

    // EDIT
    var origtxt, origtitle;

    // click of the modify button
    $( "#answers" ).on( "click", ".faq-mod", function(e) {
        e.preventDefault();
        var id = $(this).parent().parent().parent().attr('id');
        console.log('FAQ: '+id);
        $( this ).tooltip( "hide" );

        //on modify, save original FAQ title and text and disable all other "edit buttons"
        document.getElementById('text-'+id).contentEditable='true';
        document.getElementById('title-'+id).contentEditable='true';
        origtxt = $('#text-'+id).text();
        origtitle = $('#title-'+id).text();
        $('#text-'+id).addClass('asform');
        $('#title-'+id).addClass('asform');
        $('#text-'+id).focus();
        $(this).remove();

        var html =

        $('#'+id).find(".pull-right").prepend('<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Salva" class="faq-save"> <i class="mdi mdi-content-save-settings text-info"></i> </a>  <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Annulla" class="faq-cancel"><i class="mdi mdi-close text-danger"></a></i>');
        $(".faq-mod").addClass('disable-anchor');
        $('[data-toggle="tooltip"]').tooltip();
    });

    // click of the save button
    $( "#answers" ).on( "click", ".faq-save", function(e) {
        e.preventDefault();
        var id = $(this).parent().parent().parent().attr('id');
        var faq_title = document.getElementById('title-'+id).innerText;
        var faq_text = document.getElementById('text-'+id).innerHTML;

        console.log('Titolo: '+faq_title);
        console.log('Testo: '+faq_text);

        swal({
            title: "Modifica la FAQ",
            text: "Sei sicuro di voler modificare la FAQ selezionata?",
            type: "warning",
            showCancelButton: true,
            confirmButtonColor: "#DD6B55",
            confirmButtonText: "Modifica",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // edit argument
            var jqxhr = $.ajax({
                url: 'faq_put_argument',
                type: "post",
                dataType: "json",
                data: {
                    id: id,
                    title: faq_title,
                    text: faq_text
                },
            })
            .done(function(result) {

                $( this ).tooltip( "hide" );
                document.getElementById('text-'+id).contentEditable='false';
                document.getElementById('title-'+id).contentEditable='false';
                $('#args-container a').removeClass('disable-anchor');
                $('#text-'+id).removeClass('asform');
                $('#title-'+id).removeClass('asform');
                $(this).remove();
                $('#'+id).find(".pull-right").prepend('<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica" class="faq-mod"> <i class="icon-pencil text-info"></i> </a>');
                $('#'+id).find(".pull-right .faq-cancel").remove();
                $('#'+id).find(".pull-right .faq-save").remove();
                $('[data-toggle="tooltip"]').tooltip();

                if (result){
                    // message
                    menuItems.filter("[href='#" + id + "']")[0].innerText = faq_title;
                    $("#select-arg option[value='"+ id +"']").text(faq_title);
                    $(".select2").select2();

                    swal("Modificata", "La faq selezionata è stata modificata", "success");
                }
                else {

                    $('#text-'+id).text(origtxt);
                    $('#title-'+id).text(origtitle);

                    swal("Errore", "Questa operazione non è andata a buon fine", "error");
                }

            })
            .fail(function(xhr, err) {
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
            });

        });
    });

    // CANCEL
    // click of the cancel botton (X)
    $( "#answers" ).on( "click", ".faq-cancel", function(e) {
        e.preventDefault();
        var id = $(this).parent().parent().parent().attr('id');
        console.log('Annulla FAQ: '+id);
        $( this ).tooltip( "hide" );

        // Remove all changes and reset FAQ title and text; enable edit butoons
        document.getElementById('text-'+id).contentEditable='false';
        document.getElementById('title-'+id).contentEditable='false';
        $('#args-container a').removeClass('disable-anchor');
        $('#text-'+id).removeClass('asform');
        $('#title-'+id).removeClass('asform');
        $('#text-'+id).html(origtxt);
        $('#title-'+id).html(origtitle);
        $('#'+id).find(".pull-right").prepend('<a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica" class="faq-mod"> <i class="icon-pencil text-info"></i> </a>');
        $('#'+id).find(".pull-right .faq-cancel").remove();
        $('#'+id).find(".pull-right .faq-save").remove();
        $('[data-toggle="tooltip"]').tooltip();
    });

    // DELETE FAQ
    // click of the delete button
    $( "#answers" ).on( "click", ".faq-del", function(e) {
        e.preventDefault();
        var id = $(this).parent().parent().parent().attr('id');
        console.log(id);

        swal({
            title: "Elimina la FAQ",
            text: "Sei sicuro di voler eliminare la FAQ selezionata?",
            type: "warning",
            showCancelButton: true,
            confirmButtonColor: "#DD6B55",
            confirmButtonText: "Elimina",
            closeOnConfirm: false,
            cancelButtonText: "Annulla"
        }, function () {
            // delete report
            var jqxhr = $.ajax({
                url: 'faq_del_argument',
                type: "post",
                dataType: "json",
                data: { id: id },
            })
            .done(function(result) {

                if( result ){

                    // $("#select-config option[value='"+id+"']").remove();
                    $("#select-arg option[value='"+ id +"']").remove();
                    $(".select2").select2();
                    menuItems.filter("[href='#" + id + "']")[0].remove();
                    $('#'+id).remove();

                    resetParameters();
                    // message
                    swal("Eliminata", "La faq selezionata è stata eliminata", "success");
                }
                else{
                    swal("Errore", "Questa operazione non è andata a buon fine", "error");
                }

            })
            .fail(function(xhr, err) {
                swal("Errore", "Questa operazione non è andata a buon fine", "error");
            });
        });
    });

});

//function for reset the situation of the stickyside
function resetParameters(){

    topMenu = $(".stickyside");
    topMenuHeight = topMenu.outerHeight();
    // All list items
    menuItems = topMenu.find("a");
    // Anchors corresponding to menu items
    scrollItems = menuItems.map(function() {
        var item = $($(this).attr("href"));
        if (item.length) {
            return item;
        }
    });
}

// function for dinamically create left menu
function fillLeftMenu(selected_args, arg_id){
    // console.dir(selected_args);
    var firstElement = true;
    var htmlPanel='';

    $.each(selected_args, function(index, value) {

        htmlPanel += '<a href="#'+value.faq_arg_id+'" class="list-group-item">'+value.faq_arg_title+'</a>';
    });

    $('#top-menu').append(htmlPanel);

}

// function for dinamically create right contents
function fillRightDesc(selected_args){
    // console.dir(selected_args);

    var html = "";
    $.each(selected_args, function(index, value) {

        html += '<div class="faq-cont" id="'+value.faq_arg_id+'">';
        html += '    <div class="inline-faq-title clearfix">';
        html += '        <h4 class="card-title" contenteditable="false" id="title-'+value.faq_arg_id+'">'+value.faq_arg_title+'</h4>';
        html += '        <div class="pull-right"> ';
        if(update_grant){
            html += '           <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Modifica" class="faq-mod"> <i class="icon-pencil text-info"></i> </a> ';
        }
        if(delete_grant){
            html += '           <a href="javascript:void(0)" data-toggle="tooltip" data-original-title="Elimina" class="faq-del"> <i class="icon-trash text-danger"></i> </a> ';
        }
        html += '       </div>';
        html += '    </div>';
        html += '    <div class="faq-txt" contenteditable="false" id="text-'+value.faq_arg_id+'">'+value.faq_arg_desc+'</div>';
        html += '</div>';

    });

    $('#args-container').append(html);
    $('[data-toggle="tooltip"]').tooltip();
}

//function for searching a keyword
function searchKey(){
    // get keywords and check if it matches the regular expression
    var keywords = $('#input-keyword').val();
    var test = /^[a-zA-Z0-9]+((&|\|){1}[a-zA-Z0-9]+)*$/.test(keywords);

    if(test){

        $('#faq-title').empty();
        $('#top-menu').empty();
        $('#args-container').empty();

        console.log('ajax');
        var jqxhr = $.ajax({
            url: 'faq_get_key',
            type: "post",
            dataType: "json",
            data: {
                key: keywords,
                tech: flag_tech
                },
        })
        .done(function(result) {
            console.dir(result);

            var num_results = result.search_results.length;

            if(num_results == 1){
                $('#faq-title').append('Risultati ricerca: trovata 1 corrispondenza');

                // build the left menu with results and with the first element as active
                fillLeftMenu(result.search_results, result.search_results[0].faq_arg_id);
                // build the right descriptions
                fillRightDesc(result.search_results);
            }
            else if (num_results > 1){
                $('#faq-title').append('Risultati ricerca: trovate '+num_results+' corrispondenze');

                // build the left menu with results and with the first element as active
                fillLeftMenu(result.search_results, result.search_results[0].faq_arg_id);
                // build the right descriptions
                fillRightDesc(result.search_results);
            }
            else{
                $('#faq-title').append('Risultati ricerca: trovate 0 corrispondenze');
            }

            resetParameters();

        })
        .fail(function(xhr, err) {
            alert("Errore durante la ricerca!");
        });

    }
    else{
        alert('La stringa ricercata non rispetta il formato indicato nella guida');
    }
}
