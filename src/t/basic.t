use Mojo::Base -strict;

# to run it
# cd C:\Dev\portale_bobo\webapp
# perl bobo\script\bobo test

use Test::More;
use Test::Mojo;
use Data::Dumper;

use_ok 'Bobo';

my $t = Test::Mojo->new('Bobo');

# #-- ----------------------------------------------------------------------------------
# #-- welcome
# #-- ----------------------------------------------------------------------------------
# $t->get_ok('/')
#   ->status_is(200)
#   ->content_like(qr/Welcome/i)
#   ->content_type_like(qr/html/)
#   ->element_exists('html head')
#   ->element_exists('html body');


#-- ----------------------------------------------------------------------------------
#-- download dataview zip file
#-- https://github.com/koorchik/Mojolicious-Plugin-RenderFile/blob/master/t/basic.t
#-- ----------------------------------------------------------------------------------
$t->post_ok('/str_dataview_get_data' => form => {
        dateFrom => '2019-11-01',
        dateTo => '2019-11-01 23:59:59',
        stidArr => [1000],
        pridArr => [1]
    })
    ->content_type_like(qr/application\/zip/)
    ->status_is(200);



#-- ----------------------------------------------------------------------------------
# end tests
#-- ----------------------------------------------------------------------------------
done_testing();
