// GENERAL OPTIONs
moment.locale('it');
moment.tz.setDefault('Europe/Rome');
moment.modifyHolidays.set('Italy');

// GENERAL UTILITIES
if($.fn.tooltip.Constructor != null)
    $.fn.tooltip.Constructor.Default.boundary = 'window';

/**
 * Set timeout to hide tooltip when has been made visible to the user.
 */
$(document).on('shown.bs.tooltip', function (e) {
    setTimeout(function () {
        $(e.target).tooltip('hide');
    }, 6000);
});


/**
 * Validation method: check field by regular expression.
 * 
 * @param {string}       value User insert value.
 * @param {html_element} element HTML element containig the value.
 * @param {regexp}       regexp Regular expression to match.
 * 
 * @return If match, the value;
 *         If not, the alert message.
 */
$.validator.addMethod(
    // don't use \d but always [0-9]
    "regex",
    function(value, element, regexp) {
        var re = new RegExp(regexp);
        return this.optional(element) || re.test(value);
    },
    "Inserire campo in un formato valido"
);

/**
 * Validation method: check that insert decimal number has only the dot as separator and 6 decimals digits maximum.
 * 
 * @param {double}       value User insert value.
 * @param {html_element} element HTML element containig the value (callback variable).
 * @param {boolean}      flag Boolean value indicating if the dot have to be the decimal separator.
 * 
 * @return If TRUE, the value;
 *         If FALSE, the alert message.
 */
$.validator.addMethod(
    "dotSeparator",
    function(value, element, flag) {
        var re = new RegExp('^\-?[0-9]*$|^\-?[0-9]+[.][0-9]{1,6}$');
        return re.test(value) == flag;
    },
    "Inserire numero valido (separatore dec. PUNTO, max 6 decimali)"
);

/**
 * Validation method: check date format.
 * 
 * @param {date}         value User insert value.
 * @param {html_element} element HTML element containig the value.
 * 
 * @return If the format is correct (DD/MM/YYYY [HH:mm]), the value;
 *         If not, the alert message.
 */
$.validator.addMethod(
    "validDate",
    function(value, element) {
        return this.optional(element) || moment(value,"DD/MM/YYYY").isValid() || moment(value,"DD/MM/YYYY HH:mm").isValid();
    },
    "Inserire una data valida nel formato DD/MM/YYYY [HH:mm]"
);

/**
 * Validation method: check the provided coordinates.
 * 
 * @param {coordinate}   value User insert value.
 * @param {html_element} element HTML element containig the value.
 * 
 * @return If the coordinates are inside the "Italy display" limits, the value;
 *         If not, the alert message.
 */
$.validator.addMethod(
    "validWGS84Coords",
    function(value, element) {
        // Italy display limit coordinates
        var swLat = 36.137;
        var swLong = 6.350;
        var neLat = 47.070;
        var neLong = 18.435;

        return this.optional(element) || ( value >= swLat && value <= neLat ) || ( value >= swLong && value <= neLong);
    },
    "Inserire delle coordinate valide [WGS84 °N]"
);

/**
 * Function to check if the start and end dates of the entered period are valid.
 * 
 * @param {date}    start Period start date.
 * @param {date}    end Period end date.
 * @param {html_id} workingDate HTML id.
 * 
 * @return {boolean}
 */
function validDates(start, end, workingDate){

    var flagCheck = true;
    var dateFormat = 'DD/MM/YYYY';

    // check date format
    if(start.length > 10 && end.length > 10){
        dateFormat = 'DD/MM/YYYY HH:mm';
    }

    console.log(start);
    console.log(end);
    console.log(dateFormat);

    // check start date
    if(
        ! moment(start, dateFormat, true).isValid() ||
        moment(start, dateFormat).isBefore('1900-01-01 00:00') ||
        moment(start, dateFormat).isAfter( moment() )
    )
    {
        console.log('dateFrom error');
        $('#date-start').addClass('error-date');
        flagCheck = flagCheck && false;
    }
    else{
        console.log('dateFrom valid');
        $('#date-start').removeClass('error-date');
    }

    // check end date
    if(
        ! moment(end, dateFormat, true).isValid() ||
        moment(end, dateFormat).isBefore('1900-01-01 00:00') ||
        moment(end, dateFormat).isAfter( moment().format('YYYY-MM-DD 23:59') )
    )
    {
        console.log('dateTo error');
        $('#date-end').addClass('error-date');
        flagCheck = flagCheck && false;
    }
    else{
        console.log('dateTo valid');
        $('#date-end').removeClass('error-date');
    }

    // check range validity
    if( moment(start, dateFormat).isAfter(moment(end, dateFormat)) )
    {
        console.log('dateFrom-dateTo error');
        $('#'+workingDate).addClass('error-date');
        flagCheck = flagCheck && false;
    }

    if( flagCheck )
        $('#'+workingDate).removeClass('error-date');

    return flagCheck;
}


/**
 * Change first letter of a string to upper case.
 */ 
String.prototype.capitalize = function() {
    return this.charAt(0).toUpperCase() + this.slice(1);
}

/**
 * Function for left padding a number with '0'
 */
String.prototype.leftPad = function(len) {
    var output = this;
    while (output.length < len) {
        output = '0' + output;
    }
    return output;
}

// highcharts/highstock options
// https://www.highcharts.com/docs/chart-concepts/security
Highcharts.AST.allowedAttributes.push('data-toggle');
Highcharts.AST.allowedAttributes.push('data-target');
Highcharts.AST.allowedAttributes.push('data-toggle-second');
Highcharts.AST.allowedAttributes.push('data-original-title');

/**
 * Setting Highcharts display options (vocabulary).
 */ 
Highcharts.setOptions({
    time: {
        useUTC: true
    },
    lang: {
        months: ['Gennaio', 'Febbraio', 'Marzo', 'Aprile', 'Maggio', 'Giugno',
            'Luglio', 'Agosto', 'Settembre', 'Ottobre', 'Novembre', 'Dicembre'],
        shortMonths : ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'],
        weekdays: ['Domenica', 'Lunedi', 'Martedi', 'Mercoledi', 'Giovedi', 'Venerdi', 'Sabato'],
        loading: 'Caricamento...',
        printChart: 'Stampa',
        rangeSelectorFrom: 'Da',
        rangeSelectorTo: 'A',
        resetZoom: 'Indietro',
        downloadCSV: 'CSV',
        downloadJPEG:'JPEG',
        downloadPDF: 'PDF',
        downloadPNG: 'PNG',
        downloadSVG: 'SVG',
        downloadXLS: 'XLS',
        noData: 'Nessun dato disponibile',
        viewFullscreen: 'Schermo intero',
        exitFullscreen: 'Esci da schermo intero'
    },
    exporting: {
        enabled: true,
        buttons: {
            contextButton: {
                menuItems: ["viewFullscreen", "printChart", "separator", "downloadCSV", "downloadPNG", "downloadSVG"]
            }
        }
    },
    chart: {
        backgroundColor: '#FFF'
    },
    tooltip: {
        // enabled: false,
        valueDecimals: 2
    },
    legend: {
        layout: 'horizontal',
        align: 'center'
    },
    colors: ['#15598f', '#da3a89', '#7f7f7f', '#009cb6', '#222222', '#674b97', '#3b7c46', '#e16837', '#edd325', '#b6323c', '#80ba56', '#69c1d3', '#692f1b', '#c8c8c8', '#a34a94', '#abb64f', '#41b2a0', '#c1873e', '#e89ec0', '#9dcca5', '#a2455f', '#3e6882', '#979dca', '#e99261', '#6f4e2b', '#40bded', '#742249', '#004b47']
});

/**
 * Setting Tabulator display language to Italian.
 */ 
Tabulator.extendModule("localize", "langs", {
    "it":{
        "data":{
            "loading":"Caricamento...", //ajax loader text
            "error":"Errore", //ajax error text
        },
        "pagination":{
            "page_size":"Numero righe per pagina",
            "first":"Inizio",
            "first_title":"Prima pagina",
            "last":"Fine",
            "last_title":"Ultima pagina",
            "prev":"Prec",
            "prev_title":"Pagina precedente",
            "next":"Succ",
            "next_title":"Pagina sucessiva",
            "all":"Tutti"
        }
    }
});

var dateRangePickerSettings = {
    "locale": {
        "format": "DD/MM/YYYY",
        "separator": " - ",
        "applyLabel": "Applica",
        "cancelLabel": "Annulla",
        "fromLabel": "Da",
        "toLabel": "A",
        "customRangeLabel": "Personalizza",
        "daysOfWeek": [
            "Do",
            "Lu",
            "Ma",
            "Me",
            "Gi",
            "Ve",
            "Sa"
        ],
        "monthNames": [
            "Gennaio",
            "Febbraio",
            "Marzo",
            "Aprile",
            "Maggio",
            "Giugno",
            "Luglio",
            "Agosto",
            "Settembre",
            "Ottobre",
            "Novembre",
            "Dicembre"
        ],
        "firstDay": 1,
    }
};


/**
 * Setting Datatable display language to Italian.
 */
$.extend( $.fn.dataTable.defaults, {
    language: {
        "infoFiltered": "(filtrati da _MAX_ elementi totali)",
        "infoThousands": ".",
        "loadingRecords": "Caricamento...",
        "processing": "Elaborazione...",
        "search": "Cerca:",
        "paginate": {
            "first": "Inizio",
            "previous": "Prec.",
            "next": "Succ.",
            "last": "Fine"
        },
        "aria": {
            "sortAscending": ": attiva per ordinare la colonna in ordine crescente",
            "sortDescending": ": attiva per ordinare la colonna in ordine decrescente"
        },
        "autoFill": {
            "cancel": "Annulla",
            "fill": "Riempi tutte le celle con <i>%d<\/i>",
            "fillHorizontal": "Riempi celle orizzontalmente",
            "fillVertical": "Riempi celle verticalmente"
        },
        "buttons": {
            "collection": "Collezione <span class=\"ui-button-icon-primary ui-icon ui-icon-triangle-1-s\"><\/span>",
            "colvis": "Visibilità Colonna",
            "colvisRestore": "Ripristina visibilità",
            "copy": "Copia",
            "copyKeys": "Premi ctrl o u2318 + C per copiare i dati della tabella nella tua clipboard di sistema.<br \/><br \/>Per annullare, clicca questo messaggio o premi ESC.",
            "copySuccess": {
                "1": "Copiata 1 riga nella clipboard",
                "_": "Copiate %d righe nella clipboard"
            },
            "copyTitle": "Copia nella Clipboard",
            "csv": "CSV",
            "excel": "Excel",
            "pageLength": {
                "-1": "Mostra tutte le righe",
                "_": "Mostra %d righe"
            },
            "pdf": "PDF",
            "print": "Stampa",
            "createState": "Crea stato",
            "removeAllStates": "Rimuovi tutti gli stati",
            "removeState": "Rimuovi",
            "renameState": "Rinomina",
            "savedStates": "Salva stato",
            "stateRestore": "Ripristina stato",
            "updateState": "Aggiorna"
        },
        "emptyTable": "Nessun dato disponibile nella tabella",
        "info": "Risultati da _START_ a _END_ di _TOTAL_ elementi",
        "infoEmpty": "Risultati da 0 a 0 di 0 elementi",
        "lengthMenu": "Mostra _MENU_ elementi",
        "searchBuilder": {
            "add": "Aggiungi Condizione",
            "button": {
                "0": "Generatore di Ricerca",
                "_": "Generatori di Ricerca (%d)"
            },
            "clearAll": "Pulisci Tutto",
            "condition": "Condizione",
            "conditions": {
                "date": {
                    "after": "Dopo",
                    "before": "Prima",
                    "between": "Tra",
                    "empty": "Vuoto",
                    "equals": "Uguale A",
                    "not": "Non",
                    "notBetween": "Non Tra",
                    "notEmpty": "Non Vuoto"
                },
                "number": {
                    "between": "Tra",
                    "empty": "Vuoto",
                    "equals": "Uguale A",
                    "gt": "Maggiore Di",
                    "gte": "Maggiore O Uguale A",
                    "lt": "Minore Di",
                    "lte": "Minore O Uguale A",
                    "not": "Non",
                    "notBetween": "Non Tra",
                    "notEmpty": "Non Vuoto"
                },
                "string": {
                    "contains": "Contiene",
                    "empty": "Vuoto",
                    "endsWith": "Finisce Con",
                    "equals": "Uguale A",
                    "not": "Non",
                    "notEmpty": "Non Vuoto",
                    "startsWith": "Inizia Con",
                    "notContains": "Non Contiene",
                    "notStartsWith": "Non Inizia Con",
                    "notEndsWith": "Non Finisce Con"
                },
                "array": {
                    "equals": "Uguale A",
                    "empty": "Vuoto",
                    "contains": "Contiene",
                    "not": "Non",
                    "notEmpty": "Non Vuoto",
                    "without": "Senza"
                }
            },
            "data": "Dati",
            "deleteTitle": "Elimina regola filtro",
            "leftTitle": "Criterio di Riduzione Rientro",
            "logicAnd": "E",
            "logicOr": "O",
            "rightTitle": "Criterio di Aumento Rientro",
            "title": {
                "0": "Generatore di Ricerca",
                "_": "Generatori di Ricerca (%d)"
            },
            "value": "Valore"
        },
        "searchPanes": {
            "clearMessage": "Pulisci Tutto",
            "collapse": {
                "0": "Pannello di Ricerca",
                "_": "Pannelli di Ricerca (%d)"
            },
            "count": "{total}",
            "countFiltered": "{shown} ({total})",
            "emptyPanes": "Nessun Pannello di Ricerca",
            "loadMessage": "Caricamento Pannello di Ricerca",
            "title": "Filtri Attivi - %d",
            "showMessage": "Mostra tutto",
            "collapseMessage": "Espandi tutto"
        },
        "select": {
            // "cells": {
            //     "1": "1 cella selezionata",
            //     "_": "%d celle selezionate"
            // },
            // "columns": {
            //     "1": "1 colonna selezionata",
            //     "_": "%d colonne selezionate"
            // },
            "rows": {
                "1": "1 riga selezionata",
                "_": "%d righe selezionate"
            }
        },
        "zeroRecords": "Nessun elemento corrispondente trovato",
        "datetime": {
            "amPm": [
                "am",
                "pm"
            ],
            "hours": "ore",
            "minutes": "minuti",
            "next": "successivo",
            "previous": "precedente",
            "seconds": "secondi",
            "unknown": "sconosciuto",
            "weekdays": [
                "Dom",
                "Lun",
                "Mar",
                "Mer",
                "Gio",
                "Ven",
                "Sab"
            ],
            "months": [
                "Gennaio",
                "Febbraio",
                "Marzo",
                "Aprile",
                "Maggio",
                "Giugno",
                "Luglio",
                "Agosto",
                "Settembre",
                "Ottobre",
                "Novembre",
                "Dicembre"
            ]
        },
        "editor": {
            "close": "Chiudi",
            "create": {
                "button": "Nuovo",
                "submit": "Aggiungi",
                "title": "Aggiungi nuovo elemento"
            },
            "edit": {
                "button": "Modifica",
                "submit": "Modifica",
                "title": "Modifica elemento"
            },
            "error": {
                "system": "Errore del sistema."
            },
            "multi": {
                "info": "Gli elementi selezionati contengono valori diversi. Per modificare e impostare tutti gli elementi per questa selezione allo stesso valore, premi o clicca qui, altrimenti ogni cella manterrà il suo valore attuale.",
                "noMulti": "Questa selezione può essere modificata individualmente, ma non se fa parte di un gruppo.",
                "restore": "Annulla le modifiche",
                "title": "Valori multipli"
            },
            "remove": {
                "button": "Rimuovi",
                "confirm": {
                    "_": "Sei sicuro di voler cancellare %d righe?",
                    "1": "Sei sicuro di voler cancellare 1 riga?"
                },
                "submit": "Rimuovi",
                "title": "Rimuovi"
            }
        },
        "thousands": ".",
        "decimal": ",",
        "stateRestore": {
            "creationModal": {
                "button": "Crea",
                "columns": {
                    "search": "Colonna Cerca",
                    "visible": "Colonna Visibilità"
                },
                "name": "Nome:",
                "order": "Ordinamento",
                "paging": "Paginazione",
                "scroller": "Scorri posizione",
                "search": "Ricerca",
                "searchBuilder": "Form di Ricerca",
                "select": "Seleziona",
                "title": "Crea nuovo Stato",
                "toggleLabel": "Includi:"
            },
            "duplicateError": "Nome stato già presente",
            "emptyError": "Il nome è obbligatorio",
            "emptyStates": "Non ci sono stati salvati",
            "removeConfirm": "Sei sicuro di eliminare lo Stato %s?",
            "removeError": "Errore durante l'eliminazione dello Stato",
            "removeJoiner": "e",
            "removeSubmit": "Elimina",
            "removeTitle": "Elimina Stato",
            "renameButton": "Rinomina",
            "renameLabel": "Nuovo nome per %s:",
            "renameTitle": "Rinomina Stato"
        }
    }
});

// UTILITIES
/**
 * In case of device, check if orientation is in portrait mode or landscape.
 */ 
function isPortrait() {
    return window.innerHeight > window.innerWidth;
}

/**
 * Function to define the Select2 search and match feature in grouped options.
 * @link https://select2.org/searching#matching-grouped-options
 * 
 * @param {object} params Select2's search terms insert by the user.
 * @param {object} data Select2's data.
 */ 
function searchGroupedSelect2 (params, data) {
    // If there are no search terms, return all of the data
    var term = params.term;
    if ($.trim(term) === '') {
        return data;
    }

    // Skip if there is no 'children' property
    if (typeof data.children === 'undefined') {
        return null;
    }

    var searchStrings = term.split(' ');

    var labelGroup = data.text;
    var filteredChildren = [];
    $.each(data.children, function (idx, child) {

        // if (allText.toUpperCase().indexOf(term.toUpperCase()) >= 0) {
        //     filteredChildren.push(child);
        // }
        // console.dir(child);
        var allText = labelGroup +' '+ child.text+' '+child.id;
        var flag = searchStrings.every(function(txt){
            allText = allText.normalize('NFD').replace(/[\u0300-\u036f]/g, "");
            return allText.toUpperCase().indexOf(txt.toUpperCase())>= 0
        });

        if(flag)
            filteredChildren.push(child);
    });

    // If we matched any of the timezone group's children, then set the matched children on the group
    // and return the group object
    if (filteredChildren.length) {
        var modifiedData = $.extend({}, data, true);
        modifiedData.children = filteredChildren;

        // You can return modified objects from here
        // This includes matching the `children` how you want in nested data sets
        return modifiedData;
    }

    // Return `null` if the term should not be displayed
    return null;
}

// Manage DATETIMEs
$.fn.dataTable.moment('DD-MM-YYYY');

// basic [DD-MM-YYYY]
// basic_range [da HH a HH+1],
// basic_rangeMin [da HH:mm a HH+1:mm],
// basic_timeStart [00-23],
// basic_timeEnd [01-24],
// basic_timeStartMin [HH:mm],
// basic_timeEndMin [HH+1:mm]

// text [21 Marzo 2019]
// text_range [da HH a HH+1],
// text_rangeMin [da HH:mm a HH+1:mm],
// text_timeStart [00-23],
// text_timeEnd [01-24],
// text_timeStartMin [HH:mm],
// text_timeEndMin [HH:mm]

/**
 * Get formatted datetime for DataTable.
 * 
 * @param {date}   fulldate Datetime to be formatted.
 * @param {string} format Date format to be applied.
 */ 
function getFormattedDateDT(fulldate, format){

    // ATTENZIONE! ora in stazione utc-1, ma dati targati con ora di inizio come se fosse utc

    var formattedDate;

    switch(format) {
        case 'basic':
            $.fn.dataTable.moment('DD/MM/YYYY');
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY');
        break;
        case 'basic_range':
             $.fn.dataTable.moment('DD/MM/YYYY [h]. HH[-]mm');
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY [h]. HH')+'-'+moment.utc(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'basic_rangeMin':
             $.fn.dataTable.moment('DD/MM/YYYY HH:mm-kk:ss');
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY HH:mm')+'-'+moment.utc(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'basic_timeStart':
            $.fn.dataTable.moment('DD/MM/YYYY HH');
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY HH');
        break;
        case 'basic_timeStartMin':
            $.fn.dataTable.moment('DD/MM/YYYY HH:mm');
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY HH:mm');
        break;
        case 'basic_timeEnd':
            $.fn.dataTable.moment('DD/MM/YYYY HH');
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('DD/MM/YYYY HH').replace('00', '24');
        break;
        case 'basic_timeEndMin':
            $.fn.dataTable.moment('DD/MM/YYYY HH:mm');
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('DD/MM/YYYY HH:mm').replace('00:', '24:');
        break;

        case 'text':
            formattedDate = moment.utc(fulldate).format('LL');
        break;
        case 'text_month':
            formattedDate = moment.utc(fulldate).format('MMMM YYYY').capitalize();
        break;
        case 'text_range':
            formattedDate = moment.utc(fulldate).format('LL HH')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'text_rangeMin':
            formattedDate = moment.utc(fulldate).format('LL HH:mm')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'text_timeStart':
            formattedDate = moment.utc(fulldate).format('LL HH');
        break;
        case 'text_timeStartMin':
            formattedDate = moment.utc(fulldate).format('LL HH:mm');
        break;
        case 'text_timeEnd':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('LL HH').replace('00', '24');
        break;
        case 'text_timeEndMin':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('LL HH:mm').replace('00:', '24:');
        break;
        default:
            console.log('Formato non presente');
        break;
    }

    return formattedDate;
}

/**
 * Get formatted datetime for HighCharts.
 * 
 * @param {date}   fulldate Datetime to be formatted.
 * @param {string} format Date format to be applied.
 */ 
function getFormattedDateHC(fulldate, format){

    // ATTENZIONE! ora in stazione utc-1, ma dati targati con ora di inizio come se fosse utc
    var formattedDate;

    switch(format) {
        case 'basic':
            formattedDate = moment.utc(fulldate).format('DD/MM<br>YYYY');
        break;
        case 'basic_range':
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY<br>HH')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'basic_rangeMin':
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY<br>HH:mm')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'basic_timeStart':
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY<br>HH');
        break;
        case 'basic_timeStartMin':
            formattedDate = moment.utc(fulldate).format('DD/MM/YYYY<br>HH:mm');
        break;
        case 'basic_timeEnd':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('DD/MM/YYYY<br>HH').replace('00', '24');
        break;
        case 'basic_timeEndMin':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('DD/MM/YYYY<br>HH:mm').replace('00:', '24:');
        break;
        case 'text':
            formattedDate = moment.utc(fulldate).format('LL');
        break;
        case 'text_range':
            formattedDate = moment.utc(fulldate).format('LL<br>HH')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'text_rangeMin':
            formattedDate = moment.utc(fulldate).format('LL<br>HH:mm')+' a '+moment.utc(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'text_timeStart':
            formattedDate = moment.utc(fulldate).format('LL HH');
        break;
        case 'text_timeStartMin':
            formattedDate = moment.utc(fulldate).format('LL<br>HH:mm');
        break;
        case 'text_timeEnd':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('LL HH').replace('00', '24');
        break;
        case 'text_timeEndMin':
            formattedDate = moment.utc(fulldate).add('+1', 'hours').format('LL<br>HH:mm').replace('00:', '24:');
        break;
        default:
            console.log('Formato non presente');
        break;
    }

    return formattedDate;
}

/**
 * Get formatted datetime.
 * 
 * @param {date}   fulldate Datetime to be formatted.
 * @param {string} format Date format to be applied.
 */ 
function getFormattedDatePublic(fulldate, format){

   var formattedDate;

    switch(format) {
        case 'basic':
            $.fn.dataTable.moment('DD/MM/YYYY');
            formattedDate = moment(fulldate).format('DD/MM/YYYY');
        break;
        case 'basic_range':
             $.fn.dataTable.moment('DD/MM/YYYY [h]. HH-mm');
            formattedDate = moment(fulldate).format('DD/MM/YYYY [h]. HH')+'-'+moment(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'basic_rangeMin':
             $.fn.dataTable.moment('DD/MM/YYYY HH:mm-kk:ss');
            formattedDate = moment(fulldate).format('DD/MM/YYYY HH:mm')+'-'+moment(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'basic_timeStart':
            $.fn.dataTable.moment('DD/MM/YYYY HH');
            formattedDate = moment(fulldate).format('DD/MM/YYYY HH');
        break;
        case 'basic_timeStartMin':
            $.fn.dataTable.moment('DD/MM/YYYY HH:mm');
            formattedDate = moment(fulldate).format('DD/MM/YYYY HH:mm');
        break;
        case 'basic_timeEnd':
            $.fn.dataTable.moment('DD/MM/YYYY HH');
            formattedDate = moment(fulldate).add('+1', 'hours').format('DD/MM/YYYY HH').replace('00', '24');
        break;
        case 'basic_timeEndMin':
            $.fn.dataTable.moment('DD/MM/YYYY HH:mm');
            formattedDate = moment(fulldate).add('+1', 'hours').format('DD/MM/YYYY HH:mm').replace('00:', '24:');
        break;

        case 'text':
            formattedDate = moment(fulldate).format('LL');
        break;
        case 'text_range':
            formattedDate = moment(fulldate).format('LL HH')+' a '+moment(fulldate).add('+1', 'hours').format('HH').replace('00', '24');
        break;
        case 'text_rangeMin':
            formattedDate = moment(fulldate).format('LL HH:mm')+' a '+moment(fulldate).add('+1', 'hours').format('HH:mm').replace('00:', '24:');
        break;
        case 'text_timeStart':
            formattedDate = moment(fulldate).format('LL HH');
        break;
        case 'text_timeStartMin':
            formattedDate = moment(fulldate).format('LL HH:mm');
        break;
        case 'text_timeEnd':
            formattedDate = moment(fulldate).add('+1', 'hours').format('LL HH').replace('00', '24');
        break;
        case 'text_timeEndMin':
            formattedDate = moment(fulldate).add('+1', 'hours').format('LL HH:mm').replace('00:', '24:');
        break;
        default:
            console.log('Formato non presente');
        break;
    }

    return formattedDate;
}