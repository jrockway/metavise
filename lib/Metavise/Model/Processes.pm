package Metavise::Model::Processes;
# ABSTRACT: glue the Processes to Catalyst
use strict;
use warnings;
use true;
use namespace::autoclean;
use Metavise::Group;

use parent 'Catalyst::Model';

sub COMPONENT {
    my ($class, $app, $args) = @_;
    return bless $args, $class;
}

sub ACCEPT_CONTEXT {
    my ($self, $c, @args) = @_;
    my $l = $c->model('Listeners');

    $self->{group} ||= Metavise::Group->new(
        directory => $self->{directory},
        on_change => sub { $l->post_event('process', @_) },
    );

    if(my $name = shift @args){
        warn $name;
        return $self->{group}->get_process($name);
    }
    warn "return";
    return $self->{group};
}
