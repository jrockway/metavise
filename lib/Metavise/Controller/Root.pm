package Metavise::Controller::Root;
# ABSTRACT:
use Moose;
use true;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

__PACKAGE__->config(
    namespace => '',
);

sub process_listing : Path Args(0) {
    my ($self, $c) = @_;
    $c->stash->{title} = 'Process List - Metavise';
    $c->stash->{processes} = [ $c->model('Processes')->processes ];
}

sub default : Path {
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->res->body('404 Not Found');
}

sub end : ActionClass('RenderView') {}

__PACKAGE__->meta->make_immutable;
