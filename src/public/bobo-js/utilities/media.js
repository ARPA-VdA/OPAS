/**
 * Document ready
 */
$(document).ready(function() {

    /**
     * Click event for navigation in the filesystem
     */
    $('.media-file-system').on('click', '.nav-file-system', function(e){
        e.preventDefault();

        var path = $(this).data('path');
        var direction = $(this).data('dir');

        // show preloader, waiting for the end of the process
        $('.inner-preloader').show();

        // TEST PERMISSION
        // path = path.replace('arpavda', 'arpazzz');

        // Ajax call to navigate the filesystem
        var jqxhr = $.ajax({
            url: '/media_navigate_filesystem',
            type: "post",
            dataType: "json",
            data:{
                path: path,
                dir: direction
            }
        })
        .done(function(result) {

            console.dir(result);
            // check result
            // if OK then build the html to be added to the filesystem
            // else show error
            if(result.res == 'OK'){

                var html = '';
                // Build breadcrumb navigation
                let levels = result.dir.parent.split('/');
                console.log(levels.length);
                var htmlBread = [];
                levels.forEach(function(el, idx){
                    if(idx != 0)
                        htmlBread.push('<span><a class="nav-file-system go-back" href="#" data-dir="down" data-path="'+levels.slice(0,idx+1).join('/')+'">'+el+'</a>');
                });

                html += '<hr class="m-b-10">';
                html += '<div class="media-breadcrump">';
                html += '    <em>La tua posizione:</em> '+htmlBread.join(' <i class="fa-light fa-angle-double-right"></i> ');
                html += '</div>';
                html += '<hr>';
                html += '<h5 class="current-folder" data-path="'+path+'">';
                html += '    <span>Cartella corrente: <strong>'+levels[levels.length-1]+'</strong></span>';
                // html += '    <button type="button" class="btn btn-rounded btn-sm btn-danger float-right"><i class="fas fa-download"></i> Scarica</button>';

                // check if user is in a "network" directory and if he has the insert grant
                // if true then add the button for the creation of a new directory
                if ( levels.length == 3 && insert_grant){
                    html += '    <button type="button" class="btn btn-rounded btn-sm btn-info float-right m-r-5" data-toggle="modal" data-target="#add-new-folder"><i class="fas fa-folder-plus"></i> Crea cartella</button>';
                }
                html += '</h5>';

                let list = result.dir.list;
                // check if at least one element exists
                if(list.length > 0){
                    // order them by type and name
                    list.sort((a, b) => sortFuncByType(a,b) || a.rel_path.localeCompare(b.rel_path));

                    // Arrays to hold HTML for folders and files
                    var htmlFolders = [];
                    var htmlFiles   = [];

                    // loop through all elements
                    // for each row, build a html tr to be added to the table
                    list.forEach(function(el){
                        let htmlItems = '';
                        if(el.is_file){
                            // File item
                            htmlItems += '    <div class="col-xl-2 col-lg-3 col-md-4 col-sm-6">';
                            htmlItems += '        <div class="folder-media folder-editable single-files">';
                            htmlItems += '            <div class="commands-icons" data-relpath="'+el.rel_path+'">';
                            if(update_grant)
                                htmlItems += '                <i class="fa-regular fa-pencil-alt edit-item"></i>';
                            if(delete_grant)
                                htmlItems += '                <i class="fa-regular fa-trash-alt del-item"></i>';
                            htmlItems += '            </div>';
                            if(el.is_image){
                                // Image preview
                                htmlItems += '            <a href="'+el.rel_path.replace('public', '')+'" class="show-img">';
                                htmlItems += '                <img loading="lazy" src="'+el.rel_path.replace('public', '')+'" />';
                                htmlItems += '                <h6>'+el.basename+'</h6>';
                                htmlItems += '            </a>';
                            }
                            else{
                                // Other file type
                                htmlItems += '            <a href="'+el.rel_path.replace('public', '')+'" target="_blank">';
                                htmlItems += formatIcon(el);
                                htmlItems += '                <h6>'+el.basename+'</h6>';
                                htmlItems += '            </a>';
                            }
                            htmlItems += '        </div>';
                            htmlItems += '    </div>';

                            htmlFiles.push(htmlItems);
                        }
                        else{
                            // Folder item
                            htmlItems += '    <div class="col-xl-2 col-lg-3 col-md-4 col-sm-6">';
                            htmlItems += '        <div class="folder-media">'; //  folder-editable
                            if( levels.length == 3 && el.editable ){
                                htmlItems += '            <div class="commands-icons" data-relpath="'+el.rel_path+'">';
                                if(update_grant)
                                    htmlItems += '                <i class="fa-regular fa-pencil-alt edit-item"></i>';
                                if(delete_grant)
                                    htmlItems += '                <i class="fa-regular fa-trash-alt del-item"></i>';
                                htmlItems += '            </div>';
                            }
                            htmlItems += '            <a class="nav-file-system" href="#" data-path="'+el.rel_path+'" data-dir="down">';
                            htmlItems += '                <i class="fas fa-folder main-icon"></i>';
                            htmlItems += '                <h6>'+el.basename+'</h6>';
                            htmlItems += '            </a>';
                            htmlItems += '        </div>';
                            htmlItems += '    </div>';

                            htmlFolders.push(htmlItems);
                        }
                    });

                    // Append folders and files HTML
                    html += '<div class="folders-content">';
                    html += '    <div class="row all-folders">';
                    html += htmlFolders.join('');
                    html += '    </div>';
                    html += '</div>';
                    // Add horizontal line if both folders and files exist
                    if(htmlFolders.length > 0 && htmlFiles.length > 0){
                        html += '<hr>';
                    }
                    html += '<div class="files-content">';
                    html += '    <div class="row all-files">';
                    html += htmlFiles.join('');
                    html += '    </div>';
                    html += '</div>';
                    html += '<hr class="m-b-10">';
                }
                else{
                    // No files or folders
                    html += '<div class="folders-content">';
                    html += '    <div class="row all-folders">';
                    html += '    </div>';
                    html += '</div>';
                    html += '<div class="files-content">';
                    html += '    <div class="row all-files">';
                    html += '    </div>';
                    html += '</div>';
                    html += '<hr class="m-b-10">';
                }

                // Add breadcrumb and dropzone for uploads
                html += '<div class="media-breadcrump">';
                html += '    <em>La tua posizione:</em> '+htmlBread.join(' <i class="fa-light fa-angle-double-right"></i> ');
                html += '</div>';
                // Add dropzone section only if user is not in media directory
                if(levels.length > 2){
                    html += '<hr>';
                    html += '<div id="insert-attach" class="dropzone"></div>';
                }

                // Render the new HTML
                $('.media-file-system').empty();
                $('.media-file-system').append(html);

                // Initialize image gallery popup
                $('.all-files').each(function() { // the containers for all your galleries
                    $(this).magnificPopup({
                        delegate: 'a.show-img', // the selector for gallery item
                        type: 'image',
                        closeOnContentClick: true,
                        mainClass: 'mfp-img-mobile',
                        image: {
                            verticalFit: true
                        },
                        gallery: {
                          enabled: true
                        }
                    });
                });

                if(levels.length > 2)
                    // Initialize Dropzone for file uploads
                    initDropzone(result.dir.parent);
            }
            else
                // Show error if navigation fails
                swal({
                    title: "Errore!",
                    text: "E' stato restituito il seguente errore:<br><code>"+result.msg+"</code>",
                    type: "error",
                    html: true
                });

            // at the end of the process hide preloader
            $('.inner-preloader').hide();
         })
        .fail(function(xhr, err) {
            // at the end of the process hide preloader
            $('.inner-preloader').hide();
            // error message
            swal("Errore!", "Errore durante la navigazione del filesystem", "error");
        });
    });

    ////// Azioni sui singoli files / cartelle //////

    /**
     * Click event on edit folder button
     */
    $(".media-file-system").on('click', '.all-folders .edit-item', function(e){
        e.preventDefault();
        // get folder path stored in the parent HTML element
        var relPath = $(this).parent().data('relpath');

        const levels = relPath.split('/');
        const folder = levels[levels.length -1];

        // Set modal for renaming folder
        $('#add-new-folder h5').html('<strong>Rinomina la cartella</strong> selezionata: '+folder);
        $('#add-new-folder #folder-name').val(folder);
        $('#add-new-folder #folder-source').val(relPath);
        $('#add-new-folder button[type="submit"]').html(' <i class="fas fa-folder-gear"></i> Modifica');

        $('#add-new-folder').modal('show');
    });

    /**
     * Click event on delete folder button
     */
    $(".media-file-system").on('click', '.all-folders .del-item', function(e){
        e.preventDefault();

        // get folder path stored in the parent HTML element
        var folder = $(this).parent().parent().parent();
        var relPath = $(this).parent().data('relpath');

        // Confirmation dialog for deleting folder
        var txt = '';
        txt += 'L\'eliminazione della cartella comporta l\'eliminazione anche di tutti i file in essa contenuti.<br>';
        txt += '<strong>Tutti i file saranno persi definitivamente!</strong><br><br>';
        txt += 'Sei proprio sicuro di voler proseguire all\'eliminazione?<br>';
        txt += '<input type="checkbox" id="delete-confirm" name="delete-confirm" /> <label for="delete-confirm">Confermo</label>';

        // show confirm message
        swal({
            title: "Stai per eliminare la cartella",
            text: txt,
            type: "warning",
            html: true,
            showCancelButton: true,
            confirmButtonText: "Prosegui",
            closeOnConfirm: false,
            showLoaderOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function (isConfirm) {

            // if Annulla then return
            if (isConfirm === false) return false;
            // if checkbox not checked then show validation error
            if (! $('#delete-confirm').is(':checked') ) {
                swal.showInputError("E' necessario confermare l'eliminazione");
                return false;
            }

            // Ajax call to delete folder
            var jqxhr = $.ajax({
                url: '/media_del_folder',
                type: "post",
                dataType: "json",
                data: {
                    path: relPath
                }
            })
            .done(function(result) {

                // check result
                // if 1 then remove folder and all files from UI
                // else generic error
                if(result.res == 'OK'){
                    swal("Cartella eliminata", "L'elemento è stato eliminato con successo!", "success");
                    // remove folder
                    folder.remove();
                }
                else{
                    // show error message
                    swal("Errore!", "Errore durante l'eliminazione della cartella", "error");
                }

            })
            .fail(function(xhr, err) {
                // show error message
                swal("Errore!", "Errore durante l\'eliminazione della cartella", "error");
            });
        });
    });

    /**
     * Click event on edit file button
     */
    $(".media-file-system").on('click', '.all-files .edit-item', function(e){
        e.preventDefault();
        // get file path stored in the parent HTML element
        var file = $(this).parent().parent().parent();
        var relPath = $(this).parent().data('relpath');

        // Set modal for renaming file
        $('#file-path').val(relPath);
        // show modal
        $('#rename-file').modal('show');
    });

    /**
     * Click event on delete file button
     */
    $(".media-file-system").on('click', '.all-files .del-item', function(e){
        e.preventDefault();
        // get file path stored in the parent HTML element
        var file = $(this).parent().parent().parent();
        var relPath = $(this).parent().data('relpath');

        // Confirmation dialog for deleting file
        swal({
            title: "Eliminare questo file",
            text: "Sei sicuro di proseguire all'eliminazione?",
            type: "warning",
            showCancelButton: true,
            confirmButtonText: "Elimina",
            closeOnConfirm: true,
            cancelButtonText: "Annulla"
        }, function () {

            // Ajax call to delete file
            var jqxhr = $.ajax({
                url: '/media_del_file',
                type: "post",
                dataType: "json",
                data:{
                    path: relPath
                }
            })
            .done(function(result) {
                // check result
                // if OK then remove file from UI
                // else show error
                if(result.res == 'OK'){
                    // Show success toast
                    $.toast({
                        heading: 'Successo',
                        text: 'File eliminato correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });
                    // remove file from UI
                    file.remove();
                }
                else
                    swal("Errore!", "Si è verificato un errore durante l'eliminazione del file", "error");

             })
            .fail(function(xhr, err) {
                // error message
                swal("Errore!", "Si è verificato un errore durante l'eliminazione del file", "error");
            });

        });
    });

    // MODALs
    ////////////////////////////////////////////////////////

    /**
     * When showing add/rename folder or file modal, clone the breadcrumb
     */
    $('#add-new-folder, #rename-file').on('show.bs.modal', function(){
        let breadcrump = $('.media-file-system .media-breadcrump:first').clone(true);

        $('.media-breadcrump', this).replaceWith(breadcrump);
    });

    // AGGIUNGI CARTELLA
    /**
     * Modal close event, reset form fields and titles
     */
    $('#add-new-folder').on('hidden.bs.modal', function(){

        $('#add-new-folder h5').html('<strong>Aggiungi una cartella</strong> nella tua posizione attuale');
        $('#add-new-folder #folder-name').val('');
        $('#add-new-folder #folder-source').val('');
        $('#add-new-folder button[type="submit"]').html(' <i class="fas fa-folder-plus"></i> Cartella');
    });

    /**
     * Submit event of add/rename folder form
     */
    $('#add-folder-form').on('submit', function(e){
        e.preventDefault();

        // Validate folder name
        if($('#folder-name').val().trim() == ''){
            swal('Attenzione', 'È necessario inserire il nome della cartella da creare', 'info');
            return;
        }
        // Validate folder name format
        if( ! $('#folder-name').val().trim().match(/^(?=.*[a-z])[a-z0-9-_]*$/) ){

            // @Alessia
            // Show validation warning
            let msg = '<div class=\"lightbox-txt\">Inserire un nome valido per la nuova cartella.<br><br>I requisiti sono: <ul>'
            msg += '<li>deve essere <strong>tutto minuscolo</strong>;</li>';
            msg += '<li>deve contenere <strong>almeno una lettera</strong>;</li>';
            msg += '<li>può contenere <strong>numeri</strong> e <strong>caratteri speciali</strong> quali "-" e "_"</li>';
            msg += '<li>non deve essere presente <strong>un\'altra cartella con lo stesso nome</strong></li>';
            msg += '</ul></div>';

            swal({
                title: "Attenzione",
                text: msg,
                type: "info",
                html: true
            });
            return;
        }

        // get values from form
        var path = $('.current-folder').data('path');
        var name = $('#folder-name').val().trim().toLowerCase();
        var source = $('#folder-source').val();

        // Ajax call to create or rename folder
        var jqxhr = $.ajax({
            url: '/media_put_folder',
            type: "post",
            dataType: "json",
            data:{
                path: path,
                name: name,
                source: source
            }
        })
        .done(function(result) {
            // check result
            // if OK then add/rename folder and refresh UI
            if(result.res == 'OK'){

                if(source != ''){
                    // Show success toast for rename
                    $.toast({
                        heading: 'Successo',
                        text: 'Cartella rinominata correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                    $('.media-file-system a.nav-file-system:last').trigger('click');
                }
                else{
                    // Show success toast for create
                    $.toast({
                        heading: 'Successo',
                        text: 'Cartella creata correttamente!',
                        position: 'top-right',
                        loaderBg:'#e8bb05',
                        icon: 'success',
                        hideAfter: 5000
                    });

                    // Add new folder to UI
                    var htmlItems = '';
                    htmlItems += '    <div class="col-xl-2 col-lg-3 col-md-4 col-sm-6">';
                    htmlItems += '        <div class="folder-media">'; //  folder-editable
                    htmlItems += '            <div class="commands-icons" data-path="'+path+'/'+name+'">';
                    if(update_grant)
                        htmlItems += '                <i class="fa-regular fa-pencil-alt edit-item"></i>';
                    if(delete_grant)
                        htmlItems += '                <i class="fa-regular fa-trash-alt del-item"></i>';
                    htmlItems += '            </div>';
                    htmlItems += '            <a class="nav-file-system" href="#" data-path="'+path+'/'+name+'" data-dir="down">';
                    htmlItems += '                <i class="fas fa-folder main-icon"></i>';
                    htmlItems += '                <h6>'+name+'</h6>';
                    htmlItems += '            </a>';
                    htmlItems += '        </div>';
                    htmlItems += '    </div>';

                    $('.all-folders').append(htmlItems);
                }

                $('#add-new-folder').modal('hide');
            }
            else if(result.res == 'CONFLICT'){
                // Show conflict error
                swal({
                    title: "Attenzione",
                    text: "É già presente una cartella con il nome impostato. <strong>Cambiare il nome</strong> e procedere nuovamente al salvataggio.",
                    type: "warning",
                    html: true
                });
            }
            else
                swal("Errore!", "Si è verificato un errore durante la creazione della cartella", "error");

         })
        .fail(function(xhr, err) {

            // error message
            swal("Errore!", "Si è verificato un errore durante la creazione della cartella", "error");
        });
    });

    // RINOMINA FILE

    /**
     * Reset rename file modal on close
     */
    $('#rename-file').on('hidden.bs.modal', function(){
        $('#rename-file .clear-input').val('');
    });

    /**
     * Submit event of rename file form
     */
    $('#rename-file-form').on('submit', function(e){
        e.preventDefault();

        // check if file name is empty
        if($('#file-name').val().trim() == ''){
            swal('Attenzione', 'È necessario inserire il nuovo nome del file', 'info');
            return;
        }
        // Validate file name format
        const regex = /\..+$/g;
        if($('#file-name').val().trim().match(regex) != null){
            swal('Attenzione', 'Inserire il nuovo nome del file senza l\'estensione', 'info');
            return;
        }
        // get values from form
        var path = $('#file-path').val();
        var name = $('#file-name').val().trim();

        // Ajax call to rename file
        var jqxhr = $.ajax({
            url: '/media_put_file_name',
            type: "post",
            dataType: "json",
            data:{
                path: path,
                name: name
            }
        })
        .done(function(result) {
            // check result
            // if OK show success toast and then refresh UI
            // if CONFLICT show warning
            // else show error
            if(result.res == 'OK'){
                // Show success toast and refresh file list
                $.toast({
                    heading: 'Successo',
                    text: 'File rinominato correttamente!',
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 5000
                });

                $('.media-file-system .media-breadcrump .nav-file-system').last().trigger('click');

                $('#rename-file').modal('hide');
            }
            else if (result.res == 'CONFLICT'){
                // Show conflict error
                swal({
                    title: "Attenzione",
                    text: "É già presente un file con il nome impostato. <strong>Cambiare il nome</strong> e procedere nuovamente al salvataggio.",
                    type: "warning",
                    html: true
                });
            }
            else
                swal("Errore!", "Si è verificato un errore durante la modifica del nome del file", "error");

         })
        .fail(function(xhr, err) {

            // error message
            swal("Errore!", "Si è verificato un errore durante la modifica del nome del file", "error");
        });
    });
    ////////////////////////////////////////////////////////
    // END MODALs

    // Trigger initial navigation to load root folder
    $('.media-file-system .nav-file-system').trigger('click');

    // FUNCTIONs
    ////////////////////////////////////////////////////////

    /**
     * Sort function: folders before files, then by name
     * @param {object} a folder or file object
     * @param {object} b folder or file object
     * @returns integer that indicates the order of the two elements
     * -1 if a comes before b
     *  1 if b comes before a
     *  0 if they are equal
     */
    function sortFuncByType(a,b){

        if(a.is_dir && !b.is_dir)
            return -1;
        else if(!a.is_dir && b.is_dir)
            return 1;
        else
            return 0;

    }

    /**
     * Function to format the icon based on file extension
     * @param {object} o file object
     * @returns string with the icon HTML
     */
    function formatIcon(o){
        if(o.ext == 'csv')
            return '<i class="fa-solid fa-file-csv main-icon"></i>';
        else if (o.ext == 'pdf')
            return '<i class="fa-solid fa-file-pdf main-icon"></i>';
        else if (o.ext == 'docx')
            return '<i class="fa-solid fa-file-doc main-icon"></i>';
        else if (o.ext == 'xlsx')
            return '<i class="fa-solid fa-file-xls main-icon"></i>';
        else if (['dbf','prj','sbn','sbx','shp','shx'].includes(o.ext))
            return '<i class="fa-solid fa-file-vector main-icon"></i>';
        else if (['html','ep', 'css', 'js','sql','pl','pm', 'json', 'yml'].includes(o.ext) )
            return '<i class="fa-solid fa-file-code main-icon"></i>';
        else
            return '<i class="fa-solid fa-file-lines main-icon"></i>';
    }

    /**
     * Function to initialize Dropzone for file uploads
     * @param {string} path path to the folder where files will be uploaded
     */
    function initDropzone(path){

        var myDropzone = new Dropzone(".dropzone", {
            url: '/media_put_files',
            paramName: "file", // The name of the file param that gets transferred. Defaults to file
            uploadMultiple : true, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
            acceptedFiles: "image/*, application/*, text/*, .dbf, .prj, .sbn, .sbx, .shp, .shx",
            maxFilesize: 50, // MB
            maxFiles: 4,
            parallelUploads: 4,
            resizeWidth: 1500,
            createImageThumbnails: true,
            addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
            clickable: true, // If true, the dropzone element itself will be clickable
            autoProcessQueue: true, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
            dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui i file o clicca per caricarli',
            dictResponseError: 'Caricamento fallito!',
            dictRemoveFile: 'Rimuovi file',
            dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
            dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti per singolo invio (max 4).',
            dictCancelUpload: 'Annulla caricamento',
            dictUploadCanceled: 'Il caricamento è stato annullato.',
            dictFileTooBig: 'La dimensione totale dei file è superiore ai 50 MB.',
            dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
            // success: function(file, msg){},
            error: function(file, error) {
                // Show error and remove file from Dropzone
                swal("Attenzione", error, "warning");
                this.removeFile(file);
            }
        });

        // Add path to form data before upload
        myDropzone.on("sendingmultiple", function(files, xhr, formData) {
            formData.append('path', path);
        });

        // Handle successful upload
        myDropzone.on("successmultiple", function(files, response) {
            if(response.res == 'OK'){
                // success message
                $.toast({
                    heading: 'Successo',
                    text: 'File aggiunti correttamente!',
                    position: 'top-right',
                    loaderBg:'#e8bb05',
                    icon: 'success',
                    hideAfter: 5000
                });

                // console.dir(files);

                // var htmlItems = '';
                // files.forEach(function(el){
                //     let res = el.name.split('.');
                //     let ext = res[1];

                //     var o = {
                //         ext: ext
                //     };

                //     htmlItems += '    <div class="col-xl-2 col-lg-3 col-md-4 col-sm-6">';
                //     htmlItems += '        <div class="folder-media folder-editable single-files">';
                //     htmlItems += '            <div class="commands-icons" data-relpath="'+path+'/'+el.name+'">';
                //     htmlItems += '                <i class="fa-regular fa-pencil-alt edit-item"></i>';
                //     htmlItems += '                <i class="fa-regular fa-trash-alt del-item"></i>';
                //     htmlItems += '            </div>';
                //     if(el.type.search('image') > -1){
                //         htmlItems += '            <a href="'+path.replace(/\/?public/, '')+'/'+el.name+'" class="show-img">';
                //         htmlItems += '                <img loading="lazy" src="'+path.replace(/\/?public/, '')+'/'+el.name+'" />';
                //         htmlItems += '                <h6>'+el.name+'</h6>';
                //         htmlItems += '            </a>';
                //     }
                //     else{
                //         htmlItems += '            <a href="'+path.replace(/\/?public/, '')+'/'+el.name+'" target="_blank">';
                //         htmlItems += formatIcon(o);
                //         htmlItems += '                <h6>'+el.name+'</h6>';
                //         htmlItems += '            </a>';
                //     }
                //     htmlItems += '        </div>';
                //     htmlItems += '    </div>';
                // });

                // $('.all-files').append(htmlItems);

                // Refresh file list after upload
                setTimeout(function(){
                    myDropzone.removeAllFiles(true);
                    $('.media-file-system a.nav-file-system:last').trigger('click');
                }, 3000);
            }
            else{
                // Show error and mark files as error
                swal("Errore", "Si è verificato un errore durante l'aggiunta dei file", "error");
                $.each(files, function(index, file) {
                    file.previewElement.classList.add("dz-error");
                    // file.status = Dropzone.QUEUED
                });
            }
        });

        // Disable Dropzone if user does not have insert grant
        if(!insert_grant)
            myDropzone.disable();
    }
});



