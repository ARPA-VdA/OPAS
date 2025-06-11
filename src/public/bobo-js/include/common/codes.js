var tblPer, tblAuto, tblVal, tblFin;

$(document).ready(function() {

    tblPer = $('#tbl-cod-per').DataTable({
        "dom": "Bfrtip",
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "order": [[ 0, "asc" ]],
        "columnDefs": [{ className: 'text-center', targets: [0,2,3] }],
        "language": {
            "url": "/bobo-js/italian.json"
        }
    });

    tblAuto = $('#tbl-cod-auto').DataTable({
        "dom": "Bfrtip",
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "order": [[ 0, "asc" ]],
        "columnDefs": [{ className: 'text-center', targets: [0, 2, 3] }],
        "language": {
            "url": "/bobo-js/italian.json"
        }
    });

    tblVal = $('#tbl-cod-val').DataTable({
        "dom": "Bfrtip",
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "order": [[ 0, "asc" ]],
        "columnDefs": [{ className: 'text-center', targets: [0, 2, 3] }],
        "language": {
            "url": "/bobo-js/italian.json"
        }
    });

    tblFin = $('#tbl-cod-fin').DataTable({
        "dom": "Bfrtip",
        // 'copy', 'csv', 'excel', 'pdf', 'print'
        "buttons": [
            'csv',
            'pdf',
            {
                "extend": 'print',
                "text": 'STAMPA'
            }
        ],
        "order": [[ 0, "asc" ]],
        "columnDefs": [{ className: 'text-center', targets: [0, 2, 3] }],
        "language": {
            "url": "/bobo-js/italian.json"
        }
    });

    loadCodes();
});

function loadCodes(){
    $('.inner-preloader').show();

    // get models
    var jqxhr = $.ajax({
        url: '/dat_val_get_codes',
        type: "post",
        dataType: "json",
        data: {
        },
    })
    .done(function(result) {
        // console.log('codici di invalidazione')
        // console.dir(result);

        if ( tblPer )
            tblPer.clear();

        // variable that contains the periphery codes
        var periphery = result.periphery;
        console.dir(periphery);

        if(periphery.length == 0 ){
            $('#codes-tab a[href="#tab-cod-per"]').hide();
            $('#codes-tab a[href="#tab-cod-auto"]').tab('show');
        }
        else{
            // for each codes line create a row to attach at the main table
            $.each(periphery, function(index, value) {
                if(value.pvc_code_valid == 1){
                    var valid = '<i class="icon-check text-info" data-toggle="tooltip" data-placement="top" data-original-title="Codice valido"></i><span>valido</span>';
                }else{
                    var valid = '<i class="icon-close text-danger" data-toggle="tooltip" data-placement="top" data-original-title="Codice NON valido"></i><span>NON valido</span>';
                }
                if(value.pvc_code_default == 1){
                    var def = '<i class="ti-check-box text-success" data-toggle="tooltip" data-placement="top" data-original-title="Codice di default"></i><span>default</span>';
                }else{
                    var def = '';
                }
                tblPer.row.add( [  value.pvc_code_id, value.pvc_code_desc, valid, def ] ).draw();

            });
            tblPer.columns.adjust();

            // re-initialize tooltip plugin
            tblPer.rows({ page: 'all' }).every(function () { // the containers for all your galleries
                var row = this;
                // get all tr node and transform it into a jquery items
                // in order to find all tooltip elements
                $(row.node())
                    .find('[data-toggle="tooltip"]')
                    .tooltip();
            });
        }


        if ( tblAuto )
            tblAuto.clear();

        // variable that contains the auto validation codes
        var autoval = result.autoval;
        console.dir(autoval);

        // for each codes line create a row to attach at the main table
        $.each(autoval, function(index, value) {
            if(value.avc_code_valid == 1){
                var valid = '<i class="icon-check text-info" data-toggle="tooltip" data-placement="top" data-original-title="Codice valido"></i><span>valido</span>';
            }else{
                var valid = '<i class="icon-close text-danger" data-toggle="tooltip" data-placement="top" data-original-title="Codice NON valido"></i><span>NON valido</span>';
            }
            if(value.avc_code_default == 1){
                var def = '<i class="ti-check-box text-success" data-toggle="tooltip" data-placement="top" data-original-title="Codice di default"></i><span>default</span>';
            }else{
                var def = '';
            }
            tblAuto.row.add( [  value.avc_code_id, value.avc_code_desc, valid, def ] ).draw();
        });
        tblAuto.columns.adjust();

        // re-initialize tooltip plugin
        tblAuto.rows({page: 'all'}).every(function() { // the containers for all your galleries
            var row = this;
            // get all tr node and transform it into a jquery items
            // in order to find all tooltip elements
            $(row.node())
                .find('[data-toggle="tooltip"]')
                .tooltip();
        });


        if ( tblVal )
            tblVal.clear();

        // variable that contains the user validation codes
        var userval = result.userval;
        console.dir(userval);

        // for each codes line create a row to attach at the main table
        $.each(userval, function(index, value) {
            if(value.uvc_code_valid == 1){
                var valid = '<i class="icon-check text-info" data-toggle="tooltip" data-placement="top" data-original-title="Codice valido"></i><span>valido</span>';
            }else{
                var valid = '<i class="icon-close text-danger" data-toggle="tooltip" data-placement="top" data-original-title="Codice NON valido"></i><span>NON valido</span>';
            }
            if(value.uvc_code_default == 1){
                var def = '<i class="ti-check-box text-success" data-toggle="tooltip" data-placement="top" data-original-title="Codice di default"></i><span>default</span>';
            }else{
                var def = '';
            }
            tblVal.row.add( [  value.uvc_code_id, value.uvc_code_desc, valid, def ] ).draw();
        });
        tblVal.columns.adjust();

        // re-initialize tooltip plugin
        tblVal.rows({page: 'all'}).every(function() { // the containers for all your galleries
            var row = this;
            // get all tr node and transform it into a jquery items
            // in order to find all tooltip elements
            $(row.node())
                .find('[data-toggle="tooltip"]')
                .tooltip();
        });


        if ( tblFin )
            tblFin.clear();

        // variable that contains the final validation codes
        var finalval = result.finalval;
        console.dir(finalval);

        var html = '';
        html += '<tr>';
        html += '    <td class="text-center">0</td>';
        html += '    <td>Non validato</td>';
        html += '    <td></td>';
        html += '    <td class="text-center"><i class="icon-close text-danger" data-toggle="tooltip" data-placement="top" data-original-title="Codice NON valido"></i><span>NON valido</span></td>';
        html += '    <td class="text-center"><i class="ti-check-box text-success" data-toggle="tooltip" data-placement="top" data-original-title="Codice di default"></i><span>default</span></td>';
        html += '</tr>';

        tblFin.row.add($( html ));

        // for each codes line create a row to attach at the main table
        $.each(finalval, function(index, value) {
            if(value.fvc_code_valid == 1){
                var valid = '<i class="icon-check text-info" data-toggle="tooltip" data-placement="top" data-original-title="Codice valido"></i><span>valido</span>';
            }else{
                var valid = '<i class="icon-close text-danger" data-toggle="tooltip" data-placement="top" data-original-title="Codice NON valido"></i><span>NON valido</span>';
            }
            if(value.fvc_code_default == 1){
                var def = '<i class="ti-check-box text-success" data-toggle="tooltip" data-placement="top" data-original-title="Codice di default"></i><span>default</span>';
            }else{
                var def = '';
            }

            var color = '<div class="valid-level code-'+value.fvc_code_id+'"></div>';

            tblFin.row.add( [  value.fvc_code_id, value.fvc_code_desc, color, valid, def ] ).draw();
        });
        tblFin.columns.adjust();


        // re-initialize tooltip plugin
        tblFin.rows({page: 'all'}).every(function() { // the containers for all your galleries
            var row = this;
            // get all tr node and transform it into a jquery items
            // in order to find all tooltip elements
            $(row.node())
                .find('[data-toggle="tooltip"]')
                .tooltip();
        });

        // close the preloader's div
        $('.inner-preloader').hide();

    })
    .fail(function(xhr, err) {
        swal("Errore!", "Errore durante il recupero dei codici di validazione", "error");
        // close the preloader's div
        $('.inner-preloader').hide();
    });

    return;
}