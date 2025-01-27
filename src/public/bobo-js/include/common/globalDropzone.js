// DROPZONE
// https://docs.dropzone.dev/
Dropzone.autoDiscover = false;

/**
 * Dropzone initialization function (only images).
 * 
 * @param {string} url System route to update user data.
 * 
 * @return Dropzone object.
 */
function initDropzone(url){

    // arr fila sent
    // var attachname = [];
    var myDropzone = new Dropzone(".dropzone", {
                url: url,
                paramName: "file", // The name of the file param that gets transferred. Defaults to file
                uploadMultiple : true, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
                acceptedFiles: "image/*",
                maxFilesize: 50, // MB
                maxFiles: 4,
                parallelUploads: 4,
                resizeWidth: 1500,
                addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
                clickable: true, // If true, the dropzone element itself will be clickable
                autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
                dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui i file o clicca per caricarli',
                dictResponseError: 'Caricamento fallito!',
                dictRemoveFile: 'Rimuovi file',
                dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
                dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti (max 4).',
                dictCancelUpload: 'Annulla caricamento',
                dictUploadCanceled: 'Il caricamento è stato annullato.',
                dictFileTooBig: 'La dimensione totale dei file è superiore ai 50 MB.',
                dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
                // success: function(file, msg){},
                error: function(file, error) {
                    // console.dir(error);
                    swal("Attenzione", error, "warning");
                    this.removeFile(file);
                }
            });

    return myDropzone;

}

/**
 * Dropzone initialization function (only images).
 *
 * @param {string} selector HTML selector
 * @param {string} url System route to update user data.
 *
 * @return Dropzone object.
 */
function initDropzoneBySelector(selector, url){

    // arr fila sent
    // var attachname = [];
    var myDropzone = new Dropzone( selector, {
                url: url,
                paramName: "file", // The name of the file param that gets transferred. Defaults to file
                uploadMultiple : true, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
                acceptedFiles: "image/*",
                maxFilesize: 50, // MB
                maxFiles: 4,
                parallelUploads: 4,
                resizeWidth: 1500,
                addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
                clickable: true, // If true, the dropzone element itself will be clickable
                autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
                dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui i file o clicca per caricarli',
                dictResponseError: 'Caricamento fallito!',
                dictRemoveFile: 'Rimuovi file',
                dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
                dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti (max 4).',
                dictCancelUpload: 'Annulla caricamento',
                dictUploadCanceled: 'Il caricamento è stato annullato.',
                dictFileTooBig: 'La dimensione totale dei file è superiore ai 50 MB.',
                dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
                // success: function(file, msg){},
                error: function(file, error) {
                    // console.dir(error);
                    swal("Attenzione", error, "warning");
                    this.removeFile(file);
                }
            });

    return myDropzone;

}

/**
 * Dropzone initialization function (images + other files).
 * 
 * @param {string} url System route to update user data.
 * 
 * @return Dropzone object.
 */
function initDropzoneFiles(url){
    console.log('initDropzoneFiles');

    // arr fila sent
    // var attachname = [];
    var myDropzone = new Dropzone(".dropzone", {
                url: url,
                paramName: "file", // The name of the file param that gets transferred. Defaults to file
                uploadMultiple : true, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
                acceptedFiles: "image/*, application/*, text/*",
                maxFilesize: 50, // MB
                maxFiles: 4,
                parallelUploads: 4,
                resizeWidth: 1500,
                addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
                clickable: true, // If true, the dropzone element itself will be clickable
                autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
                dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui i file o clicca per caricarli',
                dictResponseError: 'Caricamento fallito!',
                dictRemoveFile: 'Rimuovi file',
                dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
                dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti (max 4).',
                dictCancelUpload: 'Annulla caricamento',
                dictUploadCanceled: 'Il caricamento è stato annullato.',
                dictFileTooBig: 'La dimensione totale dei file è superiore ai 50 MB.',
                dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
                // success: function(file, msg){},
                error: function(file, error) {
                    // console.dir(error);
                    swal("Attenzione", error, "warning");
                    this.removeFile(file);
                }
            });

    return myDropzone;

}

/**
 * Dropzone initialization function (images + other files).
 *
 * @param {string} url System route to update user data.
 * @param {string} extensions list of accepted extensions
 *
 * @return Dropzone object.
 */
function initDropzoneSpecificFiles(url, extensions){

    // arr fila sent
    // var attachname = [];
    var myDropzone = new Dropzone(".dropzone", {
        url: url,
        paramName: "file", // The name of the file param that gets transferred. Defaults to file
        uploadMultiple : true, // If you have the option uploadMultiple set to true, then Dropzone will append [] to the name.
        acceptedFiles: extensions,
        maxFilesize: 50, // MB
        maxFiles: 4,
        parallelUploads: 4,
        resizeWidth: 1500,
        addRemoveLinks : true, // This will add a link to every file preview to remove or cancel (if already uploading) the file.                               // The dictCancelUpload, dictCancelUploadConfirmation and dictRemoveFile options are used for the wording.
        clickable: true, // If true, the dropzone element itself will be clickable
        autoProcessQueue: false, // When set to false you have to call myDropzone.processQueue() yourself in order to upload the dropped files
        dictDefaultMessage : '<i class="mdi mdi-image-filter-vintage"></i> Trascina qui i file o clicca per caricarli',
        dictResponseError: 'Caricamento fallito!',
        dictRemoveFile: 'Rimuovi file',
        dictInvalidFileType: 'Non è possibile caricare un file di questo formato.',
        dictMaxFilesExceeded: 'Hai raggiunto il massimo numero di file consentiti (max 4).',
        dictCancelUpload: 'Annulla caricamento',
        dictUploadCanceled: 'Il caricamento è stato annullato.',
        dictFileTooBig: 'La dimensione totale dei file è superiore ai 50 MB.',
        dictFallbackMessage: 'Questo browser non supporta il modulo di caricamento file.',
        // success: function(file, msg){},
        error: function(file, error) {
            // console.dir(error);
            swal("Attenzione", error, "warning");
            this.removeFile(file);
        }
    });

    return myDropzone;

}