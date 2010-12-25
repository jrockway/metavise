package Metavise::Controller::Process;
# ABSTRACT:
use Moose;
use true;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::REST' }

sub status : Path Args(1) {
    my ($self, $c, $name) = @_;
    my $p = $c->model('Processes', $name);
    if(!$p){
        $c->res->status(404);
        $c->res->body("No process '$name'");
        $c->detach;
    }

    $c->stash->{process} = $p;
    $c->detach('View::TT');
}

__PACKAGE__->meta->make_immutable;
