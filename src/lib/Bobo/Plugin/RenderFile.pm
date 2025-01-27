package Bobo::Plugin::RenderFile;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use File::Basename;
use Encode qw( encode decode_utf8 );
use Mojo::Util 'quote';
use File::Find::Rule;

our $VERSION = '0.12';

sub register {
    my ( $self, $app ) = @_;

    $app->helper( 'render_file' => sub {
        my $c        = shift;
        my %args     = @_;

        utf8::decode($args{filename}) if $args{filename} && !utf8::is_utf8($args{filename});
        utf8::decode($args{filepath}) if $args{filepath} && !utf8::is_utf8($args{filepath});

        my $filename            = $args{filename};
        my $status              = $args{status}               || 200;
        my $content_disposition = $args{content_disposition}  || 'attachment';
        my $cleanup             = $args{cleanup} // 0;

        # Content type based on format
        if ($args{format} && $args{content_type}) {
            $c->app->log->error('You cannot provide both "format" and "content_type" option');
            return;
        }

        my $content_type = $args{content_type};
        $content_type ||= $c->app->types->type( $args{format} ) if $args{format};
        $content_type ||= 'application/x-download';

        # Create asset
        my $asset;
        if (my $filepath = $args{filepath}) {
            unless (-f $filepath && -r $filepath) {
                $c->app->log->error("Cannot read file [$filepath]. error [$!]");
                return;
            }

            $filename ||= fileparse($filepath);
            $asset = Mojo::Asset::File->new( path => $filepath );
            $asset->cleanup($cleanup);
        }
        elsif ($args{data}) {
            $filename ||= $c->req->url->path->parts->[-1] || 'download';
            $asset = Mojo::Asset::Memory->new();
            $asset->add_chunk( $args{data} );
        }
        else {
            $c->app->log->error('You must provide "data" or "filepath" option');
            return;
        }

        # Set response headers
        my $headers = $c->res->content->headers();

        $filename = quote($filename); # quote the filename, per RFC 5987
        $filename = encode("UTF-8", $filename);

        $headers->add( 'Content-Type', $content_type . ';name=' . $filename );
        $headers->add( 'Content-Disposition', $content_disposition . ';filename=' . $filename );
        $headers->add( 'Set-Cookie', 'fileDownload=true; path=/' );



        # Range
        # Partially based on Mojolicious::Static
        if (my $range = $c->req->headers->range) {
            my $start = 0;
            my $size  = $asset->size;
            my $end   = $size - 1 >= 0 ? $size - 1 : 0;

            # Check range
            if ($range =~ m/^bytes=(\d+)-(\d+)?/ && $1 <= $end) {
                $start = $1;
                $end = $2 if defined $2 && $2 <= $end;

                $status = 206;
                $headers->add( 'Content-Length' => $end - $start + 1 );
                $headers->add( 'Content-Range'  => "bytes $start-$end/$size" );
            }
            else {
                # Not satisfiable
                return $c->rendered(416);
            }

            # Set range for asset
            $asset->start_range($start)->end_range($end);
        }
        else {
            $headers->add( 'Content-Length' => $asset->size );
        }

        # Stream content directly from file
        $c->res->content->asset($asset);
        return $c->rendered($status);
    });

    $app->helper(helperGetStationFiles =>sub
    {
        my $self       = shift;
        my $path       = shift;

            # log
        $self->app->log->debug("sub helperGetStationFiles");

        # -------------------------------------------------------
        # calculate statistics
        # -------------------------------------------------------
        # ricerca tutti .pdf file nella directory
        $path = $self->app->home->rel_file("/public/".$path."/");

        my @pdf_files = File::Find::Rule->file()
                        ->name( '*.pdf' )
                        ->in( $path );

        my @img_files = File::Find::Rule->file()
                        ->name( '*.png', '*.jpeg', '*.jpg' )
                        ->in( $path );

        # my @other_files = File::Find::Rule->file()
        #                 ->name( '*.csv', '*.docs', '*.txt' )
        #                 ->in( $path );

        # result
        # $self->helperDumper(@pdf_files);
        # $self->helperDumper(@img_files);

        my $json = {
            pdf_files => [@pdf_files],
            img_files => [@img_files]
        };

        # return
        return $json;

    });

}

1;
