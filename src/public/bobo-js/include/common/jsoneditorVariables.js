const jsonEditorlang = {
    'it': {
        appendText: 'Aggiungi',
        appendTitle: 'Aggiungi un nuovo campo con tipo \'auto\' dopo questo campo (Ctrl+Shift+Ins)',
        appendSubmenuTitle: 'Seleziona il tipo del campo da aggiungere',
        appendTitleAuto: 'Aggiungi un nuovo campo con tipo \'auto\' (Ctrl+Shift+Ins)',
        ascending: 'Asc',
        ascendingTitle: 'Ordina i figli di questo ${type} in ordine ascendente',
        actionsMenu: 'Click per aprire il menu (Ctrl+M)',
        cannotParseFieldError: 'Cannot parse field into JSON',
        cannotParseValueError: 'Cannot parse value into JSON',
        collapseAll: 'Chiudi tutti i campi',
        compactTitle: 'Compatta il JSON, rimuovi tutti gli spazi (Ctrl+Shift+I)',
        descending: 'Desc',
        descendingTitle: 'Ordina i figli di questo ${type} in ordine discendente',
        drag: 'Trascina per spostare questo campo (Alt+Shift+Arrows)',
        duplicateKey: 'duplicate key',
        duplicateText: 'Duplica',
        duplicateTitle: 'Duplica campi selezionati (Ctrl+D)',
        duplicateField: 'Duplica questo campo (Ctrl+D)',
        duplicateFieldError: 'Duplica nome campo',
        empty: 'vuoto',
        expandAll: 'Espandi tutti i campi',
        expandTitle: 'Click per espandere/chiudere questo campo (Ctrl+E). \n' +
          'Ctrl+Click per espandere/chiudere includendo tutti i figli.',
        formatTitle: 'Format JSON data, with proper indentation and line feeds (Ctrl+I)',
        insert: 'Inserisci',
        insertTitle: 'Inserisci nuovo campo di tipo \'auto\' prima di questo campo (Ctrl+Ins)',
        insertSub: 'Seleziona il tipo del campo da aggiungere',
        object: 'Oggetto',
        ok: 'Ok',
        redo: 'Redo (Ctrl+Shift+Z)',
        removeText: 'Rimuovi',
        removeTitle: 'Rimuovi campi selezionati (Ctrl+Del)',
        removeField: 'Rimuovi questo campo (Ctrl+Del)',
        repairTitle: 'Ripara JSON: correggi le virgolette e i caratteri di escape, rimuovi commenti e notazioni JSONP, converti oggetti JavaScript in JSON.',
        searchNextResultTitle: 'Risultato successivo (Enter)',
        searchPreviousResultTitle: 'Risultato precedente (Shift + Enter)',
        selectNode: 'Seleziona un nodo...',
        showAll: 'visualizza tutto',
        showMore: 'visualizza altro',
        showMoreStatus: ' ${visibleChilds} di ${totalChilds} elementi.',
        sort: 'Ordina',
        sortTitle: 'Ordina i figli di questo ${type}',
        sortTitleShort: 'Ordina contenuti',
        sortFieldLabel: 'Campo:',
        sortDirectionLabel: 'Direzione:',
        sortFieldTitle: 'Seleziona un campo annidato per cui ordinare l\'array o l\'oggetto',
        sortAscending: 'Asc',
        sortAscendingTitle: 'Ordina il campo selezionato in ascending order',
        sortDescending: 'Desc',
        sortDescendingTitle: 'Ordina il campo selezionato in descending order',
        string: 'String',
        transform: 'Trasforma',
        transformTitle: 'Filtra, ordina, o trasforma i figli di questo ${type}',
        transformTitleShort: 'Filtra, ordina, o trasforma i contenuti',
        extract: 'Estrai',
        extractTitle: 'Estrai questo ${type}',
        transformQueryTitle: 'Inserisci un JMESPath query',
        transformWizardLabel: 'Wizard',
        transformWizardFilter: 'Filtra',
        transformWizardSortBy: 'Ordina per',
        transformWizardSelectFields: 'Seleziona campi',
        transformQueryLabel: 'Query',
        transformPreviewLabel: 'Anteprima',
        type: 'Tipo',
        typeTitle: 'Cambia il tipo di questo campo',
        openUrl: 'Ctrl+Click o Ctrl+Enter per aprire l\'url in una nuova finestra',
        undo: 'Annulla ultima azione (Ctrl+Z)',
        validationCannotMove: 'Impossibile spostare il campo dentro un figlio di se stesso',
        autoType: 'Campo di tipo "auto". ' +
          'Il tipo del campo è automaticamente determinato dal valore ' +
          'e puè essere una stringa, un numero, un boolean o null.',
        objectType: 'Campo di tipo "object". ' +
          'Un oggetto contiene un set non ordinato di coppie chiave/valore.',
        arrayType: 'Campo di tipo "array". ' +
          'Un array contiene una collezione ordinata di valori.',
        stringType: 'Campo di tipo "string". ' +
          'Il tipo del campo non è determinato dal valore, ' +
          'ma è sempre impostato come stringa.',
        modeEditorTitle: 'Passa a Editor Mode',
        modeCodeText: 'Code',
        modeCodeTitle: 'Passa a code highlighter',
        modeFormText: 'Form',
        modeFormTitle: 'Passa a form editor',
        modeTextText: 'Text',
        modeTextTitle: 'Passa a plain text editor',
        modeTreeText: 'Tree',
        modeTreeTitle: 'Passa a tree editor',
        modeViewText: 'View',
        modeViewTitle: 'Passa a tree view',
        modePreviewText: 'Preview',
        modePreviewTitle: 'Passa a preview mode',
        examples: 'Esempi',
        default: 'Default',
        containsInvalidProperties: 'Contiene proprietà non valide',
        containsInvalidItems: 'Contiene elementi non validi'
    }
};

// http://json-schema.org/learn/getting-started-step-by-step
// https://json-schema.org/understanding-json-schema/index.html
const schemaParam = {
    "title": "Oggetto del parametro",
    "type": "object",
    "additionalProperties": true,
    "properties": {
        "general": {
            "type": "object",
            "additionalProperties": true,
            "properties": {
                "suffix": {
                    "description": "Suffisso usato nell'estrazione dei dati",
                    "type": [ "string", "null" ]
                },
                "treatment": {
                    "description": "Trattamento con cui estrarre i dati",
                    "enum": ["sum", "avg", "min", "max", "cum", "sldavg", "first"]
                },
                "max": {
                    "description": "Limite massimo usato da Avanzate Visualizer",
                    "type": [ "number", "null" ]
                },
                "min": {
                    "description": "Limite minimo usato da Avanzate Visualizer",
                    "type": [ "number", "null" ]
                },
                "windroseV": {
                    "description": "Velocità vento da usare nei grafici windrose",
                    "type": "boolean"
                },
                "windroseD": {
                    "description": "Direzione vento da usare nei grafici windrose",
                    "type": "boolean"
                },
                "dataview_flag": {
                    "description": "Parametro visibile su Dataview",
                    "type": "boolean"
                },
                "dataview_live": {
                    "description": "Parametro visibile su Dati Live",
                    "type": "boolean"
                },
                "dataview_indicator": {
                    "description": "Parametro visibile su Indicatori",
                    "type": "boolean"
                },
                "dataview_labels": {
                    "description": "Etichette visualizzate su Dataview",
                    "type": "array",
                    "items": {
                        "type": "object",
                        "additionalProperties": false,
                        "properties": {
                            "big": {
                                "type": "string"
                            },
                            "little": {
                                "type": "string"
                            },
                            "target": {
                                "type": "string",
                                "enum": ["live", "indicator"]
                            },
                            "aggregation": {
                                "type": "string",
                                "enum": ["hh", "dd"]
                            },
                            "stat_id": {
                                "type": [ "number", "null" ]
                            },
                            "order":{
                                "type": [ "number", "null" ]
                            }
                        },
                        "required": [ "big", "little", "target", "aggregation" ]
                    },
                    "minItems": 1,
                    "uniqueItems": true
                },
                // "if": {
                //     "properties": { "dataview_flag": { "const": true } },
                //     "required": ["dataview_flag"]
                // },
                // "then": {
                //     "required": [ "dataview_labels" ]
                // }
            }
        }
    }
};

const templateParam = [
    {
        text: 'Base',
        title: 'Crea oggetto vuoto',
        className: 'jsoneditor-type-object',
        field: 'general',
        value: {
            "suffix": null,
            "treatment": "avg",
            "max": null,
            "min": null,
            "windroseV": false,
            "windroseD": false,
            "dataview_flag": false,
            "dataview_live": false,
            "dataview_indicator": false,
            "dataview_labels": []
        }
    },
    {
        text: 'Etichette Dataview',
        title: 'Crea oggetto vuoto',
        className: 'jsoneditor-type-object',
        field: 'dataview_labels',
        value: {
            "big": "",
            "little": "",
            "target": "live",
            "aggregation": "hh",
            "stat_id": null,
            "order": null,

        }
    }
];