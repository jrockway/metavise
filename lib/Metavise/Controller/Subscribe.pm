package Metavise::Controller::Subscribe;
# ABSTRACT: handle the details of starting the streaming data socket
use Moose;
use true;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }


sub subscribe : Path Args(0){
    my ($self, $c) = @_;
    $c->model('Processes'); # XXX: force vivication at startup

    my $id = $c->req->env->{'mongrel2.id'};
    confess 'did not get ID from the web server -- '.
        'are you using PSGI and AnyEvent::Mongrel2?'
            unless defined $id;

    # XXX: handle disconnects;
    $c->model('Listeners')->insert_listener($id);
    $c->res->header( content_type => 'text/json' );
    $c->res->header( connection => 'keep-alive' );
    $c->res->status(200);
    $c->res->body( sub {
        $c->model('Listeners')->send_to({ welcome => 'to earth' }, $id);
    } );
}

__PACKAGE__->meta->make_immutable;
